import Foundation

/// Original seed/plan/allocator proof, independent of inspection or work times.
/// This value grants no native collection, import or station authority.
struct SalvageSectionEmissionView: Sendable {
  let seed: UInt64
  let plan: SalvageLootPlan
  let progress: AlienStorageWorldProgress

  func validate() throws {
    let section = plan.section
    let source = plan.source
    guard (0..<8).contains(section.wreck.system.galaxy),
      (0...256).contains(section.wreck.system.system), section.section < 64,
      (0...255).contains(source.legalValue), (0...7).contains(source.economy),
      (0...14).contains(source.technology), source.manifestSection < 64,
      (source.manifest?.count ?? 0) <= CommodityIdentity.allCases.count,
      SalvageLootProfiles.plan(section: section, seed: seed, source: source) == plan
    else { throw AlienStorageError.invalidJoin }
    try validateAllocator()
  }

  /// Native world validation checks its own timing separately, then calls emissions
  /// for the complete deterministic source proof before publishing any records.
  func validateAllocator() throws {
    let items = plan.items
    let issued = progress.issued
    let discarded = progress.discarded
    guard issued.count == items.count, discarded.count == items.count,
      (0...5).contains(progress.structuralUnits),
      (0...progress.structuralUnits).contains(progress.issuedStructural),
      progress.issuedStructural == 0 || progress.issuedStructural == progress.structuralUnits,
      progress.structuralUnits == 0
        || progress.structuralUnits
          == SalvageLotEmission.structuralUnits(seed: seed, section: plan.section),
      plan.profile != .asteroid || progress.structuralUnits == 0,
      progress.materialKind == nil || progress.materialKind == .alloys
        || progress.materialKind == .minerals,
      progress.issuedStructural == 0 || progress.materialKind != nil,
      progress.materialKind != nil || !discarded.contains(true), progress.nextLot <= 65536
    else { throw AlienStorageError.invalidJoin }
    var prefixComplete = true
    var total: UInt64 = progress.issuedStructural > 0 ? 1 : 0
    for index in items.indices {
      let quantity = SalvageLotEmission.quantity(items[index])
      let value = issued[index]
      let limit = SalvageLotEmission.chunkLimit(items[index])
      guard quantity > 0, value >= 0, value <= quantity else {
        throw AlienStorageError.invalidJoin
      }
      if discarded[index] {
        guard case .technology = items[index].content, value == 1 else {
          throw AlienStorageError.invalidJoin
        }
      } else if value > 0 {
        guard prefixComplete,
          progress.structuralUnits == 0 || progress.issuedStructural == progress.structuralUnits,
          value == quantity || value % limit == 0, progress.materialKind != nil
        else { throw AlienStorageError.invalidJoin }
        let count = UInt64((value - 1) / limit + 1)
        let next = total.addingReportingOverflow(count)
        guard !next.overflow else { throw AlienStorageError.arithmeticOverflow }
        total = next.partialValue
      }
      prefixComplete = prefixComplete && value == quantity
    }
    guard total == UInt64(progress.nextLot) else { throw AlienStorageError.invalidJoin }
  }

  /// Enumeration is bounded by the original per-section UInt16 serial domain,
  /// without a lifetime record limit or a synthetic historical work budget.
  func emissions() throws -> [AlienStorageEmissionOrigin: SalvageLootItem] {
    try validate()
    var result: [AlienStorageEmissionOrigin: SalvageLootItem] = [:]
    var serial: UInt32 = 0
    func identity() throws -> SalvageLotIdentity {
      guard let lot = UInt16(exactly: serial), serial < progress.nextLot else {
        throw AlienStorageError.invalidJoin
      }
      return .init(section: plan.section, lot: lot)
    }
    if progress.issuedStructural > 0 {
      guard let material = progress.materialKind else { throw AlienStorageError.invalidJoin }
      result[.structural] = SalvageLotEmission.structural(
        plan: plan, quantity: progress.structuralUnits, material: material,
        identity: try identity())
      serial += 1
    }
    for index in plan.items.indices
    where !progress.discarded[index] && progress.issued[index] > 0 {
      let item = plan.items[index]
      let limit = SalvageLotEmission.chunkLimit(item)
      let count = (progress.issued[index] - 1) / limit + 1
      guard let originalIndex = UInt16(exactly: index) else {
        throw AlienStorageError.invalidJoin
      }
      for ordinal in 0..<count {
        guard let chunkOrdinal = UInt16(exactly: ordinal) else {
          throw AlienStorageError.invalidJoin
        }
        result[.planned(itemIndex: originalIndex, chunkOrdinal: chunkOrdinal)] =
          SalvageLotEmission.chunk(
            item, identity: try identity(),
            quantity: min(limit, SalvageLotEmission.quantity(item) - ordinal * limit))
        serial += 1
      }
    }
    guard serial == progress.nextLot else { throw AlienStorageError.invalidJoin }
    return result
  }
}
