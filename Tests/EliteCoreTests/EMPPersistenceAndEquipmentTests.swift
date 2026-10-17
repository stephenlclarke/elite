import Foundation
import Testing

@testable import EliteCore

struct EMPPersistenceAndEquipmentTests {
  @Test func nativeSaveRestoresDisabledHullAndEveryOccupiedPodWithoutReissuingPeople() async throws
  {
    var game = try empFixture(catalogue: "SH001")
    game.bodies[0].physical?.velocity = .init(0, 0, 0)
    game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    try #require(game.fireEMPPirateBlaster())
    let source = try #require(game.bodies[0].physical?.empSource)
    for _ in 0..<50 { game.tick(delta: 0.1) }
    let record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 22)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved.valid && saved.savedEMPState == game.commander.savedEMPState)
    let restored = GameRuntime()
    try await restored.load(from: file, persistMigrations: false)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.savedEMPState == saved.savedEMPState)
    #expect(
      loaded.bodies.filter { $0.physical?.empCrewPod?.source == source }.count == record.crewTotal)
    let hull = try #require(loaded.bodies.first { $0.physical?.empSource == source })
    #expect(loaded.isEMPDisabled(hull) && hull.physical?.npc == nil)
    #expect(
      hull.physical?.identity
        == game.bodies.first { $0.physical?.empSource == source }?.physical?.identity)
    for _ in 0..<30 { _ = await restored.advance(delta: 0.1) }
    let after = await restored.snapshot()
    #expect(after.commander.savedEMPState?.records[source]?.pods.count == record.crewTotal)
    #expect(Set(after.bodies.compactMap { $0.physical?.empCrewPod }).count == record.crewTotal)
    var bad = after
    bad.commander.savedEMPState?.records[source]?.hull.body.physical?.empSource = .init(
      system: source.system, visit: source.visit, entity: source.entity + 1)
    #expect(!bad.commander.valid)
    let refused = GameRuntime(game: bad)
    let invalidFile = directory.appendingPathComponent("refused.json")
    await #expect(throws: (any Error).self) { try await refused.save(to: invalidFile) }
    #expect(!FileManager.default.fileExists(atPath: invalidFile.path))
  }

  @Test func oldNativeSaveAndRawCommanderKeepInnocentEMPWordsButRejectActualNewState() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var game = Game(executive: false)
    game.screen = .status
    game.commander.name = "empPirateBlaster"
    var instance = ScriptInstance(
      id: UUID(), definition: "fixture/innocent-text", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.data = .object([
      "kind": .string("emp"), "producer": .string("emp"),
      "empSource": .string("dialogue only"), "name": .string(Equipment.empPirateBlaster),
    ])
    game.commander.scriptState.instances[instance.id] = instance
    let raw = directory.appendingPathComponent("ordinary.json")
    let rawBytes = try JSONEncoder().encode(game.commander)
    try rawBytes.write(to: raw)
    try EMPVersionedSave.rejectFields(rawBytes, part: .commander)
    let rawRuntime = GameRuntime()
    try await rawRuntime.load(from: raw, persistMigrations: false)
    #expect(await rawRuntime.snapshot().commander.name == "empPirateBlaster")
    let file = directory.appendingPathComponent("old-native.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 21)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved.scriptState.instances[instance.id]?.data == instance.data)
    var forged = try #require(JSONSerialization.jsonObject(with: rawBytes) as? [String: Any])
    forged["savedEMPState"] = [:]
    #expect(throws: SaveError.invalidCommander) {
      try EMPVersionedSave.rejectFields(
        JSONSerialization.data(withJSONObject: forged), part: .commander)
    }
    let innocentWorld: [String: Any] = [
      "libraryScreen": ["text": ["empSource": "fiction"]], "bodies": [],
    ]
    try EMPVersionedSave.rejectFields(
      JSONSerialization.data(withJSONObject: innocentWorld), part: .world)
    let forgedWorld: [String: Any] = ["bodies": [["physical": ["empSource": [:]]]]]
    #expect(throws: SaveError.invalidCommander) {
      try EMPVersionedSave.rejectFields(
        JSONSerialization.data(withJSONObject: forgedWorld), part: .world)
    }
  }

  @Test func actualEMPContainerCannotBeDowngradedOrEraseItsTrafficTransfer() async throws {
    var game = try empFixture()
    try #require(game.fireEMPPirateBlaster())
    let source = try #require(game.commander.savedEMPState?.records.keys.first)
    #expect(game.commander.npcPersistence.terminalReason(for: source) == .empTransferred)
    var erased = game.commander
    erased.savedEMPState = nil
    #expect(!erased.valid)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    try #require(pointer.schemaVersion == 22)
    let old = ScriptSavePointer(
      format: pointer.format, schemaVersion: 21, generation: pointer.generation,
      hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    #expect(throws: SaveError.invalidCommander) {
      _ = try ScriptSaveStore.read(ScriptValueStorage.encoder().encode(old), from: file)
    }
    let raw = directory.appendingPathComponent("raw.json")
    try JSONEncoder().encode(game.commander).write(to: raw)
    let restored = GameRuntime()
    await #expect(throws: (any Error).self) { try await restored.load(from: raw) }
  }

  @Test func realShopDebitsFiniteCashAndReloadKeepsOneSeparateFitting() async throws {
    var game = Game(executive: false)
    game.screen = .equipment
    game.commander.credits = 100_000
    game.commander.system = try #require(game.systems.first { $0.technology >= 8 }?.id)
    try game.commander.prepareEquipment(legacy: false)
    game.selection = try #require(
      Equipment.all.firstIndex { $0.name == Equipment.empPirateBlaster })
    let item = Equipment.all[game.selection]
    #expect(item.price == 30_000 && item.technology == 8)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    let result = await runtime.equipmentTransaction(.purchase(context))
    #expect(result.applied)
    let after = await runtime.snapshot()
    #expect(after.commander.credits == before.commander.credits - before.shopPrice(item))
    #expect(
      after.commander.fittedEquipment(at: .utility(.empPirateBlaster))?.node.key
        == Equipment.empPirateBlaster)
    #expect(after.commander.equipmentPurchaseHistory?.paid.count == 1)
    let bytes = try Data(contentsOf: file)
    #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: bytes).schemaVersion == 22)
    let replay = await runtime.equipmentTransaction(.purchase(context))
    #expect(replay == .refused(.staleContext))
    #expect(try Data(contentsOf: file) == bytes)
    let restored = GameRuntime()
    try await restored.load(from: file)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.equipmentInventory == after.commander.equipmentInventory)
    #expect(
      loaded.commander.equipmentInventory?.items.filter {
        $0.node.key == Equipment.empPirateBlaster
      }.count == 1)
    #expect(loaded.commander.laserMounts == before.commander.laserMounts)
  }

  @Test func xyzzyGrantsOneBlasterAndRetainsFourNavalLasersAcrossRepeatedGrantAndLoad() async throws
  {
    var game = Game(executive: false)
    game.launch()
    for key in "xyzzy" { game.key(String(key)) }
    for _ in 0..<3 { game.key("2") }
    let tool = try #require(game.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    #expect(tool.provenance == .xyzzy)
    #expect(
      game.commander.equipmentInventory?.items.filter { $0.node.key == Equipment.empPirateBlaster }
        .count == 1)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    game.key("return")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let restored = GameRuntime()
    try await restored.load(from: file)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.fittedEquipment(at: .utility(.empPirateBlaster))?.id == tool.id)
    #expect(
      loaded.commander.equipmentInventory?.items.filter {
        $0.node.key == Equipment.empPirateBlaster
      }.count == 1)
    #expect(LaserMount.allCases.allSatisfy { loaded.commander.laser(on: $0) == .naval })
  }
}
