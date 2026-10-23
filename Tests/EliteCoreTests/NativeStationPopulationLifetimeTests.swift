import Foundation
import Testing

@testable import EliteCore

/// Population component fixtures exercise admission and refusal, not a flown station journey.
struct NativeStationPopulationLifetimeTests {
  @Test func missingWorldReturnsBeforeSceneAndCursorValidation() throws {
    var game = Game(executive: false)
    game.nextBodyID = 0
    game.bodies = [SpaceBody(id: 50, hull: .asteroid, position: .init(0, 0, 0))]
    let before = game
    try #require(game.commander.nativeStations == nil && game.docked)
    try game.populateNativeStations()
    expectUnchanged(game, before: before)
  }

  @Test func emptyCohortKeepsBindingsWithoutAllocatingFromExhaustedCursors() throws {
    var game = try NativeStationTestFixture.launched()
    game.nextBodyID = 0
    try changeFlight(&game) {
      $0["nextActor"] = UInt64.max
      $0["nextSpawn"] = UInt64.max
    }
    let before = game
    try #require(game.bodies.filter { $0.nativeStationIdentity != nil }.count == 2)
    try game.populateNativeStations()
    expectUnchanged(game, before: before)
  }

  @Test(arguments: [
    "docked", "missing-anchors", "invalid-world", "system-mismatch", "duplicate", "binding",
    "body-budget", "body-cursor",
    "source", "clearance", "spawn-cursor", "second-rebind", "final-flight",
  ])
  func refusedPopulationPreservesTheWholeCandidateAndErrorPriority(scenario: String) throws {
    var game =
      scenario == "duplicate" || scenario == "binding"
      ? try NativeStationTestFixture.launched() : try unpopulated()
    let expected: NativeStationRuntimeError?
    switch scenario {
    case "docked":
      game.docked = true
      expected = .invalidState
    case "missing-anchors":
      try changeFlight(&game) { $0["anchors"] = NSNull() }
      expected = .invalidState
    case "invalid-world":
      game.commander.nativeStations?.poses.removeLast()
      game.nextBodyID = 0
      expected = .invalidState
    case "system-mismatch":
      try changeFlight(&game) { values in
        var anchors = try #require(values["anchors"] as? [String: Any])
        anchors["system"] = ["galaxy": 0, "system": 7]
        values["anchors"] = anchors
      }
      expected = .invalidState
    case "duplicate":
      let body = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
      game.bodies.append(body)
      // Existing binding validation must refuse before this separate capacity failure.
      game.nextBodyID = 0
      expected = .invalidState
    case "binding":
      let index = try #require(game.bodies.firstIndex { $0.nativeStationIdentity != nil })
      game.bodies[index].id += 1000
      game.nextBodyID = 0
      expected = .invalidState
    case "body-budget":
      game.bodies = (0..<128).map {
        SpaceBody(id: $0 + 100, hull: .asteroid, position: .init(0, 100000, 100000))
      }
      expected = .capacity
    case "body-cursor":
      game.nextBodyID = 1_000_000_000 - 2
      expected = .capacity
    case "source":
      try changeFlight(&game) { values in
        var anchors = try #require(values["anchors"] as? [String: Any])
        var station = try #require(anchors["station"] as? [String: Any])
        station["position"] = ["x": 1, "y": 0, "z": 0]
        anchors["station"] = station
        values["anchors"] = anchors
      }
      expected = .invalidSource
    case "clearance":
      let world = try #require(game.commander.nativeStations)
      let station = try #require(world.poses.first { $0.station.system == game.systemIdentity })
      game.bodies = [
        SpaceBody(
          id: 100, hull: .asteroid,
          position: game.commander.flightSimulation.pose.shipPoint(station.position))
      ]
      expected = .unsafePlacement
    case "spawn-cursor":
      try changeFlight(&game) { $0["nextSpawn"] = UInt64.max }
      expected = .capacity
    case "second-rebind":
      // The first binding accepts Int64.max. The next allocated actor exceeds its source range.
      try changeFlight(&game) { $0["nextActor"] = UInt64(Int64.max) }
      expected = nil
    case "final-flight":
      // Both actors/rebinds succeed, but the incremented spawn cursor fails final validation.
      try changeFlight(&game) { $0["nextSpawn"] = UInt64.max - 1 }
      expected = .invalidState
    default:
      Issue.record(Comment(rawValue: "Unrecognised station population fixture: " + scenario))
      return
    }
    let before = game
    if let expected {
      #expect(throws: expected) { try game.populateNativeStations() }
    } else {
      do {
        try game.populateNativeStations()
        Issue.record("Population accepted an actor outside the station binding range.")
      } catch NativeStationStateError.unavailable {
        // The original ledger rejects the second binding after the first local rebind.
      }
    }
    expectUnchanged(game, before: before)
  }

  @Test func populationPublishesTheWholeCohortInOriginalSourceAndActorOrder() throws {
    var game = try unpopulated()
    let before = game
    let worldBefore = try #require(game.commander.nativeStations)
    let records = worldBefore.ledger.records.filter { $0.identity.system == game.systemIdentity }
    try #require(records.count == 2 && records.allSatisfy { $0.binding == nil })
    let flightBefore = game.commander.flightSimulation
    try game.populateNativeStations()
    let world = try #require(game.commander.nativeStations)
    let flight = game.commander.flightSimulation
    #expect(world.valid && flight.valid)
    #expect(game.bodies.compactMap(\.nativeStationIdentity) == records.map(\.identity))
    #expect(game.nextBodyID == before.nextBodyID + 2)
    #expect(flight.nextActor == flightBefore.nextActor + 2)
    #expect(flight.nextSpawn == flightBefore.nextSpawn + 1)
    for (member, body) in game.bodies.enumerated() {
      let record = records[member]
      let source = try #require(NativeStationSource.binding(for: record.identity))
      let saved = try #require(worldBefore.pose(for: record.identity))
      let actor = ActorIdentity(
        system: game.systemIdentity, visit: flightBefore.visit,
        entity: flightBefore.nextActor + UInt64(member))
      #expect(body.id == before.nextBodyID + member && body.physical?.identity == actor)
      #expect(body.physical?.spawnIdentity?.sequence == flightBefore.nextSpawn)
      #expect(body.physical?.spawnIdentity?.member == UInt16(member))
      #expect(body.position == flightBefore.pose.shipPoint(saved.position))
      #expect(body.orientation == saved.orientation.relative(to: flightBefore.pose.orientation))
      #expect(body.energy == saved.energy && body.rotationRate == source.rotationRate)
      #expect(body.missiles == 0 && body.ecmEnabled == (source.kind == .waystation))
      #expect(
        world.ledger.records.first { $0.identity == record.identity }?.binding
          == .init(actor: actor, bodyID: body.id))
    }
    #expect(before.commander.nativeStations == worldBefore && before.bodies.isEmpty)
    let admitted = game
    try game.populateNativeStations()
    expectUnchanged(game, before: admitted)
  }

  private func unpopulated() throws -> Game {
    var game = Game(executive: false)
    game.commander.galaxy = 3
    game.commander.system = 149
    game.systems = Universe.systemsIncludingPlugh(number: 3)
    try game.activateNativeStationWorld()
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
    game.docked = false
    game.bodies = []
    return game
  }

  private func changeFlight(
    _ game: inout Game, _ change: (inout [String: Any]) throws -> Void
  ) throws {
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander.flightSimulation))
        as? [String: Any])
    try change(&fields)
    game.commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self, from: JSONSerialization.data(withJSONObject: fields))
  }

  private func expectUnchanged(_ game: Game, before: Game) {
    #expect(game.commander == before.commander)
    #expect(game.commander.nativeStations == before.commander.nativeStations)
    #expect(game.commander.flightSimulation == before.commander.flightSimulation)
    #expect(game.bodies == before.bodies && game.nextBodyID == before.nextBodyID)
  }
}
