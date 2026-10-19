import Foundation

extension Game {
  /// Called on the private validated load candidate, before any ordinary admission.
  mutating func restoreSavedNPCSceneBindings() throws {
    guard commander.npcPersistence.count > 0 else { return }
    let flight = commander.flightSimulation
    guard commander.valid, commander.equipmentOwnerID != nil, flight.valid,
      flight.system == systemIdentity, flight.pose.position.finite,
      flight.pose.orientation.validRotation, let context = gameplayContext(),
      Set(bodies.map(\.id)).count == bodies.count
    else { throw NPCSceneRestorationError.invalidScene }
    let actors = bodies.compactMap { $0.physical?.identity }
    let spawns = bodies.compactMap { $0.physical?.spawnIdentity }
    guard Set(actors).count == actors.count,
      Set(spawns).count == spawns.count,
      actors.allSatisfy({
        $0.system == systemIdentity && $0.visit == flight.visit && $0.entity < flight.nextActor
      })
    else { throw NPCSceneRestorationError.invalidScene }
    var observed: [NPCPersistenceSnapshot] = []
    var spawnIdentities: [ActorIdentity: SpawnIdentity] = [:]
    for body in bodies where body.hull.isTargetShip {
      if body.missionInstanceID != nil || body.missionActorID != nil || body.navalTarget
        || body.blackjackRole != nil || body.blackjackIdentity != nil
        || body.physical?.empSource != nil || body.physical?.empCrewPod != nil
        || body.physical?.npc?.role == .mission || body.physical?.population == .wreck
        || body.physical?.blocksNavalEncounter == true
      {
        continue
      }
      guard body.energy > 0, body.scriptNPC == nil, body.scriptShot == nil,
        let physical = body.physical, let npc = physical.npc, npc.role != .mission,
        [.civilian, .pirate, .police].contains(physical.population),
        physical.spawnIdentity.map({ $0.system == systemIdentity && $0.visit == flight.visit })
          ?? true,
        let snapshot = NPCPersistenceSnapshot.capture(
          body: body, pose: flight.pose, physicalTime: flight.physicalTime,
          protection: context.protection)
      else { throw NPCSceneRestorationError.invalidScene }
      observed.append(snapshot)
      if let spawn = physical.spawnIdentity { spawnIdentities[snapshot.actor] = spawn }
    }
    var ledger = commander.npcPersistence
    try ledger.restoreSceneBindings(
      observed, sceneActors: Set(actors), spawnIdentities: spawnIdentities,
      system: systemIdentity, visit: flight.visit,
      physicalTime: flight.physicalTime,
      nextActor: flight.nextActor, protection: context.protection)
    commander.npcPersistence = ledger
    // Only the authenticated native scene can re-establish current craft bindings.
    var careers = commander.wantedCareers
    careers.reconcile(ledger, system: systemIdentity)
    if careers != commander.wantedCareers { commander.wantedCareers = careers }
  }

  /// Capture in allocation order so retired physical identities cannot be registered anew.
  @discardableResult
  mutating func persistNPCStates() -> Set<Int> {
    guard let context = gameplayContext() else { return [] }
    let pose = commander.flightSimulation.pose
    return persistNPCStates(context: context, pose: pose)
  }

  /// Synchronous callers may reuse their current validated physical context and pose.
  /// Capture order and every admission guard are identical to the ordinary boundary.
  @discardableResult
  mutating func persistNPCStates(context: EncounterContext, pose: ShipPose) -> Set<Int> {
    var refused = Set<Int>()
    var careers = commander.wantedCareers
    for body in bodies.sorted(by: {
      ($0.physical?.identity.entity ?? 0) < ($1.physical?.identity.entity ?? 0)
    }) where body.energy > 0 && body.physical?.npc != nil {
      if body.physical?.empSource != nil { continue }
      guard body.physical?.npc?.role != .mission, !body.navalTarget,
        body.blackjackRole == nil, body.physical?.blocksNavalEncounter != true,
        (body.physical?.identity).map({ !context.protection.protectedActors.contains($0) }) == true
      else { continue }
      guard
        let snapshot = NPCPersistenceSnapshot.capture(
          body: body, pose: pose, physicalTime: context.physicalTime,
          protection: context.protection)
      else {
        refused.insert(body.id)
        continue
      }
      if case .refused = commander.npcPersistence.capture(snapshot, protection: context.protection)
      {
        refused.insert(body.id)
      } else if wantedCareerIsOrdinary(body),
        let logical = commander.npcPersistence.logicalIdentity(for: snapshot.actor)
      {
        careers.observe(
          snapshot, logical: logical,
          visible: body.position.length <= context.perceptionRadius)
      }
    }
    careers.reconcile(commander.npcPersistence, system: context.system)
    if careers != commander.wantedCareers { commander.wantedCareers = careers }
    return refused
  }

  /// Off-scene ordinary craft coast in system coordinates for actual simulation time.
  /// This does not invent AI actions, jump fuel consumption or solar collection.
  mutating func advanceUnboundNPCs() {
    let now = commander.flightSimulation.physicalTime
    for (logical, var snapshot) in commander.npcPersistence.unboundSnapshots {
      if freezesNativeCrimboOriginal(logical: logical, snapshot: snapshot) {
        if let frozen = try? Self.freezeNativeCrimboSnapshot(snapshot, at: now) {
          _ = commander.npcPersistence.updateUnbound(logicalIdentity: logical, snapshot: frozen)
        }
        continue
      }
      let elapsed = now - snapshot.physicalTime
      guard elapsed.isFinite, elapsed > 0 else { continue }
      snapshot.position = snapshot.position + snapshot.velocity * elapsed
      snapshot.rotation += snapshot.rotationRate * elapsed
      snapshot.laserCooldown = max(0, snapshot.laserCooldown - elapsed)
      let spin = snapshot.angularVelocity * elapsed
      snapshot.orientation.rotate(pitch: spin.x, roll: spin.z, yaw: spin.y)
      if var resources = snapshot.npc.resources {
        if var reserve = resources.electrical {
          guard
            reserve.advance(
              to: now, capacity: resources.energyCapacity,
              recharge: resources.electricalRecharge)
          else { continue }
          resources.electrical = reserve
        }
        resources.advance(delta: elapsed)
        if resources.profile == .nativeHull {
          snapshot.energy = min(
            resources.energyCapacity, snapshot.energy + elapsed * resources.energyRecharge)
        }
        snapshot.npc.resources = resources
      }
      snapshot.physicalTime = now
      _ = commander.npcPersistence.updateUnbound(logicalIdentity: logical, snapshot: snapshot)
    }
  }

  mutating func admitPersistentNPCs() {
    guard let context = gameplayContext() else { return }
    let prior = commander.npcPersistence.unboundSnapshots
    let provider = nativeCrimboPersistenceSelection(context: context)
    let providerRequests = commander.npcPersistence.pendingProviderSpawnRequests(
      context: context, originals: provider.originals)
    let requests = commander.npcPersistence.pendingSpawnRequests(
      context: context, excludedLogicalKeys: provider.logicalKeys)
    var batches = [SpawnBatch(requests: requests, atomic: false)]
    if !providerRequests.isEmpty {
      batches.insert(.init(requests: providerRequests, atomic: true), at: 0)
    }
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: batches, intents: []))
    let rebindings = commander.npcPersistence.acknowledge(receipts: receipts)
    var identities: [ActorIdentity: ActorIdentity] = [:]
    for rebind in rebindings {
      guard let index = bodies.firstIndex(where: { $0.physical?.identity == rebind.actor }) else {
        continue
      }
      var body = bodies[index]
      if rebind.restore(body: &body, pose: commander.flightSimulation.pose) {
        bodies[index] = body
        if let old = prior[rebind.logicalIdentity]?.actor { identities[old] = rebind.actor }
      }
    }
    guard !rebindings.isEmpty else { return }
    commander.crimeLedger.rebindActors(identities)
    for index in bodies.indices where bodies[index].physical?.npc != nil {
      let saved = bodies[index].physical.flatMap { physical in
        commander.npcPersistence.logicalIdentity(for: physical.identity).flatMap {
          commander.npcPersistence.snapshot(for: $0)
        }
      }
      var body = bodies[index]
      rebindFirstAggressor(in: &body, saved: saved, identities: identities)
      rebindIntention(in: &body, saved: saved, identities: identities)
      bodies[index] = body
    }
  }

  private func rebindFirstAggressor(
    in body: inout SpaceBody, saved: NPCPersistenceSnapshot?,
    identities: [ActorIdentity: ActorIdentity]
  ) {
    guard let original = body.physical?.npc?.firstAggressor else { return }
    if let binding = saved?.firstAggressorBinding, binding.sceneActor == original {
      if let current = currentNPCReference(binding) { body.physical?.npc?.firstAggressor = current }
    } else {
      body.physical?.npc?.firstAggressor = reboundNPCReference(original, identities: identities)
    }
  }

  private func rebindIntention(
    in body: inout SpaceBody, saved: NPCPersistenceSnapshot?,
    identities: [ActorIdentity: ActorIdentity]
  ) {
    guard let intention = body.physical?.npc?.intention ?? body.physical?.suspendedNPCIntention
    else {
      return
    }
    if let binding = saved?.intentionTargetBinding, binding.sceneActor == intention.referencedActor
    {
      if let current = currentNPCReference(binding) {
        body.physical?.npc?.intention = intention.replacingReferencedActor(with: current)
        body.physical?.suspendedNPCIntention = nil
      } else {
        // Missing, dead, refused or terminal targets cannot become a different active target.
        body.physical?.npc?.intention = nil
        body.physical?.suspendedNPCIntention = intention
        body.hostile = false
      }
    } else {
      body.physical?.suspendedNPCIntention = nil
      if let actor = intention.referencedActor {
        body.physical?.npc?.intention = intention.replacingReferencedActor(
          with: reboundNPCReference(actor, identities: identities))
      }
    }
  }

  private func currentNPCReference(_ reference: NPCReferenceBinding) -> ActorIdentity? {
    guard let current = commander.npcPersistence.binding(for: reference.logicalNPC),
      bodies.contains(where: { body in
        guard let physical = body.physical, let npc = physical.npc,
          physical.identity == current
        else { return false }
        return body.energy > 0 && body.hull.isTargetShip && !body.navalTarget
          && body.blackjackRole == nil && body.blackjackIdentity == nil && npc.role != .mission
          && [.civilian, .pirate, .police].contains(physical.population)
          && !physical.blocksNavalEncounter && physical.rock == nil && physical.payload == nil
          && physical.ordnance == nil && physical.salvage == nil
      })
    else { return nil }
    return current
  }

  private func reboundNPCReference(
    _ actor: ActorIdentity, identities: [ActorIdentity: ActorIdentity]
  ) -> ActorIdentity {
    guard actor.system == systemIdentity else { return actor }
    if actor.entity == 0 { return commander.flightSimulation.player ?? actor }
    if actor.entity == 1 { return commander.flightSimulation.anchors?.station.identity ?? actor }
    return identities[actor] ?? actor
  }
}

extension Game {
  /// The existing visit projection uses these exact canonical anchors, never a camera-local centre.
  mutating func projectNativeCrimboCanonicalAnchors() throws {
    guard nativeCrimboLifecycleAvailable, let registry = commander.savedCrimboState,
      let anchors = commander.flightSimulation.anchors,
      anchors.system == NativeCrimboRegistry.system,
      anchors.planet.position == registry.orbit.anchor.center,
      anchors.planet.radius == registry.orbit.anchor.planetRadius
    else { throw NativeCrimboError.invalidMotion }
    let pose = commander.flightSimulation.pose
    celestials = [
      .init(
        kind: .planet, position: pose.shipPoint(anchors.planet.position),
        radius: anchors.planet.radius),
      .init(kind: .sun, position: pose.shipPoint(anchors.sun.position), radius: anchors.sun.radius),
    ]
  }

  mutating func rebaseUnboundNativeCrimboOriginals() throws {
    guard nativeCrimboLifecycleAvailable else { return }
    let time = commander.flightSimulation.physicalTime
    for (logical, snapshot) in commander.npcPersistence.unboundSnapshots {
      guard freezesNativeCrimboOriginal(logical: logical, snapshot: snapshot) else { continue }
      let frozen = try Self.freezeNativeCrimboSnapshot(snapshot, at: time)
      guard commander.npcPersistence.updateUnbound(logicalIdentity: logical, snapshot: frozen)
      else {
        throw NativeCrimboError.invalidTransfer
      }
    }
  }
}
