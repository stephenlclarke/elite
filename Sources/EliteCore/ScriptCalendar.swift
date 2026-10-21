import Foundation

extension Game {
  mutating func ensureScriptCalendar(origin: ScriptCalendarOrigin) {
    if commander.scriptState.calendarLedger == nil {
      commander.scriptState.calendarLedger = .init(origin: origin)
    }
  }
  var calendarDay: Int64 { Int64(floor(commander.scriptState.calendarSeconds / 86400)) }

  mutating func recordCalendarLaunch(wasDocked: Bool) -> Bool {
    guard wasDocked else { return true }
    ensureScriptCalendar(origin: .newCommander)
    guard var ledger = commander.scriptState.calendarLedger,
      ledger.operation < UInt64(Int64.max) - 1,
      commander.scriptState.calendarSeconds <= 1e12 - 600, missionCalendarCanAdd(600)
    else { return false }
    ledger.operation += 1
    let before = commander.scriptState.calendarSeconds
    commander.scriptState.calendarSeconds += 600
    mirrorMissionCalendar(seconds: 600, operation: ledger.operation)
    ledger.lastAdjustment = .init(
      operation: ledger.operation, kind: .launch,
      seconds: 600, before: before, after: commander.scriptState.calendarSeconds)
    commander.scriptState.calendarLedger = ledger
    return true
  }
  mutating func admitCalendarJourney(destination: StarSystem, nativeFuelDebit: Int) -> Bool {
    ensureScriptCalendar(origin: .newCommander)
    guard var ledger = commander.scriptState.calendarLedger,
      ledger.pendingJourney == nil, ledger.operation < UInt64(Int64.max) - 1
    else { return false }
    let distance = currentSystem.scriptCalendarDistance(to: destination)
    guard commander.scriptState.calendarSeconds <= 1e12 - distance * distance * 3600,
      commander.scriptState.transitSeconds <= 1e12 - distance * distance * 3600,
      missionCalendarCanAdd(distance * distance * 3600)
    else {
      return false
    }
    ledger.operation += 1
    ledger.legacyUntrackedJourney = false
    ledger.pendingJourney = .init(
      operation: ledger.operation, galaxy: commander.galaxy,
      origin: commander.system, destination: destination.id, sourceDistance: distance,
      nativeFuelDebit: nativeFuelDebit)
    commander.scriptState.calendarLedger = ledger
    return true
  }
  mutating func cancelCalendarJourney() {
    commander.scriptState.calendarLedger?.pendingJourney = nil
    commander.scriptState.calendarLedger?.legacyUntrackedJourney = false
  }
  /// Physical wake entry supplies a sealed current passage, not a manufactured countdown.
  mutating func completeWormholeCalendarJourney(_ passage: NativeCommanderWormholePassage)
    -> ScriptCalendarJourney?
  {
    guard passage.matches(self) else { return nil }
    ensureScriptCalendar(origin: .newCommander)
    guard var ledger = commander.scriptState.calendarLedger, ledger.pendingJourney == nil,
      ledger.operation < UInt64(Int64.max) - 1
    else { return nil }
    let route = passage.opening.route
    let journey = ScriptCalendarJourney(operation: ledger.operation + 1,
      galaxy: route.origin.galaxy, origin: route.origin.system.id,
      destination: route.destination.system.id, sourceDistance: route.distanceLightYears,
      nativeFuelDebit: passage.fuelDebit)
    let before = commander.scriptState.calendarSeconds
    guard journey.valid, before <= 1e12 - journey.seconds,
      commander.scriptState.transitSeconds <= 1e12 - journey.seconds,
      missionCalendarCanAdd(journey.seconds)
    else { return nil }
    ledger.operation = journey.operation
    commander.scriptState.calendarSeconds += journey.seconds
    commander.scriptState.transitSeconds += journey.seconds
    mirrorMissionCalendar(seconds: journey.seconds, operation: journey.operation)
    ledger.lastAdjustment = .init(operation: journey.operation, kind: .jump,
      seconds: journey.seconds, before: before, after: commander.scriptState.calendarSeconds)
    commander.scriptState.calendarLedger = ledger
    return journey
  }
  mutating func completeCalendarJourney() -> ScriptCalendarJourney? {
    guard var ledger = commander.scriptState.calendarLedger else { return nil }
    guard let journey = ledger.pendingJourney,
      journey.galaxy == commander.galaxy, journey.origin == commander.system,
      jumpCountdown != nil
    else {
      cancelCalendarJourney()
      return nil
    }
    let before = commander.scriptState.calendarSeconds
    guard before <= 1e12 - journey.seconds,
      commander.scriptState.transitSeconds <= 1e12 - journey.seconds,
      missionCalendarCanAdd(journey.seconds) else {
      return nil
    }
    commander.scriptState.calendarSeconds += journey.seconds
    commander.scriptState.transitSeconds += journey.seconds
    mirrorMissionCalendar(seconds: journey.seconds, operation: journey.operation)
    ledger.lastAdjustment = .init(
      operation: journey.operation, kind: .jump,
      seconds: journey.seconds, before: before, after: commander.scriptState.calendarSeconds)
    ledger.pendingJourney = nil
    ledger.legacyUntrackedJourney = false
    commander.scriptState.calendarLedger = ledger
    return journey
  }
  var calendarActive: Bool {
    if docked && [Screen.chart, .shortChart, .system, .inventory].contains(screen) { return false }
    return !paused
      && ![
        Screen.title, .demo, .gameOver, .gallery, .library, .help, .navigation,
        .mission, .handoff, .rumour, .secret, .showroom, .contracts,
      ].contains(screen)
  }
}

extension GameRuntime {
  func migrateScriptCalendar(_ candidate: inout Game, untrackedJump: Bool = false) {
    let missing = candidate.commander.scriptState.calendarLedger == nil
    candidate.ensureScriptCalendar(origin: .inactiveLegacyMigration)
    if missing, untrackedJump || candidate.jumpCountdown != nil {
      candidate.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
    }
  }
}
