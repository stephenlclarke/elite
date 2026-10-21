import Foundation

enum AlienStorageError: Error, Equatable {
  case invalidSnapshot, wrongOwner, invalidJoin, arithmeticOverflow, historyChanged
  case invalidReference, invalidPage, hashMismatch, duplicateKey, aliasedPage, oversizedRecord
}

struct AlienStorageSource: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let lot: SalvageLot
  let acquisition: UUID
}

enum AlienStorageDisposition: Codable, Sendable, Equatable {
  case stored
  case fitted(hull: UUID)
  case retired(AlienAttachmentRetirement)
}
struct AlienStorageAttachment: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let kind: AlienModuleKind
  let source: UUID
  let disposition: AlienStorageDisposition
  let contributionBasisPoints: Int
}

enum AlienStorageUpgradeDisposition: Codable, Sendable, Equatable {
  case stored
  case applied(attachment: UUID, operation: UUID)
  case retired(AlienAttachmentRetirement)
}
struct AlienStorageUpgrade: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let kind: AlienModuleKind
  let source: UUID
  let disposition: AlienStorageUpgradeDisposition
}

struct AlienStorageReceipt: Codable, Sendable, Equatable {
  enum Effect: Codable, Sendable, Equatable {
    case upgrade(attachment: UUID, upgrade: UUID, basisPoints: Int)
    case transfer(attachment: UUID)
  }
  let id: UUID
  let owner: UUID
  let operation: UUID
  let effect: Effect
}
struct AlienStorageCommand: Codable, Sendable, Equatable {
  enum Action: Codable, Sendable, Equatable {
    case acquireAttachment(attachment: UUID, source: UUID)
    case acquireUpgrade(upgrade: UUID, source: UUID)
    case migrateStoredAttachment(attachment: UUID, source: UUID, section: UUID, claim: UUID)
    case migrateStoredUpgrade(upgrade: UUID, source: UUID, section: UUID, claim: UUID)
    case applyUpgrade(attachment: UUID, upgrade: UUID)
    case relocate(attachment: UUID, to: AlienStorageDisposition)
    case retireAttachment(attachment: UUID, reason: AlienAttachmentRetirement)
    case retireUpgrade(upgrade: UUID, reason: AlienAttachmentRetirement)
    case transferHull(from: UUID, to: UUID, members: UInt64)
  }
  let id: UUID
  let owner: UUID
  let revision: UInt64
  let action: Action
}

/// Normalized in-memory values, deliberately not a Codable lifetime-history blob.
/// Native acquisition, dock authority and durable actor publication belong to G1.
struct AlienStorageSnapshot: Sendable, Equatable {
  let owner: UUID
  let revision: UInt64
  let worldRevision: UInt64
  let world: [AlienStorageWorldRecord]
  let sources: [AlienStorageSource]
  let attachments: [AlienStorageAttachment]
  let upgrades: [AlienStorageUpgrade]
  let receipts: [AlienStorageReceipt]
  let commands: [AlienStorageCommand]

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.owner == rhs.owner && lhs.revision == rhs.revision && lhs.worldRevision == rhs.worldRevision
      && same(lhs.world, rhs.world, id: \.id) && same(lhs.sources, rhs.sources, id: \.id)
      && same(lhs.attachments, rhs.attachments, id: \.id)
      && same(lhs.upgrades, rhs.upgrades, id: \.id)
      && same(lhs.receipts, rhs.receipts, id: \.id) && same(lhs.commands, rhs.commands, id: \.id)
  }
  private static func same<T: Equatable>(_ lhs: [T], _ rhs: [T], id: KeyPath<T, UUID>) -> Bool {
    if lhs == rhs { return true }
    guard lhs.count == rhs.count, let a = try? unique(lhs, id: id), let b = try? unique(rhs, id: id)
    else { return false }
    return a == b
  }

  func validate() throws {
    guard world.isEmpty || worldRevision > 0 else { throw AlienStorageError.invalidSnapshot }
    let sourceMap = try Self.unique(sources, id: \.id)
    let attachmentMap = try Self.unique(attachments, id: \.id)
    let upgradeMap = try Self.unique(upgrades, id: \.id)
    let commandMap = try Self.unique(commands, id: \.id)
    _ = try Self.unique(receipts, id: \.id)
    guard sources.allSatisfy({ $0.owner == owner }), attachments.allSatisfy({ $0.owner == owner }),
      upgrades.allSatisfy({ $0.owner == owner }), receipts.allSatisfy({ $0.owner == owner }),
      commands.allSatisfy({ $0.owner == owner })
    else { throw AlienStorageError.wrongOwner }
    guard UInt64(exactly: commands.count) == revision,
      Set(commands.map(\.revision)).count == commands.count,
      commands.allSatisfy({ $0.revision > 0 && $0.revision <= revision }),
      Set(attachmentMap.keys).isDisjoint(with: upgradeMap.keys)
    else { throw AlienStorageError.invalidSnapshot }
    var claims: Set<SalvageLotIdentity> = []
    for source in sources {
      guard claims.insert(source.lot.identity).inserted, source.acquisition == source.id,
        commandMap[source.acquisition] != nil
      else { throw AlienStorageError.invalidJoin }
    }
    for case .companion(let companion) in world {
      if case .collected(let receipt) = companion.state,
        case .technology(let storage) = receipt.effect
      {
        guard attachmentMap[storage] == nil, upgradeMap[storage] == nil else {
          throw AlienStorageError.invalidJoin
        }
      }
    }
    try AlienStorageWorldValidation.validate(world, owner: owner, sources: sources, commands: commands)
    let receiptsByCommand = Dictionary(grouping: receipts, by: \.operation)
    guard receiptsByCommand.keys.allSatisfy({ commandMap[$0] != nil }) else {
      throw AlienStorageError.invalidJoin
    }
    var replay = AlienStorageReplay()
    for command in commands.sorted(by: { $0.revision < $1.revision }) {
      try replay.apply(
        command, receipts: receiptsByCommand[command.id] ?? [],
        sources: sourceMap, attachments: attachmentMap, upgrades: upgradeMap)
    }
    guard replay.claimedSources == Set(sourceMap.keys),
      replay.attachments.count == attachments.count,
      replay.upgrades.count == upgrades.count
    else { throw AlienStorageError.invalidJoin }
    for attachment in attachments {
      guard let actual = replay.attachments[attachment.id],
        actual.disposition == attachment.disposition,
        actual.bonus == attachment.contributionBasisPoints
      else { throw AlienStorageError.invalidJoin }
    }
    for upgrade in upgrades {
      guard replay.upgrades[upgrade.id] == upgrade.disposition else {
        throw AlienStorageError.invalidJoin
      }
    }
  }

  /// Permanent evidence is append-only even when the current physical item is retired.
  func validateTransition(from previous: AlienStorageSnapshot?) throws {
    try validate()
    guard let previous else { return }
    try previous.validate()
    guard owner == previous.owner else { throw AlienStorageError.wrongOwner }
    guard worldRevision >= previous.worldRevision,
      Self.same(world, previous.world, id: \.id) || worldRevision > previous.worldRevision
    else { throw AlienStorageError.historyChanged }
    try AlienStorageWorldValidation.preserve(previous.world, in: world)
    guard revision >= previous.revision else { throw AlienStorageError.historyChanged }
    try Self.preserve(previous.sources, in: sources, id: \.id)
    try Self.preserve(previous.receipts, in: receipts, id: \.id)
    try Self.preserve(previous.commands, in: commands, id: \.id)
    let physical = try Self.unique(attachments, id: \.id)
    for old in previous.attachments {
      guard let current = physical[old.id], current.owner == old.owner, current.kind == old.kind,
        current.source == old.source, current.contributionBasisPoints >= old.contributionBasisPoints
      else { throw AlienStorageError.historyChanged }
      if case .retired = old.disposition, current != old { throw AlienStorageError.historyChanged }
    }
    let ownedUpgrades = try Self.unique(upgrades, id: \.id)
    for old in previous.upgrades {
      guard let current = ownedUpgrades[old.id], current.owner == old.owner,
        current.kind == old.kind,
        current.source == old.source
      else { throw AlienStorageError.historyChanged }
      switch old.disposition {
      case .stored: break
      case .applied, .retired:
        guard current == old else { throw AlienStorageError.historyChanged }
      }
    }
  }

  private static func unique<T>(_ records: [T], id: KeyPath<T, UUID>) throws -> [UUID: T] {
    var result: [UUID: T] = [:]
    for record in records {
      guard result.updateValue(record, forKey: record[keyPath: id]) == nil else {
        throw AlienStorageError.duplicateKey
      }
    }
    return result
  }
  private static func preserve<T: Equatable>(_ old: [T], in new: [T], id: KeyPath<T, UUID>) throws {
    let records = try unique(new, id: id)
    guard old.allSatisfy({ records[$0[keyPath: id]] == $0 }) else {
      throw AlienStorageError.historyChanged
    }
  }
}

private struct AlienStorageReplay {
  struct Physical {
    var disposition: AlienStorageDisposition
    var bonus: Int
  }
  var attachments: [UUID: Physical] = [:]
  var upgrades: [UUID: AlienStorageUpgradeDisposition] = [:]
  var claimedSources: Set<UUID> = []

  mutating func apply(
    _ command: AlienStorageCommand, receipts: [AlienStorageReceipt],
    sources: [UUID: AlienStorageSource], attachments definitions: [UUID: AlienStorageAttachment],
    upgrades upgradeDefinitions: [UUID: AlienStorageUpgrade]
  ) throws {
    switch command.action {
    case .acquireAttachment(let id, let sourceID),
      .migrateStoredAttachment(let id, let sourceID, _, _):
      guard receipts.isEmpty, attachments[id] == nil, let definition = definitions[id],
        definition.source == sourceID, let source = sources[sourceID],
        source.acquisition == command.id,
        claimedSources.insert(sourceID).inserted,
        try AlienModuleDefinition.kind(for: source.lot) == definition.kind
      else { throw AlienStorageError.invalidJoin }
      attachments[id] = .init(
        disposition: .stored, bonus: AlienModuleDefinition.baseBonusBasisPoints)
    case .acquireUpgrade(let id, let sourceID), .migrateStoredUpgrade(let id, let sourceID, _, _):
      guard receipts.isEmpty, upgrades[id] == nil, let definition = upgradeDefinitions[id],
        definition.source == sourceID, let source = sources[sourceID],
        source.acquisition == command.id,
        claimedSources.insert(sourceID).inserted
      else { throw AlienStorageError.invalidJoin }
      _ = try AlienModuleDefinition.upgradeBonus(for: source.lot, kind: definition.kind)
      upgrades[id] = .stored
    case .applyUpgrade(let id, let upgradeID):
      guard receipts.count == 1, var item = live(id), upgrades[upgradeID] == .stored,
        let definition = definitions[id], let upgrade = upgradeDefinitions[upgradeID],
        upgrade.kind == definition.kind, let source = sources[upgrade.source],
        case .upgrade(let target, let receiptUpgrade, let bonus) = receipts[0].effect,
        target == id, receiptUpgrade == upgradeID,
        try AlienModuleDefinition.upgradeBonus(for: source.lot, kind: definition.kind) == bonus
      else { throw AlienStorageError.invalidJoin }
      let total = item.bonus.addingReportingOverflow(bonus)
      guard !total.overflow else { throw AlienStorageError.arithmeticOverflow }
      item.bonus = total.partialValue
      attachments[id] = item
      upgrades[upgradeID] = .applied(attachment: id, operation: command.id)
    case .relocate(let id, let destination):
      guard receipts.isEmpty, var item = live(id), item.disposition != destination else {
        throw AlienStorageError.invalidJoin
      }
      if case .retired = destination { throw AlienStorageError.invalidJoin }
      item.disposition = destination
      attachments[id] = item
    case .retireAttachment(let id, let reason):
      guard receipts.isEmpty, var item = live(id) else { throw AlienStorageError.invalidJoin }
      item.disposition = .retired(reason)
      attachments[id] = item
    case .retireUpgrade(let id, let reason):
      guard receipts.isEmpty, upgrades[id] == .stored else { throw AlienStorageError.invalidJoin }
      upgrades[id] = .retired(reason)
    case .transferHull(let from, let to, let count):
      guard from != to, count > 0, UInt64(exactly: receipts.count) == count else {
        throw AlienStorageError.invalidJoin
      }
      let expected = Set(
        attachments.compactMap { id, item in
          item.disposition == .fitted(hull: from) ? id : nil
        })
      var moved: Set<UUID> = []
      for receipt in receipts {
        guard case .transfer(let id) = receipt.effect, expected.contains(id),
          moved.insert(id).inserted,
          var item = attachments[id]
        else { throw AlienStorageError.invalidJoin }
        item.disposition = .fitted(hull: to)
        attachments[id] = item
      }
      guard moved == expected else { throw AlienStorageError.invalidJoin }
    }
  }
  private func live(_ id: UUID) -> Physical? {
    guard let item = attachments[id] else { return nil }
    if case .retired = item.disposition { return nil }
    return item
  }
}
