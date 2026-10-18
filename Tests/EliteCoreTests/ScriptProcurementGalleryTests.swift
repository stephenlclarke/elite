import Foundation
import Testing

@testable import EliteCore

@Test func procurementGalleryStartsRealUnacceptedFlightAndKeepsLiveFilesIsolated() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  var game = try fixture.policyGame()
  game.commander.name = "LIVE PROCUREMENT PARENT"
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let files = try ScriptFinanceTestFixture.files(fixture.root.appendingPathComponent("save"))
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest, seed: 42)
  let namespace = await runtime.gallerySaveDirectory()
  let trial = await runtime.snapshot()
  try #require(namespace != nil)
  #expect(trial.isMissionTrial && !trial.docked && trial.screen.isFlight)
  #expect(trial.trialSeed == 42 && trial.commander.credits == 100000)
  #expect(trial.commander.scriptState.instances.isEmpty && trial.commander.contracts.boards.isEmpty)
  #expect(
    trial.commander.flightSimulation.player != nil && !trial.nativeMainStationDockEvidenceIsCurrent)
  let receipt = try await runtime.saveForInterface()
  #expect(receipt.isTrial && receipt.url.path.hasPrefix(namespace!.path + "/"))
  await runtime.key("trial-restart")
  let restarted = await runtime.snapshot()
  #expect(
    restarted.isMissionTrial && !restarted.docked
      && restarted.commander.scriptState.instances.isEmpty)
  try await runtime.returnFromScriptGalleryTrial()
  let restored = await runtime.snapshot()
  let afterFiles = try ScriptFinanceTestFixture.files(fixture.root.appendingPathComponent("save"))
  #expect(restored.commander == before.commander && !restored.isMissionTrial && files == afterFiles)
}
