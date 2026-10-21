import Foundation

struct NativeMissionProjectileEmissionReceipt: Sendable, Equatable {
  let bodyID: Int
  let actor: ActorIdentity

  fileprivate init(bodyID: Int, actor: ActorIdentity) {
    self.bodyID = bodyID
    self.actor = actor
  }
}

/// A transient native admission prepared from the actual retained source and authored fit.
/// Only this file may construct it; decoded mission data never supplies admission authority.
struct NativeMissionProjectileEmissionPlan: Sendable {
  let bodyID: Int
  let shotID: UUID
  let actor: ActorIdentity
  let archive: MissionLaunchArchive
  fileprivate let source: MissionActorBinding
  fileprivate let target: MissionActorBinding?
  fileprivate let previousFlight: FlightSimulationState
  fileprivate let context: EncounterContext
  fileprivate let anchor: SpaceBody
  fileprivate let flight: FlightSimulationState
  fileprivate let body: SpaceBody
  fileprivate let record: ScriptProjectileRecord
}

extension Game {
  /// Prepare without adopting unrelated actors, allocating live counters or creating a fake
  /// retained shot. G2's actual selected-gun budget must pass before calling this provider.
  func prepareMissionProjectileAdmission(
    source: MissionActorBinding, weapon: ScriptNPCWeapon, component: UUID?,
    muzzle: Vector3, direction: Vector3, intendedTarget: GameplayHitTarget
  ) throws -> NativeMissionProjectileEmissionPlan {
    guard !docked, let context = gameplayContext(), let anchor = scriptAnchor,
      let sourceBody = bodies.first(where: { $0.id == source.bodyID }),
      let npc = sourceBody.scriptNPC, npc.shots < UInt64(Int64.max) - 1,
      let authored = missionWeaponDescriptor(
        weapon, source: sourceBody, component: component, muzzle: muzzle, direction: direction),
      authored.kind == .plasma,
      let speed = authored.projectileSpeed, let lifetime = authored.lifetime,
      let radius = authored.collisionRadius, let delay = authored.collisionDelay
    else { throw MissionNativeBridgeError.unsupportedWeapon }
    try validateEmissionBinding(source, context: context)
    let target: MissionActorBinding?
    let victim: ActorSnapshot
    switch intendedTarget {
    case .player:
      target = nil
      victim = context.player
    case .body(let id):
      guard let descriptor = currentMissionActorDescriptor(bodyID: id),
        let body = bodies.first(where: { $0.id == id })
      else { throw MissionNativeBridgeError.sourceMismatch }
      let binding = try MissionNativeBridge.bindActor(
        descriptor: descriptor, body: body, context: context)
      guard let actual = context.actors.first(where: { $0.identity == binding.nativeActor }) else {
        throw MissionNativeBridgeError.invalidNativeBinding
      }
      target = binding
      victim = actual
    case .celestial:
      throw MissionNativeBridgeError.unsupportedWeapon
    }
    let shotID = ScriptIdentity.uuid("npc-shot-v1:\(source.actorID):\(npc.shots + 1)")
    guard commander.scriptState.projectiles.count < 1024,
      commander.scriptState.projectiles[shotID] == nil,
      !bodies.contains(where: { $0.scriptShot?.identity == shotID }),
      (0..<999_999_999).contains(nextBodyID),
      Set(bodies.map(\.id)).count == bodies.count,
      bodies.allSatisfy({ $0.id < nextBodyID }),
      bodies.reduce(0, { $0 + $1.scriptNativeUnits }) < 1024
    else { throw NativeMissionProjectileAdmissionError.allocatorExhausted }
    var flight = commander.flightSimulation
    let identities = bodies.compactMap { $0.physical?.identity }
    let spawns = bodies.compactMap { $0.physical?.spawnIdentity }
    guard flight.valid, Set(identities).count == identities.count,
      identities.filter({ $0.system == context.system && $0.visit == context.visit })
        .allSatisfy({ $0.entity < flight.nextActor }),
      Set(spawns).count == spawns.count,
      spawns.allSatisfy({
        NativeMissionSpawnAddress.isCurrent(
          $0, system: context.system, visit: context.visit, nextFlightSpawn: flight.nextSpawn)
      }),
      let sequence = flight.allocateSpawn(), let actor = flight.allocateActor(),
      let emission = flight.allocateEmission(), flight.valid,
      let emitter = context.actors.first(where: { $0.identity == source.nativeActor })
    else { throw NativeMissionProjectileAdmissionError.allocatorExhausted }
    let velocity = direction * speed
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .ordnance),
      population: .projectile, hull: .missile,
      position: flight.pose.systemPoint(muzzle),
      orientation: flight.pose.orientation, velocity: flight.pose.orientation.apply(velocity),
      npc: nil, rock: nil, payload: nil, priority: .mission)
    if let refusal = gameplayProjectileAdmissionRefusal(request, context: context) {
      throw NativeMissionProjectileAdmissionError.refused(refusal)
    }
    let origin = AttackOrigin(
      emissionID: emission, owner: source.nativeActor, emittedAt: context.physicalTime,
      ownerLegalAtEmission: emitter.legal, sourcePart: component?.uuidString)
    let judgement = try commander.crimeLedger.freezeMissionLaunchJudgement(
      origin: origin, intendedVictim: victim, emissionPosition: request.position, context: context)
    let shot = ScriptNPCShot(
      identity: shotID, owner: source.actorID, instance: source.instanceID,
      weapon: authored.id, component: component, velocity: velocity, age: 0,
      lifetime: lifetime, damage: authored.damage, radius: radius, collisionDelay: delay)
    guard let descriptor = shot.missionDescriptor else {
      throw MissionNativeBridgeError.invalidShot
    }
    let archive = try MissionNativeBridge.makeLaunchArchive(
      shot: descriptor, source: source, intendedTarget: target, judgement: judgement)
    var body = SpaceBody(id: nextBodyID, hull: .missile, position: muzzle)
    body.energy = 1
    body.rotationRate = 0
    body.scriptShot = .init(
      identity: shotID, owner: source.actorID, instance: source.instanceID,
      weapon: authored.id, component: component, velocity: velocity, age: 0,
      lifetime: lifetime, damage: authored.damage, radius: radius, collisionDelay: delay,
      nativeAttribution: archive)
    body.physical = .init(
      identity: actor, population: .projectile, velocity: request.velocity,
      spawnIdentity: request.identity)
    body.physical?.attackOrigin = origin
    body.physical?.emissionPosition = request.position
    var canonical = body
    canonical.position = anchor.orientation.inverse(body.position - anchor.position)
    canonical.orientation = body.orientation.relative(to: anchor.orientation)
    canonical.scriptShot?.velocity = anchor.orientation.inverse(velocity)
    let record = ScriptProjectileRecord(
      galaxy: commander.galaxy, system: commander.system, body: canonical, presence: .present)
    guard record.valid, commander.scriptState.projectileArchiveValid(record) else {
      throw MissionNativeBridgeError.invalidArchive
    }
    return .init(
      bodyID: body.id, shotID: shotID, actor: actor, archive: archive, source: source,
      target: target, previousFlight: commander.flightSimulation, context: context,
      anchor: anchor, flight: flight, body: body, record: record)
  }

  /// The caller finishes its prevalidated selected-gun fields and event projection immediately
  /// after this successful commit in the same actor turn, with no await or fallible operation.
  mutating func commitMissionProjectileAdmission(_ plan: NativeMissionProjectileEmissionPlan) throws
    -> NativeMissionProjectileEmissionReceipt
  {
    guard let context = gameplayContext(), context == plan.context else {
      throw MissionNativeBridgeError.staleBinding
    }
    try validateEmissionBinding(plan.source, context: context)
    if let target = plan.target { try validateEmissionBinding(target, context: context) }
    guard commander.flightSimulation == plan.previousFlight,
      scriptAnchor == plan.anchor, nextBodyID == plan.bodyID,
      !bodies.contains(where: { $0.id == plan.bodyID || $0.scriptShot?.identity == plan.shotID }),
      commander.scriptState.projectiles[plan.shotID] == nil,
      commander.scriptState.projectiles.count < 1024
    else { throw MissionNativeBridgeError.staleBinding }
    commander.flightSimulation = plan.flight
    bodies.append(plan.body)
    nextBodyID += 1
    commander.scriptState.projectiles[plan.shotID] = plan.record
    return .init(bodyID: plan.bodyID, actor: plan.actor)
  }

  private func validateEmissionBinding(
    _ binding: MissionActorBinding, context: EncounterContext
  ) throws {
    guard let descriptor = currentMissionActorDescriptor(bodyID: binding.bodyID),
      let body = bodies.first(where: { $0.id == binding.bodyID })
    else { throw MissionNativeBridgeError.sourceMismatch }
    try MissionNativeBridge.validateBinding(
      binding, descriptor: descriptor, body: body, context: context)
  }

}
