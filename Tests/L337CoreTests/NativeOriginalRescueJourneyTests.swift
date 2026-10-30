import Foundation
import Testing

@testable import L337Core

struct NativeOriginalRescueFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }
  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledOriginalRescueDirectory)
  }
  func runtime(
    cabins: Int = 2, freeCargoTonnes: Int? = nil, tools: Bool = true, composed: Bool = false,
    escapeReady: Bool = false
  )
    async throws -> GameRuntime
  {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    if !composed {
      // Controlled initial world, never interstellar travel or station reception evidence.
      game.commander.system = 85
      game.selectedSystem = 85
      game.market = MarketItem.at(game.currentSystem)
    }
    game.commander.credits = 1_000_000
    try game.prepareG03FlightEquipment()
    if tools {
      for name in ["Fuel Scoops", "Targeting: Salvage Module"] {
        let item = try #require(Equipment.all.first { $0.name == name })
        let quote = try game.quoteEquipmentPurchase(item)
        let result = try game.applyEquipmentPurchase(quote)
        try #require(result)
      }
    }
    if escapeReady {
      let item = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(item)
      let result = try game.applyEquipmentPurchase(quote)
      try #require(result)
    }
    game.scriptPacks = [pack]
    if composed {
      game.scriptPacks += [
        try ScriptPackLibrary.read(ScriptPackLibrary.bundledCabinJourneyDirectory),
        try ScriptPackLibrary.read(ScriptPackLibrary.bundledOrbitalOutlookDirectory),
        try ScriptPackLibrary.read(ScriptPackLibrary.bundledConsentedFreightDirectory),
      ]
    }
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await flight.dock(runtime)
    for _ in 0..<cabins {
      let quote = await runtime.passengerBerthQuote()
      try #require(quote.allowed, "\(quote.issues)")
      try await runtime.confirmPassengerBerth(quote)
    }
    if let freeCargoTonnes {
      // Controlled ordinary cargo only; actual paid fitted cabins determine the remaining space.
      await runtime.nativeCommand { game in
        game.commander.cargo[0] +=
          game.commander.standardCargoCapacity - game.commander.cargoTonnes - freeCargoTonnes
      }
      let actual = await runtime.snapshot().commander
      try #require(actual.valid)
      try #require(actual.standardCargoCapacity - actual.cargoTonnes == freeCargoTonnes)
      try await runtime.save(to: save)
    }
    if composed {
      // These are real native source/reply and finite supply-allocation claims. Neither
      // waiting passenger batch is boarded or reported as a completed prior journey.
      try await NativePeopleTestFixture.confirm(runtime, row: .journey(.request))
      try await NativePeopleTestFixture.confirm(runtime, row: .outlook(.request))
      let supply = try ScriptPackLibrary.read(ScriptPackLibrary.bundledConsentedFreightDirectory)
      let key = try await runtime.generateContractBoard(packDigest: supply.digest)
      let offer = try #require(
        await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
      let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
      try #require(quote.allowed)
      _ = try await runtime.confirmContract(quote)
      await runtime.procurementRefuel()
      let current = await runtime.snapshot()
      let reach = ScriptCourierReach(current.commander)
      let systems = current.systems
      let adjacency = systems.indices.map { from in
        systems.indices.filter { $0 != from }
      }
      // Courier offers stop at three jumps; this native flight may use a longer real route.
      let path = try #require(
        NavigationRouteSearch.path(adjacency: adjacency, from: 7, to: 85) { from, to, first in
          let distance = systems[from].distance(to: systems[to])
          return distance <= (first ? reach.firstReach : reach.laterReach) ? 1 : nil
        })
      try await flight.travel(runtime, path: path)
      await runtime.procurementRefuel()
    }
    return runtime
  }
  func confirm(_ runtime: GameRuntime, _ action: NativeOriginalRescueAction) async throws {
    try await NativePeopleTestFixture.confirm(runtime, row: .rescue(action))
  }
  func source(_ runtime: GameRuntime) async throws -> NativeOriginalRescueJourneyState {
    try #require(await runtime.snapshot().commander.nativePeople?.originalRescue)
  }
  func accept(_ runtime: GameRuntime) async throws -> NativeOriginalRescueJourneyState {
    try await confirm(runtime, .accept)
    return try await source(runtime)
  }
  func launch(_ runtime: GameRuntime) async throws {
    if await runtime.snapshot().docked {
      await runtime.key("escape")
      await runtime.key("0")
    }
    _ = await runtime.advance(delta: 0.05)
    let state = try await source(runtime)
    let game = await runtime.snapshot()
    try #require(!game.docked)
    let encounter = try #require(
      game.commander.scriptState.instances[state.mission]?.ownedEncounters[
        NativeOriginalRescueJourney.encounterID])
    try #require(encounter.admitted && encounter.actors.count == 3)
  }
  func approach(_ runtime: GameRuntime, alias: String, distance: Double? = nil) async throws {
    try await launch(runtime)
    let state = try await source(runtime)
    let logical = NativeOriginalRescueJourney.actorIdentity(mission: state.mission, alias: alias)
    await runtime.nativeCommand { game in
      guard let body = game.bodies.first(where: { $0.missionActorID == logical }) else { return }
      var pose = game.commander.flightSimulation.pose
      let center = pose.systemPoint(body.position)
      let offset = distance.map { Vector3(0, 0, $0) } ?? .init(0, -45, 55)
      pose.position = center - pose.orientation.apply(offset)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
      game.pitch = 0
      game.yaw = 0
      game.roll = 0
    }
    let actual = await runtime.snapshot()
    try #require(actual.bodies.contains { $0.missionActorID == logical })
    if distance == nil {
      let body = try #require(actual.bodies.first { $0.missionActorID == logical })
      let mesh = try #require(actual.scriptNPCMesh(body))
      let radius = try #require(mesh.vertices.map(\.length).max())
      try #require(radius > 0 && radius <= 16)
      let context = try #require(actual.gameplayContext())
      let shapeFits = actual.automaticScoopShapeCompatible(body, context: context)
      try #require(
        shapeFits, "Actual registered geometry must pass the unchanged native shape gate.")
      let inside = actual.podInsideRescueAperture(body)
      try #require(inside, "Actual original actor must fit the unchanged native aperture.")
    }
  }
  func collect(_ runtime: GameRuntime, alias: String) async throws {
    try await approach(runtime, alias: alias)
    _ = await runtime.advance(delta: 0.05)
    let state = try await source(runtime)
    if alias == "emergency-record" {
      try #require(state.record != nil)
    } else {
      try #require(state.captures.contains { $0.alias == alias })
    }
  }
  func serialCare(_ runtime: GameRuntime) async throws {
    for alias in NativeOriginalRescueJourney.aliases.prefix(2) {
      try await collect(runtime, alias: alias)
      try await flight.dock(runtime)
      try await confirm(runtime, .care)
    }
  }
  func board(_ runtime: GameRuntime) async throws {
    try await serialCare(runtime)
    try await confirm(runtime, .request)
    try await confirm(runtime, .board)
    let boarded = try await source(runtime)
    try #require(boarded.boarding != nil)
  }
  func celalen(_ runtime: GameRuntime) async throws {
    if await runtime.snapshot().docked == false { try await flight.dock(runtime) }
    await runtime.procurementRefuel()
    try await flight.travel(runtime, path: [85, 241])
    try #require(await runtime.snapshot().commander.system == 241)
  }
  func roundTrip(_ game: Game, label: String, alien: Bool) throws -> Commander {
    var stage = "Alien storage preparation"
    var completed = false
    defer {
      if !completed {
        Issue.record("G08 round trip \(label), Alien=\(alien), stopped at \(stage).")
      }
    }
    var candidate = game
    if alien && !candidate.commander.usesAlienStorageSaveVersion {
      let owner = try #require(candidate.commander.equipmentOwnerID)
      try candidate.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 0,
          world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
    }
    stage = "prepareNativeSaveState"
    let prepared = try GameRuntime.prepareNativeSaveState(candidate)
    let url = files.root.appendingPathComponent("cold-\(label)-\(alien)/commander.json")
    stage = "ScriptSaveStore.write"
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander,
      world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    stage = "read published pointer"
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 46 : 45))
    stage = "ScriptSaveStore.read"
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(NativeOriginalRescueJourneySave.validateClaims(cold))
    completed = true
    return cold
  }
}

struct NativeOriginalRescueJourneyTests {
  @Test func rescueActualWholeJourneyRetainsOriginalCareAndPaysOnlyFinalPeoplePlusRecord()
    async throws
  {
    var stage = "fixture initialization"
    var completed = false
    defer {
      if !completed { Issue.record("G08 whole journey stopped at \(stage).") }
    }
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    stage = "runtime setup"
    let runtime = try await f.runtime(freeCargoTonnes: 1)
    let before = await runtime.snapshot().commander
    stage = "accept"
    let source = try await f.accept(runtime)
    #expect(source.references.allSatisfy { $0.emp == nil && $0.station == nil && $0.rescue != nil })
    #expect(await runtime.snapshot().commander.cargoTonnes == before.cargoTonnes + 1)
    for alien in [false, true] {
      stage = "accepted round trip, Alien=\(alien)"
      _ = try f.roundTrip(await runtime.snapshot(), label: "accepted", alien: alien)
    }
    for (ordinal, alias) in NativeOriginalRescueJourney.aliases.prefix(2).enumerated() {
      stage = "collect \(alias)"
      try await f.collect(runtime, alias: alias)
      let captured = await runtime.snapshot()
      #expect(captured.commander.cargoTonnes == before.cargoTonnes + 1)
      #expect(captured.commander.nativePeople?.heldPods.count == 1)
      #expect(captured.commander.nativePeople?.admissions.count == ordinal + 1)
      #expect(captured.commander.credits == before.credits)
      for alien in [false, true] {
        stage = "capsule \(ordinal) round trip, Alien=\(alien)"
        _ = try f.roundTrip(captured, label: "capsule-\(ordinal)", alien: alien)
      }
      stage = "dock with \(alias)"
      try await f.flight.dock(runtime)
      stage = "care for \(alias)"
      try await f.confirm(runtime, .care)
      let care = await runtime.snapshot()
      #expect(care.commander.cargoTonnes == before.cargoTonnes + 1)
      #expect(care.commander.nativePeople?.held.isEmpty == true)
      #expect(
        care.commander.credits == before.credits
          && care.commander.scriptState.savedClueJournal == nil)
    }
    stage = "request transport"
    try await f.confirm(runtime, .request)
    let requested = try await f.source(runtime)
    #expect(requested.replies.map(\.kind) == [.accept, .accept])
    #expect(requested.boarding == nil)
    stage = "board"
    try await f.confirm(runtime, .board)
    let boarded = await runtime.snapshot()
    #expect(boarded.commander.nativePeople?.admissions.count == 2)
    #expect(boarded.commander.nativePeople?.transfers.count == 2)
    #expect(boarded.commander.nativePeople?.held.map(\.person) == source.references)
    #expect(boarded.commander.rescuedPodTonnes == 0)
    for ordinal in 0..<2 {
      #expect(
        boarded.commander.accommodation.fittedBerths.first {
          $0.id == source.reservedBerths[ordinal]
        }?.use == .nativePerson(source.references[ordinal]))
    }
    for alien in [false, true] {
      stage = "boarded round trip, Alien=\(alien)"
      _ = try f.roundTrip(boarded, label: "boarded", alien: alien)
    }
    stage = "collect emergency record"
    try await f.collect(runtime, alias: "emergency-record")
    let record = await runtime.snapshot()
    #expect(record.commander.cargoTonnes == before.cargoTonnes + 1)
    #expect(record.commander.cargo == before.cargo && record.commander.credits == before.credits)
    for alien in [false, true] {
      stage = "record round trip, Alien=\(alien)"
      _ = try f.roundTrip(record, label: "record", alien: alien)
    }
    stage = "travel to Celalen"
    try await f.celalen(runtime)
    let receiving = await runtime.snapshot().commander
    #expect(receiving.scriptState.instances[source.mission]?.outcome == .active)
    stage = "receive at Celalen"
    try await f.confirm(runtime, .receive)
    let final = await runtime.snapshot()
    #expect(final.commander.credits == receiving.credits + 10200)
    #expect(final.commander.cargoTonnes == before.cargoTonnes)
    #expect(final.commander.cargo == before.cargo)
    #expect(final.commander.nativePeople?.admissions.count == 2)
    #expect(final.commander.nativePeople?.transfers.count == 3)
    #expect(final.commander.nativePeople?.held.isEmpty == true)
    #expect(final.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(final.commander.scriptState.instances[source.mission]?.outcome == .complete)
    #expect(
      final.commander.scriptState.savedClueJournal?.awards[NativeOriginalRescueJourney.stateID]?
        .clueID == "custody-rescue-family-trace")
    #expect(final.commander.valid)
    for alien in [false, true] {
      stage = "received round trip, Alien=\(alien)"
      _ = try f.roundTrip(final, label: "received", alien: alien)
    }
    #expect(final.originalRescueQuote(.receive).allowed == false)
    completed = true
  }

  @Test(arguments: [false, true], [false, true])
  func rescueGenuine45And46IndependentlyComposeNativeG02G04G05Claims(alien: Bool, composed: Bool)
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(composed: composed)
    let source = try await f.accept(runtime)
    try await f.collect(runtime, alias: "neri-capsule")
    try await f.flight.dock(runtime)
    try await f.confirm(runtime, .care)
    let cold = try f.roundTrip(await runtime.snapshot(), label: "composed", alien: alien)
    #expect(cold.nativePeople?.originalRescue?.references == source.references)
    #expect(cold.nativePeople?.originalRescue?.captures.count == 1)
    #expect((cold.nativePeople?.stationJourney != nil) == composed)
    #expect((cold.nativePeople?.outlookJourney != nil) == composed)
    #expect((cold.scriptState.savedOriginalConsentedFreightSupply != nil) == composed)
    #expect(NativeStationPassengerJourneySave.validateClaims(cold))
    #expect(NativeOrbitalOutlookJourneySave.validateClaims(cold))
    #expect(OriginalConsentedFreightSupplySave.validateClaims(cold))
  }

  @Test func rescueNativeConsentWithdrawsAnOldOfferAfterActualPaidEquipmentChange() async throws {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    try await f.serialCare(runtime)
    try await f.confirm(runtime, .request)
    let old = try await f.source(runtime)
    let offer = try #require(old.offers.last)
    await runtime.nativeCommand { game in
      guard let item = Equipment.all.first(where: { $0.name == "E.C.M. System" }),
        let quote = try? game.quoteEquipmentPurchase(item)
      else { return }
      _ = try? game.applyEquipmentPurchase(quote)
    }
    let changed = await runtime.snapshot()
    try #require(changed.commander.equipmentInventory?.revision != offer.inventoryRevision)
    let identity = try #require(old.references[0].rescue)
    let reply = try NativeOriginalRescueJourney.replyToTransportOffer(
      identity, offer: offer, state: old, game: changed)
    #expect(reply.kind == .withdraw)
    #expect(changed.originalRescueQuote(.board).allowed == false)
    try await f.confirm(runtime, .request)
    try await f.confirm(runtime, .board)
    #expect(await runtime.snapshot().commander.nativePeople?.admissions.count == 2)
  }

  @Test func rescueSafeSourceCancellationRetainsCareAndOriginalReferencesWithoutPaymentOrRestock()
    async throws
  {
    let f = try NativeOriginalRescueFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.accept(runtime)
    try await f.collect(runtime, alias: "neri-capsule")
    try await f.flight.dock(runtime)
    let before = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .cancel)
    let final = await runtime.snapshot()
    #expect(final.commander.credits == before)
    #expect(final.commander.scriptState.savedClueJournal == nil)
    #expect(final.commander.scriptState.instances[source.mission]?.outcome == .abandoned)
    #expect(final.commander.nativePeople?.admissions.count == 1)
    #expect(final.commander.nativePeople?.held.isEmpty == true)
    #expect(final.commander.nativePeople?.originalRescue?.references == source.references)
    #expect(final.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save)
    #expect(await runtime.snapshot().originalRescueQuote(.accept).allowed == false)
  }
}
