import Foundation
import Testing

@testable import L337Core

private let originalColdChainDigest =
  "28d0072262956e974bc2033f8b0e984e1b35780a98b6861a1a81b4ca43c7487f"

private struct OriginalColdChainFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  var save: URL { files.save }

  init(shortExpiryFixture: Bool = false) throws {
    files = try ScriptFreightFixture()
    if shortExpiryFixture {
      // Separate native expiry fixture, never production tuning or a production clue pin.
      let folder = files.root.appendingPathComponent("short-expiry")
      try FileManager.default.copyItem(at: ScriptPackLibrary.bundledColdChainDirectory, to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
        .replacingOccurrences(of: "flightAllowance = 2700", with: "flightAllowance = 0.2")
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      pack = try ScriptPackLibrary.read(folder)
    } else {
      pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledColdChainDirectory)
    }
  }

  func runtime(escapeReady: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame(escapeReady: escapeReady)
    game.commander.system = 85
    game.selectedSystem = 85
    game.market = MarketItem.at(game.currentSystem)
    game.scriptPacks = [pack]
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(pod)
      try #require(try game.applyEquipmentPurchase(quote))
    }
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return runtime
  }

  func review(
    _ runtime: GameRuntime,
    matching predicate: (WayfarerColdChainBoardAction) -> Bool
  ) async throws -> WayfarerColdChainBoardReview {
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(
      board.rows.firstIndex { row in
        row.coldChain.map { predicate($0.action) } == true
      })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let game = await runtime.snapshot()
    try #require(game.contractBoard.detail && game.contractBoard.action == .back)
    return try #require(game.contractBoard.coldChainQuote)
  }

  func confirm(_ runtime: GameRuntime) async {
    await runtime.key("right")
    await runtime.key("return")
  }

  func pickup(_ runtime: GameRuntime) async throws -> (UUID, WayfarerColdChainOffer) {
    let review = try await review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    try #require(review.allowed, Comment(rawValue: review.issues.joined(separator: "; ")))
    let offer = try #require(review.offer)
    await confirm(runtime)
    let id = ScriptIdentity.uuid("wayfarer-service-v1:" + offer.stockUnit.uuidString)
    try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.savedWayfarerColdChain != nil)
    return (id, offer)
  }

  func arrive(_ runtime: GameRuntime) async throws {
    let snapshot = await runtime.snapshot()
    if snapshot.screen == .contracts {
      if snapshot.contractBoard.detail { await runtime.key("escape") }
      await runtime.key("escape")
    }
    try await ScriptProcurementFixture.travel(runtime, path: [85, 241], verifyDeparture: true)
  }

  func objective(_ runtime: GameRuntime, id: UUID) async throws {
    let quote = try await review(runtime) { $0 == .objective(id) }
    try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
    await confirm(runtime)
    try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.savedWayfarerColdChain?
        .objective != nil)
  }

  func receive(_ runtime: GameRuntime, id: UUID) async throws {
    let quote = try await review(runtime) { $0 == .receive(id) }
    try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
    await confirm(runtime)
    try #require(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  }
}

struct OriginalColdChainTests {
  @Test func productionResourcePinsNativeTermsAndDeduplicatesItsExactDigest() throws {
    let fixture = try OriginalColdChainFixture()
    defer { fixture.files.clean() }
    let pack = fixture.pack
    #expect(pack.digest == originalColdChainDigest)
    #expect(pack.manifest.stateID == WayfarerColdChainDefinition.stateID)
    let terms = try #require(pack.manifest.coldChain)
    #expect(
      terms.source.system == 85 && terms.objective.system == 241 && terms.receiver.system == 241)
    #expect(terms.route == [85, 241] && terms.stockUnits == 6 && terms.tonnes == 1)
    #expect(terms.maximumActive == 3 && terms.hazardTier == 0)
    #expect(terms.rewardNative == 4050 && terms.flightAllowance == 2700)
    #expect(pack.manifest.board == nil && (pack.manifest.dialogs ?? []).isEmpty)
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    game.commander.system = 85
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    let distance = game.systems[85].distance(to: game.systems[241])
    #expect(abs(distance - 1.9749526627238416) < 1e-10)
    #expect(distance < game.commander.maximumJumpDistance)
    #expect(game.commander.jumpFuelCost(distance: distance) == 20)
    let installed = fixture.files.root.appendingPathComponent("installed")
    _ = try ScriptPackLibrary.install(pack, directory: installed)
    let library = ScriptPackLibrary.defaultLibrary(directory: installed)
    #expect(library.errors.isEmpty && library.packs.filter { $0.digest == pack.digest }.count == 1)
    #expect(library.packs.first?.digest == pack.digest)
  }

  @Test func actualSourceBoardBackReopenRedockAndReloadKeepStockIdentity() async throws {
    let fixture = try OriginalColdChainFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let review = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    try #require(review.allowed)
    let offer = try #require(review.offer)
    let before = await runtime.snapshot()
    let details = Display.contractDetailRows(before, width: before.viewportWidth).joined(
      separator: "\n")
    #expect(
      details.contains("Cedamar") && details.contains("Celalen") && details.contains("405.0 CR"))
    #expect(details.contains("2700") && details.contains("passenger berths: 0"))
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == before.commander)
    let reopened = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    #expect(reopened.row.key == review.row.key && reopened.offer?.id == offer.id)
    await runtime.key("escape")
    await runtime.key("escape")
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    let redocked = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    #expect(redocked.row.key == review.row.key && redocked.offer?.id != offer.id)
    await #expect(throws: (any Error).self) {
      try await runtime.pickUpWayfarerColdChain(sourceID: offer.sourceID, quotedOfferID: offer.id)
    }
    let current = try #require(redocked.offer)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    if await runtime.snapshot().paused { await runtime.key("pause") }
    let loaded = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    #expect(loaded.row.key == review.row.key && loaded.offer?.id != current.id)
    await #expect(throws: (any Error).self) {
      try await runtime.pickUpWayfarerColdChain(
        sourceID: current.sourceID, quotedOfferID: current.id)
    }
    let after = await runtime.snapshot()
    #expect(
      after.commander.scriptState.savedWayfarerColdChainStock
        == before.commander.scriptState.savedWayfarerColdChainStock)
    #expect(after.commander.scriptState.instances.isEmpty)
  }

  @Test func actualPickupWriterRollbackAndSharedCapacityUseOriginalUnits() async throws {
    let fixture = try OriginalColdChainFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let review = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("pickup")
    await fixture.confirm(runtime)
    #expect(await runtime.snapshot().commander == before.commander)
    try fixture.files.restoreWrites(blocked, files: disk)
    // A capacity-only input checks the UI read guard; it is not claimed as a native cargo purchase.
    var full = before
    full.commander.cargo[0] = full.commander.standardCargoCapacity
    #expect(!full.wayfarerColdChainReview(review.row).allowed)
    var units: Set<UUID> = []
    for _ in 0..<3 {
      let (id, offer) = try await fixture.pickup(runtime)
      #expect(units.insert(offer.stockUnit).inserted)
      #expect(
        await runtime.snapshot().commander.scriptState.instances[id]?.payloads[
          WayfarerColdChainDefinition.payloadKey] == 1)
    }
    let fullGame = await runtime.snapshot()
    #expect(OriginalServiceReservationPolicy.activeCount(fullGame.commander.scriptState) == 3)
    let fourth = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    #expect(!fourth.allowed && fourth.issues.contains { $0.contains("Three Original") })
    await fixture.confirm(runtime)
    #expect(await runtime.snapshot().commander == fullGame.commander)
    #expect(fullGame.commander.credits == before.commander.credits)
  }

  @Test func actualObjectiveAndReceiverPayExactProductionClueOnceAcrossTwoSamples() async throws {
    let fixture = try OriginalColdChainFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (first, _) = try await fixture.pickup(runtime)
    let (second, _) = try await fixture.pickup(runtime)
    let atSource = await runtime.snapshot()
    let unavailable = try await fixture.review(runtime) { $0 == .objective(first) }
    #expect(!unavailable.allowed)
    await runtime.key("escape")
    await runtime.key("escape")
    await #expect(throws: (any Error).self) {
      try await runtime.receiveWayfarerColdChain(instance: first)
    }
    try await fixture.arrive(runtime)
    let before = await runtime.snapshot()
    try await fixture.objective(runtime, id: first)
    let objective = await runtime.snapshot()
    #expect(objective.commander.credits == before.commander.credits)
    #expect(objective.commander.scriptState.savedClueJournal == nil)
    try await fixture.receive(runtime, id: first)
    let paid = await runtime.snapshot()
    let award = try #require(
      paid.commander.scriptState.savedClueJournal?.awards[WayfarerColdChainDefinition.stateID])
    #expect(award.clueID == "exchange-service-cold-chain" && award.completion.instance == first)
    #expect(
      ScriptClueTrustCatalog.production.pin(for: award.completion)?.digest
        == originalColdChainDigest)
    #expect(
      paid.message.contains("SENN:") && paid.commander.credits == before.commander.credits + 4050)
    try await fixture.objective(runtime, id: second)
    try await fixture.receive(runtime, id: second)
    let repeated = await runtime.snapshot()
    #expect(repeated.commander.credits == before.commander.credits + 8100)
    #expect(repeated.commander.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      repeated.commander.scriptState.savedClueJournal?.awards[WayfarerColdChainDefinition.stateID]?
        .completion == award.completion)
    #expect(repeated.commander.scriptState.instances[first]?.payloads.isEmpty == true)
    #expect(atSource.commander.scriptState.instances[first]?.contract == nil)
    await #expect(throws: (any Error).self) {
      try await runtime.receiveWayfarerColdChain(instance: first)
    }
    #expect(await runtime.snapshot().commander.credits == repeated.commander.credits)
  }

  @Test func actualReceiverWriterFailureRollsBackPaymentCustodyAndAcknowledgement() async throws {
    let fixture = try OriginalColdChainFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, _) = try await fixture.pickup(runtime)
    try await fixture.arrive(runtime)
    try await fixture.objective(runtime, id: id)
    let quote = try await fixture.review(runtime) { $0 == .receive(id) }
    try #require(quote.allowed)
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("receiver")
    await fixture.confirm(runtime)
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && !refused.message.contains("SENN:"))
    try fixture.files.restoreWrites(blocked, files: disk)
    try await fixture.receive(runtime, id: id)
    let after = await runtime.snapshot()
    #expect(after.commander.credits == before.commander.credits + 4050)
    #expect(after.commander.scriptState.savedClueJournal?.awards.count == 1)
  }

  @Test func actualLossUsesNewFiniteStockAndExhaustedBatchNeverReplenishes() async throws {
    let fixture = try OriginalColdChainFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(escapeReady: true)
    var lost: Set<UUID> = []
    var source = ""
    for _ in 0..<3 {
      let (id, offer) = try await fixture.pickup(runtime)
      lost.insert(id)
      source = offer.sourceID
    }
    let before = await runtime.snapshot()
    await runtime.key("escape")
    await runtime.key("0")
    await runtime.key("escape-pod")
    let failed = await runtime.snapshot()
    #expect(lost.allSatisfy { failed.commander.scriptState.instances[$0]?.outcome == .failed })
    #expect(
      failed.commander.credits == before.commander.credits
        && failed.commander.scriptState.savedClueJournal == nil)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    var retry: [UUID] = []
    for _ in 0..<3 {
      let (id, offer) = try await fixture.pickup(runtime)
      #expect(!lost.contains(id) && offer.flightAllowance == 2700)
      retry.append(id)
    }
    try await fixture.arrive(runtime)
    for id in retry {
      try await fixture.objective(runtime, id: id)
      try await fixture.receive(runtime, id: id)
    }
    await runtime.key("escape")
    try await ScriptProcurementFixture.travel(runtime, path: [241, 85], verifyDeparture: true)
    await runtime.key("contracts-open")
    let exhausted = await runtime.snapshot()
    let stock = try #require(
      exhausted.commander.scriptState.savedWayfarerColdChainStock?.sources[source])
    #expect(stock.units.count == 6 && stock.units.values.allSatisfy { $0.status != .available })
    #expect(stock.units.values.filter { $0.status == .failed }.count == 3)
    #expect(stock.units.values.filter { $0.status == .received }.count == 3)
    _ = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(
      await runtime.snapshot().commander.scriptState.savedWayfarerColdChainStock?.sources[source]
        == stock)
    await #expect(throws: (any Error).self) {
      try await runtime.wayfarerColdChainQuote(sourceID: source)
    }
  }

  @Test func actualSuspendedExpiryBoardRetryRecordsOriginalEventWithoutRestock() async throws {
    let fixture = try OriginalColdChainFixture(shortExpiryFixture: true)
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, offer) = try await fixture.pickup(runtime)
    await runtime.key("escape")
    await runtime.key("0")
    let disk = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("expiry")
    for _ in 0..<8 { _ = await runtime.advance(delta: 0.1) }
    let suspended = await runtime.snapshot()
    let state = try #require(suspended.commander.scriptState.instances[id])
    let event = try #require(
      WayfarerColdChainSave.pendingExpiry(state, engine: suspended.commander.scriptState))
    try #require(state.outcome == .active && state.suspension != nil)
    try fixture.files.restoreWrites(blocked, files: disk)
    try await ScriptProcurementFixture.dock(runtime)
    let review = try await fixture.review(runtime) { $0 == .retryExpiry(id) }
    try #require(review.allowed)
    await fixture.confirm(runtime)
    let after = await runtime.snapshot()
    let failed = try #require(after.commander.scriptState.instances[id])
    #expect(failed.outcome == .failed && failed.suspension == nil)
    #expect(failed.completionReceipt?.sequence == event.sequence)
    #expect(failed.payloads.isEmpty && after.commander.scriptState.savedClueJournal == nil)
    let stock = try #require(
      after.commander.scriptState.savedWayfarerColdChainStock?.sources[offer.sourceID])
    #expect(stock.units.count == 6 && stock.units[offer.stockUnit.uuidString]?.status == .failed)
    let next = try await fixture.review(runtime) {
      if case .pickup = $0 { return true }
      return false
    }
    #expect(next.offer?.stockUnit != offer.stockUnit)
  }

  @Test func actualPauseAndNormalAlienRoundTripsPreserveOriginalBudget() async throws {
    let fixture = try OriginalColdChainFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let (id, _) = try await fixture.pickup(runtime)
    await runtime.key("escape")
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    let remaining = try await runtime.wayfarerColdChainRemaining(instance: id)
    #expect(remaining > 0 && remaining < 2700)
    await runtime.key("pause")
    for _ in 0..<3 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await runtime.wayfarerColdChainRemaining(instance: id) == remaining)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(try await runtime.wayfarerColdChainRemaining(instance: id) == remaining)
    var game = await runtime.snapshot()
    let owner = try #require(game.commander.equipmentOwnerID)
    // Empty-Alien storage composition supplies no invented acquisition or flight receipt.
    try game.commander.replaceAlienStorage(
      with: .init(
        owner: owner, revision: 0, worldRevision: 0, world: [], sources: [], attachments: [],
        upgrades: [], receipts: [], commands: []))
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let alien = fixture.files.root.appendingPathComponent("alien/commander.json")
    try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: alien)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: alien), from: alien)
    #expect(cold.usesAlienStorageSaveVersion && world.consistent(with: cold))
    #expect(
      cold.scriptState.instances[id]?.savedWayfarerColdChain
        == prepared.commander.scriptState.instances[id]?.savedWayfarerColdChain)
  }
}
