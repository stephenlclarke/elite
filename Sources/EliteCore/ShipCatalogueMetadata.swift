import Foundation

/// Authored catalogue roles are independent of an actor's current intent or allegiance.
public enum ShipCatalogueRole: String, Codable, Sendable, CaseIterable {
  case transporter, trader, pirate, military, bountyHunter, miner, leisure
  public var label: String {
    switch self {
    case .bountyHunter: "Bounty hunter"
    default: rawValue.capitalized
    }
  }
  public var minimumStandardCargoTonnes: Int {
    switch self {
    case .transporter: 150
    case .trader: 25
    default: 0
    }
  }
}
/// Player-facing taxonomy; Alien does not replace the functional AI role.
public enum ShipCatalogueType: String, Codable, Sendable, CaseIterable {
  case transporter, trader, pirate, military, bountyHunter, miner, leisure, alien
  public var label: String {
    switch self {
    case .bountyHunter: "Bounty hunter"
    default: rawValue.capitalized
    }
  }
}
public enum ShipCatalogueCapitalSubtype: String, Codable, Sendable {
  case vessel, station
}
public enum ShipCataloguePurchasePolicy: String, Codable, Sendable {
  case blueprintFabrication, pendingFabrication, xyzzyOnly, never
}
public enum ShipCatalogueCollectionMilestone: String, Codable, Sendable {
  case none, blueprintAndFabrication, destruction, docking
}
public enum ShipCatalogueDamagePolicy: String, Codable, Sendable {
  case destructible, activeStationIndestructible
}
public struct ShipCatalogueHabitat: Codable, Sendable, Equatable {
  public let governments: [Int]
  public let minimumDisplayedTechLevel: Int
  var valid: Bool {
    !governments.isEmpty && Set(governments).count == governments.count
      && governments.allSatisfy { (0..<8).contains($0) }
      && (1...15).contains(minimumDisplayedTechLevel)
  }
  public func permits(government: Int, displayedTechLevel: Int) -> Bool {
    valid && governments.contains(government) && displayedTechLevel >= minimumDisplayedTechLevel
  }
}
public enum ShipCatalogueObjectKind: String, Codable, Sendable {
  case ship, station, platform, capsule, other
}
public enum ShipCatalogueOrigin: String, Codable, Sendable {
  case human, alien, unknown
}
public enum ShipCatalogueAccess: String, Codable, Sendable {
  case normal, xyzzyOnly
}
public enum ShipCatalogueEncounterMode: String, Codable, Sendable {
  case natural, authored, none
}
public enum ShipCatalogueMechanicsStatus: String, Codable, Sendable {
  case ready, pending
}
public enum ShipCataloguePlacementStatus: String, Codable, Sendable {
  case declared, pending
}
public enum ShipCatalogueRarity: String, Codable, Sendable, CaseIterable {
  case common, uncommon, rare
  /// Version-one project population balance, before the authored role preference.
  public var encounterWeight: Int {
    switch self {
    case .common: 100
    case .uncommon: 25
    case .rare: 5
    }
  }
}
public struct ShipCatalogueRoleWeight: Codable, Sendable, Equatable {
  public let role: ShipCatalogueRole
  public let weight: Int
}

/// Per-hull population eligibility only. Native admission and discovery are actor-owned.
public struct ShipCatalogueMetadata: Codable, Sendable, Equatable {
  public let schemaVersion: Int
  public let family: String
  public let aliases: [String]?
  public let objectKind: ShipCatalogueObjectKind
  public let origin: ShipCatalogueOrigin
  public let primaryType: ShipCatalogueType?
  /// Functional AI eligibility, separate from the eight displayed types.
  public let primaryRole: ShipCatalogueRole?
  public let roleWeights: [ShipCatalogueRoleWeight]
  public let access: ShipCatalogueAccess
  public let playerFlyable: Bool
  /// Catalogue capability only; never a commander discovery unlock or trade authority.
  public let normalPurchaseEligible: Bool
  public let purchasePolicy: ShipCataloguePurchasePolicy
  public let minimumBuildTechLevel: Int?
  /// Structural parent, independent of functional/display taxonomy.
  public let isCapital: Bool
  public let capitalSubtype: ShipCatalogueCapitalSubtype?
  public let collectionMilestone: ShipCatalogueCollectionMilestone
  public let damagePolicy: ShipCatalogueDamagePolicy
  /// Natural ecology only; never a fabrication licence, faction entitlement or legal status.
  public let habitat: ShipCatalogueHabitat?
  /// Intended collection membership, including explicitly pending mechanics/providers.
  public let discoveryEligible: Bool
  public let encounterMode: ShipCatalogueEncounterMode
  /// Pending retains intended eligibility without claiming delivered native mechanics.
  public let mechanicsStatus: ShipCatalogueMechanicsStatus
  /// Declared is placement policy, not proof of actual admitted runtime reachability.
  public let placementStatus: ShipCataloguePlacementStatus
  public let rarity: ShipCatalogueRarity
  /// Zero-based galaxy indices, matching SystemIdentity.galaxy.
  public let galaxies: [Int]
  public let regions: [EncounterRegion]
  /// Authored location intent only; pending providers are not created by this field.
  public let authoredSystems: [SystemIdentity]?
  public let basis: String
  /// Catalogue pool policy only; the runtime still authenticates and admits each actor.
  public var readyForNaturalEncounters: Bool {
    access == .normal && encounterMode == .natural && mechanicsStatus == .ready
      && placementStatus == .declared
  }
  public var normallyDiscoverable: Bool {
    access == .normal && discoveryEligible
  }
  public var minimumStandardCargoTonnes: Int {
    roleWeights.map { $0.role.minimumStandardCargoTonnes }.max() ?? 0
  }
  public func encounterWeight(for role: ShipCatalogueRole) -> Int {
    guard readyForNaturalEncounters,
      let preference = roleWeights.first(where: { $0.role == role }),
      (1...100).contains(preference.weight)
    else { return 0 }
    return rarity.encounterWeight * preference.weight
  }
  /// Effective project comparisons describe the same standard fit as actual game values.
  func validEffectiveCargo(performance: ShipPerformance?, profiles: [ShipProfile]) -> Bool {
    guard let performance else { return true }
    let selected = profiles.filter {
      $0.group == "project-refit-v1" || $0.group == "liberator-native-v1"
    }
    guard selected.count == 1, let profile = selected.first else { return false }
    func tonnes(_ key: String) -> Double? {
      let values = profile.fields.filter { $0.key == key }
      guard values.count == 1, let value = values.first, value.unit == "t",
        let number = value.number, number.isFinite, number >= 0, number.rounded() == number
      else { return nil }
      return number
    }
    if profile.group == "liberator-native-v1" {
      return tonnes("cargo") == Double(performance.cargo)
        && tonnes("cargoExpansion") == Double(performance.cargoExpansion)
        && performance.cargo >= minimumStandardCargoTonnes
    }
    guard let cabinHold = tonnes("hold_used_by_cabins"), cabinHold <= Double(performance.cargo),
      let usable = tonnes("usable_cargo_after_fit")
    else { return false }
    return tonnes("cargo_tonnes") == Double(performance.cargo)
      && tonnes("cargo_expansion_tonnes") == Double(performance.cargoExpansion)
      && usable == Double(performance.cargo) - cabinHold
      && usable >= Double(minimumStandardCargoTonnes)
  }

  private var validPurchasePolicy: Bool {
    let validLevel = minimumBuildTechLevel.map { (1...15).contains($0) } ?? false
    switch purchasePolicy {
    case .blueprintFabrication:
      return normalPurchaseEligible && collectionMilestone == .blueprintAndFabrication && validLevel
    case .pendingFabrication:
      return !normalPurchaseEligible && objectKind == .ship && mechanicsStatus == .pending
        && access == .normal && collectionMilestone == .blueprintAndFabrication && validLevel
    case .xyzzyOnly:
      return access == .xyzzyOnly && !normalPurchaseEligible && !discoveryEligible
        && collectionMilestone == .none && minimumBuildTechLevel == nil
    case .never: return !normalPurchaseEligible && minimumBuildTechLevel == nil
    }
  }
  private var validCollectionPolicy: Bool {
    switch collectionMilestone {
    case .none: return !discoveryEligible
    case .blueprintAndFabrication:
      return discoveryEligible && objectKind == .ship
        && (purchasePolicy == .blueprintFabrication || purchasePolicy == .pendingFabrication)
    case .destruction:
      return discoveryEligible && isCapital && capitalSubtype == .vessel && purchasePolicy == .never
        && damagePolicy == .destructible
    case .docking:
      return discoveryEligible && isCapital && capitalSubtype == .station
        && (objectKind == .station || objectKind == .platform)
        && purchasePolicy == .never && damagePolicy == .activeStationIndestructible
    }
  }

  private var validCapitalHierarchy: Bool {
    guard isCapital == (capitalSubtype != nil) else { return false }
    switch capitalSubtype {
    case .none: return objectKind != .station && collectionMilestone != .docking
    case .some(.vessel): return objectKind == .ship && collectionMilestone == .destruction
    case .some(.station):
      return (objectKind == .station || objectKind == .platform) && collectionMilestone == .docking
    }
  }

  func valid(shipID: String, performance: ShipPerformance?, nativeCombat: NativeCombat?) -> Bool {
    guard schemaVersion == 2, !family.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !basis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      Set(aliases ?? []).count == (aliases ?? []).count,
      (aliases ?? []).allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
      Set(authoredSystems ?? []).count == (authoredSystems ?? []).count,
      (authoredSystems ?? []).allSatisfy({
        encounterMode == .authored && galaxies.contains($0.galaxy)
          && (0..<8).contains($0.galaxy) && (0...256).contains($0.system)
      }),
      Set(galaxies).count == galaxies.count, galaxies.allSatisfy({ (0..<8).contains($0) }),
      Set(regions.map(\.rawValue)).count == regions.count,
      Set(roleWeights.map { $0.role.rawValue }).count == roleWeights.count,
      roleWeights.allSatisfy({ (1...100).contains($0.weight) }),
      primaryRole.map({ primary in roleWeights.contains { $0.role == primary } })
        ?? roleWeights.isEmpty,
      !playerFlyable || performance != nil,
      !normalPurchaseEligible
        || (access == .normal && objectKind == .ship && playerFlyable && discoveryEligible
          && mechanicsStatus == .ready),
      !discoveryEligible || (access == .normal && encounterMode != .none),
      objectKind != .ship || primaryType != nil,
      objectKind == .ship || primaryType == nil,
      objectKind != .ship || encounterMode == .none || primaryRole != nil,
      habitat?.valid ?? true,
      validCapitalHierarchy
    else { return false }
    guard validPurchasePolicy, validCollectionPolicy,
      objectKind != .station || collectionMilestone == .docking,
      damagePolicy != .activeStationIndestructible || objectKind == .station
        || objectKind == .platform
    else { return false }
    if let performance, performance.cargo < minimumStandardCargoTonnes { return false }
    if objectKind == .ship && mechanicsStatus == .ready && performance == nil && nativeCombat == nil
    {
      return false
    }
    if shipID == "SH171" {
      guard access == .xyzzyOnly, primaryType == .alien, purchasePolicy == .xyzzyOnly,
        !normalPurchaseEligible, !discoveryEligible,
        encounterMode == .none
      else {
        return false
      }
    }
    switch encounterMode {
    case .none: return placementStatus == .declared && galaxies.isEmpty && regions.isEmpty
    case .natural:
      return access == .normal && placementStatus == .declared
        && (objectKind != .ship || primaryRole != nil)
        && !galaxies.isEmpty && !regions.isEmpty
    case .authored:
      return access == .normal
        && (placementStatus == .pending || (!galaxies.isEmpty && !regions.isEmpty))
    }
  }
}
