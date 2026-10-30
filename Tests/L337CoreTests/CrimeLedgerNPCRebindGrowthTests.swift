import Foundation
import Testing

@testable import L337Core

/// Investigation regression: one surviving logical craft, not unbounded newly killed NPCs.
struct CrimeLedgerNPCRebindGrowthTests {
  @Test func repeatedSameVisitSurvivorRebindKeepsPersistedAttackHistoryBounded() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.speed = 0
    game.bodies = []
    game.celestials = []
    game.miningFields = []
    game.salvageSites = []
    game.commander.npcPersistence = .init()
    game.commander.flightSimulation.pose = .init(position: .init(100_000, 0, 0))
    let player = try #require(game.commander.flightSimulation.player)
    let visit = game.commander.flightSimulation.visit
    let context = try #require(game.gameplayContext())
    var npc = NPCState(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.resources = NPCResources.stock(game.commander.performance)
    npc.intention = .navigate(
      position: context.player.position + .init(0, 0, 2000), speedUnitsPerSecond: 0)
    let request = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: 991, member: 0),
      population: .civilian, hull: .cobra, position: context.player.position + .init(0, 0, 2000),
      orientation: .init(), velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil,
      priority: .ordinary, catalogueShipID: "SH023")
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: false)], intents: []))
    let logical = try #require(receipts.first?.actor)
    var physicalActors = Set<ActorIdentity>()
    var counts: [Int] = []
    for _ in 0..<24 {
      let actor = try #require(game.commander.npcPersistence.binding(for: logical))
      let body = try #require(game.bodies.first { $0.physical?.identity == actor })
      physicalActors.insert(actor)
      let allocated = game.makeAttackOrigin(owner: player)
      let origin = try #require(allocated)
      let hit = GameplayHit(
        target: .body(body.id), distance: body.position.length, point: body.position)
      let incident = game.applyCombatHit(
        hit, origin: origin, kind: .laser, damage: 0.01, laser: .pulse)
      #expect(incident != nil)
      game.commander.crimeLedger.finishEmission(origin.emissionID)
      #expect(game.bodies.first { $0.id == body.id }!.energy > 0)
      counts.append(try attackCount(game.commander.crimeLedger))
      // Move the observer, retaining the NPC's world position. Real tick performs persistence/cull.
      let near = game.commander.flightSimulation.pose
      relocateObserver(&game, to: .init(position: near.position + .init(0, 0, 45000)))
      game.tick(delta: 0.001)
      #expect(game.commander.npcPersistence.binding(for: logical) == nil)
      #expect(!game.bodies.contains { $0.physical?.identity == actor })
      relocateObserver(&game, to: near)
      game.tick(delta: 0.001)
      let rebound = try #require(game.commander.npcPersistence.binding(for: logical))
      #expect(rebound != actor)
      #expect(
        game.commander.npcPersistence.count == 1 && game.commander.npcPersistence.livingCount == 1)
      #expect(game.commander.flightSimulation.visit == visit)
    }
    #expect(physicalActors.count == 24)
    // No deaths or missiles exist in this trace; retained physical-ID attack windows must not grow.
    #expect(
      counts.max() ?? 0 <= 1, "Persisted attack counts across one logical survivor: \(counts)")
    let roundTrip = try JSONDecoder().decode(
      CrimeLedger.self, from: JSONEncoder().encode(game.commander.crimeLedger))
    #expect(try attackCount(roundTrip) <= 1)
  }

  private func attackCount(_ ledger: CrimeLedger) throws -> Int {
    let bytes = try JSONEncoder().encode(ledger)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    return try #require(object["attacks"] as? [Any]).count
  }

  private func relocateObserver(_ game: inout Game, to pose: ShipPose) {
    let old = game.commander.flightSimulation.pose
    for index in game.bodies.indices {
      game.bodies[index].position = pose.shipPoint(old.systemPoint(game.bodies[index].position))
      game.bodies[index].orientation.x = pose.shipVector(
        old.orientation.apply(game.bodies[index].orientation.x))
      game.bodies[index].orientation.y = pose.shipVector(
        old.orientation.apply(game.bodies[index].orientation.y))
      game.bodies[index].orientation.z = pose.shipVector(
        old.orientation.apply(game.bodies[index].orientation.z))
    }
    game.commander.flightSimulation.pose = pose
  }
}
