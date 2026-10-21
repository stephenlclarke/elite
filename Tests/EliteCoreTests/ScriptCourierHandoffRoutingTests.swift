import Foundation
import Testing

@testable import EliteCore

@Test func typedCourierBackClearsPresentationAndOnlyTheReopenedContactCanDeliver() async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game, variant: .package)
  try fixture.travel(&game, id: id)
  try fixture.requestContact(&game, id: id)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let custody = try #require(before.commander.scriptState.instances[id]?.courier)
  let oldPage = before.scriptPagePresentation
  let priorBytes = try Data(contentsOf: fixture.save)
  #expect(before.screen == .handoff && !before.scriptConfirmSelected)
  #expect(before.courierContactActionLabel == "Deliver")

  await runtime.scriptPageKey("return", expected: oldPage)
  let backedOut = await runtime.snapshot()
  #expect(backedOut.commander == before.commander && backedOut.screen == before.blackjackReturn)
  #expect(backedOut.scriptOffer == nil && backedOut.scriptPresentedDialogue == nil)
  #expect(backedOut.scriptAvailablePackDigest == nil && backedOut.scriptChoiceSelection == 0)
  #expect(try Data(contentsOf: fixture.save) == priorBytes)
  await runtime.scriptPageKey("left", expected: oldPage)
  let stale = await runtime.snapshot()
  #expect(stale.commander == before.commander && stale.screen == backedOut.screen)
  #expect(stale.scriptOffer == nil && stale.message.contains("CONTACT CHANGED"))

  await runtime.key("contacts-open")
  let reopened = await runtime.snapshot()
  let currentPage = reopened.scriptPagePresentation
  #expect(reopened.screen == .handoff && reopened.scriptOffer == id)
  #expect(!reopened.scriptConfirmSelected && currentPage != oldPage)
  await runtime.scriptPageKey("left", expected: currentPage)
  let selected = await runtime.snapshot()
  #expect(selected.scriptConfirmSelected)
  await runtime.scriptPageKey("return", expected: currentPage)
  let delivered = await runtime.snapshot()
  let completed = try #require(delivered.commander.scriptState.instances[id])
  #expect(completed.outcome == .complete && completed.courier?.terminal?.cause == .delivered)
  #expect(completed.courier?.item == custody.item && delivered.commander.cargoTonnes == 0)
  #expect(delivered.scriptOffer == nil && delivered.scriptPresentedDialogue == nil)
  #expect(delivered.scriptAvailablePackDigest == nil && delivered.scriptChoiceSelection == 0)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(saved.scriptState.instances[id]?.courier == completed.courier)
  #expect(saved.credits == delivered.commander.credits)

  await runtime.scriptPageKey("return", expected: currentPage)
  let replay = await runtime.snapshot()
  #expect(replay.commander == delivered.commander)
}
