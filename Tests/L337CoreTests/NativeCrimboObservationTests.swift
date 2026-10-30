import Foundation
import Testing

@testable import L337Core

enum MetricSteering: CaseIterable, Equatable, Sendable {
  case straight, pitch, yaw, roll, combined
  var controls: Controls {
    var result = Controls()
    switch self {
    case .straight: break
    case .pitch: result.pitch = 0.3
    case .yaw: result.yaw = -0.2
    case .roll: result.roll = 0.4
    case .combined:
      result.pitch = 0.3
      result.yaw = -0.2
      result.roll = 0.4
    }
    return result
  }
}

enum MetricCurrentTamper: CaseIterable, Sendable {
  case epoch, frame, clock, visit, playerPose, playerVelocity, subjectPose, subjectVelocity
  case duplicateBody, originalBinding, manifest, missingIdentity, missingTrajectory, paused, gate
  case trajectoryEndpoint, world
}

enum MetricBaselineTamper: CaseIterable, Sendable {
  case duplicate, olderFrameWithSameTime, future, epoch, scene
}

private enum MetricFixture {
  static func game() throws -> Game {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let count = CrimboFixture.convoyBodies(game).count
    try #require(count == 7)
    game.speed = 3
    return game
  }

  static func projection(_ game: Game, after baseline: ProviderMissionBaseline? = nil) throws
    -> NativeCrimboMetricProjection
  {
    let fact = try #require(game.nativeCrimboAttainedMotion)
    let projected = NativeCrimboMetricProjection.project(
      fact, in: game, expectedMetricRevision: NativeCrimboMetric.revision, after: baseline)
    return try #require(projected)
  }
}

struct NativeCrimboObservationTests {
  @Test(arguments: MetricSteering.allCases)
  func actualActorMotionUsesOneLocalMetricIncludingTurning(steering: MetricSteering) async throws {
    let game = try MetricFixture.game()
    let runtime = GameRuntime(game: game)
    await runtime.setControls(steering.controls)
    let frame = await runtime.advance(delta: 0.01)
    let fact = try #require(frame.nativeCrimboAttainedMotion)
    let projection = try MetricFixture.projection(frame)
    let trajectory = try #require(fact.playerTrajectory)
    guard case .nativeStep(let step) = trajectory else {
      Issue.record("Ordinary native controls must retain the native one-step trajectory.")
      return
    }
    #expect(step.end == fact.playerEnd)
    #expect(projection.metricRevision == "native-flight-metres-v1")
    #expect(NativeCrimboMetric.metresPerWorldUnit == 1)
    #expect(projection.forwardMeters == fact.tangentialDisplacementWorldUnits)
    #expect(projection.forwardMeters > 0)
    #expect(projection.elapsedSeconds == fact.endTime - fact.startTime)
    let startRange = (fact.subjectStart.position - fact.playerStart.position).length
    let endRange = (fact.subjectEnd.position - fact.playerEnd.position).length
    let actualSpeed = max(
      (fact.subjectStartVelocity - step.velocity).length,
      (fact.subjectStartVelocity - fact.playerStartVelocity).length)
    #expect(projection.maximumRangeMeters >= max(startRange, endRange))
    #expect(projection.maximumRangeMeters - max(startRange, endRange) < 1e-5)
    #expect(projection.maximumRelativeMetersPerSecond >= actualSpeed)
    #expect(projection.maximumRelativeMetersPerSecond - actualSpeed < 1e-4)
    if steering != .straight {
      #expect(fact.playerStart.orientation != fact.playerEnd.orientation)
    }
    let original = try #require(frame.commander.savedCrimboState)
    #expect(projection.manifest == original.manifest)
    #expect(projection.player == frame.commander.flightSimulation.player)
    #expect(projection.world == original.world)
    #expect(projection.sceneGeneration == original.orbit.anchor.identity)
  }

  @Test func actualTickAndClampedActorStepPreservePhysicalSecondsAndAttainedDistance() async throws
  {
    var direct = try MetricFixture.game()
    let start = direct.commander.flightSimulation.physicalTime
    let player = direct.commander.flightSimulation.player
    direct.tick(delta: 0.01, controls: MetricSteering.combined.controls)
    direct.observeNativeCrimboAttainedMotion(
      delta: 0.01, flightWasActive: true, startTime: start, startPlayer: player,
      stationEntryAttempted: false)
    let directProjection = try MetricFixture.projection(direct)
    #expect(abs(directProjection.elapsedSeconds - 0.01) < 1e-10)
    let runtime = GameRuntime(game: try MetricFixture.game())
    let frame = await runtime.advance(delta: 1.5)
    let fact = try #require(frame.nativeCrimboAttainedMotion)
    let projection = try MetricFixture.projection(frame)
    #expect(abs(projection.elapsedSeconds - 0.1) < 1e-10)
    #expect(projection.forwardMeters == fact.tangentialDisplacementWorldUnits)
    #expect(projection.forwardMeters < fact.subjectStartVelocity.length * 0.101)
  }

  @Test func adoptedNativeWorkMotionBoundsTheWholeQuadraticStep() async throws {
    var game = try MetricFixture.game()
    game.workBraking = .init(velocity: .init(25, 2, 8), angularVelocity: .init(0, 0, 0))
    let runtime = GameRuntime(game: game)
    let frame = await runtime.advance(delta: 0.1)
    let fact = try #require(frame.nativeCrimboAttainedMotion)
    let adopted = try #require(frame.lastAppliedWorkMotion)
    let trajectory = try #require(fact.playerTrajectory)
    #expect(trajectory == .acceptedWork(adopted))
    #expect(adopted.acceleration.length > 0)
    let projection = try MetricFixture.projection(frame)
    for index in 0...100 {
      let t = projection.elapsedSeconds * Double(index) / 100
      let subject = fact.subjectStart.position + fact.subjectStartVelocity * t
      let player =
        adopted.start.position + adopted.initialVelocity * t
        + adopted.acceleration * (0.5 * t * t)
      let speed = (fact.subjectStartVelocity - adopted.initialVelocity - adopted.acceleration * t)
        .length
      #expect((subject - player).length <= projection.maximumRangeMeters)
      #expect(speed <= projection.maximumRelativeMetersPerSecond)
    }
  }

  @Test func missingAdoptedWorkAuthorityRejectsEndpointsFromAnActualTick() throws {
    var game = try MetricFixture.game()
    game.workBraking = .init(velocity: .init(25, 2, 8), angularVelocity: .init(0, 0, 0))
    let start = game.commander.flightSimulation.physicalTime
    let player = game.commander.flightSimulation.player
    game.tick(delta: 0.1)
    _ = try #require(game.lastAppliedWorkMotion)
    // Boundary refusal probe: genuine endpoints cannot replace the lost integration authority.
    game.lastAppliedWorkMotion = nil
    game.observeNativeCrimboAttainedMotion(
      delta: 0.1, flightWasActive: true, startTime: start, startPlayer: player,
      stationEntryAttempted: false)
    let fact = try #require(game.nativeCrimboAttainedMotion)
    #expect(fact.playerTrajectory == nil)
    let projection = NativeCrimboMetricProjection.project(
      fact, in: game, expectedMetricRevision: NativeCrimboMetric.revision)
    #expect(projection == nil)
  }

  @Test(arguments: MetricCurrentTamper.allCases)
  func currentOriginalAndRetainedFactMustStillAuthenticate(tamper: MetricCurrentTamper) async throws
  {
    let runtime = GameRuntime(game: try MetricFixture.game())
    var game = await runtime.advance(delta: 0.01)
    let projection = try MetricFixture.projection(game)
    let fact = try #require(game.nativeCrimboAttainedMotion)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == fact.actor })
    switch tamper {
    case .epoch: game.nativeStationRuntimeEpoch = UUID()
    case .frame: game.gameplayRevision += 1
    case .clock: game.commander.flightSimulation.advancePhysicalTime(0.01)
    case .visit: game.commander.flightSimulation.enter(CrimboFixture.system, arriving: true)
    case .playerPose: game.commander.flightSimulation.pose.position.x += 1
    case .playerVelocity: game.speed += 1
    case .subjectPose: game.bodies[index].position.x += 1
    case .subjectVelocity: game.bodies[index].physical?.velocity.x += 1
    case .duplicateBody: game.bodies.append(game.bodies[index])
    case .originalBinding: game.commander.savedCrimboState?.members[6].ownership = .pending
    case .manifest:
      let old = try #require(fact.observationIdentity)
      game.nativeCrimboAttainedMotion?.observationIdentity = .init(
        world: old.world,
        manifest: .init(
          identity: UUID(), revision: 1, provider: fact.provider, subject: fact.member),
        player: old.player, sceneGeneration: old.sceneGeneration, logical: old.logical)
    case .missingIdentity: game.nativeCrimboAttainedMotion?.observationIdentity = nil
    case .missingTrajectory: game.nativeCrimboAttainedMotion?.playerTrajectory = nil
    case .trajectoryEndpoint:
      let trajectory = try #require(fact.playerTrajectory)
      var altered = fact.playerEnd
      altered.position.x += 1
      game.nativeCrimboAttainedMotion?.playerTrajectory = .nativeStep(
        .init(end: altered, velocity: trajectory.initialVelocity))
    case .world:
      let old = try #require(fact.observationIdentity)
      game.nativeCrimboAttainedMotion?.observationIdentity = .init(
        world: UUID(), manifest: old.manifest, player: old.player,
        sceneGeneration: old.sceneGeneration, logical: old.logical)
    case .paused: game.paused = true
    case .gate: game.nativeCrimboLifecycleAvailable = false
    }
    let current = projection.isCurrent(
      in: game, expectedMetricRevision: NativeCrimboMetric.revision,
      after: nil)
    #expect(!current)
    let retained = try #require(game.nativeCrimboAttainedMotion)
    let fresh = NativeCrimboMetricProjection.project(
      retained, in: game, expectedMetricRevision: NativeCrimboMetric.revision)
    #expect(fresh == nil)
  }

  @Test(arguments: MetricBaselineTamper.allCases)
  func duplicateReplayAndCrossSceneBaselinesReject(tamper: MetricBaselineTamper) async throws {
    let runtime = GameRuntime(game: try MetricFixture.game())
    let first = await runtime.advance(delta: 0.01)
    let previous = try MetricFixture.projection(first)
    let frame = await runtime.advance(delta: 0.01)
    let projection = try MetricFixture.projection(frame, after: previous.nextBaseline)
    let end = projection.nextBaseline
    let baseline: ProviderMissionBaseline
    switch tamper {
    case .duplicate: baseline = end
    case .olderFrameWithSameTime:
      baseline = .init(
        runtimeEpoch: end.runtimeEpoch, sceneGeneration: end.sceneGeneration,
        frame: end.frame - 1, time: end.time)
    case .future:
      baseline = .init(
        runtimeEpoch: end.runtimeEpoch, sceneGeneration: end.sceneGeneration,
        frame: end.frame + 1, time: end.time + 0.01)
    case .epoch:
      baseline = .init(
        runtimeEpoch: UUID(), sceneGeneration: end.sceneGeneration,
        frame: end.frame - 1, time: previous.nextBaseline.time)
    case .scene:
      baseline = .init(
        runtimeEpoch: end.runtimeEpoch, sceneGeneration: UUID(),
        frame: end.frame - 1, time: previous.nextBaseline.time)
    }
    let accepted = projection.isCurrent(
      in: frame, expectedMetricRevision: NativeCrimboMetric.revision,
      after: baseline)
    #expect(!accepted)
    let stale = previous.isCurrent(
      in: frame, expectedMetricRevision: NativeCrimboMetric.revision,
      after: nil)
    #expect(!stale)
  }

  @Test func missingOrDifferentMetricRevisionNeverReinterpretsSavedMetres() async throws {
    var game = try MetricFixture.game()
    let registry = try #require(game.commander.savedCrimboState)
    game.commander.savedCrimboState?.destination = registry.origin
    let runtime = GameRuntime(game: game)
    var frame = await runtime.advance(delta: 0.01)
    let fact = try #require(frame.nativeCrimboAttainedMotion)
    // Pure retained-storage fixture, not native admission or versioned-save acceptance.
    var state = ProviderContractFixture.state()
    state.progress = .init(
      requested: true, handshakeSeconds: 5, distanceMeters: 12000, escortSeconds: 45,
      checkpointBits: 3)
    var instance = ScriptInstance(
      id: state.instance, definition: "project.crimbo/guiding-light", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.savedProviderContract = state
    instance.payloads[state.terms.payload] = 1
    let valid = state.valid(instance: instance)
    try #require(valid)
    frame.commander.scriptState.instances[instance.id] = instance
    let beforeCommander = frame.commander
    let beforeInstance = try #require(frame.commander.scriptState.instances[instance.id])
    let beforeContract = try #require(beforeInstance.savedProviderContract)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let beforeInstanceBytes = try encoder.encode(beforeInstance)
    let beforeProgressBytes = try encoder.encode(beforeContract.progress)
    let revisions: [String?] = [nil, "", "historical-metres", "native-flight-metres-v2"]
    for revision in revisions {
      let projection = NativeCrimboMetricProjection.project(
        fact, in: frame, expectedMetricRevision: revision)
      #expect(projection == nil)
    }
    let projection = try MetricFixture.projection(frame)
    #expect(projection.missionInterval == nil)
    #expect(projection.missingMissionAuthorities.count == 5)
    #expect(projection.missingMissionAuthorities.contains(.sensorContact))
    #expect(projection.missingMissionAuthorities.contains(.communications))
    #expect(projection.missingMissionAuthorities.contains(.livingCrew))
    #expect(projection.missingMissionAuthorities.contains(.trackingThroughout))
    #expect(projection.missingMissionAuthorities.contains(.savedMetricRevision))
    let afterInstance = try #require(frame.commander.scriptState.instances[instance.id])
    let afterContract = try #require(afterInstance.savedProviderContract)
    let afterInstanceBytes = try encoder.encode(afterInstance)
    let afterProgressBytes = try encoder.encode(afterContract.progress)
    #expect(beforeInstanceBytes == afterInstanceBytes)
    #expect(beforeProgressBytes == afterProgressBytes)
    #expect(beforeContract.progress.distanceMeters == 12000)
    #expect(beforeContract.progress == afterContract.progress)
    #expect(frame.commander == beforeCommander)
    let terms = ProviderContractFixture.terms.observation
    #expect(terms.contactRange == 5000 && terms.contactSpeed == 100 && terms.contactSeconds == 5)
    #expect(terms.checkpoints == [6000, 12000, 18000])
    #expect(terms.escortRange == 8000 && terms.escortSeconds == 60)
    let observed = try frame.nativeProviderMissionFacts(instance: nil)
    let facts = try #require(observed)
    #expect(facts.source.operationsReady.isEmpty)
    #expect(!facts.source.routeAvailable && facts.source.interval == nil)
    let defaultGame = Game(executive: false)
    #expect(!defaultGame.nativeCrimboLifecycleAvailable)
  }

  @Test func actualNoTickAdvanceInvalidatesThePreviouslyRetainedProjection() async throws {
    let runtime = GameRuntime(game: try MetricFixture.game())
    let first = await runtime.advance(delta: 0.01)
    let projection = try MetricFixture.projection(first)
    let stopped = await runtime.advance(delta: 0)
    let current = projection.isCurrent(
      in: stopped, expectedMetricRevision: NativeCrimboMetric.revision, after: nil)
    #expect(!current)
    #expect(stopped.nativeCrimboAttainedMotion == nil)
    #expect(stopped.commander.flightSimulation == first.commander.flightSimulation)
  }
}
