import Foundation
import Testing

@testable import L337Core

struct OriginalConsentedFreightSupplyFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }
  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledConsentedFreightDirectory)
  }
  func runtime(defaults: Bool = false, escapeReady: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame(escapeReady: escapeReady)
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(pod)
      let bought = try game.applyEquipmentPurchase(quote)
      try #require(bought)
    }
    game.scriptPacks = defaults ? [] : [pack]
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    if defaults {
      let errors = await runtime.loadDefaultScriptPacks(
        directory: files.root.appendingPathComponent("installed"))
      try #require(errors.isEmpty)
    }
    await runtime.key("0")
    try await flight.dock(runtime)
    return runtime
  }
  func offer(_ runtime: GameRuntime) async throws -> (String, ScriptContractOffer) {
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    let offers = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers)
    try #require(offers.count == 1)
    return (key, offers[0])
  }
  func accept(_ runtime: GameRuntime) async throws -> UUID {
    let (key, offer) = try await offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed, "\(quote.issues)")
    return try await runtime.confirmContract(quote)
  }
  func receiver(_ runtime: GameRuntime, id: UUID) async throws {
    let plan = try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.freightPlan)
    try await flight.travel(runtime, path: plan.path)
    try #require(await runtime.snapshot().commander.system == 185)
  }
  func receive(_ runtime: GameRuntime, all: Bool = false) async throws {
    await runtime.key("contacts-open")
    let shown = await runtime.snapshot()
    try #require(shown.scriptPresentedDialogue?.id == "freight-delivery")
    try await ScriptFreightFixture.confirm(runtime, all: all)
  }
  func partialSeven(_ runtime: GameRuntime, id: UUID) async throws {
    try await receiver(runtime, id: id)
    for _ in 0..<7 { try await receive(runtime) }
    let state = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    try #require(state.savedOwnedCargo?.held.count == 1 && state.outcome == .active)
  }
  func returnSource(_ runtime: GameRuntime) async throws {
    await runtime.procurementRefuel()
    try await flight.travel(runtime, path: [185, 7])
  }
  func stock(_ game: borrowing Game) throws -> OriginalConsentedFreightSupplySource {
    let stock = try #require(game.commander.scriptState.savedOriginalConsentedFreightSupply)
    return try #require(stock.sources[OriginalConsentedFreightSupply.sourceKey(owner: stock.owner)])
  }
}

extension GameRuntime {
  // Controlled ordinary hold precondition; no supplied units or source allocation are manufactured.
  func supplyOrdinaryHoldFree(_ free: Int) throws {
    try scriptCommand { game in
      game.commander.cargo[CommodityIdentity.food.rawValue] =
        game.commander.standardCargoCapacity - free
    }
  }
}

struct OriginalConsentedFreightSupplyNativeTests {
  @Test func supplyProductionTermsTwoRealIssuesExhaustBatchAndKeepFirstClue() async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    #expect(f.pack.digest == OriginalConsentedFreightSupply.digest)
    let runtime = try await f.runtime()
    var ids: Set<UUID> = []
    var firstClue: ScriptClueAward?
    for index in 0..<2 {
      let id = try await f.accept(runtime)
      let accepted = await runtime.snapshot()
      let state = try #require(accepted.commander.scriptState.instances[id])
      let plan = try #require(state.contract?.offer.freightPlan)
      let cargo = try #require(state.savedOwnedCargo)
      #expect(plan.path == [7, 185] && plan.reward == (620 + 110 * (plan.path.count - 1)) * 10)
      #expect(
        plan.quantity == 8 && plan.duration == 0 && plan.deposit == 0
          && state.contract?.deadline == nil)
      #expect(ids.isDisjoint(with: cargo.issued))
      ids.formUnion(cargo.issued)
      #expect(try f.stock(accepted).remaining.count == 8 * (1 - index))
      try await f.receiver(runtime, id: id)
      try await f.receive(runtime, all: true)
      let done = await runtime.snapshot()
      #expect(done.commander.scriptState.instances[id]?.outcome == .complete)
      #expect(done.commander.credits == accepted.commander.credits + plan.reward)
      let award = try #require(
        done.commander.scriptState.savedClueJournal?.awards[OriginalConsentedFreightSupply.stateID])
      #expect(award.clueID == "consented-freight-family-trace")
      if let firstClue {
        #expect(award.completion == firstClue.completion)
      } else {
        firstClue = award
      }
      try await f.returnSource(runtime)
    }
    let exhausted = await runtime.snapshot()
    let originalUnits = try f.stock(exhausted).units
    #expect(ids.count == 16 && ids == Set(originalUnits))
    let (key, offer) = try await f.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    #expect(!quote.allowed)
    let beforeRefusal = await runtime.snapshot().commander
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == beforeRefusal)
  }

  @Test func supplySevenFreeRefusesAndEightFreeReceivesExistingOriginalIDs() async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let (key, offer) = try await f.offer(runtime)
    try await runtime.supplyOrdinaryHoldFree(7)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    let before = await runtime.snapshot().commander
    #expect(!quote.allowed)
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    #expect(
      await runtime.snapshot().commander == before
        && before.scriptState.savedOriginalConsentedFreightSupply == nil)
    try await runtime.supplyOrdinaryHoldFree(8)
    let id = try await f.accept(runtime)
    let game = await runtime.snapshot()
    let cargo = try #require(game.commander.scriptState.instances[id]?.savedOwnedCargo)
    let owner = try #require(game.commander.equipmentOwnerID)
    #expect(cargo.issued == Array(OriginalConsentedFreightSupply.unitIDs(owner: owner).prefix(8)))
    #expect(
      cargo.issued != ScriptOwnedCargoState.unitIDs(consignment: cargo.consignment, quantity: 8))
    #expect(
      game.commander.valid && OriginalConsentedFreightSupplySave.validateClaims(game.commander))
  }

  @Test func supplyStaleDoubleReinstallAndForeignAllocationCannotChangeStock() async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let (key, offer) = try await f.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    let id = try await runtime.confirmContract(quote)
    let game = await runtime.snapshot()
    let replay = try await runtime.confirmContract(quote)
    let replayed = await runtime.snapshot().commander
    #expect(replay == id && replayed == game.commander)
    let installed = f.files.root.appendingPathComponent("installed")
    _ = try ScriptPackLibrary.install(f.pack, directory: installed)
    let errors = await runtime.loadDefaultScriptPacks(directory: installed)
    #expect(errors.isEmpty)
    #expect(await runtime.snapshot().commander == game.commander)
    let plan = try #require(game.commander.scriptState.instances[id]?.contract?.offer.freightPlan)
    #expect(throws: (any Error).self) {
      try OriginalConsentedFreightSupply.allocate(plan: plan, instance: id, game: game)
    }
    var wrong = game
    wrong.commander.system = 185
    #expect(throws: (any Error).self) {
      try OriginalConsentedFreightSupply.allocate(plan: plan, instance: UUID(), game: wrong)
    }
    #expect(try f.stock(game).remaining.count == 8)
  }

  @Test func supplyBidirectionalClosureRejectsMissingOrphanCrossBatchAndDuplicateAllocations()
    async throws
  {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let id = try await f.accept(runtime)
    let game = await runtime.snapshot()
    let source = try f.stock(game)
    for mode in ["missing", "orphan", "duplicate", "foreign", "reordered"] {
      var engine = game.commander.scriptState
      if mode == "missing" {
        engine.savedOriginalConsentedFreightSupply = nil
      } else {
        var changed = source
        if mode == "orphan" {
          let units = changed.allocations.removeValue(forKey: id)
          changed.allocations[UUID()] = units
        }
        if mode == "duplicate" { changed.allocations[UUID()] = changed.allocations[id] }
        if mode == "foreign" { changed.allocations[id]?[0] = UUID() }
        if mode == "reordered" { changed.allocations[id]?.reverse() }
        engine.savedOriginalConsentedFreightSupply?.sources[source.key] = changed
      }
      #expect(!engine.valid)
    }
  }

  @Test func supplyActualReceiverSevenPartialThenEighthSettlesOriginalUnitsOnce() async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let id = try await f.accept(runtime)
    let accepted = await runtime.snapshot()
    try await f.partialSeven(runtime, id: id)
    let partial = await runtime.snapshot()
    let state = try #require(partial.commander.scriptState.instances[id])
    #expect(state.savedOwnedCargo?.transfers.count == 7 && state.conversationReceipts.count == 7)
    #expect(
      partial.commander.credits == accepted.commander.credits
        && partial.commander.scriptState.savedClueJournal == nil)
    try await f.receive(runtime)
    let done = await runtime.snapshot()
    #expect(
      done.commander.scriptState.instances[id]?.outcome == .complete
        && done.commander.credits == partial.commander.credits + 7300)
    #expect(done.commander.scriptState.savedClueJournal?.awards.count == 1)
    var replay = done
    replay.emitScriptEvent("dialogue.confirmed", only: id)
    #expect(replay.commander == done.commander)
  }

  @Test func supplySourceWriterRefusalRollsBackStockAndHoldThenRetries() async throws {
    let f = try OriginalConsentedFreightSupplyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let (key, offer) = try await f.offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("supply-source")
    await #expect(throws: (any Error).self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(held, files: files)
    _ = try await runtime.confirmContract(quote)
    #expect(try f.stock(await runtime.snapshot()).remaining.count == 8)
  }
}
