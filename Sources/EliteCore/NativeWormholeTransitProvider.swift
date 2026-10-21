import Foundation

extension Game {
  mutating func requestScriptNPCTransit(
    _ command: ScriptValue, pack: ScriptPack,
    state: ScriptInstance
  ) throws -> (String, [String: ScriptValue])? {
    guard pack.manifest.capabilities.contains("npc-wormhole-transit-v2"),
      pack.manifest.capabilities.contains("mission-calendar-v2"),
      state.outcome == .active, state.suspension == nil,
      let fields = command.object,
      Set(fields.keys) == ["op", "id", "encounter", "actor", "destination"],
      let request = fields["id"]?.string, PackValidation.localID(request),
      let encounterID = fields["encounter"]?.string,
      let alias = fields["actor"]?.string,
      let destination = fields["destination"]?.string, PackValidation.identifier(destination),
      let encounter = state.ownedEncounters[encounterID], encounter.admitted,
      let actor = encounter.actors[alias], actor.presence == .present,
      actor.body.energy > 0, actor.body.scriptNPC?.fit.definition.drive != nil,
      actor.location(in: encounter) == systemIdentity
    else {
      throw MissionPackError(
        "Transit requires a declared living owned NPC, drive and exact world ID.")
    }
    var ledger = commander.scriptState.wormholeTransit ?? .init()
    let id = NativeWormholeLeg.identity(instance: state.id, actor: actor.identity, request: request)
    if let old = ledger.legs[id] {
      guard
        old.destinationWorld == destination && old.encounter == encounterID && old.alias == alias
      else {
        throw MissionPackError("A transit leg cannot change its accepted destination.")
      }
      return nil
    }
    guard ledger.legs.count < 128,
      !ledger.legs.values.contains(where: {
        $0.actor == actor.identity && ![.arrived, .cancelled].contains($0.phase)
      })
    else {
      throw MissionPackError(
        "The actor already has an active journey or the transit ledger is full.")
    }
    let leg = NativeWormholeLeg(
      id: id, instance: state.id, actor: actor.identity,
      encounter: encounterID, alias: alias, request: request, destinationWorld: destination,
      requestedAt: commander.scriptState.calendarSeconds)
    ledger.legs[id] = leg
    guard ledger.valid else { throw SaveError.invalidCommander }
    commander.scriptState.wormholeTransit = ledger
    return (
      "actor.transit.requested",
      [
        "actor_id": .string(actor.identity.uuidString),
        "leg_id": .string(id.uuidString), "destination": .string(destination),
      ]
    )
  }

  /// This barrier runs after attained physical motion/deaths. Writer failure never rolls those
  /// effects back, and never publishes a debit, detachment, arrival or transit event partially.
  mutating func advanceNativeNPCTransit(
    from sample: NativeWormholeMotionSample?,
    publish: ScriptPublisher?, binding: ((String) -> OriginalWorldJourneyContext?)? = nil
  ) {
    guard let publish, !paused, screen != .gameOver,
      let ledger = commander.scriptState.wormholeTransit, ledger.valid
    else { return }
    for id in ledger.legs.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let leg = commander.scriptState.wormholeTransit?.legs[id],
        ![.arrived, .cancelled].contains(leg.phase)
      else { continue }
      var candidate = self
      do {
        let context =
          binding?(leg.destinationWorld)
          ?? OriginalWorldJourneyContext.production(
            in: self, destinationWorld: leg.destinationWorld)
        guard try candidate.advanceNativeNPCTransitLeg(id, sample: sample, context: context) else {
          continue
        }
        candidate.persistScriptActors()
        guard candidate.commander.valid else { throw SaveError.invalidCommander }
        try publish(&candidate)
        self = candidate
      } catch {
        // Existing physical damage/motion is the baseline. Retry needs a fresh actual sweep.
        continue
      }
    }
  }

  private mutating func advanceNativeNPCTransitLeg(
    _ id: UUID,
    sample: NativeWormholeMotionSample?, context: OriginalWorldJourneyContext?
  ) throws -> Bool {
    guard var leg = commander.scriptState.wormholeTransit?.legs[id], leg.valid else {
      throw NativeWormholeRefusal.stale
    }
    let now = commander.scriptState.calendarSeconds
    if let due = leg.dueAt {
      guard now >= due else { return false }
      leg.phase = .arrivalPending
      commander.scriptState.wormholeTransit?.legs[id] = leg
      guard let context, context.route == leg.route,
        context.matches(self, at: systemIdentity),
        systemIdentity == context.route.destination.location,
        !docked
      else {
        return leg.refusal == "Destination scene unavailable"
          ? false : setTransitRefusal(id, "Destination scene unavailable")
      }
      return try admitNativeTransitArrival(id, context: context)
    }
    if let opening = leg.opening {
      if now > opening.expiresAt {
        leg.phase = .cancelled
        leg.refusal = NativeWormholeRefusal.expired.rawValue
        commander.scriptState.wormholeTransit?.legs[id] = leg
        return true
      }
      guard let context, context.route == opening.route else { return false }
      // Open/intent is never departure. Only this frame's attained physical crossing can enter.
      guard let sample else { return false }
      let source = try NativeNPCDriveSource.resolve(in: self, leg: leg, context: context)
      guard source.component == leg.driveComponent, source.terms == leg.driveTerms else {
        throw NativeWormholeRefusal.driveUnavailable
      }
      return try enterNativeTransit(id, source: source, sample: sample)
    }
    guard now >= leg.nextAttemptAt, leg.attempts < 128 else { return false }
    leg.attempts += 1
    leg.nextAttemptAt = min(1e12, now + 2)
    commander.scriptState.wormholeTransit?.legs[id] = leg
    do {
      guard let context else { throw NativeWormholeRefusal.worldUnavailable }
      let source = try NativeNPCDriveSource.resolve(in: self, leg: leg, context: context)
      if leg.phase != .spooling || leg.route != context.route
        || leg.driveComponent != source.component || leg.driveTerms != source.terms
      {
        leg.phase = .spooling
        leg.route = context.route
        leg.driveComponent = source.component
        leg.driveTerms = source.terms
        leg.spooledAt = now
        leg.refusal = nil
        commander.scriptState.wormholeTransit?.legs[id] = leg
        return true
      }
      guard let start = leg.spooledAt, now - start >= source.terms.activationSeconds else {
        return true
      }
      try openNativeTransit(id, source: source, context: context)
      return true
    } catch let refusal as NativeWormholeRefusal {
      // Interrupted spooling cannot bank activation time through damage, EMP or mass lock.
      leg.phase = .requested
      leg.spooledAt = nil
      leg.driveComponent = nil
      leg.driveTerms = nil
      leg.refusal = refusal.rawValue
      commander.scriptState.wormholeTransit?.legs[id] = leg
      return true
    }
  }

  private mutating func setTransitRefusal(_ id: UUID, _ reason: String) -> Bool {
    commander.scriptState.wormholeTransit?.legs[id]?.refusal = reason
    return true
  }

  private mutating func openNativeTransit(
    _ id: UUID, source: NativeNPCDriveSource,
    context: OriginalWorldJourneyContext
  ) throws {
    guard var leg = commander.scriptState.wormholeTransit?.legs[id],
      let anchor = scriptAnchor, commander.scriptState.calendarSeconds <= 1e12 - 120
    else { throw NativeWormholeRefusal.stale }
    let pose = commander.flightSimulation.pose
    let forward = pose.orientation.apply(source.body.orientation.z)
    var basis = source.body.orientation.transformed(by: pose.orientation)
    basis.x = basis.x * -1
    basis.z = basis.z * -1
    let radius = max(20, source.radius * 2)
    let entrance = ShipPose(
      position: pose.systemPoint(source.body.position)
        + forward * max(500, source.radius * 4), orientation: basis)
    let opening = NativeWormholeOpening(
      id: ScriptIdentity.uuid("native-wormhole-v1:\(id)"),
      leg: id, route: context.route, sourceActor: source.actor, entrance: entrance,
      radius: radius, openedAt: commander.scriptState.calendarSeconds,
      expiresAt: commander.scriptState.calendarSeconds + 120)
    guard opening.valid else { throw NativeWormholeRefusal.stale }
    leg.opening = opening
    leg.phase = .open
    leg.refusal = nil
    commander.scriptState.wormholeTransit?.legs[id] = leg
    // Steer through, then beyond the real aperture using the existing acceleration/turn controller.
    let goal = entrance.position + forward * (radius * 2)
    let offset = anchor.orientation.inverse(pose.shipPoint(goal) - anchor.position)
    let intent = ScriptNPCIntent(
      request: leg.request, mode: .approach, target: nil,
      player: false, offset: offset, speed: 1, tolerance: 1)
    guard intent.valid,
      let index = bodies.firstIndex(where: { $0.physical?.identity == source.actor })
    else {
      throw NativeWormholeRefusal.stale
    }
    bodies[index].scriptNPC?.intent = intent
    emitNativeTransitEvent("actor.transit.opened", leg: leg)
  }

  private mutating func enterNativeTransit(
    _ id: UUID, source: NativeNPCDriveSource,
    sample: NativeWormholeMotionSample
  ) throws -> Bool {
    guard var leg = commander.scriptState.wormholeTransit?.legs[id], let opening = leg.opening,
      leg.departure == nil, sample.system == systemIdentity,
      sample.visit == commander.flightSimulation.visit,
      let before = sample.bodies.first(where: { $0.physical?.identity == source.actor }),
      before.missionActorID == leg.actor,
      let index = bodies.firstIndex(where: { $0.physical?.identity == source.actor }),
      let anchor = scriptAnchor
    else { throw NativeWormholeRefusal.stale }
    let from = sample.pose.systemPoint(before.position)
    let to = commander.flightSimulation.pose.systemPoint(source.body.position)
    guard
      NativeWormholeSweep.crosses(
        opening: opening, from: from, to: to,
        hullRadius: source.radius)
    else { return false }
    try proveNativeTransitSweep(source: source, before: before, sample: sample)
    // All entry guards have passed. The candidate contains the only reservoir debit and detachment.
    bodies[index].scriptNPC?.fuel = source.fuel - opening.route.distanceLightYears
    var retained = bodies[index]
    retained.position = anchor.orientation.inverse(retained.position - anchor.position)
    retained.orientation = retained.orientation.relative(to: anchor.orientation)
    retained.scriptNPC?.velocity = anchor.orientation.inverse(
      retained.scriptNPC?.velocity ?? .init(0, 0, 0))
    let departure = NativeWormholeDeparture(
      hole: opening.id, nativeActor: source.actor,
      calendarSeconds: commander.scriptState.calendarSeconds,
      physicalTime: commander.flightSimulation.physicalTime, revision: gameplayRevision,
      fuelBefore: source.fuel, fuelAfter: source.fuel - opening.route.distanceLightYears,
      body: retained)
    leg.departure = departure
    leg.phase = .inTransit
    guard leg.valid else { throw NativeWormholeRefusal.stale }
    commander.scriptState.instances[leg.instance]?.ownedEncounters[leg.encounter]?.actors[
      leg.alias]?.body = retained
    commander.scriptState.instances[leg.instance]?.ownedEncounters[leg.encounter]?.actors[
      leg.alias]?.presence = .inTransit
    commander.scriptState.wormholeTransit?.legs[id] = leg
    clearRemovedTarget(bodies[index])
    bodies.remove(at: index)
    emitNativeTransitEvent("actor.transit.departed", leg: leg)
    return true
  }

  private mutating func admitNativeTransitArrival(_ id: UUID, context: OriginalWorldJourneyContext)
    throws -> Bool
  {
    let source = try transitMissionActorAdmissionSource(id, context: context)
    switch try prepareMissionActorAdmission(source) {
    case .pending:
      return setTransitRefusal(id, "Destination native admission pending")
    case .unchanged:
      throw NativeWormholeRefusal.stale
    case .ready(let plan):
      guard let owner = commander.scriptState.instances[source.instanceID],
        var leg = commander.scriptState.wormholeTransit?.legs[id]
      else { throw NativeWormholeRefusal.stale }
      let staged = try plan.retentionPatch.preparingInstance(owner)
      let receipt = try commitMissionActorAdmission(plan)
      guard let actor = receipt.nativeActors[leg.actor] else { throw NativeWormholeRefusal.stale }
      commander.scriptState.instances[source.instanceID] = staged
      leg.arrival = .init(
        nativeActor: actor, calendarSeconds: commander.scriptState.calendarSeconds)
      leg.phase = .arrived
      leg.refusal = nil
      commander.scriptState.wormholeTransit?.legs[id] = leg
      emitNativeTransitEvent("actor.transit.arrived", leg: leg)
      return true
    }
  }

  private mutating func emitNativeTransitEvent(_ kind: String, leg: NativeWormholeLeg) {
    emitScriptEvent(
      kind,
      values: [
        "actor_id": .string(leg.actor.uuidString),
        "leg_id": .string(leg.id.uuidString), "destination": .string(leg.destinationWorld),
      ],
      only: leg.instance, drain: false)
  }
}
