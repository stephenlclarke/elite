import Foundation
import Testing

@testable import EliteCore

/// Authenticated current restore for bodyless fixtures whose only publication change is mining storage.
enum CurrentBodylessSaveTestFixture {
  private static func worldObject(_ world: ScriptWorldSave) throws -> NSDictionary {
    let bytes = try ScriptValueStorage.encoder().encode(world)
    return try #require(JSONSerialization.jsonObject(with: bytes) as? NSDictionary)
  }

  static func restore(_ original: Game) async throws -> Game {
    try #require(original.bodies.isEmpty && original.commander.npcPersistence.count == 0)
    try #require(
      original.commander.savedEMPState == nil && original.commander.alienStorageState == nil)
    try #require(original.commander.scriptState.instances.isEmpty)
    try #require(original.commander.contracts.boards.isEmpty && original.jumpCountdown == nil)
    try #require(original.screen == .status || original.screen.isFlight)
    try #require(original.commander.savedEquipmentVersion == 3 && original.requiresScriptDurability)
    // Current ownership cannot be admitted through the historical raw-Commander route.
    var raw = original
    let acceptedRaw = raw.load(original.commander)
    #expect(!acceptedRaw && raw.commander == original.commander)
    let expectedWorld = try worldObject(original.scriptWorldSave)
    #expect(try worldObject(raw.scriptWorldSave).isEqual(expectedWorld))
    #expect(raw.dischargeAudio.epoch == original.dischargeAudio.epoch)
    #expect(raw.dischargeAudio.events == original.dischargeAudio.events)

    // Derive expectations before the actual writer, without taking them from published or loaded output.
    var expected = original.commander
    try expected.prepareEquipment()
    expected.mirrorFittedEquipment()
    try #require(expected == original.commander)
    if expected.scriptState.calendarLedger == nil {
      expected.scriptState.calendarLedger = .init(origin: .newCommander)
    }
    let runtime = GameRuntime(game: original)
    let initialized = await runtime.snapshot()
    try #require(initialized.commander == expected)
    var mining = expected.miningLedgerForMigration(legacyMissing: false)
    try #require(mining.requiredPresencePinSystems.isEmpty)
    let system = Universe.systemsIncludingPlugh(number: expected.galaxy)[expected.system]
    try mining.migratePresence(
      current: .init(system: system, galaxy: expected.galaxy), historical: [])
    expected.miningLedger = mining
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    try await runtime.save(to: file)
    let published = await runtime.snapshot()
    try #require(published.commander == expected)
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
    try #require(stored == expected && world.valid && world.consistent(with: stored))
    #expect(try worldObject(world).isEqual(expectedWorld))
    let paths = Set(try FileManager.default.subpathsOfDirectory(atPath: directory.path))
    let files = try ScriptFinanceTestFixture.files(directory)
    try await runtime.load(from: file, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(restored.commander == expected)
    #expect(try worldObject(restored.scriptWorldSave).isEqual(expectedWorld))
    #expect(Set(try FileManager.default.subpathsOfDirectory(atPath: directory.path)) == paths)
    #expect(try ScriptFinanceTestFixture.files(directory) == files)
    return restored
  }
}
