import Foundation
import Testing

@testable import L337Core

struct NativeSavePolicyMigrationTests {
  @Test func supportedFormat25PromotesOnlyMiningPolicyAndPreservesCalendarAndNativeValues()
    async throws
  {
    var original = Commander()
    original.name = "POLICY FIXTURE"
    original.credits = 4567
    original.fuel = 23
    original.missiles = 1
    original.cargo[CommodityIdentity.gold.rawValue] = 4
    try original.prepareEquipment(legacy: false)
    original.mirrorFittedEquipment()
    original.scriptState.calendarLedger = .init(origin: .newCommander)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-policy-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let rawFile = directory.appendingPathComponent("unsupported-current-raw.json")
    try JSONEncoder().encode(original).write(to: rawFile)
    let rawRuntime = GameRuntime(game: Game(executive: false))
    await #expect(throws: SaveError.self) {
      try await rawRuntime.load(from: rawFile, persistMigrations: false)
    }
    var historical = Game(executive: false)
    historical.commander = original
    historical.energy = original.performance.energy
    historical.frontShield = original.shieldCapacity
    historical.rearShield = original.rearShieldCapacity
    try ScriptSaveStore.write(commander: original, world: historical.scriptWorldSave, to: file)
    let bytes = try Data(contentsOf: file)
    let oldPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(oldPointer.schemaVersion == 25)
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: file) == original)
    // Independently establish the required legacy-origin policy from the fixed source system.
    var expected = original
    var legacyPolicy = MiningLedger.legacyUnworked()
    let system = Universe.systemsIncludingPlugh(number: original.galaxy)[original.system]
    try legacyPolicy.migratePresence(
      current: .init(system: system, galaxy: original.galaxy), historical: [])
    expected.miningLedger = legacyPolicy
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == expected)
    #expect(try Data(contentsOf: file) == bytes)
    #expect(loaded.commander.savedSalvageLedger == nil)
    try await runtime.save(to: file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(saved == expected)
    #expect(await runtime.snapshot().commander == expected)
    #expect(saved.equipmentInventory == original.equipmentInventory)
    #expect(saved.scriptState.calendarLedger == original.scriptState.calendarLedger)
    #expect(saved.savedSalvageLedger == nil)
    let currentBytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: currentBytes)
    #expect(pointer.schemaVersion == 26)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == expected)
    #expect(try Data(contentsOf: file) == currentBytes)
  }
}
