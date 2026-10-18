import Foundation

/// Guidance is descriptive. Current native geometry, law and emitters remain authoritative.
struct StationAutoGuidance: Sendable {
  let aim: Vector3?
  let lateralVelocity: Vector3
}

/// Transient, actor-owned state; never saved or accepted as attack/entry evidence.
struct StationAutoDefenceState: Sendable {
  let station: ActorIdentity
  let player: ActorIdentity
  var combatActor: ActorIdentity?
  var evasionWorld: Vector3?
  var missilePublicationRefused = false
  var saveBinding: URL?
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

  mutating func stationAutoGuidance(target station: SpaceBody) -> StationAutoGuidance? {
    guard let assessment = stationAutoAssessment(), let stationActor = station.physical?.identity
    else {
      stationAutoDefence = nil
      return nil
    }
    let context = assessment.context
    if stationAutoDefence?.station != stationActor
      || stationAutoDefence?.player != context.player.identity
    {
      stationAutoDefence = .init(station: stationActor, player: context.player.identity)
    }
    let nearby = assessment.threats.filter { stationAutoImmediate($0, context: context) }
    let response = militaryRetaliationEnabled ? retaliation.pendingResponse(time: time) : nil
    let confirmed = assessment.threats.first { body in
      response.map {
        $0.source == body.id && $0.actor == body.physical?.identity && $0.actor != nil
      } == true
        && stationAutoKnownTarget(body, context: context)
    }
    let combat =
      confirmed
      ?? nearby.filter { stationAutoKnownTarget($0, context: context) }.min {
        $0.position.length == $1.position.length
          ? $0.id < $1.id : $0.position.length < $1.position.length
      }
    stationAutoDefence?.combatActor = combat?.physical?.identity
    let dangers = nearby + assessment.incoming + (confirmed.map { [$0] } ?? [])
    guard
      let danger = dangers.first(where: { !$0.position.finite || !$0.position.length.isFinite })
        ?? dangers.min(by: { $0.position.length < $1.position.length })
    else {
      stationAutoDefence?.evasionWorld = nil
      return nil
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
    return .init(aim: aim, lateralVelocity: lateral * (workLimits.speed * 0.35 * pressure))
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
    let target =
      confirmed
      ?? assessment.threats.filter {
        $0.position.z > 0 && stationAutoImmediate($0, context: assessment.context)
          && stationAutoKnownTarget($0, context: assessment.context)
      }.min { $0.position.length < $1.position.length }
    guard let target, target.position.z > 0, let actor = target.physical?.identity,
      max(0, laserHeat - 0.1 * 12) >= 240 || commander.laser(on: .front) == nil
        || commander.laser(on: .front) == .mining || confirmed != nil,
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
