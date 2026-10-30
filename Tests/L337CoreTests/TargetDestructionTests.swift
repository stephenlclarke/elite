import Testing

@testable import L337Core

private func lockedGame() -> Game {
  var game = Game(executive: false)
  game.commander.installTargetingComputer(.military)
  game.launch()
  game.speed = 0
  #expect(game.commander.targetingTier == .military)
  game.bodies = [.init(id: 42, hull: .cobra, position: .init(0, 0, 1000), hostile: true)]
  game.key("tab")
  #expect(game.autoPilot.targetID == 42 && game.weaponsTargetID == 42)
  return game
}
private func announcements(_ game: Game, _ text: String) -> Int {
  game.ecmControl.events.filter { $0.announcement == .gameplay(text) }.count
}
@Test func playerLaserKillClearsLocksAndAnnouncesDestructionOnceAlongsideRankReward() {
  var game = lockedGame()
  game.commander.kills = 7
  game.bodies[0].energy = 1
  var controls = Controls()
  controls.fire = true
  game.tick(delta: 0.01, controls: controls)
  #expect(game.commander.kills == 8 && game.message == "TARGET DESTROYED - YOUR KILL")
  #expect(
    game.autoPilot.targetID == nil && game.weaponsTargetID == nil && game.targetInformation == nil)
  for _ in 0..<10 { game.tick(delta: 0.1) }
  #expect(announcements(game, "TARGET DESTROYED - YOUR KILL") == 1)
  #expect(
    announcements(game, "TARGET LOST") == 0 && announcements(game, "RIGHT ON, COMMANDER") == 1)
}
@Test(arguments: 0..<3)
func playerImmediateAndTravellingMissilesAndBombCarryKillAttribution(_ mode: Int) throws {
  do {
    var game = lockedGame()
    if mode == 2 {
      try game.commander.grantEquipment(
        "Energy Bomb", at: .utility(.energyBomb), provenance: .grant("kill attribution fixture"))
      #expect(game.commander.fittedEquipment(at: .utility(.energyBomb)) != nil)
      game.energyBomb()
    } else {
      game.bodies[0].ecmEnabled = mode == 1
      game.bodies[0].position = .init(0, 0, 100)
      let target = try #require(game.bodies[0].physical?.identity)
      let player = try #require(game.commander.flightSimulation.player)
      game.key("t")
      game.key("m")
      let missile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
      let flight = try #require(missile.physical?.ordnance)
      #expect(flight.target == target && flight.origin.owner == player)
      #expect(game.commander.missiles == 2 && game.commander.kills == 0)
      #expect(game.bodies[0].energy > 0 && flight.propulsionTravel == 0)
      // Isolate actual ordnance attribution from the separately tested counterfire lane.
      game.commander.flightSimulation.advancePhysicalTime(0.1)
      game.advanceNavalMissiles(delta: 0.1)
      let impact = try #require(
        game.bodies.first { $0.id == missile.id }?.physical?.ordnance)
      #expect(impact.termination == .impact && impact.propulsionTravel > 0)
      #expect(game.bodies[0].energy == 0 && game.bodies[0].physical?.deathOrigin == flight.origin)
      #expect(game.ecmFrames == 0)
      game.resolveDestroyed()
      #expect(game.commander.kills == 1)
      #expect(announcements(game, "TARGET DESTROYED - YOUR KILL") == 1)
    }
    game.tick(delta: 0.1)
    for _ in 0..<5 { game.tick(delta: 0.1) }
    #expect(game.commander.kills == 1)
    #expect(announcements(game, "TARGET DESTROYED - YOUR KILL") == 1)
    #expect(announcements(game, "TARGET LOST") == 0)
  }
}
@Test func thirdPartyDestructionRangeLossAndDespawnCannotClaimPlayerKill() {
  for mode in 0..<3 { verifyThirdPartyRemoval(mode: mode) }
  verifyManualTargetCancellation()
}
private func verifyThirdPartyRemoval(mode: Int) {
  var game = lockedGame()
  if mode == 0 {
    game.bodies[0].energy = 0
  } else if mode == 1 {
    game.bodies[0].position.z = 100_000
  } else {
    game.bodies = []
  }
  game.tick(delta: 0.01)
  game.tick(delta: 0.01)
  #expect(
    game.commander.kills == 0 && game.weaponsTargetID == nil && game.autoPilot.targetID == nil)
  #expect(announcements(game, "TARGET LOST") == 1)
  #expect(announcements(game, "TARGET DESTROYED - YOUR KILL") == 0)
}
private func verifyManualTargetCancellation() {
  var game = lockedGame()
  game.bodies.append(.init(id: 43, hull: .cobra, position: .init(10, 0, 1200)))
  game.key("tab")
  game.key("q")
  #expect(
    announcements(game, "TARGET LOST") == 0
      && announcements(game, "TARGET DESTROYED - YOUR KILL") == 0)
}
