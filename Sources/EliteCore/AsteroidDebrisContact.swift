import Foundation

/// Authored collision tuning, not catalogue specifications or a conversion of render radii.
enum AsteroidImpactPolicy {
  static let restitution = 0.15
  static let metresPerCollisionUnit = 1.0
  static let joulesPerEnergy = 10_000.0
  static let maximumSpeed = 100_000.0
  static let maximumCandidatePairs = 32

  static func massKg(hull: Hull) -> Double {
    switch hull {
    case .station: 1_000_000_000
    case .cobra, .constrictor, .thargoid: 100_000
    case .viper: 45_000
    case .sidewinder, .thargon: 25_000
    case .cargo: 1000
    case .asteroid: 50_000
    case .missile: 250
    }
  }

  static func impulse(
    sourceMass: Double, targetMass: Double, sourceVelocity: Vector3,
    targetVelocity: Vector3, normal: Vector3
  ) -> AsteroidImpulse? {
    guard sourceMass.isFinite, targetMass.isFinite,
      (0.001...1e12).contains(sourceMass), (0.001...1e12).contains(targetMass),
      sourceVelocity.finite, targetVelocity.finite,
      sourceVelocity.length <= maximumSpeed, targetVelocity.length <= maximumSpeed,
      normal.finite, abs(normal.length - 1) < 1e-6
    else { return nil }
    let closing = (sourceVelocity - targetVelocity).dot(normal)
    guard closing.isFinite, closing > 1e-8 else { return nil }
    let inverseMass = 1 / sourceMass + 1 / targetMass
    let magnitude = (1 + restitution) * closing / inverseMass
    let impulse = normal * magnitude
    let a = sourceVelocity - impulse * (1 / sourceMass)
    let b = targetVelocity + impulse * (1 / targetMass)
    let loss =
      0.5 / inverseMass * (1 - restitution * restitution)
      * pow(closing * metresPerCollisionUnit, 2)
    let damage = loss / joulesPerEnergy
    guard a.finite, b.finite, a.length <= maximumSpeed, b.length <= maximumSpeed,
      impulse.finite, impulse.length.isFinite, damage.isFinite, (0...1e12).contains(damage)
    else { return nil }
    return .init(source: a, target: b, transferred: impulse, damage: damage)
  }
}

struct AsteroidImpulse: Sendable {
  let source: Vector3
  let target: Vector3
  let transferred: Vector3
  let damage: Double
}

/// Only the live producer in this file constructs a receipt after a real accepted effect.
struct AsteroidImpactReceipt: Sendable {
  let source: ActorIdentity
  let target: ActorIdentity
  let point: Vector3
  let transferredMomentum: Vector3
  let damage: Double
  let incident: UInt64
  let contactPhysicalTime: Double
  fileprivate init(
    source: ActorIdentity, target: ActorIdentity, point: Vector3,
    transferredMomentum: Vector3, damage: Double, incident: UInt64, contactPhysicalTime: Double
  ) {
    self.source = source
    self.target = target
    self.point = point
    self.transferredMomentum = transferredMomentum
    self.damage = damage
    self.incident = incident
    self.contactPhysicalTime = contactPhysicalTime
  }
}

enum AsteroidContactStepResult {
  case advanced(AsteroidImpactReceipt?)
  case refused(String)
  var admitted: Bool {
    if case .advanced = self { return true }
    return false
  }
}

/// Only the live contact producer can construct this non-decodable station transfer.
struct StationContactTransfer: Sendable {
  let station: StationInertialIdentity
  let actor: ActorIdentity
  let bodyID: Int
  let system: SystemIdentity
  let visit: UInt64
  let physicalTime: Double
  let impactTime: Double
  let previousVelocity: Vector3
  let finalPosition: Vector3
  let finalVelocity: Vector3
  let impulse: Vector3
  let damage: Double
  fileprivate init(
    station: StationInertialIdentity, actor: ActorIdentity, bodyID: Int,
    system: SystemIdentity, visit: UInt64, physicalTime: Double, impactTime: Double,
    previousVelocity: Vector3,
    finalPosition: Vector3, finalVelocity: Vector3, impulse: Vector3, damage: Double
  ) {
    self.station = station
    self.actor = actor
    self.bodyID = bodyID
    self.system = system
    self.visit = visit
    self.physicalTime = physicalTime
    self.impactTime = impactTime
    self.previousVelocity = previousVelocity
    self.finalPosition = finalPosition
    self.finalVelocity = finalVelocity
    self.impulse = impulse
    self.damage = damage
  }
}

/// Refused movement is a clock-bound rollback, never an admitted impact.
struct StationMotionRefusal: Sendable {
  let station: StationInertialIdentity
  let actor: ActorIdentity
  let bodyID: Int
  let system: SystemIdentity
  let visit: UInt64
  let fromTime: Double
  let toTime: Double
  let duration: Double
  let position: Vector3
  let velocity: Vector3
  fileprivate init(
    station: StationInertialIdentity, actor: ActorIdentity, bodyID: Int,
    system: SystemIdentity, visit: UInt64, fromTime: Double, toTime: Double, duration: Double,
    position: Vector3, velocity: Vector3
  ) {
    self.station = station
    self.actor = actor
    self.bodyID = bodyID
    self.system = system
    self.visit = visit
    self.fromTime = fromTime
    self.toTime = toTime
    self.duration = duration
    self.position = position
    self.velocity = velocity
  }
}

private struct DebrisActorFrame {
  let identity: ActorIdentity
  let bodyID: Int?
  let pose: ShipPose
  let velocity: Vector3
  let mesh: Mesh
  let mass: Double
  let debris: Bool
  let asteroid: Bool
  let station: StationInertialIdentity?
  let hull: Hull
  let localOrientation: Basis3
  let rotation: Double
}

private struct DebrisBodyMotion {
  let id: Int
  let identity: ActorIdentity?
  let position: Vector3
  let orientation: Basis3
  let rotation: Double
  let velocity: Vector3?
  let npcViewVelocity: Vector3?
  let shotViewVelocity: Vector3?
}

/// Synchronous, acyclic, non-Sendable ownership of actual pre-movement facts.
final class AsteroidContactFrame {
  fileprivate let system: SystemIdentity
  fileprivate let visit: UInt64
  fileprivate let time: Double
  fileprivate let playerPose: ShipPose
  fileprivate let playerVelocity: Vector3
  fileprivate let actors: [DebrisActorFrame]
  fileprivate let celestials: [CelestialBody]
  fileprivate let bodyMotion: [DebrisBodyMotion]
  fileprivate let pilot: AutoTargetControl
  fileprivate let guidance: FlightWorkGuidance?
  fileprivate let braking: FlightWorkBraking?
  fileprivate let approved: HullSceneMotion?
  fileprivate let lastApplied: HullSceneMotion?
  fileprivate let residual: Bool
  fileprivate let recovery: RockIdentity?
  fileprivate let speed: Double
  fileprivate let startTime: Double
  fileprivate let stepDuration: Double
  fileprivate let stationReady: Bool
  private var consumed = false
  func identifiedSalvageSnapshot(_ actor: ActorIdentity)
    -> (mesh: Mesh, massKg: Double, debris: Bool, asteroid: Bool)?
  {
    guard let frame = actors.first(where: { $0.identity == actor }) else { return nil }
    return (frame.mesh, frame.mass, frame.debris, frame.asteroid)
  }
  fileprivate func take() -> Bool {
    guard !consumed else { return false }
    consumed = true
    return true
  }
  @inline(never)
  fileprivate init(
    game: borrowing Game, startTime: Double, stepDuration: Double, stationReady: Bool
  ) {
    self.startTime = startTime
    self.stepDuration = stepDuration
    self.stationReady = stationReady
    system = game.systemIdentity
    visit = game.commander.flightSimulation.visit
    time = game.commander.flightSimulation.physicalTime
    playerPose = game.commander.flightSimulation.pose
    playerVelocity = game.flightWorldVelocity
    celestials = game.celestials
    pilot = game.autoPilot
    guidance = game.workGuidance
    braking = game.workBraking
    approved = game.approvedWorkMotion
    lastApplied = game.lastAppliedWorkMotion
    residual = game.manualResidualFlight
    recovery = game.workRecoveryRock
    speed = game.speed
    bodyMotion = game.bodies.map {
      .init(
        id: $0.id, identity: $0.physical?.identity, position: $0.position,
        orientation: $0.orientation, rotation: $0.rotation, velocity: $0.physical?.velocity,
        npcViewVelocity: $0.scriptNPC?.velocity, shotViewVelocity: $0.scriptShot?.velocity)
    }
    var snapshots: [DebrisActorFrame] = []
    if let player = game.commander.flightSimulation.player {
      snapshots.append(
        .init(
          identity: player, bodyID: nil, pose: playerPose,
          velocity: playerVelocity, mesh: game.commander.playerMesh,
          mass: AsteroidImpactPolicy.massKg(hull: .cobra), debris: false, asteroid: false,
          station: nil, hull: .cobra,
          localOrientation: .init(), rotation: 0))
    }
    for body in game.bodies where body.energy > 0 {
      guard let physical = body.physical, physical.identity.system == system,
        physical.identity.visit == visit, physical.ordnance == nil, body.scriptShot == nil
      else { continue }
      let mass = game.asteroidDebrisMassKg(body)
      let mesh: Mesh
      let collisionMass: Double
      if let recorder = game.recordRecoveryCollision(body) {
        mesh = recorder.mesh
        collisionMass = recorder.mass
      } else if let original = game.identifiedSalvageCollision(body) {
        mesh = original.mesh
        collisionMass = original.mass
      } else {
        mesh = game.gameplayMesh(for: body)
        collisionMass = mass ?? AsteroidImpactPolicy.massKg(hull: body.hull)
      }
      let station = game.stationInertialIdentity(for: body)
      let movingStation: Bool
      if let station {
        movingStation = game.commander.nativeStations?.inertia(for: station) != nil
      } else {
        movingStation = false
      }
      snapshots.append(
        .init(
          identity: physical.identity, bodyID: body.id,
          pose: game.modelPose(of: body), velocity: physical.velocity,
          mesh: mesh,
          mass: collisionMass,
          debris: mass != nil || movingStation, asteroid: mass != nil, station: station,
          hull: body.hull, localOrientation: body.orientation,
          rotation: body.rotation))
    }
    actors = snapshots
  }
}

private struct DebrisTrajectory {
  let frame: DebrisActorFrame
  let hull: PreparedHull
  var motion: HullSceneMotion
  let endVelocity: Vector3
}

extension Game {
  @inline(never)
  mutating func beginAsteroidContactStep(delta: Double = 0) -> AsteroidContactFrame? {
    guard !docked else { return nil }
    let start = max(0, commander.flightSimulation.physicalTime - delta)
    let ready = synchronizeNativeStationInertia(at: start)
    let moving = bodies.contains {
      guard let id = stationInertialIdentity(for: $0) else { return false }
      return commander.nativeStations?.inertia(for: id) != nil
    }
    var requiresFrame = moving || !ready
    if !requiresFrame {
      requiresFrame = bodies.contains(where: { asteroidDebrisMassKg($0) != nil })
    }
    if !requiresFrame, commander.scriptState.savedRecordRecoverySource != nil {
      requiresFrame = bodies.contains(where: { recordRecoveryAlias($0) != nil })
    }
    if !requiresFrame, commander.scriptState.savedIdentifiedSalvageSource != nil {
      requiresFrame = bodies.contains(where: { identifiedSalvageAlias($0) != nil })
    }
    guard requiresFrame else { return nil }
    return AsteroidContactFrame(
      game: self, startTime: start, stepDuration: delta, stationReady: ready)
  }

  /// Planning is pure with respect to resources and motion. Unsupported or unproven
  /// contacts retain the complete captured movement; no receipt or damage is invented.
  @inline(never)
  mutating func completeAsteroidContactStep(
    _ frame: AsteroidContactFrame?, delta: Double
  ) -> AsteroidContactStepResult {
    guard let frame else {
      return synchronizeNativeStationInertia(at: commander.flightSimulation.physicalTime)
        ? .advanced(nil) : .refused("STATION COAST UNPROVEN")
    }
    return completeCapturedAsteroidContactStep(frame, delta: delta)
  }

  @inline(never)
  private mutating func completeCapturedAsteroidContactStep(
    _ frame: AsteroidContactFrame, delta: Double
  ) -> AsteroidContactStepResult {
    guard frame.system == systemIdentity, frame.visit == commander.flightSimulation.visit,
      frame.time == commander.flightSimulation.physicalTime, frame.take()
    else { return .refused("STALE STEP") }
    guard delta.isFinite, delta > 0, delta <= 0.1, frame.time >= delta,
      frame.actors.count <= 129
    else { return refuseDebrisStep(frame, reason: "INVALID STEP") }
    guard frame.stationReady,
      synchronizeNativeStationInertia(
        at: commander.flightSimulation.physicalTime,
        advancingFrom: frame.startTime)
    else { return refuseDebrisStep(frame, reason: "STATION COAST UNPROVEN") }
    var trajectories: [DebrisTrajectory] = []
    for actor in frame.actors {
      let end: ShipPose
      let velocity: Vector3
      if let id = actor.bodyID {
        guard
          let body = bodies.first(where: { $0.id == id && $0.physical?.identity == actor.identity }
          ),
          body.energy > 0
        else { return refuseDebrisStep(frame, reason: "ACTOR CHANGED") }
        let currentMesh: Mesh
        if let recorder = recordRecoveryCollision(body) {
          currentMesh = recorder.mesh
        } else if let original = identifiedSalvageCollision(body) {
          currentMesh = original.mesh
        } else {
          currentMesh = gameplayMesh(for: body)
        }
        guard actor.mesh.vertices == currentMesh.vertices,
          actor.mesh.faces == currentMesh.faces
        else { return refuseDebrisStep(frame, reason: "ACTOR CHANGED") }
        end = modelPose(of: body)
        velocity = body.physical?.velocity ?? .init(0, 0, 0)
      } else {
        end = commander.flightSimulation.pose
        velocity = flightWorldVelocity
      }
      guard let hull = preparedWorkHull(mesh: actor.mesh, key: "debris:\(actor.identity.entity)"),
        let motion = debrisRigidMotion(
          from: actor.pose, to: end, duration: delta, radius: hull.radius)
      else { return refuseDebrisStep(frame, reason: "INVALID MOTION") }
      let actual: HullSceneMotion
      if actor.bodyID == nil, let approved = lastAppliedWorkMotion,
        approved.start == actor.pose, approved.end == end, approved.duration == delta
      {
        actual = .init(
          start: approved.start, end: approved.end,
          initialVelocity: approved.initialVelocity, acceleration: approved.acceleration,
          worldAngularVelocity: approved.worldAngularVelocity, duration: delta,
          playerRadius: hull.radius)
      } else {
        actual = motion
      }
      trajectories.append(.init(frame: actor, hull: hull, motion: actual, endVelocity: velocity))
    }
    var selected: (Int, Int, NativeHullContact)?
    var pairs = 0
    for source in trajectories.indices where trajectories[source].frame.debris {
      for target in trajectories.indices where target != source {
        if trajectories[source].frame.station != nil && trajectories[target].frame.asteroid {
          continue
        }
        if trajectories[target].frame.debris && target < source
          && !(trajectories[source].frame.asteroid && trajectories[target].frame.station != nil)
        {
          continue
        }
        guard debrisMayIntersect(trajectories[source], trajectories[target]) else { continue }
        pairs += 1
        guard pairs <= AsteroidImpactPolicy.maximumCandidatePairs else {
          return refuseDebrisStep(frame, reason: "CONTACT CAPACITY")
        }
        let result = HullSweepSafety.firstNativeContact(
          source: trajectories[source].motion, hull: trajectories[source].hull,
          target: trajectories[target].motion, targetHull: trajectories[target].hull)
        switch result {
        case .clear: continue
        case .refused(let failure):
          #if DEBUG
            print(
              "ELITE_CONTACT_OBS phase=initial-pair-refusal source=\(trajectories[source].frame.identity.entity) sourceBody=\(String(describing: trajectories[source].frame.bodyID)) sourceHull=\(trajectories[source].frame.hull) sourceDebris=\(trajectories[source].frame.debris) target=\(trajectories[target].frame.identity.entity) targetBody=\(String(describing: trajectories[target].frame.bodyID)) targetHull=\(trajectories[target].frame.hull) targetDebris=\(trajectories[target].frame.debris) delta=\(delta) relativeVelocity=\(trajectories[source].motion.initialVelocity - trajectories[target].motion.initialVelocity) failure=\(failure)"
            )
          #endif
          return refuseDebrisStep(frame, reason: "SWEEP UNPROVEN: " + failure.message)
        case .contact(let contact):
          if selected == nil || contact.lowerTime < selected!.2.lowerTime {
            selected = (source, target, contact)
          }
        }
      }
    }
    guard let (source, target, contact) = selected else { return .advanced(nil) }
    if let id = trajectories[target].frame.bodyID,
      bodies.first(where: { $0.id == id })?.scriptNPC != nil
    {
      return refuseDebrisStep(frame, reason: "MISSION INERTIA AUTHORITY UNAVAILABLE")
    }
    for index in [source, target] {
      let trajectory = trajectories[index]
      let expected = trajectory.motion.initialVelocity + trajectory.motion.acceleration * delta
      guard (expected - trajectory.endVelocity).length < 1e-5 else {
        return refuseDebrisStep(frame, reason: "NATIVE VELOCITY UNPROVEN")
      }
    }
    guard
      let impulse = AsteroidImpactPolicy.impulse(
        sourceMass: trajectories[source].frame.mass, targetMass: trajectories[target].frame.mass,
        sourceVelocity: trajectories[source].motion.initialVelocity
          + trajectories[source].motion.acceleration * contact.lowerTime,
        targetVelocity: trajectories[target].motion.initialVelocity
          + trajectories[target].motion.acceleration * contact.lowerTime,
        normal: contact.normal)
    else { return refuseDebrisStep(frame, reason: "IMPULSE UNPROVEN") }
    // Do not advance a new post-impact path without proving its entire remaining interval.
    let contactPlayerPose =
      trajectories.first { $0.frame.bodyID == nil }
      .map { debrisPose($0.motion, at: contact.upperTime) } ?? commander.flightSimulation.pose
    let contactSourcePose = debrisPose(trajectories[source].motion, at: contact.upperTime)
    let contactTargetPose = debrisPose(trajectories[target].motion, at: contact.upperTime)
    let remainder = delta - contact.lowerTime
    for index in [source, target] {
      let original = trajectories[index].motion
      let pose = debrisPose(original, at: contact.lowerTime)
      let velocity = index == source ? impulse.source : impulse.target
      let end = debrisAdvancedPose(
        pose, velocity: velocity,
        omega: original.worldAngularVelocity, time: remainder)
      trajectories[index].motion = .init(
        start: pose, end: end, initialVelocity: velocity,
        acceleration: .init(0, 0, 0), worldAngularVelocity: original.worldAngularVelocity,
        duration: remainder, playerRadius: trajectories[index].hull.radius)
    }
    for index in trajectories.indices where index != source && index != target {
      let original = trajectories[index].motion
      let start = debrisPose(original, at: contact.lowerTime)
      trajectories[index].motion = .init(
        start: start, end: original.end,
        initialVelocity: original.initialVelocity + original.acceleration * contact.lowerTime,
        acceleration: original.acceleration,
        worldAngularVelocity: original.worldAngularVelocity, duration: remainder,
        playerRadius: trajectories[index].hull.radius)
    }
    for a in trajectories.indices where trajectories[a].frame.debris {
      for b in trajectories.indices where b != a {
        if trajectories[a].frame.station != nil && trajectories[b].frame.asteroid { continue }
        if trajectories[b].frame.debris && b < a
          && !(trajectories[a].frame.asteroid && trajectories[b].frame.station != nil)
        {
          continue
        }
        guard debrisMayIntersect(trajectories[a], trajectories[b]) else { continue }
        pairs += 1
        guard pairs <= AsteroidImpactPolicy.maximumCandidatePairs else {
          return refuseDebrisStep(frame, reason: "CONTACT CAPACITY")
        }
        let result = HullSweepSafety.firstNativeContact(
          source: trajectories[a].motion,
          hull: trajectories[a].hull, target: trajectories[b].motion,
          targetHull: trajectories[b].hull)
        switch result {
        case .clear: break
        #if DEBUG
          case .contact(let remainingContact):
            print(
              "ELITE_CONTACT_OBS phase=remaining-proved-contact source=\(trajectories[a].frame.identity.entity) sourceBody=\(String(describing: trajectories[a].frame.bodyID)) sourceHull=\(trajectories[a].frame.hull) sourceDebris=\(trajectories[a].frame.debris) target=\(trajectories[b].frame.identity.entity) targetBody=\(String(describing: trajectories[b].frame.bodyID)) targetHull=\(trajectories[b].frame.hull) targetDebris=\(trajectories[b].frame.debris) selectedSource=\(trajectories[source].frame.identity.entity) selectedTarget=\(trajectories[target].frame.identity.entity) selectedLower=\(contact.lowerTime) selectedUpper=\(contact.upperTime) selectedNormal=\(contact.normal) remainingLower=\(remainingContact.lowerTime) remainingUpper=\(remainingContact.upperTime) remainingNormal=\(remainingContact.normal) impulseSourceVelocity=\(impulse.source) impulseTargetVelocity=\(impulse.target) delta=\(delta) capturedSelectedRelativeVelocity=\(trajectories[source].frame.velocity - trajectories[target].frame.velocity) remainingRelativeVelocity=\(trajectories[a].motion.initialVelocity - trajectories[b].motion.initialVelocity)"
            )
            return refuseDebrisStep(frame, reason: "REMAINING CONTACT")
        #else
          case .contact:
            return refuseDebrisStep(frame, reason: "REMAINING CONTACT")
        #endif
        case .refused(let failure):
          #if DEBUG
            print(
              "ELITE_CONTACT_OBS phase=remaining-pair-refusal source=\(trajectories[a].frame.identity.entity) sourceBody=\(String(describing: trajectories[a].frame.bodyID)) sourceHull=\(trajectories[a].frame.hull) sourceDebris=\(trajectories[a].frame.debris) target=\(trajectories[b].frame.identity.entity) targetBody=\(String(describing: trajectories[b].frame.bodyID)) targetHull=\(trajectories[b].frame.hull) targetDebris=\(trajectories[b].frame.debris) selectedSource=\(trajectories[source].frame.identity.entity) selectedTarget=\(trajectories[target].frame.identity.entity) selectedLower=\(contact.lowerTime) selectedUpper=\(contact.upperTime) selectedNormal=\(contact.normal) impulseSourceVelocity=\(impulse.source) impulseTargetVelocity=\(impulse.target) delta=\(delta) capturedSelectedRelativeVelocity=\(trajectories[source].frame.velocity - trajectories[target].frame.velocity) remainingRelativeVelocity=\(trajectories[a].motion.initialVelocity - trajectories[b].motion.initialVelocity) failure=\(failure)"
            )
          #endif
          return refuseDebrisStep(frame, reason: "REMAINING SWEEP UNPROVEN: " + failure.message)
        }
      }
    }
    var stationTransfers: [StationContactTransfer] = []
    for index in [source, target] where trajectories[index].frame.hull == .station {
      let actor = trajectories[index].frame
      guard let station = actor.station, let id = actor.bodyID else {
        return refuseDebrisStep(frame, reason: "STATION IDENTITY UNAVAILABLE")
      }
      stationTransfers.append(
        .init(
          station: station, actor: actor.identity, bodyID: id,
          system: systemIdentity, visit: commander.flightSimulation.visit,
          physicalTime: commander.flightSimulation.physicalTime,
          impactTime: frame.time - delta + contact.lowerTime, previousVelocity: actor.velocity,
          finalPosition: trajectories[index].motion.end.position,
          finalVelocity: index == source ? impulse.source : impulse.target,
          impulse: index == source ? impulse.transferred * -1 : impulse.transferred,
          damage: index == target ? impulse.damage : 0))
    }
    let stationPlan: PreparedStationTransfers?
    if stationTransfers.isEmpty {
      stationPlan = nil
    } else {
      guard let prepared = prepareStationTransfers(stationTransfers) else {
        return refuseDebrisStep(frame, reason: "STATION EFFECT REFUSED")
      }
      stationPlan = prepared
    }
    let simulation = commander.flightSimulation
    guard simulation.nextEmission < UInt64.max - 1, simulation.nextIncident < UInt64.max - 3 else {
      return refuseDebrisStep(frame, reason: "INCIDENT CAPACITY")
    }
    // The synchronous current actor join is checked again immediately before mutation.
    guard let sourceID = trajectories[source].frame.bodyID,
      let sourceBody = bodies.first(where: { $0.id == sourceID }),
      sourceBody.physical?.identity == trajectories[source].frame.identity,
      sourceBody.energy > 0
    else { return refuseDebrisStep(frame, reason: "STALE CONTACT") }
    guard let context = gameplayContext() else {
      return refuseDebrisStep(frame, reason: "CONTEXT UNAVAILABLE")
    }
    let targetIdentity = trajectories[target].frame.identity
    let trialOrigin = AttackOrigin(
      emissionID: simulation.nextEmission,
      owner: trajectories[source].frame.identity, emittedAt: context.physicalTime,
      ownerLegalAtEmission: .init())
    let trial = CombatIncident(
      id: simulation.nextIncident, physicalTime: context.physicalTime,
      origin: trialOrigin, victim: targetIdentity, kind: .collision, outcome: .hit,
      position: contact.point, victimLegalBeforeAttack: nil, firstAggressor: nil,
      victimRole: nil, victimIsStation: false)
    var law = commander.crimeLedger
    guard law.record(trial, context: context).accepted else {
      return refuseDebrisStep(frame, reason: "INCIDENT REFUSED")
    }
    mapDebrisEffectToContact(
      player: contactPlayerPose,
      sourceID: sourceID, source: contactSourcePose,
      targetID: trajectories[target].frame.bodyID, target: contactTargetPose)
    let allocated = makeAttackOrigin(owner: trajectories[source].frame.identity)
    guard let origin = allocated else { return refuseDebrisStep(frame, reason: "INCIDENT REFUSED") }
    let targetActor = trajectories[target].frame
    let targetHit: GameplayHitTarget = targetActor.bodyID.map { .body($0) } ?? .player
    let hit = GameplayHit(
      target: targetHit, distance: 0,
      point: commander.flightSimulation.pose.shipPoint(contact.point))
    // Native collision incidents bypass attack/bounty law but use the ordinary real damage
    // and destruction authorities. No weapon discharge or mission success is synthesized.
    let incident: CombatIncident?
    if trajectories[target].frame.station != nil {
      incident = recordCombat(
        origin: origin, kind: .collision, outcome: .hit,
        target: targetHit, worldPosition: contact.point)
    } else {
      incident = applyCombatHit(hit, origin: origin, kind: .collision, damage: impulse.damage)
    }
    guard let incident else {
      let effectPose = commander.flightSimulation.pose
      commander.flightSimulation = simulation
      commander.flightSimulation.pose = effectPose
      return refuseDebrisStep(frame, reason: "DAMAGE REFUSED")
    }
    stationPlan?.commit(to: &self)
    if trajectories[target].frame.station != nil, let id = targetActor.bodyID,
      let index = bodies.firstIndex(where: { $0.id == id }), bodies[index].energy <= 0
    {
      let death = recordCombat(
        origin: origin, kind: .collision, outcome: .destruction,
        target: targetHit, worldPosition: contact.point)
      bodies[index].physical?.deathOrigin = origin
      bodies[index].physical?.deathIncidentID = death?.id
      bodies[index].destroyedByPlayer = false
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
    commitDebrisMotion(trajectories, source: source, target: target, impulse: impulse)
    persistAsteroidBreakupMotion()
    persistOrePoses()
    return .advanced(
      .init(
        source: trajectories[source].frame.identity, target: targetActor.identity,
        point: contact.point, transferredMomentum: impulse.transferred,
        damage: impulse.damage, incident: incident.id,
        contactPhysicalTime: frame.time - delta + contact.upperTime))
  }

  private mutating func refuseDebrisStep(_ frame: AsteroidContactFrame, reason: String)
    -> AsteroidContactStepResult
  {
    let previous = commander.flightSimulation.pose
    rotateScriptNPCVelocities(from: previous, to: frame.playerPose)
    commander.flightSimulation.pose = frame.playerPose
    for index in bodies.indices {
      let body = bodies[index]
      if let captured = frame.bodyMotion.first(where: {
        $0.id == body.id && $0.identity == body.physical?.identity
      }) {
        bodies[index].position = captured.position
        bodies[index].orientation = captured.orientation
        bodies[index].rotation = captured.rotation
        if let velocity = captured.velocity { bodies[index].physical?.velocity = velocity }
        if let velocity = captured.npcViewVelocity { bodies[index].scriptNPC?.velocity = velocity }
        if let velocity = captured.shotViewVelocity {
          bodies[index].scriptShot?.velocity = velocity
        }
      } else {
        bodies[index].position = frame.playerPose.shipPoint(previous.systemPoint(body.position))
        let world = body.orientation.transformed(by: previous.orientation)
        bodies[index].orientation = world.relative(to: frame.playerPose.orientation)
      }
    }
    autoPilot = frame.pilot
    workGuidance = frame.guidance
    workBraking = frame.braking
    approvedWorkMotion = frame.approved
    lastAppliedWorkMotion = frame.lastApplied
    manualResidualFlight = frame.residual
    workRecoveryRock = frame.recovery
    speed = frame.speed
    celestials = frame.celestials
    var stationRefusals: [StationMotionRefusal] = []
    if frame.stationReady, frame.startTime < frame.time {
      for actor in frame.actors {
        guard let station = actor.station, let bodyID = actor.bodyID else { continue }
        if case .main = station, commander.nativeStations?.inertia(for: station) == nil { continue }
        stationRefusals.append(
          .init(
            station: station, actor: actor.identity, bodyID: bodyID,
            system: frame.system, visit: frame.visit,
            fromTime: frame.startTime, toTime: frame.time, duration: frame.stepDuration,
            position: actor.pose.position, velocity: actor.velocity))
      }
    }
    let retained = retainNativeStationRefusal(stationRefusals)
    paused = true
    notify(
      "DEBRIS CONTACT DEFERRED: " + reason
        + (retained ? "" : " / STATION ROLLBACK UNPROVEN"), voiced: false)
    return .refused(reason)
  }

  /// The normal native damage kernel sees the actually proved impact-time bank/axes.
  /// End-of-step positions must not choose the opposite shield after a fast crossing.
  private mutating func mapDebrisEffectToContact(
    player: ShipPose, sourceID: Int, source: ShipPose, targetID: Int?, target: ShipPose
  ) {
    let previous = commander.flightSimulation.pose
    rotateScriptNPCVelocities(from: previous, to: player)
    for index in bodies.indices {
      let body = bodies[index]
      let pose =
        body.id == sourceID
        ? source
        : body.id == targetID ? target : modelPose(of: body)
      setDebrisBodyPose(at: index, pose: pose, player: player)
    }
    for index in celestials.indices {
      celestials[index].position = player.shipPoint(
        previous.systemPoint(celestials[index].position))
    }
    commander.flightSimulation.pose = player
  }

  private mutating func setDebrisBodyPose(at index: Int, pose: ShipPose, player: ShipPose) {
    bodies[index].position = player.shipPoint(pose.position)
    let relative = pose.orientation.relative(to: player.orientation)
    let rotation = bodies[index].rotation
    var spin = Basis3()
    spin.rotate(pitch: bodies[index].hull == .station ? 0 : rotation * 0.4, roll: rotation, yaw: 0)
    bodies[index].orientation.x = relative.apply(spin.inverse(.init(1, 0, 0)))
    bodies[index].orientation.y = relative.apply(spin.inverse(.init(0, 1, 0)))
    bodies[index].orientation.z = relative.apply(spin.inverse(.init(0, 0, 1)))
  }

  private mutating func commitDebrisMotion(
    _ trajectories: [DebrisTrajectory], source: Int,
    target: Int, impulse: AsteroidImpulse
  ) {
    let previous = commander.flightSimulation.pose
    let player = trajectories.first { $0.frame.bodyID == nil }
    let end = player?.motion.end ?? previous
    rotateScriptNPCVelocities(from: previous, to: end)
    commander.flightSimulation.pose = end
    for index in bodies.indices {
      guard
        let trajectory = trajectories.first(where: {
          $0.frame.bodyID == bodies[index].id
            && $0.frame.identity == bodies[index].physical?.identity
        })
      else {
        bodies[index].position = end.shipPoint(previous.systemPoint(bodies[index].position))
        bodies[index].orientation = bodies[index].orientation.transformed(by: previous.orientation)
          .relative(to: end.orientation)
        continue
      }
      let pose = trajectory.motion.end
      bodies[index].position = end.shipPoint(pose.position)
      let relative = pose.orientation.relative(to: end.orientation)
      let rotation = bodies[index].rotation
      var spin = Basis3()
      spin.rotate(
        pitch: bodies[index].hull == .station ? 0 : rotation * 0.4, roll: rotation, yaw: 0)
      bodies[index].orientation.x = relative.apply(spin.inverse(.init(1, 0, 0)))
      bodies[index].orientation.y = relative.apply(spin.inverse(.init(0, 1, 0)))
      bodies[index].orientation.z = relative.apply(spin.inverse(.init(0, 0, 1)))
      if trajectory.frame.identity == trajectories[source].frame.identity {
        bodies[index].physical?.velocity = impulse.source
      } else if trajectory.frame.identity == trajectories[target].frame.identity {
        bodies[index].physical?.velocity = impulse.target
      }
    }
    for index in celestials.indices {
      celestials[index].position = end.shipPoint(previous.systemPoint(celestials[index].position))
    }
    if trajectories[target].frame.bodyID == nil {
      cancelAutoTarget()
      workGuidance = nil
      workBraking = nil
      approvedWorkMotion = nil
      speed = 0
      manualResidualFlight = true
      autoPilot.setApproachVelocity(end.shipVector(impulse.target))
    }
  }
}

private func debrisRigidMotion(
  from start: ShipPose, to end: ShipPose, duration: Double,
  radius: Double
) -> HullSceneMotion? {
  guard start.orientation.validRotation, end.orientation.validRotation,
    start.position.finite, end.position.finite, duration.isFinite, duration > 0
  else { return nil }
  let a = start.orientation
  let b = end.orientation
  var relative = Basis3()
  relative.x = b.apply(a.inverse(.init(1, 0, 0)))
  relative.y = b.apply(a.inverse(.init(0, 1, 0)))
  relative.z = b.apply(a.inverse(.init(0, 0, 1)))
  let angle = acos(max(-1, min(1, (relative.x.x + relative.y.y + relative.z.z - 1) * 0.5)))
  guard angle.isFinite, angle < 1 else { return nil }
  let skew = Vector3(
    relative.y.z - relative.z.y, relative.z.x - relative.x.z,
    relative.x.y - relative.y.x)
  let omega =
    angle < 1e-7
    ? skew * (0.5 / duration)
    : skew * (angle / (2 * sin(angle) * duration))
  return .init(
    start: start, end: end, initialVelocity: (end.position - start.position) * (1 / duration),
    acceleration: .init(0, 0, 0), worldAngularVelocity: omega, duration: duration,
    playerRadius: radius)
}

private func debrisPose(_ motion: HullSceneMotion, at time: Double) -> ShipPose {
  var pose = debrisAdvancedPose(
    motion.start, velocity: motion.initialVelocity,
    omega: motion.worldAngularVelocity, time: time)
  pose.position = pose.position + motion.acceleration * (0.5 * time * time)
  return pose
}

private func debrisAdvancedPose(
  _ start: ShipPose, velocity: Vector3, omega: Vector3,
  time: Double
) -> ShipPose {
  var pose = start
  pose.position = start.position + velocity * time
  if omega.length > 1e-12 {
    let axis = omega * (1 / omega.length)
    let angle = omega.length * time
    func rotated(_ value: Vector3) -> Vector3 {
      value * cos(angle) + axis.cross(value) * sin(angle)
        + axis * (axis.dot(value) * (1 - cos(angle)))
    }
    pose.orientation.x = rotated(start.orientation.x)
    pose.orientation.y = rotated(start.orientation.y)
    pose.orientation.z = rotated(start.orientation.z)
  }
  return pose
}

private func debrisMayIntersect(_ a: DebrisTrajectory, _ b: DebrisTrajectory) -> Bool {
  let start = a.motion.start.position - b.motion.start.position
  let end = a.motion.end.position - b.motion.end.position
  let travel = end - start
  let t = travel.dot(travel) > 0 ? max(0, min(1, -start.dot(travel) / travel.dot(travel))) : 0
  let gap = (start + travel * t).length
  let curve =
    (a.motion.acceleration - b.motion.acceleration).length
    * a.motion.duration * a.motion.duration / 8
  return !gap.isFinite || !curve.isFinite || gap <= a.hull.radius + b.hull.radius + curve + 1e-6
}
