import Foundation
import Testing

@testable import EliteCore

struct ScriptDurabilityTests {
  @Test func ordinaryCanonicalInventoryAndInstalledCatalogueDoNotPromoteNativeJSON() throws {
    let fixture = try GearScriptFixture()
    defer { fixture.clean() }
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.scriptPacks = [fixture.pack]
    let before = game.commander
    for _ in 0..<5 { #expect(!game.requiresScriptDurability) }
    #expect(game.commander == before && game.commander.scriptState.calendarLedger == nil)
    let file = fixture.root.appendingPathComponent("ordinary.json")
    try GameRuntime.writeCommander(&game, to: file)
    let bytes = try Data(contentsOf: file)
    let rawRoot = try JSONSerialization.jsonObject(with: bytes)
    let root = try #require(rawRoot as? [String: Any])
    #expect(root["format"] == nil)
    let saved = try JSONDecoder().decode(Commander.self, from: bytes)
    #expect(saved.scriptState == ScriptEngineState() && saved.equipmentInventory != nil)
  }

  @Test func emptyLoadedFormat21RetainsItsLedgerAndContainerOnTheNextSave() async throws {
    let fixture = try GearScriptFixture()
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.ensureScriptCalendar(origin: .newCommander)
    #expect(game.commander.scriptState.instances.isEmpty && game.commander.contracts.boards.isEmpty)
    #expect(game.requiresScriptDurability)
    let file = fixture.root.appendingPathComponent("empty-format21.json")
    try GameRuntime.writeCommander(&game, to: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    #expect(pointer.schemaVersion == 21)
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.load(from: file)
    let before = await runtime.snapshot()
    #expect(before.commander.scriptState.instances.isEmpty)
    #expect(
      before.commander.scriptState.calendarLedger == game.commander.scriptState.calendarLedger)
    try await runtime.save(to: file)
    let next = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    #expect(next.schemaVersion == 21)
    #expect(
      await runtime.snapshot().commander.scriptState.calendarLedger
        == before.commander.scriptState.calendarLedger)
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
