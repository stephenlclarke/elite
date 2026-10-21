import Foundation
import Testing

@testable import EliteCore

private func admissionGame() -> Game {
  var game = Game(executive: false)
  game.launch()
  game.bodies.removeAll { $0.id != 0 }
  return game
}

private func admissionRequest(
  _ game: Game, sequence: UInt64 = 1, member: UInt16 = 0,
  population: PopulationClass = .civilian, priority: AdmissionPriority = .ordinary,
  position: Vector3 = .init(1000, 0, -3000)
) -> SpawnRequest {
  .init(
    identity: .init(
      system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
      sequence: sequence, member: member),
    population: population, hull: population == .projectile ? .missile : .cobra,
    position: position, orientation: Basis3(), velocity: .init(0, 0, 10),
    npc: nil, rock: nil, payload: nil, priority: priority)
}

private func admissionPlan(_ game: Game, requests: [SpawnRequest], atomic: Bool = true)
  -> EncounterPlan
{
  .init(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
    revision: game.gameplayRevision,
    batches: [.init(requests: requests, atomic: atomic)], intents: [])
}

struct GameplayAdmissionTests {
  @Test func admittedBodiesUseOneAllocatorAndWorldToViewTransform() throws {
    var game = admissionGame()
    let request = admissionRequest(game)
    let receipts = game.admitEncounterPlan(admissionPlan(game, requests: [request]))
    let actor = try #require(receipts.first?.actor)
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(body.physical?.spawnIdentity == request.identity)
    #expect(body.physical?.velocity == request.velocity)
    #expect(game.commander.flightSimulation.pose.systemPoint(body.position) == request.position)
    #expect(receipts.first?.refusal == nil && game.bodies.count == 2)
    let replay = game.admitEncounterPlan(admissionPlan(game, requests: [request]))
    #expect(replay == receipts && game.bodies.count == 2)
  }

  @Test func stalePlanCannotMutateTheSceneOrAllocator() {
    var game = admissionGame()
    let plan = admissionPlan(game, requests: [admissionRequest(game)])
    let actor = game.commander.flightSimulation.nextActor
    game.gameplayRevision += 1
    let receipts = game.admitEncounterPlan(plan)
    #expect(receipts.first?.refusal == .staleContext)
    #expect(game.bodies.count == 1 && game.commander.flightSimulation.nextActor == actor)
  }

  @Test func atomicPackCannotBePartiallyAdmittedOnPopulationLimit() {
    var game = admissionGame()
    let requests = (0..<9).map {
      admissionRequest(game, member: UInt16($0), position: .init(Double($0) * 500, 0, -3000))
    }
    let receipts = game.admitEncounterPlan(admissionPlan(game, requests: requests))
    #expect(receipts.count == 9 && receipts.allSatisfy { $0.refusal == .populationLimit })
    #expect(game.bodies.count == 1)
    let partial = game.admitEncounterPlan(admissionPlan(game, requests: requests, atomic: false))
    #expect(partial.filter { $0.actor != nil }.count == 8 && game.bodies.count == 9)
  }

  @Test func atomicPackRejectsDuplicateIdentityAndIntersectingMembers() {
    var game = admissionGame()
    let request = admissionRequest(game)
    let duplicate = game.admitEncounterPlan(admissionPlan(game, requests: [request, request]))
    #expect(duplicate.allSatisfy { $0.refusal == .staleContext })
    let overlap = admissionRequest(game, member: 1)
    let collision = game.admitEncounterPlan(admissionPlan(game, requests: [request, overlap]))
    #expect(collision.allSatisfy { $0.refusal == .unsafePosition } && game.bodies.count == 1)
  }

  @Test func unsafePlanetSunPlayerAndNonfiniteSpawnsAreRefused() throws {
    var game = admissionGame()
    let context = try #require(game.gameplayContext())
    for point in [
      context.anchors.planet.position, context.anchors.sun.position,
      context.player.position, .init(.infinity, 0, 0),
    ] {
      let receipt = game.admitEncounterPlan(
        admissionPlan(game, requests: [admissionRequest(game, position: point)]))
      #expect(receipt.first?.refusal == .unsafePosition && game.bodies.count == 1)
    }
  }

  @Test func projectileCanStartAtOwnerMuzzleWithoutBypassingCelestialSafety() throws {
    var game = admissionGame()
    let context = try #require(game.gameplayContext())
    let muzzle = admissionRequest(game, population: .projectile, position: context.player.position)
    let receipts = game.admitEncounterPlan(admissionPlan(game, requests: [muzzle]))
    #expect(receipts.first?.actor != nil)
    let sun = admissionRequest(
      game, sequence: 2, population: .projectile, position: context.anchors.sun.position)
    let refused = game.admitEncounterPlan(admissionPlan(game, requests: [sun]))
    #expect(refused.first?.refusal == .unsafePosition)
  }

  @Test func totalCapPreservesPoliceAndMissionReserves() {
    var game = admissionGame()
    // Existing mission bodies exercise total capacity without exhausting a smaller class.
    for id in 1..<116 {
      let actor = game.commander.flightSimulation.allocateActor()!
      var body = SpaceBody(id: id, hull: .cargo, position: .init(100000 + Double(id) * 200, 0, 0))
      body.physical = .init(identity: actor, population: .mission)
      game.bodies.append(body)
    }
    let ordinary = admissionRequest(game)
    let first = game.admitEncounterPlan(admissionPlan(game, requests: [ordinary]))
    #expect(first.first?.actor != nil)
    for index in 0..<3 {
      let request = admissionRequest(
        game, sequence: UInt64(index + 2), position: .init(1000 + Double(index + 1) * 500, 0, -3000)
      )
      _ = game.admitEncounterPlan(admissionPlan(game, requests: [request]))
    }
    let overflow = admissionRequest(game, sequence: 10, position: .init(-2000, 0, -3000))
    #expect(
      game.admitEncounterPlan(admissionPlan(game, requests: [overflow])).first?.refusal
        == .reservedCapacity)
    let police = admissionRequest(
      game, sequence: 11, population: .police, priority: .police, position: .init(-2000, 0, -3000))
    #expect(game.admitEncounterPlan(admissionPlan(game, requests: [police])).first?.actor != nil)
  }
}
