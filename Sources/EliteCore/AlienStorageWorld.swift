import Foundation

/// Original inspection, including EMPTY outcomes, is permanent and never rerolled.
struct AlienStorageWorldPlan: Codable, Sendable, Equatable {
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
  let progress: AlienStorageWorldProgress
}
struct AlienStorageWorldLot: Codable, Sendable, Equatable {
  enum State: Codable, Sendable, Equatable {
    case unissued
    case pending(
      lot: SalvageLot, physicalTime: Double, offer: SpawnIdentity?, binding: ActorIdentity?)
    case acquired(source: UUID, at: Double)
    case discarded(at: Double)
    case destroyed(at: Double)
  }
  let id: UUID
  let owner: UUID
  let plan: UUID
  let itemIndex: UInt16
  let issuedAt: Double?
  let state: State
}
enum AlienStorageWorldRecord: Codable, Sendable, Equatable {
  case plan(AlienStorageWorldPlan)
  case lot(AlienStorageWorldLot)
  case companion(AlienStorageCompanion)
  var id: UUID {
    switch self {
    case .plan(let value): value.id
    case .lot(let value): value.id
    case .companion(let value): value.id
    }
  }
  var owner: UUID {
    switch self {
    case .plan(let value): value.owner
    case .lot(let value): value.owner
    case .companion(let value): value.owner
    }
  }
}

enum AlienStorageWorldValidation {
  static func validate(
    _ records: [AlienStorageWorldRecord], owner: UUID,
    sources: [AlienStorageSource]
  ) throws {
    var plans: [UUID: AlienStorageWorldPlan] = [:]
    var lots: [UUID: AlienStorageWorldLot] = [:]
    var companions: [AlienStorageCompanion] = []
    var ids: Set<UUID> = []
    var sections: Set<WreckSectionIdentity> = []
    for record in records {
      guard record.owner == owner else { throw AlienStorageError.wrongOwner }
      guard ids.insert(record.id).inserted else { throw AlienStorageError.duplicateKey }
      switch record {
      case .plan(let value):
        let identity = value.plan.section
        let source = value.plan.source
        guard (0..<8).contains(identity.wreck.system.galaxy),
          (0...256).contains(identity.wreck.system.system),
          identity.section < 64, sections.insert(identity).inserted,
          (0...255).contains(source.legalValue), (0...7).contains(source.economy),
          (0...14).contains(source.technology), source.manifestSection < 64,
          (source.manifest?.count ?? 0) <= CommodityIdentity.allCases.count,
          value.inspectedAt.isFinite, value.inspectedAt >= 0,
          value.requiredWorkSeconds.isFinite, value.requiredWorkSeconds > 0,
          value.workSeconds.isFinite, value.workSeconds >= 0,
          value.workSeconds <= value.requiredWorkSeconds,
          value.lastOperation.map({ $0 > 0 }) ?? (value.workSeconds == 0),
          SalvageLootProfiles.plan(section: identity, seed: value.seed, source: source)
            == value.plan
        else { throw AlienStorageError.invalidJoin }
        try value.progress.validate(plan: value)
        plans[value.id] = value
      case .lot(let value): lots[value.id] = value
      case .companion(let value): companions.append(value)
      }
    }
    var sourceMap: [UUID: AlienStorageSource] = [:]
    for source in sources {
      guard sourceMap.updateValue(source, forKey: source.id) == nil else {
        throw AlienStorageError.duplicateKey
      }
    }
    var emissions: [UUID: [AlienStorageEmissionOrigin: SalvageLootItem]] = [:]
    var expectedEmissions: Set<SalvageLotIdentity> = []
    for plan in plans.values {
      let issued = try plan.progress.emissions(plan: plan)
      emissions[plan.id] = issued
      expectedEmissions.formUnion(issued.values.map(\.identity))
    }
    var emissionClaims: Set<SalvageLotIdentity> = []
    var claimed: Set<UUID> = []
    var offers: Set<SpawnIdentity> = []
    var actors: Set<ActorIdentity> = []
    var itemClaims: Set<SalvageLotIdentity> = []
    for lot in lots.values {
      guard let plan = plans[lot.plan], Int(lot.itemIndex) < plan.plan.items.count else {
        throw AlienStorageError.invalidJoin
      }
      let item = plan.plan.items[Int(lot.itemIndex)]
      guard case .technology(let id, _, _, _) = item.content,
        AlienModuleDefinition.isAttachmentDefinition(id), itemClaims.insert(item.identity).inserted
      else { throw AlienStorageError.invalidJoin }
      try AlienModuleDefinition.validatePlanned(item)
      if let issued = lot.issuedAt {
        guard issued.isFinite, issued >= plan.inspectedAt,
          plan.workSeconds == plan.requiredWorkSeconds
        else {
          throw AlienStorageError.invalidJoin
        }
      }
      let issuedCount = plan.progress.issued[Int(lot.itemIndex)]
      let discarded = plan.progress.discarded[Int(lot.itemIndex)]
      if lot.issuedAt != nil {
        let identity = try plan.progress.issuedIdentity(
          itemIndex: Int(lot.itemIndex), plan: plan.plan)
        guard issuedCount == 1, !discarded,
          emissions[plan.id]?[.planned(itemIndex: lot.itemIndex, chunkOrdinal: 0)]?.identity
            == identity,
          emissionClaims.insert(identity).inserted
        else { throw AlienStorageError.invalidJoin }
      }
      switch lot.state {
      case .unissued:
        guard lot.issuedAt == nil, issuedCount == 0, !discarded, !plan.depleted, !plan.destroyed
        else {
          throw AlienStorageError.invalidJoin
        }
      case .pending(let evidence, let time, let offer, let binding):
        guard let issued = lot.issuedAt, time.isFinite, time >= issued, !plan.destroyed,
          offer == nil || binding == nil
        else { throw AlienStorageError.invalidJoin }
        try validate(
          evidence, planned: item,
          identity: plan.progress.issuedIdentity(itemIndex: Int(lot.itemIndex), plan: plan.plan))
        if let offer {
          guard offer.system == item.identity.section.wreck.system, offer.producer == .salvage,
            offer.visit > 0, offer.visit < UInt64.max, offer.sequence > 0,
            offer.sequence < UInt64.max,
            offer.member == 0, offers.insert(offer).inserted
          else { throw AlienStorageError.invalidJoin }
        }
        if let binding {
          guard binding.system == item.identity.section.wreck.system, binding.visit > 0,
            binding.entity >= 2, binding.entity < UInt64.max, binding.visit < UInt64.max,
            actors.insert(binding).inserted
          else { throw AlienStorageError.invalidJoin }
        }
      case .acquired(let sourceID, let time):
        guard let issued = lot.issuedAt, time.isFinite, time >= issued,
          let source = sourceMap[sourceID], claimed.insert(sourceID).inserted
        else {
          throw AlienStorageError.invalidJoin
        }
        try validate(
          source.lot, planned: item,
          identity: plan.progress.issuedIdentity(itemIndex: Int(lot.itemIndex), plan: plan.plan))
      case .discarded(let time):
        guard time.isFinite, time >= (lot.issuedAt ?? plan.inspectedAt),
          lot.issuedAt != nil || discarded || plan.destroyed
        else {
          throw AlienStorageError.invalidJoin
        }
      case .destroyed(let time):
        guard let issued = lot.issuedAt, time.isFinite, time >= issued else {
          throw AlienStorageError.invalidJoin
        }
      }
    }
    var collectionOperations = Set(sourceMap.keys)
    var technologyStorage: Set<UUID> = []
    for companion in companions {
      guard let plan = plans[companion.plan], let issued = emissions[plan.id] else {
        throw AlienStorageError.invalidJoin
      }
      try AlienStorageCompanionValidation.validate(
        companion, plan: plan, emissions: issued, claims: &emissionClaims,
        offers: &offers, actors: &actors, operations: &collectionOperations,
        technologyStorage: &technologyStorage)
    }
    guard emissionClaims == expectedEmissions else { throw AlienStorageError.invalidJoin }
    // Every reserved result has explicit monotone custody, even before it is issued.
    let expected = Set(
      plans.values.flatMap { value in
        value.plan.items.compactMap { item -> SalvageLotIdentity? in
          if case .technology(let id, _, _, _) = item.content,
            AlienModuleDefinition.isAttachmentDefinition(id)
          {
            return item.identity
          }
          return nil
        }
      })
    guard itemClaims == expected, claimed == Set(sourceMap.keys) else {
      throw AlienStorageError.invalidJoin
    }
  }

  private static func validate(
    _ lot: SalvageLot, planned: SalvageLootItem, identity: SalvageLotIdentity
  ) throws {
    let issued = SalvageLootItem(
      identity: identity, content: planned.content, effect: planned.effect,
      bonusBasisPoints: planned.bonusBasisPoints, massKg: planned.massKg,
      halfExtents: planned.halfExtents,
      provenance: planned.provenance, saleValueTenths: planned.saleValueTenths,
      legality: planned.legality, requiresChunking: false)
    try SalvageLotEmission.validate(lot, item: issued)
    if case .technology(let id, _, _, _) = planned.content,
      let kind = AlienModuleKind.allCases.first(where: { $0.definitionID == id })
    {
      _ = try AlienModuleDefinition.kind(for: lot)
      guard kind.definitionID == id else { throw AlienStorageError.invalidJoin }
    } else if case .technology(let id, _, _, _) = planned.content,
      let kind = AlienModuleKind.allCases.first(where: { $0.upgradeDefinitionID == id })
    {
      _ = try AlienModuleDefinition.upgradeBonus(for: lot, kind: kind)
    } else {
      throw AlienStorageError.invalidJoin
    }
  }

  static func preserve(_ previous: [AlienStorageWorldRecord], in current: [AlienStorageWorldRecord])
    throws
  {
    var records: [UUID: AlienStorageWorldRecord] = [:]
    for record in current {
      guard records.updateValue(record, forKey: record.id) == nil else {
        throw AlienStorageError.duplicateKey
      }
    }
    for old in previous {
      guard let next = records[old.id] else { throw AlienStorageError.historyChanged }
      switch (old, next) {
      case (.plan(let a), .plan(let b)):
        guard a.owner == b.owner, a.seed == b.seed, a.plan == b.plan,
          a.inspectedAt == b.inspectedAt,
          a.requiredWorkSeconds == b.requiredWorkSeconds, b.workSeconds >= a.workSeconds,
          !a.damagedTechnology || b.damagedTechnology, !a.depleted || b.depleted,
          !a.destroyed || b.destroyed,
          a.lastOperation.map({ prior in b.lastOperation.map { $0 >= prior } ?? false }) ?? true
        else { throw AlienStorageError.historyChanged }
        try b.progress.preserve(a.progress)
      case (.lot(let a), .lot(let b)):
        guard a.owner == b.owner, a.plan == b.plan, a.itemIndex == b.itemIndex,
          a.issuedAt == nil || a.issuedAt == b.issuedAt
        else { throw AlienStorageError.historyChanged }
        switch (a.state, b.state) {
        case (.unissued, _): break
        case (.pending(let oldLot, let time, _, _), .pending(let newLot, let newTime, _, _)):
          guard oldLot.loot == newLot.loot, newTime >= time else {
            throw AlienStorageError.historyChanged
          }
        case (.pending(_, let time, _, _), .acquired(_, let at)),
          (.pending(_, let time, _, _), .discarded(let at)),
          (.pending(_, let time, _, _), .destroyed(let at)):
          guard at >= time else { throw AlienStorageError.historyChanged }
        case (.acquired, .acquired), (.discarded, .discarded), (.destroyed, .destroyed):
          guard a == b else { throw AlienStorageError.historyChanged }
        default: throw AlienStorageError.historyChanged
        }
      case (.companion(let a), .companion(let b)):
        try AlienStorageCompanionValidation.preserve(a, in: b)
      default: throw AlienStorageError.historyChanged
      }
    }
  }
}

// Sets inside the original source are encoded in a stable order for content hashes.
private struct AlienStorageSourceEvidence: Codable {
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
private struct AlienStoragePlanEvidence: Codable {
  let section: WreckSectionIdentity
  let source: AlienStorageSourceEvidence
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
extension AlienStorageWorldPlan {
  private enum CodingKeys: String, CodingKey {
    case id, owner, seed, plan, inspectedAt, requiredWorkSeconds, workSeconds
    case damagedTechnology, depleted, destroyed, lastOperation, progress
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    owner = try values.decode(UUID.self, forKey: .owner)
    seed = try values.decode(UInt64.self, forKey: .seed)
    plan = try values.decode(AlienStoragePlanEvidence.self, forKey: .plan).value()
    inspectedAt = try values.decode(Double.self, forKey: .inspectedAt)
    requiredWorkSeconds = try values.decode(Double.self, forKey: .requiredWorkSeconds)
    workSeconds = try values.decode(Double.self, forKey: .workSeconds)
    damagedTechnology = try values.decode(Bool.self, forKey: .damagedTechnology)
    depleted = try values.decode(Bool.self, forKey: .depleted)
    destroyed = try values.decode(Bool.self, forKey: .destroyed)
    lastOperation = try values.decodeIfPresent(UInt64.self, forKey: .lastOperation)
    progress = try values.decode(AlienStorageWorldProgress.self, forKey: .progress)
  }
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(owner, forKey: .owner)
    try values.encode(seed, forKey: .seed)
    try values.encode(AlienStoragePlanEvidence(plan), forKey: .plan)
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
