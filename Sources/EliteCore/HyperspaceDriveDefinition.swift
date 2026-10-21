import Foundation

public enum HyperspaceDriveTier: String, CaseIterable, Codable, Sendable {
  case basic, intermediate, advanced
  public var order: Int {
    switch self {
    case .basic: 0
    case .intermediate: 1
    case .advanced: 2
    }
  }
  public var label: String {
    switch self {
    case .basic: "Basic Hyperspace Drive"
    case .intermediate: "Intermediate Hyperspace Drive"
    case .advanced: "Advanced Hyperspace Drive"
    }
  }
  public var activationSeconds: Double {
    switch self {
    case .basic: 10
    case .intermediate: 5
    case .advanced: 1
    }
  }
  public var massLockScale: Double {
    switch self {
    case .basic: 1
    case .intermediate: 0.8
    case .advanced: 0.6
    }
  }
  /// Undiscounted project balance prices, in Commander-native tenths of a credit.
  public var priceTenths: Int? {
    switch self {
    case .basic: nil
    case .intermediate: 50000
    case .advanced: 150000
    }
  }
  /// Stored technology is zero-based; the UI shows levels 10 and 13.
  public var technology: Int? {
    switch self {
    case .basic: nil
    case .intermediate: 9
    case .advanced: 12
    }
  }
}

/// This pure catalogue does not install drives, create paid history or publish shop offers.
public enum HyperspaceDriveDefinition {
  public static let family = ComponentFamily("hyperspace-drive")
  public static let purchaseFamily = EquipmentFamilyID("hyperspace-drive")
  /// Ordinary upgrades retain positive seconds. Alien immediacy is a separate typed policy.
  public static let minimumOrdinarySeconds = 0.7
  public static func node(for tier: HyperspaceDriveTier) -> EquipmentNodeID {
    .init(family: purchaseFamily, key: tier.label)
  }
  public static func template(for tier: HyperspaceDriveTier) -> ComponentTemplate {
    .init(
      identity: .init(family: family, id: tier.rawValue, version: 1), order: tier.order,
      statistics: [.jumpSpool: tier.activationSeconds], requiredAxes: [.jumpSpool])
  }
  public static let componentDefinition = ComponentFamilyDefinition(
    family: family, revision: 1,
    grades: HyperspaceDriveTier.allCases.map { template(for: $0) },
    terminalLimits: [.jumpSpool: minimumOrdinarySeconds])
  public static let purchaseGraph = EquipmentPurchaseGraph(
    revision: 1,
    nodes: HyperspaceDriveTier.allCases.map { tier in
      let previous: EquipmentNodeID? =
        tier == .basic ? nil : node(for: HyperspaceDriveTier.allCases[tier.order - 1])
      return .init(
        id: node(for: tier), displayName: tier.label,
        policy: tier == .basic ? .standardFoundation : .shop,
        prerequisites: previous.map { [$0] } ?? [],
        fittedPrerequisites: previous.map { [$0] } ?? [])
    })
}
