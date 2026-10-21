import Foundation
import Testing

@testable import EliteCore

struct GameplayEncounterIntegrationTests {
  @Test func approachingARealFieldAdmitsBoundedUndepletedPhysicalRocks() throws {
    var game = Game(executive: false)
    game.launch()
    game.bodies.removeAll { $0.id != 0 }
    let field = try #require(game.miningFields.first)
    game.commander.flightSimulation.pose.position = field.position + Vector3(0, 0, -500)
    game.activateNearbyMiningFields()
    let rocks = game.bodies.filter { $0.physical?.rock != nil }
    #expect(!rocks.isEmpty && rocks.count <= PopulationClass.asteroid.maximum)
    #expect(Set(rocks.compactMap { $0.physical?.rock }).count == rocks.count)
    for body in rocks {
      let rock = try #require(
        game.miningFields.flatMap(\.rocks).first { $0.identity == body.physical?.rock })
      #expect(body.energy == rock.energy)
      #expect(
        abs((game.gameplayMesh(for: body).vertices.map(\.length).max() ?? 0) - rock.radius) < 1e-9)
    }
    game.activateNearbyMiningFields()
    #expect(game.bodies.filter { $0.physical?.rock != nil }.count == rocks.count)
  }

  @Test func extractedOreIsAdmittedThenPhysicallyScoopedWithItsNativeQuantity() throws {
    var game = Game(executive: false)
    game.launch()
    game.bodies.removeAll()
    let rock = try #require(game.miningFields.first?.rocks.first)
    let player = try #require(game.commander.flightSimulation.player)
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    var body = SpaceBody(id: 10, hull: .asteroid, position: .init(0, 0, 500))
    body.energy = rock.energy
    body.physical = .init(identity: actor, population: .asteroid, rock: rock.identity)
    game.bodies = [body]
    let captured = game.makeAttackOrigin(owner: player)
    let origin = try #require(captured)
    game.applyCombatHit(
      .init(target: .body(body.id), distance: 500, point: body.position),
      origin: origin, kind: .laser, damage: rock.energy, laser: .mining)
    game.resolveDestroyed()
    game.admitPendingOre()
    let payloads = game.commander.miningLedger.pendingPayloads
    let pod = try #require(game.bodies.first { $0.physical?.payload != nil })
    let payload = try #require(payloads.first { $0.identity == pod.physical?.payload })
    game.commander.equipment.insert("Fuel Scoops")
    let index = try #require(game.bodies.firstIndex { $0.id == pod.id })
    game.bodies[index].position = .init(0, -10, 30)
    game.scoopCargo()
    #expect(game.commander.cargo[payload.amount.commodity.rawValue] == payload.amount.quantity)
    #expect(!game.bodies.contains { $0.id == pod.id })
    #expect(
      !game.commander.miningLedger.pendingPayloads.contains { $0.identity == payload.identity })
    game.admitPendingOre()
    #expect(!game.bodies.contains { $0.physical?.payload == payload.identity })
  }

  @Test func newPopulationMovementUsesWorldVelocityAndDoesNotRunLegacyHostileDamage() throws {
    var game = Game(executive: false)
    game.launch()
    game.speed = 0
    game.bodies.removeAll { $0.id != 0 }
    let context = try #require(game.gameplayContext())
    let npc = NPCState(role: .pirate, origin: context.system, destination: context.system)
    let request = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: 999, member: 0),
      population: .pirate, hull: .sidewinder, position: .init(1000, 0, -1000),
      orientation: Basis3(), velocity: .init(100, 0, 0), npc: npc,
      rock: nil, payload: nil, priority: .ordinary)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: true)], intents: []))
    let actor = try #require(receipts.first?.actor)
    let initial = try #require(game.gameplayContext()?.actors.first { $0.identity == actor })
    let shield = game.frontShield
    game.tick(delta: 0.1)
    let moved = try #require(game.gameplayContext()?.actors.first { $0.identity == actor })
    #expect((moved.position - initial.position).length > 0)
    #expect(game.frontShield == shield && game.commander.legal == 0)
  }
}
