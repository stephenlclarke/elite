import Foundation
import Testing

@testable import L337Core

@Suite struct SalvageLootProfilesTests {
  private func source(
    _ roles: Set<SalvageSourceRole>, legal: Int = 0, manifest: [CommodityAmount]? = nil
  ) -> SalvageLootSource {
    .init(
      roles: roles, legalValue: legal, economy: 3, technology: 12,
      ownership: .abandoned, manifest: manifest)
  }
  private func section(_ index: UInt16 = 0) -> WreckSectionIdentity {
    .init(wreck: .init(system: .init(galaxy: 0, system: 7), site: 1, lineage: 123), section: index)
  }

  @Test func exactTablesSumToOneHundredAndMostSpecificRoleWins() {
    let expected: [SalvageLootProfile: [Int]] = [
      .drugFactory: [70, 20, 10], .weaponsPlatform: [60, 30, 10], .station: [85, 15],
      .asteroid: [100], .rockHermit: [90, 10], .commercial: [95, 5], .capital: [55, 25, 20],
      .thargoid: [100], .generalShip: [95, 5],
    ]
    for profile in SalvageLootProfile.allCases {
      #expect(SalvageLootProfiles.weights(for: profile).map(\.percent) == expected[profile])
      #expect(SalvageLootProfiles.weights(for: profile).reduce(0) { $0 + $1.percent } == 100)
    }
    #expect(SalvageLootProfiles.profile(roles: Set(SalvageSourceRole.allCases)) == .thargoid)
    #expect(SalvageLootProfiles.profile(roles: [.drugFactory, .station]) == .drugFactory)
    #expect(
      SalvageLootProfiles.profile(roles: [.weaponsPlatform, .militaryCapital]) == .weaponsPlatform)
    #expect(SalvageLootProfiles.profile(roles: [.rockHermit, .station, .asteroid]) == .rockHermit)
    #expect(SalvageLootProfiles.profile(roles: [.militaryCapital, .commercialCarrier]) == .capital)
    #expect(SalvageLootProfiles.profile(roles: [.commercialCarrier]) == .commercial)
    #expect(SalvageLootProfiles.profile(roles: [.generalShip]) == .generalShip)
    #expect(SalvageLootProfiles.profile(roles: [.militaryCapital, .generalShip]) == .capital)
    #expect(SalvageLootProfiles.profile(roles: []) == nil)
  }

  @Test func seededDistributionsMatchRoleBiasesWithoutGuaranteeingTechnology() {
    let sources: [(SalvageSourceRole, SalvageLootBucket, Int)] = [
      (.drugFactory, .illegalGoods, 70), (.weaponsPlatform, .weaponItem, 60),
      (.station, .cargo, 85),
      (.rockHermit, .ore, 90), (.commercialTrader, .commercialCargo, 95),
      (.militaryCapital, .shieldItem, 55), (.generalShip, .commercialCargo, 95),
    ]
    for (role, bucket, expected) in sources {
      let counts = (0..<4000).reduce(0) { count, seed in
        count
          + (SalvageLootProfiles.plan(
            section: section(), seed: UInt64(seed), source: source([role])
          ).bucket == bucket ? 1 : 0)
      }
      let percent = Double(counts) / 40
      #expect(abs(percent - Double(expected)) < 3)
      #expect(counts > 0 && counts < 4000)
    }
  }

  @Test func knownManifestIsPreservedOnceWithoutReplacementOrRandomDuplicateCargo() {
    let original: [CommodityAmount] = [
      .init(commodity: .food, quantity: 1000), .init(commodity: .gold, quantity: 7),
    ]
    for seed in 0..<100 {
      let known = source([.commercialTrader], manifest: original)
      let cargo = SalvageLootProfiles.plan(section: section(1), seed: UInt64(seed), source: known)
      let amounts = cargo.items.compactMap { item -> CommodityAmount? in
        if case .commodity(let amount) = item.content { return amount }
        return nil
      }
      #expect(
        amounts == original && cargo.originalManifest == original && cargo.manifestChunkingRequired)
      let commodityItems = cargo.items.filter {
        if case .commodity = $0.content { return true }
        return false
      }
      let allRequireChunking = commodityItems.allSatisfy { $0.requiresChunking }
      #expect(allRequireChunking)
      let elsewhere = SalvageLootProfiles.plan(
        section: section(0), seed: UInt64(seed), source: known)
      #expect(
        !elsewhere.items.contains {
          if case .commodity = $0.content { return true }
          return false
        })
      var settled = known
      settled.manifestAlreadySettled = true
      let after = SalvageLootProfiles.plan(section: section(1), seed: UInt64(seed), source: settled)
      #expect(
        !after.items.contains {
          if case .commodity = $0.content { return true }
          return false
        })
    }
  }

  @Test func knownEmptyManifestStillAllowsIndependentCapitalTechnology() {
    var technology = 0
    var emptyCargo = 0
    for seed in 0..<1000 {
      let plan = SalvageLootProfiles.plan(
        section: section(2), seed: UInt64(seed), source: source([.militaryCapital], manifest: []))
      #expect(
        !plan.items.contains {
          if case .commodity = $0.content { return true }
          return false
        })
      if plan.bucket == .shieldItem { technology += plan.items.count }
      if plan.bucket == .cargo {
        emptyCargo += 1
        #expect(plan.items.isEmpty)
      }
    }
    #expect(technology > 400 && emptyCargo > 150)
  }

  @Test func commercialLegalityUsesFiveThirtyFiveSixtyPercentWithoutMakingAllWantedCargoIllegal() {
    var rates: [Double] = []
    for legal in [0, 10, 50] {
      var illegal = 0
      var total = 0
      for seed in 0..<6000 {
        let plan = SalvageLootProfiles.plan(
          section: section(), seed: UInt64(seed), source: source([.commercialTrader], legal: legal))
        for item in plan.items {
          guard case .commodity = item.content else { continue }
          total += 1
          if item.legality.commodityIllegal { illegal += 1 }
          #expect(item.legality.sourceLegalValue == legal && !item.legality.stolenProvenance)
        }
      }
      rates.append(Double(illegal) / Double(total) * 100)
      #expect(illegal > 0 && illegal < total)
    }
    for (actual, expected) in zip(rates, [5.0, 35, 60]) { #expect(abs(actual - expected) < 3) }
  }

  @Test func itemEffectsQualityConditionIdentityAndValueAreFixedAndRoundTripIncludingEmpty() throws
  {
    var definitions: Set<String> = []
    var axes: Set<SalvageUpgradeAxis> = []
    for seed in 0..<3000 {
      let context = source([.weaponsPlatform])
      let plan = SalvageLootProfiles.plan(section: section(2), seed: UInt64(seed), source: context)
      #expect(
        plan == SalvageLootProfiles.plan(section: section(2), seed: UInt64(seed), source: context))
      for item in plan.items {
        guard case .technology(let id, let quality, let condition, let axis) = item.content else {
          continue
        }
        let definition = try #require(SalvageDefinitions.definition(id: id))
        definitions.insert(id)
        #expect((50...100).contains(condition))
        #expect(item.massKg == definition.massKg && item.halfExtents == definition.halfExtents)
        #expect(
          item.saleValueTenths
            == SalvageDefinitions.saleValue(definition: definition, conditionPercent: condition))
        #expect(item.identity.section == section(2) && !item.requiresChunking)
        if let axis {
          axes.insert(axis)
          #expect(
            item.effect == .scalar(axes: [axis])
              && item.bonusBasisPoints == quality.bonusBasisPoints)
        } else {
          #expect(item.effect == definition.effect && item.bonusBasisPoints == 0)
        }
      }
      if seed < 20 {
        #expect(
          try JSONDecoder().decode(SalvageLootPlan.self, from: JSONEncoder().encode(plan)) == plan)
      }
    }
    #expect(definitions.contains("shield-technology") && definitions.contains("missile-heavy"))
    #expect(
      definitions.contains("feature-mining-targeting")
        && definitions.contains("feature-salvage-targeting"))
    #expect(
      definitions.contains("feature-fuel-scoops") && definitions.contains("feature-ecm")
        && definitions.contains("feature-salvage-cutter"))
    #expect(
      axes.contains(.laserDamage) && axes.contains(.laserHeatCost) && axes.contains(.maximumSpeed))
    let empty = SalvageLootProfiles.plan(section: section(), seed: 1, source: source([]))
    #expect(empty.items.isEmpty && empty.emptyReason == .unsupportedSource)
    #expect(
      try JSONDecoder().decode(SalvageLootPlan.self, from: JSONEncoder().encode(empty)) == empty)
  }

  @Test func asteroidOreRemainsMiningOwnedHermitsOccasionallyUpgradeAndThargoidsOnlyYieldArtefacts()
  {
    var hermitUpgrades = 0
    for seed in 0..<1000 {
      let asteroid = SalvageLootProfiles.plan(
        section: section(), seed: UInt64(seed), source: source([.asteroid]))
      #expect(
        asteroid.bucket == .ore && asteroid.items.isEmpty
          && asteroid.emptyReason == .miningLedgerOwnsOre)
      let hermit = SalvageLootProfiles.plan(
        section: section(), seed: UInt64(seed), source: source([.rockHermit]))
      if hermit.bucket == .shipItem { hermitUpgrades += hermit.items.count }
      if hermit.bucket == .ore {
        #expect(
          hermit.items.contains {
            if case .commodity(let amount) = $0.content { return amount.commodity == .minerals }
            return false
          })
      }
      let alien = SalvageLootProfiles.plan(
        section: section(), seed: UInt64(seed), source: source([.thargoid, .militaryCapital]))
      #expect(alien.items.count == 1 && alien.bucket == .alienArtefact)
      if case .technology(let id, _, _, let axis) = alien.items.first?.content {
        let physical = AlienModuleKind.allCases.first { $0.definitionID == id }
        let upgrade = AlienModuleKind.allCases.first { $0.upgradeDefinitionID == id }
        #expect(id == "alien-artefact" || physical != nil || upgrade != nil)
        #expect(alien.items.first?.provenance == .alien)
        if id == "alien-artefact" || physical != nil { #expect(axis == nil) }
        if let upgrade { #expect(axis.map { upgrade.axes.contains($0) } == true) }
      } else {
        Issue.record(
          "Thargoid recovery must retain a typed alien outcome; PLUGH fitting remains a separate transaction"
        )
      }
    }
    #expect(hermitUpgrades > 40 && hermitUpgrades < 160)
  }
  @Test func unknownCommercialManifestDoesNotLoseSelectedCargoAcrossSupportedEconomies() {
    for economy in 0...7 {
      for legal in [0, 10, 50] {
        let snapshot = SalvageLootSource(
          roles: [.commercialTrader], legalValue: legal,
          economy: economy, technology: 12, ownership: .abandoned, manifest: nil)
        for seed in 0..<300 {
          let plan = SalvageLootProfiles.plan(
            section: section(), seed: UInt64(seed), source: snapshot)
          if plan.bucket == .commercialCargo {
            #expect(plan.emptyReason == nil)
            #expect(plan.items.count == 1)
            if case .commodity(let amount) = plan.items.first?.content {
              #expect(amount.valid)
            } else {
              Issue.record("Selected commercial cargo was silently lost")
            }
          }
        }
      }
    }
  }

  @Test func energyFindsUseExistingRoleBucketsAndPersistOneSelectedAxis() throws {
    var seen = Set<SalvageUpgradeAxis>()
    for seed in 0..<10000 {
      let snapshot = source([.weaponsPlatform])
      let plan = SalvageLootProfiles.plan(section: section(), seed: UInt64(seed), source: snapshot)
      for item in plan.items {
        guard case .technology(let id, let quality, _, let axis) = item.content,
          id == "energy-technology", let axis
        else { continue }
        #expect(plan.bucket == .otherShipUpgrade)
        #expect([SalvageUpgradeAxis.energyCapacity, .energyRecharge].contains(axis))
        #expect(
          item.effect == .scalar(axes: [axis]) && item.bonusBasisPoints == quality.bonusBasisPoints)
        #expect(item.massKg == 8 && item.halfExtents == Vector3(2, 2, 2))
        #expect(item.provenance == .human)
        #expect(
          try JSONDecoder().decode(SalvageLootPlan.self, from: JSONEncoder().encode(plan)) == plan)
        seen.insert(axis)
      }
      if seen.count == 2 { break }
    }
    #expect(seen == [.energyCapacity, .energyRecharge])
    #expect(SalvageLootProfiles.weights(for: .weaponsPlatform).map(\.percent) == [60, 30, 10])
  }

}
