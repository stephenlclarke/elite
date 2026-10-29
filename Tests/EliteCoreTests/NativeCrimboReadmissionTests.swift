import Foundation
import Testing

@testable import EliteCore

private enum CrimboReadmissionFixture {
  static func launched() throws -> Game {
    var game = Game(executive: false)
    game.commander.galaxy = 7
    game.commander.system = 8
    game.systems = Universe.systemsIncludingPlugh(number: 7)
    // Actual native lifecycle boundary fixture; this is not supported-reader readiness evidence.
    game.nativeCrimboLifecycleAvailable = true
    game.launch()
    let count = CrimboFixture.convoyBodies(game).count
    try #require(!game.docked && count == 7)
    return game
  }

  static func originals(_ game: Game) throws -> [NPCLogicalIdentity: NPCPersistenceSnapshot] {
    let registry = try #require(game.commander.savedCrimboState)
    var result: [NPCLogicalIdentity: NPCPersistenceSnapshot] = [:]
    for member in registry.members {
      guard case .live(let logical) = member.ownership else { throw NativeCrimboError.unavailable }
      let snapshot = try #require(game.commander.npcPersistence.snapshot(for: logical.firstActor))
      result[logical] = snapshot
    }
    return result
  }

  static func unbind(_ game: inout Game, slots: Set<Int> = Set(0..<7)) throws {
    let refused = game.persistNPCStates()
    try #require(refused.isEmpty)
    let registry = try #require(game.commander.savedCrimboState)
    var actors: Set<ActorIdentity> = []
    for member in registry.members where slots.contains(member.slot) {
      guard case .live(let logical) = member.ownership else { throw NativeCrimboError.unavailable }
      let actor = try #require(game.commander.npcPersistence.binding(for: logical))
      actors.insert(actor)
      game.commander.npcPersistence.cull(actor: actor)
    }
    // Retain the actual original snapshots while simulating their absent scene bindings.
    game.bodies.removeAll { $0.physical.map { actors.contains($0.identity) } ?? false }
  }

  static func addOrdinaryTraffic(_ game: inout Game) throws -> [ActorIdentity] {
    let context = try #require(game.gameplayContext())
    let positions: [Vector3] = [.init(-2000, 1800, 2500), .init(-3000, 1800, 3500)]
    let requests = positions.enumerated().map { index, position in
      SpawnRequest(
        identity: .init(
          system: context.system, visit: context.visit,
          sequence: UInt64(9000 + index), member: 0, producer: .ambient),
        population: .civilian, hull: .cobra, position: position, orientation: Basis3(),
        velocity: .init(0, 0, 0),
        npc: .init(role: .trader, origin: context.system, destination: context.system),
        rock: nil, payload: nil, priority: .ordinary, catalogueShipID: "SH023")
    }
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: true)], intents: []))
    let actors = receipts.compactMap(\.actor)
    try #require(actors.count == 2 && receipts.allSatisfy { $0.refusal == nil })
    return actors
  }
}

struct NativeCrimboReadmissionTests {
  @Test func actualRelaunchRestoresTheThreeOriginalsBeyondGenericPerception() throws {
    var game = try CrimboReadmissionFixture.launched()
    let before = try #require(game.commander.savedCrimboState)
    let context = try #require(game.gameplayContext())
    let snapshots = try CrimboReadmissionFixture.originals(game)
    let distances = before.members.compactMap { member -> Double? in
      guard let logical = member.ownership.logical, let snapshot = snapshots[logical] else {
        return nil
      }
      return (snapshot.position - context.player.position).length
    }
    #expect(distances.count == 7 && distances.filter { $0 <= context.perceptionRadius }.count == 4)
    #expect(distances.filter { $0 > context.perceptionRadius }.count == 3)
    let santa = try #require(
      CrimboFixture.convoyBodies(game).first { $0.physical?.catalogueShipID == "SH150" })
    let index = try #require(game.bodies.firstIndex { $0.id == santa.id })
    game.bodies[index].energy = 37
    game.bodies[index].missiles = 0
    game.bodies[index].physical?.npc?.resources?.frontShield = 7
    game.bodies[index].physical?.laserCooldown = 0.4
    game.dock()
    game.launch()
    let after = try #require(game.commander.savedCrimboState)
    #expect(CrimboFixture.convoyBodies(game).count == 7)
    #expect(after.provider == before.provider && after.manifest == before.manifest)
    #expect(
      after.members.map { $0.ownership.logical } == before.members.map { $0.ownership.logical })
    #expect(after.orbit == before.orbit)
    let restored = try #require(
      CrimboFixture.convoyBodies(game).first { $0.physical?.catalogueShipID == "SH150" })
    #expect(restored.energy == 37 && restored.missiles == 0)
    #expect(
      restored.physical?.npc?.resources?.frontShield == 7 && restored.physical?.laserCooldown == 0.4
    )
  }

  @Test(arguments: [0, 6])
  func unownedSameCatalogueBeyondPerceptionRetainsOrdinaryOffsceneScope(slot: Int) throws {
    var game = try CrimboReadmissionFixture.launched()
    let allocation = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocation)
    var unowned = try CrimboFixture.snapshot(
      entity: actor.entity, slot: slot, visit: actor.visit,
      time: game.commander.flightSimulation.physicalTime)
    unowned.position = .init(0, 0, 10000)
    let captured = game.commander.npcPersistence.capture(unowned, protection: .init())
    #expect(captured == .registered(actor))
    game.commander.npcPersistence.cull(actor: actor)
    game.dock()
    game.launch()
    #expect(CrimboFixture.convoyBodies(game).count == 7)
    #expect(game.commander.npcPersistence.binding(for: actor) == nil)
    #expect(!game.bodies.contains { $0.physical?.identity == actor })
    #expect(game.commander.npcPersistence.snapshot(for: actor) == unowned)
  }

  @Test func wholeCohortCapacityRefusalKeepsOriginalsAndLaterRetryReusesThem() throws {
    var game = try CrimboReadmissionFixture.launched()
    let registry = game.commander.savedCrimboState
    try CrimboReadmissionFixture.unbind(&game)
    let traffic = try CrimboReadmissionFixture.addOrdinaryTraffic(&game)
    let before = game.commander.npcPersistence
    let cursor = game.commander.flightSimulation.nextActor
    game.admitPersistentNPCs()
    #expect(CrimboFixture.convoyBodies(game).isEmpty)
    #expect(game.commander.npcPersistence == before && game.commander.savedCrimboState == registry)
    #expect(game.commander.flightSimulation.nextActor == cursor)
    #expect(traffic.allSatisfy { actor in game.bodies.contains { $0.physical?.identity == actor } })
    // Model genuine ordinary retirement to free capacity; production restoration never evicts traffic.
    for actor in traffic {
      let retired = game.commander.npcPersistence.terminal(actor: actor, reason: .docked)
      #expect(retired)
    }
    game.bodies.removeAll { $0.physical.map { traffic.contains($0.identity) } ?? false }
    game.admitPersistentNPCs()
    #expect(CrimboFixture.convoyBodies(game).count == 7)
    #expect(game.commander.savedCrimboState == registry)
    let bound = game.commander.npcPersistence
    game.admitPersistentNPCs()
    #expect(game.commander.npcPersistence == bound && CrimboFixture.convoyBodies(game).count == 7)
  }

  @Test func partiallyBoundCohortRestoresOnlyTheMissingOriginals() throws {
    var game = try CrimboReadmissionFixture.launched()
    let registry = try #require(game.commander.savedCrimboState)
    let retained = CrimboFixture.convoyBodies(game).filter {
      ($0.physical?.spawnIdentity?.member ?? 6) < 4
    }.compactMap { $0.physical?.identity }
    try CrimboReadmissionFixture.unbind(&game, slots: [4, 5, 6])
    #expect(CrimboFixture.convoyBodies(game).count == 4)
    let cursor = game.commander.flightSimulation.nextActor
    game.admitPersistentNPCs()
    #expect(CrimboFixture.convoyBodies(game).count == 7)
    #expect(game.commander.flightSimulation.nextActor == cursor + 3)
    #expect(
      retained.allSatisfy { actor in game.bodies.contains { $0.physical?.identity == actor } })
    #expect(game.commander.savedCrimboState == registry)
  }

  @Test(arguments: [false, true])
  func originalOfferReuseAndCounterExhaustionAreAtomic(exhausted: Bool) throws {
    var game = try CrimboReadmissionFixture.launched()
    try CrimboReadmissionFixture.unbind(&game)
    if exhausted {
      let bytes = try JSONEncoder().encode(game.commander.npcPersistence)
      let decoded = try JSONSerialization.jsonObject(with: bytes)
      var object = try #require(decoded as? [String: Any])
      object["nextOffer"] = UInt64.max - 2
      let encoded = try JSONSerialization.data(withJSONObject: object)
      game.commander.npcPersistence = try JSONDecoder().decode(
        NPCPersistenceLedger.self, from: encoded)
    }
    let context = try #require(game.gameplayContext())
    let selection = game.nativeCrimboPersistenceSelection(context: context)
    let before = game.commander.npcPersistence
    let requests = game.commander.npcPersistence.pendingProviderSpawnRequests(
      context: context, originals: selection.originals)
    if exhausted {
      #expect(requests.isEmpty && game.commander.npcPersistence == before)
    } else {
      #expect(requests.count == 7)
      let offered = game.commander.npcPersistence
      let repeated = game.commander.npcPersistence.pendingProviderSpawnRequests(
        context: context, originals: selection.originals)
      #expect(repeated == requests && game.commander.npcPersistence == offered)
      game.admitPersistentNPCs()
      #expect(CrimboFixture.convoyBodies(game).count == 7)
      let accepted = game.commander.npcPersistence
      let late = requests.map { request in
        SpawnReceipt(
          request: request.identity,
          actor: game.bodies.first { $0.physical?.spawnIdentity == request.identity }?.physical?
            .identity,
          refusal: nil)
      }
      let replayed = game.commander.npcPersistence.acknowledge(receipts: late)
      #expect(replayed.isEmpty && game.commander.npcPersistence == accepted)
    }
  }

  @Test func outsideNativeBubbleOriginalStaysUnboundWithoutOfferOrResourceChanges() throws {
    var game = try CrimboReadmissionFixture.launched()
    try CrimboReadmissionFixture.unbind(&game, slots: [6])
    let registry = try #require(game.commander.savedCrimboState)
    let logical = try #require(registry.members[6].ownership.logical)
    var snapshot = try #require(game.commander.npcPersistence.snapshot(for: logical.firstActor))
    snapshot.position = game.commander.flightSimulation.pose.position + .init(0, 0, 50000)
    let updated = game.commander.npcPersistence.updateUnbound(
      logicalIdentity: logical.firstActor, snapshot: snapshot)
    #expect(updated)
    let before = game.commander.npcPersistence
    game.admitPersistentNPCs()
    #expect(game.commander.npcPersistence == before && CrimboFixture.convoyBodies(game).count == 6)
    #expect(game.commander.npcPersistence.binding(for: logical) == nil)
  }

  @Test func nativeGeometryRefusalRetainsWholeCohortAndOffersForSafeRetry() throws {
    var game = try CrimboReadmissionFixture.launched()
    try CrimboReadmissionFixture.unbind(&game)
    let originals = try CrimboReadmissionFixture.originals(game)
    let santa = try #require(originals.first { $0.value.catalogueShipID == "SH150" }?.value)
    let allocation = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocation)
    var obstacle = SpaceBody(
      id: 777, hull: .asteroid,
      position: game.commander.flightSimulation.pose.shipPoint(santa.position))
    obstacle.physical = .init(identity: actor, population: .asteroid)
    game.bodies.append(obstacle)
    let cursor = game.commander.flightSimulation.nextActor
    game.admitPersistentNPCs()
    #expect(
      CrimboFixture.convoyBodies(game).isEmpty
        && game.commander.flightSimulation.nextActor == cursor)
    let afterRefusal = try CrimboReadmissionFixture.originals(game)
    #expect(afterRefusal == originals)
    let context = try #require(game.gameplayContext())
    let selection = game.nativeCrimboPersistenceSelection(context: context)
    let offers = game.commander.npcPersistence.pendingProviderSpawnRequests(
      context: context, originals: selection.originals)
    #expect(offers.count == 7)
    // The obstacle's native removal makes the same scene geometry safe for the retained offers.
    let index = try #require(game.bodies.firstIndex { $0.id == 777 })
    game.bodies[index].energy = 0
    game.resolveDestroyed()
    game.admitPersistentNPCs()
    #expect(CrimboFixture.convoyBodies(game).count == 7)
    let actual = Set(CrimboFixture.convoyBodies(game).compactMap { $0.physical?.spawnIdentity })
    #expect(actual == Set(offers.map(\.identity)))
  }
}
