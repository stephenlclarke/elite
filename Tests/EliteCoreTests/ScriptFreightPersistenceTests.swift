import Foundation
import Testing

@testable import EliteCore

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
  #expect(trial.commander.scriptState.instances.isEmpty && trial.commander.contracts.boards.isEmpty)
  #expect(
    !trial.nativeMainStationDockEvidenceIsCurrent && trial.commander.flightSimulation.player != nil)
  try await runtime.returnFromScriptGalleryTrial()
  let restored = await runtime.snapshot()
  let after = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  #expect(restored.commander == before.commander && files == after)
}
