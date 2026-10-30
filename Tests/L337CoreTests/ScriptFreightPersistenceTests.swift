import Foundation
import Testing

@testable import L337Core

@Test func freightActualAcceptedSaveReloadKeepsUnitsAndInvalidatesOldContact() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, _) = try await fixture.accepted(row: 1)
  await runtime.key("contacts-open")
  let shown = await runtime.snapshot()
  try await runtime.save(to: fixture.save)
  let bytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == (shown.commander.usesAlienStorageSaveVersion ? 30 : 29))
  let (commander, world) = try ScriptSaveStore.read(bytes, from: fixture.save)
  #expect(
    commander.scriptState.instances[id]?.savedOwnedCargo
      == shown.commander.scriptState.instances[id]?.savedOwnedCargo)
  #expect(world.consistent(with: commander))
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let loaded = await runtime.snapshot()
  #expect(
    loaded.commander.scriptState.instances[id]?.savedOwnedCargo
      == shown.commander.scriptState.instances[id]?.savedOwnedCargo)
  var stale = loaded
  stale.scriptOffer = id
  stale.scriptPresentedDialogue = shown.scriptPresentedDialogue
  let dialogue = try #require(shown.scriptPresentedDialogue)
  let before = stale.commander
  #expect(throws: MissionPackError.self) {
    try stale.confirmFreightDialogue(id, dialogue: dialogue, choice: nil)
  }
  #expect(stale.commander == before)
}

@Test func freightReservedFieldsRejectNullAndPairsWithoutBanningAuthoredData() throws {
  for raw in [
    "{\"instances\":{\"00000000-0000-0000-0000-000000000001\":{\"savedOwnedCargo\":null}}}",
    "{\"instances\":[\"00000000-0000-0000-0000-000000000001\",{\"savedOwnedCargo\":{}}]}",
  ] {
    let bytes = Data(raw.utf8)
    #expect(throws: SaveError.self) {
      try ScriptFreightVersionedSave.rejectFields(bytes, part: .missions)
    }
  }
  let ordinary = Data(
    "{\"instances\":{\"00000000-0000-0000-0000-000000000001\":{\"data\":{\"savedOwnedCargo\":null,\"freightPlan\":1},\"payloads\":{\"g03-freight-consignment\":1}}}}"
      .utf8)
  try ScriptFreightVersionedSave.rejectFields(ordinary, part: .missions)
}

@Test func freightGenuineGalleryLaunchLeavesAcceptanceAndNativeDockToThePlayer() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  var game = try fixture.policyGame()
  game.commander.name = "LIVE FREIGHT"
  let valid = game.commander.valid
  try #require(valid)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  await runtime.key("gallery-open")
  let before = await runtime.snapshot()
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest, seed: 42)
  let trial = await runtime.snapshot()
  #expect(trial.isMissionTrial && !trial.docked && trial.screen.isFlight)
  #expect(trial.trialSeed == 42 && fixture.pack.manifest.trial?.credits == 157000)
  #expect(trial.currentSystem.original?.key == "G01-S007")
  #expect(trial.commander.galaxy == 0 && trial.commander.system == 7)
  try ScriptProcurementFixture.requirePaidG03Preparation(trial)
  #expect(trial.commander.cargo == before.commander.cargo)
  #expect(trial.commander.scriptState.instances.isEmpty && trial.commander.contracts.boards.isEmpty)
  #expect(
    !trial.nativeMainStationDockEvidenceIsCurrent && trial.commander.flightSimulation.player != nil)
  await runtime.key("trial-restart")
  let restarted = await runtime.snapshot()
  #expect(restarted.isMissionTrial && !restarted.docked && restarted.screen.isFlight)
  #expect(
    restarted.commander.scriptState.instances.isEmpty
      && restarted.commander.contracts.boards.isEmpty)
  try ScriptProcurementFixture.requirePaidG03Preparation(restarted)
  #expect(restarted.commander.cargo == trial.commander.cargo)
  #expect(restarted.commander.equipmentOwnerID != trial.commander.equipmentOwnerID)
  let initialTransactions = trial.commander.equipmentPurchaseHistory?.paid.map(\.transaction)
  let restartedTransactions = restarted.commander.equipmentPurchaseHistory?.paid.map(\.transaction)
  #expect(initialTransactions != restartedTransactions)
  try await runtime.returnFromScriptGalleryTrial()
  let restored = await runtime.snapshot()
  let after = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  #expect(restored.commander == before.commander && files == after)
}

@Test func freightGenuineAbandonmentRejectsPairedFutureSettlement() async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, _) = try await fixture.accepted(row: 1)
  await runtime.key("contacts-open")
  try await ScriptFreightFixture.confirm(runtime)
  let genuine = await runtime.snapshot()
  let state = try #require(genuine.commander.scriptState.instances[id])
  try #require(state.savedOwnedCargo?.terminal?.cause == .abandoned)
  try #require(genuine.commander.valid && genuine.commander.freightCargoValid)
  let future = genuine.commander.scriptState.clock(.missionCalendar) + 1
  let due = try #require(state.contract?.deadline)
  try #require(future <= due)
  let changed = try ScriptFreightFixture.forgedState(genuine, id: id) { object in
    var job = object["contract"] as! [String: Any]
    var cargo = object["savedOwnedCargo"] as! [String: Any]
    var terminal = cargo["terminal"] as! [String: Any]
    job["settledAt"] = future
    terminal["clock"] = future
    cargo["terminal"] = terminal
    object["contract"] = job
    object["savedOwnedCargo"] = cargo
  }
  try await fixture.rejectForgedState(changed, genuine: genuine, runtime: runtime)
}

@Test(arguments: ["revision", "committed-context"])
func freightGenuineFinalReceiptRejectsDifferentTransferTransaction(field: String) async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let (runtime, id, plan) = try await fixture.accepted()
  try await ScriptProcurementFixture.travel(runtime, path: plan.path)
  await runtime.key("contacts-open")
  try await ScriptFreightFixture.confirm(runtime)
  let completed = await runtime.snapshot()
  let final = try #require(completed.commander.scriptState.instances[id])
  let receipt = try #require(final.completionReceipt)
  let lot = try #require(final.collections[plan.template.id]?.lots[receipt.sequence])
  try #require(final.outcome == .complete && lot.revision == receipt.revision)
  try #require(lot.committed == receipt.committed && completed.commander.freightCargoValid)
  if field == "committed-context" {
    // Obtain a real later arrival; do not fabricate a native dock receipt.
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
  }
  try await runtime.save(to: fixture.save)
  let genuine = await runtime.snapshot()
  try #require(genuine.commander.valid && genuine.commander.freightCargoValid)
  let later = genuine.scriptEventContext(final)
  if field == "committed-context" {
    try #require(later.nativeMainDock != receipt.committed.nativeMainDock)
    try #require(genuine.commander.freightHistoricalContextValid(later, requiresDock: true))
  }
  let encodedContext = try JSONEncoder().encode(later)
  let decodedContext = try JSONSerialization.jsonObject(with: encodedContext)
  let contextObject = try #require(decodedContext as? [String: Any])
  let changed = try ScriptFreightFixture.forgedState(genuine, id: id) { object in
    var completion = object["completionReceipt"] as! [String: Any]
    if field == "revision" {
      let revision = (object["revision"] as! NSNumber).uint64Value + 1
      var committed = completion["committed"] as! [String: Any]
      object["revision"] = revision
      completion["revision"] = revision
      committed["revision"] = revision
      completion["committed"] = committed
    } else {
      completion["committed"] = contextObject
    }
    object["completionReceipt"] = completion
  }
  try await fixture.rejectForgedState(changed, genuine: genuine, runtime: runtime)
}
