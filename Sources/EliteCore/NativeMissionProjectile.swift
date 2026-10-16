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

extension Game {
  /// Restore one actual retained shot through the native allocator and admission budget.
  /// MC1 publishes its matching record address only after receiving this real receipt.
  mutating func admitRetainedMissionProjectile(_ shotID: UUID) throws
    -> NativeMissionProjectileReceipt
  {
    var candidate = self
    let receipt = try candidate.stageRetainedMissionProjectile(shotID)
    self = candidate
    return receipt
  }

  private mutating func stageRetainedMissionProjectile(_ shotID: UUID) throws
    -> NativeMissionProjectileReceipt
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
    guard let pack = scriptPack(for: instance), scriptUnavailable(pack) == nil else {
      throw NativeMissionProjectileAdmissionError.unavailablePack
    }
    try MissionNativeBridge.validateArchive(
      savedShot.nativeAttribution, shot: descriptor, packDigest: instance.digest)
    guard !docked, let anchor = scriptAnchor else {
      throw NativeMissionProjectileAdmissionError.outsideBubble
    }
    ensurePhysicalActors()
    guard let context = gameplayContext() else {
      throw NativeMissionProjectileAdmissionError.invalidRecord
    }
    var scriptUnits = 0
    for body in bodies {
      let units = body.scriptNativeUnits
      guard units <= 1024 - scriptUnits else {
        throw NativeMissionProjectileAdmissionError.refused(.reservedCapacity)
      }
      scriptUnits += units
    }
    let matching = bodies.filter { $0.scriptShot?.identity == shotID }
    if !matching.isEmpty {
      guard matching.count == 1, let body = matching.first, body.id == record.body.id,
        body.energy > 0, let shot = body.scriptShot, shot.valid,
        shot.owner == savedShot.owner, shot.instance == savedShot.instance,
        shot.weapon == savedShot.weapon, shot.component == savedShot.component,
        shot.lifetime == savedShot.lifetime, shot.damage == savedShot.damage,
        shot.radius == savedShot.radius, shot.collisionDelay == savedShot.collisionDelay,
        abs(shot.velocity.length - savedShot.velocity.length)
          <= max(1, max(shot.velocity.length, savedShot.velocity.length)) * 1e-6,
        shot.nativeAttribution == savedShot.nativeAttribution,
        let physical = body.physical, physical.population == .projectile,
        physical.identity.system == context.system, physical.identity.visit == context.visit,
        physical.spawnIdentity?.system == context.system,
        physical.spawnIdentity?.visit == context.visit,
        physical.spawnIdentity?.producer == .ordnance,
        physical.attackOrigin == savedShot.nativeAttribution?.origin,
        context.actors.contains(where: { $0.identity == physical.identity && $0.energy > 0 })
      else { throw NativeMissionProjectileAdmissionError.invalidRecord }
      return .init(bodyID: body.id, actor: physical.identity)
    }

    guard record.body.scriptNativeUnits <= 1024 - scriptUnits else {
      throw NativeMissionProjectileAdmissionError.refused(.reservedCapacity)
    }

    var restored = record.body
    restored.position = anchor.position + anchor.orientation.apply(record.body.position)
    restored.orientation = record.body.orientation.transformed(by: anchor.orientation)
    restored.scriptShot?.velocity = anchor.orientation.apply(savedShot.velocity)
    guard !restored.leavesLocalBubble else {
      throw NativeMissionProjectileAdmissionError.outsideBubble
    }
    guard (0..<999_999_999).contains(nextBodyID),
      let sequence = commander.flightSimulation.allocateSpawn()
    else { throw NativeMissionProjectileAdmissionError.allocatorExhausted }
    let pose = commander.flightSimulation.pose
    let worldVelocity = pose.orientation.apply(anchor.orientation.apply(savedShot.velocity))
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .ordnance),
      population: .projectile, hull: .missile, position: pose.systemPoint(restored.position),
      orientation: pose.orientation.composed(with: restored.orientation), velocity: worldVelocity,
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
    restored.id = bodies[index].id
    restored.physical = bodies[index].physical
    restored.physical?.velocity = worldVelocity
    // Historical origin is retained as data; ordinary current-visit crime guards stay strict.
    // Missing old archive never manufactures an emission, owner or legal judgement.
    restored.physical?.attackOrigin = savedShot.nativeAttribution?.origin
    restored.physical?.emissionPosition = savedShot.nativeAttribution?.judgement.emissionPosition
    bodies[index] = restored
    return .init(bodyID: restored.id, actor: actor)
  }
}
