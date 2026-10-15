import Foundation
import Testing

@testable import EliteCore

struct SalvageDefinitionsTests {
  private func context() -> SalvageFitContext {
    .init(
      stockFacingMask: 1, installedFacingMask: 1, retrofitFacingMask: 15,
      stockPylons: 4, installedPylons: 4, structuralPylonLimit: 8, storedEmptyPods: 1,
      fittedLasers: [.front: .naval])
  }

  @Test func catalogueCoversAllCategoriesWithStablePhysicalAndEconomicData() throws {
    #expect(Set(SalvageDefinitions.all.map(\.category)) == Set(SalvageTechnologyCategory.allCases))
    #expect(Set(SalvageDefinitions.all.map(\.id)).count == SalvageDefinitions.all.count)
    for item in SalvageDefinitions.all {
      #expect(SalvageDefinitions.definition(id: item.id) == item)
      #expect(item.massKg > 0 && item.massKg.isFinite)
      #expect(item.halfExtents.x > 0 && item.halfExtents.y > 0 && item.halfExtents.z > 0)
      #expect(item.installationCostTenths == item.baseValueTenths / 10)
      #expect(
        try JSONDecoder().decode(
          SalvageTechnologyDefinition.self,
          from: JSONEncoder().encode(item)) == item)
      #expect(
        SalvageDefinitions.saleValue(definition: item, conditionPercent: 100)
          == item.baseValueTenths)
      #expect(SalvageDefinitions.saleValue(definition: item, conditionPercent: 0) == 0)
      #expect(SalvageDefinitions.saleValue(definition: item, conditionPercent: -1) == 0)
      #expect(SalvageDefinitions.saleValue(definition: item, conditionPercent: 101) == 0)
    }
    #expect(SalvageDefinitions.definition(id: "unknown") == nil)
  }

  @Test func effectsUseBaseAdditiveCapsAndNavigationLimit() {
    #expect(SalvageQuality.allCases.map(\.bonusBasisPoints) == [500, 1000, 1500])
    for axis in SalvageUpgradeAxis.allCases {
      let expected = axis.reducesBaseline ? 70.0 : 130.0
      #expect(
        abs(
          SalvageDefinitions.effective(
            base: 100, axis: axis,
            bonusesBasisPoints: [1500, 1500, Int.max]) - expected) < 0.00001)
      #expect(
        SalvageDefinitions.effective(base: 100, axis: axis, bonusesBasisPoints: [-1000]) == 100)
      #expect(
        SalvageDefinitions.effective(base: .infinity, axis: axis, bonusesBasisPoints: []) == 0)
      #expect(SalvageDefinitions.effective(base: -1, axis: axis, bonusesBasisPoints: []) == 0)
    }
    #expect(
      SalvageDefinitions.effectiveJumpReach(base: 7, bonusesBasisPoints: [3000], navigationCap: 7)
        == 7)
    #expect(
      SalvageDefinitions.effectiveJumpReach(base: 14, bonusesBasisPoints: [3000], navigationCap: 14)
        == 14)
    #expect(
      SalvageDefinitions.effectiveJumpReach(base: 21, bonusesBasisPoints: [3000], navigationCap: 21)
        == 21)
    #expect(
      SalvageDefinitions.effectiveJumpReach(base: 7, bonusesBasisPoints: [3000], navigationCap: 0)
        == 0)
  }

  @Test func scalarFitsRequireOneValidAxisAndRealLaser() throws {
    for item in SalvageDefinitions.all {
      guard case .scalar(let axes) = item.effect else { continue }
      for axis in axes {
        #expect(
          SalvageDefinitions.compatibility(
            definition: item,
            action: .fit(axis: axis, mount: .front), context: context()) == .permitted)
      }
      #expect(
        SalvageDefinitions.compatibility(
          definition: item,
          action: .fit(axis: nil, mount: .front), context: context()) == .refused(.unsupportedAxis))
    }
    let laser = try #require(SalvageDefinitions.definition(id: "laser-technology"))
    #expect(
      SalvageDefinitions.compatibility(
        definition: laser,
        action: .fit(axis: .laserDamage, mount: .rear), context: context())
        == .refused(.missingLaser))
    #expect(
      SalvageDefinitions.compatibility(
        definition: laser,
        action: .fit(axis: .maximumSpeed, mount: .front), context: context())
        == .refused(.unsupportedAxis))
  }

  @Test func structuralGrantsCannotCreateFifthFacingOrUnlimitedPylons() throws {
    let hardpoint = try #require(SalvageDefinitions.definition(id: "laser-hardpoint"))
    var fit = context()
    #expect(
      SalvageDefinitions.compatibility(
        definition: hardpoint,
        action: .fit(axis: nil, mount: .rear), context: fit) == .permitted)
    fit.installedFacingMask = 15
    for mount in LaserMount.allCases {
      #expect(
        SalvageDefinitions.compatibility(
          definition: hardpoint,
          action: .fit(axis: nil, mount: mount), context: fit) == .refused(.noFacingAvailable))
    }
    fit.retrofitFacingMask = 31
    #expect(
      SalvageDefinitions.compatibility(
        definition: hardpoint,
        action: .fit(axis: nil, mount: .rear), context: fit) == .refused(.invalidStructure))
    let pylon = try #require(SalvageDefinitions.definition(id: "missile-pylon"))
    fit = context()
    fit.installedPylons = 5
    #expect(
      SalvageDefinitions.compatibility(
        definition: pylon,
        action: .fit(axis: nil, mount: nil), context: fit) == .permitted)
    fit.installedPylons = 6
    #expect(
      SalvageDefinitions.compatibility(
        definition: pylon,
        action: .fit(axis: nil, mount: nil), context: fit) == .refused(.pylonLimit))
    fit.stockPylons = 7
    fit.installedPylons = 8
    #expect(
      SalvageDefinitions.compatibility(
        definition: pylon,
        action: .fit(axis: nil, mount: nil), context: fit) == .refused(.pylonLimit))
  }

  @Test func missilesPodsAndAlienResearchHaveFiniteEligibility() throws {
    #expect(SalvageMissileVariant.guided.turningMultiplier == 1.25)
    #expect(SalvageMissileVariant.heavy.damageMultiplier == 1.5)
    #expect(SalvageMissileVariant.heavy.speedMultiplier == 0.8)
    for variant in SalvageMissileVariant.allCases {
      #expect(variant.ecmSurvivalCharges == (variant == .ecmResistant ? 1 : 0))
      #expect(
        variant.rangeMultiplier == 1 && variant.blastMultiplier == 1 && variant.heatMultiplier == 1)
    }
    let missile = try #require(SalvageDefinitions.definition(id: "missile-standard"))
    var fit = context()
    #expect(
      SalvageDefinitions.compatibility(
        definition: missile,
        action: .fit(axis: nil, mount: nil), context: fit) == .permitted)
    fit.loadedMissiles = 4
    #expect(
      SalvageDefinitions.compatibility(
        definition: missile,
        action: .fit(axis: nil, mount: nil), context: fit) == .refused(.pylonLimit))
    let pod = try #require(SalvageDefinitions.definition(id: "spare-escape-pod"))
    #expect(
      SalvageDefinitions.compatibility(
        definition: pod,
        action: .fit(axis: nil, mount: nil), context: fit) == .permitted)
    fit.fittedEscapePod = true
    #expect(
      SalvageDefinitions.compatibility(
        definition: pod,
        action: .fit(axis: nil, mount: nil), context: fit) == .refused(.sparePodLimit))
    #expect(SalvageDefinitions.canStoreSparePod(currentCount: 1))
    #expect(!SalvageDefinitions.canStoreSparePod(currentCount: 2))
    #expect(!SalvageDefinitions.canStoreSparePod(currentCount: -1))
    let alien = try #require(SalvageDefinitions.definition(id: "alien-artefact"))
    #expect(
      SalvageDefinitions.compatibility(
        definition: alien,
        action: .research, context: fit) == .refused(.incompatibleHardware))
    #expect(
      SalvageDefinitions.compatibility(
        definition: alien,
        action: .sell, context: fit) == .permitted)
    fit.hasCompatibleAlienHardware = true
    #expect(
      SalvageDefinitions.compatibility(
        definition: alien,
        action: .research, context: fit) == .permitted)
    #expect(
      SalvageDefinitions.compatibility(
        definition: alien,
        action: .fit(axis: nil, mount: nil), context: fit) == .refused(.incompatibleHardware))
    let computer = try #require(SalvageDefinitions.definition(id: "computer-core"))
    #expect(
      SalvageDefinitions.compatibility(
        definition: computer,
        action: .research, context: fit) == .refused(.researchUnavailable))
    fit.computerResearchAvailable = true
    #expect(
      SalvageDefinitions.compatibility(
        definition: computer,
        action: .research, context: fit) == .permitted)
  }
  @Test func researchRecipesUpgradeExactlyOneExistingTier() {
    #expect(Set(SalvageDefinitions.researchRecipes.map(\.id)).count == 10)
    for recipe in SalvageDefinitions.researchRecipes {
      #expect(SalvageDefinitions.definition(id: recipe.requiredDefinitionID) != nil)
      #expect(recipe.requiredCount > 0 && recipe.serviceCostTenths > 0)
      switch recipe.destination {
      case .navigation(let tier):
        #expect(recipe.priorTier == tier.rawValue - 1)
        #expect(recipe.serviceCostTenths == tier.price / 2)
        #expect(recipe.requiredCount == 2)
      case .targeting(let tier):
        #expect(recipe.priorTier == tier.rawValue - 1)
        #expect(recipe.serviceCostTenths == tier.price / 2)
        #expect(recipe.requiredCount == 2)
      case .alienPrecision(let axis):
        #expect(
          [SalvageUpgradeAxis.scanningRange, .acquisitionError, .automationError].contains(axis))
        #expect(recipe.requiresCompatibleAlienHardware)
        #expect(recipe.requiredDefinitionID == "alien-artefact")
      }
    }
  }

}
