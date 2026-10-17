import Foundation

public enum OrdnanceProfile: String, Codable, Sendable, CaseIterable {
  case standardMissile, plasma, alienSeeker

  public var speed: Double {
    switch self {
    case .standardMissile: 792
    case .plasma: 600
    case .alienSeeker: Self.standardMissile.speed * 1.25
    }
  }
  public var damage: Double {
    switch self {
    case .standardMissile: 250
    case .plasma: 40
    case .alienSeeker: Self.standardMissile.damage * 1.25
    }
  }
  public var energyCost: Double { self == .plasma ? 12 : 0 }
  public var heat: Double { self == .plasma ? 8 : 0 }
  public var firingInterval: Double { 1 }
  // Finite flight bounds are project constraints, separate from native missile speed.
  public var range: Double { self == .plasma ? 1200 : 6000 }
  public var lifetime: Double { self == .plasma ? 2 : 24 }
  public var attackKind: AttackKind { self == .plasma ? .plasma : .missile }
}

/// The caller supplies identities only while their actual ECM fields are active/in range.
public struct ECMActivationIdentity: Hashable, Codable, Sendable {
  public let emitter: ActorIdentity
  public let sequence: UInt64
  public init(emitter: ActorIdentity, sequence: UInt64) {
    self.emitter = emitter
    self.sequence = sequence
  }
}

public enum OrdnanceEnd: String, Codable, Sendable {
  case impact, rangeExpired, lifetimeExpired, targetLost, culled, ecm, destroyed, invalidState
}

private struct OrdnanceMotion {
  let start: Vector3
  let end: Vector3
  let elapsed: Double
}

/// All motion is in canonical system space. Camera motion never changes this state.
public struct OrdnanceState: Equatable, Codable, Sendable {
  public let profile: OrdnanceProfile
  public let origin: AttackOrigin
  public let target: ActorIdentity?
  public let emissionPosition: Vector3
  public let inheritedVelocity: Vector3
  public private(set) var position: Vector3
  public private(set) var direction: Vector3
  public private(set) var propulsionTravel = 0.0
  public private(set) var lastUpdatedAt: Double
  public private(set) var muzzleCleared = false
  public private(set) var resistedECM: ECMActivationIdentity?
  public private(set) var termination: OrdnanceEnd?

  public init?(
    profile: OrdnanceProfile, origin: AttackOrigin, target: ActorIdentity? = nil,
    position: Vector3, direction: Vector3, launcherVelocity: Vector3 = .init(0, 0, 0),
    emissionPosition: Vector3? = nil
  ) {
    guard position.finite, emissionPosition?.finite ?? true, launcherVelocity.finite,
      let direction = Self.normalized(direction),
      origin.emissionID > 0, origin.emittedAt.isFinite, origin.emittedAt >= 0,
      let ordnance = origin.ordnance, ordnance != origin.owner,
      ordnance.system == origin.owner.system, ordnance.visit == origin.owner.visit,
      target != origin.owner, target != ordnance,
      profile == .plasma || target != nil
    else { return nil }
    if let target,
      target.system != origin.owner.system || target.visit != origin.owner.visit
    {
      return nil
    }
    self.profile = profile
    self.origin = origin
    self.target = target
    self.emissionPosition = emissionPosition ?? position
    self.position = position
    self.direction = direction
    self.inheritedVelocity = profile == .plasma ? launcherVelocity : .init(0, 0, 0)
    self.lastUpdatedAt = origin.emittedAt
  }

  public var velocity: Vector3 { direction * profile.speed + inheritedVelocity }
  public var valid: Bool {
    position.finite && emissionPosition.finite && inheritedVelocity.finite && direction.finite
      && abs(direction.length - 1) < 1e-6 && propulsionTravel.isFinite && propulsionTravel >= 0
      && propulsionTravel <= profile.range + 1e-6 && lastUpdatedAt.isFinite
      && origin.emittedAt.isFinite && origin.emittedAt >= 0 && lastUpdatedAt >= origin.emittedAt
      && lastUpdatedAt <= origin.emittedAt + profile.lifetime + 1e-6
      && origin.emissionID > 0
      && origin.ordnance.map {
        $0 != origin.owner && $0.system == origin.owner.system && $0.visit == origin.owner.visit
      } == true
      && (profile == .plasma || target != nil) && target != origin.owner
      && target != origin.ordnance
      && (target.map { $0.system == origin.owner.system && $0.visit == origin.owner.visit } ?? true)
  }

  /// One resisted activation is enough history: a different activation terminates the seeker.
  fileprivate mutating func receiveECM(_ pulses: [ECMActivationIdentity]) -> Bool {
    guard termination == nil, profile != .plasma else { return false }
    let ordered = pulses.filter {
      $0.emitter.system == origin.owner.system && $0.emitter.visit == origin.owner.visit
    }.sorted {
      $0.sequence == $1.sequence ? $0.emitter.entity < $1.emitter.entity : $0.sequence < $1.sequence
    }
    var resisted = false
    for pulse in ordered {
      if resistedECM == pulse { continue }
      if profile == .alienSeeker && resistedECM == nil {
        resistedECM = pulse
        resisted = true
      } else {
        termination = .ecm
        break
      }
    }
    return resisted
  }

  fileprivate mutating func clearMuzzle() { muzzleCleared = true }

  fileprivate mutating func finish(_ reason: OrdnanceEnd) {
    if termination == nil { termination = reason }
  }

  fileprivate mutating func move(context: EncounterContext) -> OrdnanceMotion? {
    guard termination == nil, context.physicalTime - lastUpdatedAt > 1e-10 else { return nil }
    let remainingRange = max(0, profile.range - propulsionTravel) / profile.speed
    let remainingLife = max(0, origin.emittedAt + profile.lifetime - lastUpdatedAt)
    let guidanceStep = profile == .alienSeeker ? 1.0 / 120 : context.physicalTime - lastUpdatedAt
    let delta = min(
      context.physicalTime - lastUpdatedAt, guidanceStep, remainingRange, remainingLife)
    guard delta > 1e-10 else {
      finish(propulsionTravel >= profile.range - 1e-6 ? .rangeExpired : .lifetimeExpired)
      return nil
    }
    if profile != .plasma {
      guard let actor = target.flatMap({ Self.actor($0, context: context) }), actor.energy > 0
      else {
        finish(.targetLost)
        return nil
      }
      if let desired = Self.normalized(actor.position - position) {
        direction =
          profile == .alienSeeker
          ? Self.turned(direction, toward: desired, maximumAngle: 3 * delta) : desired
      }
    }
    let start = position
    position = position + velocity * delta
    guard position.finite else {
      position = start
      finish(.invalidState)
      return nil
    }
    propulsionTravel = min(profile.range, propulsionTravel + profile.speed * delta)
    lastUpdatedAt += delta
    return .init(start: start, end: position, elapsed: delta)
  }

  fileprivate mutating func impact(_ world: Vector3, fraction: Double, motion: OrdnanceMotion) {
    position = world
    propulsionTravel = max(0, propulsionTravel - profile.speed * motion.elapsed * (1 - fraction))
    lastUpdatedAt = max(origin.emittedAt, lastUpdatedAt - motion.elapsed * (1 - fraction))
    finish(.impact)
  }

  fileprivate mutating func enforceBounds() {
    if propulsionTravel >= profile.range - 1e-6 {
      finish(.rangeExpired)
    } else if lastUpdatedAt >= origin.emittedAt + profile.lifetime - 1e-8 {
      finish(.lifetimeExpired)
    }
  }

  private static func actor(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot?
  {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  private static func normalized(_ vector: Vector3) -> Vector3? {
    guard vector.finite else { return nil }
    let scale = max(abs(vector.x), max(abs(vector.y), abs(vector.z)))
    guard scale > 0 else { return nil }
    let scaled = Vector3(vector.x / scale, vector.y / scale, vector.z / scale)
    return scaled * (1 / hypot(hypot(scaled.x, scaled.y), scaled.z))
  }

  private static func turned(_ from: Vector3, toward to: Vector3, maximumAngle: Double) -> Vector3 {
    let angle = acos(max(-1, min(1, from.dot(to))))
    guard angle > maximumAngle else { return to }
    let cardinals = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
    let cardinal = cardinals.min { abs(from.dot($0)) < abs(from.dot($1)) } ?? cardinals[0]
    let axis = normalized(from.cross(to)) ?? normalized(from.cross(cardinal)) ?? cardinal
    let result = from * cos(maximumAngle) + axis.cross(from) * sin(maximumAngle)
    return normalized(result) ?? from
  }
}

public struct OrdnanceUpdate: Equatable, Sendable {
  public let bodyID: Int
  public let position: Vector3
  public let velocity: Vector3
  public let termination: OrdnanceEnd?
  public let hit: GameplayHit?
  public let incident: CombatIncident?
  public let resistedECM: Bool
  public let endedNow: Bool
}

/// Sealed only by the actual native swept-ordnance producer below; never decoded from a save.
struct NativeMissionOrdnanceImpactProof: Sendable {
  let projectileBody: SpaceBody
  let ordnance: OrdnanceState
  let contact: MissionCollisionContact
  let start: Vector3
  let end: Vector3
  let ignored: Set<Int>
  let includePlayer: Bool
  let physicalTime: Double
  let sceneRevision: UInt64
  let damage: Double

  fileprivate init(
    projectileBody: SpaceBody, ordnance: OrdnanceState, contact: MissionCollisionContact,
    start: Vector3, end: Vector3, ignored: Set<Int>, includePlayer: Bool,
    physicalTime: Double, sceneRevision: UInt64, damage: Double
  ) {
    self.projectileBody = projectileBody
    self.ordnance = ordnance
    self.contact = contact
    self.start = start
    self.end = end
    self.ignored = ignored
    self.includePlayer = includePlayer
    self.physicalTime = physicalTime
    self.sceneRevision = sceneRevision
    self.damage = damage
  }
}

extension Game {
  @discardableResult
  mutating func advanceOrdnance(
    bodyID: Int, state: inout OrdnanceState, context: EncounterContext,
    activeECM: [ECMActivationIdentity] = []
  ) -> OrdnanceUpdate {
    guard state.valid, context.physicalTime.isFinite,
      context.system == state.origin.owner.system, context.visit == state.origin.owner.visit,
      context.physicalTime >= state.lastUpdatedAt,
      context.system == commander.flightSimulation.system,
      context.visit == commander.flightSimulation.visit,
      abs(context.physicalTime - commander.flightSimulation.physicalTime) < 1e-8
    else { return endOrdnance(bodyID: bodyID, state: &state, reason: .invalidState) }
    guard
      let index = bodies.firstIndex(where: {
        $0.id == bodyID && $0.physical?.identity == state.origin.ordnance
      })
    else { return endOrdnance(bodyID: bodyID, state: &state, reason: .culled) }
    guard bodies[index].energy > 0 else {
      return endOrdnance(bodyID: bodyID, state: &state, reason: .destroyed)
    }
    let wasActive = state.termination == nil
    let resisted = state.receiveECM(activeECM)
    var hit: GameplayHit?
    var incident: CombatIncident?
    let beforeMotion = state
    do {
      while let motion = state.move(context: context) {
        updateMuzzleClearance(state: &state, position: motion.start, context: context)
        if let contact = try ordnanceCollision(
          bodyID: bodyID, state: state, motion: motion, context: context)
        {
          let collision = contact.hit
          if contact.selectedTargetBody?.scriptNPC != nil {
            let policy = ordnanceCollisionPolicy(bodyID: bodyID, state: state, context: context)
            let proof = NativeMissionOrdnanceImpactProof(
              projectileBody: bodies[index], ordnance: try requireStoredOrdnance(bodyID),
              contact: contact, start: commander.flightSimulation.pose.shipPoint(motion.start),
              end: commander.flightSimulation.pose.shipPoint(motion.end), ignored: policy.ignored,
              includePlayer: policy.includePlayer, physicalTime: context.physicalTime,
              sceneRevision: context.revision,
              damage: ordnanceImpactDamage(state: state, hit: collision))
            let applied = try applyMissionImpact(proof)
            projectScriptMissionImpact(applied.receipt)
            incident = applied.incident
          } else {
            incident = applyCombatHit(
              collision, origin: state.origin, kind: state.profile.attackKind,
              damage: ordnanceImpactDamage(state: state, hit: collision),
              emissionPosition: state.emissionPosition)
          }
          hit = collision
          let length = (motion.end - motion.start).length
          let fraction = length > 0 ? max(0, min(1, collision.distance / length)) : 0
          state.impact(
            commander.flightSimulation.pose.systemPoint(collision.point), fraction: fraction,
            motion: motion)
          break
        }
        updateMuzzleClearance(state: &state, position: motion.end, context: context)
        state.enforceBounds()
      }
    } catch {
      // Admission/event pressure is retryable: neither an impact nor motion is committed.
      state = beforeMotion
      hit = nil
      incident = nil
      if !(error is ScriptMissionEventCapacityError) {
        notify("ORDNANCE COLLISION UNAVAILABLE", voiced: false)
      }
    }
    bodies[index].position = commander.flightSimulation.pose.shipPoint(state.position)
    bodies[index].physical?.velocity = state.velocity
    if state.termination != nil {
      bodies[index].energy = 0
      commander.crimeLedger.finishEmission(state.origin.emissionID)
    }
    return .init(
      bodyID: bodyID, position: state.position, velocity: state.velocity,
      termination: state.termination, hit: hit, incident: incident, resistedECM: resisted,
      endedNow: wasActive && state.termination != nil)
  }

  @discardableResult
  mutating func endOrdnance(bodyID: Int, state: inout OrdnanceState, reason: OrdnanceEnd)
    -> OrdnanceUpdate
  {
    let wasActive = state.termination == nil
    state.finish(reason)
    if let index = bodies.firstIndex(where: {
      $0.id == bodyID && $0.physical?.identity == state.origin.ordnance
    }) {
      bodies[index].energy = 0
    }
    commander.crimeLedger.finishEmission(state.origin.emissionID)
    return .init(
      bodyID: bodyID, position: state.position, velocity: state.velocity,
      termination: state.termination, hit: nil, incident: nil, resistedECM: false,
      endedNow: wasActive)
  }

  private func updateMuzzleClearance(
    state: inout OrdnanceState, position: Vector3, context: EncounterContext
  ) {
    guard !state.muzzleCleared else { return }
    let center: Vector3
    let radius: Double
    if state.origin.owner == context.player.identity {
      center = context.player.position
      radius = commander.playerMesh.vertices.map(\.length).max() ?? 0
    } else if let body = bodies.first(where: {
      $0.physical?.identity == state.origin.owner && $0.energy > 0
    }) {
      center = commander.flightSimulation.pose.systemPoint(body.position)
      radius =
        body.scriptNPC == nil
        ? (gameplayMesh(for: body).vertices.map(\.length).max() ?? 0) : scriptNPCRadius(body)
    } else {
      state.clearMuzzle()
      return
    }
    if (position - center).length > radius + 1e-6 { state.clearMuzzle() }
  }

  private func requireStoredOrdnance(_ bodyID: Int) throws -> OrdnanceState {
    guard let state = bodies.first(where: { $0.id == bodyID })?.physical?.ordnance else {
      throw NativeMissionImpactError.staleProof
    }
    return state
  }

  private func ordnanceCollisionPolicy(
    bodyID: Int, state: OrdnanceState, context: EncounterContext
  ) -> (ignored: Set<Int>, includePlayer: Bool) {
    var ignored: Set<Int> = [bodyID]
    if !state.muzzleCleared,
      let owner = bodies.first(where: { $0.physical?.identity == state.origin.owner })
    {
      ignored.insert(owner.id)
    }
    return (
      ignored, energy > 0 && (state.muzzleCleared || state.origin.owner != context.player.identity)
    )
  }

  private func ordnanceCollision(
    bodyID: Int, state: OrdnanceState, motion: OrdnanceMotion, context: EncounterContext
  ) throws -> MissionCollisionContact? {
    let pose = commander.flightSimulation.pose
    let start = pose.shipPoint(motion.start)
    let end = pose.shipPoint(motion.end)
    let difference = end - start
    guard difference.length > 1e-8 else { return nil }
    let policy = ordnanceCollisionPolicy(bodyID: bodyID, state: state, context: context)
    return try nearestMissionCollision(
      from: start, direction: difference.unit, range: difference.length, radius: 0,
      excludingBodyIDs: policy.ignored, includePlayer: policy.includePlayer)
  }

  func validateNativeMissionOrdnanceImpactProof(_ proof: NativeMissionOrdnanceImpactProof) throws {
    guard let context = gameplayContext(), context.physicalTime == proof.physicalTime,
      context.revision == proof.sceneRevision,
      bodies.filter({ $0.id == proof.projectileBody.id }) == [proof.projectileBody],
      proof.projectileBody.energy > 0, proof.projectileBody.scriptShot == nil,
      proof.projectileBody.physical?.ordnance == proof.ordnance, proof.ordnance.valid,
      proof.ordnance.termination == nil,
      proof.projectileBody.physical?.identity == proof.ordnance.origin.ordnance,
      proof.ordnance.origin.owner.system == context.system,
      proof.ordnance.origin.owner.visit == context.visit,
      proof.ordnance.lastUpdatedAt <= context.physicalTime,
      proof.start.finite, proof.end.finite, (proof.end - proof.start).length > 1e-8,
      proof.damage == ordnanceImpactDamage(state: proof.ordnance, hit: proof.contact.hit),
      let contact = try nearestMissionCollision(
        from: proof.start, direction: (proof.end - proof.start).unit,
        range: (proof.end - proof.start).length, radius: 0,
        excludingBodyIDs: proof.ignored, includePlayer: proof.includePlayer),
      contact == proof.contact
    else { throw NativeMissionImpactError.staleProof }
  }

  private func ordnanceImpactDamage(state: OrdnanceState, hit: GameplayHit) -> Double {
    // Native energy-only targets were destroyed by one missile, including the 252-energy
    // Constrictor. New shielded NPC profiles use the finite weapon's actual damage instead.
    if state.profile == .standardMissile, case .body(let id) = hit.target,
      let body = bodies.first(where: { $0.id == id }), body.hull.isTargetShip,
      body.scriptNPC == nil,
      body.physical?.npc?.resources?.profile == .legacyEnergyOnly
    {
      return max(state.profile.damage, body.energy)
    }
    return state.profile.damage
  }
}
