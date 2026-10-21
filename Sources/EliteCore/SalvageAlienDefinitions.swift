import Foundation

public enum SalvageAlienRecipeID: String, CaseIterable, Codable, Sendable {
  case shieldRegenerator = "alien-shield-regenerator"
  case plasmaEmitter = "alien-plasma-emitter"
  case seekerMissile = "alien-seeker-missile"
}

/// Definitions describe equipment; G1 persists item/transaction identities and applies effects.
public struct SalvageAlienShieldSpec: Equatable, Sendable {
  public let slot: SalvageShieldSlot = .recharge
  public let allowedAxes: [SalvageUpgradeAxis] = [.frontShieldRecharge, .rearShieldRecharge]
  public let maximumBonusBasisPoints = SalvageShieldSlot.maximumAdditiveBonusBasisPoints
  public let changesCapacity = false
  public let grantsImmediateCharge = false

  public func effectiveRecharge(
    base: Double, quality: SalvageQuality, existingBonusesBasisPoints: [Int] = []
  ) -> Double {
    SalvageDefinitions.effective(
      base: base, axis: .frontShieldRecharge,
      bonusesBasisPoints: existingBonusesBasisPoints + [quality.bonusBasisPoints])
  }
}

/// Tuning is deliberately separate from laser enums and the runtime firing pipeline.
public struct SalvageAlienPlasmaSpec: Equatable, Sendable {
  public let attackKind: AttackKind = .plasma
  public let damage = 40.0
  public let energyCost = 12.0
  public let heatCost = 8.0
  public let cooldownSeconds = 1.0
  /// Muzzle-relative speed, in native collision-space units per physical second.
  public let speedNativePerSecond = 600.0
  public let rangeNative = 1200.0
  public let lifetimeSeconds = 2.0
  public let inheritsLauncherVelocity = true
  /// Range accounts for propulsion relative to the launcher, not inherited drift.
  public let rangeIncludesLauncherMotion = false
  public let usesUtilitySlot = false
  public let maximumSharedProjectiles = PopulationClass.projectile.maximum
}

public struct SalvageAlienMissileSpec: Equatable, Sendable {
  public let attackKind: AttackKind = .missile
  public var damage: Double { OrdnanceProfile.alienSeeker.damage }
  /// Native units/second; existing standard missile movement is 44 * 18 = 792.
  public var speedNativePerSecond: Double { OrdnanceProfile.alienSeeker.speed }
  public let turnRadiansPerSecond = 3.0
  /// Range exhaustion or lifetime expiry ends the projectile, whichever occurs first.
  public let rangeNative = 6000.0
  public let lifetimeSeconds = 24.0
  /// One distinct ECM activation, not one charge for every frame of that field.
  public let ecmSurvivalCharges = 1
  public let ammoPerOutput = 1
  public let maximumSharedProjectiles = PopulationClass.projectile.maximum
}

public enum SalvageAlienOutput: Equatable, Sendable {
  case shieldRegenerator(SalvageAlienShieldSpec)
  case plasmaEmitter(SalvageAlienPlasmaSpec)
  case seekerMissile(SalvageAlienMissileSpec)
}

public struct SalvageAlienRecipe: Equatable, Sendable {
  public let id: SalvageAlienRecipeID
  public let label: String
  public let requiredDefinitionID: String
  public let requiredArtefactCount: Int
  /// Final service cost in Commander-native tenths of a credit; no implicit discount.
  public let serviceCostTenths: Int
  public let output: SalvageAlienOutput
  public let outputQuantity: Int
}

/// Catalogue IDs never stand in for the physical hull that receives a fitting.
public enum SalvageAlienFittingTarget: Equatable, Codable, Sendable {
  case shield(hull: UUID, axis: SalvageUpgradeAxis)
  case combatMount(hull: UUID, mount: LaserMount)
  case missilePylon(hull: UUID, index: Int)

  public var hull: UUID {
    switch self {
    case .shield(let hull, _), .combatMount(let hull, _), .missilePylon(let hull, _): hull
    }
  }
}

/// G1 supplies actual installed structure, typed/legacy ammo occupancy and replacement space.
public struct SalvageAlienFitContext: Sendable {
  public let hull: UUID
  public let hardware: SalvageFitContext
  public let hasBasicShield: Bool
  public let occupiedRechargeAxes: Set<SalvageUpgradeAxis>
  public let occupiedPylons: Set<Int>
  public let replacementStorageAvailable: Bool

  public init(
    hull: UUID, hardware: SalvageFitContext, hasBasicShield: Bool,
    occupiedRechargeAxes: Set<SalvageUpgradeAxis> = [], occupiedPylons: Set<Int> = [],
    replacementStorageAvailable: Bool = false
  ) {
    self.hull = hull
    self.hardware = hardware
    self.hasBasicShield = hasBasicShield
    self.occupiedRechargeAxes = occupiedRechargeAxes
    self.occupiedPylons = occupiedPylons
    self.replacementStorageAvailable = replacementStorageAvailable
  }
}

public enum SalvageAlienFitRefusal: String, Codable, Sendable {
  case wrongHull, incompatibleTarget, missingBasicShield, unsupportedFacing
  case occupiedPylon, pylonLimit, invalidStructure, replacementStorageRequired
}

public enum SalvageAlienFitResult: Equatable, Sendable {
  case permitted
  case refused(SalvageAlienFitRefusal)
}

public enum SalvageAlienDefinitions {
  public static let all: [SalvageAlienRecipe] = [
    .init(
      id: .shieldRegenerator, label: "Alien Shield Regenerator",
      requiredDefinitionID: "alien-artefact", requiredArtefactCount: 1,
      serviceCostTenths: 50000, output: .shieldRegenerator(.init()), outputQuantity: 1),
    .init(
      id: .plasmaEmitter, label: "Alien Plasma Emitter",
      requiredDefinitionID: "alien-artefact", requiredArtefactCount: 2,
      serviceCostTenths: 100000, output: .plasmaEmitter(.init()), outputQuantity: 1),
    .init(
      id: .seekerMissile, label: "Alien Seeker Missile",
      requiredDefinitionID: "alien-artefact", requiredArtefactCount: 1,
      serviceCostTenths: 15000, output: .seekerMissile(.init()), outputQuantity: 1),
  ]

  public static func recipe(_ id: SalvageAlienRecipeID) -> SalvageAlienRecipe {
    all.first { $0.id == id }!
  }

  /// Pure service admission only; the runtime still owns the atomic transaction.
  public static func workshopAvailable(
    system: SystemIdentity, docked: Bool, atMainStation: Bool, discoveredPlugh: Bool
  ) -> Bool {
    (0..<8).contains(system.galaxy) && system.system == Plugh.systemID
      && docked && atMainStation && discoveredPlugh
  }

  /// Slot compatibility does not consume artefacts, install equipment or charge credits.
  public static func compatibility(
    recipe: SalvageAlienRecipe, target: SalvageAlienFittingTarget,
    context: SalvageAlienFitContext
  ) -> SalvageAlienFitResult {
    guard target.hull == context.hull else { return .refused(.wrongHull) }
    switch (recipe.output, target) {
    case (.shieldRegenerator(let spec), .shield(_, let axis)):
      guard spec.allowedAxes.contains(axis) else { return .refused(.incompatibleTarget) }
      guard context.hasBasicShield else { return .refused(.missingBasicShield) }
      if context.occupiedRechargeAxes.contains(axis) && !context.replacementStorageAvailable {
        return .refused(.replacementStorageRequired)
      }
      return .permitted
    case (.plasmaEmitter, .combatMount(_, let mount)):
      return combatCompatibility(mount: mount, context: context)
    case (.seekerMissile, .missilePylon(_, let index)):
      return missileCompatibility(index: index, context: context)
    default: return .refused(.incompatibleTarget)
    }
  }

  private static func combatCompatibility(
    mount: LaserMount, context: SalvageAlienFitContext
  ) -> SalvageAlienFitResult {
    let mask = context.hardware.installedFacingMask
    guard (0...15).contains(mask) else { return .refused(.invalidStructure) }
    let bit: Int
    switch mount {
    case .front: bit = 1
    case .rear: bit = 2
    case .left: bit = 4
    case .right: bit = 8
    }
    guard mask & bit != 0 else { return .refused(.unsupportedFacing) }
    if context.hardware.fittedLasers[mount] != nil && !context.replacementStorageAvailable {
      return .refused(.replacementStorageRequired)
    }
    return .permitted
  }

  private static func missileCompatibility(
    index: Int, context: SalvageAlienFitContext
  ) -> SalvageAlienFitResult {
    let hardware = context.hardware
    // Preserve valid stock hulls above the salvage retrofit cap of eight pylons.
    guard (0...32).contains(hardware.stockPylons),
      (0...32).contains(hardware.installedPylons),
      (0...32).contains(hardware.structuralPylonLimit),
      hardware.installedPylons <= max(hardware.stockPylons, hardware.structuralPylonLimit),
      (0...hardware.installedPylons).contains(hardware.loadedMissiles),
      context.occupiedPylons.count == hardware.loadedMissiles,
      context.occupiedPylons.allSatisfy({ (0..<hardware.installedPylons).contains($0) })
    else { return .refused(.invalidStructure) }
    guard (0..<hardware.installedPylons).contains(index) else { return .refused(.pylonLimit) }
    guard !context.occupiedPylons.contains(index) else { return .refused(.occupiedPylon) }
    return .permitted
  }
}
