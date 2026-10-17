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
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: blocker) == bytes)
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
    #expect(pointer.schemaVersion == 21)
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
    #expect(saved == expectedDisk)
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
    #expect(changedFields == ["savedNPCPersistence"])
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let evidence = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
      try JSONEncoder().encode(changedFields).write(
        to: evidence.appendingPathComponent("launch-saved-commander-diff.json"))
    }
    #expect(await runtime.takeNewCommanderSaveReceipt()?.url == save)
  }
}
