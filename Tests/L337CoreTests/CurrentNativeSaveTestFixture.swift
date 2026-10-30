import Foundation
import Testing

@testable import L337Core

/// The two original native fixtures retain their real scene and distinct save/load phases.
enum CurrentNativeSaveTestFixture {
  private static func object<T: Encodable>(_ value: T) throws -> Any {
    try JSONSerialization.jsonObject(with: ScriptValueStorage.encoder().encode(value))
  }

  private static func worldObject(_ world: ScriptWorldSave) throws -> NSDictionary {
    try #require(object(world) as? NSDictionary)
  }

  /// Failure-only facts distinguish the disk projection from strict world validation.
  @inline(never)
  private static func diskMismatchFacts(
    _ stored: borrowing Commander, expected: borrowing Commander
  ) throws -> String {
    var actualFields = try #require(object(stored) as? [String: Any])
    var expectedFields = try #require(object(expected) as? [String: Any])
    var differingFields: [String] = []
    for key in Set(actualFields.keys).union(expectedFields.keys).sorted() {
      if let actual = actualFields[key], let expected = expectedFields[key] {
        if !NSDictionary(dictionary: [key: actual]).isEqual(
          NSDictionary(dictionary: [key: expected]))
        {
          differingFields.append(key)
        }
      } else {
        differingFields.append(key)
      }
    }
    actualFields.removeValue(forKey: "savedWantedCareers")
    expectedFields.removeValue(forKey: "savedWantedCareers")
    let otherFieldsMatch = NSDictionary(dictionary: actualFields).isEqual(
      NSDictionary(dictionary: expectedFields))
    let wantedMatches = stored.wantedCareers == expected.wantedCareers
    return
      "wantedCareersMatch=\(wantedMatches); otherCommanderFieldsMatch=\(otherFieldsMatch); differingSerializedFields=\(differingFields.joined(separator: ","))"
  }

  /// Native station publication captures condition only; these fixtures have no destroyed source.
  private static func publicationExpectation(_ before: Game) throws -> Commander {
    var expected = before.commander
    try expected.prepareEquipment()
    expected.mirrorFittedEquipment()
    try #require(expected == before.commander)
    var mining = expected.miningLedgerForMigration(legacyMissing: false)
    try #require(mining.requiredPresencePinSystems.isEmpty)
    let system = Universe.systemsIncludingPlugh(number: expected.galaxy)[expected.system]
    try mining.migratePresence(
      current: .init(system: system, galaxy: expected.galaxy), historical: [])
    expected.miningLedger = mining
    if (before.requiresScriptDurability || expected.usesEconomyMiningSaveVersion
      || expected.usesModularDriveSaveVersion) && expected.scriptState.calendarLedger == nil
    {
      let legacy = expected.legacyOwnedEquipment != nil || before.jumpCountdown != nil
      expected.scriptState.calendarLedger = .init(
        origin: legacy ? .inactiveLegacyMigration : .newCommander)
      if before.jumpCountdown != nil {
        expected.scriptState.calendarLedger?.legacyUntrackedJourney = true
      }
    }
    // The original audio fixture removed body zero before its real ticks; plans never launched.
    try #require(!before.bodies.contains { $0.id == 0 && $0.hull == .station })
    for body in before.bodies where body.nativeStationIdentity != nil {
      let identity = try #require(body.nativeStationIdentity)
      let index = try #require(expected.nativeStations?.poses.firstIndex { $0.station == identity })
      let record = try #require(
        expected.nativeStations?.ledger.records.first { $0.identity == identity })
      let source = try #require(NativeStationSource.binding(for: identity))
      try #require(
        record.tombstone == nil && body.energy > 0 && body.energy <= source.maximumEnergy)
      expected.nativeStations?.poses[index].energy = body.energy
    }
    // Each actual living ordinary body must already be retained by the original completed tick.
    if let context = before.gameplayContext() {
      for body in before.bodies where body.physical?.npc != nil {
        let snapshot = try #require(
          NPCPersistenceSnapshot.capture(
            body: body, pose: before.commander.flightSimulation.pose,
            physicalTime: context.physicalTime, protection: context.protection))
        let captured = expected.npcPersistence.capture(snapshot, protection: context.protection)
        let captureAccepted: Bool
        if case .refused = captured { captureAccepted = false } else { captureAccepted = true }
        try #require(captureAccepted)
      }
    }
    return expected
  }

  /// Use original source bodies and the existing domain admission primitives, before actual load.
  private static func loadExpectation(
    original: Game, disk: Commander, world: ScriptWorldSave
  ) throws -> (Commander, NSDictionary) {
    var expected = disk
    if expected.npcPersistence.count > 0 {
      let context = try #require(original.gameplayContext())
      var snapshots: [NPCPersistenceSnapshot] = []
      var spawns: [ActorIdentity: SpawnIdentity] = [:]
      for body in original.bodies where body.physical?.npc != nil {
        let snapshot = try #require(
          NPCPersistenceSnapshot.capture(
            body: body, pose: original.commander.flightSimulation.pose,
            physicalTime: context.physicalTime, protection: context.protection))
        snapshots.append(snapshot)
        if let spawn = body.physical?.spawnIdentity { spawns[snapshot.actor] = spawn }
      }
      try expected.npcPersistence.restoreSceneBindings(
        snapshots, sceneActors: Set(original.bodies.compactMap { $0.physical?.identity }),
        spawnIdentities: spawns, system: original.systemIdentity,
        visit: original.commander.flightSimulation.visit,
        physicalTime: original.commander.flightSimulation.physicalTime,
        nextActor: original.commander.flightSimulation.nextActor, protection: context.protection)
      var careers = expected.wantedCareers
      careers.reconcile(expected.npcPersistence, system: original.systemIdentity)
      if careers != expected.wantedCareers { expected.wantedCareers = careers }
    }
    var loadedWorld = world
    if !loadedWorld.screen.isFlight { loadedWorld.screen = .status }
    var value = try #require(object(loadedWorld) as? [String: Any])
    var bodies = try #require(value["bodies"] as? [[String: Any]])
    let stations = original.bodies.indices.filter {
      original.bodies[$0].nativeStationIdentity != nil
    }
    if !stations.isEmpty {
      var flight = expected.flightSimulation
      let allocatedSpawn = flight.allocateSpawn()
      let sequence = try #require(allocatedSpawn)
      for (member, index) in stations.enumerated() {
        let body = original.bodies[index]
        let identity = try #require(body.nativeStationIdentity)
        let allocatedActor = flight.allocateActor()
        let actor = try #require(allocatedActor)
        let id = world.nextBodyID + member
        try expected.nativeStations?.ledger.rebind(identity, to: .init(actor: actor, bodyID: id))
        var physical = try #require(bodies[index]["physical"] as? [String: Any])
        physical["identity"] = try object(actor)
        physical["spawnIdentity"] = try object(
          SpawnIdentity(
            system: original.systemIdentity, visit: flight.visit, sequence: sequence,
            member: UInt16(member), producer: .mission))
        bodies[index]["id"] = id
        bodies[index]["physical"] = physical
      }
      expected.flightSimulation = flight
      value["bodies"] = bodies
      value["nextBodyID"] = world.nextBodyID + stations.count
    }
    return (expected, NSDictionary(dictionary: value))
  }

  static func restore(_ original: Game) async throws -> Game {
    try #require(
      original.commander.savedEMPState == nil && original.commander.alienStorageState == nil)
    try #require(original.commander.scriptState.instances.isEmpty)
    try #require(original.commander.contracts.boards.isEmpty && original.jumpCountdown == nil)
    try #require(
      original.screen == .mission || original.screen == .status || original.screen.isFlight)
    try #require(original.commander.savedEquipmentVersion == 3)
    var raw = original
    let acceptedRaw = raw.load(original.commander)
    #expect(!acceptedRaw && raw.commander == original.commander)
    let savedWorld = original.scriptWorldSave
    let expectedWorld = try worldObject(savedWorld)
    #expect(try worldObject(raw.scriptWorldSave).isEqual(expectedWorld))
    #expect(raw.dischargeAudio.epoch == original.dischargeAudio.epoch)
    #expect(raw.dischargeAudio.events == original.dischargeAudio.events)

    var expectedInitialized = original.commander
    try expectedInitialized.prepareEquipment()
    expectedInitialized.mirrorFittedEquipment()
    try #require(expectedInitialized == original.commander)
    if original.requiresScriptDurability && expectedInitialized.scriptState.calendarLedger == nil {
      expectedInitialized.scriptState.calendarLedger = .init(origin: .newCommander)
    }
    let runtime = GameRuntime(game: original)
    let initialized = await runtime.snapshot()
    try #require(initialized.commander == expectedInitialized)
    let expectedLive = try publicationExpectation(initialized)
    var expectedDisk = expectedLive
    if expectedDisk.npcPersistence.count > 0 {
      expectedDisk.npcPersistence.resetPhysicalBindings(system: original.systemIdentity)
    }
    expectedDisk.resetWantedCareerBindings(system: original.systemIdentity)
    let (expectedLoaded, expectedLoadedWorld) = try loadExpectation(
      original: original, disk: expectedDisk, world: savedWorld)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    try await runtime.save(to: file)
    let published = await runtime.snapshot()
    try #require(published.commander == expectedLive)
    #expect(try worldObject(published.scriptWorldSave).isEqual(expectedWorld))
    #expect(published.dischargeAudio.epoch == original.dischargeAudio.epoch)
    #expect(published.dischargeAudio.events == original.dischargeAudio.events)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    try #require(pointer.format == "elite-script-save" && pointer.schemaVersion == 26)
    try #require(pointer.scope == "commander" && pointer.valueCodec == ScriptValueStorage.codec)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let names = Set(["commander.json", "missions.json", "world.json", "contracts.json"])
    try #require(Set(pointer.hashes.keys) == names)
    try #require(Set(try FileManager.default.contentsOfDirectory(atPath: generation.path)) == names)
    for name in names {
      let chunk = try Data(contentsOf: generation.appendingPathComponent(name))
      try #require(ScriptPackLibrary.hash(chunk) == pointer.hashes[name])
    }
    let (stored, world) = try ScriptSaveStore.read(bytes, from: file)
    // Set encodings can reorder JSON arrays; installed modules must still match as typed values.
    try #require(stored.equipment == expectedDisk.equipment)
    try #require(stored.equipmentInventory == expectedDisk.equipmentInventory)
    let diskMatches = stored == expectedDisk
    if !diskMatches {
      let detail = try diskMismatchFacts(stored, expected: expectedDisk)
      try #require(diskMatches, Comment(rawValue: detail))
    }
    try #require(world.valid)
    try #require(world.consistent(with: stored))
    #expect(try worldObject(world).isEqual(expectedWorld))
    let paths = Set(try FileManager.default.subpathsOfDirectory(atPath: directory.path))
    let files = try ScriptFinanceTestFixture.files(directory)
    try await runtime.load(from: file, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(restored.commander == expectedLoaded)
    #expect(try worldObject(restored.scriptWorldSave).isEqual(expectedLoadedWorld))
    #expect(restored.missionNotice == nil)
    #expect(Set(try FileManager.default.subpathsOfDirectory(atPath: directory.path)) == paths)
    #expect(try ScriptFinanceTestFixture.files(directory) == files)
    return restored
  }
}
