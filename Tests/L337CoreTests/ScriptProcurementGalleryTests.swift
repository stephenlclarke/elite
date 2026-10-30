import Foundation
import Testing

@testable import L337Core

@Test func procurementGalleryStartsRealUnacceptedFlightAndKeepsLiveFilesIsolated() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  var game = try fixture.policyGame()
  game.commander.name = "LIVE PROCURE"
  let validParent = game.commander.valid
  try #require(validParent)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  await runtime.key("gallery-open")
  let before = await runtime.snapshot()
  let galleryOpened = before.screen == .gallery
  try #require(galleryOpened)
  let files = try ScriptFinanceTestFixture.files(fixture.root.appendingPathComponent("save"))
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest, seed: 42)
  let namespace = await runtime.gallerySaveDirectory()
  let trial = await runtime.snapshot()
  try #require(namespace != nil)
  #expect(trial.isMissionTrial && !trial.docked && trial.screen.isFlight)
  #expect(trial.trialSeed == 42 && fixture.pack.manifest.trial?.credits == 164875)
  #expect(trial.currentSystem.original?.key == "G01-S007")
  #expect(trial.commander.galaxy == 0 && trial.commander.system == 7)
  try ScriptProcurementFixture.requirePaidG03Preparation(trial)
  #expect(trial.commander.cargo == before.commander.cargo)
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
  try ScriptProcurementFixture.requirePaidG03Preparation(restarted)
  #expect(restarted.commander.cargo == trial.commander.cargo)
  #expect(restarted.commander.equipmentOwnerID != trial.commander.equipmentOwnerID)
  let initialTransactions = trial.commander.equipmentPurchaseHistory?.paid.map(\.transaction)
  let restartedTransactions = restarted.commander.equipmentPurchaseHistory?.paid.map(\.transaction)
  #expect(initialTransactions != restartedTransactions)
  try await runtime.returnFromScriptGalleryTrial()
  let restored = await runtime.snapshot()
  let afterFiles = try ScriptFinanceTestFixture.files(fixture.root.appendingPathComponent("save"))
  #expect(restored.commander == before.commander && !restored.isMissionTrial && files == afterFiles)
}

@Test func g03PaidPreparationRefusesAnAlreadyOwnedDefenceWithoutPublishingEarlierPurchases() throws
{
  var game = try ScriptProcurementFixture.freshG03FlightGame()
  let item = try #require(Equipment.all.first { $0.name == "Pulse Shield Booster" })
  let quote = try game.quoteEquipmentPurchase(item)
  let fitted = try game.applyEquipmentPurchase(quote)
  try #require(fitted && game.commander.credits == 154000)
  let before = game
  // The private preparation buys three targeting tiers before the real fourth quote refuses.
  #expect(throws: EquipmentRuntimeError.alreadyOwned) { try game.prepareG03FlightEquipment() }
  #expect(game.commander == before.commander && game.commander.targetingTier == nil)
  #expect(game.energy == before.energy && game.frontShield == before.frontShield)
  #expect(game.rearShield == before.rearShield && game.bodies == before.bodies)
  #expect(game.gameplayRevision == before.gameplayRevision && game.nextBodyID == before.nextBodyID)
}
