import Foundation
import Testing

@testable import EliteCore

private struct CalendarFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(source: String? = nil, edits: [(String, String)] = []) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "calendar-" + UUID().uuidString)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-courier")
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text = text.replacingOccurrences(
      of: "capabilities = [",
      with:
        "capabilities = [\"calendar-clocks-v2\", \"pulse-counters-v2\", \"local-flight-clocks-v2\", "
    )
    text += "\n[[handlers]]\nevent='timer.fired'\nfunction='timer'\n"
    for (a, b) in edits { text = text.replacingOccurrences(of: a, with: b) }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    try (source ?? Self.source).write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game() throws -> (Game, UUID) {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let id = try game.acceptScriptMission(pack)
    return (game, id)
  }
  static let source = """
    local M={}
    function M.accepted(e,w,d)
      return {data={stamps={}},commands={{op='timer.ensure',id='pulse',domain='local',after=0,interval=1,policy='skip'},
        {op='timer.counter.ensure',id='pulse',name='opening'},
        {op='timer.counter.ensure',id='pulse',name='lander',enabled=false},
        {op='timer.counter.ensure',id='pulse',name='final',enabled=false}}}
    end
    function M.timer(e,w,d)
      d.stamps[#d.stamps+1]={pulse=e.pulse,due=e.due,fired=e.fired_at,opening=e.counters.opening,lander=e.counters.lander,final=e.counters.final}
      local commands={}
      if e.counters.opening==3 and not d.transition then
        d.transition=true
        commands={{op='timer.counter.enable',id='pulse',name='opening',enabled=false},
          {op='timer.counter.reset',id='pulse',name='lander'},
          {op='timer.counter.reset',id='pulse',name='final'}}
      end
      return {data=d,commands=commands}
    end
    function M.contact(e,w,d) return {data=d,commands={}} end
    function M.confirm(e,w,d) return {data=d,commands={}} end
    return M
    """
}
private func clearTravelArea(_ game: inout Game) {
  game.bodies.removeAll { $0.missionActorID == nil }
  game.celestials = []
}

@Test func passengerBerthActivatesCalendarOnceBeforeMissionsAndFreezesReadOnlyAndPausedTime()
  async throws
{
  var game = Game(executive: false)
  game.screen = .status
  game.commander.credits = 100_000
  try game.commander.prepareEquipment(legacy: false)
  try game.confirmPassengerBerth(game.passengerBerthQuote)
  try #require(game.commander.accommodation != ShipAccommodation())
  try #require(game.commander.scriptState.instances.isEmpty)
  let runtime = GameRuntime(game: game)
  #expect(await runtime.snapshot().commander.scriptState.calendarLedger?.origin == .newCommander)
  _ = await runtime.advance(delta: 0.1)
  #expect(await runtime.snapshot().commander.scriptState.calendarSeconds == 0.1)
  #expect(await runtime.snapshot().commander.scriptState.localSeconds == 0)
  await runtime.key("k")
  let before = await runtime.snapshot().commander.scriptState.calendarSeconds
  _ = await runtime.advance(delta: 0.1)
  #expect(await runtime.snapshot().commander.scriptState.calendarSeconds == before)
  await runtime.key("escape")
  await runtime.key("pause")
  _ = await runtime.advance(delta: 0.1)
  #expect(await runtime.snapshot().commander.scriptState.calendarSeconds == before)
}

@Test
func activatedMissionRealLaunchChargesOnceAndCalendarDistanceRetainsSelectedO08IntegerTruncation()
  throws
{
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  var (game, _) = try fixture.game()
  game.screen = .status
  game.launch()
  #expect(game.commander.scriptState.calendarSeconds == 600)
  #expect(game.commander.scriptState.calendarLedger?.lastAdjustment?.kind == .launch)
  game.launch()
  #expect(game.commander.scriptState.calendarSeconds == 600)
  game.dock()
  game.launch()
  #expect(game.commander.scriptState.calendarSeconds == 1200)
  let examples = game.systems.flatMap { a in game.systems.map { (a, $0) } }
  let pair = try #require(
    examples.first { abs($0.0.distance(to: $0.1) - $0.0.scriptCalendarDistance(to: $0.1)) > 0.1 })
  let dx = pair.0.x - pair.1.x
  let dy = (pair.0.y - pair.1.y) / 2
  let expected = 0.4 * Double(Int(sqrt(Double(dx * dx + dy * dy))))
  #expect(pair.0.scriptCalendarDistance(to: pair.1) == expected)
}

@Test
func activatedMissionAdmittedJumpPinsActualDestinationAndNativeFuelWhileCalendarUsesItsOwnMetric()
  throws
{
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  var (game, _) = try fixture.game()
  game.launch()
  clearTravelArea(&game)
  let destination = try #require(
    game.knownSystems.first {
      $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
    })
  let source = game.currentSystem
  game.selectedSystem = destination.id
  let fuel = game.commander.fuel
  game.beginHyperspace()
  let admission = try #require(game.commander.scriptState.calendarLedger?.pendingJourney)
  let nativeDebit = Int((source.distance(to: destination) * 10).rounded())
  #expect(admission.nativeFuelDebit == nativeDebit)
  game.selectedSystem = (destination.id + 30) % 256
  game.arrive()
  #expect(game.commander.system == destination.id && game.commander.fuel == fuel - nativeDebit)
  #expect(
    game.commander.scriptState.calendarSeconds == 600 + source.scriptCalendarDistance(
      to: destination) * source.scriptCalendarDistance(to: destination) * 3600)
  #expect(game.commander.scriptState.calendarLedger?.pendingJourney == nil)
  let clock = game.commander.scriptState.calendarSeconds
  game.selectedSystem = game.commander.system
  game.arrive()
  #expect(game.commander.scriptState.calendarSeconds == clock)
}

@Test
func
  activatedMissionExplicitNavigationAndDockCancellationClearTheActualAdmissionWithoutChargingTravel()
  throws
{
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  for cancel in 0..<3 {
    var (game, _) = try fixture.game()
    game.launch()
    clearTravelArea(&game)
    let destination = try #require(
      game.knownSystems.first {
        $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
      })
    game.selectedSystem = destination.id
    game.beginHyperspace()
    #expect(game.commander.scriptState.calendarLedger?.pendingJourney != nil)
    if cancel == 0 {
      game.cancelNavigation()
    } else if cancel == 1 {
      game.manuallySelectSystem(game.commander.system)
    } else {
      game.dock()
    }
    #expect(
      game.jumpCountdown == nil && game.commander.scriptState.calendarLedger?.pendingJourney == nil)
    #expect(game.commander.scriptState.calendarSeconds == 600)
  }
}

@Test func sourcePulseCountersResetToZeroOnTheNextRealCallbackAndThenCountFollowingPulses() throws {
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  #expect(game.commander.scriptState.instances[id]?.timers["pulse"]?.pulses == 0)
  for _ in 0..<65 { game.advanceScriptClocks(delta: 0.1, flight: false, local: true) }
  let stamps = try #require(game.commander.scriptState.instances[id]?.data["stamps"]?.array)
  #expect(stamps.count == 7)
  #expect(stamps[0]["opening"] == .integer(1) && stamps[2]["opening"] == .integer(3))
  #expect(stamps[3]["lander"] == .integer(0) && stamps[3]["final"] == .integer(0))
  #expect(stamps[4]["lander"] == .integer(1) && stamps[4]["final"] == .integer(1))
  #expect(stamps[6]["lander"] == .integer(3) && stamps[6]["opening"] == .integer(3))
  #expect(game.commander.scriptState.instances[id]?.timers["pulse"]?.lastDue == 6)
  #expect(game.commander.valid)
}

@Test func skippedTimerIntervalsNeverInventCounterPulsesAndResetSurvivesSaveReload() async throws {
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.commander.scriptState.localSeconds = 20
  game.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  #expect(game.commander.scriptState.instances[id]?.timers["pulse"]?.pulses == 1)
  #expect(
    game.commander.scriptState.instances[id]?.timers["pulse"]?.counters["opening"]?.value == 1)
  #expect(game.commander.scriptState.instances[id]?.timers["pulse"]?.due == 21)
  game.commander.scriptState.instances[id]?.timers["pulse"]?.counters["lander"]?.resetOnNextPulse =
    true
  game.commander.scriptState.instances[id]?.timers["pulse"]?.counters["lander"]?.enabled = true
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  for _ in 0..<10 { _ = await loaded.advance(delta: 0.1) }
  let timer = try #require(
    await loaded.snapshot().commander.scriptState.instances[id]?.timers["pulse"])
  #expect(timer.pulses == 2 && timer.counters["lander"]?.value == 0)
  #expect(!timer.counters["lander"]!.resetOnNextPulse)
}

@Test func savedAdmittedCountdownSurvivesTitleWaitAndCompletesWithOneCalendarCharge() async throws {
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  var (game, _) = try fixture.game()
  game.launch()
  clearTravelArea(&game)
  let destination = try #require(
    game.knownSystems.first {
      $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
    })
  game.selectedSystem = destination.id
  game.beginHyperspace()
  let journey = try #require(game.commander.scriptState.calendarLedger?.pendingJourney)
  game.selectedSystem = (destination.id + 20) % 256
  let runtime = GameRuntime(game: game)
  for _ in 0..<3 { _ = await runtime.advance(delta: 0.1) }
  try await runtime.save(to: fixture.save)
  let saved = await runtime.snapshot()
  let restored = GameRuntime(game: game)
  try await restored.restoreStartup(from: fixture.save)
  let title = await restored.snapshot()
  for _ in 0..<30 { _ = await restored.advance(delta: 0.1) }
  #expect(await restored.snapshot().commander == title.commander)
  #expect(await restored.snapshot().bodies == title.bodies)
  #expect(await restored.snapshot().jumpCountdown == saved.jumpCountdown)
  await restored.key(" ")
  #expect(await restored.snapshot().time == saved.time)
  var arrived = await restored.snapshot()
  for _ in 0..<200 where arrived.jumpCountdown != nil {
    arrived = await restored.advance(delta: 0.1)
  }
  #expect(arrived.commander.system == destination.id)
  #expect(
    arrived.commander.scriptState.calendarLedger?.lastAdjustment?.operation == journey.operation)
  #expect(arrived.commander.scriptState.calendarLedger?.lastAdjustment?.seconds == journey.seconds)
  #expect(arrived.commander.scriptState.calendarSeconds > 600 + journey.seconds)
  #expect(arrived.time < 30)
  try await restored.save(to: fixture.save)
  let next = GameRuntime(game: game)
  try await next.load(from: fixture.save)
  let before = await next.snapshot().commander.scriptState.calendarSeconds
  _ = await next.advance(delta: 0.1)
  #expect(abs(await next.snapshot().commander.scriptState.calendarSeconds - before - 0.1) < 1e-8)
  #expect(
    await next.snapshot().commander.scriptState.calendarLedger?.lastAdjustment?.operation
      == journey.operation)
}

@Test
func
  activatedMissionApplyingNativeTravelCalendarTimeCannotMoveCelestialsHeatScoopOrPhysicalCounters()
  throws
{
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  var (game, _) = try fixture.game()
  game.launch()
  clearTravelArea(&game)
  let destination = try #require(
    game.knownSystems.first {
      $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
    })
  game.selectedSystem = destination.id
  game.beginHyperspace()
  game.resetCelestialFlight()
  game.cabinTemperature = 0.42
  game.solarFuelRemainder = 0.29
  let physical = game.scriptSimulationSave
  let scene = game.celestials
  let time = game.time
  let result = game.completeCalendarJourney()
  let journey = try #require(result)
  #expect(journey.seconds > 0)
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  #expect(try encoder.encode(game.scriptSimulationSave) == encoder.encode(physical))
  #expect(game.celestials == scene && game.time == time)
}

@Test func retainedLegacyMissionActivatesCalendarMigrationOnceWithoutOfflineTimeOrReset()
  async throws
{
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  try FileManager.default.createDirectory(
    at: fixture.save.deletingLastPathComponent(), withIntermediateDirectories: true)
  let (active, id) = try fixture.game()
  var original = active.commander
  original.credits = 12345
  // Preserve the actual accepted mission in an archive from before the optional calendar ledger.
  original.scriptState.calendarLedger = nil
  try #require(original.scriptState.instances[id] != nil)
  let bytes = try JSONEncoder().encode(original)
  try bytes.write(to: fixture.save)
  var host = Game(executive: false)
  host.scriptPacks = [fixture.pack]
  let runtime = GameRuntime(game: host)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let imported = await runtime.snapshot()
  #expect(imported.commander.credits == 12345)
  #expect(imported.commander.scriptState.instances[id]?.definition == fixture.pack.manifest.stateID)
  #expect(imported.commander.scriptState.instances[id]?.suspension == nil)
  #expect(imported.commander.scriptState.calendarLedger?.origin == .inactiveLegacyMigration)
  #expect(imported.commander.scriptState.calendarSeconds == 0)
  #expect(try Data(contentsOf: fixture.save) == bytes)
  _ = await runtime.advance(delta: 0.1)
  try await runtime.save(to: fixture.save)
  let saved = await runtime.snapshot().commander
  try await runtime.load(from: fixture.save)
  #expect(await runtime.snapshot().commander == saved)
  #expect(saved.scriptState.calendarSeconds == 0.1)
}

@Test func calendarTimersObserveRealTravelBeforeFiringAndDoNotFastForwardPhysicalClocks()
  async throws
{
  let source = """
    local M={}
    function M.accepted(e,w,d)
      return {data=d,commands={{op='timer.ensure',id='date',domain='calendar',after=86400,interval=0,policy='once'}}}
    end
    function M.timer(e,w,d) d.fired=true;d.day=w.calendar_day;d.system=w.system;d.due=e.due;return {data=d,commands={}} end
    function M.contact(e,w,d) return {data=d,commands={}} end
    function M.confirm(e,w,d) return {data=d,commands={}} end
    return M
    """
  let fixture = try CalendarFixture(source: source)
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.launch()
  clearTravelArea(&game)
  let destination = try #require(
    game.knownSystems.first {
      let distance = game.currentSystem.distance(to: $0)
      return $0.id != game.commander.system && distance <= 7
        && game.currentSystem.scriptCalendarDistance(to: $0) > 5
    })
  game.selectedSystem = destination.id
  game.beginHyperspace()
  let runtime = GameRuntime(game: game)
  var arrived = await runtime.snapshot()
  for _ in 0..<200 where arrived.jumpCountdown != nil {
    arrived = await runtime.advance(delta: 0.1)
  }
  let state = try #require(arrived.commander.scriptState.instances[id])
  #expect(
    state.data["fired"] == .bool(true) && state.data["system"] == .integer(Int64(destination.id)))
  #expect(state.data["day"]?.integer ?? 0 >= 1)
  #expect(
    arrived.commander.scriptState.localSeconds < 30
      && arrived.commander.scriptState.flightSeconds < 30)
  #expect(arrived.commander.scriptState.calendarSeconds > 86400)
  #expect(state.suspension == nil && state.timers["date"] == nil)
}

@Test func readOnlyViewsCannotFireAnAlreadyDueCalendarTimerOrResetPulseCounterState() async throws {
  let source = CalendarFixture.source.replacingOccurrences(
    of: "domain='local'", with: "domain='calendar'")
  let fixture = try CalendarFixture(source: source)
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.screen = .handoff
  let runtime = GameRuntime(game: game)
  for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.timers["pulse"]?.pulses == 0)
  #expect(await runtime.snapshot().commander.scriptState.calendarSeconds == 0)
  await runtime.key("escape")
  _ = await runtime.advance(delta: 0.1)
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.timers["pulse"]?.pulses == 1)
}

@Test func invalidPulseCounterCommandsRollbackEarlierMoneyAndNativeCounterLimitsCannotOverflow()
  throws
{
  let source = CalendarFixture.source.replacingOccurrences(
    of: "{op='timer.counter.ensure',id='pulse',name='opening'}",
    with:
      "{op='credits',id='credit',amount=100},{op='timer.counter.enable',id='pulse',name='missing',enabled=true}"
  )
  let fixture = try CalendarFixture(source: source)
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.scriptPacks = [fixture.pack]
  let before = game.commander
  #expect(throws: (any Error).self) { try game.acceptScriptMission(fixture.pack) }
  #expect(game.commander == before)
  let valid = try CalendarFixture()
  defer { valid.clean() }
  var (running, id) = try valid.game()
  running.commander.scriptState.instances[id]?.timers["pulse"]?.pulses = 1_000_000_000
  running.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  #expect(running.commander.scriptState.instances[id]?.suspension?.contains("pulse limit") == true)
  #expect(running.commander.valid)
  running.commander.scriptState.instances[id]?.timers["pulse"]?.pulses = Int.max
  #expect(!running.commander.valid)
}

private func calendarContractPack() throws -> ScriptPack {
  try ScriptPackLibrary.read(
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/calendar-contracts"))
}

@Test func calendarContractReviewFreezesTimeAndNativeLaunchExpiresFrozenTermsWithoutPaying()
  async throws
{
  let pack = try calendarContractPack()
  let fixture = try CalendarFixture()
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let key = try await runtime.generateContractBoard(packDigest: pack.digest)
  let offer = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
  #expect(offer.duration == 86400)
  await runtime.key("contracts-open")
  let before = await runtime.snapshot().commander
  for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
  var reviewed = await runtime.snapshot().commander
  #expect(reviewed.scriptState.calendarSeconds == before.scriptState.calendarSeconds)
  #expect(reviewed.scriptState.localSeconds > before.scriptState.localSeconds)
  reviewed.scriptState.localSeconds = before.scriptState.localSeconds
  #expect(reviewed == before)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  #expect(quote.allowed)
  let id = try await runtime.confirmContract(quote)
  var accepted = await runtime.snapshot()
  let job = try #require(accepted.commander.scriptState.instances[id]?.contract)
  #expect(job.clock == .calendar && job.deadline == job.acceptedAt + 86400)
  accepted.commander.scriptState.calendarSeconds = job.deadline! - 100
  accepted.screen = .status
  accepted.launch()
  #expect(accepted.commander.scriptState.calendarSeconds == job.deadline! + 500)
  accepted.commander.galaxy = offer.destinationGalaxy
  accepted.commander.system = offer.destinationSystem
  accepted.dock()
  accepted.emitScriptEvent("contact.requested", only: id)
  let shown = accepted.showScriptDialogue()
  #expect(shown)
  accepted.confirmScriptDialogue()
  let finished = try #require(accepted.commander.scriptState.instances[id])
  #expect(finished.outcome == .failed && finished.contract?.settlementOutcome == .failed)
  #expect(accepted.commander.credits == 1000 - offer.deposit)
  #expect(accepted.commander.cargoTonnes == 0)
  #expect(finished.contract?.deadline == job.deadline)
}

@Test func calendarBoardTrialHasSeparateEpochAndCannotResetTheLiveCommandersClock() throws {
  let pack = try calendarContractPack()
  var parent = Game(executive: false)
  parent.screen = .gallery
  parent.scriptPacks = [pack]
  parent.ensureScriptCalendar(origin: .newCommander)
  parent.commander.scriptState.calendarSeconds = 86400 * 60 + 10
  let before = parent.commander
  var trial = try parent.makeScriptTrial(packDigest: pack.digest, seed: 7)
  let job = try #require(trial.commander.scriptState.instances.values.first?.contract)
  #expect(job.clock == .calendar && job.acceptedAt == 0 && job.deadline == 86400)
  trial.launch()
  #expect(trial.commander.scriptState.calendarSeconds == 600)
  #expect(parent.commander == before && parent.calendarDay == 60)
}

@Test func nativeCalendarBoundsDenyNewTravelAndMalformedLedgerWithoutOverflowOrRetargeting()
  throws
{
  var game = Game(executive: false)
  game.screen = .status
  game.ensureScriptCalendar(origin: .newCommander)
  game.commander.scriptState.calendarSeconds = 1e12 - 599
  game.launch()
  #expect(game.docked && game.commander.scriptState.calendarSeconds == 1e12 - 599)
  game.commander.scriptState.calendarSeconds = 0
  game.commander.scriptState.calendarLedger?.operation = UInt64(Int64.max) - 1
  game.launch()
  #expect(game.docked)
  game.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
  #expect(!game.commander.valid)
  game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
  game.launch()
  clearTravelArea(&game)
  let destination = try #require(
    game.knownSystems.first {
      $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
    })
  game.selectedSystem = destination.id
  game.beginHyperspace()
  let admitted = try #require(game.commander.scriptState.calendarLedger?.pendingJourney)
  game.commander.scriptState.calendarSeconds = 1e12 - admitted.seconds - 0.05
  game.advanceScriptClocks(delta: 0.1, flight: true, local: true, calendar: true)
  #expect(game.commander.scriptState.calendarSeconds == 1e12 - admitted.seconds)
  #expect(game.commander.valid)
  let cursor = (destination.id + 50) % 256
  game.selectedSystem = cursor
  game.arrive()
  #expect(game.commander.system == admitted.destination && game.selectedSystem == cursor)
  #expect(game.commander.valid)
}

@Test func calendarAtItsCeilingDeliversTheActualLastPulseWithoutOverflowOrInventingMoreCallbacks()
  async throws
{
  let fixture = try CalendarFixture(
    source: CalendarFixture.source.replacingOccurrences(
      of: "domain='local'", with: "domain='calendar'"))
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [fixture.pack]
  game.ensureScriptCalendar(origin: .newCommander)
  game.commander.scriptState.calendarSeconds = 1e12 - 0.05
  let id = try game.acceptScriptMission(fixture.pack)
  for _ in 0..<10 {
    game.advanceScriptClocks(delta: 0.1, flight: false, local: false, calendar: true)
  }
  let timer = try #require(game.commander.scriptState.instances[id]?.timers["pulse"])
  #expect(timer.pulses == 1 && timer.clockExhausted == true && timer.due == 1e12)
  #expect(game.commander.scriptState.instances[id]?.data["stamps"]?.array?.count == 1)
  #expect(game.commander.valid)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  _ = await loaded.advance(delta: 0.1)
  #expect(await loaded.snapshot().commander.scriptState.instances[id]?.timers["pulse"] == timer)
}
