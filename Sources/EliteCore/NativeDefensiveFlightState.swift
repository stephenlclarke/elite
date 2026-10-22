import Foundation

struct NativeDefensiveFlightPermission: Codable, Sendable, Equatable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let dock: NativeMainStationDockReceipt
  let consent: ScriptChoiceReceipt
  let acceptedAt: Double

  var valid: Bool {
    acceptedAt.isFinite && (0...1e12).contains(acceptedAt) && dock.valid
      && dock.commanderOwner == owner && dock.station.system == NativeDefensiveFlight.location
      && consent.instance == mission && consent.group == NativePracticeSource.consentGroup
      && consent.choice == NativePracticeSource.consentChoice
      && consent.committed.nativeMainDock == dock && consent.committed.valid
      && consent.committed.mainStation
  }
}

struct NativeDefensiveFlightSample: Codable, Sendable, Equatable {
  let reading: NativeDefensiveFlightGeometry.Reading
  let manual: Bool
  let clear: Bool
  let centreContact: ActorIdentity?

  func valid(in original: NativePracticeState) -> Bool {
    let r = reading
    return r.operation == original.permission.operation && r.player == original.permission.player
      && r.centreActor == original.beacons.first(where: { $0.ordinal == 1 })?.actor
      && r.time.isFinite && r.time >= original.permission.begunAt && r.time <= 1e12
      && r.position.finite && r.position.length.isFinite && r.velocity.finite && r.speed.isFinite
      && r.forward.finite && abs(r.forward.length - 1) < 1e-6
      && (centreContact == nil || centreContact == r.centreActor)
  }

  func qualifies(phase: Int, radius: Double) -> Bool {
    guard manual, clear else { return false }
    switch phase {
    case 0:
      return centreContact == reading.centreActor
        && NativeDefensiveFlightGeometry.acquisitionAligned(reading)
    case 1:
      return NativeDefensiveFlightGeometry.insideGate(
        .positive, reading: reading, measuredHullRadius: radius)
    case 2:
      return NativeDefensiveFlightGeometry.insideGate(
        .negative, reading: reading, measuredHullRadius: radius)
    case 3:
      return NativeDefensiveFlightGeometry.withdrawing(reading, measuredHullRadius: radius)
    default: return false
    }
  }
}

struct NativeDefensiveFlightWindow: Codable, Sendable, Equatable {
  let phase: Int
  let first: NativeDefensiveFlightSample
  let last: NativeDefensiveFlightSample
  let duration: Double
}

struct NativeDefensiveFlightCrossing: Codable, Sendable, Equatable {
  let first: NativeDefensiveFlightSample
  let last: NativeDefensiveFlightSample
  var valid: Bool { motionValid && first.reading.position.x > 0 && last.reading.position.x <= 0 }
  var motionValid: Bool {
    let delta = last.reading.time - first.reading.time
    return delta > 0 && delta <= 0.100001
      && first.manual && first.clear && last.manual && last.clear
      && first.reading.operation == last.reading.operation
      && first.reading.player == last.reading.player
      && NativeDefensiveFlightState.continuous(first, last, delta: delta)
  }
}

enum NativeDefensiveFlightFailure: Codable, Sendable, Equatable {
  case discharge(player: ActorIdentity, emission: UInt64?, time: Double)
  case ordinaryHit(CombatIncident)
  case collision(player: ActorIdentity, time: Double)
  case interruption(player: ActorIdentity, time: Double, reason: Interruption)
  enum Interruption: String, Codable, Sendable { case docked, visitChanged, hullChanged, shipLost }
  case nearPass(
    first: NativeDefensiveFlightGeometry.Reading, last: NativeDefensiveFlightGeometry.Reading)
}

/// Native interval evidence only. Narrative data and a position assignment cannot advance it.
struct NativeDefensiveFlightState: Codable, Sendable, Equatable {
  let permission: NativeDefensiveFlightPermission
  private(set) var attemptPlayer: ActorIdentity?
  private(set) var original: NativePracticeState?
  private(set) var hullRadius: Double?
  private(set) var windows: [NativeDefensiveFlightWindow] = []
  private(set) var crossing: NativeDefensiveFlightCrossing?
  private(set) var pending: NativeDefensiveFlightWindow?
  private(set) var previous: NativeDefensiveFlightSample?
  private var liveEndpoint: NativeDefensiveFlightSample? = nil
  private(set) var positiveEntry: NativeDefensiveFlightCrossing?
  private(set) var negativeEntry: NativeDefensiveFlightCrossing?

  enum CodingKeys: String, CodingKey {
    case permission, attemptPlayer, original, hullRadius, windows, crossing, pending, previous
    case positiveEntry, negativeEntry, failure, disengagedCalendar, terminalOperation, terminalDock,
      terminalOutcome
  }
  private(set) var failure: NativeDefensiveFlightFailure?
  private(set) var disengagedCalendar: Double?
  var terminalOperation: UUID?
  var terminalDock: NativeMainStationDockReceipt?
  var terminalOutcome: ScriptOutcome?

  static let durations = [2.0, 0.5, 0.5, 3.0]
  var workVerified: Bool { failure == nil && windows.count == 4 && crossing != nil }
  var ready: Bool { valid && terminalOutcome == nil && workVerified && disengagedCalendar != nil }
  var milestones: Set<Int> {
    Set(
      [0] + (original == nil ? [] : [1]) + windows.indices.map { $0 + 2 }
        + (terminalOutcome == .complete ? [6] : []))
  }

  func matches(_ practice: NativePracticeState) -> Bool {
    guard let original else { return false }
    return practice.valid && practice.permission == original.permission
      && practice.beacons == original.beacons
  }

  var valid: Bool {
    guard permission.valid, windows.count <= 4,
      (windows.count == 4) == (disengagedCalendar != nil),
      terminalOutcome.map({ [.complete, .failed, .abandoned].contains($0) }) ?? true,
      (terminalOutcome == nil) == (terminalOperation == nil)
    else { return false }
    if let attemptPlayer {
      guard attemptPlayer.entity == 0, attemptPlayer.system == permission.dock.station.system,
        attemptPlayer.visit > permission.dock.actor.visit, attemptPlayer.visit < UInt64.max
      else { return false }
    }
    if let outcome = terminalOutcome {
      guard
        terminalOperation
          == ScriptIdentity.uuid(
            "defensive-flight-terminal-v1:\(permission.mission):\(outcome.rawValue)"),
        failure == nil || outcome == .failed, outcome != .failed || failure != nil
      else { return false }
      if outcome == .complete {
        guard workVerified, let disengagedCalendar, let dock = terminalDock, dock.valid,
          dock.station == permission.dock.station, dock.commanderOwner == permission.owner,
          dock.sequence > permission.dock.sequence, dock.calendarSeconds > disengagedCalendar,
          let original, dock.actor.visit >= original.permission.player.visit
        else { return false }
      } else if terminalDock != nil {
        return false
      }
    } else if terminalDock != nil {
      return false
    }
    guard failureValid,
      disengagedCalendar.map({
        $0.isFinite && $0 >= permission.dock.calendarSeconds && workVerified
      }) ?? true
    else { return false }
    guard let original else {
      return hullRadius == nil && windows.isEmpty && crossing == nil && pending == nil
        && previous == nil && positiveEntry == nil && negativeEntry == nil
        && terminalOutcome != .complete
    }
    guard original.valid, original.permission.player == attemptPlayer,
      original.endedAt == nil, original.hits.isEmpty,
      original.permission.lesson == .defensiveFlight,
      original.permission.mission == permission.mission,
      original.permission.owner == permission.owner,
      original.permission.carrier == permission.carrier,
      original.permission.consent == permission.consent,
      original.permission.digest == NativeDefensiveFlight.digest,
      let radius = hullRadius, NativeDefensiveFlightGeometry.hullFits(radius: radius)
    else { return false }
    var lastTime = original.permission.begunAt
    for (phase, window) in windows.enumerated() {
      guard window.phase == phase, window.first.valid(in: original),
        window.last.valid(in: original),
        window.first.qualifies(phase: phase, radius: radius),
        window.last.qualifies(phase: phase, radius: radius),
        window.first.reading.time >= lastTime, window.duration >= Self.durations[phase],
        window.duration <= Self.durations[phase] + 0.100001,
        window.last.reading.time - window.first.reading.time >= window.duration - 1e-9
      else { return false }
      lastTime = window.last.reading.time
    }
    for (phase, entry) in [(1, positiveEntry), (2, negativeEntry)] {
      if let entry {
        let gate = phase == 1 ? NativeDefensiveFlightGeometry.Gate.positive : .negative
        guard entry.motionValid, entry.first.valid(in: original), entry.last.valid(in: original),
          windows.count >= phase,
          phase != 2
            || (crossing.map { $0.last.reading.time <= entry.first.reading.time } ?? false),
          entry.first.reading.time >= windows[phase - 1].last.reading.time,
          (entry.first.reading.position - gate.offset).length
            > NativeDefensiveFlightGeometry.gateRadius,
          (entry.last.reading.position - gate.offset).length
            <= NativeDefensiveFlightGeometry.gateRadius,
          windows.count <= phase || entry.last.reading.time <= windows[phase].first.reading.time
        else { return false }
      } else if windows.count > phase {
        return false
      }
    }
    if let crossing {
      guard windows.count >= 2, crossing.valid,
        crossing.first.valid(in: original), crossing.last.valid(in: original),
        crossing.first.reading.time >= windows[1].last.reading.time,
        windows.count < 3 || crossing.last.reading.time <= windows[2].first.reading.time
      else { return false }
    } else if windows.count >= 3 {
      return false
    }
    if let pending {
      guard failure == nil, terminalOutcome == nil, windows.count < 4,
        pending.phase == windows.count, pending.first.valid(in: original),
        pending.last.valid(in: original),
        pending.first.qualifies(phase: pending.phase, radius: radius),
        pending.last.qualifies(phase: pending.phase, radius: radius),
        pending.first.reading.time >= lastTime, pending.duration >= 0,
        pending.duration < Self.durations[pending.phase],
        pending.last.reading.time - pending.first.reading.time >= pending.duration - 1e-9,
        previous.map({ $0.reading.time >= pending.last.reading.time }) ?? false
      else { return false }
    }
    return previous.map { $0.valid(in: original) && $0.reading.time >= lastTime } ?? true
  }

  /// The first actual launch visit owns this attempt even while traffic delays admission.
  mutating func launched(player: ActorIdentity) throws {
    guard valid, failure == nil, terminalOutcome == nil, attemptPlayer == nil,
      player.entity == 0, player.system == permission.dock.station.system,
      player.visit > permission.dock.actor.visit, player.visit < UInt64.max
    else { throw SaveError.invalidCommander }
    attemptPlayer = player
  }

  mutating func begin(_ provider: NativePracticeState, radius: Double) throws {
    guard valid, original == nil, failure == nil, terminalOutcome == nil,
      provider.valid, provider.endedAt == nil, provider.hits.isEmpty,
      provider.permission.lesson == .defensiveFlight,
      provider.permission.mission == permission.mission,
      provider.permission.owner == permission.owner,
      provider.permission.carrier == permission.carrier,
      provider.permission.consent == permission.consent,
      provider.permission.digest == NativeDefensiveFlight.digest,
      NativeDefensiveFlightGeometry.hullFits(radius: radius),
      attemptPlayer == nil || attemptPlayer == provider.permission.player
    else { throw SaveError.invalidCommander }
    attemptPlayer = provider.permission.player
    original = provider
    hullRadius = radius
  }

  mutating func observe(
    before: NativeDefensiveFlightSample?, after: NativeDefensiveFlightSample?, delta: Double
  ) throws {
    if delta == 0 { return }
    guard valid, failure == nil, terminalOutcome == nil, let original, let radius = hullRadius
    else { throw SaveError.invalidCommander }
    func entered(
      _ gate: NativeDefensiveFlightGeometry.Gate,
      _ a: NativeDefensiveFlightSample, _ b: NativeDefensiveFlightSample
    ) -> Bool {
      (a.reading.position - gate.offset).length > NativeDefensiveFlightGeometry.gateRadius
        && (b.reading.position - gate.offset).length <= NativeDefensiveFlightGeometry.gateRadius
    }
    guard let after, after.valid(in: original) else {
      pending = nil
      previous = nil
      liveEndpoint = nil
      return
    }
    let saved = previous
    let live = liveEndpoint
    previous = after
    liveEndpoint = after
    // A restored saved endpoint is only a consistency reference. Both observations below
    // must be freshly produced by the current native step; no saved sample earns a delta.
    guard let before, before.valid(in: original), saved?.reading == before.reading,
      live.map({ $0.reading == before.reading }) ?? true,
      Self.continuous(before, after, delta: delta)
    else {
      pending = nil
      if windows.count == 1 { positiveEntry = nil }
      if windows.count == 2 { negativeEntry = nil }
      return
    }
    for beacon in original.beacons {
      let point = NativePracticeSource.offsets[beacon.ordinal] - NativePracticeSource.volumeOffset
      // Include a full speed/time travel bound around the attained segment. Endpoint
      // clearance alone cannot certify a potentially curved within-step movement.
      if NativeDefensiveFlightGeometry.segmentDistance(
        point, start: before.reading.position, end: after.reading.position)
        <= radius + NativePracticeSource.radius + 32
        + max(before.reading.speed, after.reading.speed) * delta
      {
        failure = .nearPass(first: before.reading, last: after.reading)
        pending = nil
        return
      }
    }
    guard before.manual, before.clear, after.manual, after.clear else {
      pending = nil
      return
    }
    if windows.count == 2, crossing == nil,
      before.reading.position.x > 0, after.reading.position.x <= 0
    {
      crossing = .init(first: before, last: after)
    }
    guard windows.count < 4 else {
      pending = nil
      return
    }
    let phase = windows.count
    if phase == 1, entered(.positive, before, after) {
      positiveEntry = .init(first: before, last: after)
    }
    if phase == 2, crossing != nil, entered(.negative, before, after) {
      negativeEntry = .init(first: before, last: after)
    }
    guard phase != 1 || positiveEntry != nil,
      phase != 2 || (crossing != nil && negativeEntry != nil),
      before.qualifies(phase: phase, radius: radius), after.qualifies(phase: phase, radius: radius)
    else {
      pending = nil
      return
    }
    let next = NativeDefensiveFlightWindow(
      phase: phase, first: pending?.first ?? before, last: after,
      duration: (pending?.duration ?? 0) + delta)
    if next.duration >= Self.durations[phase] {
      windows.append(next)
      pending = nil
    } else {
      pending = next
    }
  }

  static func continuous(
    _ before: NativeDefensiveFlightSample, _ after: NativeDefensiveFlightSample, delta: Double
  ) -> Bool {
    let a = before.reading
    let b = after.reading
    guard delta.isFinite, delta > 0, delta <= 0.100001,
      a.operation == b.operation, a.player == b.player, a.centreActor == b.centreActor,
      abs(b.time - a.time - delta) <= max(1e-9, 4 * max(a.time.ulp, b.time.ulp))
    else { return false }
    return (b.position - a.position).length <= max(a.speed, b.speed) * delta + 1e-6
  }

  mutating func sealDisengagement(calendar: Double) throws {
    guard workVerified, disengagedCalendar == nil, calendar.isFinite,
      calendar >= permission.dock.calendarSeconds
    else { throw SaveError.invalidCommander }
    var candidate = self
    candidate.disengagedCalendar = calendar
    candidate.previous = nil
    candidate.liveEndpoint = nil
    guard candidate.valid else { throw SaveError.invalidCommander }
    self = candidate
  }

  mutating func retireEndpoints() {
    pending = nil
    previous = nil
    liveEndpoint = nil
  }

  mutating func recordFailure(_ value: NativeDefensiveFlightFailure) {
    guard valid, failure == nil, terminalOutcome == nil, disengagedCalendar == nil else { return }
    let old = failure
    failure = value
    guard failureValid else {
      failure = old
      return
    }
    pending = nil
  }

  private var failureValid: Bool {
    guard let failure else { return true }
    func player(_ actor: ActorIdentity, time: Double) -> Bool {
      actor.entity == 0 && actor.visit > permission.dock.actor.visit
        && time.isFinite && time >= permission.acceptedAt && time <= 1e12
    }
    switch failure {
    case .discharge(let actor, let emission, let time):
      return player(actor, time: time) && (emission.map { $0 > 0 && $0 < UInt64.max } ?? true)
    case .collision(let actor, let time), .interruption(let actor, let time, _):
      return player(actor, time: time)
    case .ordinaryHit(let incident):
      return player(incident.origin.owner, time: incident.physicalTime)
        && incident.id > 0 && incident.id < UInt64.max && incident.origin.emissionID > 0
        && incident.origin.emittedAt.isFinite && incident.origin.emittedAt <= incident.physicalTime
        && incident.origin.emittedAt >= permission.acceptedAt
        && [.hit, .destruction, .componentDestruction].contains(incident.outcome)
        && incident.victim?.system == incident.origin.owner.system
        && incident.victim?.visit == incident.origin.owner.visit
        && !(original?.beacons.contains(where: { $0.actor == incident.victim }) ?? false)
    case .nearPass(let a, let b):
      guard let original, let radius = hullRadius,
        a.operation == original.permission.operation, b.operation == a.operation,
        a.player == original.permission.player, b.player == a.player,
        NativeDefensiveFlightSample(reading: a, manual: false, clear: false, centreContact: nil)
          .valid(in: original),
        NativeDefensiveFlightSample(reading: b, manual: false, clear: false, centreContact: nil)
          .valid(in: original),
        a.time >= original.permission.begunAt, b.time > a.time, b.time - a.time <= 0.100001
      else { return false }
      return original.beacons.contains {
        NativeDefensiveFlightGeometry.segmentDistance(
          NativePracticeSource.offsets[$0.ordinal] - NativePracticeSource.volumeOffset,
          start: a.position, end: b.position) <= radius + NativePracticeSource.radius + 32
          + max(a.speed, b.speed) * (b.time - a.time)
      }
    }
  }
}

enum NativeDefensiveFlight {
  static let stateID = NativeDefensiveFlightGeometry.stateID
  static let version = "1.0.0"
  static let location = SystemIdentity(galaxy: 0, system: 7)
  static let boardID = "defensive-flight"
  static let digest = "bbc09f53e0136157ab35dad216feb1af23c0547ef763f5d2d5bd59889188ca47"
}
