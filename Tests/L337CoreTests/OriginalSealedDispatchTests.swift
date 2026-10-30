import Foundation
import Testing

@testable import L337Core

private func dispatchCurrentEnvelopes(_ game: consuming Game, root: URL) throws {
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  let normal = root.appendingPathComponent("normal-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: normal)
  let (loaded, world) = try ScriptSaveStore.read(Data(contentsOf: normal), from: normal)
  #expect(world.consistent(with: loaded) && loaded.scriptState == prepared.commander.scriptState)
  var alien = game
  let owner = try #require(alien.commander.equipmentOwnerID)
  // Empty storage proves current envelope composition, not Alien acquisition.
  try alien.commander.replaceAlienStorage(
    with: .init(
      owner: owner, revision: 0, worldRevision: 0, world: [], sources: [], attachments: [],
      upgrades: [], receipts: [], commands: []))
  let adapted = try GameRuntime.prepareNativeSaveState(alien)
  let url = root.appendingPathComponent("alien-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: adapted.commander, world: adapted.game.scriptWorldSave, to: url)
  let (cold, coldWorld) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
  #expect(cold.usesAlienStorageSaveVersion && coldWorld.consistent(with: cold))
  #expect(cold.scriptState == adapted.commander.scriptState)
  #expect(ScriptClueVersionedSave.validateClaims(cold, trust: .production))
}

struct OriginalSealedDispatchTests {
  @Test func defaultDispatchBoardBackRealTonneAndStaleAcceptancePreserveProperty() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
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
    #expect(quote.allowed && shown.contractBoard.detail && shown.contractBoard.action == .back)
    let detail = Display.contractDetailRows(shown, width: shown.viewportWidth).joined(
      separator: "\n")
    #expect(detail.contains("Untimed") && detail.contains("1t") && detail.contains("H0"))
    #expect(!detail.contains("PROJECT ESTIMATES") && !detail.contains("headroom"))
    #expect(
      shown.contractBoard.rows.filter { $0.board.hasPrefix(fixture.pack.digest + "/") }.count == 3)
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == shown.commander)
    await runtime.nativeCommand { game in
      game.commander.cargo[0] = game.commander.standardCargoCapacity
    }
    let full = await runtime.contractAcceptanceQuote(board: quote.board, offer: quote.offer)
    #expect(!full.allowed)
    let before = await runtime.snapshot()
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == before.commander)
    await runtime.nativeCommand { game in game.commander.cargo[0] -= 1 }
    let one = await runtime.contractAcceptanceQuote(board: quote.board, offer: quote.offer)
    #expect(one.allowed)
    let id = try await runtime.confirmContract(one)
    let accepted = await runtime.snapshot()
    #expect(accepted.commander.cargoTonnes == accepted.commander.standardCargoCapacity)
    #expect(
      accepted.commander.scriptState.instances[id]?.courier != nil && accepted.commander.valid)
    let again = try await runtime.confirmContract(one)
    let duplicate = await runtime.snapshot()
    #expect(again == id && duplicate.commander == accepted.commander)
  }

  @Test func dispatchWriterRollbackRetryAndRepeatSuccessKeepOneClue() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (key, offer) = try await fixture.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("issue")
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == before.commander)
    try fixture.files.restoreWrites(blocked, files: disk)
    let id = try await runtime.confirmContract(quote)
    let terms = try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    try await fixture.contact(runtime, action: "Deliver")
    await runtime.key("left")
    let ready = await runtime.snapshot()
    let original = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let held = try fixture.files.blockWrites("receive")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(
      refused.commander == ready.commander
        && refused.scriptPresentedDialogue == ready.scriptPresentedDialogue)
    #expect(
      refused.scriptCourierAdmission == nil && refused.commander.scriptState.savedClueJournal == nil
    )
    try fixture.files.restoreWrites(held, files: original)
    await runtime.key("return")
    let paid = await runtime.snapshot()
    let award = try #require(
      paid.commander.scriptState.savedClueJournal?.awards[OriginalSealedDispatch.stateID])
    #expect(paid.commander.credits == ready.commander.credits + terms.reward)
    try dispatchCurrentEnvelopes(paid, root: fixture.files.root)
    // A distinct native offer at the actual new source issues a new item, never the delivered original.
    let second = try await fixture.accept(runtime)
    #expect(second != id)
    let next = try #require(
      await runtime.snapshot().commander.scriptState.instances[second]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: next.path)
    try await fixture.contact(runtime, action: "Deliver")
    await fixture.confirm(runtime)
    let repeated = await runtime.snapshot()
    #expect(repeated.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      repeated.commander.scriptState.savedClueJournal?.awards[OriginalSealedDispatch.stateID]?
        .completion == award.completion)
    #expect(
      repeated.commander.scriptState.instances[second]?.outcome == .complete
        && repeated.commander.valid)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == repeated.commander)
  }

  @Test func dispatchSharesCurrentEnvelopeAndThreeSlotsWithExistingWayfarerServices() async throws {
    let relief = try OriginalMutualContributionFixture()
    defer { relief.files.clean() }
    let dispatch = try OriginalSealedDispatchFixture()
    defer { dispatch.files.clean() }
    let runtime = try await relief.runtime(mixedServices: true)
    await runtime.nativeCommand { game in
      game.scriptPacks.append(dispatch.pack)
      if let tutorial = try? ScriptPackLibrary.read(
        ScriptPackLibrary.bundledNavigationTradeDirectory)
      {
        game.scriptPacks.append(tutorial)
      }
    }
    _ = try await relief.donate(runtime)
    let packs = await runtime.snapshot().scriptPacks
    let clinic = try #require(
      packs.first { $0.manifest.stateID == WayfarerColdChainDefinition.stateID })
    let repair = try #require(
      packs.first { $0.manifest.stateID == WayfarerRepairLoopDefinition.stateID })
    #expect(packs.contains { $0.manifest.stateID == "l337.wayfarer-service/seed-transfer" })
    #expect(packs.contains { $0.digest == ScriptNavigationTradeContent.digest })
    let clinicSource = try await runtime.initializeWayfarerColdChainStock(packDigest: clinic.digest)
    let clinicOffer = try await runtime.wayfarerColdChainQuote(sourceID: clinicSource)
    _ = try await runtime.pickUpWayfarerColdChain(
      sourceID: clinicSource, quotedOfferID: clinicOffer.id)
    let repairSource = try await runtime.initializeWayfarerRepairLoopStock(
      packDigest: repair.digest)
    let repairOffer = try await runtime.wayfarerRepairLoopQuote(sourceID: repairSource)
    _ = try await runtime.pickUpWayfarerRepairLoop(
      sourceID: repairSource, quotedOfferID: repairOffer.id)
    let id = try await dispatch.accept(runtime)
    let game = await runtime.snapshot()
    #expect(game.commander.scriptState.instances[id]?.courier != nil)
    #expect(OriginalServiceReservationPolicy.activeCount(game.commander.scriptState) == 3)
    #expect(throws: MissionPackError.self) {
      try OriginalServiceReservationPolicy.requireAvailableSlot(game.commander.scriptState)
    }
    try dispatchCurrentEnvelopes(game, root: relief.files.root)
    try await runtime.save(to: relief.save)
    try await runtime.load(from: relief.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == game.commander)
  }

  @Test func dispatchWrongContactStaleTokenAndCurrentSaveCorruptionCannotConsumeOriginal()
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(defaults: true)
    let id = try await fixture.accept(runtime)
    try await fixture.contact(runtime, action: "Abandon")
    let game = await runtime.snapshot()
    let shown = try #require(game.scriptPresentedDialogue)
    var stale = shown
    stale.token = "forged:" + shown.token
    var candidate = game
    #expect(throws: (any Error).self) { try candidate.confirmCourierDialogue(id, dialogue: stale) }
    #expect(candidate.commander == game.commander)
    var wrong = shown
    wrong.id = OriginalSealedDispatch.definition.deliveryContact
    #expect(throws: (any Error).self) { try candidate.confirmCourierDialogue(id, dialogue: wrong) }
    #expect(candidate.commander == game.commander)
    try dispatchCurrentEnvelopes(game, root: fixture.files.root)
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
    let folder = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
    let file = folder.appendingPathComponent("missions.json")
    let bytes = try Data(contentsOf: file)
    defer { try? bytes.write(to: file) }
    for field in ["custody", "payload"] {
      var engine = game.commander.scriptState
      if field == "custody" {
        engine.instances[id]?.courier = nil
      } else {
        engine.instances[id]?.payloads.removeValue(forKey: ScriptCourierCustody.payloadKey)
      }
      let corrupted = try ScriptValueStorage.encoder().encode(engine)
      try corrupted.write(to: file)
      var hashes = pointer.hashes
      hashes["missions.json"] = ScriptPackLibrary.hash(corrupted)
      let rehashed = ScriptSavePointer(
        format: pointer.format, schemaVersion: pointer.schemaVersion,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: SaveError.self) {
        try ScriptSaveStore.read(JSONEncoder().encode(rehashed), from: fixture.save)
      }
      try bytes.write(to: file)
    }
  }
}
