import Foundation

/// Arrays have exactly the immutable original plan's item count, never lifetime history.
/// The shared native allocator is retained even when ordinary and alien custody diverge.
struct AlienStorageWorldProgress: Codable, Sendable, Equatable {
  let issued: [Int]
  let discarded: [Bool]
  let structuralUnits: Int
  let issuedStructural: Int
  let materialKind: CommodityIdentity?
  let nextLot: UInt32

  func validate(plan: AlienStorageWorldPlan) throws {
    try SalvageSectionEmissionView(seed: plan.seed, plan: plan.plan, progress: self)
      .validateAllocator()
    try validateNativeTiming(plan: plan)
  }

  /// Native observations retain their existing work/timestamp requirements.
  /// Legacy imports use the separate timing-free emission view instead.
  func validateNativeTiming(plan: AlienStorageWorldPlan) throws {
    guard issued.count == plan.plan.items.count, discarded.count == issued.count,
      plan.lastOperation.map({ $0 > 0 }) ?? (plan.workSeconds == 0),
      materialKind != nil || (plan.workSeconds == 0 && !discarded.contains(true)),
      !discarded.contains(true) || plan.lastOperation != nil,
      !plan.depleted || plan.destroyed || plan.workSeconds == plan.requiredWorkSeconds,
      issuedStructural == 0 || plan.workSeconds == plan.requiredWorkSeconds
    else { throw AlienStorageError.invalidJoin }
    let complete = zip(issued, plan.plan.items).allSatisfy {
      $0 == SalvageLotEmission.quantity($1)
    }
    guard !plan.depleted || plan.destroyed || (complete && issuedStructural == structuralUnits)
    else { throw AlienStorageError.invalidJoin }
    for index in issued.indices where issued[index] > 0 && !discarded[index] {
      guard plan.workSeconds == plan.requiredWorkSeconds else {
        throw AlienStorageError.invalidJoin
      }
    }
  }

  /// Exact existing issuedItem cursor mapping, including earlier structural/commodity lots.
  func issuedIdentity(itemIndex: Int, plan: SalvageLootPlan) throws -> SalvageLotIdentity {
    guard issued.count == plan.items.count, discarded.count == issued.count,
      issued.allSatisfy({ $0 >= 0 }), issued.indices.contains(itemIndex),
      !discarded[itemIndex], issued[itemIndex] > 0
    else {
      throw AlienStorageError.invalidJoin
    }
    var ordinal: UInt64 = issuedStructural > 0 ? 1 : 0
    for index in 0..<itemIndex where !discarded[index] && issued[index] > 0 {
      let count = UInt64((issued[index] - 1) / SalvageLotEmission.chunkLimit(plan.items[index]) + 1)
      let next = ordinal.addingReportingOverflow(count)
      guard !next.overflow else { throw AlienStorageError.arithmeticOverflow }
      ordinal = next.partialValue
    }
    guard let value = UInt16(exactly: ordinal), ordinal < nextLot else {
      throw AlienStorageError.invalidJoin
    }
    return .init(section: plan.section, lot: value)
  }

  func preserve(_ old: Self) throws {
    guard structuralUnits == old.structuralUnits, issuedStructural >= old.issuedStructural,
      nextLot >= old.nextLot, old.materialKind == nil || materialKind == old.materialKind,
      issued.count == old.issued.count, discarded.count == old.discarded.count
    else { throw AlienStorageError.historyChanged }
    for index in issued.indices {
      guard issued[index] >= old.issued[index], !old.discarded[index] || discarded[index],
        !discarded[index] || old.discarded[index] || old.issued[index] == 0
      else { throw AlienStorageError.historyChanged }
    }
  }
}
