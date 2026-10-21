import Foundation
import Testing

@testable import EliteCore

struct NPCProducerFactsTests {
  private func context(seed: UInt64, time: Double = 0) -> EncounterContext {
    let position = seed.isMultiple(of: 2) ? Vector3(32000, 0, 0) : Vector3(0, 0, 6000)
    let base = ecologyContext(seed: seed, position: position)
    let system = SystemIdentity(galaxy: 5, system: 7)
    let station = base.anchors.station
    let player = base.player
    return .init(
      system: system, seed: seed, government: base.government, visit: base.visit,
      revision: base.revision, physicalTime: time,
      anchors: .init(
        system: system,
        station: .init(
          identity: .init(system: system, visit: base.visit, entity: station.identity.entity),
          position: station.position, orientation: station.orientation,
          exitPosition: station.exitPosition, exitDirection: station.exitDirection),
        arrival: base.anchors.arrival, planet: base.anchors.planet, sun: base.anchors.sun),
      player: .init(
        identity: .init(system: system, visit: base.visit, entity: player.identity.entity),
        hull: player.hull, position: player.position, orientation: player.orientation,
        velocity: player.velocity, energy: player.energy, maximumEnergy: player.maximumEnergy,
        maximumSpeedUnitsPerSecond: player.maximumSpeedUnitsPerSecond,
        legal: player.legal, npc: nil, rock: nil, payload: nil),
      actors: [], protection: base.protection, budget: base.budget,
      perceptionRadius: base.perceptionRadius)
  }

  private func requests(seed: UInt64) -> [SpawnRequest] {
    var director = EncounterDirector(context: context(seed: seed))
    return director.advance(context: context(seed: seed, time: 120)).batches.flatMap(\.requests)
  }

  @Test func generatedCraftCarryActualFactsCatalogueAndRoleLoadoutWithoutStockResources() throws {
    var roles: Set<NPCRole> = []
    var commodities: Set<CommodityIdentity> = []
    for seed in 1...128 {
      for request in requests(seed: UInt64(seed)) {
        let npc = try #require(request.npc)
        roles.insert(npc.role)
        #expect(npc.legalProvenance == .generated)
        #expect(npc.cargoProvenance == .generated)
        #expect(npc.routeProvenance == .generated)
        #expect(npc.resources == nil)
        #expect(npc.hasFuelScoops == (npc.role == .miner || npc.role == .pirate))
        let ship = try #require(ShipCatalogue.nativeShip(request.hull))
        #expect(request.catalogueShipID == ship.id)
        #expect(request.priority == .ordinary && request.identity.producer == .ambient)
        #expect(request.rock == nil && request.payload == nil)
        #expect(npc.origin.galaxy == 5 && npc.destination.galaxy == 5)
        #expect(npc.origin != npc.destination)
        #expect(npc.origin == request.identity.system || npc.destination == request.identity.system)
        #expect((0..<256).contains(npc.origin.system) && (0..<256).contains(npc.destination.system))
        if npc.role == .pirate {
          #expect(npc.legal == LegalRecord(value: 16, bountyTenths: 50))
        } else {
          #expect(npc.legal == LegalRecord())
        }
        if npc.role == .trader {
          #expect(npc.ordinaryCargo.count == 1)
          for cargo in npc.ordinaryCargo {
            commodities.insert(cargo.commodity)
            #expect(cargo.valid && (1...12).contains(cargo.quantity))
            #expect(cargo.commodity.unit == Commodity.all[cargo.commodity.rawValue].unit)
            if [.gold, .platinum].contains(cargo.commodity) {
              #expect(cargo.commodity.unit == "kg" && cargo.tonnes == 0)
            } else {
              #expect(cargo.commodity.unit == "t" && cargo.tonnes == cargo.quantity)
            }
          }
        } else {
          #expect(npc.ordinaryCargo.isEmpty)
        }
      }
    }
    #expect(roles == [.trader, .miner, .pirate])
    #expect(commodities.contains(.gold) && commodities.contains(.platinum))
  }

  @Test func generatedFactsReplayWithThePendingRequestAndPreserveDecisionSchedule() throws {
    let seed: UInt64 = 17
    var whole = EncounterDirector(context: context(seed: seed))
    let plan = whole.advance(context: context(seed: seed, time: 120))
    #expect(!plan.batches.isEmpty)
    var partitioned = EncounterDirector(context: context(seed: seed))
    var batches: [SpawnBatch] = []
    for time in 1...120 {
      batches += partitioned.advance(context: context(seed: seed, time: Double(time))).batches
    }
    #expect(batches == plan.batches)
    #expect(partitioned == whole)
    var restored = try JSONDecoder().decode(
      EncounterDirector.self, from: JSONEncoder().encode(whole))
    #expect(restored == whole)
    #expect(restored.pendingRequests == plan.batches.flatMap(\.requests))
    #expect(
      restored.advance(context: context(seed: seed, time: 160))
        == whole.advance(context: context(seed: seed, time: 160)))
  }
}
