import Foundation
import Testing

@testable import L337Core

private struct OriginalRepairLoopBoardFixture {
  let native: WayfarerRepairLoopNativeFixture

  init() throws { native = try WayfarerRepairLoopNativeFixture() }

  func review(
    _ runtime: GameRuntime,
    matching predicate: (WayfarerRepairLoopBoardAction) -> Bool
  ) async throws -> WayfarerRepairLoopBoardReview {
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(
      board.rows.firstIndex { $0.repairLoop.map { predicate($0.action) } == true })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let game = await runtime.snapshot()
    try #require(game.contractBoard.detail && game.contractBoard.action == .back)
    return try #require(game.contractBoard.repairLoopQuote)
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
    await confirm(runtime)
    let game = await runtime.snapshot()
    let serial = try #require(quote.offer?.serial)
    return try #require(
      game.commander.scriptState.instances.values.first {
        $0.savedWayfarerRepairLoop?.serial == serial
      }?.id)
  }
}

struct OriginalRepairLoopTests {
  @Test func productionTermsAndExactPinUseFullOwnerReturnLoop() throws {
    let fixture = try WayfarerRepairLoopNativeFixture()
    defer { fixture.files.clean() }
    let pack = fixture.pack
    let terms = try #require(pack.manifest.repairLoop)
    #expect(
      terms.source.system == 85 && terms.workshop.system == 241 && terms.receiver.system == 85)
    #expect(terms.route == [85, 241, 85] && terms.stockUnits == 6 && terms.tonnes == 2)
    #expect(terms.maximumActive == 3 && terms.hazardTier == 0 && terms.rewardNative == 6100)
    #expect(pack.manifest.stateID == WayfarerRepairLoopDefinition.stateID)
    let installed = fixture.files.root.appendingPathComponent("installed")
    _ = try ScriptPackLibrary.install(pack, directory: installed)
    let library = ScriptPackLibrary.defaultLibrary(directory: installed)
    #expect(library.errors.isEmpty && library.packs.filter { $0.digest == pack.digest }.count == 1)
    #expect(library.packs.first?.digest == pack.digest)
  }

  @Test func actualBoardBackRedockAndReloadPreserveOriginalAdvertisedUnit() async throws {
    let fixture = try OriginalRepairLoopBoardFixture()
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
    #expect(detail.contains("Cedamar -> Celalen -> Cedamar") && detail.contains("610.0 CR"))
    #expect(detail.contains("2t") && detail.contains("passenger berths: 0"))
    #expect(
      detail.contains("No deposit, workshop fee or deadline") && detail.contains("transport-only"))
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
    #expect(throws: (any Error).self) { try stale.confirmWayfarerRepairLoopBoard(first) }
    try await runtime.save(to: fixture.native.save)
    try await runtime.load(from: fixture.native.save, persistMigrations: false)
    if await runtime.snapshot().paused { await runtime.key("pause") }
    let loaded = try await fixture.review(runtime) { $0 == first.row.action }
    #expect(loaded.row.key == first.row.key && loaded.offer?.id != redocked.offer?.id)
    #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  }

  @Test func actualBoardServiceAndOwnerReturnPayOnlyExactRepairClueOnce() async throws {
    let fixture = try OriginalRepairLoopBoardFixture()
    defer { fixture.native.files.clean() }
    let runtime = try await fixture.native.runtime()
    let first = try await fixture.pickup(runtime)
    let second = try await fixture.pickup(runtime)
    let source = await runtime.snapshot()
    let premature = try await fixture.review(runtime) { $0 == .service(first) }
    #expect(!premature.allowed)
    try await fixture.native.arrive(runtime, path: [85, 241])
    for id in [first, second] {
      let quote = try await fixture.review(runtime) { $0 == .service(id) }
      try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
      await fixture.confirm(runtime)
    }
    let serviced = await runtime.snapshot()
    #expect(serviced.commander.credits == source.commander.credits)
    #expect(serviced.commander.scriptState.savedClueJournal == nil)
    let wrongOwner = try await fixture.review(runtime) { $0 == .receive(first) }
    #expect(!wrongOwner.allowed)
    try await fixture.native.arrive(runtime, path: [241, 85])
    var originalAward: ScriptCompletionReceipt?
    for (index, id) in [first, second].enumerated() {
      let quote = try await fixture.review(runtime) { $0 == .receive(id) }
      try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
      await fixture.confirm(runtime)
      let paid = await runtime.snapshot()
      #expect(paid.commander.scriptState.instances[id]?.outcome == .complete)
      #expect(paid.commander.credits == source.commander.credits + 6100 * (index + 1))
      let award = try #require(
        paid.commander.scriptState.savedClueJournal?.awards[WayfarerRepairLoopDefinition.stateID])
      #expect(award.clueID == "exchange-service-repair-loop")
      #expect(
        ScriptClueTrustCatalog.production.pin(for: award.completion)?.digest
          == fixture.native.pack.digest)
      if index == 0 {
        originalAward = award.completion
        #expect(paid.message.contains("SENN:"))
      } else {
        #expect(award.completion == originalAward)
      }
      #expect(paid.commander.scriptState.savedClueJournal?.awards.count == 1)
    }
  }
}
