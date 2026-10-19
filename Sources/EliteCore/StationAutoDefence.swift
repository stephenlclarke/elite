import Foundation

/// Guidance is descriptive. Current native geometry, law and emitters remain authoritative.
struct StationAutoGuidance: Sendable {
  let aim: Vector3?
  let lateralVelocity: Vector3
  var hazard = StationAutoHazard.clear
  var interruptionAllowed = false
  var clearanceRadius = 0.0
  var handoverAllowed = false
  var movingEntryAllowed = false
  var joinedIncoming = false
  var transitGoal: Vector3? = nil
  var protectFrontShield = false

  var hasManeuver: Bool { aim != nil || lateralVelocity.length > 0 || transitGoal != nil }
}

enum StationAutoHazard: Sendable, Equatable {
  case clear, closing, active, unknown
}

/// Transient, actor-owned state; never saved or accepted as attack/entry evidence.
struct StationAutoDefenceState: Sendable {
  let station: ActorIdentity
  let player: ActorIdentity
  var combatActor: ActorIdentity?
  var evasionWorld: Vector3?
  var missilePublicationRefused = false
  var saveBinding: URL?
  /// First opted-in active decision near staging; never entry or attack authority.
  var firstEntryCourseObservation: [String: String]?
  var firstEntryCourseRefusalObservation: [String: String]?
}

private struct StationAutoAssessment {
  let context: EncounterContext
  let threats: [SpaceBody]
  let incoming: [SpaceBody]
}

extension Game {
  var stationAutoDockingActive: Bool {
    guard !docked, !paused, screen.isFlight, energy.isFinite, energy > 0,
      jumpCountdown == nil, workGuidance == nil,
      workBraking == nil,
      commander.hasAutomaticDocking, targetingEnabled || autoPilot.manualEngagement,
      let station = autoTargetBody, station.hull == .station, station.energy.isFinite,
      station.energy > 0,
      station.position.finite, station.position.length.isFinite, station.orientation.validRotation,
      let actor = station.physical?.identity, autoPilot.targetActor == actor,
      bodies.filter({ $0.id == station.id }).count == 1,
      bodies.filter({ $0.physical?.identity == actor }).count == 1,
      let player = commander.flightSimulation.player,
      actor.system == player.system, actor.visit == player.visit
    else { return false }
    return station.nativeStationIdentity == nil
      ? station.id == 0 && actor == commander.flightSimulation.anchors?.station.identity
      : nativeStationBodyIsCurrent(station)
  }

  private func stationAutoAssessment() -> StationAutoAssessment? {
    guard stationAutoDockingActive, let context = gameplayContext(),
      context.player.identity == commander.flightSimulation.player,
      context.revision == gameplayRevision, context.system == systemIdentity,
      context.visit == commander.flightSimulation.visit,
      context.player.identity.system == context.system,
      context.player.identity.visit == context.visit,
      context.physicalTime == commander.flightSimulation.physicalTime,
      context.physicalTime.isFinite, context.player.position.finite,
      context.player.orientation.validRotation,
      context.actors.filter({ $0.hull == .station }).allSatisfy({
        $0.position.finite && $0.energy.isFinite && $0.orientation.validRotation
      })
    else { return nil }
    let player = context.player.identity
    let threats = bodies.filter {
      ($0.energy > 0 || !$0.energy.isFinite) && $0.hull.isTargetShip
        && ($0.hostile || $0.physical?.npc?.intention == .engage(player)
          || $0.physical.map {
            commander.crimeLedger.hasCurrentUnlawfulAttack(
              from: $0.identity, against: player, context: context)
          } == true)
    }
    let incoming = bodies.filter {
      guard $0.energy > 0 || !$0.energy.isFinite else { return false }
      if let physical = $0.physical, let ordnance = physical.ordnance, ordnance.valid,
        physical.identity == ordnance.origin.ordnance,
        physical.identity.system == context.system, physical.identity.visit == context.visit,
        physical.attackOrigin == ordnance.origin
      {
        return ordnance.target == player && ordnance.termination == nil
      }
      return $0.enemyMissile || $0.hull == .missile || $0.scriptShot != nil
        || $0.physical?.population == .projectile
    }
    return .init(context: context, threats: threats, incoming: incoming)
  }

  private func stationAutoKnownTarget(_ body: SpaceBody, context: EncounterContext) -> Bool {
    guard pendingNativeStationDock == nil, !isEMPDisabled(body), let physical = body.physical,
      let npc = physical.npc,
      physical.empSource == nil, physical.salvage == nil,
      npc.intention == .engage(context.player.identity)
        || commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: physical.identity, against: context.player.identity, context: context),
      physical.identity != context.player.identity,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      body.position.finite, body.position.length.isFinite, body.energy.isFinite, body.energy > 0,
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
      context.actors.filter({ $0.identity == physical.identity }).count == 1,
      let snapshot = context.actors.first(where: { $0.identity == physical.identity }),
      snapshot.hull == body.hull, snapshot.npc == npc, snapshot.energy == body.energy,
      npc.resources?.valid == true, body.scriptNPC == nil, body.scriptShot == nil,
      ShipCatalogue.nativeShip(body.hull) != nil,
      physical.catalogueShipID == nil
        || physical.catalogueShipID == ShipCatalogue.nativeShip(body.hull)?.id,
      !context.protection.protectedActors.contains(physical.identity)
    else { return false }
    return commander.crimeLedger.permitsAutonomousDefence(
      owner: context.player.identity, victim: physical.identity, context: context)
  }

  private func stationAutoPulseOnly(_ body: SpaceBody, context: EncounterContext) -> Bool {
    guard stationAutoKnownTarget(body, context: context), body.missiles == 0,
      body.missionInstanceID == nil, !body.navalTarget, body.blackjackRole == nil,
      ![Hull.constrictor, .thargoid, .thargon].contains(body.hull),
      body.physical?.spawnIdentity?.producer == .ambient,
      body.physical?.npc?.intention == .engage(context.player.identity)
    else { return false }
    return true
  }

  private func stationAutoImmediate(_ body: SpaceBody, context: EncounterContext) -> Bool {
    guard stationAutoPulseOnly(body, context: context),
      let actor = context.actors.first(where: { $0.identity == body.physical?.identity }),
      actor.maximumSpeedUnitsPerSecond.isFinite, actor.velocity.finite,
      context.player.maximumSpeedUnitsPerSecond.isFinite, context.player.velocity.finite
    else { return true }
    let closing =
      0.1
      * (max(actor.maximumSpeedUnitsPerSecond, actor.velocity.length)
        + max(context.player.maximumSpeedUnitsPerSecond, context.player.velocity.length))
    return !closing.isFinite || body.position.length <= 1500 + closing
  }

  private func stationAutoThreatObserved(_ body: SpaceBody, context: EncounterContext) -> Bool {
    guard let physical = body.physical, let npc = physical.npc, npc.resources?.valid == true,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      physical.identity != context.player.identity,
      body.position.finite, body.position.length.isFinite, body.energy.isFinite,
      body.orientation.validRotation, physical.velocity.finite,
      bodies.filter({ $0.id == body.id }).count == 1,
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
      context.actors.filter({ $0.identity == physical.identity }).count == 1,
      let snapshot = context.actors.first(where: { $0.identity == physical.identity }),
      snapshot.hull == body.hull, snapshot.npc == npc, snapshot.energy == body.energy,
      body.scriptNPC == nil, body.scriptShot == nil,
      let native = ShipCatalogue.nativeShip(body.hull),
      physical.catalogueShipID == nil || physical.catalogueShipID == native.id,
      physical.empSource == nil || isEMPDisabled(body)
    else { return false }
    return true
  }

  /// Current observations only; scan all sources even after finding an authentic attacker.
  private func stationAutoHazards(
    _ assessment: StationAutoAssessment, observation: inout [String: String]?
  ) -> (
    hazard: StationAutoHazard, handoverKnown: Bool, joinedIncoming: Bool, courseKnown: Bool
  ) {
    let context = assessment.context
    var uncertain = false
    var closing = false
    var active = false
    var joinedIncoming = false
    for body in assessment.incoming {
      if let physical = body.physical, let ordnance = physical.ordnance, ordnance.valid,
        physical.identity == ordnance.origin.ordnance,
        physical.identity.system == context.system, physical.identity.visit == context.visit,
        physical.attackOrigin == ordnance.origin,
        ordnance.origin.owner.system == context.system,
        ordnance.origin.owner.visit == context.visit,
        ordnance.origin.emittedAt <= context.physicalTime,
        ordnance.lastUpdatedAt <= context.physicalTime,
        ordnance.target == context.player.identity, ordnance.termination == nil,
        body.position.finite, body.energy.isFinite,
        bodies.filter({ $0.id == body.id }).count == 1,
        bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
        context.actors.filter({ $0.identity == physical.identity }).count == 1
      {
        active = true
        joinedIncoming = true
      } else {
        if observation?["uncertainBody"] == nil {
          observation?["uncertainBody"] = String(body.id)
        }
        uncertain = true
      }
    }
    for body in assessment.threats {
      guard stationAutoThreatObserved(body, context: context), let physical = body.physical,
        let npc = physical.npc
      else {
        if observation?["uncertainBody"] == nil {
          observation?["uncertainBody"] = String(body.id)
        }
        uncertain = true
        continue
      }
      if isEMPDisabled(body) { continue }
      guard
        commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: physical.identity, against: context.player.identity, context: context)
      else { continue }
      // Native ordinary flee/navigation does not emit a beam or run hostile naval tactics.
      if !body.hostile, physical.spawnIdentity?.producer == .ambient,
        body.missionInstanceID == nil, !body.navalTarget,
        body.blackjackRole == nil, ![Hull.constrictor, .thargoid, .thargon].contains(body.hull)
      {
        switch npc.intention {
        case .flee, .navigate, .dock: continue
        default: break
        }
      }
      let pulseOnly = stationAutoPulseOnly(body, context: context)
      if pulseOnly && !stationAutoImmediate(body, context: context) { continue }
      // Only genuine stationary station geometry constitutes cover; a moving ship is not cover.
      let towardPlayer = body.position * -1
      if towardPlayer.length > 0 {
        do {
          if let hit = try nearestMissionCollision(
            from: body.position, direction: towardPlayer.unit, range: towardPlayer.length,
            radius: 0, excludingBodyIDs: [body.id], includePlayer: true),
            case .body(let id) = hit.hit.target,
            let cover = bodies.first(where: { $0.id == id }), cover.hull == .station,
            cover.nativeStationIdentity != nil
              ? nativeStationBodyIsCurrent(cover)
              : cover.id == 0 && cover.physical?.identity == context.anchors.station.identity
          {
            continue
          }
        } catch {
          observation?["coverQueryError"] = String(String(describing: error).prefix(128))
          if observation?["uncertainBody"] == nil {
            observation?["uncertainBody"] = String(body.id)
          }
          uncertain = true
          continue
        }
      }
      if pulseOnly && body.position.length > 1500 {
        closing = true
      } else {
        active = true
      }
    }
    let hazard: StationAutoHazard =
      active ? .active : (uncertain ? .unknown : (closing ? .closing : .clear))
    // An authenticated beam without real station cover is still active pressure.
    // Knowing its source does not make stationary docking alignment safe.
    return (
      hazard, !active && !uncertain && assessment.incoming.isEmpty, joinedIncoming,
      !uncertain && assessment.incoming.isEmpty
    )
  }

  mutating func stationAutoGuidance(target station: SpaceBody) -> StationAutoGuidance? {
    guard let assessment = stationAutoAssessment(), let stationActor = station.physical?.identity,
      stationActor == autoPilot.targetActor, station.id == autoPilot.targetID
    else {
      stationAutoDefence = nil
      return .init(aim: nil, lateralVelocity: .init(0, 0, 0), hazard: .unknown)
    }
    let context = assessment.context
    var courseObservation: [String: String]? = gameplayCombatTrace == nil ? nil : [:]
    let observations = stationAutoHazards(assessment, observation: &courseObservation)
    let hazard = observations.hazard
    let stationMesh = gameplayMeshOverrides[station.id] ?? Mesh.hull(station.hull)
    let structureRadius =
      (stationMesh.vertices.map(\.length).max() ?? .infinity)
      + (commander.playerMesh.vertices.map(\.length).max() ?? .infinity)
    let clearanceRadius = max(station.stationClearanceRadius, structureRadius)
    let interruptionAllowed =
      pendingNativeStationDock == nil && !station.containsPlayer
      && clearanceRadius.isFinite
    if stationAutoDefence?.station != stationActor
      || stationAutoDefence?.player != context.player.identity
    {
      stationAutoDefence = .init(station: stationActor, player: context.player.identity)
    }
    let movingEntryAllowed =
      hazard == .active && observations.courseKnown
      && stationAutoMovingEntryAllowed(station, observation: &courseObservation)
    if courseObservation != nil, hazard == .active,
      stationAutoDefence?.firstEntryCourseObservation == nil
        || (!movingEntryAllowed && stationAutoDefence?.firstEntryCourseRefusalObservation == nil)
    {
      // This observation-only radius includes the entire existing staging neighbourhood.
      // It changes no permission and does not re-evaluate any failed course predicate.
      let range = station.position.length
      let portOffset = (station.entrancePosition - station.position).length
      let nearRange =
        station.stationApproachDistance + portOffset + AutoTargetControl.stationStagingTolerance
      if range.isFinite, range <= nearRange {
        courseObservation?["time"] = String(context.physicalTime)
        courseObservation?["revision"] = String(gameplayRevision)
        courseObservation?["targetBody"] = String(station.id)
        courseObservation?["target"] =
          "\(stationActor.system.galaxy)/\(stationActor.system.system)/\(stationActor.visit)/\(stationActor.entity)"
        courseObservation?["player"] =
          "\(context.player.identity.system.galaxy)/\(context.player.identity.system.system)/\(context.player.identity.visit)/\(context.player.identity.entity)"
        courseObservation?["courseKnown"] = String(observations.courseKnown)
        courseObservation?["joinedIncoming"] = String(observations.joinedIncoming)
        courseObservation?["incomingCount"] = String(assessment.incoming.count)
        courseObservation?["movingEntryAllowed"] = String(movingEntryAllowed)
        courseObservation?["controllerPhase"] = String(describing: autoPilot.stationDefencePhase)
        courseObservation?["controllerFinal"] = String(autoPilot.finalApproach)
        courseObservation?["position"] =
          "\(context.player.position.x),\(context.player.position.y),\(context.player.position.z)"
        courseObservation?["targetRange"] = String(range)
        if !observations.courseKnown { courseObservation?["refusal"] = "hazard.observations" }
        if stationAutoDefence?.firstEntryCourseObservation == nil {
          stationAutoDefence?.firstEntryCourseObservation = courseObservation
        }
        if !movingEntryAllowed && stationAutoDefence?.firstEntryCourseRefusalObservation == nil {
          stationAutoDefence?.firstEntryCourseRefusalObservation = courseObservation
        }
      }
    }
    let nearby = assessment.threats.filter { stationAutoImmediate($0, context: context) }
    let response = militaryRetaliationEnabled ? retaliation.pendingResponse(time: time) : nil
    let confirmed = assessment.threats.first { body in
      response.map {
        $0.source == body.id && $0.actor == body.physical?.identity && $0.actor != nil
      } == true
        && stationAutoKnownTarget(body, context: context)
    }
    let authenticated = nearby.filter { body in
      guard let actor = body.physical?.identity else { return false }
      return stationAutoKnownTarget(body, context: context)
        && commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: actor, against: context.player.identity, context: context)
    }
    let previous = stationAutoDefence?.combatActor
    let combat: SpaceBody?
    if let confirmed {
      combat = confirmed
    } else if let retained = authenticated.first(where: { $0.physical?.identity == previous }) {
      combat = retained
    } else if let nearest = authenticated.min(by: { $0.position.length < $1.position.length }) {
      combat = nearest
    } else {
      let eligible = nearby.filter { stationAutoKnownTarget($0, context: context) }
      combat =
        eligible.first(where: { $0.physical?.identity == previous })
        ?? eligible.min {
          $0.position.length == $1.position.length
            ? $0.id < $1.id : $0.position.length < $1.position.length
        }
    }
    // Retention chooses only among fresh policy results, never cached attack authority.
    if previous != combat?.physical?.identity { autoPilot.resetTargetMotion() }
    stationAutoDefence?.combatActor = combat?.physical?.identity
    let dangers = nearby + assessment.incoming + (confirmed.map { [$0] } ?? [])
    guard
      let danger = dangers.first(where: { !$0.position.finite || !$0.position.length.isFinite })
        ?? dangers.min(by: { $0.position.length < $1.position.length })
    else {
      stationAutoDefence?.evasionWorld = nil
      return .init(
        aim: nil, lateralVelocity: .init(0, 0, 0), hazard: hazard,
        interruptionAllowed: interruptionAllowed, clearanceRadius: clearanceRadius,
        handoverAllowed: observations.handoverKnown && interruptionAllowed,
        movingEntryAllowed: movingEntryAllowed, joinedIncoming: observations.joinedIncoming)
    }
    let goal = station.entrancePosition + station.entranceNormal * station.stationApproachDistance
    let route = goal.unit
    if stationAutoDefence?.evasionWorld == nil {
      var lateral =
        danger.position.finite && danger.position.length.isFinite
        ? danger.position * -1 : .init(0, 0, 0)
      lateral = lateral - route * lateral.dot(route)
      if lateral.length < 1e-8 { lateral = route.cross(.init(0, 1, 0)) }
      if lateral.length < 1e-8 { lateral = route.cross(.init(1, 0, 0)) }
      let worldLateral = commander.flightSimulation.pose.orientation.apply(lateral.unit)
      stationAutoDefence?.evasionWorld = worldLateral
    }
    let side = commander.flightSimulation.pose.shipVector(
      stationAutoDefence?.evasionWorld ?? .init(0, 0, 0))
    let lateral = (side - route * side.dot(route)).unit
    let pressure =
      !assessment.incoming.isEmpty || !danger.position.finite || !danger.position.length.isFinite
      ? 1.0
      : max(
        stationAutoPulseOnly(danger, context: context) ? 0 : 0.25,
        max(0, 1 - danger.position.length / 1500))
    let front = commander.laser(on: .front)
    let canFaceForResponse =
      (front != nil && front != .mining)
      || commander.missiles > 0 || commander.unlimitedMissiles
    let aim = canFaceForResponse ? combat?.position : nil
    var transitGoal: Vector3?
    if hazard == .active, let combat, let source = combat.physical?.identity,
      commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: source, against: context.player.identity, context: context)
    {
      // Seek the far side of the real station, rather than brake to rest at its
      // exposed staging point. This is a route request, never proof of cover.
      let away = station.position - combat.position
      let radius = clearanceRadius + AutoTargetControl.stationStagingTolerance
      let goal = station.position + away.unit * radius
      if away.length.isFinite, away.length > 0, radius.isFinite, goal.finite { transitGoal = goal }
    }
    let protectFrontShield =
      transitGoal != nil && frontShield.isFinite && rearShield.isFinite
      && frontShield < rearShield * 0.75
    return .init(
      aim: aim, lateralVelocity: lateral * (workLimits.speed * 0.35 * pressure),
      hazard: hazard, interruptionAllowed: interruptionAllowed, clearanceRadius: clearanceRadius,
      handoverAllowed: observations.handoverKnown && interruptionAllowed,
      movingEntryAllowed: movingEntryAllowed,
      joinedIncoming: observations.joinedIncoming, transitGoal: transitGoal,
      protectFrontShield: protectFrontShield)
  }

  /// A current motion proposal, never native docking or attack authority.
  private func stationAutoMovingEntryAllowed(
    _ station: SpaceBody, observation: inout [String: String]?
  ) -> Bool {
    observation?["refusal"] = "motion.context"
    guard pendingNativeStationDock == nil, !station.containsPlayer,
      station.entranceNormal.finite, station.entranceUp.finite,
      workLimits.acceleration.isFinite, workLimits.acceleration > 0,
      workLimits.speed.isFinite, workLimits.speed > 0
    else { return false }
    let normal = station.entranceNormal
    let door = station.entrancePosition
    let depth = -door.dot(normal)
    let lateral = door - normal * door.dot(normal)
    let facing = hypot(atan2(-normal.y, hypot(normal.x, normal.z)), atan2(-normal.x, -normal.z))
    let phase = abs(atan2(station.entranceUp.x, station.entranceUp.y))
    let rate = abs(autoPilot.rollRate + station.rotationRate * station.orientation.z.z)
    let relative = commander.flightSimulation.pose.shipVector(
      flightWorldVelocity - nativeStationVelocity(station))
    let outward = relative.dot(normal)
    let lateralVelocity = relative - normal * outward
    let speed = relative.length
    observation?["refusal"] = "motion.depth"
    observation?["depth"] = String(depth)
    guard depth.isFinite, depth > 0 else { return false }
    let maximumDepth = station.stationApproachDistance + AutoTargetControl.stationStagingTolerance
    observation?["refusal"] = "motion.approach-range"
    observation?["maximumDepth"] = String(maximumDepth)
    guard depth <= maximumDepth else { return false }
    observation?["refusal"] = "motion.heading"
    observation?["facing"] = String(facing)
    guard facing < 0.02 else { return false }
    observation?["refusal"] = "motion.phase"
    observation?["phase"] = String(phase)
    guard phase < 0.03 else { return false }
    observation?["refusal"] = "motion.rate"
    observation?["rate"] = String(rate)
    guard rate < 0.02 else { return false }
    let lateralDistance = lateral.length
    observation?["refusal"] = "motion.lateral"
    observation?["lateral"] = String(lateralDistance)
    guard lateralDistance < 15 else { return false }
    observation?["refusal"] = "motion.relative-velocity"
    guard relative.finite, speed.isFinite else { return false }
    observation?["refusal"] = "motion.outward"
    observation?["outward"] = String(outward)
    observation?["relativeVelocity"] = "\(relative.x),\(relative.y),\(relative.z)"
    guard outward <= 0 else { return false }
    let lateralSpeed = lateralVelocity.length
    observation?["refusal"] = "motion.lateral-speed"
    observation?["lateralSpeed"] = String(lateralSpeed)
    guard lateralSpeed < 1 else { return false }
    // Preserve both original limit reads, after all preceding predicates pass.
    let speedLimit = workLimits.speed
    let speedUlp = speed.ulp
    let limitUlp = workLimits.speed.ulp
    let speedBound = speedLimit + max(speedUlp, limitUlp) * 16
    observation?["refusal"] = "motion.speed"
    observation?["relativeSpeed"] = String(speed)
    observation?["speedLimit"] = String(speedLimit)
    observation?["speedBound"] = String(speedBound)
    guard speed <= speedBound else { return false }
    // The existing final controller targets 48 before the actual <144 native crossing gate.
    // Zero inward speed is allowed only on this already aligned, immediately usable course.
    let terminal = min(48, workLimits.speed)
    let braking =
      speed > terminal
      ? (speed * speed - terminal * terminal) / (2 * workLimits.acceleration) + speed * 0.1 : 0
    observation?["refusal"] = "motion.braking"
    observation?["braking"] = String(braking)
    guard braking.isFinite, braking <= depth else { return false }
    let advance = normal * -(depth - min(0.5, depth * 0.5))
    return nativeStationAutoEntryCourseIsClear(
      station, advance: advance, terminalSpeed: terminal, observation: &observation)
  }

  private func stationAutoRayTarget(_ mount: LaserMount) -> SpaceBody? {
    let direction: Vector3
    switch mount {
    case .front: direction = .init(0, 0, 1)
    case .rear: direction = .init(0, 0, -1)
    case .left: direction = .init(-1, 0, 0)
    case .right: direction = .init(1, 0, 0)
    }
    guard
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: direction, range: 6000, radius: 0,
        excludingBodyIDs: [], includePlayer: false), case .body(let id) = contact.hit.target
    else { return nil }
    return bodies.first { $0.id == id }
  }

  mutating func fireStationAutoLaser() {
    guard let assessment = stationAutoAssessment(), !playerEMPDisabled,
      !workFireSuspended, fireCooldown <= 0, laserHeat < 240, energy > 1
    else { return }
    // A shot must not consume the strict native activation reserve before incoming detection.
    // Reserve even before a launcher acts later in this same frame; manual fire is unchanged.
    if !ecmControl.fieldActive, commander.fittedEquipment(at: .utility(.ecm)) != nil,
      energy - Self.combatLaserEnergyCost <= ECMControl.activationEnergyCost
    {
      return
    }
    for mount in LaserMount.allCases {
      guard let laser = commander.laser(on: mount), laser != .mining,
        let target = stationAutoRayTarget(mount),
        assessment.threats.contains(where: { $0.id == target.id }),
        stationAutoKnownTarget(target, context: assessment.context)
      else { continue }
      fireLaser(mount: mount)
      return
    }
  }

  func stationAutoMissileTarget() -> SpaceBody? {
    guard let assessment = stationAutoAssessment(), !playerEMPDisabled,
      !workFireSuspended, !ecmControl.fieldActive, missileCooldown == 0, energy > 1,
      commander.missiles > 0 || commander.unlimitedMissiles,
      stationAutoDefence?.missilePublicationRefused != true, assessment.incoming.isEmpty
    else { return nil }
    let response = militaryRetaliationEnabled ? retaliation.pendingResponse(time: time) : nil
    let confirmed = assessment.threats.first { body in
      response.map {
        $0.source == body.id && $0.actor != nil && $0.actor == body.physical?.identity
      } == true
        && stationAutoKnownTarget(body, context: assessment.context)
    }
    let needsMissile =
      max(0, laserHeat - 0.1 * 12) >= 240
      || commander.laser(on: .front) == nil || commander.laser(on: .front) == .mining
    // Filter each actor's genuine response eligibility before selecting nearest.
    // A closer unhurt craft must not mask a current authenticated attacker.
    let target =
      confirmed
      ?? assessment.threats.filter { body in
        guard body.position.z > 0, stationAutoImmediate(body, context: assessment.context),
          stationAutoKnownTarget(body, context: assessment.context),
          let actor = body.physical?.identity
        else { return false }
        return needsMissile
          || commander.crimeLedger.hasCurrentUnlawfulAttack(
            from: actor, against: assessment.context.player.identity, context: assessment.context)
      }.min { $0.position.length < $1.position.length }
    guard let target, target.position.z > 0, let actor = target.physical?.identity,
      !bodies.contains(where: {
        $0.energy > 0
          && $0.physical?.ordnance.map {
            $0.origin.owner == assessment.context.player.identity && $0.target == actor
              && $0.termination == nil
          } == true
      })
    else { return nil }
    // Native homing launch is forward and then seeks its explicit target; a laser ray is not a lock.
    // Keep the muzzle and first maximum physical step clear of unrelated geometry.
    let clearance = 24 + OrdnanceProfile.standardMissile.speed * 0.1
    do {
      if let contact = try nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: clearance, radius: 0,
        excludingBodyIDs: [], includePlayer: false)
      {
        guard case .body(let id) = contact.hit.target, id == target.id else { return nil }
      }
      // Check the explicit homing source's current mesh line separately from the forward muzzle.
      // This permits off-axis locks while refusing a station or unrelated intervening body.
      let muzzle = Vector3(0, 0, 24)
      let offset = target.position - muzzle
      guard offset.length.isFinite, offset.length > 0,
        let source = try nearestMissionCollision(
          from: muzzle, direction: offset.unit, range: offset.length, radius: 0,
          excludingBodyIDs: [], includePlayer: false),
        case .body(let id) = source.hit.target, id == target.id
      else { return nil }
    } catch { return nil }
    return target
  }

}

extension GameRuntime {
  /// The candidate projectile and consumption cannot enter simulation before publication.
  func advanceStationAutoMissile(delta: Double) {
    guard game.stationAutoDockingActive else {
      game.stationAutoDefence = nil
      return
    }
    if let station = game.autoTargetBody?.physical?.identity,
      let player = game.commander.flightSimulation.player,
      game.stationAutoDefence?.station != station || game.stationAutoDefence?.player != player
    {
      game.stationAutoDefence = .init(station: station, player: player)
    }
    if game.stationAutoDefence?.saveBinding != scriptSaveURL {
      game.stationAutoDefence?.saveBinding = scriptSaveURL
      game.stationAutoDefence?.missilePublicationRefused = false
    }
    guard delta.isFinite, delta > 0, controls.pitch == 0, controls.yaw == 0,
      controls.roll == 0, controls.throttle == 0, !controls.fire,
      let url = scriptSaveURL, let target = game.stationAutoMissileTarget()
    else { return }
    let before = game
    var candidate = before
    guard candidate.launchGameplayMissile(targetBodyID: target.id) else { return }
    candidate.missileCooldown = 1
    do {
      try requireGalleryFileAccess(url)
      try Self.writeCommander(&candidate, to: url)
      game = candidate
      game.notify("AUTO DEFENCE: MISSILE AWAY", voiced: !game.militaryRetaliationEnabled)
      if let actor = target.physical?.identity, game.militaryRetaliationEnabled {
        game.retaliation.reconcileResponse(bodyID: target.id, actor: actor)
        game.retaliation.report("MISSILE LAUNCHED AT ENEMY CRAFT #\(target.id)")
        game.ecmControl.emit(.missileLaunched(target.hull.modelName + " #\(target.id)"))
      }
    } catch {
      // No physical frame, emitted actor or ammunition mutation has been installed.
      game = before
      if game.stationAutoDefence == nil, let station = game.autoTargetBody?.physical?.identity,
        let player = game.commander.flightSimulation.player
      {
        game.stationAutoDefence = .init(station: station, player: player)
      }
      game.stationAutoDefence?.missilePublicationRefused = true
      game.notify("AUTO DEFENCE: MISSILE LAUNCH UNAVAILABLE")
    }
  }
}
