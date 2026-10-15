import Foundation

public enum SalvageTechnologyCategory: String, CaseIterable, Codable, Sendable {
  case computerCore, driveTechnology, laserTechnology, shieldTechnology, energyTechnology,
    recoveredMissile
  case laserHardpoint, missilePylon, spareEscapePod, alienArtefact, featureModule
}

public enum SalvageQuality: Int, CaseIterable, Codable, Sendable {
  case i = 1
  case ii, iii
  public var bonusBasisPoints: Int { rawValue * 500 }
}

public enum SalvageProvenance: String, Codable, Sendable { case human, alien }

public enum SalvageUpgradeAxis: String, CaseIterable, Codable, Sendable {
  case scanningRange, acquisitionError, automationError, maximumSpeed, acceleration
  case spoolDuration, jumpFuelCost, jumpReach, laserDamage, laserEnergyCost, laserHeatCost
  case frontShieldCapacity, rearShieldCapacity, frontShieldRecharge, rearShieldRecharge
  case energyCapacity, energyRecharge

  public var reducesBaseline: Bool {
    [
      .acquisitionError, .automationError, .spoolDuration, .jumpFuelCost, .laserEnergyCost,
      .laserHeatCost,
    ].contains(self)
  }
}

/// Physical modifications belong to an actual owned hull, not its catalogue model.
public enum SalvageUpgradeTarget: Equatable, Codable, Sendable {
  case commanderResearch
  case hull(instance: UUID)
  case laser(hull: UUID, mount: LaserMount, kind: LaserKind)
}

public enum SalvageMissileVariant: String, CaseIterable, Codable, Sendable {
  case standard, guided, heavy, ecmResistant
  public var damageMultiplier: Double { self == .heavy ? 1.5 : 1 }
  public var speedMultiplier: Double { self == .heavy ? 0.8 : 1 }
  public var turningMultiplier: Double { self == .guided ? 1.25 : 1 }
  public var ecmSurvivalCharges: Int { self == .ecmResistant ? 1 : 0 }
  public var rangeMultiplier: Double { 1 }
  public var blastMultiplier: Double { 1 }
  public var heatMultiplier: Double { 1 }
}

/// Capacity-class modules keep the existing single strongest-amplifier rule.
public enum SalvageShieldSlot: String, CaseIterable, Codable, Sendable {
  case capacityAmplifier, recharge, efficiency, feature
  public static let maximumAdditiveBonusBasisPoints = 3000
  public static let minimumEfficiencyCostBasisPoints = 7000
  public static let capacityClassesStack = false

  public static func slot(for axis: SalvageUpgradeAxis) -> SalvageShieldSlot? {
    switch axis {
    case .frontShieldCapacity, .rearShieldCapacity: .capacityAmplifier
    case .frontShieldRecharge, .rearShieldRecharge: .recharge
    default: nil
    }
  }
}

public enum SalvageFeature: String, CaseIterable, Codable, Sendable {
  case miningTargetingModule, salvageTargetingModule, fuelScoops, ecm, salvageCutter
  public var requiresTargetingCore: Bool {
    self == .miningTargetingModule || self == .salvageTargetingModule
  }
}

public enum SalvageTechnologyEffect: Equatable, Codable, Sendable {
  case scalar(axes: [SalvageUpgradeAxis])
  case missile(SalvageMissileVariant)
  case feature(SalvageFeature)
  case unlockFacing, addPylon, spareEscapePod, researchAndSale
}

public struct SalvageTechnologyDefinition: Equatable, Codable, Sendable {
  public let id: String
  public let category: SalvageTechnologyCategory
  public let label: String
  public let massKg: Double
  /// Native collision-space units; these are not metres or showroom mesh units.
  public let halfExtents: Vector3
  public let baseValueTenths: Int
  public let installationCostTenths: Int
  public let provenance: SalvageProvenance
  public let effect: SalvageTechnologyEffect
}

public enum SalvageDefinitionAction: Equatable, Codable, Sendable {
  case fit(axis: SalvageUpgradeAxis?, mount: LaserMount?)
  case research, sell
}

public enum SalvageCompatibilityRefusal: String, Codable, Sendable {
  case unsupportedAxis, missingLaser, noFacingAvailable, pylonLimit, sparePodLimit
  case incompatibleHardware, invalidStructure, researchUnavailable, alreadyInstalled,
    missingTargetingCore
}

public enum SalvageCompatibilityResult: Equatable, Codable, Sendable {
  case permitted
  case refused(SalvageCompatibilityRefusal)
}

/// G1 supplies authoritative installed structure and hardware, never UI guesses.
public struct SalvageFitContext: Codable, Sendable {
  public var installedFeatures: Set<SalvageFeature>
  public var hasTargetingCore: Bool
  public var isPlughWorkshop: Bool
  public var stockFacingMask: Int
  public var installedFacingMask: Int
  public var retrofitFacingMask: Int
  public var stockPylons: Int
  public var installedPylons: Int
  public var structuralPylonLimit: Int
  public var loadedMissiles: Int
  public var fittedEscapePod: Bool
  public var storedEmptyPods: Int
  public var fittedLasers: [LaserMount: LaserKind]
  public var hasCompatibleAlienHardware: Bool
  public var computerResearchAvailable: Bool

  public init(
    stockFacingMask: Int, installedFacingMask: Int, retrofitFacingMask: Int,
    stockPylons: Int, installedPylons: Int, structuralPylonLimit: Int, storedEmptyPods: Int,
    fittedLasers: [LaserMount: LaserKind] = [:], loadedMissiles: Int = 0,
    fittedEscapePod: Bool = false, hasCompatibleAlienHardware: Bool = false,
    computerResearchAvailable: Bool = false, installedFeatures: Set<SalvageFeature> = [],
    hasTargetingCore: Bool = false, isPlughWorkshop: Bool = false
  ) {
    self.installedFeatures = installedFeatures
    self.hasTargetingCore = hasTargetingCore
    self.isPlughWorkshop = isPlughWorkshop
    self.stockFacingMask = stockFacingMask
    self.installedFacingMask = installedFacingMask
    self.retrofitFacingMask = retrofitFacingMask
    self.stockPylons = stockPylons
    self.installedPylons = installedPylons
    self.structuralPylonLimit = structuralPylonLimit
    self.loadedMissiles = loadedMissiles
    self.fittedEscapePod = fittedEscapePod
    self.storedEmptyPods = storedEmptyPods
    self.fittedLasers = fittedLasers
    self.hasCompatibleAlienHardware = hasCompatibleAlienHardware
    self.computerResearchAvailable = computerResearchAvailable
  }
}

public enum SalvageResearchDestination: Equatable, Codable, Sendable {
  case navigation(NavigationTier)
  case targeting(TargetingTier)
  case alienPrecision(SalvageUpgradeAxis)
}

/// The station must validate the exact prior tier and consume all listed cores atomically.
public struct SalvageResearchRecipe: Equatable, Codable, Sendable {
  public let id: String
  public let requiredDefinitionID: String
  public let requiredCount: Int
  public let priorTier: Int?
  public let destination: SalvageResearchDestination
  public let serviceCostTenths: Int
  public let requiresCompatibleAlienHardware: Bool
}

/// Project tuning. Catalogue geometry never implies a retrofit entitlement.
public enum SalvageDefinitions {
  public static let maximumBonusBasisPoints = 3000
  /// Retrofit ceiling; larger native stock loadouts remain valid.
  public static let maximumPylons = 8
  public static let maximumNativePylons = 32
  public static let maximumExtraPylons = 2
  public static let maximumSparePods = 2

  public static let all: [SalvageTechnologyDefinition] = [
    item(
      "computer-core", .computerCore, "Computer core", 50, Vector3(6, 4, 3), 20000,
      .scalar(axes: [.scanningRange, .acquisitionError, .automationError])),
    item(
      "drive-technology", .driveTechnology, "Drive technology", 400, Vector3(12, 8, 8), 30000,
      .scalar(axes: [.maximumSpeed, .acceleration, .spoolDuration, .jumpFuelCost, .jumpReach])),
    // Project-calibrated recovered energy controller, not a historical mass measurement.
    item(
      "energy-technology", .energyTechnology, "Energy technology", 8,
      Vector3(2, 2, 2), 12000, .scalar(axes: [.energyCapacity, .energyRecharge])),
    item(
      "laser-technology", .laserTechnology, "Laser technology", 150, Vector3(10, 4, 4), 25000,
      .scalar(axes: [.laserDamage, .laserEnergyCost, .laserHeatCost])),
    item(
      "shield-technology", .shieldTechnology, "Shield technology", 200, Vector3(8, 8, 6), 25000,
      .scalar(axes: [
        .frontShieldCapacity, .rearShieldCapacity, .frontShieldRecharge, .rearShieldRecharge,
      ])),
    item(
      "missile-standard", .recoveredMissile, "Standard missile", 100, Vector3(3, 3, 12), 3000,
      .missile(.standard)),
    item(
      "missile-guided", .recoveredMissile, "Guided missile", 100, Vector3(3, 3, 12), 4500,
      .missile(.guided)),
    item(
      "missile-heavy", .recoveredMissile, "Heavy missile", 150, Vector3(4, 4, 14), 6000,
      .missile(.heavy)),
    item(
      "missile-ecm-resistant", .recoveredMissile, "ECM-resistant missile", 100,
      Vector3(3, 3, 12), 8000, .missile(.ecmResistant)),
    item(
      "laser-hardpoint", .laserHardpoint, "Laser hardpoint assembly", 300, Vector3(12, 10, 6),
      20000, .unlockFacing),
    item(
      "missile-pylon", .missilePylon, "Missile pylon assembly", 250, Vector3(6, 6, 12), 15000,
      .addPylon),
    item(
      "spare-escape-pod", .spareEscapePod, "Empty spare escape pod", 500,
      Vector3(15, 15, 20), 10000, .spareEscapePod),
    item(
      "feature-mining-targeting", .featureModule, "Targeting: Mining Module", 2,
      Vector3(6, 4, 3), 20000, .feature(.miningTargetingModule)),
    item(
      "feature-salvage-targeting", .featureModule, "Targeting: Salvage Module", 2,
      Vector3(6, 4, 3), 40000, .feature(.salvageTargetingModule)),
    item(
      "feature-fuel-scoops", .featureModule, "Fuel Scoops", 150,
      Vector3(10, 8, 5), Equipment.base.first { $0.name == "Fuel Scoops" }!.price,
      .feature(.fuelScoops)),
    item(
      "feature-ecm", .featureModule, "E.C.M. System", 40,
      Vector3(8, 6, 4), Equipment.base.first { $0.name == "E.C.M. System" }!.price, .feature(.ecm)),
    item(
      "feature-salvage-cutter", .featureModule, "Salvage Cutter", 125,
      Vector3(12, 4, 4), 25000, .feature(.salvageCutter)),
    item(
      "alien-artefact", .alienArtefact, "Alien technology artefact", 25,
      Vector3(4, 4, 4), 50000, .researchAndSale, provenance: .alien),
  ]

  public static let researchRecipes: [SalvageResearchRecipe] = {
    let navigation = NavigationTier.allCases.dropFirst().map { tier in
      SalvageResearchRecipe(
        id: "navigation-" + String(tier.rawValue),
        requiredDefinitionID: "computer-core", requiredCount: 2, priorTier: tier.rawValue - 1,
        destination: .navigation(tier), serviceCostTenths: tier.price / 2,
        requiresCompatibleAlienHardware: false)
    }
    let targeting = TargetingTier.allCases.dropFirst().map { tier in
      SalvageResearchRecipe(
        id: "targeting-" + String(tier.rawValue),
        requiredDefinitionID: "computer-core", requiredCount: 2, priorTier: tier.rawValue - 1,
        destination: .targeting(tier), serviceCostTenths: tier.price / 2,
        requiresCompatibleAlienHardware: false)
    }
    let alien = [SalvageUpgradeAxis.scanningRange, .acquisitionError, .automationError].map {
      axis in
      SalvageResearchRecipe(
        id: "alien-" + axis.rawValue,
        requiredDefinitionID: "alien-artefact", requiredCount: 1, priorTier: nil,
        destination: .alienPrecision(axis), serviceCostTenths: 5000,
        requiresCompatibleAlienHardware: true)
    }
    return navigation + targeting + alien
  }()

  public static func definition(id: String) -> SalvageTechnologyDefinition? {
    all.first { $0.id == id }
  }

  /// Legacy ungraded effects only. Graded components use ComponentProgression and its
  /// authoritative terminal bounds; this helper must never impose a lifetime promotion cap.
  public static func effective(base: Double, axis: SalvageUpgradeAxis, bonusesBasisPoints: [Int])
    -> Double
  {
    guard base.isFinite, base >= 0 else { return 0 }
    let bonus = bonusesBasisPoints.reduce(0) { sum, value in
      min(maximumBonusBasisPoints, sum + min(maximumBonusBasisPoints, max(0, value)))
    }
    let fraction = Double(bonus) / 10000
    return base * (axis.reducesBaseline ? 1 - fraction : 1 + fraction)
  }

  /// Jump technology changes neither tank storage nor the installed navigation cap.
  public static func effectiveJumpReach(
    base: Double, bonusesBasisPoints: [Int], navigationCap: Double
  )
    -> Double
  {
    guard navigationCap.isFinite, navigationCap > 0 else { return 0 }
    return min(
      navigationCap,
      effective(
        base: base, axis: .jumpReach,
        bonusesBasisPoints: bonusesBasisPoints))
  }

  public static func saleValue(definition: SalvageTechnologyDefinition, conditionPercent: Int)
    -> Int
  {
    guard (0...100).contains(conditionPercent), definition.baseValueTenths >= 0 else { return 0 }
    let whole = definition.baseValueTenths / 100 * conditionPercent
    let fraction = definition.baseValueTenths % 100 * conditionPercent / 100
    return whole + fraction
  }

  public static func compatibility(
    definition: SalvageTechnologyDefinition,
    action: SalvageDefinitionAction, context: SalvageFitContext
  ) -> SalvageCompatibilityResult {
    if action == .sell { return .permitted }
    if action == .research {
      if definition.category == .alienArtefact {
        return context.hasCompatibleAlienHardware && context.isPlughWorkshop
          ? .permitted : .refused(.incompatibleHardware)
      }
      return definition.category == .computerCore && context.computerResearchAvailable
        ? .permitted : .refused(.researchUnavailable)
    }
    guard case .fit(let axis, let mount) = action else { return .refused(.unsupportedAxis) }
    switch definition.effect {
    case .scalar(let axes):
      guard let axis, axes.contains(axis) else { return .refused(.unsupportedAxis) }
      if definition.category == .laserTechnology {
        guard let mount, context.fittedLasers[mount] != nil else { return .refused(.missingLaser) }
      }
      return .permitted
    case .unlockFacing:
      guard validStructure(context) else { return .refused(.invalidStructure) }
      guard let mount, context.installedFacingMask & mask(mount) == 0,
        context.retrofitFacingMask & mask(mount) != 0
      else { return .refused(.noFacingAvailable) }
      return .permitted
    case .addPylon:
      guard validStructure(context) else { return .refused(.invalidStructure) }
      let limit =
        context.stockPylons >= maximumPylons
        ? context.stockPylons
        : min(
          maximumPylons, context.structuralPylonLimit,
          context.stockPylons + maximumExtraPylons)
      return context.installedPylons < limit ? .permitted : .refused(.pylonLimit)
    case .spareEscapePod:
      return (0...maximumSparePods).contains(context.storedEmptyPods) && !context.fittedEscapePod
        ? .permitted : .refused(.sparePodLimit)
    case .missile:
      return context.installedPylons > 0 && context.installedPylons <= maximumNativePylons
        && (0..<context.installedPylons).contains(context.loadedMissiles)
        ? .permitted : .refused(.pylonLimit)
    case .feature(let feature):
      guard axis == nil, mount == nil else { return .refused(.unsupportedAxis) }
      guard !context.installedFeatures.contains(feature) else { return .refused(.alreadyInstalled) }
      guard !feature.requiresTargetingCore || context.hasTargetingCore else {
        return .refused(.missingTargetingCore)
      }
      return .permitted
    case .researchAndSale: return .refused(.incompatibleHardware)
    }
  }

  public static func canStoreSparePod(currentCount: Int) -> Bool {
    (0..<maximumSparePods).contains(currentCount)
  }

  private static func validStructure(_ context: SalvageFitContext) -> Bool {
    (1...15).contains(context.stockFacingMask) && (1...15).contains(context.installedFacingMask)
      && (1...15).contains(context.retrofitFacingMask)
      && context.stockFacingMask & context.installedFacingMask == context.stockFacingMask
      && context.installedFacingMask & context.retrofitFacingMask == context.installedFacingMask
      && (0...maximumNativePylons).contains(context.stockPylons)
      && (context.stockPylons...maximumNativePylons).contains(context.installedPylons)
      && (context.stockPylons...maximumNativePylons).contains(context.structuralPylonLimit)
  }

  private static func mask(_ mount: LaserMount) -> Int {
    switch mount {
    case .front: 1
    case .rear: 2
    case .left: 4
    case .right: 8
    }
  }

  private static func item(
    _ id: String, _ category: SalvageTechnologyCategory, _ label: String,
    _ massKg: Double, _ halfExtents: Vector3, _ value: Int, _ effect: SalvageTechnologyEffect,
    provenance: SalvageProvenance = .human
  ) -> SalvageTechnologyDefinition {
    .init(
      id: id, category: category, label: label, massKg: massKg, halfExtents: halfExtents,
      baseValueTenths: value, installationCostTenths: value / 10, provenance: provenance,
      effect: effect)
  }
}
