import Foundation
import Testing

@testable import EliteCore

@Test func nativeArrivalTickKeepsRotatingStationsOnPhysicalClockAndPublishes() throws {
  var game = Game(executive: false)
  try game.commander.prepareEquipment()
  let destination = 237  // Existing source fixture has both a rotating waystation and headquarters.
  let target = game.systems[destination]
  let reach = game.commander.maximumJumpDistance
  let origin = try #require(
    game.systems.first {
      $0.id != destination && $0.government >= 5 && $0.distance(to: target) <= reach
    })
  game.commander.system = origin.id
  game.selectedSystem = origin.id
  game.market = MarketItem.at(game.currentSystem, fluctuation: 0)
  game.screen = .status
  game.launch()
  let launched = !game.docked && !game.paused && game.screen.isFlight && game.commander.valid
  try #require(launched)
  var controls = Controls()
  controls.throttle = 1
  var departure = 0
  while game.hyperspaceMassLocked && departure < 300 {
    game.tick(delta: 0.1, controls: controls)
    departure += 1
  }
  let ready = departure < 300 && !game.hyperspaceMassLocked && game.energy > 0 && !game.paused
  try #require(ready)
  let fuel = game.commander.fuel
  game.selectedSystem = destination
  game.key("h")
  let journey = try #require(game.commander.scriptState.calendarLedger?.pendingJourney)
  try #require(journey.origin == origin.id && journey.destination == destination)
  var steps = 0
  while game.jumpCountdown != nil && steps < 500 {
    game.tick(delta: 0.1, controls: Controls())
    steps += 1
  }
  let arrived =
    steps > 0 && steps < 500 && game.commander.system == destination
    && !game.docked && !game.paused && game.energy > 0
  try #require(arrived)
  #expect(game.commander.fuel == fuel - journey.nativeFuelDebit)
  let world = try #require(game.commander.nativeStations)
  let waystation = try #require(
    game.bodies.first { $0.nativeStationIdentity?.definition == "rescue_station" })
  let headquarters = try #require(
    game.bodies.first { $0.nativeStationIdentity?.definition == "rrs_headquarters" })
  let rotatingPoseMatches = world.bodyRigidPoseIsConsistent(
    waystation, flight: game.commander.flightSimulation)
  let stationaryPoseMatches = world.bodyRigidPoseIsConsistent(
    headquarters, flight: game.commander.flightSimulation)
  #expect(rotatingPoseMatches && stationaryPoseMatches)
  let main = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  #expect(abs(main.rotation - 0.1 * main.rotationRate) < 1e-12)
  let sceneMatches = game.scriptWorldSave.consistent(with: game.commander)
  #expect(sceneMatches)
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  _ = try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: storage.url)
  let bytes = try Data(contentsOf: storage.url)
  let (cold, scene) = try ScriptSaveStore.read(bytes, from: storage.url)
  let retainedSceneMatches = scene.consistent(with: cold)
  #expect(retainedSceneMatches && cold.system == destination)
  // Actual source pose validation still rejects a changed station phase; no tolerance is relaxed.
  var changed = game.scriptWorldSave
  let index = try #require(changed.bodies.firstIndex { $0.id == waystation.id })
  changed.bodies[index].rotation += 0.01
  let changedSceneMatches = changed.consistent(with: game.commander)
  #expect(!changedSceneMatches)
}
