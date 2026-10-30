import Foundation

@testable import L337Core

/// Storage-only history fixtures. Typed source evidence comes from the producer;
/// these values never claim a native scoop, private collector permit or PLUGH dock.
struct AlienStorageTestFixture {
  static let owner = uuid(1)
  static let hull = uuid(2)
  static func uuid(_ value: UInt64) -> UUID {
    let bytes = (0..<8).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    return UUID(
      uuid: (
        0, 0, 0, 0, 0, 0, 0, 0, bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2],
        bytes[1], bytes[0]
      ))
  }
  var next: UInt64 = 10
  var world: [AlienStorageWorldRecord] = []
  var sources: [AlienStorageSource] = []
  var attachments: [AlienStorageAttachment] = []
  var upgrades: [AlienStorageUpgrade] = []
  var receipts: [AlienStorageReceipt] = []
  var commands: [AlienStorageCommand] = []
  var worldRevision: UInt64 = 0
  mutating func identifier() -> UUID {
    defer { next += 1 }
    return Self.uuid(next)
  }
  var snapshot: AlienStorageSnapshot {
    .init(
      owner: Self.owner, revision: UInt64(commands.count), worldRevision: worldRevision,
      world: world, sources: sources, attachments: attachments, upgrades: upgrades,
      receipts: receipts, commands: commands)
  }
  static func plan(site: UInt32, definition: String) throws -> (UInt64, SalvageLootPlan, SalvageLot)
  {
    let section = WreckSectionIdentity(
      wreck: .init(system: .init(galaxy: 0, system: 7), site: site, lineage: 123), section: 1)
    let source = SalvageLootSource(
      roles: [.thargoid, .militaryCapital], legalValue: 0, economy: 3,
      technology: 12, ownership: .abandoned)
    for seed in UInt64(0)..<2000 {
      let plan = SalvageLootProfiles.plan(section: section, seed: seed, source: source)
      guard let item = plan.items.first,
        case .technology(let id, let quality, let condition, _) = item.content, id == definition
      else { continue }
      return (
        seed, plan,
        .init(
          identity: item.identity,
          content: .technology(definitionID: id, quality: quality, conditionPercent: condition),
          position: .init(10, 20, 30), velocity: .init(0, 0, 0),
          halfExtents: item.halfExtents, massKg: item.massKg, loot: item)
      )
    }
    throw AlienStorageError.invalidSnapshot
  }
  mutating func acquire(kind: AlienModuleKind, upgrade: Bool = false) throws -> UUID {
    guard let site = UInt32(exactly: sources.count + 1) else {
      throw AlienStorageError.arithmeticOverflow
    }
    let (seed, plan, lot) = try Self.plan(
      site: site, definition: upgrade ? kind.upgradeDefinitionID : kind.definitionID)
    let acquisition = identifier()
    let owned = identifier()
    let planID = identifier()
    let worldLot = identifier()
    sources.append(.init(id: acquisition, owner: Self.owner, lot: lot, acquisition: acquisition))
    world.append(
      .plan(
        .init(
          id: planID, owner: Self.owner, seed: seed, plan: plan, inspectedAt: 0,
          requiredWorkSeconds: 1, workSeconds: 1, damagedTechnology: false, depleted: true,
          destroyed: false, lastOperation: 1,
          progress: .init(
            issued: [1], discarded: [false], structuralUnits: 0, issuedStructural: 0,
            materialKind: .alloys, nextLot: 1))))
    world.append(
      .lot(
        .init(
          id: worldLot, owner: Self.owner, plan: planID, itemIndex: 0, issuedAt: 1,
          state: .acquired(source: acquisition, at: 2))))
    worldRevision += 1
    if upgrade {
      upgrades.append(
        .init(id: owned, owner: Self.owner, kind: kind, source: acquisition, disposition: .stored))
      commands.append(
        .init(
          id: acquisition, owner: Self.owner, revision: UInt64(commands.count + 1),
          action: .acquireUpgrade(upgrade: owned, source: acquisition)))
    } else {
      attachments.append(
        .init(
          id: owned, owner: Self.owner, kind: kind, source: acquisition, disposition: .stored,
          contributionBasisPoints: kind.initialContribution))
      commands.append(
        .init(
          id: acquisition, owner: Self.owner, revision: UInt64(commands.count + 1),
          action: .acquireAttachment(attachment: owned, source: acquisition)))
    }
    return owned
  }
  mutating func fit(_ id: UUID, hull: UUID = Self.hull) throws {
    guard let index = attachments.firstIndex(where: { $0.id == id }) else {
      throw AlienStorageError.invalidJoin
    }
    let old = attachments[index]
    let operation = identifier()
    attachments[index] = .init(
      id: old.id, owner: old.owner, kind: old.kind, source: old.source,
      disposition: .fitted(hull: hull), contributionBasisPoints: old.contributionBasisPoints)
    commands.append(
      .init(
        id: operation, owner: Self.owner, revision: UInt64(commands.count + 1),
        action: .relocate(attachment: id, to: .fitted(hull: hull))))
  }
  mutating func apply(_ upgradeID: UUID, to id: UUID) throws {
    guard let item = attachments.firstIndex(where: { $0.id == id }),
      let upgrade =
        (upgrades.last?.id == upgradeID
          ? upgrades.indices.last : upgrades.firstIndex(where: { $0.id == upgradeID })),
      let source =
        (sources.last?.id == upgrades[upgrade].source
          ? sources.last : sources.first(where: { $0.id == upgrades[upgrade].source }))
    else { throw AlienStorageError.invalidJoin }
    let old = attachments[item]
    let owned = upgrades[upgrade]
    let bonus = try AlienModuleDefinition.upgradeBonus(for: source.lot, kind: old.kind)
    let operation = identifier()
    let receipt = identifier()
    attachments[item] = .init(
      id: id, owner: old.owner, kind: old.kind, source: old.source,
      disposition: old.disposition, contributionBasisPoints: old.contributionBasisPoints + bonus)
    upgrades[upgrade] = .init(
      id: owned.id, owner: owned.owner, kind: owned.kind, source: owned.source,
      disposition: .applied(attachment: id, operation: operation))
    commands.append(
      .init(
        id: operation, owner: Self.owner, revision: UInt64(commands.count + 1),
        action: .applyUpgrade(attachment: id, upgrade: upgradeID)))
    receipts.append(
      .init(
        id: receipt, owner: Self.owner, operation: operation,
        effect: .upgrade(attachment: id, upgrade: upgradeID, basisPoints: bonus)))
  }
  mutating func retire(_ id: UUID) throws {
    guard let index = attachments.firstIndex(where: { $0.id == id }) else {
      throw AlienStorageError.invalidJoin
    }
    let old = attachments[index]
    let operation = identifier()
    attachments[index] = .init(
      id: old.id, owner: old.owner, kind: old.kind, source: old.source,
      disposition: .retired(.sold), contributionBasisPoints: old.contributionBasisPoints)
    commands.append(
      .init(
        id: operation, owner: Self.owner, revision: UInt64(commands.count + 1),
        action: .retireAttachment(attachment: id, reason: .sold)))
  }
  mutating func transfer(to hull: UUID) {
    let moved = attachments.filter { $0.disposition == .fitted(hull: Self.hull) }
    let operation = identifier()
    commands.append(
      .init(
        id: operation, owner: Self.owner, revision: UInt64(commands.count + 1),
        action: .transferHull(from: Self.hull, to: hull, members: UInt64(moved.count))))
    let ids = Set(moved.map(\.id))
    for index in attachments.indices where ids.contains(attachments[index].id) {
      let old = attachments[index]
      attachments[index] = .init(
        id: old.id, owner: old.owner, kind: old.kind, source: old.source,
        disposition: .fitted(hull: hull), contributionBasisPoints: old.contributionBasisPoints)
      let receipt = identifier()
      receipts.append(
        .init(
          id: receipt, owner: Self.owner, operation: operation,
          effect: .transfer(attachment: old.id)))
    }
  }
}

struct AlienStorageMemoryPages: AlienStoragePageWriter, AlienStoragePageReader {
  var pages: [String: Data] = [:]
  var failAtWrite: Int?
  var writes = 0
  mutating func writePage(hash: String, data: Data) throws {
    writes += 1
    if failAtWrite == writes { throw CocoaError(.fileWriteOutOfSpace) }
    if let old = pages[hash], old != data { throw AlienStorageError.hashMismatch }
    pages[hash] = data
  }
  func readPage(hash: String) throws -> Data {
    guard let value = pages[hash] else { throw CocoaError(.fileNoSuchFile) }
    return value
  }
}
