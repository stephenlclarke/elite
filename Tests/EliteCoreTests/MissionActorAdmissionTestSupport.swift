import Foundation
import Testing

@testable import EliteCore

/// A real native fixture admission, not a caller-assigned scene or physical identity.
func admitMissionTestObstruction(_ game: inout Game, hull: Hull, position: Vector3) throws -> Int {
  game.ensurePhysicalActors()
  let allocated = game.commander.flightSimulation.allocateSpawn()
  let sequence = try #require(allocated)
  let context = try #require(game.gameplayContext())
  let request = SpawnRequest(
    identity: .init(
      system: context.system, visit: context.visit, sequence: sequence, member: 0,
      producer: .mission),
    population: .mission, hull: hull,
    position: game.commander.flightSimulation.pose.systemPoint(position), orientation: Basis3(),
    velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil, priority: .mission)
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: true)], intents: []))
  try #require(receipts.count == 1 && receipts[0].refusal == nil)
  let actor = try #require(receipts[0].actor)
  let body = try #require(game.bodies.first { $0.physical?.identity == actor })
  return body.id
}
