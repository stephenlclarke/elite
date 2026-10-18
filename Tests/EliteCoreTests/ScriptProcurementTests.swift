import Foundation
import Testing

@testable import EliteCore

@Test func procurementActualOriginDockAcceptsNoCargoGrantAndAbandonsOnce() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let runtime = try await fixture.nativeRuntime()
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let before = await runtime.snapshot()
  let offer = try #require(before.commander.contracts.boards[key]?.offers[0])
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let quoteAllowed = quote.allowed
  let quoteIssues = quote.issues.prefix(3).map { String($0.prefix(240)) }.joined(separator: "; ")
  try #require(quoteAllowed, "Procurement quote: \(quoteIssues)")
  let parent = fixture.save.deletingLastPathComponent()
  let backup = fixture.root.appendingPathComponent("before-acceptance")
  try FileManager.default.moveItem(at: parent, to: backup)
  try Data([1]).write(to: parent)
  await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
  let refused = await runtime.snapshot()
  #expect(refused.commander == before.commander)
  try FileManager.default.removeItem(at: parent)
  try FileManager.default.moveItem(at: backup, to: parent)
  let id = try await runtime.confirmContract(quote)
  let accepted = await runtime.snapshot()
  #expect(accepted.nativeMainStationDockEvidenceIsCurrent)
  #expect(accepted.commander.cargo == before.commander.cargo)
  #expect(accepted.commander.credits == before.commander.credits)
  #expect(accepted.commander.scriptState.instances[id]?.timers.isEmpty == true)
  await runtime.key("contacts-open")
  let shown = await runtime.snapshot()
  try #require(shown.scriptPresentedDialogue?.id == "procurement-abandon")
  let backSelected = !shown.scriptConfirmSelected
  try #require(backSelected)
  let shownFiles = try ScriptFinanceTestFixture.files(parent)
  await runtime.key("return")
  let backed = await runtime.snapshot()
  #expect(backed.commander == shown.commander)
  let backedFiles = try ScriptFinanceTestFixture.files(parent)
  #expect(backedFiles == shownFiles)
  await ScriptProcurementFixture.contact(runtime)
  let abandoned = await runtime.snapshot()
  let state = try #require(abandoned.commander.scriptState.instances[id])
  #expect(state.outcome == .abandoned && state.contract?.settlementAmount == 0)
  #expect(state.collections["procurement-goods"]?.lots.isEmpty == true)
  #expect(state.completionReceipt?.cause?.nativeMainDock != nil)
  #expect(abandoned.commander.cargo == before.commander.cargo)
  await ScriptProcurementFixture.contact(runtime)
  let repeated = await runtime.snapshot()
  #expect(repeated.commander == abandoned.commander)
}

@Test func procurementActualMarketTravelAndFinalLotPayOnce() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let runtime = try await fixture.nativeRuntime()
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let generated = await runtime.snapshot()
  let offer = try #require(generated.commander.contracts.boards[key]?.offers[0])
  let plan = try #require(ScriptProcurementPlan.read(offer.parameters))
  let commodity = try #require(plan.commodity).rawValue
  let unrelated = CommodityIdentity.alloys.rawValue
  // No alternate seed/route or injected stock when this fixed market premise fails.
  try #require(
    generated.market[commodity].quantity >= plan.quantity
      && generated.market[unrelated].quantity > 0)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let quoteAllowed = quote.allowed
  let quoteIssues = quote.issues.prefix(3).map { String($0.prefix(240)) }.joined(separator: "; ")
  try #require(quoteAllowed, "Procurement quote: \(quoteIssues)")
  let id = try await runtime.confirmContract(quote)
  await runtime.procurementBuy(unrelated)
  await runtime.procurementBuy(commodity)
  let bought = await runtime.snapshot()
  #expect(bought.commander.cargo[commodity] == 1)
  #expect(
    bought.commander.credits == generated.commander.credits - generated.market[commodity].price
      - generated.market[unrelated].price)
  try await ScriptProcurementFixture.travel(runtime, path: plan.path)
  await runtime.key("contacts-open")
  let review = await runtime.snapshot()
  try #require(review.nativeMainStationDockEvidenceIsCurrent)
  try #require(review.scriptPresentedDialogue?.collectionQuote?.items.first?.quantity == 1)
  await runtime.key("left")
  await runtime.key("return")
  let delivered = await runtime.snapshot()
  let state = try #require(delivered.commander.scriptState.instances[id])
  let collection = try #require(state.collections["procurement-goods"])
  let lot = try #require(collection.lots.values.first)
  #expect(collection.complete && collection.lots.count == 1 && state.outcome == .complete)
  #expect(state.completionReceipt?.sequence == lot.sequence)
  #expect(
    lot.cause.nativeMainDock == lot.committed.nativeMainDock && lot.cause.nativeMainDock != nil)
  #expect(delivered.commander.credits == review.commander.credits + plan.reward)
  #expect(
    delivered.commander.cargo[commodity] == 0 && state.contract?.settlementAmount == plan.reward)
  #expect(delivered.commander.cargo[unrelated] == 1)
  await ScriptProcurementFixture.contact(runtime)
  let repeated = await runtime.snapshot()
  #expect(repeated.commander == delivered.commander)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let restored = await runtime.snapshot()
  #expect(restored.commander.scriptState.instances[id] == state)
}

@Test func procurementActualReloadInvalidatesOldAcceptanceContextWithoutReroll() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let runtime = try await fixture.nativeRuntime()
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let generated = await runtime.snapshot()
  let board = try #require(generated.commander.contracts.boards[key])
  let offer = board.offers[0]
  let stale = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let staleAllowed = stale.allowed
  let staleIssues = stale.issues.prefix(3).map { String($0.prefix(240)) }.joined(separator: "; ")
  try #require(staleAllowed, "Procurement quote: \(staleIssues)")
  try await runtime.save(to: fixture.save)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  await #expect(throws: MissionPackError.self) { try await runtime.confirmContract(stale) }
  let reloaded = await runtime.snapshot()
  #expect(reloaded.commander.contracts.boards[key] == board)
  #expect(reloaded.commander.scriptState.instances.isEmpty)
  let fresh = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let freshAllowed = fresh.allowed
  let freshIssues = fresh.issues.prefix(3).map { String($0.prefix(240)) }.joined(separator: "; ")
  try #require(freshAllowed, "Procurement quote: \(freshIssues)")
  let id = try await runtime.confirmContract(fresh)
  let accepted = await runtime.snapshot()
  #expect(accepted.commander.scriptState.instances[id]?.contract?.offer == offer)
  #expect(accepted.commander.cargo == reloaded.commander.cargo)
}

@Test func procurementActualPartialAndFailedFinalPublicationPreserveEarlierReceipts() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let diagnostic = ScriptProcurementFlightDiagnostic()
  let runtime = try await fixture.nativeRuntime(diagnostic: diagnostic)
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let generated = await runtime.snapshot()
  let offer = try #require(generated.commander.contracts.boards[key]?.offers[1])
  let plan = try #require(ScriptProcurementPlan.read(offer.parameters))
  let commodity = try #require(plan.commodity).rawValue
  try #require(plan.quantity == 5 && generated.market[commodity].quantity > 0)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let quoteAllowed = quote.allowed
  let quoteIssues = quote.issues.prefix(3).map { String($0.prefix(240)) }.joined(separator: "; ")
  try #require(quoteAllowed, "Procurement quote: \(quoteIssues)")
  let id = try await runtime.confirmContract(quote)
  await runtime.procurementBuy(commodity)
  try await ScriptProcurementFixture.travel(runtime, path: plan.path, diagnostic: diagnostic)
  await ScriptProcurementFixture.contact(runtime)
  let partial = await runtime.snapshot()
  let first = try #require(
    partial.commander.scriptState.instances[id]?.collections[plan.template.id])
  #expect(first.delivered(commodity) == 1 && first.lots.count == 1 && !first.complete)
  #expect(partial.commander.scriptState.instances[id]?.contract?.settled == false)
  // Use actual destination stock; insufficient stock is a fixture failure, never injected goods.
  try #require(partial.market[commodity].quantity >= 5)
  for _ in 0..<5 { await runtime.procurementBuy(commodity) }
  await runtime.key("contacts-open")
  await runtime.key("left")
  let before = await runtime.snapshot()
  try #require(before.scriptPresentedDialogue?.collectionQuote?.items.first?.quantity == 4)
  let parent = fixture.save.deletingLastPathComponent()
  let backup = fixture.root.appendingPathComponent("retained-generations")
  try FileManager.default.moveItem(at: parent, to: backup)
  try Data([1]).write(to: parent)
  await runtime.key("return")
  let failed = await runtime.snapshot()
  #expect(
    failed.commander == before.commander
      && failed.scriptPresentedDialogue == before.scriptPresentedDialogue)
  #expect(failed.commander.scriptState.instances[id]?.collections[plan.template.id] == first)
  try FileManager.default.removeItem(at: parent)
  try FileManager.default.moveItem(at: backup, to: parent)
  await runtime.key("return")
  let final = await runtime.snapshot()
  let collected = try #require(
    final.commander.scriptState.instances[id]?.collections[plan.template.id])
  #expect(collected.complete && collected.lots.count == 2)
  for (sequence, receipt) in first.lots { #expect(collected.lots[sequence] == receipt) }
  #expect(final.commander.credits == before.commander.credits + plan.reward)
  #expect(final.commander.cargo[commodity] == 1 && final.commander.valid)
}

@Test func procurementActualTravelExpiryKeepsPartialReceiptsAndOrdinaryProperty() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let runtime = try await fixture.nativeRuntime()
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  let generated = await runtime.snapshot()
  let offer = try #require(generated.commander.contracts.boards[key]?.offers[1])
  let plan = try #require(ScriptProcurementPlan.read(offer.parameters))
  let commodity = try #require(plan.commodity).rawValue
  let unrelated = CommodityIdentity.alloys.rawValue
  // Bound real travel; a missing fixed stock/route premise is an explicit fixture failure.
  try #require(
    plan.quantity == 5 && generated.market[commodity].quantity > 0
      && generated.market[unrelated].quantity > 0
      && plan.calendarLowerBoundSeconds * 64 > plan.duration)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  let quoteAllowed = quote.allowed
  let quoteIssues = quote.issues.prefix(3).map { String($0.prefix(240)) }.joined(separator: "; ")
  try #require(quoteAllowed, "Procurement quote: \(quoteIssues)")
  let id = try await runtime.confirmContract(quote)
  await runtime.procurementBuy(commodity)
  await runtime.procurementBuy(unrelated)
  try await ScriptProcurementFixture.travel(runtime, path: plan.path)
  await ScriptProcurementFixture.contact(runtime)
  let partial = await runtime.snapshot()
  let first = try #require(
    partial.commander.scriptState.instances[id]?.collections[plan.template.id])
  try #require(first.delivered(commodity) == 1 && first.lots.count == 1 && !first.complete)
  let cargo = partial.commander.cargo
  // Each native jump advances its real transit cost. No calendar or location is assigned.
  var journeys = 0
  while journeys < 64 {
    let before = await runtime.snapshot()
    if before.commander.scriptState.instances[id]?.outcome != .active { break }
    await runtime.procurementRefuel()
    let path = journeys.isMultiple(of: 2) ? Array(plan.path.reversed()) : plan.path
    try await ScriptProcurementFixture.travel(runtime, path: path)
    journeys += 1
  }
  let expired = await runtime.snapshot()
  let state = try #require(expired.commander.scriptState.instances[id])
  let job = try #require(state.contract)
  let due = try #require(job.deadline)
  let settled = try #require(job.settledAt)
  #expect(journeys > 0 && journeys <= 64 && state.outcome == .failed && settled > due)
  #expect(
    job.settlementAmount == 0 && state.completionReceipt?.causeKind == "procurement.terminated")
  #expect(state.collections[plan.template.id] == first && expired.commander.cargo == cargo)
  #expect(expired.commander.cargo[unrelated] == 1 && expired.commander.valid)
  let terminal = state
  await ScriptProcurementFixture.contact(runtime)
  let repeated = await runtime.snapshot()
  #expect(repeated.commander.scriptState.instances[id] == terminal)
  try await runtime.save(to: fixture.save)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let restored = await runtime.snapshot()
  #expect(restored.commander.scriptState.instances[id] == terminal)
}
