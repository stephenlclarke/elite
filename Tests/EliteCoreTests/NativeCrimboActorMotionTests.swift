import Foundation
import Testing

@testable import EliteCore

enum NativeCrimboActorMotionRefusal: CaseIterable, Equatable, Sendable {
  case paused, docked, disabledGate, gameOver, help
}
enum NativeCrimboActorMotionTamper: CaseIterable, Sendable {
  case teleport, staleEpoch, stalePlayer, staleStart, contactMarker
}

private enum ActorMotionFixture {
  static func game() throws -> Game {
    var game = try CrimboFixture.game()
    game.advanceNativeCrimbo(delta: 0.1)
    let count = CrimboFixture.convoyBodies(game).count
    try #require(count == 7)
    return game
  }

  static func stationGame() throws -> Game {
    var game = Game(executive: false)
    game.commander.galaxy = 7
    game.commander.system = 8
    game.systems = Universe.systemsIncludingPlugh(number: 7)
    game.launch()
    try #require(!game.docked)
    let owner = try #require(game.commander.equipmentOwnerID)
    let allocation = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocation)
    // Explicit test boundary injection; G1 exclusively owns production readiness activation.
    game.nativeCrimboLifecycleAvailable = true
    game.commander.savedCrimboState = try CrimboFixture.registry(owner: owner, sequence: sequence)
    // Advance the actual scene so rotating station models share the physical clock's phase.
    game.tick(delta: 0.1)
    let count = CrimboFixture.convoyBodies(game).count
    try #require(count == 7)
    return game
  }

  /// Reintroduce actual actor-observed data solely to test rejection of a tampered callback input.
  static func sample(from fact: NativeCrimboAttainedMotion, in game: Game) throws
    -> NativeCrimboMotionSample
  {
    let registry = try #require(game.commander.savedCrimboState)
    let radial = (fact.subjectStart.position - registry.orbit.anchor.center).unit
    let tangent =
      registry.orbit.anchor.basis.z.cross(radial)
      * Double(registry.orbit.configuration.direction.rawValue)
    return .init(
      provider: fact.provider, member: fact.member, actor: fact.actor,
      runtimeEpoch: fact.runtimeEpoch, frame: fact.frame,
      stationImpactRevision: fact.stationImpactRevision,
      startTime: fact.startTime, endTime: fact.endTime, subject: fact.subjectStart,
      player: fact.playerStart, subjectVelocity: fact.subjectStartVelocity,
      playerVelocity: fact.playerStartVelocity, tangent: tangent)
  }
}

struct NativeCrimboActorMotionTests {
  @Test(arguments: [
    Screen.front, .rear, .left, .right, .status, .chart, .shortChart, .system, .inventory,
  ])
  func actualActorStepProducesOneWorldFactAcrossPhysicalSimulationViews(screen: Screen) async throws
  {
    var game = try ActorMotionFixture.game()
    game.screen = screen
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let frame = await runtime.advance(delta: 0.01)
    let observed = frame.nativeCrimboAttainedMotion
    let fact = try #require(observed)
    let actual = fact.subjectEnd.position - fact.subjectStart.position
    let elapsed = fact.endTime - fact.startTime
    #expect((actual - fact.subjectStartVelocity * elapsed).length < 1e-8)
    #expect(fact.tangentialDisplacementWorldUnits > 0)
    #expect(fact.startTime == before.commander.flightSimulation.physicalTime)
    #expect(fact.endTime == frame.commander.flightSimulation.physicalTime)
    #expect(
      fact.runtimeEpoch == frame.nativeStationRuntimeEpoch && fact.frame == frame.gameplayRevision)
    #expect(frame.nativeCrimboMotionSample == nil)
    let body = try #require(frame.bodies.first { $0.physical?.identity == fact.actor })
    let world = frame.commander.flightSimulation.pose.systemPoint(body.position)
    #expect((world - fact.subjectEnd.position).length < 1e-8)
    let read = await runtime.snapshot()
    #expect(read.nativeCrimboAttainedMotion == fact)
    #expect(read.commander.flightSimulation == frame.commander.flightSimulation)
    var duplicate = read
    let bodies = duplicate.bodies
    let commander = duplicate.commander
    duplicate.observeNativeCrimboAttainedMotion(
      delta: 0.01, flightWasActive: true, startTime: fact.startTime,
      startPlayer: frame.commander.flightSimulation.player, stationEntryAttempted: false)
    #expect(
      duplicate.nativeCrimboAttainedMotion == nil && duplicate.nativeCrimboMotionSample == nil)
    #expect(duplicate.bodies == bodies && duplicate.commander == commander)
    let noTick = await runtime.advance(delta: 0)
    #expect(noTick.nativeCrimboAttainedMotion == nil && noTick.nativeCrimboMotionSample == nil)
    #expect(
      noTick.commander.flightSimulation.physicalTime
        == frame.commander.flightSimulation.physicalTime)
  }

  @Test func requestedLargeDeltaAuthenticatesOnlyTheActualClampedPhysicalStep() async throws {
    let game = try ActorMotionFixture.game()
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let frame = await runtime.advance(delta: 1.5)
    let observed = frame.nativeCrimboAttainedMotion
    let fact = try #require(observed)
    #expect(abs(fact.endTime - fact.startTime - 0.1) < 1e-10)
    #expect(
      abs(
        frame.commander.flightSimulation.physicalTime
          - before.commander.flightSimulation.physicalTime - 0.1) < 1e-10)
    let actual = fact.subjectEnd.position - fact.subjectStart.position
    #expect((actual - fact.subjectStartVelocity * 0.1).length < 1e-8)
  }

  @Test(arguments: NativeCrimboActorMotionRefusal.allCases)
  func everyRefusedAdvanceClearsPreviousFactWithoutUndoingNativeEffects(
    refusal: NativeCrimboActorMotionRefusal
  ) async throws {
    let initial = try ActorMotionFixture.game()
    let firstRuntime = GameRuntime(game: initial)
    var game = await firstRuntime.advance(delta: 0.01)
    let observed = game.nativeCrimboAttainedMotion
    _ = try #require(observed)
    switch refusal {
    case .paused: game.paused = true
    case .docked: game.docked = true
    case .disabledGate: game.nativeCrimboLifecycleAvailable = false
    case .gameOver: game.screen = .gameOver
    case .help: game.screen = .help
    }
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let frame = await runtime.advance(delta: 0.01)
    #expect(frame.nativeCrimboAttainedMotion == nil && frame.nativeCrimboMotionSample == nil)
    if refusal == .disabledGate {
      #expect(
        frame.commander.flightSimulation.physicalTime
          > before.commander.flightSimulation.physicalTime)
    } else {
      #expect(
        frame.commander.flightSimulation.physicalTime
          == before.commander.flightSimulation.physicalTime)
      #expect(frame.bodies == before.bodies)
    }
  }

  @Test func fatalNativePhysicalStepKeepsFatalEffectsAndDiscardsMotionEvidence() async throws {
    var game = try ActorMotionFixture.game()
    game.celestials = [.init(kind: .planet, position: .init(0, 0, 0), radius: 1500)]
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let frame = await runtime.advance(delta: 0.01)
    #expect(frame.screen == .gameOver && frame.energy == 0)
    #expect(
      frame.commander.flightSimulation.physicalTime > before.commander.flightSimulation.physicalTime
    )
    #expect(frame.nativeCrimboAttainedMotion == nil && frame.nativeCrimboMotionSample == nil)
  }

  @Test func actualMainStationContactKeepsDamageAndStopWithoutAttainedEvidence() async throws {
    var game = try ActorMotionFixture.stationGame()
    var pose = ShipPose(position: .init(300, 0, 0))
    pose.orientation.x = .init(0, 0, 1)
    pose.orientation.y = .init(0, 1, 0)
    pose.orientation.z = .init(-1, 0, 0)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 32
    let runtime = GameRuntime(game: game)
    var frame = await runtime.snapshot()
    var contacted = false
    for _ in 0..<6 {
      let before = frame
      frame = await runtime.advance(delta: 0.1)
      if frame.stationImpactRevision == frame.gameplayRevision {
        contacted = true
        #expect(frame.frontShield < before.frontShield)
        #expect(frame.speed == 0 && !frame.docked)
        #expect(
          frame.commander.flightSimulation.physicalTime
            > before.commander.flightSimulation.physicalTime)
        #expect(frame.nativeCrimboAttainedMotion == nil && frame.nativeCrimboMotionSample == nil)
        break
      }
    }
    #expect(contacted)
  }

  @Test func actualRefusedRRSEntryConsumesSampleAndKeepsCompletedPhysicalClock() async throws {
    let priorRuntime = GameRuntime(game: try ActorMotionFixture.game())
    let prior = await priorRuntime.advance(delta: 0.01)
    let priorFact = try #require(prior.nativeCrimboAttainedMotion)
    let priorSample = try ActorMotionFixture.sample(from: priorFact, in: prior)
    // Current original-world routes do not require RRS/convoy coexistence. Test
    // cleanup of genuine but foreign-world/owner observations at an authentic RRS.
    var game = try NativeStationTestFixture.launched()
    game.nativeCrimboAttainedMotion = priorFact
    game.nativeCrimboMotionSample = priorSample
    try #require(game.nativeCrimboAttainedMotion != nil && game.nativeCrimboMotionSample != nil)
    let world = try #require(game.commander.nativeStations)
    let station = try #require(
      game.bodies.first {
        $0.nativeStationIdentity?.definition
          == NativeStationGeometry.Kind.waystation.sourceDefinition
      })
    let rigid = world.bodyRigidPoseIsConsistent(station, flight: game.commander.flightSimulation)
    try #require(rigid)
    let identity = try #require(station.nativeStationIdentity)
    let saved = try #require(world.pose(for: identity))
    let orientation = try #require(
      saved.orientation(at: game.commander.flightSimulation.physicalTime))
    let port = NativeStationGeometry.waystation.docking
    var pose = ShipPose()
    pose.position = saved.position + orientation.apply(port.center + port.outward)
    pose.orientation.y = orientation.apply(port.up)
    pose.orientation.z = orientation.apply(port.outward) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 2
    // A real doorway attempt is refused by the existing owner when no save destination exists.
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let oldDepth =
      (orientation.inverse(before.commander.flightSimulation.pose.position - saved.position)
      - port.center).dot(port.outward)
    let frame = await runtime.advance(delta: 0.1)
    let endpointOrientation = saved.orientation(at: frame.commander.flightSimulation.physicalTime)
    let endOrientation = try #require(endpointOrientation)
    let depth =
      (endOrientation.inverse(frame.commander.flightSimulation.pose.position - saved.position)
      - port.center).dot(port.outward)
    #expect(oldDepth > 0 && depth <= 0 && depth > -port.tunnelDepth)
    #expect(frame.message == "CHOOSE A SAVE LOCATION BEFORE RRS DOCKING")
    #expect(!frame.docked && frame.pendingNativeStationDock == nil)
    #expect(
      frame.commander.flightSimulation.physicalTime > before.commander.flightSimulation.physicalTime
    )
    #expect(frame.nativeCrimboAttainedMotion == nil && frame.nativeCrimboMotionSample == nil)
  }

  @Test func preflightEarlyRefusalClearsPriorObservationBeforeAnyPhysicalMutation() async throws {
    let initial = try ActorMotionFixture.game()
    let firstRuntime = GameRuntime(game: initial)
    let observedFrame = await firstRuntime.advance(delta: 0.01)
    let observed = observedFrame.nativeCrimboAttainedMotion
    let fact = try #require(observed)
    var (game, _, index) = try actualMissionBridgeGame()
    game.bodies[index].rotation = .infinity
    game.nativeCrimboAttainedMotion = fact
    game.nativeCrimboMotionSample = try ActorMotionFixture.sample(from: fact, in: observedFrame)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let frame = await runtime.advance(delta: 0.1)
    #expect(frame.paused && frame.message == "MISSION FLIGHT RESTORE REFUSED - PAUSED")
    #expect(frame.commander == before.commander && frame.bodies == before.bodies)
    #expect(frame.nativeCrimboAttainedMotion == nil && frame.nativeCrimboMotionSample == nil)
  }

  @Test(arguments: NativeCrimboActorMotionTamper.allCases)
  func tamperedCallbackAfterActualActorStepDiscardsEvidenceAndRetainsPhysicalState(
    tamper: NativeCrimboActorMotionTamper
  ) async throws {
    let initial = try ActorMotionFixture.game()
    let runtime = GameRuntime(game: initial)
    var game = await runtime.advance(delta: 0.01)
    let observed = game.nativeCrimboAttainedMotion
    let fact = try #require(observed)
    game.nativeCrimboMotionSample = try ActorMotionFixture.sample(from: fact, in: game)
    var startTime = fact.startTime
    var player = game.commander.flightSimulation.player
    switch tamper {
    case .teleport:
      let index = try #require(game.bodies.firstIndex { $0.physical?.identity == fact.actor })
      game.bodies[index].position.x += 1000
    case .staleEpoch: game.nativeStationRuntimeEpoch = UUID()
    case .stalePlayer:
      player = .init(system: fact.actor.system, visit: fact.visit + 1, entity: 0)
    case .staleStart: startTime += 0.02
    case .contactMarker: game.stationImpactRevision = game.gameplayRevision
    }
    game.applyDamage(7, front: true)
    let commander = game.commander
    let bodies = game.bodies
    let energy = game.energy
    let shield = game.frontShield
    game.observeNativeCrimboAttainedMotion(
      delta: 0.01, flightWasActive: true, startTime: startTime,
      startPlayer: player, stationEntryAttempted: false)
    #expect(game.nativeCrimboAttainedMotion == nil && game.nativeCrimboMotionSample == nil)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.energy == energy && game.frontShield == shield)
  }
}
