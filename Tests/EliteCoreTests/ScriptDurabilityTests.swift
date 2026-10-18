import Foundation
import Testing

@testable import EliteCore

struct ScriptDurabilityTests {
  @Test func canonicalInventoryKeepsPredicatePureAndActualSavePinsCurrentPolicy() throws {
    let fixture = try GearScriptFixture()
    defer { fixture.clean() }
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    game.scriptPacks = [fixture.pack]
    let before = game.commander
    for _ in 0..<5 { #expect(!game.requiresScriptDurability) }
    #expect(game.commander == before && game.commander.scriptState.calendarLedger == nil)
    let file = fixture.root.appendingPathComponent("ordinary.json")
    try GameRuntime.writeCommander(&game, to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26)
    var expected = before
    expected.miningLedger = MiningLedger()
    expected.scriptState.calendarLedger = .init(origin: .newCommander)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(saved == expected && game.commander == expected)
    #expect(saved.equipmentInventory == before.equipmentInventory)
    #expect(saved.savedSalvageLedger == nil)
  }

  @Test func emptyHistoricalFormat21PromotesCurrentPolicyWithoutLosingLedgerOrNativeValues()
    async throws
  {
    let fixture = try GearScriptFixture()
    defer { fixture.clean() }
    var historical = Game(executive: false)
    historical.commander.name = "FORMAT21"
    historical.commander.credits = 4567
    historical.commander.fuel = 23
    historical.commander.missiles = 1
    historical.commander.cargo[CommodityIdentity.gold.rawValue] = 4
    historical.ensureScriptCalendar(origin: .newCommander)
    let original = historical.commander
    #expect(original.scriptState.instances.isEmpty && original.contracts.boards.isEmpty)
    #expect(historical.requiresScriptDurability && !original.usesEconomyMiningSaveVersion)
    #expect(original.equipmentInventory == nil && !original.usesModularDriveSaveVersion)
    let file = fixture.root.appendingPathComponent("empty-format21.json")
    // Real pre-drive/pre-policy native header, through the supported historical store.
    try ScriptSaveStore.write(
      commander: original, world: historical.scriptWorldSave, to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 21)
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander.name == original.name && loaded.commander.credits == original.credits)
    #expect(
      loaded.commander.fuel == original.fuel && loaded.commander.missiles == original.missiles)
    #expect(loaded.commander.cargo == original.cargo && loaded.commander.shipID == original.shipID)
    #expect(
      loaded.commander.galaxy == original.galaxy && loaded.commander.system == original.system)
    #expect(loaded.commander.kills == original.kills && loaded.commander.legal == original.legal)
    #expect(loaded.commander.scriptState == original.scriptState)
    #expect(
      loaded.commander.savedSalvageLedger == nil && loaded.commander.equipmentInventory != nil)
    let inventory = try #require(loaded.commander.equipmentInventory)
    let history = try #require(loaded.commander.equipmentPurchaseHistory)
    #expect(history.owner == inventory.owner && history.paid.isEmpty)
    #expect(history.legacy.count == original.missiles)
    #expect(loaded.commander.fittedEquipment(at: .drive)?.provenance == .standard)
    let components = inventory.items.compactMap(\.component)
    #expect(!components.isEmpty && components.allSatisfy { $0.statistics == $0.origin.statistics })
    #expect(try Data(contentsOf: file) == bytes)
    // Canonical migration allocates real stock gear once. Freeze the complete pre-save
    // native value, including those original IDs, before testing current publication.
    var expected = loaded.commander
    // Current publication writes these three stock display mirrors explicitly.
    // Preserve the independent migrated gear identities, policy and native values.
    #expect(expected.equipment == [LaserKind.pulse.equipmentName])
    #expect(expected.laserMounts == LaserMounts(front: .pulse))
    #expect(expected.fuelStorageUnits == 0)
    expected.equipment.insert(HyperspaceDriveTier.basic.label)
    expected.laserMounts = LaserMounts(front: .pulse)
    expected.fuelStorageUnits = 0
    #expect(expected.equipmentInventory == inventory)
    #expect(expected.equipmentPurchaseHistory == history)
    #expect(expected.scriptState == original.scriptState)
    try await runtime.save(to: file)
    let currentBytes = try Data(contentsOf: file)
    let next = try JSONDecoder().decode(ScriptSavePointer.self, from: currentBytes)
    #expect(next.schemaVersion == 26)
    let published = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(published == expected)
    #expect(await runtime.snapshot().commander == expected)
    #expect(expected.scriptState.calendarLedger == original.scriptState.calendarLedger)
    try await runtime.load(from: file, persistMigrations: false)
    #expect(await runtime.snapshot().commander == expected)
    #expect(try Data(contentsOf: file) == currentBytes)
  }

  @Test func ordinaryActorInitAndFlightDoNotCreateOrAdvanceScriptClocks() async throws {
    let runtime = GameRuntime(game: Game(executive: false))
    #expect(await runtime.snapshot().commander.scriptState == ScriptEngineState())
    await runtime.key("0")
    for _ in 0..<5 { _ = await runtime.advance(delta: 0.1) }
    let after = await runtime.snapshot()
    #expect(after.commander.scriptState == ScriptEngineState())
  }

  @Test func actualNondefaultScriptAndAccommodationStateTriggerThePurePredicate() throws {
    var game = Game(executive: false)
    #expect(!game.requiresScriptDurability)
    game.commander.scriptState.calendarSeconds = 1
    let before = game.commander
    #expect(game.requiresScriptDurability && game.commander == before)
    game.commander.scriptState = ScriptEngineState()
    let berth = PassengerBerth(id: UUID(uuidString: "61000000-0000-0000-0000-000000000001")!)
    game.commander.accommodation.ownedBerths = [berth]
    #expect(game.requiresScriptDurability && game.commander.scriptState.calendarLedger == nil)
  }
}
