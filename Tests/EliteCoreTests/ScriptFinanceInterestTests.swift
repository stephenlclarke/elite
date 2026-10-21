import Foundation
import Testing

@testable import EliteCore

private func interestFixture(edits: [(String, String)] = []) throws -> ScriptFinanceTestFixture {
  try ScriptFinanceTestFixture(edits: edits, example: "finance-interest")
}

private func interestTerms(
  principal: Int = 2000, rate: Int = 1000, period: Int = 100,
  rounding: ScriptFinanceInterest.Rounding = .up, cap: Int = 1000
) -> ScriptFinanceDefinition {
  .init(
    id: "loan", profile: "simple-interest-v1", creditor: "example.lender", title: "Loan",
    principal: principal, galaxy: 0, system: 237,
    interest: .init(
      rateBasisPoints: rate, periodSeconds: period, rounding: rounding, maximumInterest: cap))
}

struct ScriptFinanceInterestTests {
  @Test func explicitNativeDeclineNeverCreatesInterestOrPrincipal() async throws {
    let fixture = try interestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let cash = await runtime.snapshot().commander.credits
    try await ScriptFinanceTestFixture.confirm(runtime, decline: true)
    let game = await runtime.snapshot()
    let record = try #require(game.commander.scriptState.financeLedger?.records.first)
    #expect(record.status == .declined && record.receipts.count == 1)
    #expect(record.balance(at: 1e12) == .zero && game.commander.credits == cash)
  }

  @Test func periodBoundaryRoundingAndHugeCatchupRespectTheDeclaredLifetimeCap() throws {
    let terms = interestTerms()
    let initial = ScriptFinanceBalance(
      principal: 2000, interest: 0, assessedInterest: 0, completedPeriods: 0)
    #expect(initial.accruing(terms: terms, borrowedAt: 10, at: 109.999)?.total == 2000)
    #expect(initial.accruing(terms: terms, borrowedAt: 10, at: 110)?.total == 2200)
    #expect(initial.accruing(terms: terms, borrowedAt: 10, at: 210)?.total == 2400)
    // This is an analytic catch-up, not a trillion-iteration test or an offline-time simulation.
    let huge = try #require(initial.accruing(terms: terms, borrowedAt: 10, at: 1e12))
    #expect(huge.total == 3000 && huge.assessedInterest == 1000)
    let tiny = ScriptFinanceBalance(
      principal: 10, interest: 0, assessedInterest: 0, completedPeriods: 0)
    #expect(
      tiny.accruing(terms: interestTerms(principal: 10, rate: 1), borrowedAt: 0, at: 100)?.interest
        == 1)
    #expect(
      tiny.accruing(
        terms: interestTerms(principal: 10, rate: 1, rounding: .down), borrowedAt: 0, at: 100
      )?.interest == 0)
    #expect(initial.accruing(terms: terms, borrowedAt: 10, at: 9) == nil)
    #expect(initial.accruing(terms: terms, borrowedAt: 10, at: .infinity) == nil)
    #expect(ScriptFinanceBalance.zero.accruing(terms: terms, borrowedAt: 10, at: 1e12) == .zero)
    let maximum = ScriptFinanceBalance(
      principal: 4_294_967_294, interest: 0, assessedInterest: 0, completedPeriods: 0)
    #expect(
      maximum.accruing(
        terms: interestTerms(principal: 4_294_967_294, rate: 10000, period: 1, cap: 1),
        borrowedAt: 0, at: 1e12)?.total == 4_294_967_295)
    #expect(!interestTerms(principal: 4_294_967_294, cap: 2).valid)
    let invalid = ScriptFinanceBalance(
      principal: 2000, interest: Int.max, assessedInterest: Int.max, completedPeriods: 0)
    #expect(invalid.accruing(terms: terms, borrowedAt: 0, at: 100) == nil)
  }

  @Test(arguments: [
    "rate", "period", "rounding", "cap", "profile", "capability", "calendar", "missing", "unknown",
  ])
  func manifestRejectsUnsupportedOrHiddenInterestTerms(field: String) throws {
    let edit: (String, String)
    switch field {
    case "rate": edit = ("rateBasisPoints = 1000", "rateBasisPoints = -1")
    case "period": edit = ("periodSeconds = 86400", "periodSeconds = 0")
    case "rounding": edit = ("rounding = \"up\"", "rounding = \"nearest\"")
    case "cap": edit = ("maximumInterest = 1000", "maximumInterest = 4294967295")
    case "profile": edit = ("simple-interest-v1", "fixed-principal-v1")
    case "capability": edit = ("\"finance-interest-simple-v2\", ", "")
    case "calendar": edit = ("\"mission-calendar-v2\", ", "")
    case "missing": edit = ("periodSeconds = 86400\n", "")
    default: edit = ("maximumInterest = 1000", "maximumInterest = 1000\ncompound = true")
    }
    #expect(throws: (any Error).self) { try interestFixture(edits: [edit]) }
  }

  @Test func partialPaymentPaysInterestFirstWithoutResettingPeriodsOrCompounding() async throws {
    let fixture = try interestFixture(edits: [("periodSeconds = 86400", "periodSeconds = 100")])
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    let game = await runtime.snapshot()
    let ledger = try #require(game.commander.scriptState.financeLedger)
    let record = try #require(ledger.records.first)
    let dock = try #require(game.commander.nativeStations?.currentMainDock)
    let borrowedAt = try #require(record.receipts.first?.calendarSeconds)
    // Explicit arithmetic boundary: cash changes between receipts represent ordinary outside income/spending.
    let partial = try ledger.applying(
      .repay, to: record.id, token: UUID(), cash: 700, dock: dock,
      calendarSeconds: borrowedAt + 150, epoch: game.nativeStationRuntimeEpoch)
    #expect(partial.receipt.interestAdded == 200 && partial.receipt.afterInterest == 0)
    #expect(partial.receipt.afterPrincipal == 1500 && partial.receipt.completedPeriods == 1)
    let remaining = try #require(partial.ledger.records.first)
    #expect(remaining.balance(at: borrowedAt + 199.999)?.total == 1500)
    #expect(remaining.balance(at: borrowedAt + 200)?.total == 1650)
    let paid = try partial.ledger.applying(
      .repay, to: record.id, token: UUID(), cash: 1650, dock: dock,
      calendarSeconds: borrowedAt + 200, epoch: game.nativeStationRuntimeEpoch)
    #expect(paid.cash == 0 && paid.receipt.interestAdded == 150)
    #expect(paid.ledger.records[0].status == .paid && paid.ledger.records[0].remaining == 0)
    #expect(paid.ledger.records[0].balance(at: 1e12)?.total == 0)
    #expect(throws: (any Error).self) {
      try paid.ledger.applying(
        .borrow, to: record.id, token: UUID(), cash: 0, dock: dock,
        calendarSeconds: borrowedAt + 300, epoch: game.nativeStationRuntimeEpoch)
    }
    #expect(throws: (any Error).self) {
      try partial.ledger.applying(
        .repay, to: record.id, token: partial.receipt.token, cash: 500, dock: dock,
        calendarSeconds: borrowedAt + 200, epoch: game.nativeStationRuntimeEpoch)
    }
  }

  @Test func unpaidInterestIsNotCapitalizedAndLifetimeCapNeverResetsOnRepayment() async throws {
    let fixture = try interestFixture(edits: [("periodSeconds = 86400", "periodSeconds = 100")])
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    let game = await runtime.snapshot()
    let ledger = try #require(game.commander.scriptState.financeLedger)
    let record = try #require(ledger.records.first)
    let dock = try #require(game.commander.nativeStations?.currentMainDock)
    let start = try #require(record.receipts.first?.calendarSeconds)
    let short = try ledger.applying(
      .repay, to: record.id, token: UUID(), cash: 50, dock: dock,
      calendarSeconds: start + 100, epoch: game.nativeStationRuntimeEpoch)
    #expect(short.receipt.afterPrincipal == 2000 && short.receipt.afterInterest == 150)
    #expect(short.ledger.records[0].balance(at: start + 200)?.interest == 350)
    let capped = try #require(short.ledger.records[0].balance(at: 1e12))
    #expect(capped.assessedInterest == 1000 && capped.interest == 950 && capped.total == 2950)
    #expect(throws: (any Error).self) {
      try short.ledger.applying(
        .repay, to: record.id, token: UUID(), cash: 0, dock: dock,
        calendarSeconds: start + 200, epoch: game.nativeStationRuntimeEpoch)
    }
  }

  @Test func nativeQuoteRejectsAccrualChangeWhileReadsRemainPureAndFreeOffersStayFree() async throws
  {
    let fixture = try interestFixture(edits: [("periodSeconds = 86400", "periodSeconds = 100")])
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let offered = await runtime.snapshot()
    let offer = try #require(offered.commander.scriptState.financeLedger?.records.first)
    #expect(offer.balance(at: 1e12)?.total == 0)
    try await ScriptFinanceTestFixture.confirm(runtime)
    _ = try await ScriptFinanceTestFixture.review(runtime)
    var game = await runtime.snapshot()
    let quote = try #require(game.contractBoard.financeQuote)
    let record = try #require(game.commander.scriptState.financeLedger?.records.first)
    let start = try #require(record.receipts.first?.calendarSeconds)
    // Controlled calendar-boundary fixture; actual native jump/calendar integration is tested separately.
    game.commander.scriptState.calendarSeconds = start + 100
    try #require(game.commander.valid)
    #expect(quote.resources == game.commander.contractQuoteResources)
    #expect(quote.epoch == game.nativeStationRuntimeEpoch)
    let arrival = try #require(quote.context)
    #expect(game.acceptsNativeMainStationArrivalContext(arrival))
    let before = game.commander
    let parent = try #require(game.commander.scriptState.instances[record.source.instance])
    let query = game.financeQuery(parent)
    #expect(query.object?["workshop"]?.object?["remaining"] == .integer(2200))
    #expect(game.financeDetail.contains { $0.contains("Refresh this review") })
    #expect(game.financeDetail.contains { $0.contains("10.00%") })
    _ = game.financeRows
    _ = Display.contractBoard(game, width: 768, height: 768)
    #expect(game.commander == before)
    #expect(throws: (any Error).self) { try game.confirmFinance(quote) }
    #expect(game.commander == before)
    let free = ScriptFinanceDefinition(
      id: "free", profile: "fixed-principal-v1", creditor: "example.free", title: "Free",
      principal: 2000, galaxy: 0, system: 237)
    let original = ScriptFinanceBalance(
      principal: 2000, interest: 0, assessedInterest: 0, completedPeriods: 0)
    #expect(original.accruing(terms: free, borrowedAt: 0, at: 1e12) == original)
  }

  @Test func accruedNativeRepaymentWriterFailureRollsBackWholeStateAndFilesThenPaysOnce()
    async throws
  {
    let fixture = try interestFixture(edits: [("periodSeconds = 86400", "periodSeconds = 100")])
    defer { fixture.storage.clean() }
    let borrowed = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(borrowed)
    var game = await borrowed.snapshot()
    let start = try #require(
      game.commander.scriptState.financeLedger?.records.first?.receipts.first?.calendarSeconds)
    game.commander.scriptState.calendarSeconds = start + 100
    let runtime = GameRuntime(game: game, saveURL: fixture.storage.url)
    let page = try await ScriptFinanceTestFixture.review(runtime)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    try fixture.storage.blockWriter()
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.backup) == files)
    try fixture.storage.restoreWriter()
    await runtime.scriptPageKey("return", expected: page)
    let paid = await runtime.snapshot().commander
    #expect(paid.credits == before.credits - 2200)
    #expect(paid.scriptState.financeLedger?.records.first?.status == .paid)
    #expect(paid.scriptState.financeLedger?.records.first?.receipts.last?.interestAdded == 200)
    let settled = paid.scriptState.financeLedger
    try await ScriptFinanceTestFixture.confirm(runtime)
    #expect(await runtime.snapshot().commander.credits == paid.credits)
    #expect(await runtime.snapshot().commander.scriptState.financeLedger == settled)
  }

  @Test func terminalParentCurrentFormatAndReceiptForgeryKeepAcceptedTermsAndAccrual() async throws
  {
    let fixture = try interestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    await runtime.key("contacts-open")
    #expect(
      await runtime.snapshot().commander.scriptState.instances.values.first?.outcome == .complete)
    var game = await runtime.snapshot()
    let ledger = try #require(game.commander.scriptState.financeLedger)
    game.scriptPacks = []
    let writer = GameRuntime(game: game, saveURL: fixture.storage.url)
    try await writer.save(to: fixture.storage.url)
    let reader = GameRuntime()
    try await reader.load(from: fixture.storage.url, persistMigrations: false)
    let restored = await reader.snapshot()
    #expect(restored.commander.scriptState.financeLedger == ledger)
    let record = try #require(ledger.records.first)
    #expect(
      restored.commander.scriptState.financeLedger?.records.first?.balance(at: 1e12)?.total == 3000)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
    var records = try #require(object["records"] as? [[String: Any]])
    var receipts = try #require(records[0]["receipts"] as? [[String: Any]])
    receipts[0]["assessedInterest"] = 1
    records[0]["receipts"] = receipts
    object["records"] = records
    let forged = try JSONDecoder().decode(
      ScriptFinanceLedger.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(!forged.valid)
    #expect(record.balance(at: record.source.cause.calendarSeconds - 1) == nil)
  }

  @Test func actualNativeJumpCalendarProjectsInterestWithoutAutomaticCashOrLedgerMutation()
    async throws
  {
    let fixture = try interestFixture(edits: [
      ("periodSeconds = 86400", "periodSeconds = 1"),
      ("maximumInterest = 1000", "maximumInterest = 1000000"),
    ])
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    var game = await runtime.snapshot()
    let ledger = try #require(game.commander.scriptState.financeLedger)
    let record = try #require(ledger.records.first)
    let origin = game.currentSystem
    let destination = try #require(
      game.systems.first {
        $0.id != origin.id && $0.id != Plugh.systemID && origin.distance(to: $0) > 0
          && origin.distance(to: $0) <= game.commander.maximumJumpDistance
          && game.commander.jumpFuelCost(distance: origin.distance(to: $0)) <= game.commander.fuel
      })
    game.launch()
    try #require(!game.docked)
    // Controlled mass-lock-free countdown boundary, not a claimed flight from the station.
    // Reframe preserves actual actors/world positions; arrival, fuel and calendar still use native code.
    let anchors = try #require(game.commander.flightSimulation.anchors)
    NativeStationTestFixture.reframe(
      &game, to: .init(position: anchors.arrival + .init(0, 0, -20000)))
    game.speed = 0
    game.selectedSystem = destination.id
    try #require(!game.hyperspaceMassLocked)
    let beforeTime = game.commander.scriptState.calendarSeconds
    let beforeDue = try #require(record.balance(at: beforeTime))
    let cash = game.commander.credits
    game.beginHyperspace()
    try #require(game.jumpCountdown != nil)
    var frames = 0
    while game.jumpCountdown != nil && frames < 500 {
      let observed = game.gameplayContext()
      let context = try #require(observed)
      let director = try #require(game.commander.encounterDirector)
      try #require(
        director.decisionCount == 0 && director.admittedCount == 0
          && director.pendingRequests.isEmpty)
      // Existing NPC resource fixture pattern: no unrelated new traffic during this clock test.
      game.commander.encounterDirector = EncounterDirector(context: context)
      game.tick(delta: 0.1)
      try #require(!game.docked && game.screen != .gameOver && !game.paused)
      frames += 1
    }
    try #require(frames > 0 && frames < 500 && game.commander.system == destination.id)
    let adjustment = try #require(game.commander.scriptState.calendarLedger?.lastAdjustment)
    #expect(adjustment.kind == .jump && adjustment.seconds > 0)
    #expect(game.commander.scriptState.calendarSeconds >= beforeTime + adjustment.seconds)
    let afterDue = try #require(record.balance(at: game.commander.scriptState.calendarSeconds))
    #expect(afterDue.assessedInterest > beforeDue.assessedInterest)
    #expect(game.commander.credits == cash && game.commander.scriptState.financeLedger == ledger)
    #expect(game.commander.valid)
  }
}

extension ScriptFinanceInterestTests {
  @Test func actualMarketPartialInterestPaymentSurvivesCurrentVersionedSave() async throws {
    let fixture = try interestFixture(edits: [("periodSeconds = 86400", "periodSeconds = 100")])
    defer { fixture.storage.clean() }
    let borrower = try await fixture.runtime(credits: 100)
    let beforeBorrow = await borrower.snapshot()
    let ask = beforeBorrow.market[0].price
    let expectedPayment = beforeBorrow.commander.credits + 2000 - ask
    let expectedPrincipal = 2000 - (expectedPayment - 200)
    try #require(expectedPayment > 200 && expectedPayment < 2200 && expectedPrincipal > 0)
    let nextInterest = (expectedPrincipal * 1000 + 9999) / 10000
    try await ScriptFinanceTestFixture.confirm(borrower)
    let borrowed = await borrower.snapshot()
    let start = try #require(
      borrowed.commander.scriptState.financeLedger?.records.first?.receipts.first?.calendarSeconds)
    // Controlled period boundary, through the current protected actor: no synthetic travel receipt
    // or fresh runtime that discards the actual native main-station authority.
    await borrower.nativeCommand { candidate in
      candidate.commander.scriptState.calendarSeconds = start + 100
    }
    let runtime = borrower
    let game = await runtime.snapshot()
    await runtime.key("escape")
    await runtime.key("7")
    await runtime.key("right")
    #expect(await runtime.snapshot().commander.credits == expectedPayment)
    #expect(await runtime.snapshot().commander.cargo[0] == game.commander.cargo[0] + 1)
    try await ScriptFinanceTestFixture.confirm(runtime)
    let partial = await runtime.snapshot().commander
    let ledger = try #require(partial.scriptState.financeLedger)
    let receipt = try #require(ledger.records.first?.receipts.last)
    #expect(partial.credits == 0 && receipt.amount == expectedPayment)
    #expect(
      receipt.interestAdded == 200 && receipt.afterInterest == 0
        && receipt.afterPrincipal == expectedPrincipal)
    #expect(ledger.records[0].status == .outstanding)
    try await runtime.save(to: fixture.storage.url)
    let restored = try ScriptSaveStore.read(
      Data(contentsOf: fixture.storage.url), from: fixture.storage.url
    ).0
    #expect(restored.scriptState.financeLedger == ledger)
    #expect(restored.credits == partial.credits && restored.cargo == partial.cargo)
    #expect(
      restored.scriptState.financeLedger?.records[0].balance(at: start + 200)?.total
        == expectedPrincipal + nextInterest)
  }
}
