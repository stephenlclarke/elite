import Testing

@testable import L337Core

private func nativeBeamAimGame(shipID: String = "SH025", sourceRange: Double = 1000) -> Game {
  var game = Game(executive: false)
  game.commander.shipID = shipID
  game.docked = false
  game.screen = .front
  game.speed = 0
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = [
    .init(id: 10, hull: .cobra, position: .init(0, 0, sourceRange), hostile: true)
  ]
  game.celestials = []
  game.ensurePhysicalActors()
  game.gameplayCombatTrace = .init()
  return game
}

struct LegacyNPCBeamAimTests {
  @Test func peregrineCentreOpeningRemainsAMissButNativeBeamHitsItsRealSurfaceOnce() throws {
    var game = nativeBeamAimGame()
    let source = try #require(game.bodies.first { $0.id == 10 })
    let owner = try #require(source.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    try #require(game.commander.shipID == "SH025" && source.position.length < 1500)
    let centreRay = try game.nearestMissionCollision(
      from: source.position, direction: source.position.unit * -1,
      range: source.position.length + 100, radius: 0,
      excludingBodyIDs: [source.id], includePlayer: true)
    try #require(centreRay == nil)
    let nextEmission = game.commander.flightSimulation.nextEmission
    let energy = game.energy
    let shields = game.frontShield + game.rearShield
    game.emitLegacyNPCBeam(bodyID: source.id, damage: 5)
    #expect(game.commander.flightSimulation.nextEmission == nextEmission + 1)
    #expect(game.energy < energy || game.frontShield + game.rearShield < shields)
    try #require(game.gameplayCombatTrace?.incidents.count == 1)
    let incident = try #require(game.gameplayCombatTrace?.incidents.first)
    #expect(incident.origin.owner == owner && incident.victim == player)
    #expect(incident.kind == .laser && incident.outcome == .hit)
    #expect(incident.position.finite && incident.origin.emittedAt == incident.physicalTime)
    let armed = try #require(game.bodies.first { $0.id == source.id })
    #expect(armed.energy == source.energy)
    #expect((armed.physical?.npc?.resources?.laserHeat ?? 0) > 0)
  }

  @Test func interveningActualAsteroidReceivesTheBeamInsteadOfThePlayer() throws {
    var game = nativeBeamAimGame()
    game.bodies.append(.init(id: 11, hull: .asteroid, position: .init(0, 0, 500)))
    game.ensurePhysicalActors()
    let owner = try #require(game.bodies.first { $0.id == 10 }?.physical?.identity)
    let blocker = try #require(game.bodies.first { $0.id == 11 })
    let blockerActor = try #require(blocker.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    let nextEmission = game.commander.flightSimulation.nextEmission
    game.emitLegacyNPCBeam(bodyID: 10, damage: 5)
    #expect(game.commander.flightSimulation.nextEmission == nextEmission + 1)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
    try #require(game.gameplayCombatTrace?.incidents.count == 1)
    let incident = try #require(game.gameplayCombatTrace?.incidents.first)
    #expect(incident.origin.owner == owner && incident.victim == blockerActor)
    #expect(incident.victim != player && incident.kind == .laser && incident.outcome == .hit)
  }

  @Test func ordinaryCobraPlayerStillReceivesOneAttributedPhysicalHit() throws {
    var game = nativeBeamAimGame(shipID: "SH023")
    let owner = try #require(game.bodies.first { $0.id == 10 }?.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let nextEmission = game.commander.flightSimulation.nextEmission
    let shields = game.frontShield + game.rearShield
    game.emitLegacyNPCBeam(bodyID: 10, damage: 5)
    #expect(game.commander.flightSimulation.nextEmission == nextEmission + 1)
    #expect(game.frontShield + game.rearShield < shields)
    try #require(game.gameplayCombatTrace?.incidents.count == 1)
    let incident = try #require(game.gameplayCombatTrace?.incidents.first)
    #expect(incident.origin.owner == owner && incident.victim == player)
    #expect(incident.kind == .laser && incident.outcome == .hit)
  }

  @Test func playerSurfaceAimDoesNotExtendTheLegacyEngagementRange() throws {
    var game = nativeBeamAimGame(sourceRange: 1600)
    let index = try #require(game.bodies.firstIndex { $0.id == 10 })
    let player = try #require(game.commander.flightSimulation.player)
    try #require(game.bodies[index].physical?.npc?.intention == .engage(player))
    let nextEmission = game.commander.flightSimulation.nextEmission
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    game.enemyAction(index: index, dt: 0.1)
    #expect(game.bodies[index].position.length > 1500)
    #expect(game.commander.flightSimulation.nextEmission == nextEmission)
    #expect(game.gameplayCombatTrace?.incidents.isEmpty == true)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
  }
}
