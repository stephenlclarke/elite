import Foundation
import Testing

@testable import EliteCore

private typealias EMT = EquipmentModuleTemplates

private func moduleQuote(
  _ definition: ComponentFamilyDefinition, origin: ComponentTemplate,
  grade: ComponentTemplateVersion? = nil, statistics: ComponentStatistics? = nil,
  effects: [ComponentAxis: Int]
) throws -> ComponentUpgradeQuote {
  let component = ComponentInstance(
    id: UUID(), origin: origin, statistics: statistics, grade: grade)
  let item = ComponentUpgrade(
    identity: .service(UUID()), boundComponent: component.id,
    origin: origin.identity, basisPoints: effects)
  return try ComponentProgression.quote(
    component: component, item: item,
    definition: definition, inventoryRevision: 1)
}

@Test func equipmentModuleTemplatesHaveStableMonotonicValidatedDefinitions() throws {
  #expect(EMT.definitions.map(\.family.id) == ["shield", "navigation", "energy"])
  for definition in EMT.definitions {
    #expect(definition.revision == 1)
    #expect(Set(definition.grades.map(\.identity)).count == definition.grades.count)
    for template in definition.grades {
      #expect(template.identity.version == 1)
      #expect(template.identity.id.hasPrefix(definition.family.id + "."))
      #expect(EMT.displayName(for: template.identity) != nil)
      // A real quote exercises the progression engine's full definition validation.
      let axis = try #require(template.requiredAxes.first)
      _ = try moduleQuote(definition, origin: template, effects: [axis: 500])
    }
    for (before, after) in zip(definition.grades, definition.grades.dropFirst()) {
      #expect(before.requiredAxes == after.requiredAxes)
      #expect(before.requiredAxes.allSatisfy { after.statistics[$0]! >= before.statistics[$0]! })
      #expect(before.requiredAxes.contains { after.statistics[$0]! > before.statistics[$0]! })
    }
  }
  #expect(
    EMT.shield.grades.map(\.identity.id) == [
      "shield.basic", "shield.basicII",
      "shield.intermediate", "shield.intermediateII", "shield.advanced", "shield.advancedII",
      "shield.elite",
    ])
}

@Test func equipmentModuleTemplatesKeepLegacyNavigationAdvancedUnambiguous() throws {
  let intermediate = try #require(
    EMT.legacyMapping(family: EMT.navigationFamily, key: "Navigation: Advanced"))
  #expect(intermediate.grade.id == "navigation.intermediate")
  #expect(intermediate.origin.statistics[.jumpReach] == 14)
  #expect(EMT.displayName(for: intermediate.grade) == "Intermediate")
  #expect(EMT.legacyNavigation(rawValue: 2) == intermediate)
  #expect(EMT.legacyNavigation(rawValue: 3)?.grade.id == "navigation.advanced")
  #expect(EMT.legacyNavigation(rawValue: 0) == nil)
  #expect(EMT.legacyNavigation(rawValue: 4) == nil)
  #expect(EMT.legacyMapping(family: EMT.navigationFamily, key: "Advanced") == nil)
  #expect(EMT.legacyMapping(family: EMT.energyFamily, key: "Navigation: Advanced") == nil)
  #expect(EMT.navigation.grades.map { $0.statistics[.jumpReach]! } == [7, 14, 21])
  #expect(EMT.navigation.terminalLimits == [.jumpReach: 27.3, .jumpSpool: 0.7, .jumpFuelCost: 0.7])
  let quote = try moduleQuote(
    EMT.navigation, origin: EMT.navigation.grades[0],
    effects: [.jumpSpool: 1500, .jumpFuelCost: 1500])
  #expect(quote.after[.jumpSpool] == 0.85 && quote.after[.jumpFuelCost] == 0.85)
  #expect(quote.promotions.isEmpty)
}

@Test func equipmentModuleTemplatesEnergyCapacityIsIndependentOfRechargeGrade() throws {
  #expect(EMT.energy.grades.map { $0.statistics[.energyRecharge]! } == [1, 2, 3])
  #expect(EMT.energy.grades.allSatisfy { $0.statistics[.energyCapacity] == 1 })
  #expect(
    EMT.legacyMapping(family: EMT.energyFamily, key: "Extra Energy Unit")?.grade.id
      == "energy.intermediate")
  #expect(
    EMT.legacyMapping(family: EMT.energyFamily, key: "Naval Energy Unit")?.grade.id
      == "energy.advanced")
  let quote = try moduleQuote(
    EMT.energy, origin: EMT.energy.grades[0], effects: [.energyCapacity: 1500])
  #expect(quote.after[.energyCapacity] == 1.15 && quote.promotions.isEmpty)
  let capped = try moduleQuote(
    EMT.energy, origin: EMT.energy.grades[2],
    statistics: [.energyCapacity: 1.29, .energyRecharge: 3.89],
    effects: [.energyCapacity: 1500, .energyRecharge: 1500])
  #expect(capped.after == EMT.energy.terminalLimits)
}

@Test func equipmentModuleTemplatesShieldHistoryPreservesActualStrength() throws {
  #expect(
    EMT.shield.grades.map { $0.statistics[.frontShieldCapacity]! } == [
      1, 1.5, 1.8, 2, 2.3, 6.9, 9.2,
    ])
  #expect(
    EMT.shield.historicalOrigins.map { $0.statistics[.frontShieldCapacity]! } == [
      1.5, 5, 1.5, 2.3, 6.9,
    ])
  for key in ["Pulse", "Mining", "Beam", "Military", "Capital Ship"] {
    let mapping = try #require(
      EMT.legacyMapping(family: EMT.shieldFamily, key: key + " Shield Booster"))
    #expect(EMT.legacyMapping(family: EMT.shieldFamily, key: key + " Shield Module") == mapping)
    let quote = try moduleQuote(
      EMT.shield, origin: mapping.origin, grade: mapping.grade,
      effects: [.frontShieldRecharge: 500])
    #expect(quote.before[.frontShieldCapacity] == mapping.origin.statistics[.frontShieldCapacity])
    #expect(quote.after[.frontShieldCapacity] == quote.before[.frontShieldCapacity])
  }
  #expect(
    EMT.legacyMapping(family: EMT.shieldFamily, key: "Mining Shield Booster")?.grade.id
      == "shield.advanced")
  #expect(
    EMT.legacyMapping(family: EMT.shieldFamily, key: "Beam Shield Booster")?.grade.id
      == "shield.basicII")
  #expect(EMT.shieldGrade(named: "Intermediary") == EMT.shieldGrade(named: "Intermediate"))
  #expect(EMT.shieldGrade(named: "Intermediary II") == EMT.shieldGrade(named: "Intermediate II"))
  #expect(EMT.shieldGrade(named: "unknown") == nil)
}

@Test func equipmentModuleTemplatesShieldRequiresBothFacingsAndRetainsOriginReceipts() throws {
  let basic = EMT.shield.grades[0]
  let recharge = try moduleQuote(
    EMT.shield, origin: basic,
    effects: [.frontShieldRecharge: 1500, .rearShieldRecharge: 1500])
  #expect(recharge.promotions.isEmpty)
  var stats = basic.statistics
  stats[.frontShieldCapacity] = 1.5
  stats[.rearShieldCapacity] = 1.45
  let threshold = try moduleQuote(
    EMT.shield, origin: basic, statistics: stats,
    effects: [.rearShieldCapacity: 500])
  #expect(threshold.resultingGrade.id == "shield.basicII")
  let component = ComponentInstance(id: UUID(), origin: basic, statistics: stats)
  let item = ComponentUpgrade(
    identity: .service(UUID()), boundComponent: component.id,
    origin: basic.identity, basisPoints: [.rearShieldCapacity: 500])
  let quote = try ComponentProgression.quote(
    component: component, item: item,
    definition: EMT.shield, inventoryRevision: 1)
  let result = try ComponentProgression.apply(
    quote, component: component, item: item,
    definition: EMT.shield, inventoryRevision: 1)
  #expect(result.component.origin == basic)
  #expect(result.component.receipts.first?.origin == basic.identity)
  #expect(result.component.receipts.first?.item == item.identity)
  let wrong = ComponentUpgrade(
    identity: item.identity, boundComponent: component.id,
    origin: EMT.shield.grades[1].identity, basisPoints: item.basisPoints)
  #expect(throws: ComponentProgressionError.originMismatch) {
    try ComponentProgression.quote(
      component: component, item: wrong,
      definition: EMT.shield, inventoryRevision: 1)
  }
  let cap = try moduleQuote(
    EMT.shield, origin: EMT.shield.grades[6],
    statistics: [
      .frontShieldCapacity: 11.9, .rearShieldCapacity: 11.9,
      .frontShieldRecharge: 1.29, .rearShieldRecharge: 1.29,
    ],
    effects: [
      .frontShieldCapacity: 1500, .rearShieldCapacity: 1500,
      .frontShieldRecharge: 1500, .rearShieldRecharge: 1500,
    ])
  #expect(cap.after == EMT.shield.terminalLimits)
}

@Test func equipmentModuleTemplatesRespectTerminalNavigationCostsAndGrandfatheredShieldStrength()
  throws
{
  let capped = try moduleQuote(
    EMT.navigation, origin: EMT.navigation.grades[2],
    statistics: [.jumpReach: 27.2, .jumpSpool: 0.71, .jumpFuelCost: 0.71],
    effects: [.jumpReach: 1500, .jumpSpool: 1500, .jumpFuelCost: 1500])
  #expect(capped.after == EMT.navigation.terminalLimits)
  #expect(capped.nextGrade == nil)
  let exhausted = EMT.energy.grades[2]
  #expect(throws: ComponentProgressionError.noEffectiveChange) {
    try moduleQuote(
      EMT.energy, origin: exhausted, statistics: EMT.energy.terminalLimits,
      effects: [.energyCapacity: 500, .energyRecharge: 500])
  }
  let grandfathered = try moduleQuote(
    EMT.shield, origin: EMT.shield.historicalOrigins[1],
    grade: EMT.shield.grades[6].identity,
    statistics: [
      .frontShieldCapacity: 15, .rearShieldCapacity: 15,
      .frontShieldRecharge: 1, .rearShieldRecharge: 1,
    ],
    effects: [.frontShieldCapacity: 500, .frontShieldRecharge: 500])
  #expect(grandfathered.after[.frontShieldCapacity] == 15)
  #expect(grandfathered.after[.frontShieldRecharge] == 1.05)
  #expect(
    EMT.displayName(for: .init(family: EMT.shieldFamily, id: "shield.elite", version: 2)) == nil)
  #expect(EMT.legacyMapping(family: .init("unknown"), key: "Extra Energy Unit") == nil)
}
