import Foundation
import Testing

@testable import EliteCore

private func solarGame(distance: Double = 2970) -> Game {
  var game = Game(executive: false)
  game.launch()
  game.bodies = []
  game.celestials = [.init(kind: .sun, position: .init(0, 0, distance), radius: 1100)]
  game.commander.equipment.insert("Fuel Scoops")
  game.commander.fuel = 0
  game.speed = 8
  return game
}

@Test func solarScoopAccumulatesFractionalFuelAndRespectsTankCapacity() {
  var game = solarGame()
  for _ in 0..<10 { game.advanceSolarFlight(delta: 0.1) }
  #expect(game.commander.fuel == 7)
  #expect(game.solarScoopState == .collecting)
  #expect(game.cabinTemperature > 0 && game.cabinTemperature < 0.75)
  game.commander.fuel = game.commander.fuelCapacity - 1
  for _ in 0..<10 { game.advanceSolarFlight(delta: 0.1) }
  #expect(game.commander.fuel == game.commander.fuelCapacity)
  #expect(game.solarScoopState == .tankFull && game.solarFuelRemainder == 0)
}

@Test func solarScoopRequiresEquipmentRangeNoseFacingAndForwardCruise() {
  var game = solarGame()
  game.commander.equipment.remove("Fuel Scoops")
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .noScoops)
  #expect(game.cabinTemperature > 0)
  game.commander.equipment.insert("Fuel Scoops")
  game.speed = 0
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .turnTowardSun)
  game.speed = 8
  game.celestials[0].position.z = -2970
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .turnTowardSun)
  game.celestials[0].position = .init(0, 0, 5000)
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .inactive)
  game.celestials[0] = .init(kind: .planet, position: .init(0, 0, 2970), radius: 1100)
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0)
}

@Test func solarCollectionDependsOnNoseInsteadOfSelectedCameraAndScalesWithCruise() {
  var game = solarGame()
  game.screen = .rear
  game.speed = 4
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 3 && abs(game.solarFuelRemainder - 0.5) < 0.000001)
  #expect(game.solarScoopState == .collecting)
}

@Test func thermalExposureCoolsAwayFromSunAndKillsDespiteShieldsOrXYZzyFuel() {
  var game = solarGame(distance: 1500)
  game.commander.unlimitedFuel = true
  game.commander.fuel = game.commander.fuelCapacity
  for _ in 0..<30 where game.screen != .gameOver { game.advanceSolarFlight(delta: 0.1) }
  #expect(game.screen == .gameOver && game.energy == 0)
  #expect(game.message.contains("OVERHEATED"))
  #expect(game.frontShield > 0)
  var cooling = solarGame(distance: 10000)
  cooling.cabinTemperature = 0.9
  for _ in 0..<50 { cooling.advanceSolarFlight(delta: 0.1) }
  #expect(cooling.cabinTemperature < 0.5 && cooling.screen == .front)
}

@Test func celestialSurfaceImpactsAreFatalAndProximityMassLocksJumps() {
  var game = solarGame(distance: 1000)
  #expect(game.massLocked)
  let before = game.celestials
  game.inSystemJump()
  #expect(game.celestials == before && game.message == "MASS LOCKED")
  game.advanceSolarFlight(delta: 0.1)
  #expect(game.screen == .gameOver && game.message == "DESTROYED IN THE SUN")
  var planet = solarGame()
  planet.celestials = [.init(kind: .planet, position: .init(0, 0, 900), radius: 1000)]
  planet.advanceSolarFlight(delta: 0.1)
  #expect(planet.screen == .gameOver && planet.message == "PLANET IMPACT")
}

@Test func flightTickMovesCelestialsExactlyWithShipsAndFreezesForHelp() {
  var game = solarGame(distance: 12000)
  game.bodies = [.init(id: 100, hull: .cargo, position: .init(0, 0, 12000))]
  game.tick(delta: 0.1, controls: Controls())
  #expect(game.celestials[0].position == game.bodies[0].position)
  let prior = game.celestials
  let heat = game.cabinTemperature
  game.screen = .help
  game.tick(delta: 0.1)
  #expect(game.celestials == prior && game.cabinTemperature == heat)
  game.screen = .front
  game.inSystemJump()
  #expect(game.celestials[0].position.z == prior[0].position.z - 3000)
}

@Test func dockingLoadingAndArrivalUseExistingDockedSaveSemantics() throws {
  var game = solarGame()
  game.cabinTemperature = 0.9
  game.dock()
  #expect(game.celestials.isEmpty && game.cabinTemperature == 0)
  game.launch()
  #expect(Set(game.celestials.map(\.kind)) == [.sun, .planet])
  let scene = game.celestials
  game.cabinTemperature = 0.6
  let commander = try JSONDecoder().decode(
    Commander.self, from: JSONEncoder().encode(game.commander))
  let loaded = game.load(commander)
  #expect(loaded)
  #expect(game.docked && game.celestials.isEmpty && game.cabinTemperature == 0)
  game.launch()
  var preserved = game.commander
  #expect(preserved.scriptState.calendarSeconds == commander.scriptState.calendarSeconds + 600)
  preserved.scriptState.calendarSeconds = commander.scriptState.calendarSeconds
  preserved.scriptState.calendarLedger = commander.scriptState.calendarLedger
  #expect(game.celestials == scene && preserved == commander)
}

@Test func solarHUDReportsActualScoopAndThermalDanger() {
  var game = solarGame()
  game.advanceSolarFlight(delta: 0.1)
  #expect(game.solarHUDLines.contains { $0.contains("SCOOP ACTIVE") })
  game.cabinTemperature = 0.95
  #expect(game.solarHUDLines.contains { $0.contains("CRITICAL") })
  game.celestials[0].position = .init(-1000, 1000, -3000)
  #expect(game.solarHUDLines[0].contains("ASTERN PORT UP"))
}

@Test func celestialHUDBearingsFollowTheSelectedCockpitView() {
  for (screen, position) in [
    (Screen.front, Vector3(0, 0, 1000)),
    (.rear, .init(0, 0, -1000)),
    (.left, .init(-1000, 0, 0)),
    (.right, .init(1000, 0, 0)),
  ] {
    var game = solarGame()
    game.screen = screen
    game.celestials[0].position = position
    #expect(game.solarHUDLines[0].contains("SUN AHEAD"))
    #expect(!game.solarHUDLines[0].contains("ASTERN"))
  }
}
