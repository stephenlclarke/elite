import Foundation
import Testing

@testable import EliteCore

struct AlienStorageCompanionTests {
  private struct SavedProgress: Decodable {
    let plan: SalvageLootPlan
    let issued: [Int]
    let discarded: [Bool]
    let structuralUnits: Int
    let issuedStructural: Int
    let materialKind: CommodityIdentity?
    let nextLot: UInt32
  }
  private struct SavedLedger: Decodable {
    let plans: [WreckSectionIdentity: SavedProgress]
    let lastOperation: UInt64?
  }
  private struct Fixture {
    let plan: AlienStorageWorldPlan
    let lots: [SalvageLot]
    let records: [AlienStorageWorldRecord]
    var snapshot: AlienStorageSnapshot {
      .init(
        owner: plan.owner, revision: 0, worldRevision: 1, world: records,
        sources: [], attachments: [], upgrades: [], receipts: [], commands: [])
    }
  }

  @Test func originalProducerChunksAndNativeTechnologyHaveCompleteAuthenticatedCustody() throws {
    let fixture = try fixture()
    #expect(fixture.lots.count == 11)
    #expect(fixture.lots.contains { if case .technology = $0.content { true } else { false } })
    let items = try fixture.plan.progress.emissions(plan: fixture.plan)
    #expect(items.count == fixture.lots.count)
    for lot in fixture.lots {
      let expected = try #require(items.values.first { $0.identity == lot.identity })
      try SalvageLotEmission.validate(lot, item: expected)
    }
    try fixture.snapshot.validate()
    var pages = AlienStorageMemoryPages()
    let encoded = try AlienStoragePageCodec.encode(
      snapshot: fixture.snapshot, previous: nil, into: &pages)
    let decoded = try AlienStoragePageCodec.decode(
      reference: encoded.reference,
      expectedOwner: fixture.plan.owner, rootData: encoded.rootData, from: pages)
    #expect(decoded == fixture.snapshot)
    for index in fixture.records.indices.dropFirst() {
      var missing = fixture.records
      missing.remove(at: index)
      #expect(throws: (any Error).self) { try self.snapshot(missing).validate() }
    }
  }

  @Test func collectionKeepsExactCargoCreditAndIndependentNativeTechnologyStorage() throws {
    let fixture = try fixture()
    let items = try fixture.plan.progress.emissions(plan: fixture.plan)
    var collected: [AlienStorageWorldRecord] = [.plan(fixture.plan)]
    var balances: [CommodityIdentity: Int] = [:]
    for record in fixture.records.dropFirst() {
      guard case .companion(let value) = record else { throw AlienStorageError.invalidJoin }
      let item = try #require(items[value.origin])
      let effect: AlienStorageCompanionCollection.Effect
      switch item.content {
      case .commodity(let amount):
        let before = balances[amount.commodity, default: 0]
        let after = before + amount.quantity
        effect = .cargo(amount: amount, before: before, after: after)
        balances[amount.commodity] = after
      case .technology: effect = .technology(storage: AlienStorageTestFixture.uuid(5000))
      }
      collected.append(
        .companion(
          replacing(
            value,
            state: .collected(
              .init(
                operation: AlienStorageTestFixture.uuid(2000 + UInt64(item.identity.lot)),
                hull: AlienStorageTestFixture.hull, at: 2, effect: effect)))))
    }
    #expect(balances[.food] == 27 && balances[.gold] == 2200)
    let next = snapshot(collected, revision: 2)
    try next.validateTransition(from: fixture.snapshot)
    #expect(next.sources.isEmpty && next.attachments.isEmpty && next.upgrades.isEmpty)
    #expect(throws: (any Error).self) { try fixture.snapshot.validateTransition(from: next) }
    var pages = AlienStorageMemoryPages()
    let encoded = try AlienStoragePageCodec.encode(
      snapshot: next, previous: fixture.snapshot, into: &pages)
    #expect(
      try AlienStoragePageCodec.decode(
        reference: encoded.reference,
        expectedOwner: next.owner, rootData: encoded.rootData, from: pages) == next)
  }

  @Test func changedChunkOriginContentCollectionAndTerminalHistoryAreRefused() throws {
    let fixture = try fixture()
    let pending = try #require(
      fixture.records.compactMap { record -> AlienStorageCompanion? in
        if case .companion(let value) = record { return value }
        return nil
      }.first)
    guard case .pending(let lot, _, _, _) = pending.state,
      case .commodity(let amount) = lot.content
    else { throw AlienStorageError.invalidJoin }
    let receipts: [AlienStorageCompanionCollection] = [
      .init(
        operation: AlienStorageTestFixture.uuid(9000), hull: AlienStorageTestFixture.hull, at: 2,
        effect: .cargo(
          amount: .init(commodity: amount.commodity, quantity: amount.quantity + 1), before: 0,
          after: amount.quantity + 1)),
      .init(
        operation: AlienStorageTestFixture.uuid(9000), hull: AlienStorageTestFixture.hull, at: 2,
        effect: .cargo(amount: amount, before: Int.max, after: 0)),
      .init(
        operation: AlienStorageTestFixture.uuid(9000), hull: AlienStorageTestFixture.hull, at: 0,
        effect: .cargo(amount: amount, before: 0, after: amount.quantity)),
      .init(
        operation: AlienStorageTestFixture.uuid(9000), hull: AlienStorageTestFixture.hull, at: 2,
        effect: .technology(storage: AlienStorageTestFixture.uuid(9001))),
    ]
    for receipt in receipts {
      #expect(throws: (any Error).self) {
        try self.replacing(
          pending, in: fixture, with: self.replacing(pending, state: .collected(receipt))
        ).validate()
      }
    }
    let wrongOrigin = AlienStorageCompanion(
      id: pending.id, owner: pending.owner, plan: pending.plan,
      origin: .planned(itemIndex: 0, chunkOrdinal: UInt16.max), issuedAt: pending.issuedAt,
      state: pending.state)
    #expect(throws: (any Error).self) {
      try self.replacing(pending, in: fixture, with: wrongOrigin).validate()
    }
    let forged = SalvageLot(
      identity: lot.identity, content: lot.content, position: lot.position, velocity: lot.velocity,
      halfExtents: lot.halfExtents, massKg: lot.massKg + 1, loot: lot.loot)
    #expect(throws: (any Error).self) {
      try self.replacing(
        pending, in: fixture,
        with: self.replacing(
          pending,
          state: .pending(lot: forged, physicalTime: 1, offer: nil, binding: nil))
      ).validate()
    }
    var unrepresentablePosition = lot
    unrepresentablePosition.position.x = Double.greatestFiniteMagnitude
    #expect(throws: (any Error).self) {
      try self.replacing(
        pending, in: fixture,
        with: self.replacing(
          pending,
          state: .pending(lot: unrepresentablePosition, physicalTime: 1, offer: nil, binding: nil))
      ).validate()
    }
    var unrepresentableVelocity = lot
    unrepresentableVelocity.velocity.x = Double.greatestFiniteMagnitude
    #expect(throws: (any Error).self) {
      try self.replacing(
        pending, in: fixture,
        with: self.replacing(
          pending,
          state: .pending(lot: unrepresentableVelocity, physicalTime: 1, offer: nil, binding: nil))
      ).validate()
    }
    let terminal = replacing(pending, state: .destroyed(at: 2))
    let destroyed = replacing(pending, in: fixture, with: terminal)
    try destroyed.validateTransition(from: fixture.snapshot)
    #expect(throws: (any Error).self) { try fixture.snapshot.validateTransition(from: destroyed) }
    #expect(throws: (any Error).self) {
      try self.replacing(
        pending, in: fixture,
        with: self.replacing(
          terminal,
          state: .discarded(at: 3))
      ).validateTransition(from: destroyed)
    }
  }

  @Test func collectionOperationsAndPhysicalBindingsCannotBeClaimedTwice() throws {
    let fixture = try fixture()
    let companions = fixture.records.compactMap { record -> AlienStorageCompanion? in
      if case .companion(let value) = record { return value }
      return nil
    }
    let first = try #require(companions.first)
    let second = try #require(companions.dropFirst().first)
    let binding = ActorIdentity(
      system: fixture.plan.plan.section.wreck.system, visit: 1, entity: 42)
    func bound(_ value: AlienStorageCompanion) throws -> AlienStorageCompanion {
      guard case .pending(let lot, _, _, _) = value.state else {
        throw AlienStorageError.invalidJoin
      }
      return replacing(
        value, state: .pending(lot: lot, physicalTime: 1, offer: nil, binding: binding))
    }
    let boundFirst = try bound(first)
    let boundSecond = try bound(second)
    let bothBound = fixture.records.map { record in
      record.id == first.id
        ? AlienStorageWorldRecord.companion(boundFirst)
        : record.id == second.id ? .companion(boundSecond) : record
    }
    #expect(throws: (any Error).self) { try self.snapshot(bothBound).validate() }
    let operation = AlienStorageTestFixture.uuid(9999)
    func collected(_ value: AlienStorageCompanion) throws -> AlienStorageCompanion {
      guard case .pending(let lot, _, _, _) = value.state, case .commodity(let amount) = lot.content
      else { throw AlienStorageError.invalidJoin }
      return replacing(
        value,
        state: .collected(
          .init(
            operation: operation,
            hull: AlienStorageTestFixture.hull, at: 2,
            effect: .cargo(amount: amount, before: 0, after: amount.quantity))))
    }
    let collectedFirst = try collected(first)
    let collectedSecond = try collected(second)
    let bothCollected = fixture.records.map { record in
      record.id == first.id
        ? AlienStorageWorldRecord.companion(collectedFirst)
        : record.id == second.id ? .companion(collectedSecond) : record
    }
    #expect(throws: (any Error).self) { try self.snapshot(bothCollected).validate() }
  }

  private func snapshot(_ records: [AlienStorageWorldRecord], revision: UInt64 = 1)
    -> AlienStorageSnapshot
  {
    .init(
      owner: AlienStorageTestFixture.owner, revision: 0, worldRevision: revision,
      world: records, sources: [], attachments: [], upgrades: [], receipts: [], commands: [])
  }
  private func replacing(_ value: AlienStorageCompanion, state: AlienStorageCompanion.State)
    -> AlienStorageCompanion
  {
    .init(
      id: value.id, owner: value.owner, plan: value.plan, origin: value.origin,
      issuedAt: value.issuedAt, state: state)
  }
  private func replacing(
    _ old: AlienStorageCompanion, in fixture: Fixture,
    with next: AlienStorageCompanion
  ) -> AlienStorageSnapshot {
    snapshot(fixture.records.map { $0.id == old.id ? .companion(next) : $0 }, revision: 2)
  }

  /// Actual immutable inspection and ordinary cutter emissions, not hand-authored chunks.
  private func fixture() throws -> Fixture {
    let section = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
    let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 78, lineage: 123)
    let identity = WreckSectionIdentity(wreck: wreck, section: 1)
    var source = SalvageLootSource(
      roles: [.militaryCapital], legalValue: 0, economy: 3,
      technology: 12, ownership: .abandoned)
    source.manifest = [
      .init(commodity: .food, quantity: 27), .init(commodity: .gold, quantity: 2200),
    ]
    source.manifestSection = 1
    let seed = try #require(
      (UInt64(0)..<2000).first { seed in
        SalvageLootProfiles.plan(section: identity, seed: seed, source: source).items.contains {
          if case .technology = $0.content { true } else { false }
        }
      })
    var ledger = SalvageLedger(seed: seed)
    let original = try #require(ledger.inspectLoot(wreck: wreck, section: section, source: source))
    var lots: [SalvageLot] = []
    for operation in UInt64(1)...4 {
      let result = ledger.advance(
        wreck: wreck, section: section,
        pose: .init(position: .init(100, 200, 300)), velocity: .init(1, 2, 3),
        angularVelocity: .init(0, 0, 0),
        tool: .cutter, elapsed: 1, operation: operation,
        conditions: .init(
          toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
          resourcesAvailable: true, ownershipAuthorized: true), source: source)
      if case .released(let emitted) = result { lots += emitted }
    }
    let saved = try JSONDecoder().decode(SavedLedger.self, from: JSONEncoder().encode(ledger))
    let progress = try #require(saved.plans[identity])
    #expect(progress.plan == original)
    let plan = AlienStorageWorldPlan(
      id: AlienStorageTestFixture.uuid(10), owner: AlienStorageTestFixture.owner,
      seed: seed, plan: original, inspectedAt: 0, requiredWorkSeconds: 1, workSeconds: 1,
      damagedTechnology: false, depleted: true, destroyed: false,
      lastOperation: saved.lastOperation,
      progress: .init(
        issued: progress.issued, discarded: progress.discarded,
        structuralUnits: progress.structuralUnits, issuedStructural: progress.issuedStructural,
        materialKind: progress.materialKind, nextLot: progress.nextLot))
    let emissions = try plan.progress.emissions(plan: plan)
    let records: [AlienStorageWorldRecord] =
      [.plan(plan)]
      + (try lots.map { lot in
        let origin = try #require(emissions.first { $0.value.identity == lot.identity }?.key)
        return .companion(
          .init(
            id: AlienStorageTestFixture.uuid(100 + UInt64(lot.identity.lot)), owner: plan.owner,
            plan: plan.id, origin: origin, issuedAt: 1,
            state: .pending(lot: lot, physicalTime: 1, offer: nil, binding: nil)))
      })
    return .init(plan: plan, lots: lots, records: records)
  }
}
