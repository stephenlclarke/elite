import Foundation
import Testing

@testable import EliteCore

struct MiningLedgerTests {
  @Test func destroyedOreStaysSettledAfterSaveAndSceneRebuild() throws {
    var ledger = MiningLedger(seed: 42)
    guard case .extracted(let pods) = ledger.hit(rock: rock(), incident: incident(1), damage: 200)
    else {
      Issue.record("Missing ore")
      return
    }
    let pod = try #require(pods.first)
    var protection = MissionProtection()
    protection.protectedPayloads.insert(pod.identity)
    let protected = ledger.destroy(payload: pod.identity, protection: protection)
    #expect(!protected)
    let removed = ledger.destroy(payload: pod.identity)
    let duplicate = ledger.destroy(payload: pod.identity)
    #expect(removed && !duplicate)
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    ledger.resetPhysicalBindings(system: system)
    #expect(ledger.isDepleted(rock().identity))
    #expect(!ledger.pendingPayloads.contains { $0.identity == pod.identity })
    var cargo = Array(repeating: 0, count: 17)
    #expect(
      ledger.collect(
        payload: pod.identity, into: &cargo, freeTonnes: 100,
        hasScoops: true, approachAllowed: true, protection: .init()) == .refused(.unavailable))
    #expect(cargo.allSatisfy { $0 == 0 })
  }
  private let system = SystemIdentity(galaxy: 0, system: 7)
  private func rock(_ index: UInt16 = 0) -> MiningRock {
    MiningRock(
      identity: RockIdentity(system: system, field: 0, rock: index),
      position: Vector3(100, 200, 300), radius: 40, energy: 150)
  }
  private func incident(
    _ id: UInt64, kind: AttackKind = .laser,
    laser: LaserKind? = .mining, mount: LaserMount = .front
  ) -> CombatIncident {
    let actor = ActorIdentity(system: system, visit: 1, entity: 1)
    return CombatIncident(
      id: id, physicalTime: Double(id),
      origin: AttackOrigin(
        emissionID: id, owner: actor, ordnance: nil, emittedAt: Double(id),
        ownerLegalAtEmission: LegalRecord()), victim: nil, kind: kind, outcome: .hit,
      position: Vector3(100, 200, 300), victimLegalBeforeAttack: nil, firstAggressor: nil,
      victimRole: nil, victimIsStation: false, laser: laser, mount: mount)
  }

  @Test func allMountsExtractOnceAndRoundTrip() throws {
    for mount in LaserMount.allCases {
      var ledger = MiningLedger(seed: 42)
      #expect(
        ledger.hit(rock: rock(), incident: incident(1, mount: mount), damage: 50) == .damaged(100))
      #expect(ledger.hit(rock: rock(), incident: incident(1, mount: mount), damage: 50) == .ignored)
      let restored = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
      #expect(restored == ledger)
      ledger = restored
      #expect(ledger.remainingEnergy(for: rock()) == 100)
      guard
        case .extracted(let payloads) = ledger.hit(
          rock: rock(), incident: incident(2, mount: mount), damage: 100)
      else {
        Issue.record("Mining did not extract")
        continue
      }
      #expect((1...7).contains(payloads.count))
      #expect(
        payloads.filter { $0.amount.commodity == .minerals }.allSatisfy { $0.amount.quantity == 1 })
      #expect(ledger.hit(rock: rock(), incident: incident(3), damage: 200) == .ignored)
      ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
      var cargo = Array(repeating: 0, count: 17)
      let payload = try #require(payloads.first)
      #expect(
        ledger.collect(
          payload: payload.identity, into: &cargo, freeTonnes: 10,
          hasScoops: true, approachAllowed: true, protection: MissionProtection())
          == .collected(payload.amount))
      #expect(
        ledger.collect(
          payload: payload.identity, into: &cargo, freeTonnes: 10,
          hasScoops: true, approachAllowed: true, protection: MissionProtection())
          == .refused(.unavailable))
      ledger.depart(system: system)
      #expect(ledger.pendingPayloads.isEmpty)
      #expect(ledger.isDepleted(rock().identity))
    }
  }

  @Test func ordinaryWeaponsDestroyWithoutOre() {
    for kind in [AttackKind.laser, .bomb, .missile, .plasma, .collision] {
      var ledger = MiningLedger()
      #expect(
        ledger.hit(rock: rock(), incident: incident(1, kind: kind, laser: .pulse), damage: 200)
          == .destroyed)
      #expect(ledger.pendingPayloads.isEmpty)
      #expect(ledger.isDepleted(rock().identity))
    }
    var ledger = MiningLedger()
    #expect(ledger.hit(rock: rock(), incident: incident(1), damage: .nan) == .ignored)
    #expect(ledger.hit(rock: rock(), incident: incident(1), damage: -1) == .ignored)
  }

  @Test func cargoUnitsProtectionAndAtomicRefusals() {
    var cargo = Array(repeating: 0, count: 17)
    let identity = PayloadIdentity.ore(rock().identity, fragment: 0)
    let mineral = TypedCargoPayload(
      identity: identity, amount: .init(commodity: .minerals, quantity: 3),
      position: Vector3(0, 0, 0))
    #expect(
      mineral.collect(
        into: &cargo, freeTonnes: 2, hasScoops: true,
        approachAllowed: true, protection: MissionProtection()) == .refused(.fullHold))
    #expect(cargo.allSatisfy { $0 == 0 })
    #expect(
      mineral.collect(
        into: &cargo, freeTonnes: 10, hasScoops: false,
        approachAllowed: true, protection: MissionProtection()) == .refused(.noScoops))
    #expect(
      mineral.collect(
        into: &cargo, freeTonnes: 10, hasScoops: true,
        approachAllowed: false, protection: MissionProtection()) == .refused(.invalidApproach))
    for commodity in [CommodityIdentity.gold, .platinum, .gemstones] {
      let rare = TypedCargoPayload(
        identity: identity, amount: .init(commodity: commodity, quantity: 1),
        position: Vector3(0, 0, 0))
      #expect(
        rare.collect(
          into: &cargo, freeTonnes: 0, hasScoops: true,
          approachAllowed: true, protection: MissionProtection()) == .collected(rare.amount))
    }
    var protection = MissionProtection()
    protection.protectedPayloads.insert(identity)
    #expect(
      mineral.collect(
        into: &cargo, freeTonnes: 10, hasScoops: true,
        approachAllowed: true, protection: protection) == .refused(.protectedPayload))
    let mission = TypedCargoPayload(
      identity: .mission(instance: UUID(), payload: "protected"),
      amount: mineral.amount, position: mineral.position)
    #expect(
      mission.collect(
        into: &cargo, freeTonnes: 10, hasScoops: true,
        approachAllowed: true, protection: MissionProtection()) == .refused(.protectedPayload))
    let wreck = WreckIdentity(system: system, site: 1, lineage: 2)
    let lot = SalvageLotIdentity(section: WreckSectionIdentity(wreck: wreck, section: 0), lot: 0)
    let salvage = TypedCargoPayload(
      identity: .salvage(lot), amount: mineral.amount,
      position: mineral.position)
    #expect(
      salvage.collect(
        into: &cargo, freeTonnes: 10, hasScoops: true,
        approachAllowed: true, protection: MissionProtection()) == .refused(.protectedPayload))
    cargo[CommodityIdentity.minerals.rawValue] = Int.max / 17
    #expect(
      mineral.collect(
        into: &cargo, freeTonnes: 10, hasScoops: true,
        approachAllowed: true, protection: MissionProtection()) == .refused(.invalidCargo))
  }

  @Test func yieldsAreStableAndRareUnitsCorrect() {
    var rareCount = 0
    var alloyCount = 0
    for seed in 0..<1000 {
      var first = MiningLedger(seed: UInt64(seed))
      var second = MiningLedger(seed: UInt64(seed))
      let result = first.hit(rock: rock(), incident: incident(1), damage: 200)
      #expect(result == second.hit(rock: rock(), incident: incident(1), damage: 200))
      for payload in first.pendingPayloads {
        if payload.amount.commodity == .alloys { alloyCount += 1 }
        if payload.amount.commodity == .gold || payload.amount.commodity == .platinum {
          rareCount += 1
          #expect(payload.amount.quantity == 1)
          #expect(payload.amount.tonnes == 0)
        }
      }
    }
    #expect((5...45).contains(rareCount))
    #expect((140...260).contains(alloyCount))
  }
  @Test func admissionRefusalCullAndSettlementKeepOnePayload() throws {
    var ledger = MiningLedger()
    _ = ledger.hit(rock: rock(), incident: incident(1), damage: 200)
    let actor = ActorIdentity(system: system, visit: 1, entity: 9)
    let station = StationAnchor(
      identity: actor, position: Vector3(0, 0, 0),
      orientation: Basis3(), exitPosition: Vector3(0, 0, 600), exitDirection: Vector3(0, 0, 1))
    let anchors = SystemAnchors(
      system: system, station: station, arrival: Vector3(0, 0, 12000),
      planet: SphereAnchor(position: Vector3(20000, 0, 0), radius: 1000),
      sun: SphereAnchor(position: Vector3(50000, 0, 0), radius: 1000))
    let player = ActorSnapshot(
      identity: actor, hull: .cobra, position: Vector3(0, 0, 0),
      orientation: Basis3(), velocity: Vector3(0, 0, 0), energy: 100, maximumEnergy: 100,
      maximumSpeedUnitsPerSecond: 144, legal: LegalRecord(), npc: nil, rock: nil, payload: nil)
    let context = EncounterContext(
      system: system, seed: 0, government: 0, visit: 1, revision: 1,
      physicalTime: 1, anchors: anchors, player: player, actors: [],
      protection: MissionProtection(), budget: AdmissionBudget(), perceptionRadius: 3000)
    let fields = [MiningField(position: rock().position, rocks: [rock()])]
    let requests = ledger.pendingSpawnRequests(context: context, fields: fields)
    #expect(!requests.isEmpty)
    #expect(requests.allSatisfy { $0.identity.producer == .mining })
    #expect(ledger.pendingSpawnRequests(context: context, fields: fields).isEmpty)
    ledger.acknowledge(
      receipts: requests.map {
        SpawnReceipt(request: $0.identity, actor: nil, refusal: .populationLimit)
      })
    let retry = ledger.pendingSpawnRequests(context: context, fields: fields)
    #expect(retry.count == requests.count)
    ledger.acknowledge(
      receipts: retry.enumerated().map { index, request in
        SpawnReceipt(
          request: request.identity,
          actor: .init(system: system, visit: 1, entity: actor.entity + UInt64(index)), refusal: nil
        )
      })
    #expect(ledger.pendingSpawnRequests(context: context, fields: fields).isEmpty)
    for index in retry.indices {
      ledger.cull(actor: .init(system: system, visit: 1, entity: actor.entity + UInt64(index)))
    }
    #expect(ledger.pendingSpawnRequests(context: context, fields: fields).count == requests.count)
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    ledger.resetPhysicalBindings(system: system)
    let restoredRequests = ledger.pendingSpawnRequests(context: context, fields: fields)
    #expect(restoredRequests.count == requests.count)
    let stale = ActorIdentity(system: system, visit: 2, entity: 99)
    ledger.acknowledge(
      receipts: restoredRequests.map {
        SpawnReceipt(request: $0.identity, actor: stale, refusal: nil)
      })
    #expect(ledger.pendingSpawnRequests(context: context, fields: fields).count == requests.count)
    var cargo = Array(repeating: 0, count: 17)
    let item = try #require(ledger.pendingPayloads.first)
    #expect(
      ledger.collect(
        payload: item.identity, into: &cargo, freeTonnes: 0,
        hasScoops: true, approachAllowed: true, protection: MissionProtection())
        == .refused(.fullHold))
    #expect(ledger.pendingPayloads.contains(item))
    #expect(
      ledger.collect(
        payload: item.identity, into: &cargo, freeTonnes: 10,
        hasScoops: true, approachAllowed: true, protection: MissionProtection())
        == .collected(item.amount))
    #expect(
      ledger.collect(
        payload: item.identity, into: &cargo, freeTonnes: 10,
        hasScoops: true, approachAllowed: true, protection: MissionProtection())
        == .refused(.unavailable))
  }

  @Test func wreckUsesNativeManifestAndHonoursMissionCustody() {
    let actor = ActorIdentity(system: system, visit: 1, entity: 8)
    let manifest = [
      CommodityAmount(commodity: .computers, quantity: 2),
      CommodityAmount(commodity: .gold, quantity: 7),
      CommodityAmount(commodity: .food, quantity: -1),
    ]
    let payloads = TypedCargoPayload.wreck(
      actor: actor, manifest: manifest,
      position: Vector3(1, 2, 3), protection: MissionProtection())
    #expect(payloads.map(\.amount) == Array(manifest.prefix(2)))
    var protection = MissionProtection()
    protection.protectedActors.insert(actor)
    #expect(
      TypedCargoPayload.wreck(
        actor: actor, manifest: manifest,
        position: Vector3(1, 2, 3), protection: protection
      ).isEmpty)
    protection.protectedActors.remove(actor)
    protection.protectedPayloads.insert(.wreck(actor, lot: 1))
    #expect(
      TypedCargoPayload.wreck(
        actor: actor, manifest: manifest,
        position: Vector3(1, 2, 3), protection: protection
      ).map(\.amount) == [manifest[0]])
  }

  @Test func capacityRefusalDoesNotLoseOreOrResetDepletion() {
    var ledger = MiningLedger()
    var refused: MiningRock?
    for index in 0..<300 {
      let identity = RockIdentity(
        system: SystemIdentity(galaxy: 0, system: index / 48),
        field: UInt16((index % 48) / 12), rock: UInt16(index % 12))
      let item = MiningRock(
        identity: identity, position: Vector3(100, 200, 300), radius: 40, energy: 150)
      if ledger.hit(rock: item, incident: incident(UInt64(index + 1)), damage: 200)
        == .capacityRefused
      {
        refused = item
        break
      }
    }
    guard let item = refused else {
      Issue.record("Pending bound was not enforced")
      return
    }
    #expect(ledger.pendingPayloads.count <= MiningLedger.maximumPending)
    #expect(!ledger.isDepleted(item.identity))
    #expect(ledger.remainingEnergy(for: item) == item.energy)
    for index in 0...6 { ledger.depart(system: SystemIdentity(galaxy: 0, system: index)) }
    #expect(ledger.pendingPayloads.isEmpty)
    guard case .extracted = ledger.hit(rock: item, incident: incident(1000), damage: 200)
    else {
      Issue.record("Refused extraction could not be retried")
      return
    }
    #expect(ledger.isDepleted(item.identity))
  }

}

extension MiningLedgerTests {
  @Test(arguments: Array(0..<AsteroidBeltDefinition.chunkUnits.count))
  func nativeChunkBirthLayoutPreservesIssuedMassCentroidAndMomentum(index: Int) throws {
    let identity = RockIdentity(
      system: system, field: index == 4 ? 5 : 4, rock: index == 4 ? 0 : UInt16(index))
    let chunk = try #require(AsteroidBeltDefinition.chunk(for: identity))
    let source = MiningRock(
      identity: identity, position: .init(10000.25, -20000.5, 30000.75),
      radius: chunk.radius, energy: chunk.energy)
    var ledger = MiningLedger(seed: 42)
    guard
      case .extracted(let pods) = ledger.hit(
        rock: source, incident: incident(1), damage: chunk.energy)
    else {
      Issue.record("Actual native chunk did not release its full output")
      return
    }
    let radius = try #require(Mesh.hull(.cargo).vertices.map(\.length).max())
    #expect(pods.count == chunk.units && Set(pods.map(\.identity)).count == chunk.units)
    var positionSum = Vector3(0, 0, 0)
    var oldPositionSum = Vector3(0, 0, 0)
    var momentum = Vector3(0, 0, 0)
    var oldMomentum = Vector3(0, 0, 0)
    var angular = Vector3(0, 0, 0)
    var oldAngular = Vector3(0, 0, 0)
    for (i, pod) in pods.enumerated() {
      let velocity = Vector3(Double(i % 5), 2, 3)
      let oldOffset = Vector3(Double(i % 5) * 12, Double(i / 5) * 12, 10)
      #expect(pod.identity == .ore(identity, fragment: UInt16(i)))
      #expect(pod.amount == .init(commodity: chunk.content.commodity, quantity: 1))
      #expect(pod.velocity == velocity && pod.position.finite)
      positionSum = positionSum + (pod.position - source.position)
      oldPositionSum = oldPositionSum + oldOffset
      momentum = momentum + pod.velocity
      oldMomentum = oldMomentum + velocity
      angular = angular + (pod.position - source.position).cross(pod.velocity)
      oldAngular = oldAngular + oldOffset.cross(velocity)
      for other in pods.dropFirst(i + 1) {
        #expect((pod.position - other.position).length > 2 * radius + 8)
      }
    }
    #expect((positionSum - oldPositionSum).length < 1e-7)
    #expect(momentum == oldMomentum && (angular - oldAngular).length < 1e-6)
    if chunk.units == 20 {
      #expect(chunk.content.commodity == .minerals)
      #expect(pods.reduce(0) { $0 + $1.amount.quantity } == 20)
      #expect(pods.reduce(0) { $0 + $1.amount.tonnes } == 20)
    }
    let saved = try JSONEncoder().encode(ledger)
    let cold = try JSONDecoder().decode(MiningLedger.self, from: saved)
    #expect(cold.pendingPayloads == ledger.pendingPayloads)
    let retained = ledger.pendingPayloads
    let nextIdentity = RockIdentity(system: system, field: 6, rock: UInt16(index))
    let nextChunk = try #require(AsteroidBeltDefinition.chunk(for: nextIdentity))
    let nextRock = MiningRock(
      identity: nextIdentity, position: .init(50000, 60000, 70000),
      radius: nextChunk.radius, energy: nextChunk.energy)
    guard
      case .extracted = ledger.hit(
        rock: nextRock, incident: incident(2), damage: nextChunk.energy)
    else {
      Issue.record("Second genuine chunk was not extracted")
      return
    }
    for pod in retained { #expect(ledger.pendingPayloads.contains(pod)) }
  }
}
