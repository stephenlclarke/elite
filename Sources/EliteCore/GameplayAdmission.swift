import Foundation

extension Game {
  /// One runtime allocator admits complete batches against the current scene,
  /// including reserves. Proposals never allocate identities themselves.
  mutating func admitEncounterPlan(_ plan: EncounterPlan) -> [SpawnReceipt] {
    ensurePhysicalActors()
    guard let context = gameplayContext(), plan.system == context.system,
      plan.visit == context.visit, plan.revision == context.revision
    else {
      return plan.batches.flatMap(\.requests).map {
        .init(request: $0.identity, actor: nil, refusal: .staleContext)
      }
    }
    var receipts: [SpawnReceipt] = []
    for batch in plan.batches {
      if batch.atomic, let refusal = batchRefusal(batch.requests) {
        receipts += batch.requests.map { .init(request: $0.identity, actor: nil, refusal: refusal) }
        continue
      }
      for request in batch.requests {
        if let existing = bodies.first(where: { $0.physical?.spawnIdentity == request.identity }) {
          receipts.append(
            .init(request: request.identity, actor: existing.physical?.identity, refusal: nil))
          continue
        }
        if let refusal = batchRefusal([request]) {
          receipts.append(.init(request: request.identity, actor: nil, refusal: refusal))
          continue
        }
        guard let actor = commander.flightSimulation.allocateActor() else {
          receipts.append(.init(request: request.identity, actor: nil, refusal: .reservedCapacity))
          continue
        }
        let pose = commander.flightSimulation.pose
        var body = SpaceBody(
          id: nextBodyID, hull: request.hull, position: pose.shipPoint(request.position))
        nextBodyID += 1
        body.orientation.x = pose.shipVector(request.orientation.x)
        body.orientation.y = pose.shipVector(request.orientation.y)
        body.orientation.z = pose.shipVector(request.orientation.z)
        body.rotationRate = request.npc == nil ? 0.5 : 0
        if request.identity.producer == .derelicts {
          body.rotationRate = 0
          body.missiles = 0
          body.ecmEnabled = false
        }
        body.hostile = request.npc?.intention == .engage(context.player.identity)
        if let rock = miningFields.flatMap(\.rocks).first(where: { $0.identity == request.rock }) {
          body.energy = commander.miningLedger.remainingEnergy(for: rock)
        }
        var npc = request.npc
        if npc != nil, npc?.resources == nil, request.priority != .mission,
          let performance = request.catalogueShipID.flatMap({ ShipCatalogue.ship($0)?.game })
            ?? ShipCatalogue.nativeShip(request.hull)?.game
        {
          npc?.resources = NPCResources.stock(performance)
        }
        if let resources = npc?.resources {
          body.energy = request.energy ?? resources.energyCapacity
        } else if let energy = request.energy {
          body.energy = energy
        }
        body.physical = .init(
          identity: actor, population: request.population, npc: npc,
          velocity: request.velocity, rock: request.rock, payload: request.payload,
          spawnIdentity: request.identity, catalogueShipID: request.catalogueShipID,
          angularVelocity: request.angularVelocity, salvage: request.salvage)
        if request.identity.producer == .derelicts { body.physical?.canonicalSpin = true }
        if request.identity.producer != .persistence,
          let snapshot = NPCPersistenceSnapshot.capture(
            body: body, pose: pose, physicalTime: context.physicalTime,
            protection: context.protection),
          case .refused = commander.npcPersistence.capture(snapshot, protection: context.protection)
        {
          receipts.append(.init(request: request.identity, actor: nil, refusal: .reservedCapacity))
          continue
        }
        bodies.append(body)
        receipts.append(.init(request: request.identity, actor: actor, refusal: nil))
      }
    }
    return receipts
  }

  private mutating func batchRefusal(_ requests: [SpawnRequest]) -> AdmissionRefusal? {
    guard let context = gameplayContext() else { return .staleContext }
    let fresh = requests.filter { request in
      !bodies.contains { $0.physical?.spawnIdentity == request.identity }
    }
    guard Set(fresh.map(\.identity)).count == fresh.count else { return .staleContext }
    guard UInt64(fresh.count) <= UInt64.max - commander.flightSimulation.nextActor,
      fresh.count <= Int.max - nextBodyID
    else { return .reservedCapacity }
    let newNPCs = fresh.filter {
      $0.npc != nil && $0.npc?.role != .mission && $0.identity.producer != .persistence
    }.count
    guard newNPCs <= NPCPersistenceLedger.maximumEntries - commander.npcPersistence.count else {
      return .reservedCapacity
    }
    var budget = context.budget
    for request in fresh {
      if let refusal = admissionCapacityRefusal(request, context: context, budget: budget) {
        return refusal
      }
      guard safeSpawn(request, context: context) else { return .unsafePosition }
      budget.total += 1
      budget.active[request.population, default: 0] += 1
    }
    for (index, request) in fresh.enumerated() {
      for other in fresh.dropFirst(index + 1) {
        if (request.position - other.position).length < spawnRadius(request) + spawnRadius(other)
          + 8
        {
          return .unsafePosition
        }
      }
    }
    return nil
  }

  /// A pure emission path shares the native population/reserve and celestial policy without
  /// entering unrelated salvage geometry caches or adopting actors.
  func gameplayProjectileAdmissionRefusal(_ request: SpawnRequest, context: EncounterContext)
    -> AdmissionRefusal?
  {
    guard request.population == .projectile, request.hull == .missile, request.npc == nil,
      request.rock == nil, request.payload == nil, request.salvage == nil,
      !bodies.contains(where: { $0.physical?.spawnIdentity == request.identity })
    else { return .staleContext }
    if let refusal = admissionCapacityRefusal(request, context: context, budget: context.budget) {
      return refusal
    }
    return spawnParametersSafe(request, context: context) ? nil : .unsafePosition
  }

  private func admissionCapacityRefusal(
    _ request: SpawnRequest, context: EncounterContext, budget: AdmissionBudget
  ) -> AdmissionRefusal? {
    guard request.identity.system == context.system, request.identity.visit == context.visit
    else {
      return .staleContext
    }
    if context.protection.suppressAmbientShips,
      [.civilian, .pirate].contains(request.population), request.priority == .ordinary
    {
      return .missionSuppression
    }
    guard budget.active[request.population, default: 0] < request.population.maximum else {
      return .populationLimit
    }
    let reserve: Int
    switch request.priority {
    case .mission: reserve = 0
    case .police: reserve = max(0, budget.missionReserve - budget.active[.mission, default: 0])
    case .ordinary:
      reserve =
        max(0, budget.policeReserve - budget.active[.police, default: 0])
        + max(0, budget.missionReserve - budget.active[.mission, default: 0])
    }
    guard budget.total < budget.maximum - reserve else { return .reservedCapacity }
    return nil
  }

  private func spawnParametersSafe(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard request.position.finite, request.velocity.finite,
      request.orientation.x.finite, request.orientation.y.finite, request.orientation.z.finite,
      request.angularVelocity.finite
    else { return false }
    let radius = spawnRadius(request)
    guard request.npc?.resources?.valid ?? true,
      request.energy.map({
        $0.isFinite && $0 >= 0 && $0 <= (request.npc?.resources?.energyCapacity ?? 100000)
      }) ?? true,
      radius.isFinite, radius > 0,
      (request.position - context.anchors.planet.position).length > context.anchors.planet.radius
        + radius,
      (request.position - context.anchors.sun.position).length > context.anchors.sun.radius
        * (request.population == .projectile ? 1 : 4)
        + radius
    else { return false }
    return true
  }

  private mutating func safeSpawn(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard spawnParametersSafe(request, context: context) else { return false }
    let radius = spawnRadius(request)
    // An emitted projectile starts at its owner's muzzle; its collision resolver
    // excludes that owner. Other admissions must be separated from live hulls.
    if request.population == .projectile { return true }
    let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? 80
    guard (request.position - context.player.position).length > radius + playerRadius + 8 else {
      return false
    }
    for actor in context.actors {
      let otherRadius =
        actor.salvage.map { $0.bounds.radius + $0.bounds.center.length }
        ?? (Mesh.hull(actor.hull).vertices.map(\.length).max() ?? 80)
      if actor.energy > 0,
        (request.position - actor.position).length < radius + otherRadius + 8,
        !releasedFragmentClearsParent(request, parent: actor, context: context)
      {
        return false
      }
    }
    return true
  }

  private func spawnRadius(_ request: SpawnRequest) -> Double {
    if let bounds = request.salvage?.bounds { return bounds.radius + bounds.center.length }
    if let rock = miningFields.flatMap(\.rocks).first(where: { $0.identity == request.rock }) {
      return rock.radius
    }
    return Mesh.hull(request.hull).vertices.map(\.length).max() ?? 80
  }
}
