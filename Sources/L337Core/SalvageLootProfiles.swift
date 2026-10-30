import Foundation

public enum SalvageSourceRole: String, Hashable, CaseIterable, Codable, Sendable {
  case thargoid, drugFactory, weaponsPlatform, rockHermit, station, militaryCapital
  case commercialTrader, commercialCarrier, generalShip, asteroid
}

public enum SalvageLootProfile: String, CaseIterable, Codable, Sendable {
  case drugFactory, weaponsPlatform, station, asteroid, rockHermit, commercial, capital, thargoid,
    generalShip
}

public enum SalvageLootBucket: String, Hashable, Codable, Sendable {
  case illegalGoods, ordinaryCargo, shipItem, weaponItem, otherShipUpgrade
  case cargo, ore, commercialCargo, shieldItem, otherShipItem, alienArtefact
}

public struct SalvageLootWeight: Equatable, Codable, Sendable {
  public let bucket: SalvageLootBucket
  public let percent: Int
}

public struct SalvageLootSource: Equatable, Codable, Sendable {
  public let roles: Set<SalvageSourceRole>
  public let legalValue: Int
  public let economy: Int
  public let technology: Int
  public let ownership: SalvageOwnership
  public var stolenProvenance = false
  /// nil means unknown; an empty array is an authoritative empty manifest.
  public var manifest: [CommodityAmount]?
  public var manifestSection: UInt16 = 1
  public var manifestAlreadySettled = false
}

public struct SalvageLootLegality: Equatable, Codable, Sendable {
  public let commodityIllegal: Bool
  public let sourceLegalValue: Int
  public let ownership: SalvageOwnership
  public let stolenProvenance: Bool
}

public enum SalvageLootContent: Equatable, Codable, Sendable {
  case commodity(CommodityAmount)
  case technology(
    definitionID: String, quality: SalvageQuality, conditionPercent: Int, axis: SalvageUpgradeAxis?)
}

public struct SalvageLootItem: Equatable, Codable, Sendable {
  public let identity: SalvageLotIdentity
  public let content: SalvageLootContent
  /// The selected axis or discrete feature/missile effect is fixed with the roll.
  public let effect: SalvageTechnologyEffect?
  public let bonusBasisPoints: Int
  public let massKg: Double
  public let halfExtents: Vector3
  public let provenance: SalvageProvenance
  public let saleValueTenths: Int
  public let legality: SalvageLootLegality
  public let requiresChunking: Bool
}

public enum SalvageLootEmptyReason: String, Codable, Sendable {
  case unsupportedSource, invalidManifest, invalidSection, manifestAlreadyHandled
  case unavailableCargo, miningLedgerOwnsOre, missingDefinition
}

/// G1 stores this whole value at first creation/inspection, including empty results.
public struct SalvageLootPlan: Equatable, Codable, Sendable {
  public let section: WreckSectionIdentity
  public let source: SalvageLootSource
  public var originalManifest: [CommodityAmount]? { source.manifest }
  public var manifestChunkingRequired: Bool {
    source.manifest?.contains { $0.quantity > ($0.commodity.unit == "t" ? 5 : 3) } ?? false
  }
  public let profile: SalvageLootProfile?
  public let bucket: SalvageLootBucket?
  public let items: [SalvageLootItem]
  public let emptyReason: SalvageLootEmptyReason?
}

private struct SalvageLootRandom {
  var state: UInt64
  mutating func next() -> UInt64 {
    state &+= 0x9e37_79b9_7f4a_7c15
    var value = state
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    return value ^ (value >> 31)
  }
}

public enum SalvageLootProfiles {
  public static func profile(roles: Set<SalvageSourceRole>) -> SalvageLootProfile? {
    if roles.contains(.thargoid) { return .thargoid }
    if roles.contains(.drugFactory) { return .drugFactory }
    if roles.contains(.weaponsPlatform) { return .weaponsPlatform }
    if roles.contains(.rockHermit) { return .rockHermit }
    if roles.contains(.station) { return .station }
    if roles.contains(.militaryCapital) { return .capital }
    if !roles.isDisjoint(with: [.commercialTrader, .commercialCarrier]) { return .commercial }
    if roles.contains(.generalShip) { return .generalShip }
    return roles.contains(.asteroid) ? .asteroid : nil
  }

  public static func weights(for profile: SalvageLootProfile) -> [SalvageLootWeight] {
    let pairs: [(SalvageLootBucket, Int)]
    switch profile {
    case .drugFactory: pairs = [(.illegalGoods, 70), (.ordinaryCargo, 20), (.shipItem, 10)]
    case .weaponsPlatform:
      pairs = [(.weaponItem, 60), (.ordinaryCargo, 30), (.otherShipUpgrade, 10)]
    case .station: pairs = [(.cargo, 85), (.shipItem, 15)]
    case .asteroid: pairs = [(.ore, 100)]
    case .rockHermit: pairs = [(.ore, 90), (.shipItem, 10)]
    case .commercial, .generalShip: pairs = [(.commercialCargo, 95), (.shipItem, 5)]
    case .capital: pairs = [(.shieldItem, 55), (.cargo, 25), (.otherShipItem, 20)]
    case .thargoid: pairs = [(.alienArtefact, 100)]
    }
    return pairs.map { .init(bucket: $0.0, percent: $0.1) }
  }

  public static func plan(section: WreckSectionIdentity, seed: UInt64, source: SalvageLootSource)
    -> SalvageLootPlan
  {
    let resolved = profile(roles: source.roles)
    guard section.section < 64 else {
      return .init(
        section: section, source: source, profile: resolved, bucket: nil, items: [],
        emptyReason: .invalidSection)
    }
    guard let resolved else {
      return .init(
        section: section, source: source, profile: nil, bucket: nil, items: [],
        emptyReason: .unsupportedSource)
    }
    var random = SalvageLootRandom(
      state: seed ^ 0x5341_4c56_4c4f_4f54 ^ section.wreck.lineage
        ^ UInt64(section.wreck.site) << 32 ^ UInt64(section.section)
        ^ UInt64(truncatingIfNeeded: section.wreck.system.galaxy) &* 0x9e37_79b9_7f4a_7c15
        ^ UInt64(truncatingIfNeeded: section.wreck.system.system))
    let roll = Int(random.next() % 100)
    var threshold = 0
    let bucket = weights(for: resolved).first {
      threshold += $0.percent
      return roll < threshold
    }!.bucket
    if resolved == .asteroid {
      return .init(
        section: section, source: source, profile: resolved, bucket: bucket, items: [],
        emptyReason: .miningLedgerOwnsOre)
    }
    if let manifest = source.manifest, manifest.count > 17 || !manifest.allSatisfy(\.valid) {
      return .init(
        section: section, source: source, profile: resolved, bucket: bucket, items: [],
        emptyReason: .invalidManifest)
    }
    var items: [SalvageLootItem] = []
    // Known cargo is emitted once by its designated section, never replaced by random cargo.
    // Independent missing technology may still roll, including on known-empty combat ships.
    if resolved != .thargoid, resolved != .rockHermit,
      let manifest = source.manifest, !source.manifestAlreadySettled,
      section.section == source.manifestSection
    {
      for amount in manifest {
        items.append(commodity(amount, section: section, lot: UInt16(items.count), source: source))
      }
    }
    var empty: SalvageLootEmptyReason?
    switch bucket {
    case .illegalGoods, .ordinaryCargo, .cargo, .commercialCargo:
      if source.manifest != nil {
        empty = .manifestAlreadyHandled
      } else if let amount = cargo(bucket: bucket, source: source, random: &random) {
        items.append(commodity(amount, section: section, lot: UInt16(items.count), source: source))
      } else {
        empty = .unavailableCargo
      }
    case .ore:
      items.append(
        commodity(
          .init(commodity: .minerals, quantity: 1 + Int(random.next() % 5)), section: section,
          lot: 0, source: source))
      if random.next() % 100 < 20 {
        items.append(
          commodity(
            .init(commodity: .alloys, quantity: 1), section: section, lot: UInt16(items.count),
            source: source))
      }
      if random.next() % 100 < 2 {
        items.append(
          commodity(
            .init(commodity: random.next() & 1 == 0 ? .gold : .platinum, quantity: 1),
            section: section, lot: UInt16(items.count), source: source))
      }
    default:
      if let item = technology(
        bucket: bucket, section: section, lot: UInt16(items.count), source: source, random: &random)
      {
        items.append(item)
      } else {
        empty = .missingDefinition
      }
    }
    return .init(
      section: section, source: source, profile: resolved, bucket: bucket, items: items,
      emptyReason: items.isEmpty ? empty : nil)
  }

  private static let illegal: [CommodityIdentity] = [.slaves, .narcotics, .firearms]
  private static let legal: [CommodityIdentity] = [
    .food, .textiles, .radioactives, .liquor, .luxuries, .computers, .machinery, .alloys, .furs,
    .minerals, .gold, .platinum, .gemstones,
  ]

  private static func cargo(
    bucket: SalvageLootBucket, source: SalvageLootSource, random: inout SalvageLootRandom
  ) -> CommodityAmount? {
    let contraband: Bool
    if bucket == .illegalGoods {
      contraband = true
    } else if bucket == .commercialCargo {
      let chance = source.legalValue == 0 ? 5 : (source.legalValue < 50 ? 35 : 60)
      contraband = random.next() % 100 < chance
    } else {
      contraband = false
    }
    _ = random.next()  // Preserve this existing manifest draw independently of market state.
    let pool = contraband ? illegal : legal
    let market = MarketItem.authoredManifest
    let available = pool.filter { market[$0.rawValue].quantity > 0 }
    // An impossible pool produces the explicit unavailableCargo plan, never substitute loot.
    guard !available.isEmpty else { return nil }
    // Factories most often contain narcotics when their illegal roll has local stock.
    let identity =
      bucket == .illegalGoods && available.contains(.narcotics) && random.next() % 10 < 7
      ? CommodityIdentity.narcotics : available[Int(random.next() % UInt64(available.count))]
    let maximum = min(identity.unit == "t" ? 5 : 3, market[identity.rawValue].quantity)
    return .init(commodity: identity, quantity: 1 + Int(random.next() % UInt64(maximum)))
  }

  private static func commodity(
    _ amount: CommodityAmount, section: WreckSectionIdentity, lot: UInt16, source: SalvageLootSource
  ) -> SalvageLootItem {
    let mass =
      Double(amount.quantity)
      * (amount.commodity.unit == "t" ? 1000 : amount.commodity.unit == "kg" ? 1 : 0.001)
    let half = max(1, pow(max(1, mass) / 100, 1.0 / 3) * 4)
    let market = MarketItem.authoredManifest
    let price = market[amount.commodity.rawValue].price
    let (value, overflow) = amount.quantity.multipliedReportingOverflow(by: price)
    return .init(
      identity: .init(section: section, lot: lot), content: .commodity(amount), effect: nil,
      bonusBasisPoints: 0, massKg: mass, halfExtents: .init(half, half, half), provenance: .human,
      saleValueTenths: overflow ? Int.max : value,
      legality: .init(
        commodityIllegal: illegal.contains(amount.commodity), sourceLegalValue: source.legalValue,
        ownership: source.ownership, stolenProvenance: source.stolenProvenance),
      requiresChunking: amount.quantity > (amount.commodity.unit == "t" ? 5 : 3))
  }

  private static func technology(
    bucket: SalvageLootBucket, section: WreckSectionIdentity, lot: UInt16,
    source: SalvageLootSource, random: inout SalvageLootRandom
  ) -> SalvageLootItem? {
    let weapons = [
      "laser-technology", "missile-standard", "missile-guided", "missile-heavy",
      "missile-ecm-resistant", "laser-hardpoint", "missile-pylon",
    ]
    let other = [
      "computer-core", "drive-technology", "shield-technology", "energy-technology",
      "spare-escape-pod",
      "feature-mining-targeting", "feature-salvage-targeting", "feature-fuel-scoops", "feature-ecm",
      "feature-salvage-cutter",
    ]
    let pool: [String]
    let selection = random.next()
    switch bucket {
    case .alienArtefact:
      guard source.roles.contains(.thargoid) else { return nil }
      // Project balance: five percent of alien outcomes yield a physical drive;
      // the four scalar modules and their upgrades retain their existing selection.
      // Reuse the pre-existing selection draw; human pools and their RNG cadence are unchanged.
      let kind = AlienModuleKind.allCases[Int((selection / 100) % 4)]
      let roll = selection % 100
      pool = [
        roll < 5
          ? AlienModuleKind.hyperspaceDrive.definitionID
          : roll < 50 ? "alien-artefact" : roll < 75 ? kind.definitionID : kind.upgradeDefinitionID
      ]
    case .shieldItem: pool = ["shield-technology"]
    case .weaponItem: pool = weapons
    case .otherShipUpgrade: pool = other
    case .otherShipItem: pool = weapons + other.filter { $0 != "shield-technology" }
    default: pool = weapons + other
    }
    let id = pool[Int(selection % UInt64(pool.count))]
    guard let definition = SalvageDefinitions.definition(id: id) else { return nil }
    let qualityRoll = random.next() % 100
    let tier = max(0, min(14, source.technology))
    let quality: SalvageQuality =
      tier >= 10 && qualityRoll < 5 ? .iii : (tier >= 5 && qualityRoll < 30 ? .ii : .i)
    let condition = 50 + Int(random.next() % 51)
    var axis: SalvageUpgradeAxis?
    var effect = definition.effect
    let physical = AlienModuleKind.allCases.first { $0.definitionID == id }
    let upgrade = AlienModuleKind.allCases.first { $0.upgradeDefinitionID == id }
    if let upgrade {
      axis = upgrade.axes[Int(random.next() % UInt64(upgrade.axes.count))]
      // A shield controller upgrades the matching module type, which affects both banks.
      effect = .scalar(axes: upgrade.axes)
    } else if physical == nil, case .scalar(let axes) = definition.effect, !axes.isEmpty {
      axis = axes[Int(random.next() % UInt64(axes.count))]
      effect = .scalar(axes: [axis!])
    }
    return .init(
      identity: .init(section: section, lot: lot),
      content: .technology(
        definitionID: id, quality: quality, conditionPercent: condition, axis: axis),
      effect: effect,
      bonusBasisPoints: physical?.initialContribution
        ?? (axis == nil ? 0 : quality.bonusBasisPoints),
      massKg: definition.massKg, halfExtents: definition.halfExtents,
      provenance: definition.provenance,
      saleValueTenths: SalvageDefinitions.saleValue(
        definition: definition, conditionPercent: condition),
      legality: .init(
        commodityIllegal: false, sourceLegalValue: source.legalValue, ownership: source.ownership,
        stolenProvenance: source.stolenProvenance), requiresChunking: false)
  }
}
