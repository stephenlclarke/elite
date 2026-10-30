import Foundation
import Testing

@testable import L337Core

private func assistedGame() -> Game {
  var game = Game(executive: false)
  game.launch()
  for key in "xyzzy" { game.key(String(key)) }
  game.key("return")
  game.speed = 0
  game.ecmControl = ECMControl()
  return game
}
@Test func autoCyclesVisibleFrontThenOffscreenWithStableMovingTargets() throws {
  // A controlled pre-admission unit cohort, not an ordinary populated launch.
  var game = Game(executive: false)
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.commander.credits = 1000
  game.commander.installTargetingComputer(.docking)
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  try #require(game.commander.valid && game.commander.targetingTier == .docking)
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.docked = false
  game.screen = .rear
  game.speed = 0
  try #require(game.commander.nativeStations == nil)
  game.ensurePhysicalActors()
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
    game.key("tab")
    #expect(game.autoPilot.targetID == id)
    game.bodies.reverse()
  }
  game.key("tab")
  #expect(game.autoPilot.targetID == 3)
  game.bodies.removeAll { $0.id == 3 }
  game.tick(delta: 0.01)
  #expect(game.autoPilot.targetID == nil)
  game.bodies = []
  game.key("tab")
  #expect(game.autoPilot.status == "NO TARGETS")
}
@Test func autoFacesTargetsWithoutChangingSpeedOrFiringAndManualSteeringWins() {
  var game = assistedGame()
  game.bodies = [.init(id: 1, hull: .cobra, position: .init(900, 500, -800))]
  game.bodies[0].rotationRate = 0
  game.speed = 7
  game.key("tab")
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
  game.key("tab")
  game.key("q")
  #expect(game.autoPilot.targetID == nil)
}
@Test func stationAutoCompletesRealDockingFromEitherSideWithEitherSpin() throws {
  for z in [1800.0, -1800.0] {
    for rate in [-0.3, 0.3] {
      var game = assistedGame()
      let anchor = try #require(
        game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
      let index = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
      // Express the original relative start by moving the observer, retaining the real source.
      NativeStationTestFixture.reframe(
        &game,
        to: .init(
          position: anchor.position - anchor.orientation.apply(.init(0, 0, z)),
          orientation: anchor.orientation))
      game.bodies[index].rotation = 1.4
      game.bodies[index].rotationRate = rate
      try #require(game.bodies[index].physical?.identity == anchor.identity)
      #expect((game.bodies[index].position - Vector3(0, 0, z)).length < 1e-8)
      #expect(game.bodies[index].rotation == 1.4 && game.bodies[index].rotationRate == rate)
      for _ in 0..<(game.bodies.count * 2) {
        game.key("tab")
        if game.autoPilot.targetActor == anchor.identity { break }
      }
      try #require(game.autoPilot.targetID == 0 && game.autoPilot.targetActor == anchor.identity)
      for _ in 0..<7000 where !game.docked { game.tick(delta: 0.02) }
      #expect(game.docked && game.screen == .status && game.bodies.isEmpty)
      #expect(game.nativeMainStationDockEvidenceIsCurrent)
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
  #expect(game.energy < 256)
  #expect(!game.bodies.contains { (1...3).contains($0.id) && $0.hull == .missile })
  #expect(game.bodies.contains { $0.id == 4 && $0.hull == .cobra && $0.energy > 0 })
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

@Test func stationAutoUsesTiltedEntrancePoseAndSwitchesAwayWithoutResidualTranslation() throws {
  var game = assistedGame()
  let anchor = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  let position = Vector3(1200, 700, 1600)
  var orientation = Basis3()
  orientation.rotate(pitch: 0.6, roll: 0.4, yaw: 0.8)
  let camera = anchor.orientation.composed(with: orientation.transposed)
  NativeStationTestFixture.reframe(
    &game,
    to: .init(position: anchor.position - camera.apply(position), orientation: camera))
  var station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  station.rotationRate = -0.3
  try #require(station.physical?.identity == anchor.identity)
  #expect((station.position - position).length < 1e-8)
  for axis in [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)] {
    #expect((station.orientation.apply(axis) - orientation.apply(axis)).length < 1e-8)
  }
  game.bodies = [station]
  game.key("tab")
  let selected = try #require(game.autoTargetBody)
  let anchors = try #require(game.commander.flightSimulation.anchors)
  let actor = try #require(selected.physical?.identity)
  try #require(
    selected.id == 0 && selected.nativeStationIdentity == nil
      && actor == anchors.station.identity && game.dockingComputer)
  for _ in 0..<7000 where !game.docked { game.tick(delta: 0.02) }
  #expect(game.docked)
  game.launch()
  game.speed = 0
  station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  game.bodies = [station, .init(id: 2, hull: .cobra, position: .init(0, 0, 500))]
  game.key("tab")
  #expect(game.autoPilot.targetID == 2 && game.autoPilot.velocity.length == 0)
  game.bodies.removeAll { $0.hull != .station }
  game.key("tab")
  game.key("b")
  #expect(game.autoPilot.targetID == nil)
  game.key("tab")
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

@Test func rCentersTheSelectedShipFromEveryViewAtNativeResolutionWithoutChangingCruise() {
  for view in [Screen.front, .rear, .left, .right] {
    for position in [Vector3(900, 500, 1800), .init(-900, -500, -1800)] {
      var game = assistedGame()
      game.commander.autoTarget = false
      game.viewportWidth = 1800
      game.viewportHeight = 1160
      game.screen = view
      game.speed = 3
      game.bodies = [.init(id: 22, hull: .cobra, position: position)]
      game.key("tab")
      #expect(game.screen == .front && game.weaponsTargetID == 22)
      for _ in 0..<800 {
        // Independent target movement exercises tracking rather than only a fixed bearing.
        game.bodies[0].position.x += 0.08
        game.bodies[0].position.y -= 0.04
        game.tick(delta: 0.01)
      }
      let target = game.bodies[0].position
      let focal = CockpitLayout(game: game, width: 1800, height: 1160).projection.focal
      #expect(target.z > 0 && hypot(target.x, target.y) / target.z * focal < 1.5)
      #expect(game.speed == 3 && game.autoPilot.status == "TRACKING TARGET")
      #expect(!game.commander.autoTarget && game.autoPilot.manualEngagement)
      game.key("q")
      #expect(game.autoPilot.targetID == nil && !game.autoPilot.manualEngagement)
    }
  }
}
