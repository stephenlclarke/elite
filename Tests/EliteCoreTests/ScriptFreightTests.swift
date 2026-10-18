import Foundation
import Testing

@testable import EliteCore

@Test(arguments: [0, 1, 2])
func freightRealIssuerSuppliesExactUnitsForFreeAndBackPreservesFiles(row: Int) async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let runtime = try await fixture.nativeRuntime()
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let before = await runtime.snapshot()
  let offer = try #require(before.commander.contracts.boards[key]?.offers[row])
  let plan = try #require(offer.freightPlan)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let allowed = quote.allowed
  try #require(allowed)
  let parent = fixture.save.deletingLastPathComponent()
  let preserved = fixture.root.appendingPathComponent("preserved-issue")
  try FileManager.default.moveItem(at: parent, to: preserved)
  try Data([1]).write(to: parent)
  await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
  let refused = await runtime.snapshot()
  #expect(refused.commander == before.commander)
  try FileManager.default.removeItem(at: parent)
  try FileManager.default.moveItem(at: preserved, to: parent)
  let id = try await runtime.confirmContract(quote)
  let accepted = await runtime.snapshot()
  let state = try #require(accepted.commander.scriptState.instances[id])
  let cargo = try #require(state.savedOwnedCargo)
  #expect(
    accepted.commander.cargo == before.commander.cargo
      && accepted.commander.credits == before.commander.credits)
  #expect(cargo.held.count == plan.quantity && Set(cargo.held).count == plan.quantity)
  #expect(cargo.issue.context.nativeMainDock == before.commander.nativeStations?.currentMainDock)
  #expect(accepted.commander.cargoTonnes == before.commander.cargoTonnes + plan.quantity)
  #expect(accepted.commander.freightCargoValid)
  let repeatedID = try await runtime.confirmContract(quote)
  let repeated = await runtime.snapshot()
  #expect(repeatedID == id && repeated.commander == accepted.commander)
  await runtime.key("contacts-open")
  let shown = await runtime.snapshot()
  try #require(shown.scriptPresentedDialogue?.id == "freight-abandon")
  try #require(!shown.scriptConfirmSelected)
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  await runtime.key("return")
  let backed = await runtime.snapshot()
  let afterFiles = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  #expect(backed.commander == shown.commander && files == afterFiles)
  await runtime.key("contacts-open")
  try await ScriptFreightFixture.confirm(runtime)
  let terminal = await runtime.snapshot()
  let abandoned = try #require(terminal.commander.scriptState.instances[id])
  #expect(abandoned.outcome == .abandoned && abandoned.contract?.settlementAmount == 0)
  #expect(abandoned.savedOwnedCargo?.terminal?.removed == cargo.held)
  #expect(
    terminal.commander.cargo == before.commander.cargo
      && terminal.commander.cargoTonnes == before.commander.cargoTonnes)
}

@Test(arguments: [0, 2])
func freightActualAllRemainingPaysFrozenTierReward(row: Int) async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, plan) = try await fixture.accepted(row: row)
  let accepted = await runtime.snapshot()
  try await ScriptProcurementFixture.travel(runtime, path: plan.path)
  await runtime.key("contacts-open")
  try await ScriptFreightFixture.confirm(runtime, all: true)
  let delivered = await runtime.snapshot()
  let state = try #require(delivered.commander.scriptState.instances[id])
  #expect(state.outcome == .complete && state.savedOwnedCargo?.held.isEmpty == true)
  #expect(state.collections[plan.template.id]?.lots.count == 1)
  #expect(state.savedOwnedCargo?.transfers.values.first?.units.count == plan.quantity)
  #expect(state.contract?.settlementAmount == plan.reward)
  #expect(delivered.commander.cargo == accepted.commander.cargo)
}

@Test func freightRealPartialChoiceAndFailedFinalWriterPreserveUnitsAndPayOnce() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, plan) = try await fixture.accepted(row: 1)
  let accepted = await runtime.snapshot()
  let commodity = try #require(plan.commodity)
  try #require(accepted.market[commodity.rawValue].quantity > 0)
  await runtime.procurementBuy(commodity.rawValue)
  let bought = await runtime.snapshot()
  try await ScriptProcurementFixture.travel(runtime, path: plan.path)
  await runtime.key("contacts-open")
  let shown = await runtime.snapshot()
  try #require(shown.nativeMainStationDockEvidenceIsCurrent)
  try #require(shown.selectedScriptChoice?.id == "freight-one")
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  await runtime.key("down")
  let browsed = await runtime.snapshot()
  let browsedFiles = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  #expect(browsed.commander == shown.commander && files == browsedFiles)
  await runtime.key("up")
  try await ScriptFreightFixture.confirm(runtime)
  let partial = await runtime.snapshot()
  let first = try #require(partial.commander.scriptState.instances[id])
  #expect(
    first.savedOwnedCargo?.held.count == 4 && first.collections[plan.template.id]?.lots.count == 1)
  #expect(
    partial.commander.credits == bought.commander.credits
      && partial.commander.cargo == bought.commander.cargo)
  let priorLots = try #require(first.collections[plan.template.id]?.lots)
  let parent = fixture.save.deletingLastPathComponent()
  let preserved = fixture.root.appendingPathComponent("preserved-final")
  try FileManager.default.moveItem(at: parent, to: preserved)
  try Data([1]).write(to: parent)
  try await ScriptFreightFixture.confirm(runtime, all: true)
  let refused = await runtime.snapshot()
  #expect(refused.commander == partial.commander)
  try FileManager.default.removeItem(at: parent)
  try FileManager.default.moveItem(at: preserved, to: parent)
  // Selection is presentation-only; restore the actual declared all-remaining choice.
  let retryShown = await runtime.snapshot()
  if retryShown.selectedScriptChoice?.id != "freight-all" { await runtime.key("down") }
  if !retryShown.scriptConfirmSelected { await runtime.key("left") }
  await runtime.key("return")
  let complete = await runtime.snapshot()
  let final = try #require(complete.commander.scriptState.instances[id])
  #expect(final.outcome == .complete && final.savedOwnedCargo?.held.isEmpty == true)
  #expect(
    final.contract?.settlementAmount == plan.reward
      && complete.commander.credits == partial.commander.credits + plan.reward)
  #expect(complete.commander.cargo == bought.commander.cargo)
  #expect(priorLots.allSatisfy { final.collections[plan.template.id]?.lots[$0.key] == $0.value })
  #expect(final.savedOwnedCargo?.transfers.values.reduce(0, { $0 + $1.units.count }) == 5)
  await runtime.key("contacts-open")
  await runtime.key("left")
  await runtime.key("return")
  let repeated = await runtime.snapshot()
  #expect(repeated.commander == complete.commander)
  try await runtime.save(to: fixture.save)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let loaded = await runtime.snapshot()
  #expect(loaded.commander.scriptState.instances[id]?.savedOwnedCargo == final.savedOwnedCargo)
  #expect(loaded.commander.scriptState.instances[id]?.collections == final.collections)
  #expect(loaded.commander.credits == complete.commander.credits)
}

@Test func freightRealTravelExpiryKeepsEarlierDeliveryAndOrdinaryGoods() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, plan) = try await fixture.accepted(row: 1)
  let accepted = await runtime.snapshot()
  let commodity = try #require(plan.commodity)
  try #require(accepted.market[commodity.rawValue].quantity > 0)
  await runtime.procurementBuy(commodity.rawValue)
  try await ScriptProcurementFixture.travel(runtime, path: plan.path)
  await runtime.key("contacts-open")
  try await ScriptFreightFixture.confirm(runtime)
  await runtime.key("return")  // Genuine default Back closes the repeat contact.
  let partial = await runtime.snapshot()
  let earlier = try #require(
    partial.commander.scriptState.instances[id]?.collections[plan.template.id]?.lots)
  var path = Array(plan.path.reversed())
  for _ in 0..<6 {
    let current = await runtime.snapshot()
    if current.commander.scriptState.instances[id]?.outcome != .active { break }
    try await ScriptProcurementFixture.travel(runtime, path: path)
    path.reverse()
  }
  let expired = await runtime.snapshot()
  let state = try #require(expired.commander.scriptState.instances[id])
  #expect(state.outcome == .failed && state.savedOwnedCargo?.terminal?.cause == .expired)
  #expect(
    state.contract?.settlementAmount == 0 && state.savedOwnedCargo?.terminal?.removed.count == 4)
  #expect(
    state.collections[plan.template.id]?.lots == earlier
      && expired.commander.cargo == partial.commander.cargo)
}
