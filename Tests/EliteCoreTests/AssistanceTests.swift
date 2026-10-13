import Foundation
import Testing

@testable import EliteCore

private func assistedGame() -> Game {
  var game = Game(executive: false)
  game.launch()
  for key in "xyzzy" { game.key(String(key)) }
  game.key("return")
  game.speed = 0
  game.ecmControl = ECMControl()
  return game
}
@Test func autoCyclesVisibleFrontThenOffscreenWithStableMovingTargets() {
  var game = assistedGame()
  game.screen = .rear
  game.bodies = [
    .init(id: 8, hull: .cobra, position: .init(0, 0, 2000)),
    .init(id: 4, hull: .cobra, position: .init(0, 0, 1000)),
    .init(id: 3, hull: .viper, position: .init(0, 0, 1000)),
    .init(id: 2, hull: .viper, position: .init(0, 0, -100)),
    .init(id: 1, hull: .cobra, position: .init(1000, 0, 10)),
    .init(id: 9, hull: .missile, position: .init(0, 0, 10)),
  ]
  #expect(game.autoPilot.targetID == nil)
  for id in [3, 4, 8, 2, 1] {
    game.key("r")
    #expect(game.autoPilot.targetID == id)
    game.bodies.reverse()
  }
  game.key("r")
  #expect(game.autoPilot.targetID == 3)
  game.bodies.removeAll { $0.id == 3 }
  game.tick(delta: 0.01)
  #expect(game.autoPilot.targetID == nil)
  game.bodies = []
  game.key("r")
  #expect(game.autoPilot.status == "NO TARGETS")
}
@Test func autoFacesTargetsWithoutChangingSpeedOrFiringAndManualSteeringWins() {
  var game = assistedGame()
  game.bodies = [.init(id: 1, hull: .cobra, position: .init(900, 500, -800))]
  game.bodies[0].rotationRate = 0
  game.speed = 7
  game.key("r")
  game.key("v")
  game.key("]")
  let initialEnergy = game.bodies[0].energy
  for _ in 0..<200 { game.tick(delta: 0.02) }
  #expect(game.autoPilot.facingError < 0.1)
  #expect(game.speed == 7 && game.bodies[0].energy == initialEnergy && game.laserFlash == 0)
  #expect(game.spin.mode && game.spin.actualRate > 0)
  var controls = Controls()
  controls.pitch = 0.5
  game.tick(delta: 0.02, controls: controls)
  #expect(game.autoPilot.targetID == nil && game.pitch == 0.5)
  game.key("r")
  game.key("q")
  #expect(game.autoPilot.targetID == nil)
}
@Test func stationAutoCompletesRealDockingFromEitherSideWithEitherSpin() {
  for z in [1800.0, -1800.0] {
    for rate in [-0.3, 0.3] {
      var game = assistedGame()
      var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, z))
      station.rotation = 1.4
      station.rotationRate = rate
      game.bodies = [station]
      game.key("r")
      for _ in 0..<7000 where !game.docked { game.tick(delta: 0.02) }
      #expect(game.docked && game.screen == .status && game.bodies.isEmpty)
      #expect(
        !game.ecmControl.events.contains { $0.announcement == .gameplay("DOCKING COLLISION") })
    }
  }
}
@Test func automaticECMAnnouncesActualOutcomesInOrderAndRespectsCooldownAndSwitch() {
  var game = assistedGame()
  game.bodies = []
  for id in 1...3 {
    var missile = SpaceBody(id: id, hull: .missile, position: .init(0, 0, 1000))
    missile.enemyMissile = true
    game.bodies.append(missile)
  }
  game.bodies.append(.init(id: 4, hull: .cobra, position: .init(0, 0, 600)))
  game.tick(delta: 0.02)
  #expect(game.ecmControl.events.map(\.announcement) == [.missileDetected, .ecmActivated])
  #expect(game.energy < 256 && game.bodies.count == 1)
  let after = game.energy
  game.ecm()
  #expect(game.energy == after)
  for _ in 0..<31 { game.tick(delta: 0.02) }
  #expect(game.ecmControl.events.last?.announcement == .missilesDestroyed(3))
  #expect(FlightAnnouncement.missilesDestroyed(1).text == "1 missile destroyed by ECM")
  #expect(FlightAnnouncement.missilesDestroyed(3).text == "3 missiles destroyed by ECM")
  game.commander.autoECM = false
  var missile = SpaceBody(id: 10, hull: .missile, position: .init(0, 0, 1000))
  missile.enemyMissile = true
  game.bodies.append(missile)
  game.tick(delta: 0.02)
  #expect(game.bodies.contains { $0.id == 10 })
  #expect(game.ecmControl.events.last?.announcement == .missileDetected)
  game.ecm()
  for _ in 0..<32 { game.tick(delta: 0.02) }
  #expect(game.ecmControl.events.last?.announcement == .missilesDestroyed(1))
}
@Test func ecmIgnoresUnrelatedThreatsAndCountsOnlyItsOwnDestruction() {
  var game = assistedGame()
  game.bodies = [.init(id: 1, hull: .missile, position: .init(0, 0, 1000))]
  game.tick(delta: 0.02)
  #expect(game.ecmControl.events.isEmpty)
  game.bodies[0].enemyMissile = true
  game.bodies[0].energy = 0
  game.tick(delta: 0.02)
  #expect(game.ecmControl.events.isEmpty)
  game.ecm()
  for _ in 0..<32 { game.tick(delta: 0.02) }
  #expect(game.ecmControl.events.map(\.announcement) == [.ecmActivated])
  var missile = SpaceBody(id: 2, hull: .missile, position: .init(0, 0, 1000))
  missile.enemyMissile = true
  game.commander.autoECM = false
  game.bodies = [missile]
  game.ecmFrames = 32
  game.tick(delta: 0.02)
  for _ in 0..<32 { game.tick(delta: 0.02) }
  #expect(
    !game.ecmControl.events.contains {
      if case .missilesDestroyed = $0.announcement { return true }
      return false
    })
}

@Test func stationAutoUsesTiltedEntrancePoseAndSwitchesAwayWithoutResidualTranslation() {
  var game = assistedGame()
  var station = SpaceBody(id: 1, hull: .station, position: .init(1200, 700, 1600))
  station.orientation.rotate(pitch: 0.6, roll: 0.4, yaw: 0.8)
  station.rotationRate = -0.3
  game.bodies = [station]
  game.key("r")
  for _ in 0..<7000 where !game.docked { game.tick(delta: 0.02) }
  #expect(game.docked)
  game.launch()
  game.speed = 0
  game.bodies = [station, .init(id: 2, hull: .cobra, position: .init(0, 0, 500))]
  game.key("r")
  #expect(game.autoPilot.targetID == 2 && game.autoPilot.velocity.length == 0)
  game.bodies.removeAll { $0.hull != .station }
  game.key("r")
  game.key("b")
  #expect(game.autoPilot.targetID == nil)
  game.key("r")
  game.commander.autoTarget = false
  game.tick(delta: 0.02)
  #expect(game.autoPilot.targetID == nil)
}

@Test func ecmCountsNewWavesOnceDuringAnOwnActivationAndRequiresRealEquipment() {
  var game = assistedGame()
  game.bodies = []
  game.commander.equipment.remove("E.C.M. System")
  var missile = SpaceBody(id: 1, hull: .missile, position: .init(0, 0, 1000))
  missile.enemyMissile = true
  game.bodies = [missile]
  game.tick(delta: 0.02)
  #expect(game.ecmControl.events.map(\.announcement) == [.missileDetected])
  game.commander.equipment.insert("E.C.M. System")
  game.tick(delta: 0.02)
  missile = SpaceBody(id: 2, hull: .missile, position: .init(0, 0, 1000))
  missile.enemyMissile = true
  game.bodies.append(missile)
  game.tick(delta: 0.02)
  for _ in 0..<31 { game.tick(delta: 0.02) }
  let events = game.ecmControl.events.map(\.announcement)
  #expect(events.filter { $0 == .ecmActivated }.count == 1)
  #expect(events.filter { $0 == .missilesDestroyed(2) }.count == 1)
  #expect(events.filter { $0 == .missileDetected }.count == 2)
  game.commander.xyzzyActive = false
  missile = SpaceBody(id: 3, hull: .missile, position: .init(0, 0, 1000))
  missile.enemyMissile = true
  game.bodies.append(missile)
  game.tick(delta: 0.02)
  #expect(game.bodies.contains { $0.id == 3 })
}
