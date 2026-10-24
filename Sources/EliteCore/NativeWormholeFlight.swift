import Foundation

extension Game {
  /// A physical frame can interrupt an admitted spool, never complete one or spend fuel.
  /// This cheap observer keeps continuous damage/power/clearance loss out of the receipt path.
  mutating func observeNativeTransitSpool(_ body: SpaceBody) {
    guard let actor = body.missionActorID,
      let entry = commander.scriptState.wormholeTransit?.legs.first(where: {
        $0.value.actor == actor && $0.value.phase == .spooling
      }), let drive = entry.value.driveTerms, drive.valid,
      (0...128).contains(entry.value.attempts)
    else { return }
    var leg = entry.value
    let refusal: NativeWormholeRefusal?
    if body.energy <= 0 || body.physical?.identity != leg.spoolActor {
      refusal = .actorUnavailable
    } else if body.scriptNPC?.components[drive.component]?.energy ?? 0 <= 0 {
      refusal = .driveUnavailable
    } else if isEMPDisabled(body)
      || body.physical?.npc?.resources?.electrical.map({ $0.remaining <= 0 }) == true
    {
      refusal = .disabled
    } else if (body.scriptNPC?.fuel ?? -1) < (leg.route?.distanceLightYears ?? .infinity) {
      refusal = .insufficientFuel
    } else {
      let distance = 600 * drive.massLockScale
      refusal =
        body.position.length < distance
          || bodies.contains(where: {
            $0.id != body.id && $0.hull != .cargo && ($0.position - body.position).length < distance
          })
          || celestials.contains(where: {
            ($0.position - body.position).length < $0.radius * 4 * drive.massLockScale
          }) ? .massLocked : nil
    }
    guard let refusal else { return }
    leg.phase = .requested
    leg.attempts = min(128, leg.attempts + 1)
    leg.nextAttemptAt = min(1e12, commander.scriptState.calendarSeconds + 2)
    leg.spooledAt = nil
    leg.spoolActor = nil
    leg.spoolPhysicalTime = nil
    leg.driveComponent = nil
    leg.driveTerms = nil
    leg.refusal = refusal.rawValue
    commander.scriptState.wormholeTransit?.legs[entry.key] = leg
  }
  func nativeTransitSteeringGoal(_ body: SpaceBody, intent: ScriptNPCIntent? = nil) -> Vector3? {
    guard let actor = body.missionActorID,
      let leg = commander.scriptState.wormholeTransit?.legs.values.first(where: {
        $0.actor == actor && $0.phase == .open
      }), let hole = leg.opening, let request = intent ?? body.scriptNPC?.intent,
      request.mode == .approach, request.request == leg.request,
      commander.scriptState.calendarSeconds <= hole.expiresAt,
      hole.route.origin.location == systemIdentity, let anchor = scriptAnchor
    else { return nil }
    return anchor.position + anchor.orientation.apply(request.offset)
  }

  /// A rejected crossing uses normal controls to return, stop, turn and cross again.
  /// The actual intent waypoint supplies hysteresis; no vanished actor/GPS or old sweep is reused.
  func nativeTransitSteeringIntent(_ body: SpaceBody, intent: ScriptNPCIntent) -> ScriptNPCIntent {
    guard let goal = nativeTransitSteeringGoal(body, intent: intent),
      let leg = commander.scriptState.wormholeTransit?.legs.values.first(where: {
        $0.actor == body.missionActorID && $0.phase == .open
      }), let hole = leg.opening, let anchor = scriptAnchor
    else { return intent }
    let pose = commander.flightSimulation.pose
    let position = pose.systemPoint(body.position)
    let currentSide = hole.entrance.orientation.inverse(position - hole.entrance.position).z
    let goalSide = hole.entrance.orientation.inverse(
      pose.systemPoint(goal) - hole.entrance.position
    ).z
    let retreat = hole.entrance.position + hole.entrance.orientation.z * (hole.radius * 2)
    let newGoal: Vector3
    if goalSide < 0 && currentSide <= 0 {
      newGoal = retreat
    } else if goalSide > 0 && (position - retreat).length <= 2
      && (body.scriptNPC?.velocity.length ?? .infinity) <= 1
    {
      newGoal = hole.entrance.position - hole.entrance.orientation.z * (hole.radius * 2)
    } else {
      return intent
    }
    let offset = anchor.orientation.inverse(pose.shipPoint(newGoal) - anchor.position)
    return .init(
      request: intent.request, mode: intent.mode, target: nil, player: false,
      offset: offset, speed: intent.speed, tolerance: intent.tolerance)
  }
  /// Transit steering proposes ordinary bounded motion. Native continuous clearance admits
  /// the whole controlled cohort before positions can become departure evidence.
  mutating func resolveNativeTransitMotion(before: [SpaceBody], delta: Double) {
    guard let ledger = commander.scriptState.wormholeTransit else { return }
    let controlled = Set(
      ledger.legs.values.filter {
        $0.phase == .open || $0.phase == .arrived
      }.map(\.actor))
    let selected = bodies.indices.filter { index in
      guard let actor = bodies[index].missionActorID, controlled.contains(actor) else {
        return false
      }
      return nativeTransitSteeringGoal(bodies[index]) != nil
        || bodies[index].scriptNPC?.intent == nil
          && nativeTransitExitClearanceGoal(bodies[index]) != nil
    }
    guard !selected.isEmpty else { return }
    let sample = NativeWormholeMotionSample.profiledMotion(in: self, before: before, delta: delta)
    do {
      for index in selected {
        let body = bodies[index]
        guard let identity = body.physical?.identity,
          let previous = before.first(where: { $0.physical?.identity == identity }),
          let mesh = scriptNPCMesh(body)
        else { throw NativeWormholeRefusal.unsafeSweep }
        let radius = try NativeWormholeSweep.radius(mesh)
        try proveNativeWormholeMotion(
          from: sample.pose.systemPoint(previous.position),
          to: sample.pose.systemPoint(body.position), radius: radius, excluding: identity,
          sample: sample, includePlayer: true)
      }
    } catch {
      for index in selected {
        guard
          let previous = before.first(where: {
            $0.physical?.identity == bodies[index].physical?.identity
          })
        else { continue }
        bodies[index].position = previous.position
        bodies[index].orientation = previous.orientation
        bodies[index].scriptNPC?.velocity = .init(0, 0, 0)
      }
    }
  }
  var hasNativeWormholeMotionObservers: Bool {
    guard let ledger = commander.scriptState.wormholeTransit else { return false }
    let now = commander.scriptState.calendarSeconds
    return ledger.legs.values.contains { leg in
      guard let hole = leg.opening, hole.route.origin.location == systemIdentity,
        hole.openedAt <= now && now <= hole.expiresAt
      else { return false }
      return leg.phase == .open || ledger.commanderPassages[hole.id] == nil
    }
  }
  /// Uncommanded arrivals clear their actual exit through ordinary acceleration/turn limits.
  /// This fixed aperture point is not a moving actor/GPS target or an escort reception.
  func nativeTransitExitClearanceGoal(_ body: SpaceBody) -> Vector3? {
    guard let actor = body.missionActorID,
      let leg = commander.scriptState.wormholeTransit?.legs.values.first(where: {
        $0.actor == actor && $0.phase == .arrived
          && $0.route?.destination.location == systemIdentity
      }), let route = leg.route, let mesh = scriptNPCMesh(body),
      let radius = mesh.vertices.map(\.length).max(), radius.isFinite, radius > 0
    else { return nil }
    let pose = commander.flightSimulation.pose
    guard (pose.systemPoint(body.position) - route.exit.position).length < radius * 4 else {
      return nil
    }
    return pose.shipPoint(route.exit.position + route.exit.orientation.z * (radius * 6))
  }
}
