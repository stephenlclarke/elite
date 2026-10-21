import Foundation

/// Pure conservation checks only. Authentic exports, current scene seals and publication
/// remain G1's responsibility; passing these checks never grants native authority.
enum AlienStorageLegacyValidation {
  static func validate(
    section: AlienStorageLegacySection, lots: [AlienStorageLegacyLot],
    evidence: AlienStorageLegacyCustodyEvidence, settlements: AlienStorageLegacySettlements,
    migrations: [AlienStorageLegacyStoredMigration]
  ) throws {
    try validateSection(section)
    let view = SalvageSectionEmissionView(
      seed: section.seed, plan: section.plan, progress: section.progress)
    let emissions = try view.emissions()
    let audit = try settlementIndex(settlements, owner: section.owner)
    let custody = try custodyIndex(evidence, section: section, audit: audit)
    let transfers = try migrationIndex(migrations, section: section)
    var ids: Set<UUID> = [section.id]
    var origins: Set<AlienStorageEmissionOrigin> = []
    var identities: Set<SalvageLotIdentity> = []
    var migrated: Set<SalvageLotIdentity> = []
    for claim in lots {
      guard claim.owner == section.owner else { throw AlienStorageError.wrongOwner }
      guard ids.insert(claim.id).inserted else { throw AlienStorageError.duplicateKey }
      guard claim.section == section.id, let item = emissions[claim.origin],
        claim.identity == item.identity, origins.insert(claim.origin).inserted,
        identities.insert(claim.identity).inserted
      else { throw AlienStorageError.invalidJoin }
      try validateClaim(
        claim, item: item, custody: custody, audit: audit, evidence: evidence,
        transfers: transfers, migrated: &migrated)
    }
    guard origins == Set(emissions.keys), identities == Set(emissions.values.map(\.identity)),
      migrated == Set(transfers.keys),
      Set(custody.pending.keys).union(custody.stored.keys).union(custody.settled.keys)
        .isSubset(of: identities)
    else { throw AlienStorageError.invalidJoin }
  }

  static func validateSettlements(_ settlements: AlienStorageLegacySettlements, owner: UUID)
    throws
  {
    _ = try settlementIndex(settlements, owner: owner)
  }

  static func preserve(
    section old: AlienStorageLegacySection, lots oldLots: [AlienStorageLegacyLot],
    in section: AlienStorageLegacySection, lots: [AlienStorageLegacyLot]
  ) throws {
    guard old == section, try unique(oldLots, id: \.id) == unique(lots, id: \.id) else {
      throw AlienStorageError.historyChanged
    }
  }

  static func preserveSettlements(
    _ old: AlienStorageLegacySettlements, in current: AlienStorageLegacySettlements
  ) throws {
    try preserveRecords(old.headers, in: current.headers, id: \.id)
    try preserveRecords(old.items, in: current.items, id: \.id)
  }

  /// The supplied evidence is section-local except for whole original proposals.
  /// No old settlement is appended, and ordinary stored technology remains in old custody.
  static func validateTransfer(
    section: AlienStorageLegacySection, lots: [AlienStorageLegacyLot],
    before: AlienStorageLegacyCustodyEvidence, after: AlienStorageLegacyCustodyEvidence,
    settlements: AlienStorageLegacySettlements, migrations: [AlienStorageLegacyStoredMigration]
  ) throws {
    try validate(
      section: section, lots: lots, evidence: before, settlements: settlements,
      migrations: migrations)
    let stored = try unique(before.stored, id: \.identity)
    let removed = Set(migrations.map(\.identity))
    guard after.pending.isEmpty, after.offers.isEmpty, after.bindings.isEmpty,
      try unique(after.stored, id: \.identity) == stored.filter({ !removed.contains($0.key) }),
      try unique(before.settlements, id: \.command) == unique(after.settlements, id: \.command)
    else { throw AlienStorageError.invalidJoin }
  }

  private struct SettlementIndex {
    let headers: [UUID: AlienStorageLegacySettlement]
    let items: [UUID: AlienStorageLegacySettlementItem]
    let proposals: [UUID: SalvageSettlementProposal]
  }
  private struct CustodyIndex {
    let pending: [SalvageLotIdentity: SalvageLot]
    let stored: [SalvageLotIdentity: SalvageLot]
    let settled: [SalvageLotIdentity: UUID]
  }

  private static func validateSection(_ section: AlienStorageLegacySection) throws {
    guard section.importedAt.isFinite, section.importedAt >= 0,
      section.savedPartialWorkSeconds.map({ $0.isFinite && $0 > 0 }) ?? true,
      !section.savedDamagedTechnology || section.savedPartialWorkSeconds != nil,
      section.savedPartialWorkSeconds == nil
        || (!section.sectionDepleted && !section.sectionDestroyed && !section.wreckDestroyed),
      !section.sectionDestroyed || section.sectionDepleted,
      (section.savedPartialWorkSeconds == nil && section.progress.nextLot == 0
        && !section.sectionDestroyed) || section.savedLedgerLastOperation != nil
    else { throw AlienStorageError.invalidJoin }
    try SalvageSectionEmissionView(
      seed: section.seed, plan: section.plan, progress: section.progress
    ).validate()
    if section.sectionDepleted && !section.sectionDestroyed && !section.wreckDestroyed {
      guard section.progress.issuedStructural == section.progress.structuralUnits,
        section.plan.items.indices.allSatisfy({
          section.progress.issued[$0] == SalvageLotEmission.quantity(section.plan.items[$0])
        })
      else { throw AlienStorageError.invalidJoin }
    }
  }

  private static func settlementIndex(_ values: AlienStorageLegacySettlements, owner: UUID)
    throws -> SettlementIndex
  {
    let headers = try unique(values.headers, id: \.id)
    let items = try unique(values.items, id: \.id)
    guard Set(headers.keys).isDisjoint(with: items.keys) else {
      throw AlienStorageError.duplicateKey
    }
    let groups = Dictionary(grouping: values.items, by: \.settlement)
    var proposals: [UUID: SalvageSettlementProposal] = [:]
    var identities: Set<SalvageLotIdentity> = []
    for item in values.items {
      guard item.owner == owner else { throw AlienStorageError.wrongOwner }
      guard let header = headers[item.settlement], item.ordinal < header.itemCount,
        identities.insert(item.lot.identity).inserted,
        case .technology = item.lot.content
      else { throw AlienStorageError.invalidJoin }
    }
    for header in values.headers {
      guard header.owner == owner else { throw AlienStorageError.wrongOwner }
      guard header.itemCount > 0, Int(header.itemCount) <= SalvageLedger.maximumInventory,
        header.saleValueTenths >= 0
      else { throw AlienStorageError.invalidJoin }
      let members = (groups[header.id] ?? []).sorted { $0.ordinal < $1.ordinal }
      guard members.count == Int(header.itemCount),
        members.enumerated().allSatisfy({ Int($0.element.ordinal) == $0.offset })
      else { throw AlienStorageError.invalidJoin }
      let proposal = SalvageSettlementProposal(
        command: header.command, revision: header.revision, items: members.map(\.lot),
        action: header.action, saleValueTenths: header.saleValueTenths, binding: header.binding)
      guard proposals.updateValue(proposal, forKey: header.command) == nil else {
        throw AlienStorageError.duplicateKey
      }
    }
    return .init(headers: headers, items: items, proposals: proposals)
  }

  private static func custodyIndex(
    _ evidence: AlienStorageLegacyCustodyEvidence, section: AlienStorageLegacySection,
    audit: SettlementIndex
  ) throws -> CustodyIndex {
    let pending = try unique(evidence.pending, id: \.identity)
    let stored = try unique(evidence.stored, id: \.identity)
    let proposals = try unique(evidence.settlements, id: \.command)
    let relevantAudit = audit.proposals.filter {
      $0.value.items.contains(where: { $0.identity.section == section.plan.section })
    }
    guard Set(pending.keys).isDisjoint(with: stored.keys),
      proposals == relevantAudit,
      pending.keys.allSatisfy({ $0.section == section.plan.section }),
      stored.keys.allSatisfy({ $0.section == section.plan.section }),
      stored.values.allSatisfy({
        if case .technology = $0.content { return true }
        return false
      }),
      Set(evidence.bindings.keys).isSubset(of: Set(pending.keys)),
      Set(evidence.offers.values).isSubset(of: Set(pending.keys)),
      Set(evidence.offers.values).count == evidence.offers.count,
      Set(evidence.bindings.values).count == evidence.bindings.count,
      Set(evidence.offers.values).isDisjoint(with: evidence.bindings.keys)
    else { throw AlienStorageError.invalidJoin }
    for (offer, identity) in evidence.offers {
      guard offer.system == identity.section.wreck.system, offer.producer == .salvage,
        offer.visit > 0, offer.visit < UInt64.max, offer.sequence > 0,
        offer.sequence < UInt64.max, offer.member == 0
      else { throw AlienStorageError.invalidJoin }
    }
    for (identity, actor) in evidence.bindings {
      guard actor.system == identity.section.wreck.system, actor.visit > 0,
        actor.visit < UInt64.max, actor.entity >= 2, actor.entity < UInt64.max
      else { throw AlienStorageError.invalidJoin }
    }
    var settled: [SalvageLotIdentity: UUID] = [:]
    for proposal in proposals.values {
      guard audit.proposals[proposal.command] == proposal,
        proposal.items.contains(where: { $0.identity.section == section.plan.section })
      else { throw AlienStorageError.invalidJoin }
      for lot in proposal.items where lot.identity.section == section.plan.section {
        guard pending[lot.identity] == nil, stored[lot.identity] == nil,
          settled.updateValue(proposal.command, forKey: lot.identity) == nil
        else { throw AlienStorageError.invalidJoin }
      }
    }
    return .init(pending: pending, stored: stored, settled: settled)
  }

  private static func migrationIndex(
    _ values: [AlienStorageLegacyStoredMigration], section: AlienStorageLegacySection
  ) throws -> [SalvageLotIdentity: AlienStorageLegacyStoredMigration] {
    let result = try unique(values, id: \.identity)
    var operations: Set<UUID> = []
    var sources: Set<UUID> = []
    var properties: Set<UUID> = []
    for value in values {
      guard value.owner == section.owner else { throw AlienStorageError.wrongOwner }
      guard value.section == section.id, value.identity == value.lot.identity,
        operations.insert(value.operation).inserted, sources.insert(value.source).inserted,
        properties.insert(value.property).inserted
      else { throw AlienStorageError.invalidJoin }
      switch value.kind {
      case .attachment(let kind):
        guard try AlienModuleDefinition.kind(for: value.lot) == kind else {
          throw AlienStorageError.invalidJoin
        }
      case .upgrade(let kind):
        _ = try AlienModuleDefinition.upgradeBonus(for: value.lot, kind: kind)
      }
    }
    return result
  }

  private static func validateClaim(
    _ claim: AlienStorageLegacyLot, item: SalvageLootItem, custody: CustodyIndex,
    audit: SettlementIndex, evidence: AlienStorageLegacyCustodyEvidence,
    transfers: [SalvageLotIdentity: AlienStorageLegacyStoredMigration],
    migrated: inout Set<SalvageLotIdentity>
  ) throws {
    let identity = claim.identity
    switch claim.state {
    case .pending(let lot, let offer, let binding):
      let originalOffer = evidence.offers.first { $0.value == identity }?.key
      guard custody.pending[identity] == lot, offer == originalOffer,
        binding == evidence.bindings[identity]
      else { throw AlienStorageError.invalidJoin }
      try SalvageLotEmission.validate(lot, item: item)
    case .storedReserved(let lot, let operation, let source):
      guard custody.stored[identity] == lot, let transfer = transfers[identity],
        transfer.lot == lot, transfer.operation == operation, transfer.source == source,
        migrated.insert(identity).inserted
      else { throw AlienStorageError.invalidJoin }
      try SalvageLotEmission.validate(lot, item: item)
    case .retainedOrdinaryStored(let lot):
      guard custody.stored[identity] == lot, case .technology(let id, _, _) = lot.content,
        !AlienModuleDefinition.isAttachmentDefinition(id), transfers[identity] == nil
      else { throw AlienStorageError.invalidJoin }
      try SalvageLotEmission.validate(lot, item: item)
    case .legacySettled(let settlement, let member):
      guard let header = audit.headers[settlement], let evidence = audit.items[member],
        evidence.settlement == settlement, evidence.lot.identity == identity,
        custody.settled[identity] == header.command
      else { throw AlienStorageError.invalidJoin }
      try SalvageLotEmission.validate(evidence.lot, item: item)
    case .legacyUnavailable:
      guard custody.pending[identity] == nil, custody.stored[identity] == nil,
        custody.settled[identity] == nil
      else { throw AlienStorageError.invalidJoin }
    }
  }

  private static func unique<T, Key: Hashable>(_ values: [T], id: KeyPath<T, Key>) throws
    -> [Key: T]
  {
    var result: [Key: T] = [:]
    for value in values {
      guard result.updateValue(value, forKey: value[keyPath: id]) == nil else {
        throw AlienStorageError.duplicateKey
      }
    }
    return result
  }

  private static func preserveRecords<T: Equatable>(
    _ old: [T], in current: [T], id: KeyPath<T, UUID>
  ) throws {
    let previous = try unique(old, id: id)
    let next = try unique(current, id: id)
    guard previous.allSatisfy({ next[$0.key] == $0.value }) else {
      throw AlienStorageError.historyChanged
    }
  }
}
