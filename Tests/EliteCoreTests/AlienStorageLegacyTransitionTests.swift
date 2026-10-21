import Foundation
import Testing

@testable import EliteCore

struct AlienStorageLegacyTransitionTests {
  @Test func genuineStoredAttachmentAndUpgradeUseExplicitMigration() throws {
    for upgrade in [false, true] {
      let kind = AlienModuleKind.energyCapacity
      var fixture = try AlienLegacyFixture.make(
        definition: upgrade ? kind.upgradeDefinitionID : kind.definitionID)
      let lot = try #require(
        fixture.ledger.pendingLots.first {
          if case .technology = $0.content { return true }
          return false
        })
      try fixture.collect(lot)
      let section = try fixture.section()
      let migration = AlienStorageLegacyStoredMigration(
        operation: AlienLegacyFixture.uuid(600), owner: section.owner, section: section.id,
        identity: lot.identity, lot: lot, source: AlienLegacyFixture.uuid(601),
        property: AlienLegacyFixture.uuid(602),
        kind: upgrade ? .upgrade(kind) : .attachment(kind))
      let evidence = try fixture.evidence
      let claims = try fixture.claims(section) { item in
        if item.identity == lot.identity {
          return .storedReserved(
            lot: lot, migrationOperation: migration.operation, source: migration.source)
        }
        let pending = try #require(evidence.pending.first { $0.identity == item.identity })
        return .pending(lot: pending, offer: nil, binding: nil)
      }
      try fixture.validate(section, claims, migrations: [migration])
      #expect(throws: (any Error).self) { try fixture.validate(section, claims) }
      let after = AlienStorageLegacyCustodyEvidence(
        pending: [], stored: [], offers: [:], bindings: [:], settlements: [])
      try AlienStorageLegacyValidation.validateTransfer(
        section: section, lots: claims, before: evidence, after: after,
        settlements: .init(headers: [], items: []), migrations: [migration])
      #expect(throws: (any Error).self) {
        try AlienStorageLegacyValidation.validateTransfer(
          section: section, lots: claims, before: evidence, after: evidence,
          settlements: .init(headers: [], items: []), migrations: [migration])
      }
      let wrongKind = AlienStorageLegacyStoredMigration(
        operation: migration.operation, owner: migration.owner, section: migration.section,
        identity: migration.identity, lot: migration.lot, source: migration.source,
        property: migration.property,
        kind: upgrade ? .attachment(kind) : .upgrade(kind))
      #expect(throws: (any Error).self) {
        try fixture.validate(section, claims, migrations: [wrongKind])
      }
      let unknown = try fixture.claims(section)
      #expect(throws: (any Error).self) { try fixture.validate(section, unknown) }
    }
  }

  @Test func genuineOrdinaryStoredTechnologyRemainsOldCustody() throws {
    var fixture = try AlienLegacyFixture.make(
      definition: "shield-technology", roles: [.militaryCapital])
    let lot = try #require(
      fixture.ledger.pendingLots.first {
        if case .technology = $0.content { return true }
        return false
      })
    try fixture.collect(lot)
    let section = try fixture.section()
    let evidence = try fixture.evidence
    let claims = try fixture.claims(section) { item in
      if item.identity == lot.identity { return .retainedOrdinaryStored(lot: lot) }
      let pending = try #require(evidence.pending.first { $0.identity == item.identity })
      return .pending(lot: pending, offer: nil, binding: nil)
    }
    try fixture.validate(section, claims)
    let after = AlienStorageLegacyCustodyEvidence(
      pending: [], stored: [lot], offers: [:], bindings: [:], settlements: [])
    try AlienStorageLegacyValidation.validateTransfer(
      section: section, lots: claims, before: evidence, after: after,
      settlements: .init(headers: [], items: []), migrations: [])
    let lost = AlienStorageLegacyCustodyEvidence(
      pending: [], stored: [], offers: [:], bindings: [:], settlements: [])
    #expect(throws: (any Error).self) {
      try AlienStorageLegacyValidation.validateTransfer(
        section: section, lots: claims, before: evidence, after: lost,
        settlements: .init(headers: [], items: []), migrations: [])
    }
    try AlienStorageLegacyValidation.preserve(
      section: section, lots: claims, in: section, lots: Array(claims.reversed()))
    let rewritten = claims.map {
      $0.identity == lot.identity ? AlienLegacyFixture.replacing($0, state: .legacyUnavailable) : $0
    }
    #expect(throws: AlienStorageError.historyChanged) {
      try AlienStorageLegacyValidation.preserve(
        section: section, lots: claims, in: section, lots: rewritten)
    }
  }

  @Test func oneMaximumOriginalProposalIsSharedAcrossSectionsWithoutDuplication() throws {
    let (fixture, proposal, otherPlan) = try settledFixture(count: SalvageLedger.maximumInventory)
    let normalized = normalized(proposal)
    #expect(normalized.headers.count == 1)
    #expect(normalized.items.count == 128)
    let header = try #require(normalized.headers.first)
    let reconstructed = try normalized.proposal(for: header)
    #expect(reconstructed == proposal)
    let section = try fixture.section()
    let claims = try settledClaims(fixture, section: section, audit: normalized)
    try fixture.validate(section, claims, settlements: normalized)
    let other = AlienLegacyFixture(ledger: fixture.ledger, seed: fixture.seed, plan: otherPlan)
    let otherSection = try other.section()
    let otherClaims = try settledClaims(other, section: otherSection, audit: normalized)
    try other.validate(otherSection, otherClaims, settlements: normalized)
    try AlienStorageLegacyValidation.preserveSettlements(normalized, in: normalized)
    #expect(
      claims.contains {
        if case .legacySettled(let id, _) = $0.state { return id == header.id }
        return false
      })
    #expect(
      otherClaims.contains {
        if case .legacySettled(let id, _) = $0.state { return id == header.id }
        return false
      })
    // Record-size evidence only. Final world/page encoding belongs to G1's codec integration.
    for item in normalized.items {
      let bytes = try JSONEncoder().encode(item)
      #expect(bytes.count + 4096 < AlienStoragePageCodec.maximumPageBytes)
    }
    let bytes = try JSONEncoder().encode(header)
    #expect(bytes.count + 4096 < AlienStoragePageCodec.maximumPageBytes)
  }

  @Test func settlementOrdinalAndMetadataCorruptionRefuseWithoutChangingAudit() throws {
    let (fixture, proposal, _) = try settledFixture(count: 2)
    let audit = normalized(proposal)
    let section = try fixture.section()
    let claims = try settledClaims(fixture, section: section, audit: audit)
    let header = try #require(audit.headers.first)
    let first = try #require(audit.items.first)
    let repeatedOrdinal = AlienStorageLegacySettlementItem(
      id: AlienLegacyFixture.uuid(9000), owner: first.owner, settlement: first.settlement,
      ordinal: first.ordinal, lot: audit.items[1].lot)
    let badItems = AlienStorageLegacySettlements(
      headers: audit.headers, items: [first, repeatedOrdinal])
    #expect(throws: (any Error).self) {
      try fixture.validate(section, claims, settlements: badItems)
    }
    let missing = AlienStorageLegacySettlements(headers: audit.headers, items: [first])
    #expect(throws: (any Error).self) {
      try fixture.validate(section, claims, settlements: missing)
    }
    let changed = AlienStorageLegacySettlement(
      id: header.id, owner: header.owner, command: header.command, revision: header.revision + 1,
      action: header.action, saleValueTenths: header.saleValueTenths, binding: header.binding,
      itemCount: header.itemCount)
    let changedAudit = AlienStorageLegacySettlements(headers: [changed], items: audit.items)
    #expect(throws: (any Error).self) {
      try fixture.validate(section, claims, settlements: changedAudit)
    }
    #expect(throws: AlienStorageError.historyChanged) {
      try AlienStorageLegacyValidation.preserveSettlements(audit, in: changedAudit)
    }
    let changedAction = AlienStorageLegacySettlement(
      id: header.id, owner: header.owner, command: header.command, revision: header.revision,
      action: .research, saleValueTenths: header.saleValueTenths, binding: header.binding,
      itemCount: header.itemCount)
    let changedValue = AlienStorageLegacySettlement(
      id: header.id, owner: header.owner, command: header.command, revision: header.revision,
      action: header.action, saleValueTenths: header.saleValueTenths + 1, binding: header.binding,
      itemCount: header.itemCount)
    let changedBinding = AlienStorageLegacySettlement(
      id: header.id, owner: header.owner, command: header.command, revision: header.revision,
      action: header.action, saleValueTenths: header.saleValueTenths,
      binding: .research(
        recipeID: "navigation-1", expectedComponentInstanceID: nil, templateVersion: 1),
      itemCount: header.itemCount)
    for forged in [changedAction, changedValue, changedBinding] {
      let forgedAudit = AlienStorageLegacySettlements(headers: [forged], items: audit.items)
      #expect(throws: (any Error).self) {
        try fixture.validate(section, claims, settlements: forgedAudit)
      }
    }
    let conflictingCommand = AlienStorageLegacySettlement(
      id: AlienLegacyFixture.uuid(9100), owner: header.owner, command: header.command,
      revision: header.revision, action: header.action, saleValueTenths: header.saleValueTenths,
      binding: header.binding, itemCount: header.itemCount)
    let conflictItems = audit.items.enumerated().map { index, item in
      AlienStorageLegacySettlementItem(
        id: AlienLegacyFixture.uuid(9200 + UInt64(index)), owner: item.owner,
        settlement: conflictingCommand.id, ordinal: item.ordinal, lot: item.lot)
    }
    let conflict = AlienStorageLegacySettlements(
      headers: audit.headers + [conflictingCommand], items: audit.items + conflictItems)
    #expect(throws: (any Error).self) {
      try AlienStorageLegacyValidation.validateSettlements(conflict, owner: header.owner)
    }
    let reconstructed = try audit.proposal(for: header)
    #expect(reconstructed == proposal)
    try fixture.validate(section, claims, settlements: audit)
  }

  @Test func knownSettledCannotBecomeUnknownPendingOrFreshProperty() throws {
    let (fixture, proposal, _) = try settledFixture(count: 2)
    let audit = normalized(proposal)
    let section = try fixture.section()
    let claims = try settledClaims(fixture, section: section, audit: audit)
    let claim = try #require(
      claims.first {
        if case .legacySettled = $0.state { return true }
        return false
      })
    let item = try #require(proposal.items.first { $0.identity == claim.identity })
    for state in [
      AlienStorageLegacyLot.State.legacyUnavailable, .pending(lot: item, offer: nil, binding: nil),
      .storedReserved(
        lot: item, migrationOperation: AlienLegacyFixture.uuid(905),
        source: AlienLegacyFixture.uuid(906)),
    ] {
      let changed = claims.map {
        $0.id == claim.id ? AlienLegacyFixture.replacing($0, state: state) : $0
      }
      #expect(throws: (any Error).self) {
        try fixture.validate(section, changed, settlements: audit)
      }
      #expect(throws: AlienStorageError.historyChanged) {
        try AlienStorageLegacyValidation.preserve(
          section: section, lots: claims, in: section, lots: changed)
      }
    }
  }

  @Test func parentDeathDoesNotEraseGenuinePendingFragments() throws {
    var fixture = try AlienLegacyFixture.make()
    let killed = fixture.ledger.markWreckDestroyed(fixture.plan.section.wreck)
    #expect(killed)
    let section = try fixture.section()
    #expect(section.wreckDestroyed)
    let claims = try fixture.claims(section)
    #expect(!claims.isEmpty)
    try fixture.validate(section, claims)
  }

  private func normalized(_ proposal: SalvageSettlementProposal) -> AlienStorageLegacySettlements {
    let header = AlienStorageLegacySettlement(
      id: AlienLegacyFixture.uuid(7000), owner: AlienLegacyFixture.owner, command: proposal.command,
      revision: proposal.revision, action: proposal.action,
      saleValueTenths: proposal.saleValueTenths,
      binding: proposal.binding, itemCount: UInt16(proposal.items.count))
    let items = proposal.items.enumerated().map { index, lot in
      AlienStorageLegacySettlementItem(
        id: AlienLegacyFixture.uuid(8000 + UInt64(index)), owner: header.owner,
        settlement: header.id, ordinal: UInt16(index), lot: lot)
    }
    return .init(headers: [header], items: items)
  }
  private func settledClaims(
    _ fixture: AlienLegacyFixture, section: AlienStorageLegacySection,
    audit: AlienStorageLegacySettlements
  ) throws -> [AlienStorageLegacyLot] {
    let evidence = try fixture.evidence
    return try fixture.claims(section) { item in
      if let settled = audit.items.first(where: { $0.lot.identity == item.identity }) {
        return .legacySettled(settlement: settled.settlement, item: settled.id)
      }
      let pending = try #require(evidence.pending.first { $0.identity == item.identity })
      return .pending(lot: pending, offer: nil, binding: nil)
    }
  }
  private func settledFixture(count: Int) throws -> (
    AlienLegacyFixture, SalvageSettlementProposal, SalvageLootPlan
  ) {
    var ledger = SalvageLedger(seed: 0)
    let source = SalvageLootSource(
      roles: [.thargoid], legalValue: 0, economy: 3, technology: 12, ownership: .abandoned)
    let profile = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1), radius: 10,
      workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
    var plans: [SalvageLootPlan] = []
    for index in 0..<count {
      let wreck = WreckIdentity(
        system: .init(galaxy: 0, system: 7), site: UInt32(2000 + index), lineage: 123)
      let inspected = ledger.inspectLoot(wreck: wreck, section: profile, source: source)
      let plan = try #require(inspected)
      plans.append(plan)
      let result = ledger.advance(
        wreck: wreck, section: profile, pose: ShipPose(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: UInt64(index),
        conditions: .init(
          toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
          resourcesAvailable: true, ownershipAuthorized: true), source: source)
      guard case .released(let lots) = result else { throw AlienStorageError.invalidJoin }
      let technology = try #require(
        lots.first {
          if case .technology = $0.content { return true }
          return false
        })
      var fixture = AlienLegacyFixture(ledger: ledger, seed: 0, plan: plan)
      try fixture.collect(technology)
      ledger = fixture.ledger
    }
    let prepared = ledger.prepareSettlement(
      command: AlienLegacyFixture.uuid(7010), items: ledger.inventory.reversed().map(\.identity),
      action: .sell)
    let proposal = try #require(prepared)
    let receipt = ledger.commitSettlement(proposal)
    #expect(receipt == .committed(proposal))
    let first = try #require(plans.first)
    let last = try #require(plans.last)
    return (.init(ledger: ledger, seed: 0, plan: first), proposal, last)
  }
}

extension AlienStorageLegacyTransitionTests {
  @Test func independentLegacyCollectionCannotReuseRetirementSettlementOrImportOperations() throws {
    let (original, proposal, _) = try settledFixture(count: 2)
    var owned = AlienStorageTestFixture()
    let module = try owned.acquire(kind: .energyCapacity)
    try owned.retire(module)
    let retirement = try #require(owned.commands.last?.id)
    let imported = try NativeSalvageImport(
      ledger: original.ledger,
      section: original.plan.section, owner: AlienStorageTestFixture.owner, at: 100,
      previous: owned.snapshot)
    let section = try #require(
      imported.snapshot.world.compactMap { record -> AlienStorageLegacySection? in
        if case .legacySection(let value) = record { return value }
        return nil
      }.first)
    let pending = try #require(
      imported.snapshot.world.compactMap { record -> AlienStorageLegacyCurrent? in
        guard case .legacyCurrent(let value) = record,
          case .pending(let lot, _, _, _) = value.state, case .commodity = lot.content
        else { return nil }
        return value
      }.first)
    guard case .pending(let lot, _, _, _) = pending.state, case .commodity(let amount) = lot.content
    else { throw AlienStorageError.invalidJoin }
    func candidate(_ operation: UUID) -> AlienStorageSnapshot {
      let collected = AlienStorageLegacyCurrent(
        id: pending.id, owner: pending.owner, claim: pending.claim,
        state: .collected(
          .init(
            operation: operation, hull: AlienStorageTestFixture.hull,
            at: 101, effect: .cargo(amount: amount, before: 0, after: amount.quantity))))
      let old = imported.snapshot
      return .init(
        owner: old.owner, revision: old.revision, worldRevision: old.worldRevision + 1,
        world: old.world.map { $0.id == pending.id ? .legacyCurrent(collected) : $0 },
        sources: old.sources, attachments: old.attachments, upgrades: old.upgrades,
        receipts: old.receipts, commands: old.commands)
    }
    try candidate(UUID()).validateTransition(from: imported.snapshot)
    for operation in [retirement, proposal.command, section.importOperation] {
      #expect(throws: (any Error).self) { try candidate(operation).validate() }
    }
    try imported.snapshot.validate()
  }
}

private func genuineReservedCrossSectionSale() throws -> (
  SalvageLedger, SalvageLootPlan, SalvageLootPlan, SalvageSettlementProposal
) {
  var ledger = SalvageLedger(seed: 0)
  let source = SalvageLootSource(
    roles: [.thargoid], legalValue: 0, economy: 3,
    technology: 12, ownership: .abandoned)
  let profile = SalvageSectionProfile(
    index: 1, kind: .computer, localPosition: .init(10, 0, 0),
    normal: .init(0, 0, 1), radius: 10, workSeconds: 1, structural: true,
    technologyDefinitionIDs: [], sourceFaceIndex: 0)
  var plans: [SalvageLootPlan] = []
  for site in UInt32(21000)..<23000 where plans.count < 2 {
    let section = WreckSectionIdentity(
      wreck: .init(
        system: .init(galaxy: 0, system: 7),
        site: site, lineage: 123), section: 1)
    let possible = SalvageLootProfiles.plan(section: section, seed: 0, source: source)
    guard
      possible.items.contains(where: { item in
        if case .technology(let id, _, _, _) = item.content {
          return AlienModuleKind.allCases.contains { $0.definitionID == id }
        }
        return false
      })
    else { continue }
    let inspected = ledger.inspectLoot(wreck: section.wreck, section: profile, source: source)
    let plan = try #require(inspected)
    let emitted = ledger.advance(
      wreck: section.wreck, section: profile, pose: .init(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
      elapsed: 1, operation: UInt64(plans.count + 1),
      conditions: .init(
        toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
        resourcesAvailable: true, ownershipAuthorized: true), source: source)
    guard case .released(let lots) = emitted else { throw AlienStorageError.invalidJoin }
    let technology = try #require(
      lots.first { lot in
        if case .technology(let id, _, _) = lot.content {
          return AlienModuleKind.allCases.contains { $0.definitionID == id }
        }
        return false
      })
    var original = AlienLegacyFixture(ledger: ledger, seed: 0, plan: plan)
    try original.collect(technology)
    ledger = original.ledger
    plans.append(plan)
  }
  try #require(plans.count == 2)
  let prepared = ledger.prepareSettlement(
    command: UUID(), items: ledger.inventory.map(\.identity), action: .sell)
  let proposal = try #require(prepared)
  let committed = ledger.commitSettlement(proposal)
  try #require(committed == .committed(proposal))
  return (ledger, plans[0], plans[1], proposal)
}

extension AlienStorageLegacyTransitionTests {
  @Test(arguments: [false, true])
  func fullOriginalCrossSectionAuditRefusesFreshPendingAndAcquiredNativeProperty(acquired: Bool)
    throws
  {
    let (ledger, a, b, proposal) = try genuineReservedCrossSectionSale()
    let owner = AlienLegacyFixture.owner
    let importedA = try NativeSalvageImport(
      ledger: ledger, section: a.section, owner: owner,
      at: 100, previous: nil)
    let exportedB = try ledger.exportNativeSection(b.section)
    let nativePlan = AlienStorageWorldPlan(
      id: UUID(), owner: owner, seed: 0, plan: b,
      inspectedAt: 0, requiredWorkSeconds: 1, workSeconds: 1, damagedTechnology: false,
      depleted: true, destroyed: false, lastOperation: 2, progress: exportedB.progress)
    let item = try #require(proposal.items.first { $0.identity.section == b.section })
    let operation = UUID()
    let property = UUID()
    var world: [AlienStorageWorldRecord] = [.plan(nativePlan)]
    let source: [AlienStorageSource]
    let attachments: [AlienStorageAttachment]
    let commands: [AlienStorageCommand]
    if acquired {
      source = [.init(id: operation, owner: owner, lot: item, acquisition: operation)]
      attachments = [
        .init(
          id: property, owner: owner, kind: try AlienModuleDefinition.kind(for: item),
          source: operation, disposition: .stored, contributionBasisPoints: 1000)
      ]
      commands = [
        .init(
          id: operation, owner: owner, revision: 1,
          action: .acquireAttachment(attachment: property, source: operation))
      ]
    } else {
      source = []
      attachments = []
      commands = []
    }
    world.append(
      .lot(
        .init(
          id: UUID(), owner: owner, plan: nativePlan.id, itemIndex: 0, issuedAt: 1,
          state: acquired
            ? .acquired(source: operation, at: 2)
            : .pending(lot: item, physicalTime: 2, offer: nil, binding: nil))))
    let emissions = try nativePlan.progress.emissions(plan: nativePlan)
    for original in exportedB.evidence.pending {
      let origin = try #require(emissions.first { $0.value.identity == original.identity }?.key)
      world.append(
        .companion(
          .init(
            id: UUID(), owner: owner, plan: nativePlan.id, origin: origin,
            issuedAt: 1, state: .pending(lot: original, physicalTime: 2, offer: nil, binding: nil)))
      )
    }
    let standalone = AlienStorageSnapshot(
      owner: owner, revision: UInt64(commands.count),
      worldRevision: 1, world: world, sources: source, attachments: attachments,
      upgrades: [], receipts: [], commands: commands)
    // This forged ownership is otherwise structurally valid without the old terminal audit.
    try standalone.validate()
    let combined = AlienStorageSnapshot(
      owner: owner, revision: standalone.revision,
      worldRevision: importedA.snapshot.worldRevision + 1,
      world: importedA.snapshot.world + world, sources: source, attachments: attachments,
      upgrades: [], receipts: [], commands: commands)
    #expect(throws: (any Error).self) { try combined.validateTransition(from: importedA.snapshot) }
    try importedA.snapshot.validate()
  }

  @Test func laterHonestLegacyImportReusesCompleteCrossSectionSettlementWithoutGrantingProperty()
    throws
  {
    let (ledger, a, b, proposal) = try genuineReservedCrossSectionSale()
    let owner = AlienLegacyFixture.owner
    let importedA = try NativeSalvageImport(
      ledger: ledger, section: a.section, owner: owner,
      at: 100, previous: nil)
    let importedB = try NativeSalvageImport(
      ledger: importedA.ledger, section: b.section,
      owner: owner, at: 101, previous: importedA.snapshot)
    try importedB.snapshot.validateTransition(from: importedA.snapshot)
    let headers = importedB.snapshot.world.compactMap { record -> AlienStorageLegacySettlement? in
      if case .legacySettlement(let header) = record { return header }
      return nil
    }
    let items = importedB.snapshot.world.compactMap { record -> AlienStorageLegacySettlementItem? in
      if case .legacySettlementItem(let item) = record { return item }
      return nil
    }
    #expect(headers.count == 1 && items.count == 2)
    let header = try #require(headers.first)
    let audit = AlienStorageLegacySettlements(headers: headers, items: items)
    #expect(try audit.proposal(for: header) == proposal)
    #expect(importedB.snapshot.sources.isEmpty && importedB.snapshot.attachments.isEmpty)
    #expect(importedB.snapshot.upgrades.isEmpty && importedB.snapshot.commands.isEmpty)
    #expect(
      importedB.ledger.isNativeTransferred(a.section)
        && importedB.ledger.isNativeTransferred(b.section))
  }
}
