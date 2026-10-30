import Foundation
import Testing
import os

@testable import L337Core

@Test func protectedTerminalSettlementAwardsOnceAndReplayCannotPayOrReplaceTheProof() throws {
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  var game = try fixture.game()
  let initial = game.commander
  let id = try fixture.queueSettlement(&game)
  let before = game.commander
  #expect(before.scriptState.savedClueJournal == nil)
  game.drainScriptEvents(clueTrust: fixture.trust)
  let journal = try #require(game.commander.scriptState.savedClueJournal)
  let award = try #require(journal.awards["l337.glass-meridian"])
  #expect(award.completion == game.commander.scriptState.instances[id]?.completionReceipt)
  #expect(award.completion.causeKind == "dialogue.confirmed")
  #expect(game.commander.credits == before.credits + 7)
  #expect(game.commander.cargo == initial.cargo && game.commander.scriptState.payloadTonnes == 0)
  #expect(journal.progress.collectedClueIDs == ["meridian-offset"])
  #expect(journal.progress.missingClueIDs.count == 63 && !journal.progress.complete)
  #expect(
    Set(journal.progress.collectedClueIDs).union(journal.progress.missingClueIDs)
      == ScriptBaseClueCatalog.requiredClueIDs)
  let settled = game.commander
  game.confirmScriptDialogue()
  game.emitScriptEvent("dialogue.confirmed", only: id)
  game.drainScriptEvents(clueTrust: fixture.trust)
  #expect(game.commander == settled && game.commander.valid)
}

@Test func failedTerminalPublicationRollsBackCluePaymentAndCompletionTogether() throws {
  enum Refused: Error { case publication }
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try fixture.queueSettlement(&game)
  let before = game.commander
  let publicationReached = OSAllocatedUnfairLock(initialState: false)
  game.drainScriptEvents(
    publish: { candidate in
      publicationReached.withLock { $0 = true }
      // Observe the actual candidate after protected Lua evaluation and native validation.
      #expect(candidate.commander.scriptState.savedClueJournal?.awards.count == 1)
      #expect(candidate.commander.credits == before.credits + 7)
      #expect(candidate.commander.scriptState.instances[id]?.outcome == .complete)
      throw Refused.publication
    }, clueTrust: fixture.trust)
  let reached = publicationReached.withLock { $0 }
  #expect(reached)
  #expect(game.commander.credits == before.credits)
  #expect(game.commander.scriptState.savedClueJournal == nil)
  #expect(game.commander.scriptState.instances[id]?.outcome == .active)
  #expect(game.commander.scriptState.instances[id]?.completionReceipt == nil)
}

@Test func claimedApprovedNameAndCreditsDoNotAuthorizeAProductionClue() throws {
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try fixture.queueSettlement(&game)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(game.commander.scriptState.savedClueJournal == nil)
  // Native pinning includes version and executable digest, not just definition or source ID.
  let alternate = try ScriptClueFixture(edition: "1.0.1")
  defer { alternate.clean() }
  var changed = try alternate.game()
  _ = try alternate.queueSettlement(&changed)
  changed.drainScriptEvents(clueTrust: fixture.trust)
  #expect(changed.commander.scriptState.savedClueJournal == nil)
}

@Test func failedAbandonedAndAcceptanceTerminalOutcomesCannotAwardAClue() throws {
  for outcome in ["failed", "abandoned"] {
    let fixture = try ScriptClueFixture(outcome: outcome)
    defer { fixture.clean() }
    var game = try fixture.game()
    let id = try fixture.queueSettlement(&game)
    game.drainScriptEvents(clueTrust: fixture.trust)
    #expect(game.commander.scriptState.instances[id]?.outcome.rawValue == outcome)
    #expect(game.commander.scriptState.savedClueJournal == nil)
  }
  let fixture = try ScriptClueFixture(acceptanceFinish: true)
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try game.acceptScriptMission(fixture.pack, drainAccepted: false)
  game.drainScriptEvents(clueTrust: fixture.trust)
  #expect(game.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(game.commander.scriptState.savedClueJournal == nil)
}

@Test func clueCatalogRequiresExactDistinctIdentitiesAndProgressQueryDoesNotScanHistory()
  async throws
{
  let sources = ScriptBaseClueCatalog.sources
  #expect(sources.count == 64 && Set(sources.map(\.sourceID)).count == 64)
  #expect(Set(sources.map(\.clueID)).count == 64 && Set(sources.map(\.receiptID)).count == 64)
  #expect(ScriptBaseClueCatalog.requiredClueIDs.count == 64)
  #expect(ScriptBaseClueCatalog.requiredClueIDs.contains("exchange-service-convoy-watch"))
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  var game = try fixture.game()
  _ = try fixture.queueSettlement(&game)
  game.drainScriptEvents()
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  let progress = await runtime.baseClueProgress()
  let after = await runtime.snapshot()
  #expect(progress == .empty && before.commander == after.commander)
}

@Test func retainedClueIsIndependentOfInstalledSourceAndEscapeCargoLoss() throws {
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  var (game, _) = try fixture.completed()
  let journal = game.commander.scriptState.savedClueJournal
  game.scriptPacks = []
  try game.commander.grantEquipment(
    "Escape Pod", at: .utility(.escapePod), provenance: .grant("clue escape regression"))
  let pod = game.commander.fittedEquipment(at: .utility(.escapePod))
  try #require(pod != nil)
  game.launch()
  game.escapePod()
  #expect(game.docked && game.commander.fittedEquipment(at: .utility(.escapePod)) == nil)
  #expect(game.commander.scriptState.savedClueJournal == journal)
  #expect(game.commander.valid)
}

@Test func repeatedSourceSuccessKeepsFirstProofAndDoesNotSubstituteForMissingClues() throws {
  let first = try ScriptClueFixture()
  let second = try ScriptClueFixture(packID: "fixture.second-success")
  defer {
    first.clean()
    second.clean()
  }
  let trust = try ScriptClueTrustCatalog(
    pins: [first.pack, second.pack].map {
      .init(
        sourceID: "l337.glass-meridian", definition: $0.manifest.stateID,
        version: $0.manifest.version, digest: $0.digest, terminalEvents: ["dialogue.confirmed"])
    })
  var (game, _) = try first.completed()
  let original = game.commander.scriptState.savedClueJournal
  game.scriptPacks.append(second.pack)
  let id = try second.queueSettlement(&game)
  game.drainScriptEvents(clueTrust: trust)
  #expect(game.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(game.commander.scriptState.savedClueJournal == original)
  #expect(game.commander.scriptState.savedClueJournal?.progress.missingClueIDs.count == 63)
}

@Test func changedExecutableDigestAndCreditOnlyProposalCannotAward() throws {
  let approved = try ScriptClueFixture()
  let changed = try ScriptClueFixture(settlement: 8)
  let creditOnly = try ScriptClueFixture(finish: false)
  defer {
    approved.clean()
    changed.clean()
    creditOnly.clean()
  }
  #expect(changed.pack.manifest.version == approved.pack.manifest.version)
  #expect(changed.pack.manifest.stateID == approved.pack.manifest.stateID)
  #expect(changed.pack.digest != approved.pack.digest)
  var changedGame = try changed.game()
  _ = try changed.queueSettlement(&changedGame)
  changedGame.drainScriptEvents(clueTrust: approved.trust)
  #expect(changedGame.commander.scriptState.savedClueJournal == nil)
  var creditGame = try creditOnly.game()
  let initialCredits = creditGame.commander.credits
  let id = try creditOnly.queueSettlement(&creditGame)
  creditGame.drainScriptEvents(clueTrust: creditOnly.trust)
  #expect(creditGame.commander.credits == initialCredits + 7)
  #expect(creditGame.commander.scriptState.instances[id]?.outcome == .active)
  #expect(creditGame.commander.scriptState.savedClueJournal == nil)
}

@Test func actualHullExchangePreservesPermanentClueOwnershipAndProgress() throws {
  let fixture = try ScriptClueFixture()
  defer { fixture.clean() }
  var (game, _) = try fixture.completed()
  let journal = game.commander.scriptState.savedClueJournal
  let owner = game.commander.equipmentOwnerID
  game.commander.credits = 10_000_000
  let destinationFuel = try #require(ShipCatalogue.ship("SH013")?.game?.fuel)
  game.commander.fuel = destinationFuel
  try #require(game.commander.valid)
  game.commander.navigationPlan = nil
  game.key("6")
  game.showroom.selection = "SH013"
  let quote = try #require(game.shipTradeQuote)
  try #require(quote.allowed)
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH013" && game.commander.credits == quote.balance)
  #expect(game.commander.equipmentOwnerID == owner)
  #expect(game.commander.scriptState.savedClueJournal == journal && game.commander.valid)
}
