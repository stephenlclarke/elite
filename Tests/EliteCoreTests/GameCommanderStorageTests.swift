import Foundation
import Testing

@testable import EliteCore

struct GameCommanderStorageTests {
  @Test func gameCopiesDetachNestedCommanderMutationsAndWholeValueReplacement() throws {
    var original = Game(executive: false)
    try original.commander.prepareEquipment(legacy: false)
    original.commander.cargo[0] = 2
    let station = ScriptStationResource(
      identity: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"),
      galaxy: 0, system: 7)
    original.commander.scriptState.stationResources[station.key] = station
    try #require(original.commander.valid)
    let retained = original
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(original.commander)
    let laser = try #require(original.commander.fittedEquipment(at: .laser(.front)))
    var copy = original
    try copy.commander.storeEquipment(
      laser, expectedRevision: #require(copy.commander.equipmentInventory?.revision))
    try #require(copy.commander.valid)
    copy.commander.cargo[0] = 9
    try #require(copy.commander.valid)
    copy.commander.scriptState.stationResources[station.key]?.energy = 50
    try #require(copy.commander.valid)
    copy.commander.credits += 10
    try #require(copy.commander.valid)
    let changed = copy.commander
    #expect(changed != retained.commander)
    #expect(copy.commander.fittedEquipment(at: .laser(.front)) == nil)
    #expect(original.commander.fittedEquipment(at: .laser(.front)) == laser)
    #expect(original.commander == retained.commander)
    #expect(try encoder.encode(original.commander) == bytes)
    original.commander.cargo[0] = 5
    try #require(original.commander.valid)
    original.commander.scriptState.stationResources[station.key]?.energy = 0
    original.commander.scriptState.stationResources[station.key]?.destroyed = true
    try #require(original.commander.valid)
    #expect(copy.commander == changed && retained.commander.cargo[0] == 2)
    #expect(retained.commander.scriptState.stationResources[station.key] == station)
    let replacement = Commander()
    copy.commander = replacement
    #expect(copy.commander == replacement && retained.commander != replacement)
    #expect(original.commander.cargo[0] == 5)
    #expect(try JSONDecoder().decode(Commander.self, from: bytes) == retained.commander)
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let directory = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let rows: [[String: Any]] = [
        [
          "type": String(reflecting: EliteCore.Game.self),
          "sizeBytes": MemoryLayout<EliteCore.Game>.size,
          "strideBytes": MemoryLayout<EliteCore.Game>.stride,
          "alignment": MemoryLayout<EliteCore.Game>.alignment,
        ],
        [
          "type": String(reflecting: EliteCore.Commander.self),
          "sizeBytes": MemoryLayout<EliteCore.Commander>.size,
          "strideBytes": MemoryLayout<EliteCore.Commander>.stride,
          "alignment": MemoryLayout<EliteCore.Commander>.alignment,
        ],
      ]
      try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        .write(to: directory.appendingPathComponent("game-commander-layout.json"))
    }
  }

  @Test func actorSnapshotsRemainIndependentThroughActualXYZzyGrantAndCallerMutation()
    async throws
  {
    var initial = Game(executive: false)
    initial.screen = .status
    try initial.commander.prepareEquipment(legacy: false)
    let supplied = initial.commander
    let runtime = GameRuntime(game: initial)
    let retained = await runtime.snapshot()
    let authorityBefore = retained.commander
    #expect(initial.commander == supplied)
    for key in "xyzzy" { await runtime.key(String(key)) }
    let committed = await runtime.snapshot()
    try #require(committed.commander.name == "CLARKE" && committed.commander.xyzzyActive)
    try #require(committed.commander.valid)
    #expect(retained.commander == authorityBefore && initial.commander == supplied)
    #expect(retained.commander.name == "JAMESON" && !retained.commander.xyzzyActive)
    #expect(committed.commander.equipmentInventory != retained.commander.equipmentInventory)
    var caller = committed
    caller.commander.credits = 0
    caller.commander.cargo[0] += 1
    let laser = try #require(caller.commander.fittedEquipment(at: .laser(.front)))
    try caller.commander.storeEquipment(
      laser, expectedRevision: #require(caller.commander.equipmentInventory?.revision))
    #expect(caller.commander != committed.commander)
    #expect(await runtime.snapshot().commander == committed.commander)
    #expect(retained.commander == authorityBefore && initial.commander == supplied)
  }

  @Test func failedActualLaunchPublicationRollsBackNestedStateAndRetryKeepsOldSnapshots()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocker = directory.appendingPathComponent("parent")
    let save = blocker.appendingPathComponent("commander.json")
    var initial = Game(executive: false)
    initial.screen = .status
    try initial.commander.prepareEquipment(legacy: false)
    let runtime = GameRuntime(game: initial)
    _ = try await runtime.registerNewCommanderDestination(at: save)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let bytes = Data("preserve this existing file".utf8)
    try bytes.write(to: blocker)
    let retained = await runtime.snapshot()
    let commander = retained.commander
    await runtime.key("0")
    let refused = await runtime.snapshot()
    #expect(refused.commander == commander && retained.commander == commander)
    #expect(refused.docked && refused.bodies == retained.bodies)
    #expect(refused.commander.nativeStations == nil)
    #expect(refused.commander.scriptState.calendarLedger == nil)
    #expect(refused.pendingNewSaveDestination == save)
    let refusedReceipt = await runtime.takeNewCommanderSaveReceipt()
    let blockerBytes = try Data(contentsOf: blocker)
    #expect(refusedReceipt == nil)
    #expect(blockerBytes == bytes)
    try FileManager.default.removeItem(at: blocker)
    await runtime.key("0")
    let committed = await runtime.snapshot()
    try #require(!committed.docked && committed.commander.nativeStations != nil)
    #expect(committed.commander.scriptState.calendarSeconds == 600)
    #expect(retained.commander == commander && refused.commander == commander)
    #expect(committed.commander != commander)
    let savedBytes = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: savedBytes)
    let (saved, _) = try ScriptSaveStore.read(savedBytes, from: save)
    #expect(pointer.schemaVersion == 26)
    let liveCommander = committed.commander
    try #require(liveCommander.npcPersistence.count > 0)
    let liveNPCs = committed.bodies.compactMap { body -> ActorIdentity? in
      guard let physical = body.physical, physical.npc != nil else { return nil }
      return liveCommander.npcPersistence.logicalIdentity(for: physical.identity)
    }
    try #require(!liveNPCs.isEmpty)
    // Disk custody retains each craft but clears scene-local bindings and offers.
    // Derive the documented normalization from an independent value copy.
    var expectedDisk = liveCommander
    expectedDisk.npcPersistence.resetPhysicalBindings(system: committed.systemIdentity)
    expectedDisk.resetWantedCareerBindings(system: committed.systemIdentity)
    #expect(saved == expectedDisk)
    let liveCareers = liveCommander.wantedCareers.careers
    try #require(liveCareers.values.contains { $0.binding != nil })
    #expect(saved.wantedCareers.careers.count == liveCareers.count)
    for (identity, career) in liveCareers {
      var expectedCareer = career
      if identity.system == committed.systemIdentity { expectedCareer.binding = nil }
      #expect(saved.wantedCareers.careers[identity] == expectedCareer)
    }
    for logical in liveNPCs {
      try #require(liveCommander.npcPersistence.binding(for: logical) != nil)
      #expect(saved.npcPersistence.binding(for: logical) == nil)
      #expect(
        saved.npcPersistence.snapshot(for: logical)
          == liveCommander.npcPersistence.snapshot(for: logical))
    }
    #expect(committed.commander == liveCommander)
    #expect(retained.commander == commander && refused.commander == commander)
    let encoder = JSONEncoder()
    let savedFields = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(saved)) as? [String: NSObject])
    let liveFields = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(liveCommander)) as? [String: NSObject])
    let changedFields = Set(savedFields.keys).union(liveFields.keys).filter {
      savedFields[$0] != liveFields[$0]
    }.sorted()
    #expect(saved.equipmentInventory == liveCommander.equipmentInventory)
    #expect(saved.equipment == liveCommander.equipment)
    // Canonicalize only the Set-valued field; keep the raw diff for evidence below.
    var savedSemanticFields = savedFields
    var liveSemanticFields = liveFields
    savedSemanticFields["equipment"] = saved.equipment.sorted() as NSArray
    liveSemanticFields["equipment"] = liveCommander.equipment.sorted() as NSArray
    let semanticChangedFields = Set(savedSemanticFields.keys).union(liveSemanticFields.keys).filter
    {
      savedSemanticFields[$0] != liveSemanticFields[$0]
    }.sorted()
    // Codable dictionaries/sets may reorder their array representation on reload.
    // The complete Commander comparison above still proves semantic conservation.
    #expect(changedFields.contains("savedNPCPersistence"))
    #expect(
      Set(semanticChangedFields).isSubset(of: [
        "savedNPCPersistence", "savedEquipmentInventory", "savedWantedCareers",
      ]))
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let evidence = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
      try JSONEncoder().encode(changedFields).write(
        to: evidence.appendingPathComponent("launch-saved-commander-diff.json"))
    }
    let committedReceipt = await runtime.takeNewCommanderSaveReceipt()
    #expect(committedReceipt?.url == save)
  }

  @Test func borrowedCommanderReadsPreserveDefaultFlightAndOwnedSnapshots() throws {
    var original = Game(executive: false)
    let encoder = JSONEncoder()
    let before = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(original.commander)) as? [String: Any])
    #expect(before["savedFlightSimulation"] == nil)
    #expect(before["savedScriptState"] == nil)
    #expect(original.withReadOnlyScriptState { $0.nextEvent } == 0)
    #expect(original.withReadOnlyCommander { $0.scriptState.instances.isEmpty })
    var ownedDefaultScript = original.withReadOnlyCommander { $0.scriptState }
    ownedDefaultScript.nextEvent = 99
    #expect(original.withReadOnlyCommander { $0.scriptState.nextEvent } == 0)
    original.commander.scriptState.nextEvent = 0

    let defaults = original.withReadOnlyCommander { commander in
      (
        visit: commander.flightSimulation.visit,
        time: commander.flightSimulation.physicalTime,
        system: commander.flightSimulation.system,
        hasAnchors: commander.flightSimulation.anchors != nil,
        position: commander.flightSimulation.pose.position
      )
    }
    #expect(defaults.visit == 0 && defaults.time == 0)
    #expect(defaults.system == nil && !defaults.hasAnchors)
    #expect(defaults.position == Vector3(0, 0, 0))
    var ownedDefault = original.withReadOnlyCommander { $0.flightSimulation }
    ownedDefault.physicalTime = 99
    #expect(original.withReadOnlyCommander { $0.flightSimulation.physicalTime } == 0)
    let after = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(original.commander)) as? [String: Any])
    #expect(after["savedFlightSimulation"] == nil)
    #expect(after["savedScriptState"] == nil)

    let system = SystemIdentity(galaxy: 0, system: 7)
    original.commander.flightSimulation.enter(system, arriving: false)
    original.commander.scriptState.nextEvent = 4
    let retained = original
    var ownedScript = original.withReadOnlyCommander { $0.scriptState }
    original.commander.scriptState.nextEvent = 7
    #expect(retained.withReadOnlyCommander { $0.scriptState.nextEvent } == 4)
    #expect(ownedScript.nextEvent == 4)
    ownedScript.nextEvent = 88
    var ownedFlight = original.withReadOnlyCommander { $0.flightSimulation }
    original.commander.flightSimulation.advancePhysicalTime(3)
    original.commander.flightSimulation.pose.position.x += 25
    #expect(original.withReadOnlyCommander { $0.flightSimulation.physicalTime } == 3)
    #expect(original.withReadOnlyCommander { $0.flightSimulation.pose.position.x } == 25)
    #expect(retained.withReadOnlyCommander { $0.flightSimulation.physicalTime } == 0)
    #expect(retained.withReadOnlyCommander { $0.flightSimulation.pose.position.x } == 0)
    #expect(ownedFlight.physicalTime == 0 && ownedFlight.pose.position.x == 0)

    ownedFlight.pose.position.x = -40
    var caller = retained
    caller.commander.scriptState.nextEvent = 9
    #expect(caller.withReadOnlyCommander { $0.scriptState.nextEvent } == 9)
    #expect(original.withReadOnlyCommander { $0.scriptState.nextEvent } == 7)
    #expect(retained.withReadOnlyCommander { $0.scriptState.nextEvent } == 4)
    #expect(ownedScript.nextEvent == 88 && ownedDefaultScript.nextEvent == 99)
    caller.commander.flightSimulation.enter(.init(galaxy: 0, system: 8), arriving: true)
    #expect(caller.withReadOnlyCommander { $0.flightSimulation.visit } == 2)
    #expect(retained.withReadOnlyCommander { $0.flightSimulation.visit } == 1)
    #expect(original.withReadOnlyCommander { $0.flightSimulation.system } == system)
    #expect(original.withReadOnlyCommander { $0.flightSimulation.pose.position.x } == 25)
    #expect(retained.withReadOnlyCommander { $0.flightSimulation.pose.position.x } == 0)
    #expect(ownedFlight.pose.position.x == -40 && ownedDefault.physicalTime == 99)
    #expect(original.withReadOnlyScriptState { $0.nextEvent } == 7)
    let bytes = try encoder.encode(original.commander)
    let fields = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let savedScript = try #require(fields["savedScriptState"] as? NSDictionary)
    let ownedActualScript = original.withReadOnlyScriptState { $0 }
    let plainScript = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(ownedActualScript)) as? NSDictionary)
    #expect(savedScript == plainScript)
    let decoded = try JSONDecoder().decode(Commander.self, from: bytes)
    #expect(decoded.scriptState.nextEvent == 7)
    #expect(decoded.flightSimulation.pose.position.x == 25)
  }
}
