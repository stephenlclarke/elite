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
