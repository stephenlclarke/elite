import Foundation
import Testing

@testable import EliteCore

private let alienProducerSection = WreckSectionIdentity(
  wreck: .init(system: .init(galaxy: 0, system: 7), site: 1, lineage: 123), section: 1)
private func alienProducerSource(_ roles: Set<SalvageSourceRole>) -> SalvageLootSource {
  .init(roles: roles, legalValue: 0, economy: 3, technology: 12, ownership: .abandoned)
}
private func producedLot(_ item: SalvageLootItem) throws -> SalvageLot {
  guard case .technology(let id, let quality, let condition, _) = item.content else {
    throw AlienAttachmentError.invalidSource
  }
  return .init(
    identity: item.identity,
    content: .technology(definitionID: id, quality: quality, conditionPercent: condition),
    position: .init(100, 200, 300), velocity: .init(0, 0, 0),
    halfExtents: item.halfExtents, massKg: item.massKg, loot: item)
}

struct AlienModuleLootProducerTests {
  @Test func actualThargoidPlansProduceArtefactsAllFourModulesAndMatchingQualityUpgrades() throws {
    let source = alienProducerSource([.thargoid, .militaryCapital])
    var artefacts = 0
    var modules = 0
    var upgrades = 0
    var moduleTypes: Set<AlienModuleKind> = []
    var upgradeTypes: Set<AlienModuleKind> = []
    var qualities: Set<SalvageQuality> = []
    for seed in UInt64(0)..<2000 {
      let plan = SalvageLootProfiles.plan(section: alienProducerSection, seed: seed, source: source)
      #expect(
        plan == SalvageLootProfiles.plan(section: alienProducerSection, seed: seed, source: source))
      #expect(plan.profile == .thargoid && plan.bucket == .alienArtefact && plan.items.count == 1)
      let item = try #require(plan.items.first)
      #expect(
        item.identity == .init(section: alienProducerSection, lot: 0) && item.provenance == .alien)
      guard case .technology(let id, let quality, _, let axis) = item.content else {
        Issue.record("Expected a typed alien outcome")
        return
      }
      if id == "alien-artefact" {
        artefacts += 1
        #expect(axis == nil && item.effect == .researchAndSale && item.bonusBasisPoints == 0)
      } else if let kind = AlienModuleKind.allCases.first(where: { $0.definitionID == id }) {
        modules += 1
        moduleTypes.insert(kind)
        try AlienModuleDefinition.validatePlanned(item)
        #expect(try AlienModuleDefinition.kind(for: producedLot(item)) == kind)
        #expect(
          axis == nil && item.bonusBasisPoints == 1000 && item.effect == .scalar(axes: kind.axes))
      } else if let kind = AlienModuleKind.allCases.first(where: { $0.upgradeDefinitionID == id }) {
        upgrades += 1
        upgradeTypes.insert(kind)
        qualities.insert(quality)
        try AlienModuleDefinition.validatePlanned(item)
        #expect(
          try AlienModuleDefinition.upgradeBonus(for: producedLot(item), kind: kind)
            == quality.bonusBasisPoints)
        #expect(axis.map { kind.axes.contains($0) } == true)
      } else {
        Issue.record("Unexpected alien definition")
      }
      if seed < 20 {
        #expect(
          try JSONDecoder().decode(SalvageLootPlan.self, from: JSONEncoder().encode(plan)) == plan)
      }
    }
    #expect(
      (800...1200).contains(artefacts) && (350...650).contains(modules)
        && (350...650).contains(upgrades))
    #expect(
      moduleTypes == Set(AlienModuleKind.allCases) && upgradeTypes == Set(AlienModuleKind.allCases))
    #expect(qualities == Set(SalvageQuality.allCases))
  }

  @Test func plannedTypedValidatorRejectsHumanProvenanceAndOutOfContractSections() throws {
    let source = alienProducerSource([.thargoid])
    let item = try #require(
      (UInt64(0)..<500).lazy.flatMap {
        SalvageLootProfiles.plan(section: alienProducerSection, seed: $0, source: source).items
      }.first {
        if case .technology(let id, _, _, _) = $0.content {
          AlienModuleDefinition.isAttachmentDefinition(id)
        } else {
          false
        }
      })
    try AlienModuleDefinition.validatePlanned(item)
    let identity = SalvageLotIdentity(
      section: .init(wreck: item.identity.section.wreck, section: 64), lot: item.identity.lot)
    for human in [false, true] {
      let invalid = SalvageLootItem(
        identity: human ? item.identity : identity, content: item.content,
        effect: item.effect, bonusBasisPoints: item.bonusBasisPoints, massKg: item.massKg,
        halfExtents: item.halfExtents, provenance: human ? .human : .alien,
        saleValueTenths: item.saleValueTenths, legality: item.legality,
        requiresChunking: item.requiresChunking)
      #expect(throws: AlienAttachmentError.invalidSource) {
        try AlienModuleDefinition.validatePlanned(invalid)
      }
    }
    #expect(!AlienModuleDefinition.isAttachmentDefinition("alien-artefact"))
    #expect(!AlienModuleDefinition.isAttachmentDefinition("energy-technology"))
  }

  @Test func humanSourceProfilesNeverGenerateAlienAttachmentsOrTheirUpgrades() {
    for role in SalvageSourceRole.allCases where role != .thargoid {
      for seed in UInt64(0)..<200 {
        let plan = SalvageLootProfiles.plan(
          section: alienProducerSection, seed: seed, source: alienProducerSource([role]))
        for item in plan.items {
          if case .technology(let id, _, _, _) = item.content {
            #expect(
              !AlienModuleKind.allCases.contains {
                $0.definitionID == id || $0.upgradeDefinitionID == id
              })
          }
        }
      }
    }
  }

  @Test func definitionsDeclareBalanceAndRefuseGenericCappedScalarFitting() throws {
    let context = SalvageFitContext(
      stockFacingMask: 1, installedFacingMask: 1, retrofitFacingMask: 0,
      stockPylons: 1, installedPylons: 1, structuralPylonLimit: 8, storedEmptyPods: 0,
      fittedLasers: [:], loadedMissiles: 0)
    for kind in AlienModuleKind.allCases {
      for upgrade in [false, true] {
        let id = upgrade ? kind.upgradeDefinitionID : kind.definitionID
        let definition = try #require(SalvageDefinitions.definition(id: id))
        #expect(
          definition.provenance == .alien && definition.massKg == 8
            && definition.halfExtents == .init(2, 2, 2))
        #expect(definition.baseValueTenths == (upgrade ? 25000 : 50000))
        #expect(definition.installationCostTenths == (upgrade ? 2500 : 5000))
        #expect(
          SalvageDefinitions.compatibility(
            definition: definition, action: .fit(axis: kind.axes[0], mount: nil), context: context)
            == .refused(.incompatibleHardware))
        #expect(
          SalvageDefinitions.compatibility(definition: definition, action: .sell, context: context)
            == .permitted)
      }
    }
    #expect(SalvageDefinitions.definition(id: "alien-artefact")?.effect == .researchAndSale)
  }

  @Test func retainedAlienPlanUsesOriginalSourceAndSurvivesLedgerReloadWithoutReroll() throws {
    let source = alienProducerSource([.thargoid])
    let profile = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(10, 0, 0),
      normal: .init(0, 0, 1), radius: 10, workSeconds: 1, structural: false,
      technologyDefinitionIDs: [], sourceFaceIndex: 0)
    for target in [
      "alien-artefact", AlienModuleKind.energyCapacity.definitionID,
      AlienModuleKind.shieldCapacity.upgradeDefinitionID,
    ] {
      let seed = try #require(
        (UInt64(0)..<500).first { seed in
          let plan = SalvageLootProfiles.plan(
            section: alienProducerSection, seed: seed, source: source)
          return plan.items.contains {
            if case .technology(let id, _, _, _) = $0.content { id == target } else { false }
          }
        })
      var ledger = SalvageLedger(seed: seed)
      let original = try #require(
        ledger.inspectLoot(wreck: alienProducerSection.wreck, section: profile, source: source))
      let revision = ledger.revision
      #expect(
        ledger.inspectLoot(
          wreck: alienProducerSection.wreck, section: profile,
          source: alienProducerSource([.generalShip])) == original)
      #expect(ledger.revision == revision)
      ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
      #expect(
        ledger.inspectLoot(wreck: alienProducerSection.wreck, section: profile, source: source)
          == original)
    }
  }
}
