import Foundation
import Testing

@testable import L337Core

@Test(arguments: [
  "unit", "owner", "issuer", "schema", "duplicate", "missing", "missing-custody", "mirror",
  "future-visit",
])
func freightAuthenticIssueRejectsForgedCustodyWithoutRepair(field: String) async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, _) = try await fixture.accepted(row: 1)
  let game = await runtime.snapshot()
  var changed = try ScriptFreightFixture.forgedCargo(game, id: id) { cargo in
    switch field {
    case "unit": cargo["held"] = [UUID().uuidString]
    case "owner": cargo["owner"] = UUID().uuidString
    case "issuer": cargo["issuer"] = ["galaxy": 0, "system": 1, "stationClass": "main-orbital"]
    case "schema": cargo["schema"] = 2
    case "duplicate":
      let units = cargo["issued"] as! [String]
      cargo["issued"] = Array(repeating: units[0], count: units.count)
    case "missing": cargo["held"] = []
    case "future-visit":
      var issue = cargo["issue"] as! [String: Any]
      var context = issue["context"] as! [String: Any]
      var dock = context["nativeMainDock"] as! [String: Any]
      var actor = dock["actor"] as! [String: Any]
      actor["visit"] = (actor["visit"] as! NSNumber).uint64Value + 1
      dock["actor"] = actor
      context["nativeMainDock"] = dock
      issue["context"] = context
      cargo["issue"] = issue
    default: break
    }
  }
  if field == "missing-custody" { changed.scriptState.instances[id]?.savedOwnedCargo = nil }
  if field == "mirror" {
    var state = try #require(changed.scriptState.instances[id])
    state.payloads[ScriptOwnedCargoState.payloadKey] = 6
    changed.scriptState.instances[id] = state
  }
  try await fixture.rejectForgedState(changed, genuine: game, runtime: runtime)
}

@Test func freightCannotBeSoldOrManufacturedAndCompatibleHullKeepsUnitIdentities() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, plan) = try await fixture.accepted(row: 2)
  let game = await runtime.snapshot()
  let original = try #require(game.commander.scriptState.instances[id]?.savedOwnedCargo)
  let commodity = try #require(plan.commodity)
  #expect(game.commander.sellableCargo(commodity.rawValue) == 0)
  var traded = game
  traded.screen = .market
  traded.selection = commodity.rawValue
  traded.trade(buy: false)
  #expect(traded.commander == game.commander)
  var state = try #require(game.commander.scriptState.instances[id])
  var candidate = game.commander
  let event = ScriptEvent(
    sequence: candidate.scriptState.nextEvent, kind: "mission.accepted",
    instance: id, values: [:], context: game.scriptEventContext(state))
  #expect(throws: MissionPackError.self) {
    try game.applyScriptCommand(
      .object([
        "op": .string("payload.add"), "id": .string("fake"),
        "key": .string(ScriptOwnedCargoState.payloadKey), "amount": .integer(1),
      ]),
      event: event, pack: fixture.pack, state: &state, candidate: &candidate)
  }
  state.milestones = [0]
  #expect(throws: MissionPackError.self) {
    try game.finishScriptMission(
      .complete, pack: fixture.pack, state: &state, candidate: &candidate)
  }
  #expect(candidate == game.commander && state.outcome == .active)
  var transferred = game.commander
  let fuel = transferred.fuel
  let missiles = transferred.missiles
  let ship = transferred.shipID
  try transferred.transferEquipment(to: ship, hullID: UUID())
  #expect(transferred.scriptState.instances[id]?.savedOwnedCargo == original)
  #expect(
    transferred.cargoTonnes == game.commander.cargoTonnes && transferred.fuel == fuel
      && transferred.missiles == missiles)
  var small = game
  small.commander.unlimitedCargo = true
  small.showroom.selection = "SH038"
  let selected = try #require(small.showroomShip)
  let profile = try #require(selected.game)
  let hold = profile.cargo
  try #require(selected.catalogue.playerFlyable && selected.catalogue.normalPurchaseEligible)
  try #require(hold == 2 && profile.cargoExpansion == 0 && hold < plan.quantity)
  try #require(!small.commander.equipment.contains("Large Cargo Bay"))
  let quote = try #require(small.shipTradeQuote)
  #expect(!quote.allowed && quote.issues.contains { $0.contains("issuer-owned freight") })
  #expect(throws: EquipmentRuntimeError.self) {
    try small.commander.transferEquipment(to: "SH038", hullID: UUID())
  }
  #expect(small.commander.scriptState.instances[id]?.savedOwnedCargo == original)
}

@Test func freightActualEscapeRemovesOnlyOutstandingOwnedUnits() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, plan) = try await fixture.accepted(row: 1, escapeReady: true)
  try await ScriptProcurementFixture.travel(runtime, path: plan.path)
  await runtime.key("contacts-open")
  try await ScriptFreightFixture.confirm(runtime)
  await runtime.key("return")
  let partial = await runtime.snapshot()
  let earlier = try #require(
    partial.commander.scriptState.instances[id]?.collections[plan.template.id]?.lots)
  await runtime.key("0")
  let launched = await runtime.snapshot()
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.blockWrites("escape")
  await runtime.key("escape-pod")
  let refused = await runtime.snapshot()
  #expect(refused.commander == launched.commander && refused.docked == launched.docked)
  try fixture.restoreWrites(preserved, files: files)
  await runtime.key("escape-pod")
  let escaped = await runtime.snapshot()
  let state = try #require(escaped.commander.scriptState.instances[id])
  #expect(state.outcome == .failed && state.savedOwnedCargo?.terminal?.cause == .escapePod)
  #expect(
    state.savedOwnedCargo?.terminal?.removed.count == 4
      && state.payloads[ScriptOwnedCargoState.payloadKey] == 0)
  #expect(
    state.collections[plan.template.id]?.lots == earlier && state.contract?.settlementAmount == 0)
}

@Test func freightActualFatalTransitionRetainsPendingLossAcrossWriterRefusal() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, _) = try await fixture.accepted(row: 1)
  await runtime.key("0")
  let before = await runtime.snapshot()
  try #require(!before.docked && before.screen.isFlight)
  let units = try #require(before.commander.scriptState.instances[id]?.savedOwnedCargo?.held)
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.blockWrites("fatal")
  try await runtime.freightFatalHit()
  _ = await runtime.advance(delta: 0.1)
  let dead = await runtime.snapshot()
  let pending = try #require(dead.commander.scriptState.instances[id]?.savedOwnedCargo?.pendingLoss)
  #expect(dead.screen == .gameOver && pending.units == units)
  #expect(dead.commander.scriptState.instances[id]?.savedOwnedCargo?.held == units)
  try fixture.restoreWrites(preserved, files: files)
  _ = await runtime.advance(delta: 0.1)
  let settled = await runtime.snapshot()
  let state = try #require(settled.commander.scriptState.instances[id])
  #expect(state.outcome == .failed && state.savedOwnedCargo?.terminal?.cause == .shipDestroyed)
  #expect(
    state.savedOwnedCargo?.terminal?.removed == units && state.savedOwnedCargo?.pendingLoss == nil)
  #expect(
    state.completionReceipt?.cause == pending.context && state.contract?.settlementAmount == 0)
}
