import Foundation
import Testing

@testable import L337Core

struct NativeOriginalSurveyFixture {
  let base: NativeStationJourneyFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { base.files }
  var save: URL { base.save }
  init() throws {
    base = try NativeStationJourneyFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledOriginalSurveyDirectory)
  }
  func runtime(cabins: Int = 0, coexist: Bool = false) async throws -> GameRuntime {
    let runtime = try await base.runtime(cabins: cabins)
    let packs = coexist ? [base.pack, pack] : [pack]
    await runtime.nativeCommand { $0.scriptPacks = packs }
    return runtime
  }
  func review(_ runtime: GameRuntime, _ action: NativeOriginalSurveyAction) async throws
    -> ScriptPagePresentation
  {
    await runtime.key("contracts-open")
    let game = await runtime.snapshot()
    let index = try #require(game.contractBoard.rows.firstIndex { $0.survey == action })
    for _ in 0..<abs(index - game.contractBoard.selection) {
      await runtime.key(index < game.contractBoard.selection ? "up" : "down")
    }
    let page = await runtime.snapshot().scriptPagePresentation
    await runtime.scriptPageKey("return", expected: page)
    try #require(await runtime.snapshot().contractBoard.surveyQuote?.action == action)
    return await runtime.snapshot().scriptPagePresentation
  }
  func confirm(_ runtime: GameRuntime, _ action: NativeOriginalSurveyAction) async throws {
    let page = try await review(runtime, action)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
  }
  func source(_ runtime: GameRuntime) async throws -> NativeOriginalSurveyState {
    try #require(await runtime.snapshot().originalSurveyState)
  }
  func board(_ runtime: GameRuntime) async throws -> NativeOriginalSurveyState {
    try await confirm(runtime, .accept)
    let source = try await source(runtime)
    try #require(source.permission != nil)
    return source
  }
  func renas(_ runtime: GameRuntime) async throws {
    try await base.flight.travel(runtime, path: [7, 185])
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    let source = try await source(runtime)
    let permission = try #require(source.permission)
    let game = await runtime.snapshot()
    let encounter = try #require(
      game.commander.scriptState.instances[permission.mission]?.ownedEncounters[
        NativeOriginalSurvey.encounterID])
    try #require(encounter.admitted && encounter.actors.count == 3)
    #expect(Set(encounter.actors.values.map(\.identity)).count == 3)
  }
  /// Controlled player framing only. Existing Tab/Q select the real actor; no scan/actor is manufactured.
  func aim(_ runtime: GameRuntime, ordinal: Int, distance: Double = 1000) async throws {
    let source = try await source(runtime)
    let permission = try #require(source.permission)
    let identity = NativeOriginalSurvey.markerIdentity(
      mission: permission.mission, digest: source.digest, ordinal: ordinal)
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
    try #require(await runtime.snapshot().originalSurveySample()?.ordinal == ordinal)
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

struct NativeOriginalSurveyJourneyTests {
  @Test func surveyAcceptanceWriterRefusalKeepsPermissionAndResourcesUnchanged() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let page = try await f.review(runtime, .accept)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("survey-permission")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().originalSurveyState == nil)
    try f.files.restoreWrites(held, files: files)
    let source = try await f.board(runtime)
    #expect(source.readings.isEmpty && source.authorities.isEmpty)
    let permission = try #require(source.permission)
    #expect(await runtime.snapshot().commander.scriptState.instances[permission.mission] != nil)
    #expect(await runtime.snapshot().commander.credits == before.credits)
  }

  @Test func surveyPermissionBackAndCancelConserveCargoBerthsCashAndClue() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let before = await runtime.snapshot().commander
    let page = try await f.review(runtime, .accept)
    #expect(await runtime.snapshot().contractBoard.action == .back)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    _ = try await f.board(runtime)
    let accepted = await runtime.snapshot()
    #expect(accepted.commander.cargo == before.cargo)
    #expect(accepted.commander.accommodation == before.accommodation)
    #expect(accepted.commander.credits == before.credits)
    #expect(accepted.commander.nativePeople == before.nativePeople)
    #expect(accepted.originalSurveyReview(.receive).allowed == false)
    try await f.confirm(runtime, .cancel)
    let cancelled = await runtime.snapshot()
    #expect(cancelled.commander.credits == before.credits)
    #expect(cancelled.commander.scriptState.savedClueJournal == nil)
    #expect(cancelled.originalSurveyState?.terminalOperation != nil)
    #expect(cancelled.originalSurveyRows.isEmpty)
  }

  @Test func surveyActualThreeMeasurementsReturnPaysOnlyAtReception() async throws {
    let f = try NativeOriginalSurveyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    let before = await runtime.snapshot().commander
    try await f.renas(runtime)
    try await f.allViews(runtime)
    let measured = await runtime.snapshot()
    #expect(measured.commander.credits == before.credits)
    #expect(measured.commander.scriptState.savedClueJournal == nil)
    #expect(measured.originalSurveyReview(.receive).allowed == false)
    try await f.returnHome(runtime)
    let receptionCash = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot()
    #expect(done.commander.credits == receptionCash + NativeOriginalSurvey.reward)
    #expect(done.originalSurveyState?.readings.count == 3)
    #expect(done.originalSurveyState?.terminalDock != nil)
    #expect(done.originalSurveyRows.isEmpty)
    #expect(done.commander.nativePeople == before.nativePeople)
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[NativeOriginalSurvey.stateID] != nil)
  }
}
