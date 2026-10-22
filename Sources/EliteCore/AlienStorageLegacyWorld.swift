import Foundation

/// Whole-world joins for immutable imports and their separate current custody.
enum AlienStorageLegacyWorldValidation {
  static func validate(
    _ records: [AlienStorageWorldRecord], owner: UUID, sources: [AlienStorageSource],
    commands: [AlienStorageCommand]
  ) throws -> Set<UUID> {
    let hasLegacy = records.contains { record in
      switch record {
      case .legacySection, .legacyLot, .legacySettlement, .legacySettlementItem, .legacyCurrent:
        true
      default: false
      }
    }
    if !hasLegacy {
      guard
        !commands.contains(where: { command in
          switch command.action {
          case .migrateStoredAttachment, .migrateStoredUpgrade: true
          default: false
          }
        })
      else { throw AlienStorageError.invalidJoin }
      return []
    }
    var sections: [AlienStorageLegacySection] = []
    var claims: [AlienStorageLegacyLot] = []
    var headers: [AlienStorageLegacySettlement] = []
    var items: [AlienStorageLegacySettlementItem] = []
    var current: [AlienStorageLegacyCurrent] = []
    var physicalSections: Set<WreckSectionIdentity> = []
    var offers: Set<SpawnIdentity> = []
    var actors: Set<ActorIdentity> = []
    var operations = Set(sources.map(\.id))
    var technology: Set<UUID> = []
    for record in records {
      switch record {
      case .plan(let plan):
        guard physicalSections.insert(plan.plan.section).inserted else {
          throw AlienStorageError.duplicateKey
        }
      case .lot(let lot):
        if case .pending(_, _, let offer, let binding) = lot.state {
          try reserve(offer, binding, offers: &offers, actors: &actors)
        }
      case .companion(let lot):
        if case .pending(_, _, let offer, let binding) = lot.state {
          try reserve(offer, binding, offers: &offers, actors: &actors)
        } else if let receipt = lot.state.collection {
          guard operations.insert(receipt.operation).inserted else {
            throw AlienStorageError.invalidJoin
          }
          if case .technology(let id) = receipt.effect {
            guard technology.insert(id).inserted else { throw AlienStorageError.duplicateKey }
          }
        }
      case .nativeInspection(let value):
        guard physicalSections.insert(value.plan.section).inserted else {
          throw AlienStorageError.duplicateKey
        }
      case .nativeWreck, .nativeWork: break
      case .legacySection(let value): sections.append(value)
      case .legacyLot(let value): claims.append(value)
      case .legacySettlement(let value): headers.append(value)
      case .legacySettlementItem(let value): items.append(value)
      case .legacyCurrent(let value): current.append(value)
      }
    }
    let sectionMap = try unique(sections, id: \.id)
    let claimMap = try unique(claims, id: \.id)
    let currentMap = try unique(current, id: \.claim)
    let sourceMap = try unique(sources, id: \.id)
    let commandMap = try unique(commands, id: \.id)
    let audit = AlienStorageLegacySettlements(headers: headers, items: items)
    try AlienStorageLegacyValidation.validateSettlements(audit, owner: owner)
    guard sections.allSatisfy({ $0.owner == owner }), claims.allSatisfy({ $0.owner == owner }),
      current.allSatisfy({ $0.owner == owner }),
      claims.allSatisfy({ sectionMap[$0.section] != nil }),
      current.allSatisfy({ claimMap[$0.claim] != nil }),
      Set(sections.map(\.importOperation)).count == sections.count,
      Set(headers.map(\.command)).isDisjoint(with: commands.map(\.id))
    else { throw AlienStorageError.invalidJoin }
    let bySection = Dictionary(grouping: claims, by: \.section)
    var claimedSources: Set<UUID> = []
    var migratedOperations: Set<UUID> = []
    for section in sections {
      guard physicalSections.insert(section.plan.section).inserted else {
        throw AlienStorageError.duplicateKey
      }
      let members = bySection[section.id] ?? []
      var pending: [SalvageLot] = []
      var stored: [SalvageLot] = []
      var originalOffers: [SpawnIdentity: SalvageLotIdentity] = [:]
      var originalBindings: [SalvageLotIdentity: ActorIdentity] = [:]
      var migrations: [AlienStorageLegacyStoredMigration] = []
      let emissions = try SalvageSectionEmissionView(
        seed: section.seed, plan: section.plan, progress: section.progress
      ).emissions()
      for claim in members {
        guard let item = emissions[claim.origin] else { throw AlienStorageError.invalidJoin }
        switch claim.state {
        case .pending(let lot, let offer, let binding):
          pending.append(lot)
          if let offer { originalOffers[offer] = lot.identity }
          if let binding { originalBindings[lot.identity] = binding }
          guard let live = currentMap[claim.id] else { throw AlienStorageError.invalidJoin }
          if let source = try validateCurrent(
            live, claim: claim, section: section, item: item,
            sources: sourceMap, commands: commandMap, offers: &offers, actors: &actors,
            operations: &operations, technology: &technology)
          {
            guard claimedSources.insert(source).inserted else {
              throw AlienStorageError.invalidJoin
            }
          }
        case .storedReserved(let lot, let operation, let source):
          guard currentMap[claim.id] == nil, claimedSources.insert(source).inserted,
            migratedOperations.insert(operation).inserted
          else { throw AlienStorageError.invalidJoin }
          stored.append(lot)
          migrations.append(
            try migration(
              claim, lot: lot, operation: operation, source: source,
              section: section, sources: sourceMap, commands: commandMap))
        case .retainedOrdinaryStored(let lot):
          guard currentMap[claim.id] == nil else { throw AlienStorageError.invalidJoin }
          stored.append(lot)
        case .legacySettled, .legacyUnavailable:
          guard currentMap[claim.id] == nil else { throw AlienStorageError.invalidJoin }
        }
      }
      let relevant = try headers.compactMap { header -> SalvageSettlementProposal? in
        let proposal = try audit.proposal(for: header)
        return proposal.items.contains { $0.identity.section == section.plan.section }
          ? proposal : nil
      }
      let evidence = AlienStorageLegacyCustodyEvidence(
        pending: pending, stored: stored, offers: originalOffers, bindings: originalBindings,
        settlements: relevant)
      try AlienStorageLegacyValidation.validate(
        section: section, lots: members, evidence: evidence, settlements: audit,
        migrations: migrations)
    }
    let declaredMigrations = Set(
      commands.compactMap { command -> UUID? in
        switch command.action {
        case .migrateStoredAttachment, .migrateStoredUpgrade: command.id
        default: nil
        }
      })
    guard migratedOperations == declaredMigrations else { throw AlienStorageError.invalidJoin }
    return claimedSources
  }

  private static func migration(
    _ claim: AlienStorageLegacyLot, lot: SalvageLot, operation: UUID, source: UUID,
    section: AlienStorageLegacySection, sources: [UUID: AlienStorageSource],
    commands: [UUID: AlienStorageCommand]
  ) throws -> AlienStorageLegacyStoredMigration {
    guard let receipt = sources[source], receipt.lot == lot, receipt.acquisition == operation,
      let command = commands[operation], command.owner == section.owner
    else { throw AlienStorageError.invalidJoin }
    let property: UUID
    let kind: AlienStorageLegacyStoredMigration.Kind
    switch command.action {
    case .migrateStoredAttachment(let id, let sourceID, let sectionID, let claimID):
      guard sourceID == source, sectionID == section.id, claimID == claim.id else {
        throw AlienStorageError.invalidJoin
      }
      property = id
      kind = .attachment(try AlienModuleDefinition.kind(for: lot))
    case .migrateStoredUpgrade(let id, let sourceID, let sectionID, let claimID):
      guard sourceID == source, sectionID == section.id, claimID == claim.id,
        case .technology(let definition, _, _) = lot.content,
        let module = AlienModuleKind.allCases.first(where: { $0.upgradeDefinitionID == definition })
      else { throw AlienStorageError.invalidJoin }
      _ = try AlienModuleDefinition.upgradeBonus(for: lot, kind: module)
      property = id
      kind = .upgrade(module)
    default: throw AlienStorageError.invalidJoin
    }
    return .init(
      operation: operation, owner: section.owner, section: section.id, identity: lot.identity,
      lot: lot, source: source, property: property, kind: kind)
  }

  private static func validateCurrent(
    _ value: AlienStorageLegacyCurrent, claim: AlienStorageLegacyLot,
    section: AlienStorageLegacySection, item: SalvageLootItem,
    sources: [UUID: AlienStorageSource], commands: [UUID: AlienStorageCommand],
    offers: inout Set<SpawnIdentity>, actors: inout Set<ActorIdentity>,
    operations: inout Set<UUID>, technology: inout Set<UUID>
  ) throws -> UUID? {
    func validTime(_ time: Double) -> Bool { time.isFinite && time >= section.importedAt }
    let reserved: Bool
    if case .technology(let id, _, _, _) = item.content {
      reserved = AlienModuleDefinition.isAttachmentDefinition(id)
    } else {
      reserved = false
    }
    switch value.state {
    case .pending(let lot, let at, let offer, let binding):
      guard validTime(at), offer == nil || binding == nil else {
        throw AlienStorageError.invalidJoin
      }
      try SalvageLotEmission.validate(lot, item: item)
      let system = lot.identity.section.wreck.system
      if let offer {
        guard offer.system == system, offer.producer == .salvage,
          offer.visit > 0, offer.visit < UInt64.max, offer.sequence > 0,
          offer.sequence < UInt64.max,
          offer.member == 0
        else { throw AlienStorageError.invalidJoin }
      }
      if let binding {
        guard binding.system == system, binding.visit > 0, binding.visit < UInt64.max,
          binding.entity >= 2, binding.entity < UInt64.max
        else { throw AlienStorageError.invalidJoin }
      }
      try reserve(offer, binding, offers: &offers, actors: &actors)
    case .acquired(let id, let at):
      guard reserved, validTime(at), let source = sources[id],
        let command = commands[source.acquisition]
      else { throw AlienStorageError.invalidJoin }
      try SalvageLotEmission.validate(source.lot, item: item)
      switch command.action {
      case .acquireAttachment(_, let sourceID), .acquireUpgrade(_, let sourceID):
        guard sourceID == id else { throw AlienStorageError.invalidJoin }
      default: throw AlienStorageError.invalidJoin
      }
      return id
    case .collected(let receipt), .researched(let receipt, _):
      guard !reserved, validTime(receipt.at), operations.insert(receipt.operation).inserted else {
        throw AlienStorageError.invalidJoin
      }
      if case .researched(_, let research) = value.state {
        try research.validate(item: item, collection: receipt, owner: value.owner)
        guard operations.insert(research.operation).inserted else {
          throw AlienStorageError.invalidJoin
        }
      }
      switch (item.content, receipt.effect) {
      case (.commodity(let original), .cargo(let amount, let before, let after)):
        let sum = before.addingReportingOverflow(original.quantity)
        guard original == amount, before >= 0, !sum.overflow, after == sum.partialValue else {
          throw AlienStorageError.invalidJoin
        }
      case (.technology, .technology(let storage)):
        guard technology.insert(storage).inserted else { throw AlienStorageError.invalidJoin }
      default: throw AlienStorageError.invalidJoin
      }
    case .discarded(let at), .destroyed(let at):
      guard validTime(at) else { throw AlienStorageError.invalidJoin }
    }
    return nil
  }

  private static func reserve(
    _ offer: SpawnIdentity?, _ actor: ActorIdentity?, offers: inout Set<SpawnIdentity>,
    actors: inout Set<ActorIdentity>
  ) throws {
    if let offer, !offers.insert(offer).inserted { throw AlienStorageError.invalidJoin }
    if let actor, !actors.insert(actor).inserted { throw AlienStorageError.invalidJoin }
  }
  private static func unique<T, Key: Hashable>(_ values: [T], id: KeyPath<T, Key>) throws -> [Key:
    T]
  {
    var result: [Key: T] = [:]
    for value in values {
      guard result.updateValue(value, forKey: value[keyPath: id]) == nil else {
        throw AlienStorageError.duplicateKey
      }
    }
    return result
  }
}
