import Foundation

/// An original plan index is distinct from the allocator's actual emitted lot serial.
enum AlienStorageEmissionOrigin: Codable, Hashable, Sendable {
  case structural
  case planned(itemIndex: UInt16, chunkOrdinal: UInt16)
}

struct AlienStorageCompanionCollection: Codable, Equatable, Sendable {
  enum Effect: Codable, Equatable, Sendable {
    case cargo(amount: CommodityAmount, before: Int, after: Int)
    case technology(storage: UUID)
  }
  let operation: UUID
  let hull: UUID
  let at: Double
  let effect: Effect
}

/// Native commodities and non-reserved technology accompanying an alien-owned section.
/// Their records do not consume the ordinary ledger's lifetime inventory/history pools.
struct AlienStorageCompanion: Codable, Equatable, Sendable {
  enum State: Codable, Equatable, Sendable {
    case pending(
      lot: SalvageLot, physicalTime: Double, offer: SpawnIdentity?, binding: ActorIdentity?)
    case collected(AlienStorageCompanionCollection)
    case discarded(at: Double)
    case destroyed(at: Double)
  }
  let id: UUID
  let owner: UUID
  let plan: UUID
  let origin: AlienStorageEmissionOrigin
  let issuedAt: Double
  let state: State
}

extension AlienStorageWorldProgress {
  /// This per-section enumeration is bounded only by the original UInt16 serial domain.
  func emissions(plan: AlienStorageWorldPlan) throws -> [AlienStorageEmissionOrigin:
    SalvageLootItem]
  {
    try validateNativeTiming(plan: plan)
    return try SalvageSectionEmissionView(seed: plan.seed, plan: plan.plan, progress: self)
      .emissions()
  }
}

enum AlienStorageCompanionValidation {
  static func validate(
    _ value: AlienStorageCompanion, plan: AlienStorageWorldPlan,
    emissions: [AlienStorageEmissionOrigin: SalvageLootItem],
    claims: inout Set<SalvageLotIdentity>, offers: inout Set<SpawnIdentity>,
    actors: inout Set<ActorIdentity>, operations: inout Set<UUID>,
    technologyStorage: inout Set<UUID>
  ) throws {
    guard value.issuedAt.isFinite, value.issuedAt >= plan.inspectedAt,
      plan.workSeconds == plan.requiredWorkSeconds,
      let item = emissions[value.origin],
      claims.insert(item.identity).inserted
    else { throw AlienStorageError.invalidJoin }
    if case .technology(let id, _, _, _) = item.content {
      guard !AlienModuleDefinition.isAttachmentDefinition(id) else {
        throw AlienStorageError.invalidJoin
      }
    }
    let system = item.identity.section.wreck.system
    switch value.state {
    case .pending(let lot, let time, let offer, let binding):
      // Parent death cannot destroy an already released independent fragment.
      guard time.isFinite, time >= value.issuedAt, offer == nil || binding == nil
      else { throw AlienStorageError.invalidJoin }
      try SalvageLotEmission.validate(lot, item: item)
      if let offer {
        guard offer.system == system, offer.producer == .salvage,
          offer.visit > 0, offer.visit < UInt64.max, offer.sequence > 0,
          offer.sequence < UInt64.max, offer.member == 0, offers.insert(offer).inserted
        else { throw AlienStorageError.invalidJoin }
      }
      if let binding {
        guard binding.system == system, binding.visit > 0, binding.visit < UInt64.max,
          binding.entity >= 2, binding.entity < UInt64.max, actors.insert(binding).inserted
        else { throw AlienStorageError.invalidJoin }
      }
    case .collected(let receipt):
      guard receipt.at.isFinite, receipt.at >= value.issuedAt,
        operations.insert(receipt.operation).inserted
      else { throw AlienStorageError.invalidJoin }
      switch (item.content, receipt.effect) {
      case (.commodity(let original), .cargo(let amount, let before, let after)):
        let total = before.addingReportingOverflow(original.quantity)
        guard original == amount, before >= 0, !total.overflow, after == total.partialValue
        else { throw AlienStorageError.invalidJoin }
      case (.technology, .technology(let storage)):
        guard technologyStorage.insert(storage).inserted else {
          throw AlienStorageError.invalidJoin
        }
      default: throw AlienStorageError.invalidJoin
      }
    case .discarded(let at), .destroyed(let at):
      guard at.isFinite, at >= value.issuedAt else { throw AlienStorageError.invalidJoin }
    }
  }

  static func preserve(_ old: AlienStorageCompanion, in current: AlienStorageCompanion) throws {
    guard old.id == current.id, old.owner == current.owner, old.plan == current.plan,
      old.origin == current.origin, old.issuedAt == current.issuedAt
    else { throw AlienStorageError.historyChanged }
    switch (old.state, current.state) {
    case (.pending(let a, let time, _, _), .pending(let b, let newTime, _, _)):
      guard a.identity == b.identity, a.loot == b.loot, newTime >= time else {
        throw AlienStorageError.historyChanged
      }
    case (.pending(_, let time, _, _), .collected(let receipt)):
      guard receipt.at >= time else { throw AlienStorageError.historyChanged }
    case (.pending(_, let time, _, _), .discarded(let at)),
      (.pending(_, let time, _, _), .destroyed(let at)):
      guard at >= time else { throw AlienStorageError.historyChanged }
    case (.collected, .collected), (.discarded, .discarded), (.destroyed, .destroyed):
      guard old == current else { throw AlienStorageError.historyChanged }
    default: throw AlienStorageError.historyChanged
    }
  }
}
