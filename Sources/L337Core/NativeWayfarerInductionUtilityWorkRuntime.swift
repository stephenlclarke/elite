import Foundation

private final class NativeInductionUtilityWorkAttempt {
  var game: Game
  init(_ game: borrowing Game) { self.game = copy game }
}

extension Game {
  var inductionUtilityQualifiedSeconds: Double {
    inductionUtilityChild?.savedNativeInductionUtility?.modules.reduce(0) {
      $0 + ($1.work?.seconds ?? 0)
    } ?? 0
  }

  /// Attained partial time survives a refused write; a kit/control transition remains candidate-only.
  mutating func advanceInductionUtilityWork(
    from start: NativeInductionUtilityEndpoint?,
    publish: ScriptPublisher?
  ) {
    let end = inductionUtilityEndpoint()
    let attained: Bool
    if let start, let end {
      attained =
        start.sameAuthority(end)
        && NativeInductionUtilityEnvelope.credit(before: 0, start: start.time, end: end.time) != nil
    } else {
      attained = false
    }
    if attained, let start, let end {
      observeInductionUtilityWork(start: start, end: end)
    } else if inductionUtilityWorkRuntime.arm != nil {
      inductionUtilityWorkRuntime.reason =
        "PAUSED: keep the unobstructed front surface50-150m away, relative speed<=1m/s, aim<=2deg. Partial work stays."
    }
    guard let publish else { return }
    var finish = false
    if let arm = inductionUtilityWorkRuntime.arm,
      let state = inductionUtilityChild?.savedNativeInductionUtility,
      let module = state.modules.first(where: { $0.role == arm.role }), let work = module.work
    {
      finish = work.seconds >= 20 - 1e-8 && work.repair == nil
    }
    let checkpoint =
      inductionUtilityWorkRuntime.dirty
      && (inductionUtilityQualifiedSeconds - inductionUtilityWorkRuntime.publishedSeconds >= 0.5
        || inductionUtilityWorkRuntime.arm == nil || paused || !screen.isFlight)
    guard checkpoint || (finish && attained) else { return }
    let attempt = NativeInductionUtilityWorkAttempt(self)
    do {
      // Repair requires a fresh attained interval as well as the accumulated original work.
      if finish, attained, let end {
        try attempt.game.completeInductionUtilityRepair(at: end)
      }
      attempt.game.persistScriptActors()
      guard attempt.game.commander.valid else { throw SaveError.invalidCommander }
      try publish(&attempt.game)
      self = attempt.game
    } catch {
      inductionUtilityWorkRuntime.reason =
        "MEASURED WORK RETAINED - SAVE/REPAIR PUBLICATION PENDING; KIT AND CONTROL NOT COMMITTED"
    }
  }

  private mutating func observeInductionUtilityWork(
    start: NativeInductionUtilityEndpoint,
    end: NativeInductionUtilityEndpoint
  ) {
    guard let arm = inductionUtilityWorkRuntime.arm, start.arm == arm.operation,
      var child = inductionUtilityChild, var state = child.savedNativeInductionUtility,
      child.revision < UInt64(Int64.max) - 2,
      let index = state.modules.firstIndex(where: { $0.role == arm.role }),
      var work = state.modules[index].work, work.repair == nil,
      var segment = work.segments.last, segment.arm == arm,
      segment.intervals < 999_999_999,
      start.time >= (segment.last ?? arm.physicalTime),
      let credit = NativeInductionUtilityEnvelope.credit(
        before: work.seconds, start: start.time, end: end.time)
    else { return }
    if credit > 0 {
      segment.first = segment.first ?? start.time
      segment.last = end.time
      segment.seconds += credit
      segment.intervals += 1
      segment.lastRange = end.range
      segment.lastSpeed = end.speed
      segment.lastAim = end.aim
      work.segments[work.segments.count - 1] = segment
      state.modules[index].work = work
      child.savedNativeInductionUtility = state
      child.revision += 1
      commander.scriptState.instances[child.id] = child
      inductionUtilityWorkRuntime.dirty = true
    }
    inductionUtilityWorkRuntime.reason = String(
      format: "%@ MEASURED WORK %.2f /20s - ONE LOCAL KIT ONLY AT COMPLETION",
      arm.role.rawValue.uppercased(), work.seconds)
  }

  private mutating func completeInductionUtilityRepair(at end: NativeInductionUtilityEndpoint)
    throws
  {
    guard let arm = inductionUtilityWorkRuntime.arm, end.arm == arm.operation,
      var child = inductionUtilityChild, var state = child.savedNativeInductionUtility,
      let index = state.modules.firstIndex(where: { $0.role == arm.role }),
      state.modules[index].availableKits == 1, state.modules[index].fault == arm.role.initialFault,
      var work = state.modules[index].work, work.repair == nil, abs(work.seconds - 20) < 1e-8,
      work.segments.last?.arm == arm,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let source = try NativeInductionUtilitySource(parent: leaf)
    let sequence = commander.scriptState.nextEvent + 1
    let history = try NativeFlightReception.hash(work.segments)
    let operation = try NativeInductionUtilityRepair.identity(
      authorization: state.authorization.operation,
      module: source.module(arm.role), kit: source.kit(arm.role), history: history,
      actor: end.actor, time: end.time, sequence: sequence)
    work.repair = .init(
      operation: operation, sequence: sequence,
      authorization: state.authorization.operation, owner: source.owner, job: child.id,
      role: arm.role, module: source.module(arm.role), kit: source.kit(arm.role),
      actor: end.actor, history: history, physicalTime: end.time,
      flightSeconds: commander.scriptState.flightSeconds)
    state.modules[index].work = work
    state.modules[index].availableKits = 0
    state.modules[index].fault = arm.role.workingFault
    guard state.shapeValid(parent: leaf) else { throw SaveError.invalidCommander }
    child.savedNativeInductionUtility = state
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    child.journal.append(
      "Actual20s native remote work restored original " + arm.role.target
        + "; its single original local crew kit was consumed with the working control. No player cargo, energy or money charge; no stage10 receiving yet."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    inductionUtilityWorkRuntime.arm = nil
    inductionUtilityWorkRuntime.dirty = true
    inductionUtilityWorkRuntime.reason =
      arm.role.rawValue.uppercased() + " WORKING / ORIGINAL KIT CONSUMED - ENRON RECEIVES ALL THREE"
    notify("ENRON " + arm.role.rawValue.uppercased() + " ACTUALLY REPAIRED - ONE CREW KIT CONSUMED")
  }
}
