import Foundation
import Testing

@testable import EliteCore

private let originalBondedDigest =
  "08dfba917d8f630b0fb39a4458ec1fa06245eb1347352a172a7576c0967682ca"
private let originalBondedSource = "l337.contract/bonded-freight"

private struct OriginalBondedFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack

  init() throws {
    files = try ScriptFreightFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledBondedFreightDirectory)
  }

  func plans(_ game: Game) throws -> [ScriptFreightPlan] {
    let board = try #require(pack.manifest.board)
    let key = pack.digest + "/" + board.id + "/" + game.contractStation.key
    return try ScriptFreightGeneration.plans(
      pack: pack, commander: game.commander, origin: game.contractStation, revision: 0,
      seed: try #require(Game.pledgeBoardSeed(key, revision: 0)))
  }

  // Choose the scene and actual deterministic offer before any acceptance or journey.
  // Government is a test premise, never authority for the declared pricing premium.
  func quietScene() throws -> (Game, String, [Int]) {
    for galaxy in 0..<8 {
      let systems = Universe.systemsIncludingPlugh(number: galaxy)
      let quiet = Set(systems.filter { $0.government == 7 }.map(\.id))
      for system in systems
      where system.original != nil && system.technology >= 12 && quiet.contains(system.id) {
        var game = try ScriptProcurementFixture.freshG03FlightGame()
        game.commander.galaxy = galaxy
        game.commander.system = system.id
        game.systems = systems
        game.selectedSystem = system.id
        game.market = MarketItem.at(game.currentSystem)
        try game.prepareG03FlightEquipment()
        game.scriptPacks = [pack]
        let generated = try plans(game)
        if let selected = generated.first(where: {
          $0.path.count == 2 && $0.path.allSatisfy(quiet.contains)
        }) {
          return (game, selected.key, selected.path)
        }
      }
    }
    throw MissionPackError("No actual quiet one-leg bonded offer in the controlled initial scene.")
  }

  func runtime() async throws -> (GameRuntime, String, [Int]) {
    let (game, offer, path) = try quietScene()
    let runtime = GameRuntime(game: game, saveURL: files.save)
    try await runtime.save(to: files.save)
    let errors = await runtime.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("installed"))
    try #require(errors.isEmpty)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return (runtime, offer, path)
  }

  func accepted() async throws -> (GameRuntime, UUID, ScriptFreightPlan) {
    let (runtime, key, path) = try await runtime()
    let board = try await runtime.generateContractBoard(packDigest: pack.digest)
    let live = await runtime.snapshot()
    let offer = try #require(live.commander.contracts.boards[board]?.offers.first { $0.key == key })
    let plan = try #require(offer.freightPlan)
    try #require(plan.path == path && plan.path.allSatisfy { live.systems[$0].government == 7 })
    try #require(live.nativeMainStationDockEvidenceIsCurrent)
    let quote = await runtime.contractAcceptanceQuote(board: board, offer: offer.id)
    try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
    return (runtime, try await runtime.confirmContract(quote), plan)
  }

  func arrive(_ runtime: GameRuntime, plan: ScriptFreightPlan) async throws {
    try await ScriptProcurementFixture.travel(
      runtime, path: plan.path, verifyDeparture: true)
    let arrived = await runtime.snapshot()
    try #require(arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.commander.system == plan.path.last)
    await runtime.key("contacts-open")
    let contact = await runtime.snapshot()
    try #require(contact.scriptPresentedDialogue?.id == "freight-delivery")
  }
}

struct OriginalBondedFreightTests {
  @Test func productionResourceDeclaresExactNativeTermsAndDistinctDefaultProvider() throws {
    let fixture = try OriginalBondedFixture()
    defer { fixture.files.clean() }
    #expect(fixture.pack.digest == originalBondedDigest)
    #expect(fixture.pack.manifest.stateID == originalBondedSource)
    #expect(fixture.pack.manifest.trial == nil)
    #expect(fixture.pack.manifest.source.contains("20 October 2026"))
    let (game, _, _) = try fixture.quietScene()
    let plans = try fixture.plans(game)
    #expect(plans.count == 3)
    for (row, plan) in plans.enumerated() {
      #expect(
        plan.profile == originalBondedSource && plan.quantity == 3 && plan.commodity == .machinery)
      #expect(plan.deposit == 750 && plan.duration == 0 && plan.bondedHazardTiers == [0, 1, 2])
      #expect(plan.bondedQuote?.hazardTier == row)
      #expect(plan.reward == 4800 + 950 * (plan.path.count - 1) + 800 * row)
      #expect(plan.successPayment == plan.reward + 750)
    }
    let installed = fixture.files.root.appendingPathComponent("installed")
    _ = try ScriptPackLibrary.install(fixture.pack, directory: installed)
    let library = ScriptPackLibrary.defaultLibrary(directory: installed)
    #expect(
      library.errors.isEmpty
        && library.packs.filter { $0.digest == originalBondedDigest }.count == 1)
    #expect(library.packs.first?.digest == originalBondedDigest)
  }

  @Test func nativeReviewBackAndConfirmPreserveOriginalUnitsAndDebitBondOnce() async throws {
    let fixture = try OriginalBondedFixture()
    defer { fixture.files.clean() }
    let (runtime, offerKey, path) = try await fixture.runtime()
    let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
    let before = await runtime.snapshot()
    let offer = try #require(
      before.commander.contracts.boards[key]?.offers.first { $0.key == offerKey })
    try #require(offer.freightPlan?.path == path)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed)
    let reviewed = await runtime.snapshot()
    #expect(reviewed.commander == before.commander)
    let id = try await runtime.confirmContract(quote)
    let accepted = await runtime.snapshot()
    let state = try #require(accepted.commander.scriptState.instances[id])
    let cargo = try #require(state.savedOwnedCargo)
    #expect(cargo.held.count == 3 && Set(cargo.held).count == 3 && cargo.issued == cargo.held)
    #expect(accepted.commander.credits == before.commander.credits - 750)
    #expect(accepted.commander.cargoTonnes == before.commander.cargoTonnes + 3)
    #expect(accepted.commander.cargo == before.commander.cargo && state.contract?.deadline == nil)
    #expect(accepted.commander.scriptState.savedClueJournal == nil)
    let repeatedID = try await runtime.confirmContract(quote)
    let repeated = await runtime.snapshot()
    #expect(repeatedID == id && repeated.commander == accepted.commander)
    await runtime.key("contacts-open")
    let shown = await runtime.snapshot()
    try #require(
      shown.scriptPresentedDialogue?.id == "freight-abandon" && !shown.scriptConfirmSelected)
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    await runtime.key("return")
    let backed = await runtime.snapshot()
    #expect(backed.commander == shown.commander)
    #expect(
      try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
  }

  @Test func actualPartialThenFinalReceptionPaysRewardRefundAndOneClue() async throws {
    let fixture = try OriginalBondedFixture()
    defer { fixture.files.clean() }
    let (runtime, id, plan) = try await fixture.accepted()
    let accepted = await runtime.snapshot()
    let issued = try #require(accepted.commander.scriptState.instances[id]?.savedOwnedCargo?.issued)
    try await fixture.arrive(runtime, plan: plan)
    let arrival = await runtime.snapshot()
    try await ScriptFreightFixture.confirm(runtime)
    let partial = await runtime.snapshot()
    let first = try #require(partial.commander.scriptState.instances[id])
    #expect(first.outcome == .active && first.savedOwnedCargo?.held == Array(issued.dropFirst()))
    #expect(first.collections[plan.template.id]?.lots.count == 1)
    #expect(partial.commander.credits == arrival.commander.credits)
    #expect(partial.commander.scriptState.savedClueJournal == nil)
    await runtime.key("contacts-open")
    try await ScriptFreightFixture.confirm(runtime, all: true)
    let complete = await runtime.snapshot()
    let final = try #require(complete.commander.scriptState.instances[id])
    #expect(final.outcome == .complete && final.savedOwnedCargo?.held.isEmpty == true)
    #expect(final.savedOwnedCargo?.transfers.values.reduce(0) { $0 + $1.units.count } == 3)
    #expect(final.contract?.settlementAmount == plan.successPayment)
    #expect(complete.commander.credits == partial.commander.credits + plan.successPayment)
    let journal = try #require(complete.commander.scriptState.savedClueJournal)
    #expect(
      journal.awards.count == 1
        && journal.awards[originalBondedSource]?.clueID == "bonded-freight-family-trace")
    #expect(journal.awards[originalBondedSource]?.completion == final.completionReceipt)
    #expect(complete.commander.cargoTonnes == accepted.commander.cargoTonnes - 3)
    await runtime.key("contacts-open")
    await runtime.key("left")
    await runtime.key("return")
    let duplicate = await runtime.snapshot()
    #expect(duplicate.commander == complete.commander)
    try await runtime.save(to: fixture.files.save)
    try await runtime.load(from: fixture.files.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(cold.commander.scriptState.savedClueJournal == journal)
    #expect(cold.commander.credits == complete.commander.credits)
  }

  @Test func failedFinalWriterRollsBackCustodyPaymentAndClueBeforeRetry() async throws {
    let fixture = try OriginalBondedFixture()
    defer { fixture.files.clean() }
    let (runtime, id, plan) = try await fixture.accepted()
    try await fixture.arrive(runtime, plan: plan)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let preserved = try fixture.files.blockWrites("bonded-final")
    try await ScriptFreightFixture.confirm(runtime, all: true)
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.commander.scriptState.savedClueJournal == nil)
    try fixture.files.restoreWrites(preserved, files: files)
    let shown = await runtime.snapshot()
    if shown.selectedScriptChoice?.id != "freight-all" { await runtime.key("down") }
    if !shown.scriptConfirmSelected { await runtime.key("left") }
    await runtime.key("return")
    let retried = await runtime.snapshot()
    #expect(retried.commander.scriptState.instances[id]?.outcome == .complete)
    #expect(retried.commander.credits == before.commander.credits + plan.successPayment)
    let bytes = try Data(contentsOf: fixture.files.save)
    let (cold, world) = try ScriptSaveStore.read(bytes, from: fixture.files.save)
    #expect(cold.scriptState.savedClueJournal == retried.commander.scriptState.savedClueJournal)
    #expect(cold.scriptState.instances[id] == retried.commander.scriptState.instances[id])
    #expect(world.consistent(with: cold))
  }

  @Test func actualAbandonmentForfeitsBondAndNewOfferCannotReuseOriginalUnits() async throws {
    let fixture = try OriginalBondedFixture()
    defer { fixture.files.clean() }
    let (runtime, id, _) = try await fixture.accepted()
    let accepted = await runtime.snapshot()
    let issued = try #require(accepted.commander.scriptState.instances[id]?.savedOwnedCargo?.issued)
    await runtime.key("contacts-open")
    try await ScriptFreightFixture.confirm(runtime)
    let abandoned = await runtime.snapshot()
    let terminal = try #require(abandoned.commander.scriptState.instances[id])
    #expect(terminal.outcome == .abandoned && terminal.contract?.settlementAmount == 0)
    #expect(terminal.savedOwnedCargo?.terminal?.removed == issued)
    #expect(abandoned.commander.credits == accepted.commander.credits)
    #expect(abandoned.commander.scriptState.savedClueJournal == nil)
    let boardKey = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
    let available = await runtime.snapshot()
    let board = try #require(available.commander.contracts.boards[boardKey])
    let offer = try #require(board.offers.first { $0.status == .available })
    let quote = await runtime.contractAcceptanceQuote(board: boardKey, offer: offer.id)
    try #require(quote.allowed)
    let next = try await runtime.confirmContract(quote)
    let repeated = await runtime.snapshot()
    let nextUnits = try #require(
      repeated.commander.scriptState.instances[next]?.savedOwnedCargo?.issued)
    #expect(next != id && Set(nextUnits).isDisjoint(with: issued))
    #expect(repeated.commander.scriptState.instances[id] == terminal)
  }

  @Test func exactProductionPinAndNormalAlienEnvelopesUseActualCompletion() async throws {
    let fixture = try OriginalBondedFixture()
    defer { fixture.files.clean() }
    let (runtime, id, plan) = try await fixture.accepted()
    try await fixture.arrive(runtime, plan: plan)
    try await ScriptFreightFixture.confirm(runtime, all: true)
    let complete = await runtime.snapshot()
    let receipt = try #require(complete.commander.scriptState.instances[id]?.completionReceipt)
    #expect(ScriptClueTrustCatalog.production.pin(for: receipt)?.sourceID == originalBondedSource)
    // Mutated codec inputs test pin rejection; they are never installed as native completions.
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
    for (field, value) in [
      ("definition", "l337.courier/other"), ("version", "1.0.1"),
      ("digest", String(repeating: "0", count: 64)), ("causeKind", "mission.accepted"),
    ] {
      var changed = object
      changed[field] = value
      let foreign = try JSONDecoder().decode(
        ScriptCompletionReceipt.self, from: JSONSerialization.data(withJSONObject: changed))
      #expect(ScriptClueTrustCatalog.production.pin(for: foreign) == nil)
    }
    for alien in [false, true] {
      var game = complete
      if alien {
        let owner = try #require(game.commander.equipmentOwnerID)
        // Empty storage composition adds no acquisition, collector or docking authority.
        try game.commander.replaceAlienStorage(
          with: .init(
            owner: owner, revision: 0, worldRevision: 0, world: [], sources: [], attachments: [],
            upgrades: [], receipts: [], commands: []))
      }
      let prepared = try GameRuntime.prepareNativeSaveState(game)
      let save = fixture.files.root.appendingPathComponent(
        alien ? "alien/commander.json" : "normal/commander.json")
      try ScriptSaveStore.write(
        commander: prepared.commander, world: prepared.game.scriptWorldSave, to: save)
      let bytes = try Data(contentsOf: save)
      let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
      #expect(pointer.schemaVersion == (alien ? 32 : 31))
      let (cold, world) = try ScriptSaveStore.read(bytes, from: save)
      #expect(cold.scriptState.savedClueJournal == complete.commander.scriptState.savedClueJournal)
      #expect(
        cold.scriptState.instances[id]?.completionReceipt == receipt && world.consistent(with: cold)
      )
    }
  }
}
