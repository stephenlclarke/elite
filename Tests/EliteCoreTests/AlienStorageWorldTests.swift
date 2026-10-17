import Foundation
import Testing

@testable import EliteCore

struct AlienStorageWorldTests {
  private struct SavedProgress: Decodable {
    let plan: SalvageLootPlan
    let issued: [Int]
    let discarded: [Bool]
    let structuralUnits: Int
    let issuedStructural: Int
    let materialKind: CommodityIdentity?
    let nextLot: UInt32
    var value: AlienStorageWorldProgress {
      .init(
        issued: issued, discarded: discarded, structuralUnits: structuralUnits,
        issuedStructural: issuedStructural, materialKind: materialKind, nextLot: nextLot)
    }
  }
  private struct SavedLedger: Decodable { let plans: [WreckSectionIdentity: SavedProgress] }

  @Test func genuineStructuralEmissionPreservesReidentifiedReservedLot() throws {
    let (seed, original, oldIdentity) = try AlienStorageTestFixture.plan(
      site: 77,
      definition: AlienModuleKind.allCases[0].definitionID)
    let section = sectionProfile()
    var ledger = SalvageLedger(seed: seed)
    let inspected = ledger.inspectLoot(
      wreck: original.section.wreck, section: section, source: original.source)
    #expect(inspected == original)
    let result = advance(&ledger, original: original, section: section)
    guard case .released(let lots) = result else { throw AlienStorageError.invalidJoin }
    let lot = try #require(
      lots.first { value in
        if case .technology(let id, _, _) = value.content {
          return AlienModuleDefinition.isAttachmentDefinition(id)
        }
        return false
      })
    #expect(lots.count == 2)
    #expect(original.items[0].identity.lot == 0)
    #expect(lot.identity.lot == 1)
    #expect(lot.loot != original.items[0])
    let saved = try JSONDecoder().decode(SavedLedger.self, from: JSONEncoder().encode(ledger))
    let progress = try #require(saved.plans[original.section])
    let planID = AlienStorageTestFixture.uuid(10)
    let worldPlan = plan(id: planID, seed: seed, saved: progress)
    let worldLot = AlienStorageWorldLot(
      id: AlienStorageTestFixture.uuid(11), owner: AlienStorageTestFixture.owner,
      plan: planID, itemIndex: 0, issuedAt: 1,
      state: .pending(lot: lot, physicalTime: 1, offer: nil, binding: nil))
    let companions = try companionRecords(plan: worldPlan, lots: lots)
    let snapshot = snapshot([.plan(worldPlan), .lot(worldLot)] + companions)
    #expect(throws: (any Error).self) {
      try self.snapshot([.plan(worldPlan), .lot(worldLot)]).validate()
    }
    try snapshot.validate()
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    let restored = try AlienStoragePageCodec.decode(
      reference: archive.reference, expectedOwner: snapshot.owner,
      rootData: archive.rootData, from: pages)
    #expect(restored == snapshot)
    let fabricated = AlienStorageWorldLot(
      id: worldLot.id, owner: worldLot.owner, plan: planID,
      itemIndex: 0, issuedAt: 1,
      state: .pending(lot: oldIdentity, physicalTime: 1, offer: nil, binding: nil))
    #expect(throws: (any Error).self) {
      try self.snapshot([.plan(worldPlan), .lot(fabricated)] + companions).validate()
    }
    let sourceID = AlienStorageTestFixture.uuid(12)
    let attachmentID = AlienStorageTestFixture.uuid(13)
    let acquired = AlienStorageWorldLot(
      id: worldLot.id, owner: worldLot.owner, plan: planID,
      itemIndex: 0, issuedAt: 1, state: .acquired(source: sourceID, at: 2))
    let owned = AlienStorageSnapshot(
      owner: snapshot.owner, revision: 1, worldRevision: 2,
      world: [.plan(worldPlan), .lot(acquired)] + companions,
      sources: [.init(id: sourceID, owner: snapshot.owner, lot: lot, acquisition: sourceID)],
      attachments: [
        .init(
          id: attachmentID, owner: snapshot.owner, kind: AlienModuleKind.allCases[0],
          source: sourceID, disposition: .stored, contributionBasisPoints: 1000)
      ], upgrades: [], receipts: [],
      commands: [
        .init(
          id: sourceID, owner: snapshot.owner, revision: 1,
          action: .acquireAttachment(attachment: attachmentID, source: sourceID))
      ])
    try owned.validateTransition(from: snapshot)
  }

  @Test func genuineMixedCommodityChunksRetainLaterTechnologyOrdinal() throws {
    let section = sectionProfile()
    let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 78, lineage: 123)
    var source = SalvageLootSource(
      roles: [.militaryCapital], legalValue: 0, economy: 3,
      technology: 12, ownership: .abandoned)
    source.manifest = [
      .init(commodity: .food, quantity: 27), .init(commodity: .gold, quantity: 2200),
    ]
    source.manifestSection = 1
    let identity = WreckSectionIdentity(wreck: wreck, section: 1)
    let seed = try #require(
      (UInt64(0)..<2000).first { seed in
        SalvageLootProfiles.plan(section: identity, seed: seed, source: source).items.contains {
          if case .technology = $0.content { return true }
          return false
        }
      })
    var ledger = SalvageLedger(seed: seed)
    let inspection = ledger.inspectLoot(wreck: wreck, section: section, source: source)
    let original = try #require(inspection)
    var emitted: [SalvageLot] = []
    for _ in 0..<4 {
      let result = advance(&ledger, original: original, section: section)
      if case .released(let lots) = result { emitted.append(contentsOf: lots) }
    }
    let saved = try JSONDecoder().decode(SavedLedger.self, from: JSONEncoder().encode(ledger))
    let progress = try #require(saved.plans[identity])
    let worldPlan = plan(id: AlienStorageTestFixture.uuid(20), seed: seed, saved: progress)
    try worldPlan.progress.validate(plan: worldPlan)
    let index = try #require(
      original.items.firstIndex {
        if case .technology = $0.content { return true }
        return false
      })
    let lot = try #require(
      emitted.first {
        if case .technology = $0.content { return true }
        return false
      })
    let derived = try progress.value.issuedIdentity(itemIndex: index, plan: original)
    #expect(derived == lot.identity)
    // One structural lot, six tonne chunks and three kilogram chunks precede the tech.
    #expect(derived.lot == 10)
    #expect(derived != original.items[index].identity)
    let companions = try companionRecords(plan: worldPlan, lots: emitted)
    #expect(companions.count == emitted.count)
    try snapshot([.plan(worldPlan)] + companions).validate()
    #expect(throws: (any Error).self) { try self.snapshot([.plan(worldPlan)]).validate() }
    let rewind = AlienStorageWorldProgress(
      issued: Array(repeating: 0, count: original.items.count),
      discarded: Array(repeating: false, count: original.items.count),
      structuralUnits: progress.structuralUnits,
      issuedStructural: 0, materialKind: nil, nextLot: 0)
    #expect(throws: (any Error).self) { try rewind.preserve(progress.value) }
  }

  @Test func emptyOutcomesAndUnissuedDiscardedResultsArePermanent() throws {
    let section = WreckSectionIdentity(
      wreck: .init(system: .init(galaxy: 0, system: 7), site: 79, lineage: 123), section: 1)
    let source = SalvageLootSource(
      roles: [], legalValue: 0, economy: 3, technology: 12, ownership: .abandoned)
    let original = SalvageLootProfiles.plan(section: section, seed: 1, source: source)
    #expect(original.items.isEmpty)
    let empty = AlienStorageWorldPlan(
      id: AlienStorageTestFixture.uuid(30), owner: AlienStorageTestFixture.owner,
      seed: 1, plan: original, inspectedAt: 0, requiredWorkSeconds: 1, workSeconds: 0,
      damagedTechnology: false, depleted: false, destroyed: false, lastOperation: nil,
      progress: .init(
        issued: [], discarded: [], structuralUnits: 0, issuedStructural: 0, materialKind: nil,
        nextLot: 0))
    try snapshot([.plan(empty)]).validate()
    #expect(throws: (any Error).self) {
      try AlienStorageWorldValidation.preserve([.plan(empty)], in: [])
    }
  }

  @Test func pendingMotionBindingAndDiscardHaveMonotoneCustody() throws {
    let (seed, original, lot) = try AlienStorageTestFixture.plan(
      site: 80,
      definition: AlienModuleKind.allCases[0].definitionID)
    let planID = AlienStorageTestFixture.uuid(40)
    let lotID = AlienStorageTestFixture.uuid(41)
    let owner = AlienStorageTestFixture.owner
    let untouched = AlienStorageWorldPlan(
      id: planID, owner: owner, seed: seed, plan: original,
      inspectedAt: 0, requiredWorkSeconds: 1, workSeconds: 0, damagedTechnology: false,
      depleted: false, destroyed: false, lastOperation: nil,
      progress: .init(
        issued: [0], discarded: [false], structuralUnits: 0, issuedStructural: 0,
        materialKind: nil, nextLot: 0))
    let unissued = AlienStorageWorldLot(
      id: lotID, owner: owner, plan: planID, itemIndex: 0,
      issuedAt: nil, state: .unissued)
    let initial = snapshot([.plan(untouched), .lot(unissued)])
    try initial.validate()
    let completed = AlienStorageWorldPlan(
      id: planID, owner: owner, seed: seed, plan: original,
      inspectedAt: 0, requiredWorkSeconds: 1, workSeconds: 1, damagedTechnology: false,
      depleted: true, destroyed: false, lastOperation: 1,
      progress: .init(
        issued: [1], discarded: [false], structuralUnits: 0, issuedStructural: 0,
        materialKind: .alloys, nextLot: 1))
    let offer = SpawnIdentity(
      system: original.section.wreck.system, visit: 1, sequence: 1,
      member: 0, producer: .salvage)
    let pending = AlienStorageWorldLot(
      id: lotID, owner: owner, plan: planID, itemIndex: 0,
      issuedAt: 1, state: .pending(lot: lot, physicalTime: 1, offer: offer, binding: nil))
    let issued = AlienStorageSnapshot(
      owner: owner, revision: 0, worldRevision: 2,
      world: [.plan(completed), .lot(pending)], sources: [], attachments: [], upgrades: [],
      receipts: [], commands: [])
    try issued.validateTransition(from: initial)
    let actor = ActorIdentity(system: original.section.wreck.system, visit: 1, entity: 2)
    let rebound = AlienStorageWorldLot(
      id: lotID, owner: owner, plan: planID, itemIndex: 0,
      issuedAt: 1, state: .pending(lot: lot, physicalTime: 2, offer: nil, binding: actor))
    let bound = AlienStorageSnapshot(
      owner: owner, revision: 0, worldRevision: 3,
      world: [.plan(completed), .lot(rebound)], sources: [], attachments: [], upgrades: [],
      receipts: [], commands: [])
    try bound.validateTransition(from: issued)
    let discarded = AlienStorageWorldLot(
      id: lotID, owner: owner, plan: planID, itemIndex: 0,
      issuedAt: 1, state: .discarded(at: 3))
    let terminal = AlienStorageSnapshot(
      owner: owner, revision: 0, worldRevision: 4,
      world: [.plan(completed), .lot(discarded)], sources: [], attachments: [], upgrades: [],
      receipts: [], commands: [])
    try terminal.validateTransition(from: bound)
    #expect(throws: (any Error).self) { try bound.validateTransition(from: terminal) }
    let doubleBinding = AlienStorageWorldLot(
      id: lotID, owner: owner, plan: planID, itemIndex: 0,
      issuedAt: 1, state: .pending(lot: lot, physicalTime: 2, offer: offer, binding: actor))
    #expect(throws: (any Error).self) {
      try self.snapshot([.plan(completed), .lot(doubleBinding)]).validate()
    }
    let destroyed = AlienStorageWorldLot(
      id: lotID, owner: owner, plan: planID, itemIndex: 0,
      issuedAt: 1, state: .destroyed(at: 3))
    try AlienStorageWorldValidation.validate(
      [.plan(completed), .lot(destroyed)], owner: owner, sources: [])
  }

  private func snapshot(_ world: [AlienStorageWorldRecord]) -> AlienStorageSnapshot {
    .init(
      owner: AlienStorageTestFixture.owner, revision: 0, worldRevision: 1, world: world,
      sources: [], attachments: [], upgrades: [], receipts: [], commands: [])
  }
  private func sectionProfile() -> SalvageSectionProfile {
    .init(
      index: 1, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
  }
  private func advance(
    _ ledger: inout SalvageLedger, original: SalvageLootPlan,
    section: SalvageSectionProfile
  ) -> SalvageWorkResult {
    ledger.advance(
      wreck: original.section.wreck, section: section, pose: ShipPose(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1,
      operation: UInt64(ledger.pendingLots.count + 1),
      conditions: .init(
        toolInstalled: true,
        inRange: true, aligned: true, lineOfSight: true, resourcesAvailable: true,
        ownershipAuthorized: true),
      source: original.source)
  }
  private func companionRecords(plan: AlienStorageWorldPlan, lots: [SalvageLot]) throws
    -> [AlienStorageWorldRecord]
  {
    let emissions = try plan.progress.emissions(plan: plan)
    return try lots.compactMap { lot in
      if case .technology(let id, _, _) = lot.content,
        AlienModuleDefinition.isAttachmentDefinition(id)
      {
        return nil
      }
      let origin = try #require(emissions.first { $0.value.identity == lot.identity }?.key)
      return .companion(
        .init(
          id: AlienStorageTestFixture.uuid(1000 + UInt64(lot.identity.lot)),
          owner: plan.owner, plan: plan.id, origin: origin, issuedAt: 1,
          state: .pending(lot: lot, physicalTime: 1, offer: nil, binding: nil)))
    }
  }
  private func plan(id: UUID, seed: UInt64, saved: SavedProgress) -> AlienStorageWorldPlan {
    .init(
      id: id, owner: AlienStorageTestFixture.owner, seed: seed, plan: saved.plan,
      inspectedAt: 0, requiredWorkSeconds: 1, workSeconds: 1, damagedTechnology: false,
      depleted: true, destroyed: false, lastOperation: 1, progress: saved.value)
  }
}
