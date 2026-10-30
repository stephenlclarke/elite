import Foundation

/// New project-local game metric, not a recovered historical, SI or astronomical scale.
enum NativeCrimboMetric {
  static let revision = "native-flight-metres-v1"
  static let metresPerWorldUnit = 1.0
}

struct NativeCrimboObservationIdentity: Equatable, Sendable {
  let world: UUID
  let manifest: NativeProviderManifest
  let player: ActorIdentity
  let sceneGeneration: UUID
  let logical: NPCLogicalIdentity
}

/// Transient provenance from the native rotate-once/translate-once integrator.
struct NativeCrimboNormalPlayerStep: Equatable, Sendable {
  let end: ShipPose
  let velocity: Vector3
}

enum NativeCrimboPlayerTrajectory: Equatable, Sendable {
  case nativeStep(NativeCrimboNormalPlayerStep)
  case acceptedWork(HullSceneMotion)

  var initialVelocity: Vector3 {
    switch self {
    case .nativeStep(let step): step.velocity
    case .acceptedWork(let motion): motion.initialVelocity
    }
  }
  var acceleration: Vector3 {
    switch self {
    case .nativeStep: .init(0, 0, 0)
    case .acceptedWork(let motion): motion.acceleration
    }
  }
}

extension Game {
  /// Same positional model as moveBodies: rotate the view once, then translate once.
  /// A final endpoint check is required; this prediction alone never proves attainment.
  func nativeCrimboNormalPlayerStep(delta: Double) -> NativeCrimboNormalPlayerStep? {
    guard workGuidance == nil, workBraking == nil, workRecoveryRock == nil else { return nil }
    var pilot = autoPilot
    pilot.rotateVelocity(pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    var end = commander.flightSimulation.pose
    let translation = pilot.velocity * delta + Vector3(0, 0, speed * delta * 18)
    end.advanceView(
      pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta,
      translation: translation)
    return .init(
      end: end, velocity: end.orientation.apply(pilot.velocity + .init(0, 0, speed * 18)))
  }

  func nativeCrimboPlayerTrajectory(sample: NativeCrimboMotionSample)
    -> NativeCrimboPlayerTrajectory?
  {
    let end = commander.flightSimulation.pose
    let duration = sample.endTime - sample.startTime
    guard duration.isFinite, duration > 0, duration <= 0.100001 else { return nil }
    if let motion = lastAppliedWorkMotion {
      guard motion.start == sample.player, motion.end == end,
        abs(motion.duration - duration) <= 1e-8,
        motion.initialVelocity == sample.playerVelocity,
        motion.initialVelocity.finite, motion.acceleration.finite,
        motion.worldAngularVelocity.finite,
        NativeCrimboMetricProjection.close(
          end.position - motion.start.position,
          motion.initialVelocity * duration + motion.acceleration * (0.5 * duration * duration)),
        NativeCrimboMetricProjection.close(
          flightWorldVelocity, motion.initialVelocity + motion.acceleration * duration)
      else { return nil }
      return .acceptedWork(motion)
    }
    guard workGuidance == nil, workBraking == nil, let step = sample.normalPlayerStep,
      step.end == end, step.velocity.finite,
      NativeCrimboMetricProjection.close(flightWorldVelocity, step.velocity)
    else { return nil }
    return .nativeStep(step)
  }
}

/// Numeric evidence only. No contact/communications/crew/tracking interval authority exists yet.
/// The private initializer prevents callers constructing a projection from synthetic measurements.
struct NativeCrimboMetricProjection: Equatable, Sendable {
  let metricRevision: String
  let manifest: NativeProviderManifest
  let world: UUID
  let player: ActorIdentity
  let sceneGeneration: UUID
  let forwardMeters: Double
  let maximumRangeMeters: Double
  let maximumRelativeMetersPerSecond: Double
  let elapsedSeconds: Double
  private let fact: NativeCrimboAttainedMotion

  var nextBaseline: ProviderMissionBaseline {
    .init(
      runtimeEpoch: fact.runtimeEpoch, sceneGeneration: sceneGeneration,
      frame: fact.frame, time: fact.endTime)
  }

  enum MissingMissionAuthority: CaseIterable, Equatable, Sendable {
    case sensorContact, communications, livingCrew, trackingThroughout, savedMetricRevision
  }
  var missingMissionAuthorities: [MissingMissionAuthority] { MissingMissionAuthority.allCases }
  var missionInterval: ProviderMissionInterval? { nil }

  private init(
    fact: NativeCrimboAttainedMotion, manifest: NativeProviderManifest, world: UUID,
    player: ActorIdentity, sceneGeneration: UUID, range: Double, speed: Double
  ) {
    self.fact = fact
    self.manifest = manifest
    self.world = world
    self.player = player
    self.sceneGeneration = sceneGeneration
    metricRevision = NativeCrimboMetric.revision
    forwardMeters = fact.tangentialDisplacementWorldUnits * NativeCrimboMetric.metresPerWorldUnit
    maximumRangeMeters = range * NativeCrimboMetric.metresPerWorldUnit
    maximumRelativeMetersPerSecond = speed * NativeCrimboMetric.metresPerWorldUnit
    elapsedSeconds = fact.endTime - fact.startTime
  }

  /// Recheck immediately before any future fold, against its current persisted baseline.
  /// Reading a projection is repeatable; it never mutates progress or authorizes a mission fold.
  func isCurrent(
    in game: Game, expectedMetricRevision: String?, after baseline: ProviderMissionBaseline?
  )
    -> Bool
  {
    Self.project(fact, in: game, expectedMetricRevision: expectedMetricRevision, after: baseline)
      == self
  }

  static func project(
    _ fact: NativeCrimboAttainedMotion, in game: Game, expectedMetricRevision: String?,
    after baseline: ProviderMissionBaseline? = nil
  ) -> Self? {
    guard expectedMetricRevision == NativeCrimboMetric.revision,
      game.nativeCrimboAttainedMotion == fact,
      game.nativeCrimboLifecycleAvailable, !game.paused, !game.docked, game.screen != .gameOver,
      game.energy.isFinite, game.energy > 0,
      game.pendingNativeStationDock == nil,
      fact.runtimeEpoch == game.nativeStationRuntimeEpoch, fact.frame == game.gameplayRevision,
      fact.frame > 0, fact.frame < UInt64(Int64.max),
      fact.stationImpactRevision == game.stationImpactRevision,
      game.stationImpactRevision != fact.frame,
      let registry = game.commander.savedCrimboState,
      registry.world == game.commander.equipmentOwnerID,
      registry.spawnSequence < game.commander.flightSimulation.nextSpawn,
      (try? registry.validate()) != nil, registry.threat == nil,
      registry.provider == fact.provider, registry.members[6].identity == fact.member,
      registry.manifest.provider == fact.provider, registry.manifest.subject == fact.member,
      case .live(let logical) = registry.members[6].ownership,
      let identity = fact.observationIdentity, identity.world == registry.world,
      identity.manifest == registry.manifest, identity.logical == logical,
      identity.sceneGeneration == registry.orbit.anchor.identity,
      registry.binding(of: registry.members[6], ledger: game.commander.npcPersistence)
        == fact.actor,
      game.commander.npcPersistence.logicalIdentity(for: fact.actor) == logical.firstActor,
      let context = game.gameplayContext(), context.system == NativeCrimboRegistry.system,
      context.visit == fact.visit, fact.actor.visit == fact.visit,
      context.physicalTime == fact.endTime,
      context.player.identity == game.commander.flightSimulation.player,
      context.player.identity == identity.player,
      game.commander.flightSimulation.pose == fact.playerEnd,
      context.player.velocity == fact.playerEndVelocity,
      let actor = context.actors.first(where: { $0.identity == fact.actor }), actor.energy > 0,
      actor.position == fact.subjectEnd.position, actor.orientation == fact.subjectEnd.orientation,
      actor.velocity == fact.subjectEndVelocity,
      game.bodies.filter({ $0.physical?.identity == fact.actor }).count == 1,
      let body = game.bodies.first(where: { $0.physical?.identity == fact.actor }),
      !game.isEMPDisabled(body), body.missionActorID == nil, body.missionInstanceID == nil,
      body.scriptNPC == nil,
      let snapshot = NPCPersistenceSnapshot.capture(
        body: body, pose: game.commander.flightSimulation.pose,
        physicalTime: context.physicalTime, protection: context.protection),
      NativeCrimboRegistry.matches(snapshot, member: registry.members[6]),
      authenticTangentialDisplacement(fact, registry: registry),
      let bounds = bounds(fact)
    else { return nil }
    let scene = registry.orbit.anchor.identity
    if let baseline {
      // Epoch/scene changes require a new native baseline; they cannot replay an old projection.
      guard baseline.runtimeEpoch == fact.runtimeEpoch, baseline.sceneGeneration == scene,
        baseline.frame < fact.frame, baseline.time < fact.endTime,
        baseline.frame > 0, baseline.time.isFinite, baseline.time >= 0
      else { return nil }
    }
    return .init(
      fact: fact, manifest: registry.manifest, world: registry.world,
      player: context.player.identity, sceneGeneration: scene,
      range: bounds.range, speed: bounds.speed)
  }

  private static func authenticTangentialDisplacement(
    _ fact: NativeCrimboAttainedMotion, registry: NativeCrimboRegistry
  ) -> Bool {
    let radial = (fact.subjectStart.position - registry.orbit.anchor.center).unit
    let tangent =
      registry.orbit.anchor.basis.z.cross(radial)
      * Double(registry.orbit.configuration.direction.rawValue)
    let actual = (fact.subjectEnd.position - fact.subjectStart.position).dot(tangent)
    return actual.isFinite && fact.tangentialDisplacementWorldUnits == actual
  }

  /// For a quadratic path, distance from its endpoint chord is at most |a| * dt^2 / 8.
  /// Relative velocity is affine, whose norm is bounded by its endpoint norms.
  private static func bounds(_ fact: NativeCrimboAttainedMotion) -> (range: Double, speed: Double)?
  {
    let duration = fact.endTime - fact.startTime
    guard fact.startTime.isFinite, fact.startTime >= 0, duration.isFinite,
      duration > 0, duration <= 0.100001,
      fact.tangentialDisplacementWorldUnits.isFinite, let trajectory = fact.playerTrajectory,
      trajectoryMatches(trajectory, fact: fact),
      fact.subjectStart.position.finite, fact.subjectEnd.position.finite,
      fact.playerStart.position.finite, fact.playerEnd.position.finite,
      fact.subjectStartVelocity.finite, fact.subjectEndVelocity.finite,
      fact.playerStartVelocity.finite,
      trajectory.initialVelocity.finite, trajectory.acceleration.finite,
      fact.subjectStartVelocity == fact.subjectEndVelocity,
      close(
        fact.subjectEnd.position - fact.subjectStart.position, fact.subjectStartVelocity * duration),
      close(
        fact.playerEnd.position - fact.playerStart.position,
        trajectory.initialVelocity * duration + trajectory.acceleration
          * (0.5 * duration * duration)),
      close(fact.playerEndVelocity, trajectory.initialVelocity + trajectory.acceleration * duration)
    else { return nil }
    let start = fact.subjectStart.position - fact.playerStart.position
    let end = fact.subjectEnd.position - fact.playerEnd.position
    let initialVelocity = fact.subjectStartVelocity - trajectory.initialVelocity
    let endVelocity = fact.subjectEndVelocity - fact.playerEndVelocity
    // Include the sampled pre-turn boundary velocity as well as the applied native-step velocity.
    let sampledStartSpeed = (fact.subjectStartVelocity - fact.playerStartVelocity).length
    let tolerance =
      1e-8
      * max(
        1,
        max(
          (end - start).length,
          (fact.playerEnd.position - fact.playerStart.position).length))
    let range =
      max(start.length, end.length) + trajectory.acceleration.length * duration * duration / 8
      + 2 * tolerance
    let speed =
      max(sampledStartSpeed, max(initialVelocity.length, endVelocity.length))
      + 2 * tolerance / duration
    guard range.isFinite, speed.isFinite else { return nil }
    return (range, speed)
  }

  private static func trajectoryMatches(
    _ trajectory: NativeCrimboPlayerTrajectory, fact: NativeCrimboAttainedMotion
  ) -> Bool {
    switch trajectory {
    case .nativeStep(let step):
      return step.end == fact.playerEnd
    case .acceptedWork(let motion):
      return motion.start == fact.playerStart && motion.end == fact.playerEnd
        && motion.initialVelocity == fact.playerStartVelocity
        && motion.duration.isFinite
        && abs(motion.duration - (fact.endTime - fact.startTime)) <= 1e-8
        && motion.worldAngularVelocity.finite
    }
  }

  fileprivate static func close(_ actual: Vector3, _ expected: Vector3) -> Bool {
    actual.finite && expected.finite && (actual - expected).length <= 1e-8 * max(1, expected.length)
  }
}
