import Foundation

struct NativeMissionProjectileReceipt: Sendable, Equatable {
  let bodyID: Int
  let actor: ActorIdentity
  fileprivate init(bodyID: Int, actor: ActorIdentity) {
    self.bodyID = bodyID
    self.actor = actor
  }
}

enum NativeMissionProjectileAdmissionError: Error, Sendable, Equatable {
  case missingRecord, invalidRecord, unavailablePack, outsideBubble, allocatorExhausted
  case refused(AdmissionRefusal)
}

private enum RetainedMissionProjectilePlan {
  case present(NativeMissionProjectileReceipt)
  case restore(SpaceBody, retiringBodyID: Int?)
}

extension Game {
  /// The same pure hard checks run before restoration batches or frame clocks mutate.
  func validateRetainedMissionProjectileAdmission(_ shotID: UUID) throws {
    _ = try retainedMissionProjectilePlan(shotID, context: gameplayContext())
  }

  /// One actual context for the whole preflight; temporary refusal never hides a later hard error.
  func validateRetainedMissionProjectileAdmissions(_ shotIDs: [UUID]) throws {
    let context = gameplayContext()
    for identity in shotIDs {
      do { _ = try retainedMissionProjectilePlan(identity, context: context) } catch let error
        as NativeMissionProjectileAdmissionError
      {
        switch error {
        case .unavailablePack, .outsideBubble, .allocatorExhausted, .refused: continue
        case .missingRecord, .invalidRecord: throw error
        }
      }
    }
  }

  /// Only an actual restoration needs a staged candidate; no frame/no-op copy is required.
  mutating func admitRetainedMissionProjectile(_ shotID: UUID) throws
    -> NativeMissionProjectileReceipt
  {
    let plan = try retainedMissionProjectilePlan(shotID, context: gameplayContext())
    if case .present(let receipt) = plan { return receipt }
    guard case .restore(let restored, let retiringBodyID) = plan else {
      throw NativeMissionProjectileAdmissionError.invalidRecord
    }
    var candidate = self
    if let retiringBodyID { candidate.bodies.removeAll { $0.id == retiringBodyID } }
    let receipt = try candidate.stageRetainedMissionProjectile(restored)
    self = candidate
    return receipt
  }

  private func retainedMissionProjectilePlan(_ shotID: UUID, context: EncounterContext?) throws
    -> RetainedMissionProjectilePlan
  {
    guard let record = commander.scriptState.projectiles[shotID] else {
      throw NativeMissionProjectileAdmissionError.missingRecord
    }
    guard record.valid, record.galaxy == commander.galaxy, record.system == commander.system,
      let savedShot = record.body.scriptShot, savedShot.identity == shotID,
      let descriptor = savedShot.missionDescriptor,
      commander.scriptState.projectileArchiveValid(record),
      let instance = commander.scriptState.instances[savedShot.instance],
      instance.id == savedShot.instance
    else { throw NativeMissionProjectileAdmissionError.invalidRecord }
    try MissionNativeBridge.validateArchive(
      savedShot.nativeAttribution, shot: descriptor, packDigest: instance.digest)
    let matching = bodies.filter { $0.scriptShot?.identity == shotID }
    guard matching.count <= 1 else { throw NativeMissionProjectileAdmissionError.invalidRecord }
    var legacy: SpaceBody?
    if let body = matching.first {
      guard body.id == record.body.id, bodies.filter({ $0.id == body.id }).count == 1,
        body.hull == .missile, body.scriptNPC == nil,
        body.missionActorID == nil, body.missionInstanceID == nil,
        body.energy.isFinite, body.energy > 0, body.position.finite, body.orientation.validRotation,
        let shot = body.scriptShot, shot.valid,
        shot.owner == savedShot.owner, shot.instance == savedShot.instance,
        shot.weapon == savedShot.weapon, shot.component == savedShot.component,
        shot.lifetime == savedShot.lifetime, shot.damage == savedShot.damage,
        shot.radius == savedShot.radius, shot.collisionDelay == savedShot.collisionDelay,
        abs(shot.velocity.length - savedShot.velocity.length)
          <= max(1, max(shot.velocity.length, savedShot.velocity.length)) * 1e-6,
        shot.nativeAttribution == savedShot.nativeAttribution
      else { throw NativeMissionProjectileAdmissionError.invalidRecord }
      if let physical = body.physical, physical.spawnIdentity != nil {
        guard let context, physical.population == .projectile, physical.npc == nil,
          physical.ordnance == nil, physical.rock == nil, physical.payload == nil,
          physical.salvage == nil, physical.deathOrigin == nil, physical.deathIncidentID == nil,
          physical.identity.system == context.system, physical.identity.visit == context.visit,
          physical.spawnIdentity?.system == context.system,
          physical.spawnIdentity?.visit == context.visit,
          physical.spawnIdentity?.producer == .ordnance,
          physical.attackOrigin == savedShot.nativeAttribution?.origin,
          bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
          context.actors.contains(where: { $0.identity == physical.identity && $0.energy > 0 })
        else { throw NativeMissionProjectileAdmissionError.invalidRecord }
        return .present(.init(bodyID: body.id, actor: physical.identity))
      }
      guard savedShot.nativeAttribution == nil else {
        throw NativeMissionProjectileAdmissionError.invalidRecord
      }
      if let physical = body.physical {
        guard let context, physical.population == .projectile, physical.npc == nil,
          physical.ordnance == nil, physical.spawnIdentity == nil, physical.attackOrigin == nil,
          physical.emissionPosition == nil, physical.rock == nil, physical.payload == nil,
          physical.salvage == nil, physical.deathOrigin == nil, physical.deathIncidentID == nil,
          !physical.blocksNavalEncounter, physical.suspendedNPCIntention == nil,
          physical.identity.system == context.system, physical.identity.visit == context.visit,
          bodies.filter({ $0.physical?.identity == physical.identity }).count == 1
        else { throw NativeMissionProjectileAdmissionError.invalidRecord }
      }
      // Readmission keeps the actual live pose, direction and age, never the older stored pose.
      legacy = body
    }
    guard let pack = scriptPack(for: instance), scriptUnavailable(pack) == nil else {
      throw NativeMissionProjectileAdmissionError.unavailablePack
    }
    guard !docked, let anchor = scriptAnchor else {
      throw NativeMissionProjectileAdmissionError.outsideBubble
    }
    var scriptUnits = 0
    for body in bodies {
      let units = body.scriptNativeUnits
      guard units <= 1024 - scriptUnits else {
        throw NativeMissionProjectileAdmissionError.refused(.reservedCapacity)
      }
      scriptUnits += units
    }
    let additional = legacy == nil ? record.body.scriptNativeUnits : 0
    guard additional <= 1024 - scriptUnits else {
      throw NativeMissionProjectileAdmissionError.refused(.reservedCapacity)
    }
    var restored: SpaceBody
    if let legacy {
      restored = legacy
      restored.physical = nil
    } else {
      restored = record.body
      restored.position = anchor.position + anchor.orientation.apply(record.body.position)
      restored.orientation = record.body.orientation.transformed(by: anchor.orientation)
      restored.scriptShot?.velocity = anchor.orientation.apply(savedShot.velocity)
    }
    guard !restored.leavesLocalBubble else {
      throw NativeMissionProjectileAdmissionError.outsideBubble
    }
    guard (0..<999_999_999).contains(nextBodyID),
      commander.flightSimulation.nextSpawn < UInt64.max,
      commander.flightSimulation.nextActor < UInt64.max,
      !bodies.contains(where: { $0.id == nextBodyID }),
      !bodies.contains(where: {
        $0.physical?.identity.system == systemIdentity
          && $0.physical?.identity.visit == commander.flightSimulation.visit
          && $0.physical?.identity.entity == commander.flightSimulation.nextActor
      })
    else { throw NativeMissionProjectileAdmissionError.allocatorExhausted }
    return .restore(restored, retiringBodyID: legacy?.id)
  }

  private mutating func stageRetainedMissionProjectile(_ prototype: SpaceBody) throws
    -> NativeMissionProjectileReceipt
  {
    ensurePhysicalActors()
    guard let shot = prototype.scriptShot, let context = gameplayContext(),
      let sequence = commander.flightSimulation.allocateSpawn()
    else { throw NativeMissionProjectileAdmissionError.allocatorExhausted }
    let pose = commander.flightSimulation.pose
    let worldVelocity = pose.orientation.apply(shot.velocity)
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .ordnance),
      population: .projectile, hull: .missile, position: pose.systemPoint(prototype.position),
      orientation: pose.orientation.composed(with: prototype.orientation), velocity: worldVelocity,
      npc: nil, rock: nil, payload: nil, priority: .mission)
    let results = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: true)], intents: []))
    guard let result = results.first, let actor = result.actor,
      let index = bodies.firstIndex(where: { $0.physical?.identity == actor })
    else {
      throw NativeMissionProjectileAdmissionError.refused(
        results.first?.refusal ?? .reservedCapacity)
    }
    var restored = prototype
    restored.id = bodies[index].id
    restored.physical = bodies[index].physical
    restored.physical?.velocity = worldVelocity
    // Historical attribution stays data; missing old archive never invents an origin.
    restored.physical?.attackOrigin = shot.nativeAttribution?.origin
    restored.physical?.emissionPosition = shot.nativeAttribution?.judgement.emissionPosition
    bodies[index] = restored
    return .init(bodyID: restored.id, actor: actor)
  }
}
