import Foundation
import Testing

@testable import EliteCore

struct MiningLedgerTests {
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
      physicalTime: 0, anchors: anchors, player: player, actors: [],
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
      receipts: retry.map {
        SpawnReceipt(request: $0.identity, actor: actor, refusal: nil)
      })
    #expect(ledger.pendingSpawnRequests(context: context, fields: fields).isEmpty)
    ledger.cull(actor: actor)
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
