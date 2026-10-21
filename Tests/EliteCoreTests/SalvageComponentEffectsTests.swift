import Foundation
import Testing

@testable import EliteCore

struct SalvageComponentEffectsTests {
  private let hull = UUID()

  private func inventory(_ definitionID: String, count: Int = 1) throws -> SalvageLedger {
    var ledger = SalvageLedger(seed: 123)
    var cargo = Array(repeating: 0, count: 17)
    for index in 0..<count {
      let wreck = WreckIdentity(
        system: .init(galaxy: 0, system: 7), site: UInt32(index / 64), lineage: 1)
      let section = SalvageSectionProfile(
        index: UInt16(index % 64), kind: .computer,
        localPosition: .init(0, 0, 0), normal: .init(0, 0, 1), radius: 10, workSeconds: 1,
        structural: false, technologyDefinitionIDs: [definitionID], sourceFaceIndex: 0)
      let conditions = SalvageWorkConditions(
        toolInstalled: true, inRange: true, aligned: true,
        lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true)
      _ = ledger.advance(
        wreck: wreck, section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: UInt64(index + 1),
        conditions: conditions)
      let lot = try #require(ledger.pendingLots.first)
      let collected = ledger.collect(
        lot: lot.identity, cargo: &cargo, freeTonnes: 1000,
        apertureHalfExtents: .init(100, 100, 100), hasScoops: true, approachAllowed: true,
        protection: .init())
      #expect(collected == .collected(lot))
    }
    return ledger
  }

  private func binding(
    _ component: ComponentInstance, axis: SalvageUpgradeAxis,
    slot: ComponentFittingSlot
  ) -> SalvageTransactionBinding {
    .equipment(
      target: .hull(instance: hull), expectedComponentInstanceID: component.id,
      templateVersion: UInt32(component.origin.identity.version), axis: axis, feature: nil,
      location: .init(hullInstanceID: hull, slot: slot))
  }

  private func quote(
    _ ledger: SalvageLedger, lot: SalvageLot, component: ComponentInstance,
    axis: SalvageUpgradeAxis, slot: ComponentFittingSlot
  ) throws -> SalvageComponentUpgradeQuote {
    try SalvageComponentEffects.quote(
      lotID: lot.identity, ledger: ledger, component: component,
      liveLocation: .init(hullInstanceID: hull, slot: slot),
      binding: binding(component, axis: axis, slot: slot))
  }

  private func apply(
    _ quote: SalvageComponentUpgradeQuote, ledger: inout SalvageLedger,
    component: ComponentInstance, axis: SalvageUpgradeAxis
  ) throws -> ComponentInstance {
    guard case .salvage(let lotID) = quote.item.identity else {
      throw SalvageComponentEffectError.unsupportedEffect
    }
    let settlement = try #require(
      ledger.prepareSettlement(
        command: UUID(), items: [lotID],
        action: .fit(axis: axis, mount: nil), binding: quote.binding))
    let result = try ComponentProgression.apply(
      quote.progression, component: component,
      item: quote.item, definition: quote.definition, inventoryRevision: ledger.revision)
    #expect(ledger.commitSettlement(settlement) == .committed(settlement))
    return result.component
  }

  @Test func axesUseAuthoritativeFamiliesTemplatesAndDeclaredUnits() throws {
    let examples:
      [(String, SalvageUpgradeAxis, ComponentAxis, ComponentFamilyDefinition, ComponentFittingSlot)] =
        [
          (
            "energy-technology", .energyCapacity, .energyCapacity, EquipmentModuleTemplates.energy,
            .energy
          ),
          (
            "energy-technology", .energyRecharge, .energyRecharge, EquipmentModuleTemplates.energy,
            .energy
          ),
          (
            "drive-technology", .jumpReach, .jumpReach, EquipmentModuleTemplates.navigation,
            .navigation
          ),
          (
            "drive-technology", .spoolDuration, .jumpSpool, EquipmentModuleTemplates.navigation,
            .navigation
          ),
          (
            "drive-technology", .jumpFuelCost, .jumpFuelCost, EquipmentModuleTemplates.navigation,
            .navigation
          ),
          (
            "shield-technology", .frontShieldCapacity, .frontShieldCapacity,
            EquipmentModuleTemplates.shield, .shield
          ),
          (
            "shield-technology", .rearShieldCapacity, .rearShieldCapacity,
            EquipmentModuleTemplates.shield, .shield
          ),
          (
            "shield-technology", .frontShieldRecharge, .frontShieldRecharge,
            EquipmentModuleTemplates.shield, .shield
          ),
          (
            "shield-technology", .rearShieldRecharge, .rearShieldRecharge,
            EquipmentModuleTemplates.shield, .shield
          ),
        ]
    for (id, axis, sharedAxis, family, slot) in examples {
      let ledger = try inventory(id)
      let lot = try #require(ledger.inventory.first)
      let component = ComponentInstance(id: UUID(), origin: family.grades[0])
      let result = try quote(ledger, lot: lot, component: component, axis: axis, slot: slot)
      guard case .technology(_, let quality, _) = lot.content else {
        Issue.record("Missing technology")
        continue
      }
      #expect(result.item.basisPoints == [sharedAxis: quality.bonusBasisPoints])
      #expect(result.item.origin == component.origin.identity)
      #expect(result.definition == family)
      #expect(result.progression.inventoryRevision == ledger.revision)
      #expect(ledger.inventory.count == 1 && component.receipts.isEmpty)
    }
  }

  @Test func energyAndNavigationPromoteBeyondFormerLifetimeCeilingWithoutResettingStatistics()
    throws
  {
    for (id, family, axis, sharedAxis, slot) in [
      (
        "energy-technology", EquipmentModuleTemplates.energy, SalvageUpgradeAxis.energyRecharge,
        ComponentAxis.energyRecharge, ComponentFittingSlot.energy
      ),
      (
        "drive-technology", EquipmentModuleTemplates.navigation, .jumpReach, .jumpReach, .navigation
      ),
    ] {
      var ledger = try inventory(id, count: 100)
      var component = ComponentInstance(id: UUID(), origin: family.grades[0])
      let original = component.origin
      var crossedOldCap = false
      var terminalRefused = false
      for lot in ledger.inventory {
        do {
          let result = try quote(ledger, lot: lot, component: component, axis: axis, slot: slot)
          let previous = component.statistics[sharedAxis]!
          component = try apply(result, ledger: &ledger, component: component, axis: axis)
          #expect(component.statistics[sharedAxis]! >= previous)
          #expect(component.origin == original)
          if component.statistics[sharedAxis]! > original.statistics[sharedAxis]! * 1.3 {
            crossedOldCap = true
          }
        } catch ComponentProgressionError.noEffectiveChange {
          terminalRefused = true
          break
        }
      }
      #expect(crossedOldCap && terminalRefused)
      #expect(component.grade == family.grades.last?.identity)
      #expect(component.statistics[sharedAxis] == family.terminalLimits[sharedAxis])
      #expect(!ledger.inventory.isEmpty)
      #expect(
        try JSONDecoder().decode(ComponentInstance.self, from: JSONEncoder().encode(component))
          == component)
    }
  }

  @Test func legacyMiningShieldOriginPreservesExcessAndPromotesOnlyWithBothCapacities() throws {
    let mapping = try #require(
      EquipmentModuleTemplates.legacyMapping(
        family: EquipmentModuleTemplates.shieldFamily, key: "Mining Shield Booster"))
    var component = ComponentInstance(id: UUID(), origin: mapping.origin, grade: mapping.grade)
    var ledger = try inventory("shield-technology", count: 40)
    let threshold = EquipmentModuleTemplates.shield.grades[5]
    for lot in ledger.inventory {
      let axis: SalvageUpgradeAxis =
        component.statistics[.frontShieldCapacity]! < threshold.statistics[.frontShieldCapacity]!
        ? .frontShieldCapacity : .rearShieldCapacity
      let result = try quote(ledger, lot: lot, component: component, axis: axis, slot: .shield)
      component = try apply(result, ledger: &ledger, component: component, axis: axis)
      if component.grade == threshold.identity { break }
    }
    #expect(component.grade == threshold.identity)
    #expect(
      component.statistics[.frontShieldCapacity]! >= threshold.statistics[.frontShieldCapacity]!)
    #expect(
      component.statistics[.rearShieldCapacity]! >= threshold.statistics[.rearShieldCapacity]!)
    #expect(component.origin == mapping.origin)
    #expect(
      component.statistics[.frontShieldCapacity]! > mapping.origin.statistics[.frontShieldCapacity]!
        * 1.3)
  }

  @Test func quotePinsStoredItemCompleteOriginInstanceLocationAndInventoryRevision() throws {
    var ledger = try inventory("energy-technology")
    let lot = try #require(ledger.inventory.first)
    let component = ComponentInstance(id: UUID(), origin: EquipmentModuleTemplates.energy.grades[0])
    let pinned = binding(component, axis: .energyRecharge, slot: .energy)
    let location = ComponentFittingLocation(hullInstanceID: hull, slot: .energy)
    #expect(throws: SalvageComponentEffectError.missingComponent) {
      try SalvageComponentEffects.quote(
        lotID: lot.identity, ledger: ledger,
        component: nil, liveLocation: location, binding: pinned)
    }
    #expect(throws: SalvageComponentEffectError.locationMismatch) {
      try SalvageComponentEffects.quote(
        lotID: lot.identity, ledger: ledger,
        component: component, liveLocation: .init(hullInstanceID: UUID(), slot: .energy),
        binding: pinned)
    }
    let fakeOrigin = ComponentTemplate(
      identity: .init(
        family: component.family,
        id: "energy.unrecognized", version: component.origin.identity.version), order: 0,
      statistics: component.origin.statistics, requiredAxes: component.origin.requiredAxes)
    let fake = ComponentInstance(id: component.id, origin: fakeOrigin)
    #expect(throws: ComponentProgressionError.originMismatch) {
      try SalvageComponentEffects.quote(
        lotID: lot.identity, ledger: ledger,
        component: fake, liveLocation: location, binding: pinned)
    }
    let result = try quote(
      ledger, lot: lot, component: component, axis: .energyRecharge, slot: .energy)
    var changedStats = component.statistics
    changedStats[.energyCapacity] = 1.01
    let changed = ComponentInstance(
      id: component.id, origin: component.origin, statistics: changedStats)
    #expect(throws: ComponentProgressionError.staleQuote) {
      try ComponentProgression.apply(
        result.progression, component: changed,
        item: result.item, definition: result.definition, inventoryRevision: ledger.revision)
    }
    #expect(throws: ComponentProgressionError.inventoryChanged) {
      try ComponentProgression.apply(
        result.progression, component: component,
        item: result.item, definition: result.definition, inventoryRevision: ledger.revision + 1)
    }
    _ = try apply(result, ledger: &ledger, component: component, axis: .energyRecharge)
    #expect(throws: SalvageComponentEffectError.missingStoredItem) {
      try SalvageComponentEffects.quote(
        lotID: lot.identity, ledger: ledger,
        component: ComponentInstance(id: UUID(), origin: component.origin), liveLocation: location,
        binding: pinned)
    }
  }
  @Test func commanderResearchCannotAuthorizeAnInstalledPhysicalUpgrade() throws {
    let ledger = try inventory("energy-technology")
    let lot = try #require(ledger.inventory.first)
    let component = ComponentInstance(id: UUID(), origin: EquipmentModuleTemplates.energy.grades[0])
    let location = ComponentFittingLocation(hullInstanceID: hull, slot: .energy)
    let malformed = SalvageTransactionBinding.equipment(
      target: .commanderResearch,
      expectedComponentInstanceID: component.id, templateVersion: 1, axis: .energyRecharge,
      feature: nil, location: location)
    #expect(throws: SalvageComponentEffectError.invalidBinding) {
      try SalvageComponentEffects.quote(
        lotID: lot.identity, ledger: ledger,
        component: component, liveLocation: location, binding: malformed)
    }
    #expect(ledger.inventory.count == 1 && component.receipts.isEmpty)
  }

  @Test func rolledMetadataMustRetainExactSerialDefinitionConditionQualityAndAxis() {
    let identity = SalvageLotIdentity(
      section: .init(
        wreck: .init(
          system: .init(galaxy: 0, system: 7),
          site: 1, lineage: 1), section: 0), lot: 0)
    func lot(
      serial: UInt16 = 0, definition: String = "energy-technology", condition: Int = 100,
      quality: SalvageQuality = .i, axis: SalvageUpgradeAxis = .energyRecharge
    ) -> SalvageLot {
      let fixed = SalvageLootItem(
        identity: .init(section: identity.section, lot: serial),
        content: .technology(
          definitionID: definition, quality: quality, conditionPercent: condition, axis: axis),
        effect: .scalar(axes: [axis]), bonusBasisPoints: quality.bonusBasisPoints,
        massKg: 8, halfExtents: .init(2, 2, 2), provenance: .human, saleValueTenths: 12000,
        legality: .init(
          commodityIllegal: false, sourceLegalValue: 0, ownership: .abandoned,
          stolenProvenance: false), requiresChunking: false)
      return .init(
        identity: identity,
        content: .technology(
          definitionID: "energy-technology",
          quality: .i, conditionPercent: 100), position: .init(0, 0, 0), velocity: .init(0, 0, 0),
        halfExtents: .init(2, 2, 2), massKg: 8, loot: fixed)
    }
    #expect(SalvageComponentEffects.hasCoherentFixedEffect(lot(), axis: .energyRecharge))
    #expect(!SalvageComponentEffects.hasCoherentFixedEffect(lot(serial: 1), axis: .energyRecharge))
    #expect(
      !SalvageComponentEffects.hasCoherentFixedEffect(
        lot(definition: "shield-technology"), axis: .energyRecharge))
    #expect(
      !SalvageComponentEffects.hasCoherentFixedEffect(lot(condition: 90), axis: .energyRecharge))
    #expect(
      !SalvageComponentEffects.hasCoherentFixedEffect(lot(quality: .ii), axis: .energyRecharge))
    #expect(
      !SalvageComponentEffects.hasCoherentFixedEffect(
        lot(axis: .energyCapacity), axis: .energyRecharge))
    let legacy = SalvageLot(
      identity: identity, content: lot().content, position: .init(0, 0, 0),
      velocity: .init(0, 0, 0), halfExtents: .init(2, 2, 2), massKg: 8)
    #expect(SalvageComponentEffects.hasCoherentFixedEffect(legacy, axis: .energyRecharge))
  }

  @Test func actualRolledEnergyItemQuotesOnlyItsPersistedSelectedAxis() throws {
    let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 1, lineage: 1)
    let sectionID = WreckSectionIdentity(wreck: wreck, section: 0)
    let source = SalvageLootSource(
      roles: [.weaponsPlatform], legalValue: 0, economy: 3,
      technology: 12, ownership: .abandoned, manifest: nil)
    let seed = try #require(
      (0..<10000).first { value in
        SalvageLootProfiles.plan(section: sectionID, seed: UInt64(value), source: source).items
          .contains {
            if case .technology(let id, _, _, _) = $0.content { return id == "energy-technology" }
            return false
          }
      })
    var ledger = SalvageLedger(seed: UInt64(seed))
    let section = SalvageSectionProfile(
      index: 0, kind: .computer, localPosition: .init(0, 0, 0),
      normal: .init(0, 0, 1), radius: 10, workSeconds: 1, structural: false,
      technologyDefinitionIDs: [], sourceFaceIndex: 0)
    let conditions = SalvageWorkConditions(
      toolInstalled: true, inRange: true, aligned: true,
      lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true)
    _ = ledger.advance(
      wreck: wreck, section: section, pose: .init(), velocity: .init(0, 0, 0),
      angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: 1,
      conditions: conditions, source: source)
    let lot = try #require(ledger.pendingLots.first)
    let fixed = try #require(lot.loot)
    guard case .technology(_, _, _, let selected) = fixed.content, let selected else {
      Issue.record("Rolled energy item lost its selected axis")
      return
    }
    var cargo = Array(repeating: 0, count: 17)
    _ = ledger.collect(
      lot: lot.identity, cargo: &cargo, freeTonnes: 10,
      apertureHalfExtents: .init(10, 10, 10), hasScoops: true, approachAllowed: true,
      protection: .init())
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    let component = ComponentInstance(id: UUID(), origin: EquipmentModuleTemplates.energy.grades[0])
    let result = try quote(ledger, lot: lot, component: component, axis: selected, slot: .energy)
    #expect(result.item.identity == .salvage(lot.identity))
    let other: SalvageUpgradeAxis = selected == .energyRecharge ? .energyCapacity : .energyRecharge
    #expect(throws: SalvageComponentEffectError.unsupportedEffect) {
      try quote(ledger, lot: lot, component: component, axis: other, slot: .energy)
    }
  }

}
