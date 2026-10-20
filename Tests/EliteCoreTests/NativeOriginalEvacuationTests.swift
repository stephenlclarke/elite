import Foundation
import Testing

@testable import EliteCore

struct NativeEvacuationFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }
  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledOrbitalEvacuationDirectory)
  }
  func runtime(cabins: Int = 4, escapeReady: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    // Controlled initial funds; all equipment and cabins still require actual paid purchases.
    game.commander.credits = 400000
    try game.prepareG03FlightEquipment()
    if cabins > 4 {
      // Six cabins plus the genuine G08 tools require a lean paid fit on this same hull.
      let owner = game.commander.equipmentOwnerID
      let hull = game.commander.hullInstanceID
      let units = game.commander.commonEquipmentUnits
      var stored: [UUID] = []
      let optionalFit: [(ComponentFittingSlot, String)] = [
        (.energy, "Extra Energy Unit"), (.shield, ShieldBooster.pulse.equipmentName),
      ]
      for (slot, name) in optionalFit {
        let item = try #require(game.commander.fittedEquipment(at: slot))
        try #require(item.node.key == name)
        let revision = try #require(game.commander.equipmentInventory?.revision)
        try game.storeEquipment(item, expectedRevision: revision)
        stored.append(item.id)
      }
      for name in ["Fuel Scoops", "Targeting: Salvage Module"] {
        let item = try #require(Equipment.all.first { $0.name == name })
        let quote = try game.quoteEquipmentPurchase(item)
        let bought = try game.applyEquipmentPurchase(quote)
        try #require(bought)
      }
      try #require(
        game.commander.equipmentOwnerID == owner && game.commander.hullInstanceID == hull)
      try #require(game.commander.commonEquipmentUnits == units - 2)
      try #require(
        stored.allSatisfy { id in
          game.commander.equipmentInventory?.items.contains { $0.id == id && $0.location == nil }
            == true
        })
      try #require(game.hasNativeRescueTools && game.commander.hasAutomaticDocking)
      try #require(game.commander.valid)
    }
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(pod)
      let bought = try game.applyEquipmentPurchase(quote)
      try #require(bought)
    }
    game.scriptPacks = [pack]
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await flight.dock(runtime)
    for _ in 0..<cabins {
      let quote = await runtime.passengerBerthQuote()
      try #require(quote.allowed, "\(quote.issues)")
      try await runtime.confirmPassengerBerth(quote)
    }
    return runtime
  }
  func prepareEarlierClaims(_ runtime: GameRuntime) async throws {
    let packs = try [
      ScriptPackLibrary.bundledCabinJourneyDirectory,
      ScriptPackLibrary.bundledOrbitalOutlookDirectory,
      ScriptPackLibrary.bundledConsentedFreightDirectory,
      ScriptPackLibrary.bundledOriginalRescueDirectory,
    ].map { try ScriptPackLibrary.read($0) }
    await runtime.nativeCommand { $0.scriptPacks += packs }
    try await NativePeopleTestFixture.confirm(runtime, row: .journey(.request))
    try await NativePeopleTestFixture.confirm(runtime, row: .outlook(.request))
    let supply = packs[2]
    let key = try await runtime.generateContractBoard(packDigest: supply.digest)
    let offer = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed)
    _ = try await runtime.confirmContract(quote)
    await runtime.procurementRefuel()
    let game = await runtime.snapshot()
    let reach = ScriptCourierReach(game.commander)
    let systems = game.systems
    let adjacency = systems.indices.map { from in systems.indices.filter { $0 != from } }
    let path = try #require(
      NavigationRouteSearch.path(adjacency: adjacency, from: 7, to: 85) { from, to, first in
        systems[from].distance(to: systems[to]) <= (first ? reach.firstReach : reach.laterReach)
          ? 1 : nil
      })
    try await flight.travel(runtime, path: path)
    try await NativePeopleTestFixture.confirm(runtime, row: .rescue(.accept))
    await runtime.procurementRefuel()
    try await flight.travel(runtime, path: Array(path.reversed()))
    try #require(await runtime.snapshot().commander.system == 7)
  }
  func roundTrip(_ game: Game, label: String, alien: Bool) throws -> Commander {
    var candidate = game
    if alien && !candidate.commander.usesAlienStorageSaveVersion {
      let owner = try #require(candidate.commander.equipmentOwnerID)
      try candidate.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 0,
          world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
    }
    let prepared = try GameRuntime.prepareNativeSaveState(candidate)
    let url = files.root.appendingPathComponent("cold-\(label)-\(alien)/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 48 : 47))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(NativeOriginalEvacuationSave.validateClaims(cold))
    return cold
  }
  func confirm(_ runtime: GameRuntime, _ action: NativeOriginalEvacuationAction) async throws {
    try await NativePeopleTestFixture.confirm(runtime, row: .evacuation(action))
  }
  func source(_ runtime: GameRuntime) async throws -> NativeOriginalEvacuationState {
    try #require(await runtime.snapshot().commander.nativePeople?.orbitalEvacuation)
  }
  func board(_ runtime: GameRuntime) async throws -> NativeOriginalEvacuationState {
    try await confirm(runtime, .request)
    try await confirm(runtime, .board)
    let state = try await source(runtime)
    try #require(state.boarding != nil)
    return state
  }
}

struct NativeOriginalEvacuationTests {
  @Test func evacuationRequestDefaultsBackAndOnlyNativeRepliesPrecedeSeparateBoarding() async throws
  {
    let f = try NativeEvacuationFixture()
    defer { f.files.clean() }
    #expect(f.pack.digest == NativeOriginalEvacuation.digest)
    let runtime = try await f.runtime()
    let before = await runtime.snapshot().commander
    let page = try await NativePeopleTestFixture.review(runtime, row: .evacuation(.request))
    #expect(await runtime.snapshot().contractBoard.action == .back)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try await f.confirm(runtime, .request)
    let requested = await runtime.snapshot()
    let source = try await f.source(runtime)
    let offer = try #require(source.latestOffer)
    #expect(source.people.map(\.name) == ["Sera Venn", "Tavi Noll", "Eren Pell", "Mara Quill"])
    #expect(source.references.count == 4 && Set(source.references).count == 4)
    #expect(source.references.allSatisfy { $0.emp == nil && $0.evacuation != nil })
    #expect(source.latestReplies(for: offer).map(\.kind) == [.accept, .accept, .accept, .accept])
    #expect(source.boarding == nil && requested.commander.nativePeople?.admissions.isEmpty == true)
    #expect(requested.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(
      requested.commander.credits == before.credits && requested.commander.cargo == before.cargo)
    #expect(requested.commander.valid)
  }

  @Test func evacuationThreeActualCabinsRefuseAllThenPaidFourthCabinEnablesAll() async throws {
    let f = try NativeEvacuationFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(cabins: 3)
    try await f.confirm(runtime, .request)
    let refused = try await f.source(runtime)
    let offer = try #require(refused.latestOffer)
    #expect(refused.latestReplies(for: offer).map(\.kind) == [.refuse, .refuse, .refuse, .refuse])
    #expect(await runtime.snapshot().originalEvacuationQuote(.board).allowed == false)
    let quote = await runtime.passengerBerthQuote()
    try await runtime.confirmPassengerBerth(quote)
    try await f.confirm(runtime, .request)
    let renewed = try await f.source(runtime)
    let next = try #require(renewed.latestOffer)
    #expect(renewed.references == refused.references && renewed.people == refused.people)
    #expect(renewed.latestReplies(for: next).map(\.kind) == [.accept, .accept, .accept, .accept])
    try await f.confirm(runtime, .board)
    let boarded = await runtime.snapshot()
    #expect(boarded.commander.accommodation.fittedBerths.filter { $0.use.used }.count == 4)
    #expect(boarded.commander.valid)
  }

  @Test func evacuationActualBoardingPreservesFourPeopleSlotsCashAndFullHold() async throws {
    let f = try NativeEvacuationFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    await runtime.nativeCommand { game in
      game.commander.cargo[0] += game.commander.standardCargoCapacity - game.commander.cargoTonnes
    }
    try await runtime.save(to: f.save)
    let before = await runtime.snapshot().commander
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    let after = await runtime.snapshot().commander
    let state = try #require(after.scriptState.instances[boarding.mission])
    let job = try #require(state.contract)
    #expect(after.nativePeople?.admissions.map(\.person) == source.references)
    #expect(Set(boarding.berths) == Set(before.accommodation.fittedBerths.map(\.id)))
    #expect(job.offer.reward == 10650 && job.offer.deposit == 0 && job.deadline == nil)
    #expect(after.credits == before.credits && after.cargo == before.cargo)
    #expect(after.nativeCaptiveCount == 0 && state.outcome == .active)
    #expect(after.valid)
    #expect(await runtime.snapshot().originalEvacuationQuote(.board).allowed == false)
    #expect(await runtime.snapshot().originalEvacuationQuote(.receive).allowed == false)
  }

  @Test func evacuationStalePaintedBoardQuoteCannotAcquirePeopleAfterFitChanges() async throws {
    let f = try NativeEvacuationFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.confirm(runtime, .request)
    let page = try await NativePeopleTestFixture.review(runtime, row: .evacuation(.board))
    await runtime.scriptPageKey("right", expected: page)
    let snapshot = await runtime.snapshot()
    let id = try #require(snapshot.commander.accommodation.fittedBerths.first?.id)
    try await runtime.setPassengerBerthFitted(id, fitted: false)
    let before = await runtime.snapshot().commander
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().commander.nativePeople?.admissions.isEmpty == true)
  }

  @Test func evacuationNativePolicyRefusesWrongDestinationAndWithdrawsChangedRealFit() async throws
  {
    let f = try NativeEvacuationFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.confirm(runtime, .request)
    var source = try await f.source(runtime)
    let game = await runtime.snapshot()
    try NativeOriginalEvacuation.requestConsent(
      state: &source, game: game,
      destination: .init(galaxy: 0, system: 8))
    let refused = try #require(source.latestOffer)
    #expect(source.latestReplies(for: refused).map(\.kind) == [.refuse, .refuse, .refuse, .refuse])
    let original = try await f.source(runtime)
    let offer = try #require(original.latestOffer)
    let id = try #require(offer.berths.first?.id)
    try await runtime.setPassengerBerthFitted(id, fitted: false)
    let changed = await runtime.snapshot()
    let reply = try NativeOriginalEvacuation.replyToPassageOffer(
      person: original.people[0].identity, offer: offer, state: original, game: changed)
    #expect(reply.kind == .withdraw)
    let foreign = NativeOriginalEvacuationIdentity(
      owner: UUID(), batch: NativeOriginalEvacuation.batch, person: "sera-venn")
    #expect(throws: (any Error).self) {
      try NativeOriginalEvacuation.replyToPassageOffer(
        person: foreign, offer: offer,
        state: original, game: changed)
    }
  }

  @Test func evacuationNativeWithdrawalBeforeBoardingRetainsSameFiniteRosterWithoutPay()
    async throws
  {
    let f = try NativeEvacuationFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.confirm(runtime, .request)
    let original = try await f.source(runtime)
    let before = await runtime.snapshot().commander
    try await f.confirm(runtime, .cancel)
    let closed = await runtime.snapshot()
    let state = try #require(closed.commander.nativePeople?.orbitalEvacuation)
    #expect(
      state.references == original.references && state.withdrawal != nil && state.boarding == nil)
    #expect(state.people.allSatisfy { $0.currentRequest?.intent == .withdrawn })
    #expect(state.replies.suffix(4).allSatisfy { $0.kind == .withdraw })
    #expect(
      closed.commander.credits == before.credits
        && closed.commander.nativePeople?.admissions.isEmpty == true)
    #expect(
      closed.commander.scriptState.savedClueJournal == nil && closed.originalEvacuationRows.isEmpty)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(
      cold.commander.nativePeople?.orbitalEvacuation == state && cold.originalEvacuationRows.isEmpty
    )
  }

}
