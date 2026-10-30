import Foundation
import Testing

@testable import L337Core

struct AlienStorageLegacyValidationTests {
  @Test func originalStructuralAndReservedSerialsHaveExactClaims() throws {
    let fixture = try AlienLegacyFixture.make()
    let section = try fixture.section()
    let claims = try fixture.claims(section)
    #expect(claims.count == 2)
    #expect(claims.contains { $0.origin == .structural && $0.identity.lot == 0 })
    #expect(
      claims.contains {
        $0.origin == .planned(itemIndex: 0, chunkOrdinal: 0) && $0.identity.lot == 1
      })
    try fixture.validate(section, claims)
    let encoded = try JSONEncoder().encode(section)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(object["inspectedAt"] == nil)
    #expect(object["issuedAt"] == nil)
    #expect(section.savedPartialWorkSeconds == nil)
    #expect(section.savedLedgerLastOperation == 0)
  }

  @Test func collectedCommodityWithoutReceiptIsHonestlyUnavailable() throws {
    var fixture = try AlienLegacyFixture.make()
    let commodity = try #require(
      fixture.ledger.pendingLots.first {
        if case .commodity = $0.content { return true }
        return false
      })
    try fixture.collect(commodity)
    let section = try fixture.section()
    let claims = try fixture.claims(section)
    let unknown = try #require(claims.first { $0.identity == commodity.identity })
    #expect(unknown.state == .legacyUnavailable)
    let evidence = try fixture.evidence
    #expect(evidence.settlements.isEmpty)
    try fixture.validate(section, claims)
    let lie = AlienLegacyFixture.replacing(
      unknown, state: .pending(lot: commodity, offer: nil, binding: nil))
    #expect(throws: (any Error).self) {
      try fixture.validate(section, claims.map { $0.id == lie.id ? lie : $0 })
    }
  }

  @Test func partialMiningDamageAndAbsentPostBatchWorkStayDistinct() throws {
    let partial = try AlienLegacyFixture.make(elapsed: 0.25, tool: .miningLaser)
    let section = try partial.section()
    #expect(section.savedPartialWorkSeconds == 0.25)
    // The planned old path records discarded technology, but does not insert this marker.
    #expect(!section.savedDamagedTechnology)
    #expect(section.progress.nextLot == 0)
    #expect(section.progress.discarded.contains(true))
    try partial.validate(section, partial.claims(section))
    let complete = try AlienLegacyFixture.make()
    let imported = try complete.section()
    #expect(imported.progress.nextLot > 0)
    #expect(imported.savedPartialWorkSeconds == nil)
    #expect(!imported.savedDamagedTechnology)
    try complete.validate(imported, complete.claims(imported))
  }

  @Test func eightReleaseBatchDoesNotImplyRemainingWorkCompleted() throws {
    let fixture = try AlienLegacyFixture.make(
      definition: nil, roles: [.militaryCapital], manifest: [.init(commodity: .food, quantity: 60)])
    let section = try fixture.section()
    let claims = try fixture.claims(section)
    #expect(claims.count == 8)
    #expect(!section.sectionDepleted)
    #expect(section.savedPartialWorkSeconds == nil)
    try fixture.validate(section, claims)
  }

  @Test func genuineDamageMembershipBeforeInspectionIsRetainedExactly() throws {
    var fixture = try AlienLegacyFixture.make(batches: 0)
    fixture.ledger = SalvageLedger(seed: fixture.seed)
    let profile = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
    let work = fixture.ledger.advance(
      wreck: fixture.plan.section.wreck, section: profile, pose: ShipPose(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .miningLaser,
      elapsed: 0.25, operation: 0,
      conditions: .init(
        toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
        resourcesAvailable: true, ownershipAuthorized: true))
    #expect(work == .progress(seconds: 0.25, required: 1))
    let inspected = fixture.ledger.inspectLoot(
      wreck: fixture.plan.section.wreck, section: profile, source: fixture.plan.source)
    #expect(inspected == fixture.plan)
    let section = try fixture.section()
    #expect(section.savedPartialWorkSeconds == 0.25)
    #expect(section.savedDamagedTechnology)
    #expect(section.progress.discarded == [false])
    try fixture.validate(section, fixture.claims(section))
  }

  @Test func chunkOriginsPreserveOriginalTonnesKilogramsAndGrams() throws {
    let fixture = try AlienLegacyFixture.make(
      definition: nil, roles: [.militaryCapital],
      manifest: [
        .init(commodity: .food, quantity: 27), .init(commodity: .gold, quantity: 2200),
        .init(commodity: .gemstones, quantity: 2_200_000),
      ],
      batches: 3)
    let section = try fixture.section()
    let claims = try fixture.claims(section)
    try fixture.validate(section, claims)
    for commodity in [CommodityIdentity.food, .gold, .gemstones] {
      let emitted = fixture.ledger.pendingLots.compactMap { lot -> CommodityAmount? in
        if case .commodity(let amount) = lot.content, amount.commodity == commodity {
          return amount
        }
        return nil
      }
      let expected = try #require(section.plan.source.manifest?.first { $0.commodity == commodity })
      #expect(emitted.reduce(0) { $0 + $1.quantity } == expected.quantity)
      #expect(emitted.count == (commodity == .food ? 6 : 3))
    }
  }

  @Test func emptyPlanAndDiscardedTechnologyHaveNoFictionalSerial() throws {
    let empty = try AlienLegacyFixture.make(definition: nil, roles: [.asteroid], batches: 0)
    let section = try empty.section()
    #expect(section.plan.items.isEmpty)
    #expect(section.progress.nextLot == 0)
    let claims = try empty.claims(section)
    #expect(claims.isEmpty)
    try empty.validate(section, claims)
    let damaged = try AlienLegacyFixture.make(tool: .miningLaser)
    let damagedSection = try damaged.section()
    let damagedClaims = try damaged.claims(damagedSection)
    #expect(damagedSection.progress.discarded == [true])
    #expect(damagedClaims.allSatisfy { $0.origin == .structural })
    try damaged.validate(damagedSection, damagedClaims)
  }

  @Test func missingDuplicateForeignAndUnknownClaimsAreRejected() throws {
    let fixture = try AlienLegacyFixture.make()
    let section = try fixture.section()
    let claims = try fixture.claims(section)
    let first = try #require(claims.first)
    #expect(throws: (any Error).self) { try fixture.validate(section, Array(claims.dropFirst())) }
    #expect(throws: (any Error).self) { try fixture.validate(section, claims + [first]) }
    let unknown = AlienLegacyFixture.replacing(first, state: .legacyUnavailable)
    #expect(throws: (any Error).self) {
      try fixture.validate(section, claims.map { $0.id == first.id ? unknown : $0 })
    }
    let foreign = AlienStorageLegacyLot(
      id: first.id, owner: AlienLegacyFixture.uuid(999), section: first.section,
      origin: first.origin, identity: first.identity, state: first.state)
    #expect(throws: (any Error).self) {
      try fixture.validate(section, claims.map { $0.id == first.id ? foreign : $0 })
    }
    #expect(try fixture.claims(section) == claims)
  }

  @Test func pendingOfferAndBindingMustMatchExactExport() throws {
    let fixture = try AlienLegacyFixture.make()
    let section = try fixture.section()
    let claims = try fixture.claims(section)
    let claim = try #require(claims.first)
    let original = try fixture.evidence
    let lot = try #require(original.pending.first { $0.identity == claim.identity })
    // A pure custody projection exercises joins; it does not authenticate a native offer.
    let offer = SpawnIdentity(
      system: fixture.plan.section.wreck.system, visit: 4, sequence: 1, member: 0,
      producer: .salvage)
    let evidence = AlienStorageLegacyCustodyEvidence(
      pending: original.pending, stored: [], offers: [offer: lot.identity], bindings: [:],
      settlements: [])
    let offered = AlienLegacyFixture.replacing(
      claim, state: .pending(lot: lot, offer: offer, binding: nil))
    let valid = claims.map { $0.id == claim.id ? offered : $0 }
    try AlienStorageLegacyValidation.validate(
      section: section, lots: valid, evidence: evidence, settlements: .init(headers: [], items: []),
      migrations: [])
    let cleared = AlienLegacyFixture.replacing(
      claim, state: .pending(lot: lot, offer: nil, binding: nil))
    #expect(throws: (any Error).self) {
      try AlienStorageLegacyValidation.validate(
        section: section, lots: valid.map { $0.id == claim.id ? cleared : $0 }, evidence: evidence,
        settlements: .init(headers: [], items: []), migrations: [])
    }
  }
}

/// Actual old producer/collection values, used only for pure migration schema tests.
/// This fixture never supplies a native import seal, actor observation or new property.
struct AlienLegacyFixture {
  struct SavedPlan: Decodable {
    let plan: SalvageLootPlan
    let issued: [Int]
    let discarded: [Bool]
    let nextLot: UInt32
    let destroyed: Bool
    let structuralUnits: Int
    let issuedStructural: Int
    let materialKind: CommodityIdentity?
    var progress: AlienStorageWorldProgress {
      .init(
        issued: issued, discarded: discarded, structuralUnits: structuralUnits,
        issuedStructural: issuedStructural, materialKind: materialKind, nextLot: nextLot)
    }
  }
  struct SavedLedger: Decodable {
    let plans: [WreckSectionIdentity: SavedPlan]
    let work: [WreckSectionIdentity: Double]
    let damagedTechnology: Set<WreckSectionIdentity>
    let offers: [SpawnIdentity: SalvageLotIdentity]
    let bindings: [SalvageLotIdentity: ActorIdentity]
    let settlements: [UUID: SalvageSettlementReceipt]
    let lastOperation: UInt64?
  }
  static func uuid(_ value: UInt64) -> UUID { AlienStorageTestFixture.uuid(value) }
  var ledger: SalvageLedger
  let seed: UInt64
  let plan: SalvageLootPlan
  static let owner = uuid(500)

  static func make(
    site: UInt32 = 501, definition: String? = AlienModuleKind.energyCapacity.definitionID,
    roles: Set<SalvageSourceRole> = [.thargoid, .militaryCapital],
    manifest: [CommodityAmount]? = nil, batches: Int = 1,
    elapsed: Double = 1, tool: SalvageTool = .cutter, system: Int = 7
  ) throws -> Self {
    let identity = WreckSectionIdentity(
      wreck: .init(system: .init(galaxy: 0, system: system), site: site, lineage: 123), section: 1)
    var source = SalvageLootSource(
      roles: roles, legalValue: 0, economy: 3, technology: 12, ownership: .abandoned)
    source.manifest = manifest
    let seed = try #require(
      (UInt64(0)..<2000).first { seed in
        guard let definition else { return true }
        return SalvageLootProfiles.plan(section: identity, seed: seed, source: source).items
          .contains {
            if case .technology(let id, _, _, _) = $0.content { return id == definition }
            return false
          }
      })
    var ledger = SalvageLedger(seed: seed)
    let profile = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1), radius: 10,
      workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
    let inspected = ledger.inspectLoot(wreck: identity.wreck, section: profile, source: source)
    let plan = try #require(inspected)
    for batch in 0..<batches {
      let result = ledger.advance(
        wreck: identity.wreck, section: profile, pose: ShipPose(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: tool, elapsed: elapsed,
        operation: UInt64(batch),
        conditions: .init(
          toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
          resourcesAvailable: true, ownershipAuthorized: true), source: source)
      switch result {
      case .released, .progress, .alreadyDepleted, .destroyed: break
      default: throw AlienStorageError.invalidJoin
      }
    }
    return .init(ledger: ledger, seed: seed, plan: plan)
  }
  func saved() throws -> SavedLedger {
    try JSONDecoder().decode(SavedLedger.self, from: JSONEncoder().encode(ledger))
  }
  func section() throws -> AlienStorageLegacySection {
    let saved = try saved()
    let record = try #require(saved.plans[plan.section])
    return .init(
      id: Self.uuid(UInt64(plan.section.wreck.site) + 1000), owner: Self.owner,
      importOperation: Self.uuid(503), importedAt: 100,
      ledgerRevision: ledger.revision, seed: seed, plan: plan, progress: record.progress,
      savedPartialWorkSeconds: saved.work[plan.section],
      savedDamagedTechnology: saved.damagedTechnology.contains(plan.section),
      sectionDepleted: ledger.isDepleted(plan.section), sectionDestroyed: record.destroyed,
      wreckDestroyed: ledger.isWreckDestroyed(plan.section.wreck),
      savedLedgerLastOperation: saved.lastOperation)
  }
  var evidence: AlienStorageLegacyCustodyEvidence {
    get throws {
      let saved = try saved()
      return .init(
        pending: ledger.pendingLots.filter { $0.identity.section == plan.section },
        stored: ledger.inventory.filter { $0.identity.section == plan.section },
        offers: saved.offers.filter { $0.value.section == plan.section },
        bindings: saved.bindings.filter { $0.key.section == plan.section },
        settlements: saved.settlements.values.compactMap {
          if case .committed(let value) = $0,
            value.items.contains(where: { $0.identity.section == plan.section })
          {
            return value
          }
          return nil
        })
    }
  }
  func claims(
    _ section: AlienStorageLegacySection,
    state: ((SalvageLootItem) throws -> AlienStorageLegacyLot.State)? = nil
  ) throws -> [AlienStorageLegacyLot] {
    let evidence = try evidence
    let emissions = try SalvageSectionEmissionView(
      seed: seed, plan: plan, progress: section.progress
    ).emissions()
    return try emissions.map { origin, item in
      let value: AlienStorageLegacyLot.State
      if let state {
        value = try state(item)
      } else if let lot = evidence.pending.first(where: { $0.identity == item.identity }) {
        value = .pending(
          lot: lot, offer: evidence.offers.first { $0.value == lot.identity }?.key,
          binding: evidence.bindings[lot.identity])
      } else {
        value = .legacyUnavailable
      }
      return .init(
        id: Self.uuid(
          10_000 + UInt64(plan.section.wreck.site) * 65_536 + UInt64(item.identity.lot)),
        owner: Self.owner, section: section.id, origin: origin, identity: item.identity,
        state: value)
    }.sorted { $0.identity.lot < $1.identity.lot }
  }
  func validate(
    _ section: AlienStorageLegacySection, _ claims: [AlienStorageLegacyLot],
    settlements: AlienStorageLegacySettlements = .init(headers: [], items: []),
    migrations: [AlienStorageLegacyStoredMigration] = []
  ) throws {
    try AlienStorageLegacyValidation.validate(
      section: section, lots: claims, evidence: evidence, settlements: settlements,
      migrations: migrations)
  }
  mutating func collect(_ lot: SalvageLot) throws {
    var cargo = Array(repeating: 0, count: CommodityIdentity.allCases.count)
    let result = ledger.collect(
      lot: lot.identity, cargo: &cargo, freeTonnes: 1000,
      apertureHalfExtents: .init(1000, 1000, 1000), hasScoops: true, approachAllowed: true,
      protection: .init())
    guard case .collected = result else { throw AlienStorageError.invalidJoin }
  }
  static func replacing(_ old: AlienStorageLegacyLot, state: AlienStorageLegacyLot.State)
    -> AlienStorageLegacyLot
  {
    .init(
      id: old.id, owner: old.owner, section: old.section, origin: old.origin,
      identity: old.identity, state: state)
  }
}
