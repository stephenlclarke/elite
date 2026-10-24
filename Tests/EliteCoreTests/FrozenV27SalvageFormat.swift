import Foundation

@testable import EliteCore

// Format oracle frozen from 55d57c4f5d1e3a61562cd13c55355d54051a48ad,
// before nativeWreck/nativeInspection/nativeWork existed. This is authored old-format
// compatibility evidence, not a retained historical production save or bootstrap proof.
// Original plan and legacy-section Codable implementations below are copied verbatim
// except for their type names and frozen progress-field representation. The page encoder deliberately supports only these two
// fixture record cases and one leaf, rejecting new tags and larger fixture trees.
struct FrozenV27WorldProgress: Codable, Sendable, Equatable {
  let issued: [Int]
  let discarded: [Bool]
  let structuralUnits: Int
  let issuedStructural: Int
  let materialKind: CommodityIdentity?
  let nextLot: UInt32

  init(_ value: AlienStorageWorldProgress) {
    issued = value.issued
    discarded = value.discarded
    structuralUnits = value.structuralUnits
    issuedStructural = value.issuedStructural
    materialKind = value.materialKind
    nextLot = value.nextLot
  }
}

struct FrozenV27WorldPlan: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let seed: UInt64
  let plan: SalvageLootPlan
  let inspectedAt: Double
  let requiredWorkSeconds: Double
  let workSeconds: Double
  let damagedTechnology: Bool
  let depleted: Bool
  let destroyed: Bool
  let lastOperation: UInt64?
  let progress: FrozenV27WorldProgress
}
struct FrozenV27LegacySection: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let importOperation: UUID
  let importedAt: Double
  let ledgerRevision: UInt64
  let seed: UInt64
  let plan: SalvageLootPlan
  let progress: FrozenV27WorldProgress
  let savedPartialWorkSeconds: Double?
  let savedDamagedTechnology: Bool
  let sectionDepleted: Bool
  let sectionDestroyed: Bool
  let wreckDestroyed: Bool
  /// This cursor belongs to the entire original ledger, not a dated section event.
  let savedLedgerLastOperation: UInt64?
}

// Sets inside the original source are encoded in a stable order for content hashes.
private struct FrozenV27SourceEvidence: Codable {
  let roles: [SalvageSourceRole]
  let legalValue: Int
  let economy: Int
  let technology: Int
  let ownership: SalvageOwnership
  let stolenProvenance: Bool
  let manifest: [CommodityAmount]?
  let manifestSection: UInt16
  let manifestAlreadySettled: Bool
  init(_ source: SalvageLootSource) {
    roles = source.roles.sorted { $0.rawValue < $1.rawValue }
    legalValue = source.legalValue
    economy = source.economy
    technology = source.technology
    ownership = source.ownership
    stolenProvenance = source.stolenProvenance
    manifest = source.manifest
    manifestSection = source.manifestSection
    manifestAlreadySettled = source.manifestAlreadySettled
  }
  func value() throws -> SalvageLootSource {
    guard Set(roles).count == roles.count else { throw AlienStorageError.duplicateKey }
    var source = SalvageLootSource(
      roles: Set(roles), legalValue: legalValue, economy: economy,
      technology: technology, ownership: ownership)
    source.stolenProvenance = stolenProvenance
    source.manifest = manifest
    source.manifestSection = manifestSection
    source.manifestAlreadySettled = manifestAlreadySettled
    return source
  }
}
private struct FrozenV27PlanEvidence: Codable {
  let section: WreckSectionIdentity
  let source: FrozenV27SourceEvidence
  let profile: SalvageLootProfile?
  let bucket: SalvageLootBucket?
  let items: [SalvageLootItem]
  let emptyReason: SalvageLootEmptyReason?
  init(_ plan: SalvageLootPlan) {
    section = plan.section
    source = .init(plan.source)
    profile = plan.profile
    bucket = plan.bucket
    items = plan.items
    emptyReason = plan.emptyReason
  }
  func value() throws -> SalvageLootPlan {
    .init(
      section: section, source: try source.value(), profile: profile,
      bucket: bucket, items: items, emptyReason: emptyReason)
  }
}
extension FrozenV27WorldPlan {
  private enum CodingKeys: String, CodingKey {
    case id, owner, seed, plan, inspectedAt, requiredWorkSeconds, workSeconds
    case damagedTechnology, depleted, destroyed, lastOperation, progress
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    owner = try values.decode(UUID.self, forKey: .owner)
    seed = try values.decode(UInt64.self, forKey: .seed)
    plan = try values.decode(FrozenV27PlanEvidence.self, forKey: .plan).value()
    inspectedAt = try values.decode(Double.self, forKey: .inspectedAt)
    requiredWorkSeconds = try values.decode(Double.self, forKey: .requiredWorkSeconds)
    workSeconds = try values.decode(Double.self, forKey: .workSeconds)
    damagedTechnology = try values.decode(Bool.self, forKey: .damagedTechnology)
    depleted = try values.decode(Bool.self, forKey: .depleted)
    destroyed = try values.decode(Bool.self, forKey: .destroyed)
    lastOperation = try values.decodeIfPresent(UInt64.self, forKey: .lastOperation)
    progress = try values.decode(FrozenV27WorldProgress.self, forKey: .progress)
  }
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(owner, forKey: .owner)
    try values.encode(seed, forKey: .seed)
    try values.encode(FrozenV27PlanEvidence(plan), forKey: .plan)
    try values.encode(inspectedAt, forKey: .inspectedAt)
    try values.encode(requiredWorkSeconds, forKey: .requiredWorkSeconds)
    try values.encode(workSeconds, forKey: .workSeconds)
    try values.encode(damagedTechnology, forKey: .damagedTechnology)
    try values.encode(depleted, forKey: .depleted)
    try values.encode(destroyed, forKey: .destroyed)
    try values.encodeIfPresent(lastOperation, forKey: .lastOperation)
    try values.encode(progress, forKey: .progress)
  }
}

extension FrozenV27LegacySection {
  private enum CodingKeys: String, CodingKey {
    case id, owner, importOperation, importedAt, ledgerRevision, seed, plan, progress
    case savedPartialWorkSeconds, savedDamagedTechnology, sectionDepleted, sectionDestroyed
    case wreckDestroyed, savedLedgerLastOperation
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try values.decode(UUID.self, forKey: .id),
      owner: try values.decode(UUID.self, forKey: .owner),
      importOperation: try values.decode(UUID.self, forKey: .importOperation),
      importedAt: try values.decode(Double.self, forKey: .importedAt),
      ledgerRevision: try values.decode(UInt64.self, forKey: .ledgerRevision),
      seed: try values.decode(UInt64.self, forKey: .seed),
      plan: try values.decode(FrozenV27PlanEvidence.self, forKey: .plan).value(),
      progress: try values.decode(FrozenV27WorldProgress.self, forKey: .progress),
      savedPartialWorkSeconds: try values.decodeIfPresent(
        Double.self, forKey: .savedPartialWorkSeconds),
      savedDamagedTechnology: try values.decode(Bool.self, forKey: .savedDamagedTechnology),
      sectionDepleted: try values.decode(Bool.self, forKey: .sectionDepleted),
      sectionDestroyed: try values.decode(Bool.self, forKey: .sectionDestroyed),
      wreckDestroyed: try values.decode(Bool.self, forKey: .wreckDestroyed),
      savedLedgerLastOperation: try values.decodeIfPresent(
        UInt64.self, forKey: .savedLedgerLastOperation))
  }
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(owner, forKey: .owner)
    try values.encode(importOperation, forKey: .importOperation)
    try values.encode(importedAt, forKey: .importedAt)
    try values.encode(ledgerRevision, forKey: .ledgerRevision)
    try values.encode(seed, forKey: .seed)
    try values.encode(FrozenV27PlanEvidence(plan), forKey: .plan)
    try values.encode(progress, forKey: .progress)
    try values.encodeIfPresent(savedPartialWorkSeconds, forKey: .savedPartialWorkSeconds)
    try values.encode(savedDamagedTechnology, forKey: .savedDamagedTechnology)
    try values.encode(sectionDepleted, forKey: .sectionDepleted)
    try values.encode(sectionDestroyed, forKey: .sectionDestroyed)
    try values.encode(wreckDestroyed, forKey: .wreckDestroyed)
    try values.encodeIfPresent(savedLedgerLastOperation, forKey: .savedLedgerLastOperation)
  }
}

private enum FrozenV27World: Encodable {
  case plan(FrozenV27WorldPlan)
  case legacySection(FrozenV27LegacySection)

  init(_ value: AlienStorageWorldRecord) throws {
    switch value {
    case .plan(let p):
      self = .plan(
        .init(
          id: p.id, owner: p.owner, seed: p.seed, plan: p.plan, inspectedAt: p.inspectedAt,
          requiredWorkSeconds: p.requiredWorkSeconds, workSeconds: p.workSeconds,
          damagedTechnology: p.damagedTechnology, depleted: p.depleted, destroyed: p.destroyed,
          lastOperation: p.lastOperation, progress: .init(p.progress)))
    case .legacySection(let p):
      self = .legacySection(
        .init(
          id: p.id, owner: p.owner, importOperation: p.importOperation, importedAt: p.importedAt,
          ledgerRevision: p.ledgerRevision, seed: p.seed, plan: p.plan, progress: .init(p.progress),
          savedPartialWorkSeconds: p.savedPartialWorkSeconds,
          savedDamagedTechnology: p.savedDamagedTechnology, sectionDepleted: p.sectionDepleted,
          sectionDestroyed: p.sectionDestroyed, wreckDestroyed: p.wreckDestroyed,
          savedLedgerLastOperation: p.savedLedgerLastOperation))
    default: throw AlienStorageError.invalidPage
    }
  }
}
private enum FrozenV27Payload: Encodable {
  case world(FrozenV27World)
}
private struct FrozenV27Entry: Encodable {
  let key: String
  let payload: FrozenV27Payload
}
private struct FrozenV27Tree: Encodable {
  let hash: String?
  let count: UInt64
  let height: UInt64
  let firstKey: String?
  let lastKey: String?
  static let empty = Self(hash: nil, count: 0, height: 0, firstKey: nil, lastKey: nil)
}
private struct FrozenV27IndexRoot: Encodable {
  let index: String
  let tree: FrozenV27Tree
}
private struct FrozenV27Root: Encodable {
  let version: Int
  let owner: UUID
  let revision: UInt64
  let worldRevision: UInt64
  let indices: [FrozenV27IndexRoot]
}
private struct FrozenV27Page: Encodable {
  let version: Int
  let owner: UUID
  let index: String
  let height: UInt64
  let entries: [FrozenV27Entry]
  let children: [FrozenV27Tree]
}

enum FrozenV27SalvageFormat {
  static func encode(_ snapshot: AlienStorageSnapshot) throws -> (Data, [String: Data]) {
    guard snapshot.world.count <= 128, snapshot.sources.isEmpty, snapshot.attachments.isEmpty,
      snapshot.upgrades.isEmpty, snapshot.receipts.isEmpty, snapshot.commands.isEmpty
    else { throw AlienStorageError.invalidPage }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let entries = try snapshot.world.sorted { $0.id.uuidString < $1.id.uuidString }.map {
      FrozenV27Entry(key: $0.id.uuidString, payload: .world(try .init($0)))
    }
    var pages: [String: Data] = [:]
    var roots: [FrozenV27IndexRoot] = []
    for index in ["sources", "attachments", "upgrades", "receipts", "commands", "world"] {
      var tree = FrozenV27Tree.empty
      if index == "world", !entries.isEmpty {
        let bytes = try encoder.encode(
          FrozenV27Page(
            version: 1, owner: snapshot.owner, index: index, height: 0, entries: entries,
            children: []))
        guard bytes.count <= 262144 else { throw AlienStorageError.oversizedRecord }
        let hash = ScriptPackLibrary.hash(bytes)
        pages[hash] = bytes
        tree = .init(
          hash: hash, count: UInt64(entries.count), height: 0,
          firstKey: entries.first?.key, lastKey: entries.last?.key)
      }
      roots.append(.init(index: index, tree: tree))
    }
    let root = try encoder.encode(
      FrozenV27Root(
        version: 1, owner: snapshot.owner, revision: snapshot.revision,
        worldRevision: snapshot.worldRevision, indices: roots))
    return (root, pages)
  }
}

struct FrozenV27SavePointer: Encodable {
  let format = "elite-script-save"
  let schemaVersion = 27
  let generation: String
  let hashes: [String: String]
  let scope: String? = "commander"
  let valueCodec: String? = "tagged-script-values-v1"
}
