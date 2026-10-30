import Foundation
import Testing

@testable import L337Core

struct NativeMissionFrameTests {
  private func movingMissionNPC() throws -> Game {
    var game = Game(executive: false)
    game.launch()
    game.bodies = []
    game.celestials = []
    game.speed = 0
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let pack = try ScriptPackLibrary.read(directory)
    let definition = try #require(pack.manifest.npcs?.first)
    let identity = UUID()
    var npc = try game.makeScriptNPC(definition, pack: pack, identity: identity)
    npc.velocity = .init(13, -7, 31)
    try #require(npc.valid)
    var body = SpaceBody(id: 90, hull: .cobra, position: .init(500, 100, 4000))
    body.missionActorID = identity
    body.missionInstanceID = UUID()
    body.scriptNPC = npc
    game.bodies = [body]
    return game
  }

  @Test func actualManualCameraRotationPreservesMissionNPCWorldMomentumAndDisplacement() throws {
    var stationary = try movingMissionNPC()
    var rotating = stationary
    var controls = Controls()
    controls.yaw = 0.6
    controls.pitch = -0.3
    controls.roll = 0.2
    for _ in 0..<4 {
      stationary.tick(delta: 0.1)
      rotating.tick(delta: 0.1, controls: controls)
    }
    let a = try #require(stationary.bodies.first { $0.id == 90 })
    let b = try #require(rotating.bodies.first { $0.id == 90 })
    let worldA = stationary.commander.flightSimulation.pose.systemPoint(a.position)
    let worldB = rotating.commander.flightSimulation.pose.systemPoint(b.position)
    let velocityA = stationary.commander.flightSimulation.pose.orientation.apply(
      try #require(a.scriptNPC?.velocity))
    let velocityB = rotating.commander.flightSimulation.pose.orientation.apply(
      try #require(b.scriptNPC?.velocity))
    #expect((worldA - worldB).length < 1e-8 && (velocityA - velocityB).length < 1e-8)
    #expect(
      rotating.commander.flightSimulation.pose.orientation
        != stationary.commander.flightSimulation.pose.orientation)
  }

  @Test func actualGuidedFrameRotationPreservesTheSameMissionNPCWorldDisplacement() throws {
    var stationary = try movingMissionNPC()
    var rotating = stationary
    let start = stationary.commander.flightSimulation.pose
    var end = start
    end.orientation.rotate(pitch: 0.1, roll: -0.2, yaw: 0.3)
    for changed in [false, true] {
      var game = changed ? rotating : stationary
      game.workBraking = .init(velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
      game.approvedWorkMotion = .init(
        start: start, end: changed ? end : start, initialVelocity: .init(0, 0, 0),
        acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
        duration: 0.1, playerRadius: 1)
    let moved = game.moveWorkFrame(delta: 0.1)
    try #require(moved)
      game.advanceScriptNPCFlight(delta: 0.1)
      if changed { rotating = game } else { stationary = game }
    }
    let a = try #require(stationary.bodies.first { $0.id == 90 })
    let b = try #require(rotating.bodies.first { $0.id == 90 })
    let worldA = stationary.commander.flightSimulation.pose.systemPoint(a.position)
    let worldB = rotating.commander.flightSimulation.pose.systemPoint(b.position)
    #expect((worldA - worldB).length < 1e-8)
    #expect(rotating.commander.flightSimulation.pose == end)
  }

  @Test func anOwnedScriptActorIsProtectedBeforeOrdinaryNPCPersistenceCanAdoptIt() throws {
    var game = Game(executive: false)
    game.launch()
    var actor = SpaceBody(id: 90, hull: .cobra, position: .init(300, 0, 1700))
    actor.missionInstanceID = UUID()
    actor.missionActorID = UUID()
    game.bodies.append(actor)
    game.ensurePhysicalActors()
    let physical = try #require(game.bodies.first { $0.id == 90 }?.physical)
    #expect(physical.npc?.role == .mission && physical.population == .mission)
    let context = try #require(game.gameplayContext())
    #expect(context.protection.protectedActors.contains(physical.identity))
    _ = game.persistNPCStates()
    #expect(game.commander.npcPersistence.logicalIdentity(for: physical.identity) == nil)
  }

  private func flight() throws -> (Game, Vector3) {
    var game = Game(executive: false)
    game.launch()
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let world = game.commander.flightSimulation.pose.systemPoint(station.position)
    game.scriptReferenceFrame = .init(
      galaxy: game.commander.galaxy, system: game.commander.system,
      station: station)
    game.bodies.removeAll { $0.id == 0 }
    return (game, world)
  }

  @Test func actualManualFlightKeepsACulledMissionStationAtItsCanonicalWorldPoint() throws {
    var (game, world) = try flight()
    game.speed = 2
    var controls = Controls()
    controls.pitch = 0.2
    controls.yaw = 0.3
    controls.roll = -0.15
    for _ in 0..<5 { game.tick(delta: 0.1, controls: controls) }
    let frame = try #require(game.scriptReferenceFrame)
    let restored = game.commander.flightSimulation.pose.systemPoint(frame.station.position)
    #expect((restored - world).length < 1e-8 && frame.station.orientation.validRotation)
  }

  @Test func actualInSystemJumpProjectsTheSameRetainedStationWithoutASecondIntegration() throws {
    var (game, world) = try flight()
    game.bodies = []
    game.celestials = []
    let before = game.commander.flightSimulation.pose
    game.inSystemJump()
    #expect(game.commander.flightSimulation.pose != before)
    let frame = try #require(game.scriptReferenceFrame)
    let restored = game.commander.flightSimulation.pose.systemPoint(frame.station.position)
    #expect((restored - world).length < 1e-8)
  }
}
