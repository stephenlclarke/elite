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
  public let primaryRole: ShipCatalogueRole?
  public let roleWeights: [ShipCatalogueRoleWeight]
  public let access: ShipCatalogueAccess
  public let playerFlyable: Bool
  /// Catalogue capability only; never a commander discovery unlock or trade authority.
  public let normalPurchaseEligible: Bool
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

  func valid(shipID: String, performance: ShipPerformance?, nativeCombat: NativeCombat?) -> Bool {
    guard schemaVersion == 1, !family.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
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
      objectKind != .ship || encounterMode == .none || primaryRole != nil
    else { return false }
    if let performance, performance.cargo < minimumStandardCargoTonnes { return false }
    if objectKind == .ship && mechanicsStatus == .ready && performance == nil && nativeCombat == nil
    {
      return false
    }
    if shipID == "SH171" {
      guard access == .xyzzyOnly, !normalPurchaseEligible, !discoveryEligible,
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
