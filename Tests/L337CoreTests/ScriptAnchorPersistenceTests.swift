import Foundation
import Testing

@testable import L337Core

@Test(arguments: [
  "live", "dead-live", "saved", "dead-saved", "other-galaxy", "other-system", "absent",
])
func scriptAnchorPreservesLivePreferenceAndExactSavedFrameFallback(selection: String) throws {
  var game = Game(executive: false)
  game.launch()
  let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  var saved = station
  saved.position = station.position + .init(10, 20, 30)
  game.scriptReferenceFrame = .init(
    galaxy: game.commander.galaxy, system: game.commander.system, station: saved)
  if selection != "live" && selection != "dead-live" {
    game.bodies.removeAll { $0.id == 0 && $0.hull == .station }
  }
  let galaxy = game.commander.galaxy
  let system = game.commander.system
  switch selection {
  case "dead-live":
    let index = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
    game.bodies[index].energy = 0
  case "dead-saved": game.scriptReferenceFrame?.station.energy = 0
  case "other-galaxy": game.scriptReferenceFrame?.galaxy = (galaxy + 1) % 8
  case "other-system": game.scriptReferenceFrame?.system = (system + 1) % 256
  case "absent": game.scriptReferenceFrame = nil
  default: break
  }
  let before = game.commander
  let bodies = game.bodies
  let frame = game.scriptReferenceFrame
  let anchor = game.scriptAnchor
  if selection == "live" {
    #expect(anchor == station)
  } else if selection == "saved" {
    #expect(anchor == saved)
  } else {
    #expect(anchor == nil)
  }
  #expect(game.commander == before && game.bodies == bodies && game.scriptReferenceFrame == frame)
}

@Test(arguments: [false, true])
func scriptActorPersistenceRetainsCanonicalPoseWithLiveOrSavedAnchor(savedOnly: Bool) throws {
  var (game, instance, index) = try actualMissionBridgeGame()
  let station = try #require(game.scriptAnchor)
  game.scriptReferenceFrame = .init(
    galaxy: game.commander.galaxy, system: game.commander.system, station: station)
  game.bodies[index].position = game.bodies[index].position + .init(7, 11, 13)
  game.bodies[index].energy -= 1
  let body = game.bodies[index]
  if savedOnly { game.bodies.removeAll { $0.id == 0 && $0.hull == .station } }
  game.persistScriptActors(unloading: true)
  let retained = try #require(
    game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"])
  #expect(retained.identity == body.missionActorID && retained.presence == .unloaded)
  #expect(retained.body.energy == max(0, body.energy))
  #expect(retained.body.position == station.orientation.inverse(body.position - station.position))
  #expect(retained.body.orientation == body.orientation.relative(to: station.orientation))
  #expect(
    retained.body.scriptNPC?.velocity
      == station.orientation.inverse(
        body.scriptNPC?.velocity ?? .init(0, 0, 0)))
  #expect(game.scriptReferenceFrame?.station == station)
  #expect(game.bodies.contains { $0 == body })
}

@Test func scriptActorPersistenceRefreshesDeadStationBeforeRefusingSavedFallback() throws {
  var (game, instance, index) = try actualMissionBridgeGame()
  let station = try #require(game.scriptAnchor)
  game.scriptReferenceFrame = .init(
    galaxy: game.commander.galaxy, system: game.commander.system, station: station)
  let before = game.commander.scriptState.instances[instance]?.ownedEncounters
  game.bodies[index].position = game.bodies[index].position + .init(7, 11, 13)
  let stationIndex = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
  game.bodies[stationIndex].energy = 0
  game.persistScriptActors(unloading: true)
  #expect(game.scriptReferenceFrame?.station.energy == 0)
  #expect(game.scriptAnchor == nil)
  #expect(game.commander.scriptState.instances[instance]?.ownedEncounters == before)
}
