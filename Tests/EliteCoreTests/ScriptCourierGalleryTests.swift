import Foundation
import Testing

@testable import EliteCore

@Test func courierGalleryTrialReviewSaveLoadRestartReturnPreservesLiveCommander() async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.name = "LIVE"
  game.commander.cargo[0] = 3
  game.commander.credits = 32100
  game.openGallery()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let live = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.save)
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest, seed: 42)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let trial = await runtime.snapshot()
  #expect(trial.isMissionTrial && trial.commander.scriptState.instances.isEmpty)
  #expect(
    trial.screen == .contracts && trial.contractBoard.detail && trial.contractBoard.action == .back)
  #expect(trial.contractBoard.rows.count == 6 && trial.commander.cargoTonnes == 0)
  let terms = trial.commander.contracts
  _ = try await runtime.saveForInterface()
  _ = try await runtime.loadForInterface()
  #expect(await runtime.snapshot().commander.contracts == terms)
  try await runtime.restartScriptGalleryTrial()
  let restarted = await runtime.snapshot()
  #expect(
    restarted.commander.contracts == terms && restarted.commander.scriptState.instances.isEmpty)
  #expect(restarted.contractBoard.action == .back)
  try await runtime.returnFromScriptGalleryTrial()
  let restored = await runtime.snapshot()
  #expect(restored.commander == live.commander && !restored.isMissionTrial)
  #expect(try Data(contentsOf: fixture.save) == pointer)
}

@Test(arguments: [ScriptCourierVariant.data, .package])
func courierContactRendererUsesTypedActionsAndKeepsCompactWideBounds(variant: ScriptCourierVariant)
  throws
{
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game, variant: variant)
  try fixture.requestContact(&game, id: id)
  for (width, height) in [(512.0, 518.0), (1512.0, 982.0)] {
    let frame = Display.blackjackHandoff(game, width: width, height: height)
    #expect(frame.labels.contains { $0.text.contains("Abandon") })
    #expect(frame.labels.contains { $0.text.contains("> Back") })
    #expect(
      frame.labels.allSatisfy {
        $0.x.isFinite && $0.y.isFinite && $0.x >= 0 && $0.y >= 0 && $0.y < height
      })
    #expect(game.packDialogLines(width: width).joined(separator: " ").contains("Consignment"))
  }
  game.key("escape")
  try fixture.travel(&game, id: id)
  try fixture.requestContact(&game, id: id)
  #expect(game.courierContactActionLabel == "Deliver")
  game.scriptPresentedDialogue?.token = "stale"
  #expect(game.courierContactActionLabel == nil && game.courierContactDetails.isEmpty)
  game.scriptPresentedDialogue = game.commander.scriptState.instances[id]?.dialogue
  game.scriptPacks = []
  #expect(game.courierContactActionLabel == nil)
  let fallback = Display.blackjackHandoff(game, width: 512, height: 518)
  #expect(fallback.labels.contains { $0.text.contains("Confirm / Continue") })
}
