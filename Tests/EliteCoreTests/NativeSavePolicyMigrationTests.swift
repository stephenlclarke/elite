import Foundation
import Testing

@testable import EliteCore

struct NativeSavePolicyMigrationTests {
  @Test func legacyNativeLoadAndCurrentSaveAddOnlyRequiredPolicyAndCalendar() async throws {
    var original = Commander()
    original.name = "POLICY FIXTURE"
    original.credits = 4567
    original.fuel = 23
    original.missiles = 1
    original.cargo[CommodityIdentity.gold.rawValue] = 4
    try original.prepareEquipment(legacy: false)
    original.mirrorFittedEquipment()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-policy-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let bytes = try JSONEncoder().encode(original)
    try bytes.write(to: file)
    #expect(throws: (any Error).self) {
      try NativeSaveTestFixture.readVersionedCommander(from: file)
    }
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
    expected.scriptState.calendarLedger = .init(origin: .newCommander)
    try await runtime.save(to: file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(saved == expected)
    #expect(await runtime.snapshot().commander == expected)
    #expect(saved.equipmentInventory == original.equipmentInventory)
    #expect(saved.savedSalvageLedger == nil)
    let currentBytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: currentBytes)
    #expect(pointer.schemaVersion == 26)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == expected)
    #expect(try Data(contentsOf: file) == currentBytes)
  }
}
