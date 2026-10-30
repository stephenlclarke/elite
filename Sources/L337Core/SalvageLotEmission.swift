import Foundation

/// Shared pure reconstruction of the existing native producer's exact emitted item.
enum SalvageLotEmission {
  static func structuralUnits(seed: UInt64, section: WreckSectionIdentity) -> Int {
    var value =
      seed ^ 0x4855_4C4C_504C_4154 ^ section.wreck.lineage
      ^ UInt64(section.wreck.site) << 32 ^ UInt64(section.section)
      ^ UInt64(section.wreck.system.system) &* 0xBF58_476D_1CE4_E5B9
      ^ UInt64(section.wreck.system.galaxy) &* 0x9E37_79B9_7F4A_7C15
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    return 1 + Int((value ^ (value >> 27)) % 5)
  }

  static func quantity(_ item: SalvageLootItem) -> Int {
    if case .commodity(let amount) = item.content { return amount.quantity }
    return 1
  }
  static func chunkLimit(_ item: SalvageLootItem) -> Int {
    guard case .commodity(let amount) = item.content else { return 1 }
    switch amount.commodity.unit {
    case "t": return 5
    case "kg": return 1000
    default: return 1_000_000
    }
  }
  static func mass(_ amount: CommodityAmount) -> Double {
    Double(amount.quantity)
      * (amount.commodity.unit == "t" ? 1000 : amount.commodity.unit == "kg" ? 1 : 0.001)
  }
  static func chunk(_ item: SalvageLootItem, identity: SalvageLotIdentity, quantity: Int)
    -> SalvageLootItem
  {
    guard case .commodity(let amount) = item.content else {
      return .init(
        identity: identity, content: item.content, effect: item.effect,
        bonusBasisPoints: item.bonusBasisPoints, massKg: item.massKg, halfExtents: item.halfExtents,
        provenance: item.provenance, saleValueTenths: item.saleValueTenths,
        legality: item.legality, requiresChunking: false)
    }
    let chunkAmount = CommodityAmount(commodity: amount.commodity, quantity: quantity)
    let mass = mass(chunkAmount)
    let half = max(1, pow(max(1, mass) / 100, 1.0 / 3) * 4)
    return .init(
      identity: identity, content: .commodity(chunkAmount), effect: nil, bonusBasisPoints: 0,
      massKg: mass, halfExtents: .init(half, half, half), provenance: item.provenance,
      saleValueTenths: item.saleValueTenths / Self.quantity(item) * quantity,
      legality: item.legality, requiresChunking: false)
  }
  static func structural(
    plan: SalvageLootPlan, quantity: Int, material: CommodityIdentity, identity: SalvageLotIdentity
  ) -> SalvageLootItem {
    let amount = CommodityAmount(commodity: material, quantity: quantity)
    let mass = mass(amount)
    let half = max(1, pow(max(1, mass) / 100, 1.0 / 3) * 4)
    let source = plan.source
    let price = MarketItem.authoredManifest[
      amount.commodity.rawValue
    ].price
    return .init(
      identity: identity, content: .commodity(amount), effect: nil, bonusBasisPoints: 0,
      massKg: mass, halfExtents: .init(half, half, half), provenance: .human,
      saleValueTenths: price * amount.quantity,
      legality: .init(
        commodityIllegal: false, sourceLegalValue: source.legalValue,
        ownership: source.ownership, stolenProvenance: source.stolenProvenance),
      requiresChunking: false)
  }
  static func validate(_ lot: SalvageLot, item: SalvageLootItem) throws {
    let content: SalvageLotContent
    switch item.content {
    case .commodity(let amount): content = .commodity(amount)
    case .technology(let id, let quality, let condition, _):
      content = .technology(definitionID: id, quality: quality, conditionPercent: condition)
    }
    guard lot.identity == item.identity, lot.loot == item, lot.content == content,
      lot.massKg == item.massKg, lot.halfExtents == item.halfExtents,
      lot.position.finite, lot.position.length.isFinite,
      lot.velocity.finite, lot.velocity.length.isFinite
    else { throw AlienStorageError.invalidJoin }
  }
}
