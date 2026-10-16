import Foundation
import Testing

@testable import EliteCore

struct NativeMissionFrameTests {
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
