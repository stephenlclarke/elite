import Foundation
import Testing

@testable import L337Core

struct NativeOrbitalOutlookFixture {
  let base: NativeStationJourneyFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { base.files }
  var save: URL { base.save }
  init() throws {
    base = try NativeStationJourneyFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledOrbitalOutlookDirectory)
  }
  func runtime(cabins: Int = 2, coexist: Bool = false) async throws -> GameRuntime {
    let runtime = try await base.runtime(cabins: cabins)
    let packs = coexist ? [base.pack, pack] : [pack]
    await runtime.nativeCommand { $0.scriptPacks = packs }
    return runtime
  }
  func confirm(_ runtime: GameRuntime, _ action: NativeOrbitalOutlookJourneyAction) async throws {
    try await NativePeopleTestFixture.confirm(runtime, row: .outlook(action))
  }
  func source(_ runtime: GameRuntime) async throws -> NativeOrbitalOutlookJourneyState {
    try #require(await runtime.snapshot().commander.nativePeople?.outlookJourney)
  }
  func board(_ runtime: GameRuntime) async throws -> NativeOrbitalOutlookJourneyState {
    try await confirm(runtime, .request)
    try await confirm(runtime, .board)
    let source = try await source(runtime)
    try #require(source.boarding != nil)
    return source
  }
  func renas(_ runtime: GameRuntime) async throws {
    try await base.flight.travel(runtime, path: [7, 185])
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    let source = try await source(runtime)
    let boarding = try #require(source.boarding)
    let game = await runtime.snapshot()
    let encounter = try #require(
      game.commander.scriptState.instances[boarding.mission]?.ownedEncounters[
        NativeOrbitalOutlookJourney.encounterID])
    try #require(encounter.admitted && encounter.actors.count == 3)
    #expect(Set(encounter.actors.values.map(\.identity)).count == 3)
  }
  /// Controlled player framing only. Existing Tab/Q select the real actor; no scan/actor is manufactured.
  func aim(_ runtime: GameRuntime, ordinal: Int, distance: Double = 1000) async throws {
    let source = try await source(runtime)
    let boarding = try #require(source.boarding)
    let identity = NativeOrbitalOutlookJourney.markerIdentity(
      mission: boarding.mission, ordinal: ordinal)
    await runtime.nativeCommand { game in
      guard let body = game.bodies.first(where: { $0.missionActorID == identity }),
        let station = game.bodies.first(where: { $0.id == 0 })
      else { return }
      var pose = game.commander.flightSimulation.pose
      let normal = pose.orientation.apply(station.orientation.y)
      let right = pose.orientation.apply(station.orientation.x)
      let target = pose.systemPoint(body.position)
      pose.position = target + normal * distance
      pose.orientation.x = right
      pose.orientation.z = normal * -1
      pose.orientation.y = pose.orientation.z.cross(right)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
    }
    for _ in 0..<100 {
      await runtime.key("tab")
      if await runtime.snapshot().informationTargetBody?.missionActorID == identity { break }
    }
    try #require(await runtime.snapshot().informationTargetBody?.missionActorID == identity)
    await runtime.key("q")
    try #require(await runtime.snapshot().informationTargetBody?.missionActorID == identity)
  }
  func view(_ runtime: GameRuntime, ordinal: Int) async throws {
    try await aim(runtime, ordinal: ordinal)
    try #require(await runtime.snapshot().orbitalOutlookSample()?.ordinal == ordinal)
    for _ in 0..<130 {
      if try await source(runtime).readings.count > ordinal { break }
      _ = await runtime.advance(delta: 0.1)
    }
    let source = try await source(runtime)
    try #require(source.readings.count == ordinal + 1)
    #expect(source.readings[ordinal].qualifiedSeconds >= 12)
    #expect(source.readings[ordinal].intervals >= 120)
  }
  func allViews(_ runtime: GameRuntime) async throws {
    for ordinal in 0..<3 { try await view(runtime, ordinal: ordinal) }
  }
  func returnHome(_ runtime: GameRuntime) async throws {
    // The flight helper launches from a genuine dock, so physically dock first after the views.
    try await base.flight.dock(runtime)
    await runtime.procurementRefuel()
    try await base.flight.travel(runtime, path: [185, 7])
  }
}

struct NativeOrbitalOutlookJourneyTests {
  @Test func outlookProductionConsentNamesWholeItineraryAndRequiresSeparatePaidCabins() async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    #expect(f.pack.digest == NativeOrbitalOutlookJourney.digest)
    let runtime = try await f.runtime(cabins: 1)
    let before = await runtime.snapshot().commander
    let page = try await NativePeopleTestFixture.review(runtime, row: .outlook(.request))
    #expect(await runtime.snapshot().contractBoard.action == .back)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try await f.confirm(runtime, .request)
    let refused = try await f.source(runtime)
    let offer = try #require(refused.latestOffer)
    #expect(refused.people.map(\.name) == ["Lysa Renn", "Tovan Hale"])
    #expect(
      refused.people.allSatisfy {
        $0.currentRequest?.itinerary == NativeOrbitalOutlookJourney.views
      })
    #expect(offer.path == [7, 185, 7] && offer.itinerary == NativeOrbitalOutlookJourney.views)
    #expect(refused.latestReplies(for: offer).map(\.kind) == [.refuse, .refuse])
    #expect(await runtime.snapshot().orbitalOutlookQuote(.board).allowed == false)
    let cabin = await runtime.passengerBerthQuote()
    try await runtime.confirmPassengerBerth(cabin)
    try await f.confirm(runtime, .request)
    let ready = try await f.source(runtime)
    let next = try #require(ready.latestOffer)
    #expect(ready.references == refused.references)
    #expect(ready.latestReplies(for: next).map(\.kind) == [.accept, .accept])
    #expect(await runtime.snapshot().commander.nativePeople?.admissions.isEmpty == true)
    try await f.confirm(runtime, .board)
    let boarded = await runtime.snapshot()
    #expect(boarded.commander.nativePeople?.admissions.map(\.person) == ready.references)
    #expect(boarded.commander.valid && boarded.commander.nativeCaptiveCount == 0)
    #expect(boarded.orbitalOutlookQuote(.receive).allowed == false)
    #expect(boarded.commander.cargo == before.cargo)
  }

  @Test func outlookFullActualThreeViewReturnReleasesSamePeopleAndPaysOneClue() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    let before = await runtime.snapshot().commander
    try await f.renas(runtime)
    try await f.allViews(runtime)
    let scanned = await runtime.snapshot()
    #expect(scanned.commander.credits == before.credits)
    #expect(scanned.commander.scriptState.savedClueJournal == nil)
    #expect(scanned.commander.scriptState.instances[boarding.mission]?.outcome == .active)
    #expect(scanned.orbitalOutlookQuote(.receive).allowed == false)
    try await f.returnHome(runtime)
    let receptionCash = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot()
    #expect(done.commander.credits == receptionCash + 8700)
    #expect(done.commander.nativePeople?.transfers.last?.members == source.references)
    #expect(done.commander.nativePeople?.transfers.last?.kind == .care)
    #expect(done.commander.scriptState.instances[boarding.mission]?.outcome == .complete)
    #expect(done.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    let clue = try #require(
      done.commander.scriptState.savedClueJournal?.awards[NativeOrbitalOutlookJourney.stateID])
    #expect(clue.clueID == "orbital-outlook-family-trace")
    #expect(done.commander.valid && done.orbitalOutlookRows.isEmpty)
    await runtime.key("contracts-open")
    #expect(await runtime.snapshot().commander == done.commander)
  }

  @Test func outlookSourceAndBoardWriterRefusalPreserveOriginalPeopleAndBothCabins() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    for action in [NativeOrbitalOutlookJourneyAction.request, .board] {
      let page = try await NativePeopleTestFixture.review(runtime, row: .outlook(action))
      await runtime.scriptPageKey("right", expected: page)
      let before = await runtime.snapshot().commander
      let bytes = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
      let held = try f.files.blockWrites("outlook-source-" + action.rawValue)
      await runtime.scriptPageKey("return", expected: page)
      #expect(await runtime.snapshot().commander == before)
      try f.files.restoreWrites(held, files: bytes)
      try await f.confirm(runtime, action)
    }
    #expect(await runtime.snapshot().commander.nativePeople?.admissions.count == 2)
  }

  @Test func outlookNativeRepliesWithdrawWhenActualCabinFitChanges() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.confirm(runtime, .request)
    let source = try await f.source(runtime)
    let offer = try #require(source.latestOffer)
    let cabin = try #require(offer.berths.first?.cabinID)
    try await runtime.setPassengerBerthFitted(cabin, fitted: false)
    let changed = await runtime.snapshot()
    let reply = try NativeOrbitalOutlookJourney.replyToPassageOffer(
      person: source.people[0].identity,
      offer: offer, state: source, game: changed)
    #expect(reply.kind == .withdraw)
    #expect(changed.orbitalOutlookQuote(.board).allowed == false)
  }

  @Test func outlookConcurrentG04CareCannotOffloadOrSettleTheOtherParty() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(cabins: 4, coexist: true)
    let g04 = try await f.base.board(runtime)
    let g05 = try await f.board(runtime)
    #expect(Set(g04.references).isDisjoint(with: g05.references))
    try await f.renas(runtime)
    try await f.base.flight.dock(runtime)
    try await f.base.confirm(runtime, .receive)
    let care = await runtime.snapshot()
    #expect(care.commander.nativePeople?.held.map(\.person) == g05.references)
    #expect(care.commander.nativePeople?.outlookJourney?.terminalOperation == nil)
    #expect(care.commander.nativePeople?.transfers.last?.members == g04.references)
    #expect(care.commander.accommodation.fittedBerths.filter { $0.use.used }.count == 2)
    await runtime.key("0")
    try await f.allViews(runtime)
    try await f.returnHome(runtime)
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot()
    #expect(done.commander.nativePeople?.transfers.last?.members == g05.references)
    #expect(done.commander.nativePeople?.held.isEmpty == true && done.commander.valid)
    #expect(done.commander.scriptState.savedClueJournal?.awards.count == 2)
  }

  @Test func outlookSourceCareCancelsWithoutPaymentAndCannotRepopulateAfterLoad() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    let before = await runtime.snapshot().commander
    try await f.confirm(runtime, .cancel)
    try await runtime.load(from: f.save, persistMigrations: false)
    let done = await runtime.snapshot()
    #expect(done.commander.scriptState.instances[boarding.mission]?.outcome == .abandoned)
    #expect(
      done.commander.credits == before.credits && done.commander.scriptState.savedClueJournal == nil
    )
    #expect(done.commander.nativePeople?.outlookJourney?.references == source.references)
    #expect(done.commander.nativePeople?.transfers.last?.members == source.references)
    #expect(done.orbitalOutlookRows.isEmpty && done.commander.valid)
  }

  @Test func outlookFatalPhysicalLossClosesBothPeopleWithoutViewsPaymentOrClue() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    let before = await runtime.snapshot().commander
    await runtime.key("escape")
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    try await runtime.supplyFatalHullHit()
    _ = await runtime.advance(delta: 0.1)
    let lost = await runtime.snapshot()
    #expect(lost.commander.scriptState.instances[boarding.mission]?.outcome == .failed)
    #expect(lost.commander.nativePeople?.transfers.last?.members == source.references)
    #expect(lost.commander.nativePeople?.transfers.last?.kind == .loss)
    #expect(
      lost.commander.credits == before.credits && lost.commander.scriptState.savedClueJournal == nil
    )
    #expect(lost.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(lost.commander.valid)
  }
}

extension NativeOrbitalOutlookJourneyTests {
  @Test func outlookPrivateAwakeConsentRejectsPackedPodsAndTwoPlacesInOnePhysicalCabin()
    async throws
  {
    let fixture = try NativeOrbitalOutlookFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(cabins: 0)
    let packed = await runtime.passengerCabinQuote(.cryogenic)
    try await runtime.confirmPassengerBerth(packed)
    try await fixture.confirm(runtime, .request)
    let stasisOnly = try await fixture.source(runtime)
    let stasisOffer = try #require(stasisOnly.latestOffer)
    #expect(stasisOffer.berths.isEmpty)
    #expect(stasisOnly.latestReplies(for: stasisOffer).map(\.kind) == [.refuse, .refuse])
    let shared = await runtime.passengerCabinQuote(.stateroomDouble)
    try await runtime.confirmPassengerBerth(shared)
    try await fixture.confirm(runtime, .request)
    let oneCabin = try await fixture.source(runtime)
    let oneOffer = try #require(oneCabin.latestOffer)
    #expect(oneOffer.berths.count == 1)
    #expect(oneCabin.latestReplies(for: oneOffer).map(\.kind) == [.refuse, .refuse])
    let separate = await runtime.passengerCabinQuote(.stateroomSingle)
    try await runtime.confirmPassengerBerth(separate)
    try await fixture.confirm(runtime, .request)
    let agreed = try await fixture.source(runtime)
    let offer = try #require(agreed.latestOffer)
    #expect(Set(offer.berths.map(\.cabinID)).count == 2)
    #expect(agreed.latestReplies(for: offer).map(\.kind) == [.accept, .accept])
    try await fixture.confirm(runtime, .board)
    let aboard = await runtime.snapshot().commander
    #expect(
      aboard.nativePeople?.held.filter {
        $0.person.station?.batch == NativeOrbitalOutlookJourney.batch
      }.count == 2)
    #expect(
      aboard.accommodation.fittedBerths.filter { $0.use.used }.allSatisfy {
        $0.mode == .awake && $0.privateCabin
      })
    #expect(aboard.valid)
  }
}
