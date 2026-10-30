import Foundation
import Testing

@testable import L337Core

private let originalSeedTransferFamily = "l337.wayfarer-service/seed-transfer"

private struct OriginalSeedTransferBoardFixture {
  let native: WayfarerSeedTransferNativeFixture
  init() throws { native = try WayfarerSeedTransferNativeFixture() }

  func review(
    _ runtime: GameRuntime,
    matching predicate: (WayfarerColdChainBoardAction) -> Bool
  ) async throws -> WayfarerColdChainBoardReview {
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(
      board.rows.firstIndex {
        $0.coldChain?.digest == native.pack.digest
          && $0.coldChain.map { predicate($0.action) } == true
      })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let game = await runtime.snapshot()
    try #require(game.contractBoard.detail && game.contractBoard.action == .back)
    return try #require(game.contractBoard.coldChainQuote)
  }

  func confirm(_ runtime: GameRuntime) async {
    await runtime.key("right")
    await runtime.key("return")
  }

  func pickup(_ runtime: GameRuntime) async throws -> UUID {
    let quote = try await review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
    let offer = try #require(quote.offer)
    await confirm(runtime)
    let game = await runtime.snapshot()
    let id = try #require(
      game.commander.scriptState.instances.values.first {
        $0.savedWayfarerColdChain?.unit == offer.stockUnit
          && $0.definition == originalSeedTransferFamily
      }?.id)
    try #require(
      game.commander.scriptState.instances[id]?.savedWayfarerColdChain?.seedTransfer != nil)
    return id
  }
}

struct OriginalSeedTransferTests {
  @Test func productionSeedProfileTermsAndNamedCustodiansDeduplicateExactContent() throws {
    let fixture = try WayfarerSeedTransferNativeFixture()
    defer { fixture.files.clean() }
    let pack = fixture.pack
    let terms = try #require(pack.manifest.coldChain)
    #expect(pack.manifest.stateID == originalSeedTransferFamily && terms.isSeedTransfer)
    #expect(terms.instanceDefinition == originalSeedTransferFamily)
    #expect(
      terms.source.system == 241 && terms.objective.system == 85 && terms.receiver.system == 85)
    #expect(terms.route == [241, 85] && terms.stockUnits == 6 && terms.tonnes == 3)
    #expect(terms.maximumActive == 3 && terms.hazardTier == 0 && terms.rewardNative == 6050)
    #expect(terms.flightAllowance == 2700)
    #expect(terms.sourceCustodian?.name == "Custodian Lysa Verin")
    #expect(terms.receiverCustodian?.name == "Custodian Oren Hale")
    #expect(terms.sourceCustodian?.id != terms.receiverCustodian?.id)
    let installed = fixture.files.root.appendingPathComponent("installed")
    _ = try ScriptPackLibrary.install(pack, directory: installed)
    let library = ScriptPackLibrary.defaultLibrary(directory: installed)
    #expect(library.errors.isEmpty && library.packs.filter { $0.digest == pack.digest }.count == 1)
    #expect(library.packs.first?.digest == pack.digest)
  }

  @Test func actualSeedBoardBackThreeTonneReviewAndRedockKeepOriginalConsignment() async throws {
    let fixture = try OriginalSeedTransferBoardFixture()
    defer { fixture.native.files.clean() }
    let runtime = try await fixture.native.runtime()
    let first = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    try #require(first.allowed)
    let before = await runtime.snapshot()
    let detail = Display.contractDetailRows(before, width: before.viewportWidth).joined(
      separator: "\n")
    #expect(detail.contains("Celalen -> Cedamar") && detail.contains("605.0 CR"))
    #expect(
      detail.contains("3t") && detail.contains("passenger berths: 0") && detail.contains("2700"))
    #expect(detail.contains("Custodian Lysa Verin") && detail.contains("Custodian Oren Hale"))
    #expect(detail.contains("explicitly authored") && detail.contains("not a measured journey"))
    // A copied capacity input checks the UI guard only; it supplies no native cargo purchase proof.
    var onlyTwo = before
    onlyTwo.commander.cargo[0] = onlyTwo.commander.standardCargoCapacity - 2
    #expect(!onlyTwo.wayfarerColdChainReview(first.row).allowed)
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == before.commander)
    let reopened = try await fixture.review(runtime) { $0 == first.row.action }
    #expect(reopened.row.key == first.row.key && reopened.offer?.id == first.offer?.id)
    await runtime.key("escape")
    await runtime.key("escape")
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    let redocked = try await fixture.review(runtime) { $0 == first.row.action }
    #expect(redocked.row.key == first.row.key && redocked.offer?.id != first.offer?.id)
    var stale = await runtime.snapshot()
    #expect(throws: (any Error).self) { try stale.confirmWayfarerColdChainBoard(first) }
    try await runtime.save(to: fixture.native.save)
    try await runtime.load(from: fixture.native.save, persistMigrations: false)
    if await runtime.snapshot().paused { await runtime.key("pause") }
    let loaded = try await fixture.review(runtime) { $0 == first.row.action }
    #expect(loaded.row.key == first.row.key && loaded.offer?.id != redocked.offer?.id)
    #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  }

  @Test func actualSeedBoardNamedReceptionPaysItsOwnClueOnceAcrossTwoLots() async throws {
    let fixture = try OriginalSeedTransferBoardFixture()
    defer { fixture.native.files.clean() }
    let runtime = try await fixture.native.runtime()
    let first = try await fixture.pickup(runtime)
    let second = try await fixture.pickup(runtime)
    let source = await runtime.snapshot()
    #expect(
      source.commander.scriptState.instances[first]?.payloads["wayfarer-sealed-seed-lot"] == 3)
    let premature = try await fixture.review(runtime) { $0 == .objective(first) }
    #expect(!premature.allowed)
    try await fixture.native.arrive(runtime, path: [241, 85])
    var originalAward: ScriptCompletionReceipt?
    for (index, id) in [first, second].enumerated() {
      let objective = try await fixture.review(runtime) { $0 == .objective(id) }
      try #require(objective.allowed, Comment(rawValue: objective.issues.joined(separator: "; ")))
      await fixture.confirm(runtime)
      let verified = await runtime.snapshot()
      #expect(verified.commander.credits == source.commander.credits + 6050 * index)
      let receiving = try await fixture.review(runtime) { $0 == .receive(id) }
      try #require(receiving.allowed, Comment(rawValue: receiving.issues.joined(separator: "; ")))
      await fixture.confirm(runtime)
      let paid = await runtime.snapshot()
      #expect(paid.commander.scriptState.instances[id]?.outcome == .complete)
      #expect(
        paid.commander.scriptState.instances[id]?.savedWayfarerColdChain?.seedTransfer?.acceptance
          != nil)
      #expect(paid.commander.credits == source.commander.credits + 6050 * (index + 1))
      let award = try #require(
        paid.commander.scriptState.savedClueJournal?.awards[originalSeedTransferFamily])
      #expect(award.clueID == "exchange-service-seed-transfer")
      #expect(
        ScriptClueTrustCatalog.production.pin(for: award.completion)?.digest
          == fixture.native.pack.digest)
      #expect(
        paid.commander.scriptState.savedClueJournal?.awards[WayfarerColdChainDefinition.stateID]
          == nil)
      if index == 0 {
        originalAward = award.completion
        #expect(paid.message.contains("SENN:"))
      } else {
        #expect(award.completion == originalAward)
      }
      #expect(paid.commander.scriptState.savedClueJournal?.awards.count == 1)
    }
    #expect(
      await runtime.snapshot().commander.scriptState.instances[first]?.payloads.isEmpty == true)
  }
}
