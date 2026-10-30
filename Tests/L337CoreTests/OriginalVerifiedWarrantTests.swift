import Foundation
import Testing

@testable import L337Core

extension GameRuntime {
  func warrantStoreFrontFixture() throws -> OwnedEquipmentItem {
    try scriptCommand { game in
      let item = try #require(game.commander.fittedEquipment(at: .laser(.front)))
      let revision = try #require(game.commander.equipmentInventory?.revision)
      try game.storeEquipment(item, expectedRevision: revision)
      return item
    }
  }
  func warrantRefitFrontFixture(_ id: UUID) throws {
    try scriptCommand { game in
      let inventory = try #require(game.commander.equipmentInventory)
      let item = try #require(inventory.items.first { $0.id == id })
      try game.fitEquipment(item, at: .laser(.front), expectedRevision: inventory.revision)
    }
  }
}

struct OriginalVerifiedWarrantTests {
  @Test func warrantDefaultDiscoveryBoardBackAndStaleChangedFitCannotAccept() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let installed = fixture.files.root.appendingPathComponent("installed-copy")
    _ = try ScriptPackLibrary.install(fixture.pack, directory: installed)
    let library = ScriptPackLibrary.defaultLibrary(directory: installed)
    #expect(
      library.errors.isEmpty && library.packs.filter { $0.digest == fixture.pack.digest }.count == 1
    )
    let runtime = try await fixture.runtime(defaults: true)
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(
      board.rows.firstIndex { $0.board.hasPrefix(fixture.pack.digest + "/") && $0.offer != nil })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let shown = await runtime.snapshot()
    let quote = try #require(shown.contractBoard.quote)
    let detail = Display.contractDetailRows(shown, width: shown.viewportWidth).joined(
      separator: "\n")
    #expect(quote.allowed && shown.contractBoard.action == .back)
    #expect(detail.contains("1120") && detail.contains("H0") && detail.contains("untimed"))
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == shown.commander)
    let front = try await runtime.warrantStoreFrontFixture()
    let changed = await runtime.snapshot()
    #expect(changed.commander.laser(on: .front) == nil)
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    let fresh = await runtime.contractAcceptanceQuote(board: quote.board, offer: quote.offer)
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(fresh) }
    #expect(await runtime.snapshot().commander == changed.commander)
    #expect(changed.commander.scriptState.instances.isEmpty)
    try await runtime.warrantRefitFrontFixture(front.id)
    let current = await runtime.contractAcceptanceQuote(board: quote.board, offer: quote.offer)
    let id = try await runtime.confirmContract(current)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .active)
  }

  @Test func warrantAcceptanceAndReportWriterFailureRetryPreserveNativeProof() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (key, offer) = try await fixture.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("warrant-accept")
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == before.commander)
    try fixture.files.restoreWrites(blocked, files: disk)
    let id = try await runtime.confirmContract(quote)
    try await fixture.objective(runtime, id: id)
    try await fixture.kill(runtime, id: id)
    try await fixture.returnToVoss(runtime)
    try await fixture.contact(runtime, dialogue: OriginalVerifiedWarrant.report)
    let ready = await runtime.snapshot()
    let original = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let held = try fixture.files.blockWrites("warrant-report")
    await fixture.confirm(runtime)
    let refused = await runtime.snapshot()
    #expect(
      refused.commander == ready.commander
        && refused.scriptPresentedDialogue == ready.scriptPresentedDialogue)
    #expect(refused.commander.scriptState.savedClueJournal == nil)
    #expect(
      OriginalVerifiedWarrant.qualifiedKill(
        try #require(refused.commander.scriptState.instances[id])))
    try fixture.files.restoreWrites(held, files: original)
    await fixture.confirm(runtime)
    let done = await runtime.snapshot()
    #expect(done.commander.scriptState.instances[id]?.outcome == .complete)
    #expect(done.commander.credits == ready.commander.credits + OriginalVerifiedWarrant.reward)
    #expect(done.commander.scriptState.savedClueJournal?.awards.count == 1)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == done.commander)
  }

  @Test func warrantKillAloneWrongStationAndStaleReportCannotSettle() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let id = try await fixture.accept(runtime)
    try await fixture.objective(runtime, id: id)
    try await fixture.kill(runtime, id: id)
    try await fixture.flight.dock(runtime)
    let balance = await runtime.snapshot().commander.credits
    await runtime.key("contacts-open")
    let wrong = await runtime.snapshot()
    #expect(wrong.scriptPresentedDialogue?.id != OriginalVerifiedWarrant.report)
    #expect(
      wrong.commander.credits == balance && wrong.commander.scriptState.savedClueJournal == nil)
    #expect(wrong.commander.scriptState.instances[id]?.outcome == .active)
    await runtime.key("escape")
    try await fixture.returnToVoss(runtime)
    try await fixture.contact(runtime, dialogue: OriginalVerifiedWarrant.report)
    let shown = await runtime.snapshot()
    var stale = shown
    let oldToken = stale.scriptPresentedDialogue?.token ?? ""
    stale.scriptPresentedDialogue?.token = "stale:" + oldToken
    stale.confirmScriptDialogue()
    #expect(stale.commander == shown.commander)
    #expect(stale.commander.scriptState.instances[id]?.outcome == .active)
    await fixture.confirm(runtime)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  }

  @Test func warrantRepeatUsesNewActorAndRetainsFirstClue() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let first = try await fixture.successful(runtime)
    let paid = await runtime.snapshot()
    let oldActor = try #require(
      paid.commander.scriptState.instances[first]?.ownedEncounters[
        OriginalVerifiedWarrant.encounterID]?.actors[OriginalVerifiedWarrant.actorID]?.identity)
    let firstAward = try #require(
      paid.commander.scriptState.savedClueJournal?.awards[OriginalVerifiedWarrant.stateID])
    let second = try await fixture.successful(runtime)
    let done = await runtime.snapshot()
    let newActor = try #require(
      done.commander.scriptState.instances[second]?.ownedEncounters[
        OriginalVerifiedWarrant.encounterID]?.actors[OriginalVerifiedWarrant.actorID]?.identity)
    #expect(first != second && oldActor != newActor)
    #expect(done.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[OriginalVerifiedWarrant.stateID]?
        .completion == firstAward.completion)
    #expect(done.commander.valid)
    try warrantCurrentEnvelopes(done, root: fixture.files.root)
  }
}
