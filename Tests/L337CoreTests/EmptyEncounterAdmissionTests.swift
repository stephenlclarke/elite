import Foundation
import Testing

@testable import L337Core

struct EmptyEncounterAdmissionTests {
  @Test func emptyAdmissionDoesNotAllocateOrAdoptUnrelatedActors() throws {
    var game = Game(executive: false)
    game.bodies = [.init(id: 2, hull: .cobra, position: .init(-8000, -1000, 20000))]
    let before = game
    try #require(game.commander.flightSimulation.system == nil)
    let variants: [[SpawnBatch]] = [[], [.init(requests: [], atomic: false)]]
    for batches in variants {
      let plan = EncounterPlan(
        system: game.systemIdentity, visit: 0, revision: game.gameplayRevision,
        batches: batches, intents: [])
      let receipts = game.admitEncounterPlan(plan)
      #expect(receipts.isEmpty)
      #expect(game.commander == before.commander && game.bodies == before.bodies)
      #expect(
        game.gameplayRevision == before.gameplayRevision && game.nextBodyID == before.nextBodyID)
      #expect(game.message == before.message && game.ecmControl.events == before.ecmControl.events)
      #expect(game.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    }
  }

  @Test func actualRequestStillAdoptsAndValidatesTheOriginalScene() throws {
    var game = Game(executive: false)
    game.bodies = [.init(id: 2, hull: .cobra, position: .init(-8000, -1000, 20000))]
    let identity = game.systemIdentity
    let request = SpawnRequest(
      identity: .init(system: identity, visit: 1, sequence: 42, member: 0),
      population: .cargo, hull: .cargo, position: .init(20000, 20000, 20000),
      orientation: .init(), velocity: .init(0, 0, 0), npc: nil, rock: nil,
      payload: nil, priority: .ordinary)
    let plan = EncounterPlan(
      system: identity, visit: 1, revision: game.gameplayRevision,
      batches: [.init(requests: [request], atomic: false)], intents: [])
    let receipts = game.admitEncounterPlan(plan)
    try #require(receipts.count == 1)
    #expect(receipts[0].refusal == nil && receipts[0].actor != nil)
    #expect(game.commander.flightSimulation.system == identity)
    #expect(game.bodies.first(where: { $0.id == 2 })?.physical?.identity != nil)
    #expect(game.bodies.contains { $0.physical?.spawnIdentity == request.identity })
    let before = game
    let stale = EncounterPlan(
      system: identity, visit: 0, revision: game.gameplayRevision,
      batches: [.init(requests: [request], atomic: false)], intents: [])
    let refused = game.admitEncounterPlan(stale)
    #expect(refused.count == 1 && refused[0].refusal == .staleContext && refused[0].actor == nil)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
  }
}
