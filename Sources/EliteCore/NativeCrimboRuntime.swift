import Foundation

/// Native world units throughout. No SI conversion or mission route interval is implied.
struct NativeCrimboAttainedMotion: Equatable, Sendable {
  let provider: NativeProviderIdentity
  let member: UUID
  let actor: ActorIdentity
  let runtimeEpoch: UUID
  let frame: UInt64
  let stationImpactRevision: UInt64?
  let visit: UInt64
  let startTime: Double
  let endTime: Double
  let subjectStart: ShipPose
  let subjectEnd: ShipPose
  let playerStart: ShipPose
  let playerEnd: ShipPose
  let subjectStartVelocity: Vector3
  let subjectEndVelocity: Vector3
  let playerStartVelocity: Vector3
  let playerEndVelocity: Vector3
  let tangentialDisplacementWorldUnits: Double
}

struct NativeCrimboMotionSample: Sendable {
  let provider: NativeProviderIdentity
  let member: UUID
  let actor: ActorIdentity
  let runtimeEpoch: UUID
  let frame: UInt64
  let stationImpactRevision: UInt64?
  let startTime: Double
  let endTime: Double
  let subject: ShipPose
  let player: ShipPose
  let subjectVelocity: Vector3
  let playerVelocity: Vector3
  let tangent: Vector3
}

/// Bounded geometry checks use actual native displacement (new velocity * dt), not a goal pose.
enum NativeCrimboMotion {
  static func closestDistance(offset: Vector3, displacement: Vector3) -> Double {
    let square = displacement.dot(displacement)
    let projection = offset.dot(displacement)
    guard offset.finite, displacement.finite, square.isFinite, projection.isFinite else { return 0 }
    let fraction = square > 0 ? max(0, min(1, -projection / square)) : 0
    let result = (offset + displacement * fraction).length
    return result.isFinite ? result : 0
  }

  static func turned(_ basis: Basis3, toward: Vector3, maximum: Double) -> Basis3 {
    let forward = basis.z.unit
    let desired = toward.unit
    let angle = min(acos(max(-1, min(1, forward.dot(desired)))), maximum)
    let cross = forward.cross(desired)
    let axis = cross.length > 1e-9 ? cross.unit : basis.y
    func turn(_ v: Vector3) -> Vector3 {
      v * cos(angle) + axis.cross(v) * sin(angle) + axis * (axis.dot(v) * (1 - cos(angle)))
    }
    var result = Basis3()
    result.x = turn(basis.x)
    result.y = turn(basis.y)
    result.z = turn(basis.z)
    return result
  }
}

extension Game {
  func isNativeCrimboMember(_ actor: ActorIdentity) -> Bool {
    guard let registry = commander.savedCrimboState,
      registry.world == commander.equipmentOwnerID,
      registry.spawnSequence < commander.flightSimulation.nextSpawn,
      (try? registry.validate()) != nil
    else { return false }
    return registry.contains(actor: actor, ledger: commander.npcPersistence)
  }

  /// A rejected candidate leaves all originals, resources and bindings unchanged.
  mutating func advanceNativeCrimbo(delta: Double) {
    nativeCrimboMotionSample = nil
    guard !paused, !docked, delta.isFinite, delta > 0, delta <= 0.1,
      let registry = commander.savedCrimboState,
      registry.world == commander.equipmentOwnerID,
      registry.spawnSequence < commander.flightSimulation.nextSpawn,
      let context = gameplayContext(), context.system == NativeCrimboRegistry.system,
      context.physicalTime >= delta, (try? registry.validate()) != nil,
      context.anchors.planet.position == registry.orbit.anchor.center,
      context.anchors.planet.radius == registry.orbit.anchor.planetRadius
    else { return }
    var candidate = self
    do {
      try candidate.admitNativeCrimbo(context: context)
      try candidate.steerNativeCrimbo(delta: delta)
      self = candidate
    } catch {
      // Native admission or geometry refused the whole staged mutation; existing craft coast.
    }
  }

  private mutating func admitNativeCrimbo(context: EncounterContext) throws {
    guard var registry = commander.savedCrimboState else { throw NativeCrimboError.unavailable }
    let waiting = registry.members.filter {
      switch $0.ownership {
      case .pending, .parked: true
      default: false
      }
    }
    guard !waiting.isEmpty else { return }
    let requests = try waiting.map { member -> SpawnRequest in
      let position: Vector3
      let orientation: Basis3
      let velocity: Vector3
      let energy: Double
      let angularVelocity: Vector3
      let npc: NPCState
      if case .parked(_, let snapshot) = member.ownership {
        position = snapshot.position
        orientation = snapshot.orientation
        velocity = snapshot.velocity
        energy = snapshot.energy
        angularVelocity = snapshot.angularVelocity
        npc = snapshot.npc
      } else {
        guard let performance = ShipCatalogue.ship(member.catalogueShipID)?.game,
          let resources = NPCResources.stock(performance)
        else { throw NativeCrimboError.unavailable }
        let sign = Double(registry.orbit.configuration.direction.rawValue)
        let angle =
          registry.orbit.phase - sign * Double(member.slot)
          * registry.orbit.configuration.slotSpacing
        let anchor = registry.orbit.anchor
        let radial = anchor.basis.x * cos(angle) + anchor.basis.y * sin(angle)
        let tangent = (anchor.basis.x * -sin(angle) + anchor.basis.y * cos(angle)) * sign
        position = anchor.center + radial * anchor.orbitRadius
        var basis = Basis3()
        basis.z = tangent
        basis.y = anchor.basis.z
        basis.x = basis.y.cross(basis.z).unit
        orientation = basis
        velocity = tangent * (registry.orbit.angularSpeed * anchor.orbitRadius)
        energy = resources.energyCapacity
        angularVelocity = .init(0, 0, 0)
        npc = .init(
          role: member.role, origin: context.system, destination: context.system,
          legalProvenance: .generated, cargoProvenance: .generated, routeProvenance: .generated,
          resources: resources)
      }
      return .init(
        identity: .init(
          system: context.system, visit: context.visit, sequence: registry.spawnSequence,
          member: UInt16(member.slot), producer: .provider),
        population: .civilian, hull: member.hull, position: position, orientation: orientation,
        velocity: velocity, npc: npc, rock: nil, payload: nil, priority: .ordinary,
        catalogueShipID: member.catalogueShipID, energy: energy, angularVelocity: angularVelocity)
    }
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: true)], intents: []))
    guard receipts.count == waiting.count,
      receipts.allSatisfy({ $0.refusal == nil && $0.actor != nil })
    else { throw NativeCrimboError.unavailable }
    var parked: [NPCLogicalIdentity: NPCPersistenceSnapshot] = [:]
    var admitted: [NPCLogicalIdentity: NPCPersistenceSnapshot] = [:]
    for (member, receipt) in zip(waiting, receipts) {
      guard let actor = receipt.actor,
        receipt.request.member == UInt16(member.slot),
        let index = bodies.firstIndex(where: { $0.physical?.identity == actor }),
        bodies[index].physical?.spawnIdentity == receipt.request,
        let existingLogical = commander.npcPersistence.logicalIdentity(for: actor),
        existingLogical == actor
      else { throw NativeCrimboError.invalidTransfer }
      let logical: NPCLogicalIdentity
      if case .parked(let original, var snapshot) = member.ownership {
        logical = original
        parked[original] = snapshot
        snapshot.actor = actor
        snapshot.physicalTime = context.physicalTime
        guard
          NPCRebind(logicalIdentity: original.firstActor, actor: actor, snapshot: snapshot)
            .restore(body: &bodies[index], pose: commander.flightSimulation.pose)
        else { throw NativeCrimboError.invalidTransfer }
      } else {
        logical = .init(firstActor: actor)
        let loadout = member.slot == 6 ? registry.santaLoadout : registry.rudolfLoadout
        bodies[index].missiles = loadout.missiles
        bodies[index].ecmEnabled = loadout.ecmEnabled
      }
      guard
        let current = NPCPersistenceSnapshot.capture(
          body: bodies[index], pose: commander.flightSimulation.pose,
          physicalTime: context.physicalTime, protection: context.protection)
      else { throw NativeCrimboError.invalidTransfer }
      if case .refused = commander.npcPersistence.capture(current, protection: context.protection) {
        throw NativeCrimboError.invalidTransfer
      }
      if parked[logical] != nil { admitted[logical] = current }
      registry.members[member.slot].ownership = .live(logical)
    }
    if !parked.isEmpty {
      try commander.npcPersistence.importProviderOriginals(
        parked: parked, admitted: admitted, protection: context.protection)
    }
    try registry.validate()
    commander.savedCrimboState = registry
  }

  private mutating func steerNativeCrimbo(delta: Double) throws {
    guard var registry = commander.savedCrimboState, let context = gameplayContext() else {
      throw NativeCrimboError.unavailable
    }
    // The native law owner must end an actual threat; a missing target never substitutes the player.
    guard registry.threat == nil else { return }
    let members = try registry.members.compactMap { member -> OrbitFormationMember? in
      guard let actorID = registry.binding(of: member, ledger: commander.npcPersistence),
        let actor = context.actors.first(where: { $0.identity == actorID }), actor.energy > 0,
        let body = bodies.first(where: { $0.physical?.identity == actorID }), !isEMPDisabled(body)
      else { return nil }
      guard body.missionActorID == nil, body.missionInstanceID == nil, body.scriptNPC == nil,
        let actual = NPCPersistenceSnapshot.capture(
          body: body, pose: commander.flightSimulation.pose,
          physicalTime: context.physicalTime, protection: context.protection),
        NativeCrimboRegistry.matches(actual, member: member),
        let performance = ShipCatalogue.ship(member.catalogueShipID)?.game
      else { throw NativeCrimboError.unavailable }
      return .init(
        logicalID: member.identity, slot: member.slot, position: actor.position,
        velocity: actor.velocity, forward: actor.orientation.z,
        hullRadius: gameplayMesh(for: body).vertices.map(\.length).max() ?? .infinity,
        limits: .init(
          speed: actor.maximumSpeedUnitsPerSecond, acceleration: performance.acceleration * 18,
          turnRate: min(performance.pitch, performance.yaw)))
    }
    let step = try OrbitFormationController.step(
      state: registry.orbit,
      input: .init(anchor: registry.orbit.anchor, members: members, delta: delta))
    var velocities: [UUID: Vector3] = [:]
    for directive in step.directives {
      guard let member = members.first(where: { $0.logicalID == directive.logicalID }) else {
        throw NativeCrimboError.invalidMotion
      }
      velocities[member.logicalID] =
        directive.steering.map {
          member.velocity + $0.acceleration * delta
        } ?? member.velocity
    }
    guard
      nativeCrimboSweepSafe(
        members: members, velocities: velocities, context: context, delta: delta)
    else { throw NativeCrimboError.invalidMotion }
    registry.orbit = step.state
    for directive in step.directives {
      guard let steering = directive.steering,
        let member = members.first(where: { $0.logicalID == directive.logicalID }),
        let record = registry.members.first(where: { $0.identity == member.logicalID }),
        let actorID = registry.binding(of: record, ledger: commander.npcPersistence),
        let actor = context.actors.first(where: { $0.identity == actorID }),
        let index = bodies.firstIndex(where: { $0.physical?.identity == actorID }),
        let velocity = velocities[member.logicalID]
      else { continue }
      let orientation = NativeCrimboMotion.turned(
        actor.orientation, toward: steering.desiredForward, maximum: member.limits.turnRate * delta)
      bodies[index].orientation = orientation.relative(
        to: commander.flightSimulation.pose.orientation)
      bodies[index].physical?.velocity = velocity
      // Actual translation belongs to moveBodies/FlightWorkScene later in this same frame.
      if record.slot == 6, steering.tracking == .tracking {
        var subject = ShipPose()
        subject.position = actor.position
        subject.orientation = orientation
        let radial = (actor.position - registry.orbit.anchor.center).unit
        let tangent =
          registry.orbit.anchor.basis.z.cross(radial)
          * Double(registry.orbit.configuration.direction.rawValue)
        nativeCrimboMotionSample = .init(
          provider: registry.provider, member: record.identity, actor: actorID,
          runtimeEpoch: nativeStationRuntimeEpoch, frame: context.revision,
          stationImpactRevision: stationImpactRevision,
          startTime: context.physicalTime - delta, endTime: context.physicalTime,
          subject: subject, player: commander.flightSimulation.pose,
          subjectVelocity: velocity, playerVelocity: context.player.velocity, tangent: tangent)
      }
    }
    commander.savedCrimboState = registry
  }

  private func nativeCrimboSweepSafe(
    members: [OrbitFormationMember], velocities: [UUID: Vector3],
    context: EncounterContext, delta: Double
  ) -> Bool {
    let memberActors = Set(
      (commander.savedCrimboState?.members ?? []).compactMap {
        commander.savedCrimboState?.binding(of: $0, ledger: commander.npcPersistence)
      })
    for member in members {
      guard let velocity = velocities[member.logicalID], member.hullRadius.isFinite else {
        return false
      }
      let displacement = velocity * delta
      for sphere in [context.anchors.planet, context.anchors.sun] {
        if NativeCrimboMotion.closestDistance(
          offset: member.position - sphere.position, displacement: displacement)
          <= sphere.radius + member.hullRadius
        {
          return false
        }
      }
      for body in bodies where body.energy > 0 {
        if let identity = body.physical?.identity, memberActors.contains(identity) { continue }
        let radius = gameplayMesh(for: body).vertices.map(\.length).max() ?? .infinity
        let position = commander.flightSimulation.pose.systemPoint(body.position)
        let otherVelocity = body.physical?.velocity ?? .init(0, 0, 0)
        if !radius.isFinite
          || NativeCrimboMotion.closestDistance(
            offset: member.position - position, displacement: (velocity - otherVelocity) * delta)
            <= radius + member.hullRadius
        {
          return false
        }
      }
      let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? .infinity
      if NativeCrimboMotion.closestDistance(
        offset: member.position - context.player.position,
        displacement: (velocity - context.player.velocity) * delta)
        <= playerRadius + member.hullRadius
      {
        return false
      }
      for other in members where other.slot > member.slot {
        guard let otherVelocity = velocities[other.logicalID] else { return false }
        if NativeCrimboMotion.closestDistance(
          offset: member.position - other.position,
          displacement: (velocity - otherVelocity) * delta)
          <= member.hullRadius + other.hullRadius
        {
          return false
        }
      }
    }
    return true
  }

  /// G1 calls only after actual translation and collision resolution, in the same private candidate.
  mutating func finishNativeCrimboMotion(admitted: Bool) throws -> NativeCrimboAttainedMotion? {
    let sample = nativeCrimboMotionSample
    nativeCrimboMotionSample = nil
    guard admitted, !paused, !docked, let sample,
      sample.runtimeEpoch == nativeStationRuntimeEpoch, sample.frame == gameplayRevision,
      sample.stationImpactRevision == stationImpactRevision,
      stationImpactRevision != gameplayRevision,
      sample.endTime == commander.flightSimulation.physicalTime,
      let registry = commander.savedCrimboState, registry.provider == sample.provider,
      registry.world == commander.equipmentOwnerID,
      registry.spawnSequence < commander.flightSimulation.nextSpawn,
      (try? registry.validate()) != nil,
      registry.threat == nil, let context = gameplayContext(), context.visit == sample.actor.visit,
      let member = registry.members.first(where: { $0.identity == sample.member }),
      registry.binding(of: member, ledger: commander.npcPersistence) == sample.actor,
      let actor = context.actors.first(where: { $0.identity == sample.actor }), actor.energy > 0,
      let body = bodies.first(where: { $0.physical?.identity == sample.actor }),
      !isEMPDisabled(body), body.missionActorID == nil, body.missionInstanceID == nil,
      body.scriptNPC == nil,
      let actual = NPCPersistenceSnapshot.capture(
        body: body, pose: commander.flightSimulation.pose,
        physicalTime: context.physicalTime, protection: context.protection),
      NativeCrimboRegistry.matches(actual, member: member)
    else { return nil }
    let displacement = actor.position - sample.subject.position
    let expected = sample.subjectVelocity * (sample.endTime - sample.startTime)
    guard (displacement - expected).length <= max(1, expected.length) * 1e-8 else {
      throw NativeCrimboError.invalidMotion
    }
    var subjectEnd = ShipPose()
    subjectEnd.position = actor.position
    subjectEnd.orientation = actor.orientation
    return .init(
      provider: sample.provider, member: sample.member, actor: sample.actor,
      runtimeEpoch: sample.runtimeEpoch, frame: sample.frame,
      stationImpactRevision: sample.stationImpactRevision, visit: context.visit,
      startTime: sample.startTime, endTime: sample.endTime,
      subjectStart: sample.subject, subjectEnd: subjectEnd,
      playerStart: sample.player, playerEnd: commander.flightSimulation.pose,
      subjectStartVelocity: sample.subjectVelocity, subjectEndVelocity: actor.velocity,
      playerStartVelocity: sample.playerVelocity, playerEndVelocity: context.player.velocity,
      tangentialDisplacementWorldUnits: displacement.dot(sample.tangent))
  }

  /// G1 must clear the departed world in this SAME candidate before publishing the parked ownership.
  mutating func parkNativeCrimboBeforeDeparture() throws {
    guard var registry = commander.savedCrimboState,
      commander.flightSimulation.player?.system == NativeCrimboRegistry.system
    else { return }
    try registry.validate()
    guard registry.world == commander.equipmentOwnerID,
      registry.spawnSequence < commander.flightSimulation.nextSpawn
    else { throw NativeCrimboError.invalidTransfer }
    var candidate = self
    guard candidate.persistNPCStates().isEmpty, let context = candidate.gameplayContext() else {
      throw NativeCrimboError.invalidTransfer
    }
    var originals: [NPCLogicalIdentity: NPCPersistenceSnapshot] = [:]
    for member in registry.members {
      guard case .live(let logical) = member.ownership else { continue }
      guard candidate.commander.npcPersistence.terminalReason(for: logical.firstActor) == nil,
        let snapshot = candidate.commander.npcPersistence.snapshot(for: logical.firstActor),
        NativeCrimboRegistry.matches(snapshot, member: member)
      else { throw NativeCrimboError.invalidTransfer }
      originals[logical] = snapshot
    }
    if !originals.isEmpty {
      let removed = try candidate.commander.npcPersistence.takeProviderOriginals(
        expected: originals, protection: context.protection)
      for member in registry.members {
        guard case .live(let logical) = member.ownership, let snapshot = removed[logical] else {
          continue
        }
        registry.members[member.slot].ownership = .parked(logical, snapshot)
      }
    }
    try registry.validate()
    candidate.commander.savedCrimboState = registry
    candidate.nativeCrimboMotionSample = nil
    self = candidate
  }
}
