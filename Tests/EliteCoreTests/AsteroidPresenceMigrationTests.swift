import Foundation
import Testing

@testable import EliteCore

private func presenceAnchors(_ identity: SystemIdentity) -> SystemAnchors {
  var flight = FlightSimulationState()
  flight.enter(identity, arriving: false)
  return flight.anchors!
}

private func oldPresenceLedger(_ source: MiningLedger, generation: Int?) throws -> MiningLedger {
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
  object.removeValue(forKey: "legacyClusters")
  object.removeValue(forKey: "presenceOverrides")
  if let generation {
    object["generation"] = generation
  } else {
    object.removeValue(forKey: "generation")
    object.removeValue(forKey: "ringTerminal")
  }
  return try JSONDecoder().decode(
    MiningLedger.self, from: JSONSerialization.data(withJSONObject: object))
}

private func presenceIncident(_ id: UInt64, system: SystemIdentity) -> CombatIncident {
  let origin = AttackOrigin(
    emissionID: id, owner: .init(system: system, visit: 1, entity: 0),
    emittedAt: Double(id), ownerLegalAtEmission: .init())
  return .init(
    id: id, physicalTime: Double(id), origin: origin, victim: nil, kind: .laser, outcome: .hit,
    position: .init(0, 0, 0), victimLegalBeforeAttack: nil, firstAggressor: nil,
    victimRole: nil, victimIsStation: false, laser: .mining, mount: .front)
}

private func presenceContext(_ system: SystemIdentity) -> EncounterContext {
  let player = ActorSnapshot(
    identity: .init(system: system, visit: 1, entity: 0), hull: .cobra,
    position: .init(0, 0, 0), orientation: Basis3(), velocity: .init(0, 0, 0),
    energy: 100, maximumEnergy: 100, maximumSpeedUnitsPerSecond: 144,
    legal: LegalRecord(), npc: nil, rock: nil, payload: nil)
  return EncounterContext(
    system: system, seed: 0, government: 3, visit: 1, revision: 1,
    physicalTime: 0, anchors: presenceAnchors(system), player: player, actors: [],
    protection: MissionProtection(), budget: AdmissionBudget(), perceptionRadius: 3000)
}

struct AsteroidPresenceMigrationTests {
  @Test func allEightEconomiesUseApprovedRatesAndActualWorldsShareFieldPresence() {
    let policy = AsteroidBeltPresencePolicy.economyWeighted
    #expect(
      (0..<8).map { policy.probabilityPercent(economy: $0) } == [80, 80, 80, 60, 40, 20, 20, 20])
    let ledger = MiningLedger()
    #expect(ledger.usesEconomyWeightedPresence && !ledger.retainsLegacyFields)
    var totals = [Int](repeating: 0, count: 8)
    var present = totals
    for galaxy in 0..<8 {
      for system in Universe.systemsIncludingPlugh(number: galaxy) {
        let identity = SystemIdentity(galaxy: galaxy, system: system.id)
        let flag = ledger.ringPresence(system: system, galaxy: galaxy)
        let expected =
          system.id == 7
          || AsteroidBeltDefinition.mixed(
            identity: identity, salt: AsteroidBeltDefinition.seed(for: system)) % 100
            < UInt64(policy.probabilityPercent(economy: system.economy))
        #expect(flag == expected)
        let fields = MiningFields.generate(
          anchors: presenceAnchors(identity), seed: AsteroidBeltDefinition.seed(for: system),
          ringPresent: flag)
        #expect(flag == !fields.isEmpty)
        totals[system.economy] += 1
        if flag { present[system.economy] += 1 }
      }
    }
    #expect(totals.allSatisfy { $0 > 0 })
    let industrialPresent = present[0...2].reduce(0, +)
    let industrialTotal = totals[0...2].reduce(0, +)
    let agriculturalPresent = present[5...7].reduce(0, +)
    let agriculturalTotal = totals[5...7].reduce(0, +)
    #expect(industrialPresent * agriculturalTotal > agriculturalPresent * industrialTotal)
  }

  @Test func currentAbsenceIsPinnedButUnworkedWorldsChangeAndMigrationIsIdempotent() throws {
    let systems = Universe.systemsIncludingPlugh(number: 0)
    let current = try #require(
      systems.first {
        !AsteroidBeltDefinition.isPresent(system: $0, galaxy: 0, policy: .legacyUniform)
          && AsteroidBeltDefinition.isPresent(system: $0, galaxy: 0)
      })
    let unworked = try #require(
      systems.first {
        $0.id != current.id
          && AsteroidBeltDefinition.isPresent(system: $0, galaxy: 0, policy: .legacyUniform)
            != AsteroidBeltDefinition.isPresent(system: $0, galaxy: 0)
      })
    var ledger = try oldPresenceLedger(MiningLedger(), generation: 1)
    #expect(!ledger.usesEconomyWeightedPresence)
    try ledger.migratePresence(current: .init(system: current, galaxy: 0), historical: [])
    #expect(ledger.usesEconomyWeightedPresence && !ledger.retainsLegacyFields)
    #expect(!ledger.ringPresence(system: current, galaxy: 0))
    #expect(
      ledger.ringPresence(system: unworked, galaxy: 0)
        == AsteroidBeltDefinition.isPresent(system: unworked, galaxy: 0))
    let frozen = ledger
    try ledger.migratePresence(current: .init(system: unworked, galaxy: 0), historical: [])
    #expect(ledger == frozen)
    let restored = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored == frozen && !restored.ringPresence(system: current, galaxy: 0))
  }

  @Test func historyMigrationPreservesPartialDepletionAndPendingSourcesAtomically() throws {
    let systems = Universe.systemsIncludingPlugh(number: 0)
    let star = systems[7]
    let identity = SystemIdentity(galaxy: 0, system: star.id)
    let fields = MiningFields.generate(
      anchors: presenceAnchors(identity), seed: AsteroidBeltDefinition.seed(for: star),
      ringPresent: true)
    let rocks = fields.flatMap(\.rocks)
    let partial = try #require(rocks.first)
    let depleted = try #require(rocks.dropFirst().first)
    var ledger = MiningLedger()
    _ = ledger.hit(rock: partial, incident: presenceIncident(1, system: identity), damage: 10)
    _ = ledger.hit(
      rock: depleted, incident: presenceIncident(2, system: identity), damage: depleted.energy)
    let originalContext = presenceContext(identity)
    let context = EncounterContext(
      system: originalContext.system, seed: originalContext.seed,
      government: originalContext.government,
      visit: originalContext.visit, revision: originalContext.revision, physicalTime: 2,
      anchors: originalContext.anchors, player: originalContext.player,
      actors: originalContext.actors,
      protection: originalContext.protection, budget: originalContext.budget,
      perceptionRadius: originalContext.perceptionRadius,
      depletedRocks: originalContext.depletedRocks, miningPresence: originalContext.miningPresence)
    let requests = ledger.pendingSpawnRequests(context: context, fields: fields)
    let admitted = try #require(requests.first)
    let boundPayload = try #require(admitted.payload)
    let boundActor = ActorIdentity(system: identity, visit: 1, entity: 9)
    ledger.acknowledge(receipts: [
      .init(request: admitted.identity, actor: boundActor, refusal: nil)
    ])
    #expect(ledger.pendingSpawnRequests(context: context, fields: fields).isEmpty)
    ledger = try oldPresenceLedger(ledger, generation: 1)
    #expect(ledger.requiredPresencePinSystems == [identity])
    let current = systems[0]
    let before = ledger
    #expect(throws: SaveError.invalidCommander) {
      try ledger.migratePresence(current: .init(system: current, galaxy: 0), historical: [])
    }
    #expect(ledger == before)
    let pin = AsteroidPresencePin(system: star, galaxy: 0)
    #expect(throws: SaveError.invalidCommander) {
      try ledger.migratePresence(
        current: .init(system: current, galaxy: 0), historical: [pin, pin])
    }
    #expect(ledger == before)
    try ledger.migratePresence(current: .init(system: current, galaxy: 0), historical: [pin])
    #expect(ledger.remainingEnergy(for: partial) == before.remainingEnergy(for: partial))
    #expect(
      ledger.isDepleted(depleted.identity) && ledger.pendingPayloads == before.pendingPayloads)
    #expect(ledger.boundActor(for: boundPayload) == boundActor)
    #expect(ledger.pendingSpawnRequests(context: context, fields: fields).isEmpty)
    #expect(ledger.ringPresence(system: star, galaxy: 0) && ledger.valid)
    let restored = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored == ledger)
  }

  @Test func legacyClustersSurviveMigrationAndPlughCurrentIdentityCanBePinned() throws {
    let star = Universe.systemsIncludingPlugh(number: 0)[256]
    let source = Universe.systemsIncludingPlugh(number: 0)[7]
    let identity = SystemIdentity(galaxy: 0, system: source.id)
    let fields = MiningFields.legacyFields(anchors: presenceAnchors(identity), seed: 1)
    let rock = try #require(fields.first?.rocks.first)
    var ledger = MiningLedger()
    _ = ledger.hit(rock: rock, incident: presenceIncident(1, system: identity), damage: rock.energy)
    let cargo = ledger.pendingPayloads
    ledger = try oldPresenceLedger(ledger, generation: nil)
    #expect(ledger.retainsLegacyFields && !ledger.usesEconomyWeightedPresence)
    #expect(ledger.requiredPresencePinSystems == [identity])
    try ledger.migratePresence(
      current: .init(system: star, galaxy: 0), historical: [.init(system: source, galaxy: 0)])
    #expect(ledger.retainsLegacyFields && ledger.usesEconomyWeightedPresence && ledger.valid)
    #expect(ledger.isDepleted(rock.identity) && ledger.pendingPayloads == cargo)
    let generated = MiningFields.generate(
      anchors: presenceAnchors(identity), seed: 1,
      ringPresent: ledger.ringPresence(system: source, galaxy: 0),
      includingLegacy: ledger.retainsLegacyFields)
    #expect(generated.filter { $0.rocks.allSatisfy { $0.identity.field < 4 } } == fields)
    #expect(
      ledger.ringPresence(system: star, galaxy: 0)
        == AsteroidBeltDefinition.isPresent(system: star, galaxy: 0, policy: .legacyUniform))
    let restored = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored.retainsLegacyFields && restored == ledger)
  }

  @Test func newPresenceEvidenceRejectsDuplicateInvalidAndMixedVersionShapes() throws {
    let data = try JSONEncoder().encode(MiningLedger())
    let source = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let key = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(SystemIdentity(galaxy: 0, system: 7)))
    var duplicate = source
    duplicate["presenceOverrides"] = [key, true, key, false]
    #expect(throws: (any Error).self) {
      _ = try JSONDecoder().decode(
        MiningLedger.self, from: JSONSerialization.data(withJSONObject: duplicate))
    }
    var invalid = source
    invalid["presenceOverrides"] = [
      try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(SystemIdentity(galaxy: 8, system: 7))), true,
    ]
    #expect(throws: (any Error).self) {
      _ = try JSONDecoder().decode(
        MiningLedger.self, from: JSONSerialization.data(withJSONObject: invalid))
    }
    var mixed = source
    mixed["generation"] = 1
    #expect(throws: SaveError.invalidCommander) {
      _ = try JSONDecoder().decode(
        MiningLedger.self, from: JSONSerialization.data(withJSONObject: mixed))
    }
    var missing = source
    missing.removeValue(forKey: "legacyClusters")
    #expect(throws: SaveError.invalidCommander) {
      _ = try JSONDecoder().decode(
        MiningLedger.self, from: JSONSerialization.data(withJSONObject: missing))
    }
  }
}
