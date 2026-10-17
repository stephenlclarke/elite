import Foundation

extension Game {
  mutating func advanceGameplayEncounters(delta: Double) {
    ensurePhysicalActors()
    advanceEMPActors()
    advanceNPCResources(delta: delta)
    _ = persistNPCStates()
    advanceUnboundNPCs()
    admitPersistentNPCs()
    guard let context = gameplayContext() else { return }
    let hasStation = bodies.contains { $0.id == 0 && $0.hull == .station && $0.energy > 0 }
    let security: SecurityPlan
    if hasStation {
      security = commander.stationSecurity.advance(context: context)
    } else {
      security = .init(
        encounters: .init(
          system: context.system, visit: context.visit,
          revision: context.revision, batches: [], intents: []), notices: [])
    }
    let policeReceipts = admitEncounterPlan(security.encounters)
    commander.stationSecurity.acknowledge(receipts: policeReceipts)
    for notice in security.notices where message != notice.text || messageTime <= 0 {
      notify(notice.text)
    }
    guard let current = gameplayContext() else { return }
    var director = commander.encounterDirector ?? EncounterDirector(context: current)
    let plan = director.advance(context: current)
    director.acknowledge(receipts: admitEncounterPlan(plan))
    commander.encounterDirector = director
    activateNearbyMiningFields()
    activateNearbySalvageSites()
    admitPendingOre()
    admitPendingCargo()
    admitPendingSalvage()
    guard let live = gameplayContext() else { return }
    let intents = TrafficIntent.intents(context: live) + security.encounters.intents
    for index in bodies.indices where bodies[index].physical?.spawnIdentity != nil {
      let cooldown = max(0, (bodies[index].physical?.laserCooldown ?? 0) - delta)
      bodies[index].physical?.laserCooldown = cooldown
    }
    advanceClassicMissionActors(context: live, delta: delta)
    for intent in intents { applyGameplayIntent(intent, context: live, delta: delta) }
  }

  /// Retained classic hulls use native steering and weapons, with one later translation owner.
  /// Profiled craft keep their authored driver; unjoined bodies gain no mission AI authority.
  private mutating func advanceClassicMissionActors(context: EncounterContext, delta: Double) {
    let bodyIDs = bodies.filter {
      $0.energy > 0 && $0.scriptNPC == nil && $0.scriptShot == nil
        && $0.missionActorID != nil && $0.physical?.spawnIdentity != nil
    }.map(\.id)
    for bodyID in bodyIDs {
      guard let descriptor = currentMissionActorDescriptor(bodyID: bodyID),
        let body = bodies.first(where: { $0.id == bodyID }),
        let binding = try? MissionNativeBridge.bindActor(
          descriptor: descriptor, body: body, context: context),
        let instance = commander.scriptState.instances[descriptor.instanceID],
        let pack = scriptPack(for: instance),
        let encounter = pack.manifest.encounters?.first(where: { $0.id == descriptor.encounterID }),
        let declared = encounter.actors.first(where: { $0.id == descriptor.alias }),
        let action = body.physical?.npc?.intention
      else { continue }
      switch action {
      case .engage(let target):
        guard declared.hostile, target == context.player.identity else { continue }
      case .navigate, .flee, .dock: break
      case .mine, .scoop: continue
      }
      applyGameplayIntent(
        .init(actor: binding.nativeActor, action: action), context: context, delta: delta)
    }
  }

  mutating func activateNearbyMiningFields() {
    guard let context = gameplayContext() else { return }
    let observers =
      [context.player.position]
      + context.actors.filter { $0.npc?.role == .miner && $0.energy > 0 }.map(\.position)
    for field in miningFields
    where observers.contains(where: {
      ($0 - field.position).length < 2500
    }) {
      let requests = field.rocks.compactMap { rock -> SpawnRequest? in
        guard !commander.miningLedger.isDepleted(rock.identity),
          !bodies.contains(where: { $0.physical?.rock == rock.identity })
        else { return nil }
        return .init(
          identity: .init(
            system: context.system, visit: context.visit,
            sequence: UInt64(rock.identity.field) * 12 + UInt64(rock.identity.rock) + 1,
            member: 0, producer: .asteroids),
          population: .asteroid, hull: .asteroid, position: rock.position,
          orientation: Basis3(), velocity: .init(0, 0, 0), npc: nil, rock: rock.identity,
          payload: nil, priority: .ordinary)
      }
      _ = admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit, revision: context.revision,
          batches: [.init(requests: requests, atomic: false)], intents: []))
    }
  }

  mutating func admitPendingOre() {
    guard let context = gameplayContext() else { return }
    let requests = commander.miningLedger.pendingSpawnRequests(
      context: context, fields: miningFields)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: false)], intents: []))
    commander.miningLedger.acknowledge(receipts: receipts)
  }

  private mutating func applyGameplayIntent(
    _ intent: NPCIntent, context: EncounterContext, delta: Double
  ) {
    guard
      let index = bodies.firstIndex(where: {
        $0.physical?.identity == intent.actor && $0.energy > 0
          && $0.physical?.spawnIdentity != nil
      }), let actor = context.actors.first(where: { $0.identity == intent.actor })
    else { return }
    guard
      bodies[index].physical?.suspendedNPCIntention == nil
        || bodies[index].physical?.npc?.intention != nil
    else { return }
    guard !isEMPDisabled(bodies[index]) else { return }
    bodies[index].hostile = intent.action == .engage(context.player.identity)
    // A fleeing trader keeps its original destination for later recovery.
    if bodies[index].physical?.npc?.role != .trader {
      bodies[index].physical?.npc?.intention = intent.action
    }
    switch intent.action {
    case .navigate(let destination, let speed):
      steerGameplayActor(
        index: index, toward: destination, speed: speed, context: context, delta: delta)
    case .flee(let identity):
      guard let threat = gameplayActor(identity, context: context) else { return }
      let away = (actor.position - threat.position).unit
      steerGameplayActor(
        index: index, toward: actor.position + away * 6000,
        speed: actor.maximumSpeedUnitsPerSecond, context: context, delta: delta)
    case .engage(let identity):
      guard let target = gameplayActor(identity, context: context), target.energy > 0 else {
        return
      }
      steerGameplayActor(
        index: index, toward: target.position, speed: actor.maximumSpeedUnitsPerSecond,
        stopDistance: 500, context: context, delta: delta)
      emitGameplayNPCBeam(bodyID: bodies[index].id, target: identity, context: context)
    case .mine(let identity):
      guard let rock = context.actors.first(where: { $0.rock == identity && $0.energy > 0 }) else {
        return
      }
      steerGameplayActor(
        index: index, toward: rock.position, speed: actor.maximumSpeedUnitsPerSecond,
        stopDistance: 250, context: context, delta: delta)
      emitGameplayNPCBeam(
        bodyID: bodies[index].id, target: rock.identity, context: context, mining: true)
    case .scoop(let payload):
      guard let pod = context.actors.first(where: { $0.payload == payload && $0.energy > 0 }) else {
        return
      }
      steerGameplayActor(
        index: index, toward: pod.position, speed: min(80, actor.maximumSpeedUnitsPerSecond),
        stopDistance: 0, context: context, delta: delta)
      if (pod.position - actor.position).length < 85 {
        collectOreForNPC(actor: intent.actor, payload: payload, context: context)
      }
    case .dock(let station):
      guard station == context.anchors.station.identity else { return }
      let permission = commander.stationSecurity.dockingPermission(
        for: actor.identity, context: context)
      let destination =
        permission.allowed
        ? context.anchors.station.position : context.anchors.station.exitPosition
      steerGameplayActor(
        index: index, toward: destination, speed: min(80, actor.maximumSpeedUnitsPerSecond),
        stopDistance: permission.allowed ? 0 : 400, context: context, delta: delta)
      if permission.allowed && (actor.position - destination).length < 80 {
        // Departure is a traffic transition, never a death or bounty settlement.
        let departing = bodies[index]
        _ = commander.npcPersistence.terminal(actor: actor.identity, reason: .docked)
        clearRemovedTarget(departing)
        bodies.removeAll { $0.id == departing.id }
      }
    }
  }

  private func gameplayActor(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot?
  {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  private mutating func steerGameplayActor(
    index: Int, toward destination: Vector3, speed requestedSpeed: Double,
    stopDistance: Double = 100, context: EncounterContext, delta: Double
  ) {
    guard let physical = bodies[index].physical,
      let actor = context.actors.first(where: { $0.identity == physical.identity })
    else { return }
    let craft = ShipCatalogue.nativeShip(actor.hull)?.game
    let acceleration = max(1, (craft?.acceleration ?? 2) * 18)
    let offset = destination - actor.position
    let desired = offset.unit
    let heading = actor.orientation.z.unit
    let axis = heading.cross(desired)
    let angle = acos(max(-1, min(1, heading.dot(desired))))
    let turn = min(angle, max(craft?.pitch ?? 1, craft?.yaw ?? 1) * delta)
    let tangent = axis.length > 1e-8 ? axis.unit : actor.orientation.y
    let forward = (heading * cos(turn) + tangent.cross(heading) * sin(turn)).unit
    let up = abs(forward.y) > 0.95 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)
    let right = up.cross(forward).unit
    bodies[index].orientation.x = commander.flightSimulation.pose.shipVector(right)
    bodies[index].orientation.y = commander.flightSimulation.pose.shipVector(
      forward.cross(right).unit)
    bodies[index].orientation.z = commander.flightSimulation.pose.shipVector(forward)
    let brakingSpeed = sqrt(2 * acceleration * max(0, offset.length - stopDistance))
    let speed = max(0, min(requestedSpeed, actor.maximumSpeedUnitsPerSecond, brakingSpeed))
    let desiredVelocity = forward * speed
    let change = desiredVelocity - physical.velocity
    let impulse = min(change.length, acceleration * delta)
    bodies[index].physical?.velocity = physical.velocity + change.unit * impulse
  }

  private mutating func emitGameplayNPCBeam(
    bodyID: Int, target identity: ActorIdentity, context: EncounterContext, mining: Bool = false
  ) {
    guard let index = bodies.firstIndex(where: { $0.id == bodyID }),
      !isEMPDisabled(bodies[index]),
      let actor = bodies[index].physical, actor.laserCooldown <= 0, bodies[index].energy > 1,
      actor.npc?.resources?.canFire ?? true,
      let target = gameplayActor(identity, context: context)
    else { return }
    let position = bodies[index].position
    let destination = commander.flightSimulation.pose.shipPoint(target.position)
    let direction = destination - position
    let range = mining ? 500.0 : 1500.0
    guard direction.length <= range,
      bodies[index].orientation.z.dot(direction.unit) > 0.98,
      let contact = try? nearestMissionCollision(
        from: position, direction: direction.unit, range: range, radius: 0,
        excludingBodyIDs: [bodyID], includePlayer: true)
    else { return }
    let hit = contact.hit
    let intended =
      identity == context.player.identity
      ? hit.target == .player
      : bodies.first(where: { $0.physical?.identity == identity }).map {
        hit.target == .body($0.id)
      } == true
    let flightBeforeEmission = commander.flightSimulation
    guard intended else { return }
    let laser: LaserKind = mining ? .mining : .pulse
    if contact.selectedTargetBody?.scriptNPC != nil {
      do {
        _ = try preflightNativeMissionContact(
          contact, owner: actor.identity, damage: laser.damage, laser: laser, mount: .front)
      } catch { return }
    }
    guard let origin = makeAttackOrigin(owner: actor.identity) else { return }
    if contact.selectedTargetBody?.scriptNPC != nil {
      guard
        let receipt = try? applyNativeMissionContact(
          contact, origin: origin, damage: laser.damage, laser: laser, mount: .front,
          emissionPosition: commander.flightSimulation.pose.systemPoint(position))
      else {
        commander.flightSimulation = flightBeforeEmission
        return
      }
      projectScriptMissionImpact(receipt)
    } else {
      applyCombatHit(
        hit, origin: origin, kind: .laser, damage: laser.damage, laser: laser, mount: .front,
        emissionPosition: commander.flightSimulation.pose.systemPoint(position))
    }
    bodies[index].physical?.laserCooldown = laser.firingInterval
    bodies[index].energy -= 1
    bodies[index].physical?.npc?.resources?.recordBeam(heat: 10)
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  private mutating func collectOreForNPC(
    actor: ActorIdentity, payload: PayloadIdentity, context: EncounterContext
  ) {
    guard let index = bodies.firstIndex(where: { $0.physical?.identity == actor }),
      let npc = bodies[index].physical?.npc
    else { return }
    var cargo = Array(repeating: 0, count: CommodityIdentity.allCases.count)
    for amount in npc.ordinaryCargo {
      guard amount.valid, cargo[amount.commodity.rawValue] <= Int.max / 17 - amount.quantity else {
        return
      }
      cargo[amount.commodity.rawValue] += amount.quantity
    }
    let capacity =
      bodies[index].physical?.catalogueShipID.flatMap { ShipCatalogue.ship($0)?.game?.cargo }
      ?? ShipCatalogue.nativeShip(bodies[index].hull)?.game?.cargo ?? 20
    let used = CommodityIdentity.allCases.reduce(0) {
      $0 + ($1.unit == "t" ? cargo[$1.rawValue] : 0)
    }
    let receipt = collectOrdinaryPayload(
      payload: payload, into: &cargo, freeTonnes: max(0, capacity - used),
      hasScoops: npc.hasFuelScoops == true, approachAllowed: true, protection: context.protection)
    if case .collected = receipt {
      bodies[index].physical?.npc?.cargoProvenance = .recorded
      bodies[index].physical?.npc?.ordinaryCargo = CommodityIdentity.allCases.compactMap {
        cargo[$0.rawValue] > 0 ? .init(commodity: $0, quantity: cargo[$0.rawValue]) : nil
      }
      bodies.removeAll { $0.physical?.payload == payload }
    }
  }
}
