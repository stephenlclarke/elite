import Foundation
import Testing

@testable import L337Core

struct NativeStationJourneyFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }
  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledCabinJourneyDirectory)
  }
  func runtime(cabins: Int = 2, escapeReady: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    // Controlled initial funds; all equipment and cabins still require actual paid purchases.
    game.commander.credits = 1_000_000
    try game.prepareG03FlightEquipment()
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
  func confirm(_ runtime: GameRuntime, _ action: NativeStationPassengerJourneyAction) async throws {
    try await NativePeopleTestFixture.confirm(runtime, row: .journey(action))
  }
  func source(_ runtime: GameRuntime) async throws -> NativeStationPassengerJourneyState {
    try #require(await runtime.snapshot().commander.nativePeople?.stationJourney)
  }
  func board(_ runtime: GameRuntime) async throws -> NativeStationPassengerJourneyState {
    try await confirm(runtime, .request)
    try await confirm(runtime, .board)
    let state = try await source(runtime)
    try #require(state.boarding != nil)
    return state
  }
}

struct NativeStationPassengerJourneyTests {
  @Test func journeyRequestDefaultsBackAndOnlyNativeRepliesPrecedeSeparateBoarding() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    #expect(f.pack.digest == NativeStationPassengerJourney.digest)
    let runtime = try await f.runtime()
    let before = await runtime.snapshot().commander
    let page = try await NativePeopleTestFixture.review(runtime, row: .journey(.request))
    #expect(await runtime.snapshot().contractBoard.action == .back)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try await f.confirm(runtime, .request)
    let requested = await runtime.snapshot()
    let source = try await f.source(runtime)
    let offer = try #require(source.latestOffer)
    #expect(source.people.map(\.name) == ["Mira Talen", "Oren Vey"])
    #expect(source.references.count == 2 && Set(source.references).count == 2)
    #expect(source.references.allSatisfy { $0.emp == nil && $0.station != nil })
    #expect(source.latestReplies(for: offer).map(\.kind) == [.accept, .accept])
    #expect(source.boarding == nil && requested.commander.nativePeople?.admissions.isEmpty == true)
    #expect(requested.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(
      requested.commander.credits == before.credits && requested.commander.cargo == before.cargo)
    #expect(requested.commander.valid)
  }

  @Test func journeyOneActualCabinRefusesBothThenPaidSecondCabinEnablesBoth() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(cabins: 1)
    try await f.confirm(runtime, .request)
    let refused = try await f.source(runtime)
    let offer = try #require(refused.latestOffer)
    #expect(refused.latestReplies(for: offer).map(\.kind) == [.refuse, .refuse])
    #expect(await runtime.snapshot().stationPassengerQuote(.board).allowed == false)
    let quote = await runtime.passengerBerthQuote()
    try await runtime.confirmPassengerBerth(quote)
    try await f.confirm(runtime, .request)
    let renewed = try await f.source(runtime)
    let next = try #require(renewed.latestOffer)
    #expect(renewed.references == refused.references && renewed.people == refused.people)
    #expect(renewed.latestReplies(for: next).map(\.kind) == [.accept, .accept])
    try await f.confirm(runtime, .board)
    let boarded = await runtime.snapshot()
    #expect(boarded.commander.accommodation.fittedBerths.filter { $0.use.used }.count == 2)
    #expect(boarded.commander.valid)
  }

  @Test func journeyActualBoardingPreservesPeopleSlotsCashAndZeroCargo() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let before = await runtime.snapshot().commander
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    let after = await runtime.snapshot().commander
    let state = try #require(after.scriptState.instances[boarding.mission])
    let job = try #require(state.contract)
    #expect(after.nativePeople?.admissions.map(\.person) == source.references)
    #expect(Set(boarding.berths) == Set(before.accommodation.fittedBerths.map(\.id)))
    #expect(job.offer.reward == 6100 && job.offer.deposit == 0 && job.deadline == nil)
    #expect(after.credits == before.credits && after.cargo == before.cargo)
    #expect(after.nativeCaptiveCount == 0 && state.outcome == .active)
    #expect(after.valid)
    #expect(await runtime.snapshot().stationPassengerQuote(.board).allowed == false)
    #expect(await runtime.snapshot().stationPassengerQuote(.receive).allowed == false)
  }

  @Test func journeyStalePaintedBoardQuoteCannotAcquirePeopleAfterFitChanges() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.confirm(runtime, .request)
    let page = try await NativePeopleTestFixture.review(runtime, row: .journey(.board))
    await runtime.scriptPageKey("right", expected: page)
    let snapshot = await runtime.snapshot()
    let id = try #require(snapshot.commander.accommodation.fittedCabins.first?.id)
    try await runtime.setPassengerBerthFitted(id, fitted: false)
    let before = await runtime.snapshot().commander
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().commander.nativePeople?.admissions.isEmpty == true)
  }

  @Test func journeySourceWriterFailurePublishesNeitherRepliesNorCustody() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let page = try await NativePeopleTestFixture.review(runtime, row: .journey(.request))
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let bytes = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("journey-source")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(held, files: bytes)
    try await f.confirm(runtime, .request)
    let state = try await f.source(runtime)
    #expect(state.people.count == 2 && state.replies.count == 2)
  }
  @Test func journeyNativePolicyRefusesWrongDestinationAndWithdrawsChangedRealFit() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.confirm(runtime, .request)
    var source = try await f.source(runtime)
    let game = await runtime.snapshot()
    try NativeStationPassengerJourney.requestConsent(
      state: &source, game: game,
      destination: .init(galaxy: 0, system: 8))
    let refused = try #require(source.latestOffer)
    #expect(source.latestReplies(for: refused).map(\.kind) == [.refuse, .refuse])
    let original = try await f.source(runtime)
    let offer = try #require(original.latestOffer)
    let id = try #require(offer.berths.first?.cabinID)
    try await runtime.setPassengerBerthFitted(id, fitted: false)
    let changed = await runtime.snapshot()
    let reply = try NativeStationPassengerJourney.replyToPassageOffer(
      person: original.people[0].identity, offer: offer, state: original, game: changed)
    #expect(reply.kind == .withdraw)
    let foreign = NativeStationPersonIdentity(
      owner: UUID(), batch: NativeStationPassengerJourney.batch, person: "mira-talen")
    #expect(throws: (any Error).self) {
      try NativeStationPassengerJourney.replyToPassageOffer(
        person: foreign, offer: offer,
        state: original, game: changed)
    }
  }

}
