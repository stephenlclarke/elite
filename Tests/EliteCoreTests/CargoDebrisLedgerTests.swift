import Foundation
import Testing

@testable import EliteCore

// Evaluate mutating ledger calls before the assertion macro captures their result.
private func debrisExpect(_ condition: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
  #expect(condition, sourceLocation: sourceLocation)
}

private func debrisRequire<T>(_ value: T?) throws -> T { try #require(value) }

private func debrisActor(
  _ entity: UInt64 = 2, manifest: [CommodityAmount] = [],
  position: Vector3 = .init(100, 200, 300), velocity: Vector3 = .init(0, 0, 0),
  role: NPCRole? = .trader, energy: Double = 0
) -> ActorSnapshot {
  .init(
    identity: crimeTestID(entity), hull: .cobra, position: position, orientation: Basis3(),
    velocity: velocity, energy: energy, maximumEnergy: 100, maximumSpeedUnitsPerSecond: 576,
    legal: LegalRecord(),
    npc: role.map { .init(role: $0, origin: crimeTestSystem, destination: crimeTestSystem) },
    rock: nil, payload: nil, ordinaryCargo: manifest)
}

private func debrisRegister(
  _ ledger: inout CargoDebrisLedger, actor: ActorSnapshot = debrisActor(),
  manifest: [CommodityAmount], id: UInt64 = 1, time: Double = 0,
  protection: MissionProtection = .init()
) -> CargoDeathRegistration {
  ledger.registerDeath(
    actor: actor, manifest: manifest, settlementID: id, physicalTime: time, protection: protection)
}

private func debrisCollect(
  _ ledger: inout CargoDebrisLedger, payload: PayloadIdentity, cargo: inout [Int],
  free: Int = 1_000_000
) -> CargoCollectionReceipt {
  ledger.collect(
    payload: payload, into: &cargo, freeTonnes: free, hasScoops: true, approachAllowed: true,
    protection: .init())
}

struct CargoDebrisLedgerTests {
  @Test func exactManifestIsCanonicalChunkedAndPinnedBeforeAdmissionWithoutFoodFallback() throws {
    var ledger = CargoDebrisLedger()
    let manifest: [CommodityAmount] = [
      .init(commodity: .gold, quantity: 1001), .init(commodity: .food, quantity: 3),
      .init(commodity: .gemstones, quantity: 1_000_001), .init(commodity: .food, quantity: 4),
    ]
    debrisExpect(debrisRegister(&ledger, manifest: manifest) == .registered(lots: 6))
    debrisExpect(
      ledger.pendingPayloads.map(\.amount) == [
        .init(commodity: .food, quantity: 5), .init(commodity: .food, quantity: 2),
        .init(commodity: .gold, quantity: 1000), .init(commodity: .gold, quantity: 1),
        .init(commodity: .gemstones, quantity: 1_000_000),
        .init(commodity: .gemstones, quantity: 1),
      ])
    debrisExpect(
      ledger.pendingPayloads.enumerated().allSatisfy {
        $0.element.identity == .wreck(crimeTestID(2), lot: UInt16($0.offset))
      })
    let before = ledger.pendingPayloads
    ledger = try JSONDecoder().decode(CargoDebrisLedger.self, from: JSONEncoder().encode(ledger))
    debrisExpect(
      debrisRegister(&ledger, manifest: [.init(commodity: .narcotics, quantity: 100)])
        == .alreadyRegistered)
    debrisExpect(ledger.pendingPayloads == before && ledger.valid)
    var empty = CargoDebrisLedger()
    debrisExpect(debrisRegister(&empty, manifest: []) == .registered(lots: 0))
    debrisExpect(empty.pendingPayloads.isEmpty)
  }

  @Test func largeManifestStreamsThroughBoundedPendingStorageWithoutTruncatingAnyQuantity() {
    var ledger = CargoDebrisLedger()
    debrisExpect(
      debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: 5000)])
        == .registered(lots: 1000))
    debrisExpect(ledger.pendingPayloads.count == CargoDebrisLedger.maximumPending)
    debrisExpect(
      ledger.unissuedManifest(for: crimeTestID(2)) == [.init(commodity: .food, quantity: 3720)])
    var cargo = Array(repeating: 0, count: 17)
    var lots: Set<PayloadIdentity> = []
    while !ledger.pendingPayloads.isEmpty {
      for item in ledger.pendingPayloads {
        debrisExpect(lots.insert(item.identity).inserted)
        debrisExpect(
          debrisCollect(&ledger, payload: item.identity, cargo: &cargo) == .collected(item.amount))
      }
      _ = ledger.pendingSpawnRequests(context: crimeTestContext(0))
      debrisExpect(ledger.pendingPayloads.count <= CargoDebrisLedger.maximumPending && ledger.valid)
    }
    debrisExpect(lots.count == 1000 && cargo[CommodityIdentity.food.rawValue] == 5000)
    debrisExpect(ledger.unissuedManifest(for: crimeTestID(2)).isEmpty)
    debrisExpect(
      debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: 5000)])
        == .alreadyRegistered)
  }

  @Test func nativeUnitsFullHoldAndCollectionRefusalsAreAtomic() throws {
    var ledger = CargoDebrisLedger()
    _ = debrisRegister(
      &ledger,
      manifest: [
        .init(commodity: .food, quantity: 5), .init(commodity: .gold, quantity: 1000),
        .init(commodity: .gemstones, quantity: 1_000_000),
      ])
    let food = try debrisRequire(ledger.pendingPayloads.first { $0.amount.commodity == .food })
    var cargo = Array(repeating: 0, count: 17)
    debrisExpect(
      debrisCollect(&ledger, payload: food.identity, cargo: &cargo, free: 4) == .refused(.fullHold))
    debrisExpect(cargo.allSatisfy { $0 == 0 } && ledger.pendingPayloads.count == 3)
    for (scoops, approach, reason) in [
      (false, true, CargoCollectionRefusal.noScoops), (true, false, .invalidApproach),
    ] {
      let receipt = ledger.collect(
        payload: food.identity, into: &cargo, freeTonnes: 10, hasScoops: scoops,
        approachAllowed: approach, protection: .init())
      debrisExpect(receipt == .refused(reason) && cargo.allSatisfy { $0 == 0 })
    }
    for item in ledger.pendingPayloads where item.amount.commodity != .food {
      debrisExpect(
        debrisCollect(&ledger, payload: item.identity, cargo: &cargo, free: 0)
          == .collected(item.amount))
    }
    debrisExpect(cargo[13] == 1000 && cargo[15] == 1_000_000 && cargo[0] == 0)
    cargo[0] = Int.max / 17
    debrisExpect(
      debrisCollect(&ledger, payload: food.identity, cargo: &cargo) == .refused(.invalidCargo))
    debrisExpect(ledger.pendingPayloads.count == 1)
  }

  @Test func admissionRefusalSaveReloadAndLateReceiptsKeepStableOffersUnderSharedCargoCap() throws {
    var ledger = CargoDebrisLedger()
    _ = debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: 250)])
    let context = crimeTestContext(0, budget: .init(active: [.cargo: 4], total: 4))
    let first = ledger.pendingSpawnRequests(context: context)
    debrisExpect(
      first.count == 28 && first.allSatisfy { $0.identity.producer == .cargo && $0.hull == .cargo })
    ledger.acknowledge(
      receipts: first.map { .init(request: $0.identity, actor: nil, refusal: .unsafePosition) })
    ledger = try JSONDecoder().decode(CargoDebrisLedger.self, from: JSONEncoder().encode(ledger))
    debrisExpect(ledger.pendingSpawnRequests(context: context) == first)
    debrisExpect(
      ledger.pendingSpawnRequests(
        context: crimeTestContext(0, budget: .init(active: [.cargo: 32], total: 32))
      ).isEmpty)
    debrisExpect(ledger.pendingSpawnRequests(context: context) == first)
    let offered = try debrisRequire(first.first)
    ledger.acknowledge(receipts: [
      .init(request: offered.identity, actor: crimeTestID(500, visit: 2), refusal: nil)
    ])
    debrisExpect(ledger.pendingSpawnRequests(context: context) == first)
    let admitted = SpawnReceipt(request: offered.identity, actor: crimeTestID(500), refusal: nil)
    ledger.acknowledge(receipts: [admitted, admitted])
    let next = ledger.pendingSpawnRequests(
      context: crimeTestContext(0, budget: .init(active: [.cargo: 5], total: 5)))
    debrisExpect(
      next.count == 27 && !next.contains { $0.payload == offered.payload } && ledger.valid)
  }

  @Test func physicalWorldPoseSurvivesCullAndResumeAndOldAdmissionCannotBindItAgain() throws {
    var ledger = CargoDebrisLedger()
    _ = debrisRegister(
      &ledger, actor: debrisActor(velocity: .init(10, 0, 0)),
      manifest: [.init(commodity: .food, quantity: 1)], time: 5)
    let request = try debrisRequire(ledger.pendingSpawnRequests(context: crimeTestContext(5)).first)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(500), refusal: nil)
    ledger.acknowledge(receipts: [receipt])
    debrisExpect(
      ledger.updatePhysicalPose(
        actor: crimeTestID(500), position: .init(1000, 2000, 3000), velocity: .init(4, 5, 6),
        physicalTime: 10))
    debrisExpect(
      !ledger.updatePhysicalPose(
        actor: crimeTestID(500), position: .init(0, 0, 0), velocity: .init(0, 0, 0), physicalTime: 9
      ))
    ledger.cull(actor: crimeTestID(500))
    ledger = try JSONDecoder().decode(CargoDebrisLedger.self, from: JSONEncoder().encode(ledger))
    let resumed = try debrisRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(12)).first)
    debrisExpect(resumed.payload == request.payload && resumed.identity != request.identity)
    debrisExpect(resumed.position == .init(1008, 2010, 3012) && resumed.velocity == .init(4, 5, 6))
    ledger.acknowledge(receipts: [receipt])
    debrisExpect(
      ledger.pendingSpawnRequests(context: crimeTestContext(12)).first?.identity == resumed.identity
    )
  }

  @Test func collectionAndDestructionAreTerminalWhileDockResetAndCullKeepCargo() throws {
    var ledger = CargoDebrisLedger()
    _ = debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: 20)])
    let requests = ledger.pendingSpawnRequests(context: crimeTestContext(0))
    ledger.acknowledge(
      receipts: requests.enumerated().map {
        .init(
          request: $0.element.identity, actor: crimeTestID(500 + UInt64($0.offset)), refusal: nil)
      })
    let first = try debrisRequire(requests.first?.payload)
    ledger.cull(actor: crimeTestID(500))
    debrisExpect(ledger.pendingPayloads.count == 4)
    var cargo = Array(repeating: 0, count: 17)
    debrisExpect(
      debrisCollect(&ledger, payload: first, cargo: &cargo)
        == .collected(.init(commodity: .food, quantity: 5)))
    debrisExpect(debrisCollect(&ledger, payload: first, cargo: &cargo) == .refused(.unavailable))
    let second = try debrisRequire(requests[1].payload)
    debrisExpect(ledger.destroy(payload: second) && !ledger.destroy(payload: second))
    ledger.resetPhysicalBindings(system: crimeTestSystem)
    let loaded = ledger.pendingSpawnRequests(context: crimeTestContext(0, visit: 2))
    debrisExpect(loaded.count == 2 && loaded.allSatisfy { $0.identity.visit == 2 })
    debrisExpect(!loaded.contains { $0.payload == first || $0.payload == second } && cargo[0] == 5)
    ledger.depart(system: crimeTestSystem)
    debrisExpect(
      ledger.pendingPayloads.isEmpty && ledger.unissuedManifest(for: crimeTestID(2)).isEmpty)
    debrisExpect(
      debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: 20)])
        == .alreadyRegistered)
  }

  @Test func protectedMissionActorsAndPayloadsNeverEnterOrdinaryCargoSettlement() throws {
    let manifest: [CommodityAmount] = [.init(commodity: .food, quantity: 1)]
    var ledger = CargoDebrisLedger()
    debrisExpect(
      debrisRegister(&ledger, actor: debrisActor(role: .mission), manifest: manifest)
        == .refused(.protectedSource))
    var protected = MissionProtection()
    protected.protectedActors.insert(crimeTestID(2))
    debrisExpect(
      debrisRegister(&ledger, manifest: manifest, protection: protected)
        == .refused(.protectedSource))
    protected.protectedActors = []
    protected.protectedPayloads.insert(.wreck(crimeTestID(2), lot: 0))
    debrisExpect(
      debrisRegister(&ledger, manifest: manifest, protection: protected)
        == .refused(.protectedSource))
    debrisExpect(ledger.pendingPayloads.isEmpty)
    _ = debrisRegister(&ledger, manifest: manifest)
    let item = try debrisRequire(ledger.pendingPayloads.first)
    var cargo = Array(repeating: 0, count: 17)
    debrisExpect(
      ledger.collect(
        payload: item.identity, into: &cargo, freeTonnes: 5, hasScoops: true, approachAllowed: true,
        protection: protected) == .refused(.protectedPayload))
    debrisExpect(!ledger.destroy(payload: item.identity, protection: protected))
    debrisExpect(
      ledger.pendingSpawnRequests(context: crimeTestContext(0, protection: protected)).isEmpty)
    debrisExpect(cargo.allSatisfy { $0 == 0 } && ledger.pendingPayloads.count == 1)
    debrisExpect(!ledger.destroy(payload: .mission(instance: UUID(), payload: "person")))
  }

  @Test func invalidOrUnrepresentableManifestRejectsAtomicallyAndLiveRemovalIsNotDeath() {
    var ledger = CargoDebrisLedger()
    debrisExpect(
      debrisRegister(
        &ledger, actor: debrisActor(energy: 100), manifest: [.init(commodity: .food, quantity: 1)])
        == .refused(.notDestroyedNPC))
    debrisExpect(
      debrisRegister(&ledger, actor: debrisActor(role: nil), manifest: [])
        == .refused(.notDestroyedNPC))
    debrisExpect(
      debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: -1)])
        == .refused(.invalidManifest))
    debrisExpect(
      debrisRegister(&ledger, actor: debrisActor(position: .init(.infinity, 0, 0)), manifest: [])
        == .refused(.invalidPose))
    debrisExpect(
      debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: 5 * 65536 + 1)])
        == .refused(.unrepresentableManifest))
    debrisExpect(ledger.pendingPayloads.isEmpty && ledger.valid)
    debrisExpect(
      debrisRegister(&ledger, manifest: [.init(commodity: .food, quantity: 5)])
        == .registered(lots: 1))
  }

  @Test func capacityRefusalBlocksLaterDeathsUntilTheSamePinnedEventCanRetry() {
    var ledger = CargoDebrisLedger()
    for id in UInt64(1)...256 {
      debrisExpect(
        debrisRegister(
          &ledger, actor: debrisActor(id + 100), manifest: [.init(commodity: .food, quantity: 1)],
          id: id) == .registered(lots: 1))
    }
    debrisExpect(
      debrisRegister(
        &ledger, actor: debrisActor(999), manifest: [.init(commodity: .gold, quantity: 1)], id: 257)
        == .refused(.capacity))
    debrisExpect(
      debrisRegister(
        &ledger, actor: debrisActor(1000), manifest: [.init(commodity: .food, quantity: 1)], id: 258
      ) == .refused(.earlierSettlement))
    if let first = ledger.pendingPayloads.first {
      debrisExpect(ledger.destroy(payload: first.identity))
    }
    debrisExpect(
      debrisRegister(
        &ledger, actor: debrisActor(999), manifest: [.init(commodity: .gold, quantity: 1)], id: 257)
        == .registered(lots: 1))
    debrisExpect(ledger.pendingPayloads.count == 256 && ledger.valid)
    debrisExpect(
      ledger.pendingPayloads.contains { $0.amount == .init(commodity: .gold, quantity: 1) })
  }

  @Test func settlementReplayBarrierSurvivesBoundedActorTombstoneCompactionAndReload() throws {
    var ledger = CargoDebrisLedger()
    for id in UInt64(1)...400 {
      debrisExpect(
        debrisRegister(&ledger, actor: debrisActor(id), manifest: [], id: id)
          == .registered(lots: 0))
    }
    ledger = try JSONDecoder().decode(CargoDebrisLedger.self, from: JSONEncoder().encode(ledger))
    debrisExpect(
      debrisRegister(
        &ledger, actor: debrisActor(1), manifest: [.init(commodity: .food, quantity: 5)], id: 1)
        == .alreadyRegistered)
    debrisExpect(ledger.pendingPayloads.isEmpty && ledger.valid)
    debrisExpect(
      debrisRegister(
        &ledger, actor: debrisActor(500), manifest: [.init(commodity: .food, quantity: 1)], id: 401)
        == .registered(lots: 1))
  }

  @Test func unboundWorldDriftIsIndependentOfTickPartitionAndSmallerWreckCanIssueNext() throws {
    var one = CargoDebrisLedger()
    var split = CargoDebrisLedger()
    let manifest: [CommodityAmount] = [.init(commodity: .gold, quantity: 1001)]
    let actor = debrisActor(velocity: .init(20, 30, 40))
    _ = debrisRegister(&one, actor: actor, manifest: manifest)
    _ = debrisRegister(&split, actor: actor, manifest: manifest)
    let single = one.pendingSpawnRequests(context: crimeTestContext(10))
    for time in [3.0, 6, 10] {
      _ = split.pendingSpawnRequests(context: crimeTestContext(time))
      split = try JSONDecoder().decode(CargoDebrisLedger.self, from: JSONEncoder().encode(split))
    }
    let partitioned = split.pendingSpawnRequests(context: crimeTestContext(10))
    debrisExpect(single.map(\.identity) == partitioned.map(\.identity))
    debrisExpect(zip(single, partitioned).allSatisfy { ($0.position - $1.position).length < 1e-8 })
    var large = CargoDebrisLedger()
    _ = debrisRegister(&large, manifest: [.init(commodity: .food, quantity: 1500)])
    _ = debrisRegister(
      &large, actor: debrisActor(3), manifest: [.init(commodity: .gold, quantity: 1)], id: 2)
    var cargo = Array(repeating: 0, count: 17)
    let first = try debrisRequire(large.pendingPayloads.first)
    _ = debrisCollect(&large, payload: first.identity, cargo: &cargo)
    let offered = large.pendingSpawnRequests(context: crimeTestContext(0))
    debrisExpect(offered.contains { $0.payload == .wreck(crimeTestID(3), lot: 0) })
    debrisExpect(large.valid)
  }
}
