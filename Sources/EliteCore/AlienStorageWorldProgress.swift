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
    let items = plan.plan.items
    guard issued.count == items.count, discarded.count == items.count,
      (0...5).contains(structuralUnits), (0...structuralUnits).contains(issuedStructural),
      issuedStructural == 0 || issuedStructural == structuralUnits,
      structuralUnits == 0 || structuralUnits == Self.structuralUnits(plan),
      plan.plan.profile != .asteroid || structuralUnits == 0,
      materialKind == nil || materialKind == .alloys || materialKind == .minerals,
      issuedStructural == 0 || materialKind != nil, nextLot <= 65536,
      materialKind != nil || (plan.workSeconds == 0 && !discarded.contains(true)),
      !discarded.contains(true) || plan.lastOperation != nil,
      !plan.depleted || plan.destroyed || plan.workSeconds == plan.requiredWorkSeconds
    else { throw AlienStorageError.invalidJoin }
    var prefixComplete = true
    var total: UInt64 = issuedStructural > 0 ? 1 : 0
    for index in items.indices {
      let quantity = Self.quantity(items[index])
      let value = issued[index]
      let limit = Self.chunkLimit(items[index])
      guard quantity > 0, value >= 0, value <= quantity else { throw AlienStorageError.invalidJoin }
      if discarded[index] {
        guard case .technology = items[index].content, value == 1 else {
          throw AlienStorageError.invalidJoin
        }
      } else if value > 0 {
        guard prefixComplete, structuralUnits == 0 || issuedStructural == structuralUnits,
          value == quantity || value % limit == 0, materialKind != nil,
          plan.workSeconds == plan.requiredWorkSeconds
        else { throw AlienStorageError.invalidJoin }
        let count = UInt64((value - 1) / limit + 1)
        let next = total.addingReportingOverflow(count)
        guard !next.overflow else { throw AlienStorageError.arithmeticOverflow }
        total = next.partialValue
      }
      prefixComplete = prefixComplete && value == quantity
    }
    guard total == UInt64(nextLot),
      !plan.depleted || plan.destroyed || (prefixComplete && issuedStructural == structuralUnits),
      issuedStructural == 0 || plan.workSeconds == plan.requiredWorkSeconds
    else { throw AlienStorageError.invalidJoin }
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
      let count = UInt64((issued[index] - 1) / Self.chunkLimit(plan.items[index]) + 1)
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
  private static func quantity(_ item: SalvageLootItem) -> Int {
    if case .commodity(let amount) = item.content { return amount.quantity }
    return 1
  }
  private static func chunkLimit(_ item: SalvageLootItem) -> Int {
    guard case .commodity(let amount) = item.content else { return 1 }
    switch amount.commodity.unit {
    case "t": return 5
    case "kg": return 1000
    default: return 1_000_000
    }
  }
  private static func structuralUnits(_ plan: AlienStorageWorldPlan) -> Int {
    let section = plan.plan.section
    var value =
      plan.seed ^ 0x4855_4C4C_504C_4154 ^ section.wreck.lineage
      ^ UInt64(section.wreck.site) << 32 ^ UInt64(section.section)
      ^ UInt64(section.wreck.system.system) &* 0xBF58_476D_1CE4_E5B9
      ^ UInt64(section.wreck.system.galaxy) &* 0x9E37_79B9_7F4A_7C15
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    return 1 + Int((value ^ (value >> 27)) % 5)
  }
}
