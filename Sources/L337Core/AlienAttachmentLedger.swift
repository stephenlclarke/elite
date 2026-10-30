import Foundation

struct AlienAttachmentAddress: Hashable, Codable, Sendable {
  let hull: UUID
  let attachment: UUID
}

enum AlienAttachmentRetirement: String, Codable, Sendable { case sold, lost }
enum AlienAttachmentDisposition: Equatable, Codable, Sendable {
  case stored
  case fitted(AlienAttachmentAddress)
  case retired(AlienAttachmentRetirement)
}
struct AlienAttachmentUpgrade: Equatable, Codable, Sendable {
  let operation: UUID
  let source: SalvageLot
  let appliedBasisPoints: Int
}
struct AlienAttachment: Equatable, Codable, Sendable {
  let id: UUID
  let owner: UUID
  let kind: AlienModuleKind
  let source: SalvageLot
  fileprivate(set) var disposition: AlienAttachmentDisposition
  fileprivate(set) var contributionBasisPoints: Int
  fileprivate(set) var upgrades: [AlienAttachmentUpgrade]
}

private enum AlienAttachmentCommand: Equatable, Codable, Sendable {
  case acquire(item: UUID, source: SalvageLotIdentity)
  case upgrade(item: UUID, source: SalvageLotIdentity)
  case move(item: UUID)
  case transfer(items: [UUID])
  case retire(item: UUID)
}

/// Scalable physical attachments and permanent source history, separate from ordinary inventory.
/// No bay, pool or per-hull count cap. Retired records and command/source claims are never evicted.
struct AlienAttachmentLedger: Equatable, Codable, Sendable {
  static let schemaVersion = 1
  let owner: UUID
  private(set) var revision: UInt64 = 0
  private var records: [UUID: AlienAttachment] = [:]
  private var commands: [UUID: AlienAttachmentCommand] = [:]
  // Derived cache; each complete source is persisted once in its item or upgrade receipt.
  private var sources: Set<SalvageLotIdentity> = []

  init(owner: UUID) { self.owner = owner }
  var items: [AlienAttachment] { records.values.sorted { $0.id.uuidString < $1.id.uuidString } }
  func item(_ id: UUID) -> AlienAttachment? { records[id] }
  func sourceWasClaimed(_ source: SalvageLotIdentity) -> Bool { sources.contains(source) }
  func fitted(to hull: UUID) -> [AlienAttachment] {
    records.values.filter {
      if case .fitted(let address) = $0.disposition { address.hull == hull } else { false }
    }
  }

  /// Caller must atomically consume the actual source lot and publish this candidate or neither.
  @discardableResult mutating func admitRecovered(
    lot: SalvageLot, command: UUID, owner: UUID, expectedRevision: UInt64
  ) throws -> UUID {
    let next = try nextRevision(command: command, owner: owner, expected: expectedRevision)
    guard records[command] == nil else { throw AlienAttachmentError.duplicateItem }
    guard !sources.contains(lot.identity) else { throw AlienAttachmentError.replayedSource }
    let kind = try AlienModuleDefinition.kind(for: lot)
    let item = AlienAttachment(
      id: command, owner: owner, kind: kind, source: lot, disposition: .stored,
      contributionBasisPoints: kind.initialContribution, upgrades: [])
    records[command] = item
    sources.insert(lot.identity)
    commit(command: command, action: .acquire(item: command, source: lot.identity), revision: next)
    return command
  }

  /// Pure relocation. Actual hull ownership and current PLUGH dock proof belong to the actor.
  mutating func relocate(
    item id: UUID, toHull hull: UUID?, command: UUID, owner: UUID, expectedRevision: UInt64
  ) throws {
    let next = try nextRevision(command: command, owner: owner, expected: expectedRevision)
    var item = try liveItem(id)
    let destination: AlienAttachmentDisposition =
      hull.map { .fitted(.init(hull: $0, attachment: id)) } ?? .stored
    guard item.disposition != destination else { throw AlienAttachmentError.noChange }
    item.disposition = destination
    records[id] = item
    commit(command: command, action: .move(item: id), revision: next)
  }

  /// Hull exchange retains physical UUIDs, contributions and all permanent source evidence.
  mutating func transferHull(
    from: UUID, to: UUID, command: UUID, owner: UUID, expectedRevision: UInt64
  ) throws {
    let next = try nextRevision(command: command, owner: owner, expected: expectedRevision)
    guard from != to else { throw AlienAttachmentError.noChange }
    let moved = fitted(to: from)
    guard !moved.isEmpty else { throw AlienAttachmentError.noChange }
    for var item in moved {
      item.disposition = .fitted(.init(hull: to, attachment: item.id))
      records[item.id] = item
    }
    commit(command: command, action: .transfer(items: moved.map(\.id)), revision: next)
  }

  /// A permanent physical upgrade, independent of normal module grade and terminal caps.
  mutating func upgrade(
    item id: UUID, lot: SalvageLot, command: UUID, owner: UUID, expectedRevision: UInt64
  ) throws {
    let next = try nextRevision(command: command, owner: owner, expected: expectedRevision)
    var item = try liveItem(id)
    guard !sources.contains(lot.identity) else { throw AlienAttachmentError.replayedSource }
    let bonus = try AlienModuleDefinition.upgradeBonus(for: lot, kind: item.kind)
    let total = item.contributionBasisPoints.addingReportingOverflow(bonus)
    guard !total.overflow else { throw AlienAttachmentError.arithmeticOverflow }
    item.contributionBasisPoints = total.partialValue
    item.upgrades.append(.init(operation: command, source: lot, appliedBasisPoints: bonus))
    records[id] = item
    sources.insert(lot.identity)
    commit(command: command, action: .upgrade(item: id, source: lot.identity), revision: next)
  }

  /// Removal does not permit source replay or reset an upgraded physical item.
  mutating func retire(
    item id: UUID, reason: AlienAttachmentRetirement, command: UUID, owner: UUID,
    expectedRevision: UInt64
  ) throws {
    let next = try nextRevision(command: command, owner: owner, expected: expectedRevision)
    var item = try liveItem(id)
    item.disposition = .retired(reason)
    records[id] = item
    commit(command: command, action: .retire(item: id), revision: next)
  }

  private func liveItem(_ id: UUID) throws -> AlienAttachment {
    guard let item = records[id] else { throw AlienAttachmentError.unavailable }
    if case .retired = item.disposition { throw AlienAttachmentError.retiredItem }
    return item
  }
  private func nextRevision(command: UUID, owner: UUID, expected: UInt64) throws -> UInt64 {
    guard owner == self.owner else { throw AlienAttachmentError.wrongOwner }
    guard expected == revision else { throw AlienAttachmentError.staleRevision }
    guard commands[command] == nil else { throw AlienAttachmentError.replayedCommand }
    let next = revision.addingReportingOverflow(1)
    guard !next.overflow else { throw AlienAttachmentError.arithmeticOverflow }
    return next.partialValue
  }
  private mutating func commit(command: UUID, action: AlienAttachmentCommand, revision: UInt64) {
    commands[command] = action
    self.revision = revision
  }

  private enum CodingKeys: String, CodingKey { case version, owner, revision, records, commands }
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(Self.schemaVersion, forKey: .version)
    try values.encode(owner, forKey: .owner)
    try values.encode(revision, forKey: .revision)
    var entries = values.nestedUnkeyedContainer(forKey: .records)
    for item in items {
      try entries.encode(item.id)
      try entries.encode(item)
    }
    var savedCommands = values.nestedUnkeyedContainer(forKey: .commands)
    for key in commands.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      try savedCommands.encode(key)
      try savedCommands.encode(commands[key]!)
    }
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard try values.decode(Int.self, forKey: .version) == Self.schemaVersion else {
      throw AlienAttachmentError.invalidState
    }
    owner = try values.decode(UUID.self, forKey: .owner)
    revision = try values.decode(UInt64.self, forKey: .revision)
    var savedCommands = try values.nestedUnkeyedContainer(forKey: .commands)
    while !savedCommands.isAtEnd {
      let key = try savedCommands.decode(UUID.self)
      guard commands[key] == nil else { throw AlienAttachmentError.invalidState }
      commands[key] = try savedCommands.decode(AlienAttachmentCommand.self)
    }
    guard UInt64(commands.count) == revision else { throw AlienAttachmentError.invalidState }
    var entries = try values.nestedUnkeyedContainer(forKey: .records)
    var receiptOperations: Set<UUID> = []
    while !entries.isAtEnd {
      let id = try entries.decode(UUID.self)
      // Refuse a duplicate physical key before touching its potentially malformed payload.
      guard records[id] == nil, commands[id] != nil, receiptOperations.insert(id).inserted else {
        throw AlienAttachmentError.invalidState
      }
      let item = try entries.decode(AlienAttachment.self)
      guard item.id == id, item.owner == owner,
        commands[id] == .acquire(item: id, source: item.source.identity),
        try AlienModuleDefinition.kind(for: item.source) == item.kind,
        sources.insert(item.source.identity).inserted
      else { throw AlienAttachmentError.invalidState }
      if case .fitted(let address) = item.disposition, address.attachment != id {
        throw AlienAttachmentError.invalidState
      }
      var contribution = item.kind.initialContribution
      for upgrade in item.upgrades {
        guard commands[upgrade.operation] == .upgrade(item: id, source: upgrade.source.identity),
          receiptOperations.insert(upgrade.operation).inserted,
          sources.insert(upgrade.source.identity).inserted,
          try AlienModuleDefinition.upgradeBonus(for: upgrade.source, kind: item.kind)
            == upgrade.appliedBasisPoints
        else { throw AlienAttachmentError.invalidState }
        let sum = contribution.addingReportingOverflow(upgrade.appliedBasisPoints)
        guard !sum.overflow else { throw AlienAttachmentError.arithmeticOverflow }
        contribution = sum.partialValue
      }
      guard contribution == item.contributionBasisPoints else {
        throw AlienAttachmentError.invalidState
      }
      records[id] = item
    }
    // A saved command cannot outlive its physical item/source proof, even after retirement.
    for (operation, action) in commands {
      switch action {
      case .acquire(let id, let source):
        guard operation == id, records[id]?.source.identity == source else {
          throw AlienAttachmentError.invalidState
        }
      case .upgrade:
        // The receipt loop already matched this exact command's item and source.
        // Reuse its unique operation index instead of rescanning a growing upgrade array.
        guard receiptOperations.contains(operation) else { throw AlienAttachmentError.invalidState }
      case .move(let id):
        guard records[id] != nil else { throw AlienAttachmentError.invalidState }
      case .retire(let id):
        guard let item = records[id], case .retired = item.disposition else {
          throw AlienAttachmentError.invalidState
        }
      case .transfer(let items):
        guard !items.isEmpty, Set(items).count == items.count,
          items.allSatisfy({ records[$0] != nil })
        else {
          throw AlienAttachmentError.invalidState
        }
      }
    }
  }
}
