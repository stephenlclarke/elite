import Foundation
import Testing

@testable import L337Core

private struct MutualContributionBoardFixture {
  let native: OriginalMutualContributionFixture
  init() throws { native = try OriginalMutualContributionFixture() }
  func review(_ runtime: GameRuntime) async throws -> ContractAcceptanceQuote {
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(
      board.rows.firstIndex {
        $0.board.hasPrefix(native.pack.digest + "/") && $0.offer?.key == "credits-1"
      })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let game = await runtime.snapshot()
    try #require(game.contractBoard.detail && game.contractBoard.action == .back)
    return try #require(game.contractBoard.quote)
  }
  func donate(_ runtime: GameRuntime) async {
    await runtime.key("right")
    await runtime.key("return")
  }
}

struct OriginalMutualContributionTests {
  @Test func actualReliefBoardShowsOneNamedFiveHundredRowAndBackDeclineTransferNothing()
    async throws
  {
    let fixture = try MutualContributionBoardFixture()
    defer { fixture.native.files.clean() }
    let runtime = try await fixture.native.runtime()
    let quote = try await fixture.review(runtime)
    try #require(quote.allowed)
    let before = await runtime.snapshot()
    let rows = before.contractBoard.rows.filter {
      $0.board.hasPrefix(fixture.native.pack.digest + "/")
    }
    #expect(rows.count == 1 && rows.first?.offer?.key == "credits-1")
    let detail = Display.contractDetailRows(before, width: before.viewportWidth).joined(
      separator: "\n")
    #expect(detail.contains("Cedamar Orbital Relief Reserve") && detail.contains("500.0 CR"))
    #expect(
      detail.contains("Cargo: 0t") && detail.contains("reward: 0")
        && detail.contains("no deadline or refund"))
    #expect(!detail.contains("standing by one") && !detail.contains("Food pledge"))
    #expect(
      Display.contractBoard(before, width: before.viewportWidth, height: before.viewportHeight)
        .labels.contains { $0.text == "  Donate" })
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == before.commander)
    _ = try await fixture.review(runtime)
    await runtime.key("left")
    await runtime.key("return")
    let declined = await runtime.snapshot()
    #expect(declined.commander.credits == before.commander.credits)
    #expect(declined.commander.cargo == before.commander.cargo)
    #expect(declined.commander.scriptState.instances.isEmpty)
    #expect(
      declined.commander.scriptState.pledgeLedger == nil
        && declined.commander.scriptState.savedClueJournal == nil)
    #expect(declined.commander.contracts.boards[quote.board]?.offers.first?.status == .declined)
  }

  @Test func actualReliefBoardStaleRedockAndShortCashCannotBorrowAReview() async throws {
    let fixture = try MutualContributionBoardFixture()
    defer { fixture.native.files.clean() }
    let runtime = try await fixture.native.runtime()
    let old = try await fixture.review(runtime)
    await runtime.key("escape")
    await runtime.key("escape")
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    let before = await runtime.snapshot()
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(old) }
    #expect(await runtime.snapshot().commander == before.commander)
    let poor = try await fixture.native.runtime(cash: 4999)
    let refused = try await fixture.review(poor)
    #expect(!refused.allowed && refused.pledge?.amount == 5000)
    let assets = await poor.snapshot().commander
    await fixture.donate(poor)
    #expect(await poor.snapshot().commander == assets)
  }

  @Test func actualReliefWriterRollbackRetryAndSecondHourlyDonationKeepFirstClue() async throws {
    let fixture = try MutualContributionBoardFixture()
    defer { fixture.native.files.clean() }
    let runtime = try await fixture.native.runtime()
    // Existing hourly pledge policy: align a clock boundary before any donation evidence exists.
    await runtime.nativeCommand { game in game.commander.scriptState.localSeconds = 3599.9 }
    let firstQuote = try await fixture.review(runtime)
    try #require(firstQuote.allowed)
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(fixture.native.save.deletingLastPathComponent())
    let blocked = try fixture.native.files.blockWrites("contribution")
    await fixture.donate(runtime)
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander)
    #expect(
      failed.commander.scriptState.pledgeLedger == nil
        && failed.commander.scriptState.savedClueJournal == nil)
    try fixture.native.files.restoreWrites(blocked, files: disk)
    _ = try await fixture.review(runtime)
    await fixture.donate(runtime)
    let first = await runtime.snapshot()
    let award = try #require(
      first.commander.scriptState.savedClueJournal?.awards[OriginalMutualContribution.stateID])
    #expect(first.commander.credits == before.commander.credits - 5000)
    #expect(first.message.contains("CEDAMAR ORBITAL RELIEF RESERVE RECEIVED 500.0 CR"))
    #expect(!first.message.contains("STANDING"))
    #expect(first.commander.scriptState.pledgeLedger?.receipts.count == 1)
    #expect(first.commander.scriptState.savedClueJournal?.awards.count == 1)
    await runtime.nativeCommand { game in
      _ = game.advanceScriptClockValues(delta: 0.1, flight: false, local: true, calendar: false)
    }
    let second = try await fixture.review(runtime)
    #expect(second.offer != firstQuote.offer && second.allowed)
    await fixture.donate(runtime)
    let paid = await runtime.snapshot()
    #expect(paid.commander.credits == before.commander.credits - 10000)
    #expect(paid.commander.scriptState.pledgeLedger?.receipts.count == 2)
    #expect(paid.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      paid.commander.scriptState.savedClueJournal?.awards[OriginalMutualContribution.stateID]?
        .completion == award.completion)
    try await runtime.save(to: fixture.native.save)
    try await runtime.load(from: fixture.native.save, persistMigrations: false)
    #expect(
      await runtime.snapshot().commander.scriptState.savedClueJournal?.awards[
        OriginalMutualContribution.stateID]?.completion == award.completion)
  }
}
