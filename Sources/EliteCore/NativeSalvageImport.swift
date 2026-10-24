import Foundation

/// A complete staged value transition from an original sealed ledger section.
/// This value alone supplies no actor, scene, tool or collection authority.
struct NativeSalvageImport: Sendable {
  private let original: SalvageNativeSectionExport
  private let previous: AlienStorageSnapshot?
  let owner: UUID
  let ledger: SalvageLedger
  let snapshot: AlienStorageSnapshot
  let section: UUID

  init(
    ledger: SalvageLedger, section identity: WreckSectionIdentity, owner: UUID,
    at time: Double, previous: AlienStorageSnapshot?
  ) throws {
    guard time.isFinite, time >= 0, previous?.owner == nil || previous?.owner == owner else {
      throw AlienStorageError.wrongOwner
    }
    let export = try ledger.exportNativeSection(identity)
    var builder = Builder(owner: owner, previous: previous)
    let sectionID = UUID()
    let record = AlienStorageLegacySection(
      id: sectionID, owner: owner, importOperation: UUID(), importedAt: time,
      ledgerRevision: export.revision, seed: export.seed, plan: export.plan,
      progress: export.progress, savedPartialWorkSeconds: export.partialWork,
      savedDamagedTechnology: export.damagedTechnology, sectionDepleted: export.depleted,
      sectionDestroyed: export.sectionDestroyed, wreckDestroyed: export.wreckDestroyed,
      savedLedgerLastOperation: export.lastOperation)
    try builder.importSettlements(export.evidence.settlements)
    let emissions = try SalvageSectionEmissionView(
      seed: export.seed, plan: export.plan, progress: export.progress
    ).emissions()
    let claims = try emissions.sorted { $0.value.identity.lot < $1.value.identity.lot }.map {
      entry in
      try builder.importClaim(item: entry.value, origin: entry.key, section: record, export: export)
    }
    let audit = builder.settlements
    let migrations = builder.migrations
    var transferred = ledger
    try transferred.transferNativeSection(export)
    try AlienStorageLegacyValidation.validateTransfer(
      section: record, lots: claims, before: export.evidence,
      after: transferred.nativeSectionCustody(identity), settlements: audit,
      migrations: migrations)
    builder.world.append(.legacySection(record))
    builder.world.append(contentsOf: claims.map(AlienStorageWorldRecord.legacyLot))
    let result = try builder.snapshot()
    try result.validateTransition(from: previous)
    original = export
    self.previous = previous
    self.owner = owner
    self.ledger = transferred
    snapshot = result
    section = sectionID
  }

  func matches(_ commander: Commander) -> Bool {
    commander.equipmentOwnerID == owner && original.matches(commander.salvageLedger)
      && commander.alienStorageState?.current.snapshot == previous
  }

  /// Only the native actor may invoke this inside its actual scene-sealed candidate.
  /// All custody and property changes are private until the whole save is published.
  func apply(to commander: inout Commander) throws {
    guard commander.alienStorageStateValid, matches(commander) else {
      throw AlienStorageError.historyChanged
    }
    var candidate = commander
    try candidate.replaceAlienStorage(with: snapshot)
    candidate.salvageLedger = ledger
    guard candidate.alienStorageStateValid else { throw AlienStorageError.invalidJoin }
    commander = candidate
  }

  private struct Builder {
    let owner: UUID
    let previous: AlienStorageSnapshot?
    var world: [AlienStorageWorldRecord]
    var sources: [AlienStorageSource]
    var attachments: [AlienStorageAttachment]
    var upgrades: [AlienStorageUpgrade]
    var commands: [AlienStorageCommand]
    var headers: [AlienStorageLegacySettlement]
    var items: [AlienStorageLegacySettlementItem]
    var migrations: [AlienStorageLegacyStoredMigration] = []

    init(owner: UUID, previous: AlienStorageSnapshot?) {
      self.owner = owner
      self.previous = previous
      world = previous?.world ?? []
      sources = previous?.sources ?? []
      attachments = previous?.attachments ?? []
      upgrades = previous?.upgrades ?? []
      commands = previous?.commands ?? []
      headers = world.compactMap { if case .legacySettlement(let x) = $0 { x } else { nil } }
      items = world.compactMap { if case .legacySettlementItem(let x) = $0 { x } else { nil } }
    }

    var settlements: AlienStorageLegacySettlements { .init(headers: headers, items: items) }

    mutating func importSettlements(_ originals: [SalvageSettlementProposal]) throws {
      for proposal in originals {
        if let existing = headers.first(where: { $0.command == proposal.command }) {
          guard try settlements.proposal(for: existing) == proposal else {
            throw AlienStorageError.historyChanged
          }
          continue
        }
        guard let count = UInt16(exactly: proposal.items.count), count > 0 else {
          throw AlienStorageError.invalidJoin
        }
        let header = AlienStorageLegacySettlement(
          id: proposal.command, owner: owner, command: proposal.command,
          revision: proposal.revision, action: proposal.action,
          saleValueTenths: proposal.saleValueTenths, binding: proposal.binding, itemCount: count)
        headers.append(header)
        world.append(.legacySettlement(header))
        for (ordinal, lot) in proposal.items.enumerated() {
          guard let value = UInt16(exactly: ordinal) else { throw AlienStorageError.invalidJoin }
          let member = AlienStorageLegacySettlementItem(
            id: UUID(), owner: owner, settlement: header.id, ordinal: value, lot: lot)
          items.append(member)
          world.append(.legacySettlementItem(member))
        }
      }
    }

    mutating func importClaim(
      item: SalvageLootItem, origin: AlienStorageEmissionOrigin,
      section: AlienStorageLegacySection, export: SalvageNativeSectionExport
    ) throws -> AlienStorageLegacyLot {
      let id = UUID()
      let state: AlienStorageLegacyLot.State
      if let lot = export.evidence.pending.first(where: { $0.identity == item.identity }) {
        let offer = export.evidence.offers.first { $0.value == lot.identity }?.key
        let binding = export.evidence.bindings[lot.identity]
        state = .pending(lot: lot, offer: offer, binding: binding)
        world.append(
          .legacyCurrent(
            .init(
              id: UUID(), owner: owner, claim: id,
              state: .pending(lot: lot, at: section.importedAt, offer: offer, binding: binding))))
      } else if let lot = export.evidence.stored.first(where: { $0.identity == item.identity }) {
        if case .technology(let definition, _, _) = lot.content,
          AlienModuleDefinition.isAttachmentDefinition(definition)
        {
          let source = try importStored(lot, section: section.id, claim: id)
          state = .storedReserved(lot: lot, migrationOperation: source, source: source)
        } else {
          state = .retainedOrdinaryStored(lot: lot)
        }
      } else if let member = items.first(where: { $0.lot.identity == item.identity }) {
        state = .legacySettled(settlement: member.settlement, item: member.id)
      } else {
        state = .legacyUnavailable
      }
      return .init(
        id: id, owner: owner, section: section.id, origin: origin,
        identity: item.identity, state: state)
    }

    mutating func importStored(_ lot: SalvageLot, section: UUID, claim: UUID) throws -> UUID {
      let operation = UUID()
      let property = UUID()
      guard let oldCount = UInt64(exactly: commands.count) else {
        throw AlienStorageError.arithmeticOverflow
      }
      let revision = oldCount.addingReportingOverflow(1)
      guard !revision.overflow else { throw AlienStorageError.arithmeticOverflow }
      let action: AlienStorageCommand.Action
      let migrationKind: AlienStorageLegacyStoredMigration.Kind
      if let kind = try? AlienModuleDefinition.kind(for: lot) {
        attachments.append(
          .init(
            id: property, owner: owner, kind: kind, source: operation, disposition: .stored,
            contributionBasisPoints: kind.initialContribution))
        action = .migrateStoredAttachment(
          attachment: property, source: operation, section: section, claim: claim)
        migrationKind = .attachment(kind)
      } else {
        guard case .technology(let definition, _, _) = lot.content,
          let kind = AlienModuleKind.allCases.first(where: { $0.upgradeDefinitionID == definition })
        else { throw AlienStorageError.invalidJoin }
        _ = try AlienModuleDefinition.upgradeBonus(for: lot, kind: kind)
        upgrades.append(
          .init(
            id: property, owner: owner, kind: kind, source: operation, disposition: .stored))
        action = .migrateStoredUpgrade(
          upgrade: property, source: operation, section: section, claim: claim)
        migrationKind = .upgrade(kind)
      }
      sources.append(.init(id: operation, owner: owner, lot: lot, acquisition: operation))
      commands.append(
        .init(id: operation, owner: owner, revision: revision.partialValue, action: action))
      migrations.append(
        .init(
          operation: operation, owner: owner, section: section, identity: lot.identity, lot: lot,
          source: operation, property: property, kind: migrationKind))
      return operation
    }

    func snapshot() throws -> AlienStorageSnapshot {
      let revision = (previous?.worldRevision ?? 0).addingReportingOverflow(1)
      guard !revision.overflow, let count = UInt64(exactly: commands.count) else {
        throw AlienStorageError.arithmeticOverflow
      }
      return .init(
        owner: owner, revision: count, worldRevision: revision.partialValue, world: world,
        sources: sources, attachments: attachments, upgrades: upgrades,
        receipts: previous?.receipts ?? [], commands: commands)
    }
  }
}
