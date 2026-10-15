import Testing

@testable import EliteCore

private func lockedGame() -> Game {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.commander.installTargetingComputer(.military)
  game.bodies = [.init(id: 42, hull: .cobra, position: .init(0, 0, 1000), hostile: true)]
  game.key("r")
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
func playerImmediateAndTravellingMissilesAndBombCarryKillAttribution(_ mode: Int) {
  do {
    var game = lockedGame()
    if mode == 2 {
      game.commander.equipment.insert("Energy Bomb")
      game.energyBomb()
    } else {
      // Isolate kill attribution: a nearby attacker can now physically intercept the missile.
      game.bodies[0].hostile = false
      game.bodies[0].ecmEnabled = mode == 1
      game.bodies[0].position = .init(0, 0, 100)
      game.key("t")
      game.key("m")
    }
    game.tick(delta: 0.1)
    for _ in 0..<5 { game.tick(delta: 0.1) }
    #expect(game.commander.kills == 1)
    #expect(announcements(game, "TARGET DESTROYED - YOUR KILL") == 1)
    #expect(announcements(game, "TARGET LOST") == 0)
  }
}
@Test func thirdPartyDestructionRangeLossAndDespawnCannotClaimPlayerKill() {
  for mode in 0..<3 {
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
  var game = lockedGame()
  game.bodies.append(.init(id: 43, hull: .cobra, position: .init(10, 0, 1200)))
  game.key("r")
  game.key("q")
  #expect(
    announcements(game, "TARGET LOST") == 0
      && announcements(game, "TARGET DESTROYED - YOUR KILL") == 0)
}
