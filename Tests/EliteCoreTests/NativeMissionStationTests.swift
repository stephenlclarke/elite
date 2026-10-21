import Foundation
import Testing

@testable import EliteCore

struct NativeMissionStationTests {
  @Test
  func restoringALivingStationUsesTheCurrentCanonicalIdentityWithoutAllocatingOrReusingCustody()
    throws
  {
    var (game, _, _) = try actualMissionBridgeGame()
    game.persistScriptActors()
    let frame = try #require(game.scriptReferenceFrame)
    let anchors = try #require(game.commander.flightSimulation.anchors)
    game.bodies.removeAll { $0.id == 0 }
    let commander = game.commander
    let bodyID = game.nextBodyID
    let restored = game.restoreNativeMissionStationIfEligible()
    try #require(restored)
    let station = try #require(game.bodies.first { $0.id == 0 })
    #expect(station.physical?.identity == anchors.station.identity)
    #expect(station.physical?.npc == nil && station.physical?.spawnIdentity == nil)
    #expect(station.missionActorID == nil && station.missionInstanceID == nil)
    #expect(
      station.position == frame.station.position && station.orientation == frame.station.orientation
    )
    #expect(station.rotation == frame.station.rotation && station.energy == frame.station.energy)
    #expect(game.commander == commander && game.nextBodyID == bodyID)
    let duplicate = game.restoreNativeMissionStationIfEligible()
    #expect(!duplicate && game.bodies.filter { $0.id == 0 }.count == 1)
  }

  @Test(arguments: ["player", "unallocated", "visit", "system"])
  func invalidDecodedAnchorCannotCreateAStationOrMutateAnyNativeState(field: String) throws {
    var (game, _, _) = try actualMissionBridgeGame()
    game.persistScriptActors()
    game.bodies.removeAll { $0.id == 0 }
    let encoded = try JSONEncoder().encode(game.commander.flightSimulation)
    let decoded = try JSONSerialization.jsonObject(with: encoded)
    var object = try #require(decoded as? [String: Any])
    var anchors = try #require(object["anchors"] as? [String: Any])
    var station = try #require(anchors["station"] as? [String: Any])
    var identity = try #require(station["identity"] as? [String: Any])
    switch field {
    case "player": identity["entity"] = 0
    case "unallocated":
      identity["entity"] = NSNumber(value: game.commander.flightSimulation.nextActor)
    case "visit": identity["visit"] = NSNumber(value: game.commander.flightSimulation.visit + 1)
    default:
      var system = try #require(identity["system"] as? [String: Any])
      system["system"] = (game.commander.system + 1) % 256
      identity["system"] = system
    }
    station["identity"] = identity
    anchors["station"] = station
    object["anchors"] = anchors
    game.commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self, from: JSONSerialization.data(withJSONObject: object))
    let commander = game.commander
    let bodies = game.bodies
    let next = game.nextBodyID
    let restored = game.restoreNativeMissionStationIfEligible()
    #expect(
      !restored && game.commander == commander && game.bodies == bodies && game.nextBodyID == next)
  }

  @Test func anActualDeadStationCannotBeReplacedByAnOlderLivingReferenceFrame() throws {
    var (game, _, _) = try actualMissionBridgeGame()
    game.persistScriptActors()
    let index = try #require(game.bodies.firstIndex { $0.id == 0 })
    try #require(game.scriptReferenceFrame?.station.energy ?? 0 > 0)
    game.bodies[index].energy = 0
    let commander = game.commander
    let bodies = game.bodies
    let restored = game.restoreNativeMissionStationIfEligible()
    #expect(!restored && game.commander == commander && game.bodies == bodies)
  }
}
