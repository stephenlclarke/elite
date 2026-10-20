import Foundation

extension Game {
  /// One runtime allocator admits complete batches against the current scene,
  /// including reserves. Proposals never allocate identities themselves.
  mutating func admitEncounterPlan(_ plan: EncounterPlan) -> [SpawnReceipt] {
    // Empty plans have no admission effects. The frame adopts existing actors
    // once; every real request still performs the complete native preflight.
    guard plan.batches.contains(where: { !$0.requests.isEmpty }) else { return [] }
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
        if request.identity.producer != .persistence && request.identity.producer != .emp,
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
        && $0.identity.producer != .emp
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

  /// Uses sealed measured hull/component geometry and the ordinary native reserve policy.
  /// Requests must correspond in order to the selected sealed cohort; no identities are allocated.
  @inline(never)
  func gameplayMissionActorAdmissionRefusal(
    _ requests: [SpawnRequest], templates: [MissionActorAdmissionTemplate],
    context: EncounterContext
  ) -> AdmissionRefusal? {
    guard requests.count == templates.count,
      Set(requests.map(\.identity)).count == requests.count
    else { return .staleContext }
    let registeredStationBodies = Set(
      commander.nativeStations?.ledger.records.compactMap { record in
        record.identity.system == context.system ? record.binding?.bodyID : nil
      } ?? [])
    let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? 80
    return Self.gameplayMissionActorAdmissionRefusal(
      original: self, requests, templates: templates, context: context,
      registeredStationBodies: registeredStationBodies, playerRadius: playerRadius)
  }

  /// Read actual Commander facts before reserving the per-request geometry-validation frame.
  @inline(never)
  private static func gameplayMissionActorAdmissionRefusal(
    original: borrowing Game, _ requests: [SpawnRequest],
    templates: [MissionActorAdmissionTemplate], context: EncounterContext,
    registeredStationBodies: Set<Int>, playerRadius: Double
  ) -> AdmissionRefusal? {
    var budget = context.budget
    for index in requests.indices {
      if let refusal = Self.gameplayMissionActorRequestRefusal(
        original: original, request: requests[index], template: templates[index],
        context: context, budget: budget, playerRadius: playerRadius)
      {
        return refusal
      }
      if let refusal = Self.gameplayMissionActorSceneClearanceRefusal(
        original: original, center: requests[index].position, radius: templates[index].radius,
        context: context, registeredStationBodies: registeredStationBodies)
      {
        return refusal
      }
      budget.total += 1
      budget.active[requests[index].population, default: 0] += 1
    }
    for index in requests.indices {
      for other in requests.indices where other > index {
        if (requests[index].position - requests[other].position).length
          < templates[index].radius + templates[other].radius + 64
        {
          return .unsafePosition
        }
      }
    }
    return nil
  }

  /// Keep one request's condition and capacity temporaries out of cohort iteration.
  @inline(never)
  private static func gameplayMissionActorRequestRefusal(
    original: borrowing Game, request: SpawnRequest,
    template: borrowing MissionActorAdmissionTemplate, context: EncounterContext,
    budget: AdmissionBudget, playerRadius: Double
  ) -> AdmissionRefusal? {
    let maximumHullEnergy = template.maximumHullEnergy
    let resourceCapacityMatches: Bool
    if let resources = request.npc?.resources {
      resourceCapacityMatches = resources.energyCapacity == maximumHullEnergy
    } else {
      resourceCapacityMatches =
        template.canonicalBody.scriptNPC != nil
        && maximumHullEnergy > 100000
    }
    guard request.priority == .mission, request.identity.producer == .mission,
      request.population == .mission,
      request.hull == template.canonicalBody.hull,
      request.energy == template.canonicalBody.energy,
      resourceCapacityMatches
    else { return .staleContext }
    for index in original.bodies.indices {
      if original.bodies[index].physical?.spawnIdentity == request.identity {
        return .staleContext
      }
    }
    if let refusal = original.admissionCapacityRefusal(request, context: context, budget: budget) {
      return refusal
    }
    let radius = template.radius
    guard
      original.spawnParametersSafe(
        request, context: context, measuredRadius: radius,
        measuredMaximumEnergy: maximumHullEnergy),
      (request.position - context.player.position).length > radius + playerRadius + 64
    else { return .unsafePosition }
    return nil
  }

  /// Scene-body and measured-radius storage is needed only after request preflight returns.
  @inline(never)
  private static func gameplayMissionActorSceneClearanceRefusal(
    original: borrowing Game, center: Vector3, radius: Double, context: EncounterContext,
    registeredStationBodies: Set<Int>
  ) -> AdmissionRefusal? {
    for actorIndex in context.actors.indices where context.actors[actorIndex].energy > 0 {
      var matchingBodyIndex: Int?
      for bodyIndex in original.bodies.indices {
        if original.bodies[bodyIndex].physical?.identity == context.actors[actorIndex].identity {
          matchingBodyIndex = bodyIndex
          break
        }
      }
      guard let bodyIndex = matchingBodyIndex else { return .staleContext }
      if let refusal = Self.gameplayMissionActorSceneBodyRefusal(
        original: original, center: center, radius: radius,
        actor: context.actors[actorIndex], body: original.bodies[bodyIndex],
        registeredStationBodies: registeredStationBodies)
      {
        return refusal
      }
    }
    return nil
  }

  /// Borrow the selected scene records; only a downstream body API receives an owned copy.
  @inline(never)
  private static func gameplayMissionActorSceneBodyRefusal(
    original: borrowing Game, center: Vector3, radius: Double,
    actor: borrowing ActorSnapshot, body: borrowing SpaceBody,
    registeredStationBodies: Set<Int>
  ) -> AdmissionRefusal? {
    let bodyID = body.id
    if body.nativeStationIdentity != nil || registeredStationBodies.contains(bodyID) {
      return original.missionActorClearsNativeStation(
        center: center, radius: radius, body: body) ? nil : .unsafePosition
    }
    let rockIdentity = actor.rock
    let otherRadius: Double
    if let bounds = actor.salvage?.bounds {
      otherRadius = bounds.radius + bounds.center.length
    } else if body.scriptNPC != nil {
      otherRadius = original.scriptNPCRadius(copy body)
    } else if let rock = original.miningFields.flatMap(\.rocks).first(where: {
      $0.identity == rockIdentity
    }) {
      otherRadius = rock.radius
    } else {
      otherRadius = original.gameplayMesh(for: copy body).vertices.map(\.length).max() ?? 80
    }
    guard otherRadius.isFinite, otherRadius > 0,
      (center - actor.position).length >= radius + otherRadius + 64
    else { return .unsafePosition }
    return nil
  }

  /// Static admission only: transform every source-box corner with the actual accepted
  /// model basis. The resulting world box encloses the full station even for tolerated scale.
  @inline(never)
  func missionActorClearsNativeStation(
    center: Vector3, radius: Double, body: borrowing SpaceBody
  ) -> Bool {
    guard center.finite, center.length.isFinite, radius.isFinite, radius > 0,
      let identity = body.nativeStationIdentity, nativeStationBodyIsCurrent(copy body)
    else { return false }
    guard
      let bounds = Self.validatedMissionActorStationBounds(
        original: self, identity: identity, body: body)
    else { return false }
    let pose = modelPose(of: copy body)
    return Self.missionActorClearsStationBounds(
      center: center, radius: radius, minimum: bounds.minimum, maximum: bounds.maximum, pose: pose)
  }

  /// Current station authority finishes before model-pose and bounds construction starts.
  @inline(never)
  private static func validatedMissionActorStationBounds(
    original: borrowing Game, identity: NativeStationIdentity, body: borrowing SpaceBody
  ) -> (minimum: Vector3, maximum: Vector3)? {
    guard let world = original.commander.nativeStations, let saved = world.pose(for: identity),
      let source = NativeStationSource.binding(for: identity), body.energy == saved.energy,
      world.bodyRigidPoseIsConsistent(copy body, flight: original.commander.flightSimulation)
    else { return nil }
    let bounds = source.geometry.bounds
    return (bounds.minimum, bounds.maximum)
  }

  /// Pure geometry receives only the measured bounds and the actual model pose.
  @inline(never)
  private static func missionActorClearsStationBounds(
    center: Vector3, radius: Double, minimum: Vector3, maximum: Vector3, pose: ShipPose
  ) -> Bool {
    guard minimum.finite, maximum.finite,
      minimum.x < maximum.x, minimum.y < maximum.y, minimum.z < maximum.z,
      pose.position.finite, pose.orientation.validRotation
    else { return false }
    var worldMinimum = pose.systemPoint(minimum)
    var worldMaximum = worldMinimum
    for x in [minimum.x, maximum.x] {
      for y in [minimum.y, maximum.y] {
        for z in [minimum.z, maximum.z] {
          let point = pose.systemPoint(.init(x, y, z))
          guard point.finite, point.length.isFinite else { return false }
          worldMinimum = .init(
            min(worldMinimum.x, point.x), min(worldMinimum.y, point.y), min(worldMinimum.z, point.z)
          )
          worldMaximum = .init(
            max(worldMaximum.x, point.x), max(worldMaximum.y, point.y), max(worldMaximum.z, point.z)
          )
        }
      }
    }
    let closest = Vector3(
      max(worldMinimum.x, min(worldMaximum.x, center.x)),
      max(worldMinimum.y, min(worldMaximum.y, center.y)),
      max(worldMinimum.z, min(worldMaximum.z, center.z)))
    let clearance = (center - closest).length - radius
    let numerical =
      1e-8 * max(1, radius + center.length + worldMinimum.length + worldMaximum.length)
    return clearance.isFinite && numerical.isFinite && clearance - 64 > numerical
  }

  private func admissionCapacityRefusal(
    _ request: SpawnRequest, context: EncounterContext, budget: AdmissionBudget
  ) -> AdmissionRefusal? {
    guard request.identity.system == context.system, request.identity.visit == context.visit
    else {
      return .staleContext
    }
    if let emp = commander.savedEMPState, request.identity.producer != .emp,
      emp.records.values.contains(where: { record in
        guard let original = record.originalSpawn else { return false }
        return original.system == request.identity.system
          && original.visit == request.identity.visit
          && original.producer == request.identity.producer
          && original.sequence == request.identity.sequence
          && original.member == request.identity.member
      })
    {
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

  private func spawnParametersSafe(
    _ request: SpawnRequest, context: EncounterContext, measuredRadius: Double? = nil,
    measuredMaximumEnergy: Double? = nil
  ) -> Bool {
    guard request.position.finite, request.velocity.finite,
      request.orientation.x.finite, request.orientation.y.finite, request.orientation.z.finite,
      request.angularVelocity.finite
    else { return false }
    let radius = measuredRadius ?? spawnRadius(request)
    let maximumEnergy = measuredMaximumEnergy ?? request.npc?.resources?.energyCapacity ?? 100000
    guard request.npc?.resources?.valid ?? true,
      maximumEnergy.isFinite, maximumEnergy > 0,
      request.energy.map({ $0.isFinite && $0 >= 0 && $0 <= maximumEnergy }) ?? true,
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
