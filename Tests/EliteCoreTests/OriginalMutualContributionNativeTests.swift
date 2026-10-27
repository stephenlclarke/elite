import Foundation
import Testing

@testable import EliteCore

struct OriginalMutualContributionFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  var save: URL { files.save }
  init() throws {
    files = try ScriptFreightFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledMutualContributionDirectory)
  }
  func runtime(cash: Int = 10000, system: Int = 85, mixedServices: Bool = false) async throws
    -> GameRuntime
  {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    game.commander.system = system
    game.selectedSystem = system
    game.market = MarketItem.at(game.currentSystem)
    game.scriptPacks = [pack]
    try game.prepareG03FlightEquipment()
    game.commander.credits = cash
    if mixedServices {
      for directory in [
        ScriptPackLibrary.bundledColdChainDirectory,
        ScriptPackLibrary.bundledRepairLoopDirectory,
        ScriptPackLibrary.bundledSeedTransferDirectory,
      ] {
        game.scriptPacks.append(try ScriptPackLibrary.read(directory))
      }
    }
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return runtime
  }
  func offer(_ runtime: GameRuntime) async throws -> (String, ScriptContractOffer) {
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    let game = await runtime.snapshot()
    let board = try #require(game.commander.contracts.boards[key])
    try #require(board.offers.count == 1)
    return (key, try #require(board.offers.first))
  }
  func donate(_ runtime: GameRuntime) async throws -> UUID {
    let (key, offer) = try await offer(runtime)
    return try await runtime.confirmContract(
      runtime.contractAcceptanceQuote(board: key, offer: offer.id))
  }
}

private func mutualContributionCurrentEnvelopes(_ game: consuming Game, root: URL) throws {
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  let normal = root.appendingPathComponent("normal-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: normal)
  let (loaded, world) = try ScriptSaveStore.read(Data(contentsOf: normal), from: normal)
  #expect(world.consistent(with: loaded))
  #expect(loaded.scriptState.pledgeLedger == prepared.commander.scriptState.pledgeLedger)
  #expect(loaded.scriptState.savedClueJournal == prepared.commander.scriptState.savedClueJournal)
  #expect(ScriptClueVersionedSave.validateClaims(loaded, trust: .production))
  var alien = game
  let owner = try #require(alien.commander.equipmentOwnerID)
  // Empty storage tests current envelope composition; no Alien acquisition is claimed.
  try alien.commander.replaceAlienStorage(
    with: .init(
      owner: owner, revision: 0, worldRevision: 0,
      world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
  let adapted = try GameRuntime.prepareNativeSaveState(alien)
  let url = root.appendingPathComponent("alien-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: adapted.commander, world: adapted.game.scriptWorldSave, to: url)
  let (cold, coldWorld) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
  #expect(cold.usesAlienStorageSaveVersion && coldWorld.consistent(with: cold))
  #expect(cold.scriptState.pledgeLedger == adapted.commander.scriptState.pledgeLedger)
  #expect(cold.scriptState.savedClueJournal == adapted.commander.scriptState.savedClueJournal)
  #expect(ScriptClueVersionedSave.validateClaims(cold, trust: .production))
}

struct OriginalMutualContributionNativeTests {
  @Test func closedContributionDeclarationRejectsOtherAmountsFoodAndRecipient() throws {
    let fixture = try OriginalMutualContributionFixture()
    defer { fixture.files.clean() }
    let declaration = try #require(fixture.pack.manifest.pledge)
    #expect(OriginalMutualContribution.validManifest(fixture.pack.manifest))
    #expect(fixture.pack.digest == OriginalMutualContribution.digest)
    #expect(declaration.creditAmounts == [5000] && declaration.foodTonnes.isEmpty)
    #expect(declaration.amount(difficulty: 1, variant: .credits) == 5000)
    #expect(declaration.amount(difficulty: 2, variant: .credits) == nil)
    #expect(declaration.amount(difficulty: 1, variant: .food) == nil)
    for (index, edit) in [
      ("[5000]", "[4999]"), ("foodTonnes = []", "foodTonnes = [1]"),
      ("Cedamar Orbital Relief Reserve", "Foreign Relief Fund"),
    ].enumerated() {
      let folder = fixture.files.root.appendingPathComponent("invalid-\(index)")
      try FileManager.default.copyItem(
        at: ScriptPackLibrary.bundledMutualContributionDirectory, to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
      try text.replacingOccurrences(of: edit.0, with: edit.1).write(
        to: manifest, atomically: true, encoding: .utf8)
      #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
    }
  }

  @Test func actualFiveHundredContributionDebitsToZeroAndJoinsNativeReserveReceipt() async throws {
    let fixture = try OriginalMutualContributionFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(cash: 5000)
    let before = await runtime.snapshot()
    let id = try await fixture.donate(runtime)
    let game = await runtime.snapshot()
    let receipt = try #require(game.commander.scriptState.pledgeLedger?.receipt(instance: id))
    let state = try #require(game.commander.scriptState.instances[id])
    let completion = try #require(state.completionReceipt)
    #expect(receipt.valid(engine: game.commander.scriptState))
    #expect(
      OriginalMutualContribution.validCompletion(
        completion, engine: game.commander.scriptState,
        owner: try #require(game.commander.equipmentOwnerID)))
    #expect(
      receipt.creditedAt == OriginalMutualContribution.station
        && receipt.declaration.title == OriginalMutualContribution.recipient)
    #expect(receipt.amount == 5000 && receipt.before.cash == 5000 && receipt.after.cash == 0)
    #expect(game.commander.credits == 0 && game.commander.cargo == before.commander.cargo)
    #expect(
      state.outcome == .complete && state.contract?.settlementAmount == 0
        && state.contract?.deadline == nil)
    #expect(
      game.commander.scriptState.savedClueJournal?.awards[OriginalMutualContribution.stateID]?
        .clueID == "mutual-contribution-family-trace")
    let completed = game.commander
    let (key, offer) = try await fixture.offer(runtime)
    #expect(
      try await runtime.confirmContract(
        runtime.contractAcceptanceQuote(board: key, offer: offer.id)) == id)
    #expect(await runtime.snapshot().commander == completed)
  }

  @Test func contributionInsufficientCashWrongDockAndGenericAcceptanceCannotDonate() async throws {
    let fixture = try OriginalMutualContributionFixture()
    defer { fixture.files.clean() }
    let poor = try await fixture.runtime(cash: 4999)
    let (key, offer) = try await fixture.offer(poor)
    let before = await poor.snapshot()
    #expect(!before.contractAcceptanceQuote(board: key, offer: offer.id).allowed)
    await #expect(throws: (any Error).self) {
      try await poor.confirmContract(poor.contractAcceptanceQuote(board: key, offer: offer.id))
    }
    #expect(await poor.snapshot().commander == before.commander)
    let wrong = try await fixture.runtime(system: 241)
    let elsewhere = await wrong.snapshot()
    await #expect(throws: (any Error).self) { try await fixture.offer(wrong) }
    #expect(await wrong.snapshot().commander == elsewhere.commander)
    var generic = before
    #expect(throws: (any Error).self) { try generic.acceptScriptMission(fixture.pack) }
    #expect(generic.commander == before.commander)
  }

  @Test func strippedForgedForeignAndAcceptanceOnlyProofsCannotAwardOrValidateClue() async throws {
    let fixture = try OriginalMutualContributionFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let id = try await fixture.donate(runtime)
    let game = await runtime.snapshot()
    let state = try #require(game.commander.scriptState.instances[id])
    let completion = try #require(state.completionReceipt)
    let journal = try #require(game.commander.scriptState.savedClueJournal)
    let ledger = try #require(game.commander.scriptState.pledgeLedger)
    let original = try #require(ledger.receipt(instance: id))
    #expect(OriginalMutualContribution.cluePin.valid)
    #expect(
      !ScriptClueExecutionPin(
        sourceID: "l337.contract/bonded-freight", definition: "l337.contract/bonded-freight",
        version: "1.0.0", digest: OriginalMutualContribution.digest,
        terminalEvents: ["mission.accepted"]
      ).valid)
    #expect(
      !OriginalMutualContribution.validCompletion(
        completion,
        engine: game.commander.scriptState, owner: UUID()))
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
    let missions = directory.appendingPathComponent("missions.json")
    let originalBytes = try Data(contentsOf: missions)
    defer { try? originalBytes.write(to: missions) }
    for field in ["amount", "fund", "digest", "instance", "missing", "marker", "all-native-proof"] {
      var engine = game.commander.scriptState
      if field == "all-native-proof" {
        engine.pledgeLedger = nil
        engine.instances[id]?.pledgeReceiptID = nil
      } else if field == "missing" {
        engine.pledgeLedger = nil
      } else if field == "marker" {
        engine.instances[id]?.pledgeReceiptID = nil
      } else {
        var object = try #require(
          JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        switch field {
        case "amount": object["amount"] = 4999
        case "fund":
          var declaration = try #require(object["declaration"] as? [String: Any])
          declaration["title"] = "Foreign Relief Fund"
          object["declaration"] = declaration
        case "digest": object["digest"] = String(repeating: "a", count: 64)
        default: object["instance"] = UUID().uuidString
        }
        let changed = try JSONDecoder().decode(
          ScriptPledgeReceipt.self, from: JSONSerialization.data(withJSONObject: object))
        engine.pledgeLedger?.receipts[original.id] = changed
      }
      #expect(
        !OriginalMutualContribution.validCompletion(
          completion, engine: engine, owner: try #require(game.commander.equipmentOwnerID)))
      #expect(!journal.valid(engine: engine))
      let bytes = try ScriptValueStorage.encoder().encode(engine)
      try bytes.write(to: missions)
      var hashes = pointer.hashes
      hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
      let rehashed = ScriptSavePointer(
        format: pointer.format, schemaVersion: pointer.schemaVersion,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: SaveError.self) {
        try ScriptSaveStore.read(JSONEncoder().encode(rehashed), from: fixture.save)
      }
      try originalBytes.write(to: missions)
      var candidate = game
      candidate.commander.scriptState = engine
      candidate.commander.scriptState.savedClueJournal = nil
      var active = state
      active.outcome = .active
      #expect(throws: (any Error).self) {
        try candidate.awardScriptClue(previous: active, next: state, trust: .production)
      }
      #expect(candidate.commander.scriptState.savedClueJournal == nil)
    }
  }

  @Test func currentContributionAloneAndMixedServicesRetainNormalAlienReceiptJoins() async throws {
    let fixture = try OriginalMutualContributionFixture()
    defer { fixture.files.clean() }
    let alone = try await fixture.runtime()
    _ = try await fixture.donate(alone)
    try mutualContributionCurrentEnvelopes(await alone.snapshot(), root: fixture.files.root)
    let mixed = try await fixture.runtime(mixedServices: true)
    _ = try await fixture.donate(mixed)
    let packs = await mixed.snapshot().scriptPacks
    let clinic = try #require(
      packs.first { $0.manifest.stateID == WayfarerColdChainDefinition.stateID })
    let repair = try #require(
      packs.first { $0.manifest.stateID == WayfarerRepairLoopDefinition.stateID })
    let seed = try #require(
      packs.first { $0.manifest.stateID == "l337.wayfarer-service/seed-transfer" })
    let clinicSource = try await mixed.initializeWayfarerColdChainStock(packDigest: clinic.digest)
    let clinicOffer = try await mixed.wayfarerColdChainQuote(sourceID: clinicSource)
    _ = try await mixed.pickUpWayfarerColdChain(
      sourceID: clinicSource, quotedOfferID: clinicOffer.id)
    let repairSource = try await mixed.initializeWayfarerRepairLoopStock(packDigest: repair.digest)
    let repairOffer = try await mixed.wayfarerRepairLoopQuote(sourceID: repairSource)
    _ = try await mixed.pickUpWayfarerRepairLoop(
      sourceID: repairSource, quotedOfferID: repairOffer.id)
    try await ScriptProcurementFixture.travel(mixed, path: [85, 241], verifyDeparture: true)
    let seedSource = try await mixed.initializeWayfarerColdChainStock(packDigest: seed.digest)
    let seedOffer = try await mixed.wayfarerColdChainQuote(sourceID: seedSource)
    _ = try await mixed.pickUpWayfarerColdChain(sourceID: seedSource, quotedOfferID: seedOffer.id)
    try await ScriptProcurementFixture.travel(mixed, path: [241, 85], verifyDeparture: true)
    let game = await mixed.snapshot()
    #expect(OriginalServiceReservationPolicy.activeCount(game.commander.scriptState) == 3)
    try mutualContributionCurrentEnvelopes(game, root: fixture.files.root)
  }
}
