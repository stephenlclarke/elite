import Foundation
import Testing

@testable import EliteCore

private func alienFitContext(
  hull: UUID, facings: Int = 15, stockPylons: Int = 4, pylons: Int = 4,
  structuralPylons: Int = 8, occupiedPylons: Set<Int> = [], hasShield: Bool = true,
  occupiedRechargeAxes: Set<SalvageUpgradeAxis> = [], lasers: [LaserMount: LaserKind] = [:],
  replacementStorage: Bool = false
) -> SalvageAlienFitContext {
  .init(
    hull: hull,
    hardware: .init(
      stockFacingMask: facings, installedFacingMask: facings, retrofitFacingMask: 0,
      stockPylons: stockPylons, installedPylons: pylons,
      structuralPylonLimit: structuralPylons, storedEmptyPods: 0,
      fittedLasers: lasers, loadedMissiles: occupiedPylons.count),
    hasBasicShield: hasShield, occupiedRechargeAxes: occupiedRechargeAxes,
    occupiedPylons: occupiedPylons, replacementStorageAvailable: replacementStorage)
}

@Test func alienRecipesHaveFiniteCanonicalInputsAndFrozenCombatTuning() {
  #expect(Set(SalvageAlienDefinitions.all.map(\.id)).count == 3)
  let shield = SalvageAlienDefinitions.recipe(.shieldRegenerator)
  let plasma = SalvageAlienDefinitions.recipe(.plasmaEmitter)
  let missile = SalvageAlienDefinitions.recipe(.seekerMissile)
  #expect([shield, plasma, missile].map(\.requiredArtefactCount) == [1, 2, 1])
  #expect([shield, plasma, missile].map(\.serviceCostTenths) == [50000, 100000, 15000])
  #expect([shield, plasma, missile].allSatisfy {
    $0.requiredDefinitionID == "alien-artefact" && $0.outputQuantity == 1
  })
  guard case .plasmaEmitter(let p) = plasma.output,
    case .seekerMissile(let m) = missile.output
  else { Issue.record("Recipe outputs must retain their typed weapon identity"); return }
  #expect(p.attackKind == .plasma && p.damage == 40 && p.energyCost == 12 && p.heatCost == 8)
  #expect(p.cooldownSeconds == 1 && p.speedNativePerSecond == 600)
  #expect(p.inheritsLauncherVelocity && !p.rangeIncludesLauncherMotion && !p.usesUtilitySlot)
  #expect(p.rangeNative == p.speedNativePerSecond * p.lifetimeSeconds)
  #expect(m.attackKind == .missile && m.damage == 160 && m.speedNativePerSecond == 990)
  #expect(m.turnRadiansPerSecond == 3 && m.rangeNative == 6000 && m.lifetimeSeconds == 24)
  #expect(m.ecmSurvivalCharges == 1 && m.ammoPerOutput == 1)
  #expect(p.maximumSharedProjectiles == 32 && m.maximumSharedProjectiles == 32)
}

@Test func alienRegeneratorOnlyChangesRechargeAgainstImmutableBaseWithExistingCaps() {
  let recipe = SalvageAlienDefinitions.recipe(.shieldRegenerator)
  guard case .shieldRegenerator(let spec) = recipe.output else {
    Issue.record("Expected recharge module"); return
  }
  #expect(spec.slot == .recharge && spec.maximumBonusBasisPoints == 3000)
  #expect(!spec.changesCapacity && !spec.grantsImmediateCharge)
  for quality in SalvageQuality.allCases {
    let expected = 1 + Double(quality.bonusBasisPoints) / 10000
    #expect(abs(spec.effectiveRecharge(base: 1, quality: quality) - expected) < 1e-12)
  }
  #expect(spec.effectiveRecharge(base: 1, quality: .iii, existingBonusesBasisPoints: [1500, 1500]) == 1.3)
  #expect(spec.effectiveRecharge(base: .nan, quality: .iii) == 0)
  #expect(spec.effectiveRecharge(base: -1, quality: .i) == 0)
}

@Test func alienWorkshopUsesActualSecretSystemIdentityInEveryGalaxy() {
  for galaxy in 0..<8 {
    let system = SystemIdentity(galaxy: galaxy, system: 256)
    #expect(SalvageAlienDefinitions.workshopAvailable(
      system: system, docked: true, atMainStation: true, discoveredPlugh: true))
    #expect(!SalvageAlienDefinitions.workshopAvailable(
      system: system, docked: false, atMainStation: true, discoveredPlugh: true))
    #expect(!SalvageAlienDefinitions.workshopAvailable(
      system: system, docked: true, atMainStation: false, discoveredPlugh: true))
    #expect(!SalvageAlienDefinitions.workshopAvailable(
      system: system, docked: true, atMainStation: true, discoveredPlugh: false))
  }
  for system in [SystemIdentity(galaxy: 0, system: 7), .init(galaxy: 8, system: 256)] {
    #expect(!SalvageAlienDefinitions.workshopAvailable(
      system: system, docked: true, atMainStation: true, discoveredPlugh: true))
  }
}

@Test func alienPlasmaUsesOnlySupportedExistingCombatFacingsAndPreservesUtilitySeparation() {
  let hull = UUID()
  let recipe = SalvageAlienDefinitions.recipe(.plasmaEmitter)
  for (mount, bit) in [(LaserMount.front, 1), (.rear, 2), (.left, 4), (.right, 8)] {
    let target = SalvageAlienFittingTarget.combatMount(hull: hull, mount: mount)
    #expect(SalvageAlienDefinitions.compatibility(
      recipe: recipe, target: target, context: alienFitContext(hull: hull, facings: bit)) == .permitted)
    #expect(SalvageAlienDefinitions.compatibility(
      recipe: recipe, target: target, context: alienFitContext(hull: hull, facings: 15 ^ bit))
      == .refused(.unsupportedFacing))
    #expect(SalvageAlienDefinitions.compatibility(
      recipe: recipe, target: target,
      context: alienFitContext(hull: hull, lasers: [mount: .naval]))
      == .refused(.replacementStorageRequired))
  }
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .combatMount(hull: UUID(), mount: .front),
    context: alienFitContext(hull: hull)) == .refused(.wrongHull))
}

@Test func alienSeekerUsesOneVacantPylonWithoutReducingStockCapacityOrDuplicatingAmmo() {
  let hull = UUID()
  let recipe = SalvageAlienDefinitions.recipe(.seekerMissile)
  let context = alienFitContext(
    hull: hull, stockPylons: 32, pylons: 32, structuralPylons: 8, occupiedPylons: Set(0..<31))
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .missilePylon(hull: hull, index: 31), context: context) == .permitted)
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .missilePylon(hull: hull, index: 0), context: context)
    == .refused(.occupiedPylon))
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .missilePylon(hull: hull, index: 32), context: context)
    == .refused(.pylonLimit))
  let invalid = alienFitContext(hull: hull, occupiedPylons: [4])
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .missilePylon(hull: hull, index: 0), context: invalid)
    == .refused(.invalidStructure))
}

@Test func alienShieldCompatibilityRejectsCapacityAxisAndUnsafeReplacement() {
  let hull = UUID()
  let recipe = SalvageAlienDefinitions.recipe(.shieldRegenerator)
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .shield(hull: hull, axis: .frontShieldCapacity),
    context: alienFitContext(hull: hull)) == .refused(.incompatibleTarget))
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .shield(hull: hull, axis: .rearShieldRecharge),
    context: alienFitContext(hull: hull, hasShield: false)) == .refused(.missingBasicShield))
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .shield(hull: hull, axis: .frontShieldRecharge),
    context: alienFitContext(hull: hull, occupiedRechargeAxes: [.frontShieldRecharge]))
    == .refused(.replacementStorageRequired))
  #expect(SalvageAlienDefinitions.compatibility(
    recipe: recipe, target: .shield(hull: hull, axis: .frontShieldRecharge),
    context: alienFitContext(
      hull: hull, occupiedRechargeAxes: [.frontShieldRecharge], replacementStorage: true)) == .permitted)
}

@Test func alienFittingTargetRoundTripRetainsPhysicalHullAndExactSlot() throws {
  let hull = UUID()
  let targets: [SalvageAlienFittingTarget] = [
    .shield(hull: hull, axis: .rearShieldRecharge),
    .combatMount(hull: hull, mount: .left), .missilePylon(hull: hull, index: 31),
  ]
  for target in targets {
    let data = try JSONEncoder().encode(target)
    let decoded = try JSONDecoder().decode(SalvageAlienFittingTarget.self, from: data)
    #expect(decoded == target && decoded.hull == hull)
  }
}
