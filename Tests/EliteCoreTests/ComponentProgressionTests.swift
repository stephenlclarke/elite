import Foundation
import Testing

@testable import EliteCore

private let cpFamily = ComponentFamily("test-shield")
private let cpID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
private let cpAxes: Set<ComponentAxis> = [
  .frontShieldCapacity, .rearShieldCapacity, .frontShieldRecharge, .rearShieldRecharge,
]
private func cpTemplate(_ order: Int, capacity: Double, recharge: Double = 10) -> ComponentTemplate
{
  .init(
    identity: .init(family: cpFamily, id: "g\(order)", version: 1), order: order,
    statistics: [
      .frontShieldCapacity: capacity, .rearShieldCapacity: capacity,
      .frontShieldRecharge: recharge, .rearShieldRecharge: recharge,
    ], requiredAxes: cpAxes, compatibleFeatures: ["existing-feature"])
}
private func cpDefinition() -> ComponentFamilyDefinition {
  .init(
    family: cpFamily, revision: 1,
    grades: [
      cpTemplate(0, capacity: 100), cpTemplate(1, capacity: 110),
      cpTemplate(2, capacity: 120, recharge: 12),
    ],
    terminalLimits: [
      .frontShieldCapacity: 150, .rearShieldCapacity: 150,
      .frontShieldRecharge: 20, .rearShieldRecharge: 20,
    ])
}
private func cpInstance() -> ComponentInstance {
  .init(id: cpID, origin: cpTemplate(0, capacity: 100), features: ["existing-feature"])
}
private func cpItem(
  _ number: UInt16, component: ComponentInstance,
  points: [ComponentAxis: Int] = [.frontShieldCapacity: 500, .rearShieldCapacity: 500]
) -> ComponentUpgrade {
  let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 4, lineage: 400)
  let identity = ComponentUpgradeIdentity.salvage(
    .init(section: .init(wreck: wreck, section: 1), lot: number))
  return .init(
    identity: identity, boundComponent: component.id, origin: component.origin.identity,
    basisPoints: points)
}
private func cpApply(
  _ item: ComponentUpgrade, to component: ComponentInstance,
  definition: ComponentFamilyDefinition = cpDefinition(), revision: UInt64 = 10
) throws -> ComponentInstance {
  let quote = try ComponentProgression.quote(
    component: component, item: item, definition: definition, inventoryRevision: revision)
  let application = try ComponentProgression.apply(
    quote, component: component, item: item, definition: definition, inventoryRevision: revision)
  #expect(application.component.id == component.id && application.consumedItem == item.identity)
  #expect(application.expectedInventoryRevision == revision)
  return application.component
}

@Test func componentProgressionUsesPinnedOriginOnceAndRequiresEveryGradeAxis() throws {
  let initial = cpInstance()
  let one = cpItem(1, component: initial, points: [.frontShieldCapacity: 500])
  let quote = try ComponentProgression.quote(
    component: initial, item: one, definition: cpDefinition(), inventoryRevision: 10)
  #expect(quote.before[.frontShieldCapacity] == 100 && quote.after[.frontShieldCapacity] == 105)
  #expect(quote.promotions.isEmpty && quote.resultingGrade == initial.grade)
  #expect(quote.progress.first(where: { $0.axis == .frontShieldCapacity })?.fraction == 0.5)
  #expect(quote.progress.first(where: { $0.axis == .rearShieldCapacity })?.fraction == 0)
  #expect(initial.statistics[.frontShieldCapacity] == 100 && initial.receipts.isEmpty)

  var component = try cpApply(one, to: initial)
  component = try cpApply(cpItem(2, component: component), to: component)
  #expect(component.statistics[.frontShieldCapacity] == 110)
  #expect(component.statistics[.rearShieldCapacity] == 105 && component.grade == initial.grade)
  component = try cpApply(
    cpItem(3, component: component, points: [.rearShieldCapacity: 500]), to: component)
  #expect(component.grade == cpTemplate(1, capacity: 110).identity)
  component = try cpApply(cpItem(4, component: component), to: component)
  #expect(
    component.statistics[.frontShieldCapacity] == 115
      && component.statistics[.rearShieldCapacity] == 115)
  #expect(component.origin == initial.origin && component.features == initial.features)
  #expect(component.receipts.count == 4)
}

@Test func componentProgressionCarriesExcessThroughMultiplePromotionsWithoutRefillingAnything()
  throws
{
  let initial = cpInstance()
  let definition = ComponentFamilyDefinition(
    family: cpFamily, revision: 2,
    grades: [
      cpTemplate(2, capacity: 110), cpTemplate(0, capacity: 100), cpTemplate(1, capacity: 105),
    ],
    terminalLimits: cpDefinition().terminalLimits)
  let item = cpItem(
    1, component: initial, points: [.frontShieldCapacity: 1500, .rearShieldCapacity: 1500])
  let quote = try ComponentProgression.quote(
    component: initial, item: item, definition: definition, inventoryRevision: 5)
  #expect(quote.promotions.map(\.id) == ["g1", "g2"])
  #expect(quote.after[.frontShieldCapacity] == 115 && quote.after[.rearShieldCapacity] == 115)
  #expect(quote.nextGrade == nil)
  let upgraded = try cpApply(item, to: initial, definition: definition, revision: 5)
  #expect(upgraded.id == initial.id && upgraded.origin == initial.origin)
  #expect(upgraded.statistics[.frontShieldRecharge] == 10)
  #expect(upgraded.features == ["existing-feature"] && upgraded.receipts.count == 1)
}

@Test func componentProgressionRechargeOnlyDoesNotPretendCapacityReachedTheNextGrade() throws {
  let initial = cpInstance()
  let item = cpItem(
    1, component: initial, points: [.frontShieldRecharge: 1500, .rearShieldRecharge: 1500])
  let quote = try ComponentProgression.quote(
    component: initial, item: item, definition: cpDefinition(), inventoryRevision: 10)
  #expect(quote.after[.frontShieldRecharge] == 11.5 && quote.after[.frontShieldCapacity] == 100)
  #expect(quote.promotions.isEmpty)
  #expect(quote.progress.first(where: { $0.axis == .frontShieldCapacity })?.fulfilled == false)
  #expect(quote.progress.first(where: { $0.axis == .frontShieldRecharge })?.fulfilled == true)
}

@Test func componentProgressionReversesCostAxesAndPreservesTheirAbsoluteImprovements() throws {
  let family = ComponentFamily("test-tool")
  let axes: Set<ComponentAxis> = [.energyDemand, .heat, .firingInterval, .jumpSpool]
  let first = ComponentTemplate(
    identity: .init(family: family, id: "a", version: 1), order: 0,
    statistics: [.energyDemand: 100, .heat: 80, .firingInterval: 2, .jumpSpool: 10],
    requiredAxes: axes)
  let second = ComponentTemplate(
    identity: .init(family: family, id: "b", version: 1), order: 1,
    statistics: [.energyDemand: 95, .heat: 76, .firingInterval: 1.9, .jumpSpool: 9.5],
    requiredAxes: axes)
  let definition = ComponentFamilyDefinition(
    family: family, revision: 1, grades: [first, second],
    terminalLimits: [.energyDemand: 80, .heat: 60, .firingInterval: 1.2, .jumpSpool: 6])
  var component = ComponentInstance(id: cpID, origin: first)
  for number in 1...2 {
    let item = cpItem(
      UInt16(number), component: component,
      points: Dictionary(uniqueKeysWithValues: axes.map { ($0, 500) }))
    component = try cpApply(item, to: component, definition: definition)
  }
  #expect(component.grade == second.identity)
  #expect(component.statistics[.energyDemand] == 90 && component.statistics[.heat] == 72)
  #expect(abs((component.statistics[.firingInterval] ?? 0) - 1.8) < 1e-12)
  #expect(component.statistics[.jumpSpool] == 9)
  #expect(component.receipts.allSatisfy { $0.appliedAbsoluteEffects.values.allSatisfy { $0 < 0 } })
}

@Test func componentProgressionPreservesLegacyExcessAndNeverImprovesACappedAxisFurther() throws {
  let original = cpInstance()
  let legacy = ComponentInstance(
    id: original.id, origin: original.origin,
    statistics: [
      .frontShieldCapacity: 200, .rearShieldCapacity: 140, .frontShieldRecharge: 15,
      .rearShieldRecharge: 15,
    ],
    grade: cpTemplate(2, capacity: 120, recharge: 12).identity, features: original.features)
  let item = cpItem(
    1, component: legacy, points: [.frontShieldCapacity: 1500, .rearShieldCapacity: 1500])
  let updated = try cpApply(item, to: legacy)
  #expect(
    updated.statistics[.frontShieldCapacity] == 200
      && updated.statistics[.rearShieldCapacity] == 150)
  #expect(updated.receipts[0].appliedAbsoluteEffects[.frontShieldCapacity] == 0)
  #expect(updated.receipts[0].appliedAbsoluteEffects[.rearShieldCapacity] == 10)
  #expect(throws: ComponentProgressionError.noEffectiveChange) {
    try ComponentProgression.quote(
      component: updated, item: cpItem(2, component: updated), definition: cpDefinition(),
      inventoryRevision: 10)
  }
  #expect(updated.statistics[.frontShieldCapacity] == 200 && updated.receipts.count == 1)
}

@Test func componentProgressionRefusesReplayChangedBindingsStaleStateAndInventoryRevision() throws {
  let initial = cpInstance()
  let definition = cpDefinition()
  let item = cpItem(1, component: initial)
  let quote = try ComponentProgression.quote(
    component: initial, item: item, definition: definition, inventoryRevision: 10)
  let updated = try cpApply(item, to: initial)
  #expect(throws: ComponentProgressionError.replayedItem) {
    try ComponentProgression.apply(
      quote, component: updated, item: item, definition: definition, inventoryRevision: 10)
  }
  #expect(throws: ComponentProgressionError.inventoryChanged) {
    try ComponentProgression.apply(
      quote, component: initial, item: item, definition: definition, inventoryRevision: 11)
  }
  let forged = ComponentUpgrade(
    identity: item.identity,
    boundComponent: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, origin: item.origin,
    basisPoints: item.basisPoints)
  #expect(throws: ComponentProgressionError.wrongComponent) {
    try ComponentProgression.quote(
      component: initial, item: forged, definition: definition, inventoryRevision: 10)
  }
  let changedPayload = cpItem(1, component: initial, points: [.frontShieldCapacity: 1500])
  #expect(throws: ComponentProgressionError.staleQuote) {
    try ComponentProgression.apply(
      quote, component: initial, item: changedPayload, definition: definition, inventoryRevision: 10
    )
  }
  let altered = ComponentInstance(
    id: initial.id, origin: initial.origin, statistics: updated.statistics,
    features: initial.features)
  #expect(throws: ComponentProgressionError.staleQuote) {
    try ComponentProgression.apply(
      quote, component: altered, item: item, definition: definition, inventoryRevision: 10)
  }
  #expect(initial.receipts.isEmpty && initial.statistics[.frontShieldCapacity] == 100)
}

@Test func componentProgressionPinsHistoricalOriginVersionAndRejectsForgedBaselines() throws {
  let old = cpTemplate(0, capacity: 100)
  let active = ComponentTemplate(
    identity: .init(family: cpFamily, id: "new", version: 2), order: 0,
    statistics: old.statistics, requiredAxes: cpAxes, compatibleFeatures: old.compatibleFeatures)
  let definition = ComponentFamilyDefinition(
    family: cpFamily, revision: 2, grades: [active], terminalLimits: cpDefinition().terminalLimits,
    historicalOrigins: [old])
  let component = ComponentInstance(
    id: cpID, origin: old, grade: active.identity, features: ["existing-feature"])
  let updated = try cpApply(cpItem(1, component: component), to: component, definition: definition)
  #expect(updated.origin == old && updated.statistics[.frontShieldCapacity] == 105)
  let forgedOrigin = cpTemplate(0, capacity: 200)
  let forged = ComponentInstance(id: cpID, origin: forgedOrigin, grade: active.identity)
  #expect(throws: ComponentProgressionError.originMismatch) {
    try ComponentProgression.quote(
      component: forged, item: cpItem(2, component: forged), definition: definition,
      inventoryRevision: 1)
  }
}

@Test func componentProgressionSaveRoundTripRetainsPhysicalIdentityFeaturesAndReceiptBinding()
  throws
{
  let initial = cpInstance()
  let item = cpItem(1, component: initial)
  let component = try cpApply(item, to: initial)
  let restored = try JSONDecoder().decode(
    ComponentInstance.self, from: JSONEncoder().encode(component))
  #expect(restored == component && restored.id == initial.id)
  #expect(restored.origin == initial.origin && restored.features == initial.features)
  #expect(throws: ComponentProgressionError.replayedItem) {
    try ComponentProgression.quote(
      component: restored, item: item, definition: cpDefinition(), inventoryRevision: 99)
  }
}

@Test func componentProgressionRejectsInvalidEffectsNonmonotonicTablesAndUnknownAxes() throws {
  let initial = cpInstance()
  for points in [
    [ComponentAxis.frontShieldCapacity: 1], [.frontShieldCapacity: 2000], [.damage: 500],
  ] {
    #expect(throws: ComponentProgressionError.invalidEffect) {
      try ComponentProgression.quote(
        component: initial, item: cpItem(1, component: initial, points: points),
        definition: cpDefinition(), inventoryRevision: 1)
    }
  }
  let bad = ComponentFamilyDefinition(
    family: cpFamily, revision: 1,
    grades: [cpTemplate(0, capacity: 100), cpTemplate(1, capacity: 100.nextDown)],
    terminalLimits: cpDefinition().terminalLimits)
  #expect(throws: ComponentProgressionError.invalidDefinition) {
    try ComponentProgression.quote(
      component: initial, item: cpItem(1, component: initial), definition: bad, inventoryRevision: 1
    )
  }
  let invalid = ComponentInstance(
    id: initial.id, origin: initial.origin, statistics: [.frontShieldCapacity: .nan])
  #expect(throws: ComponentProgressionError.invalidInstance) {
    try ComponentProgression.quote(
      component: invalid, item: cpItem(1, component: invalid), definition: cpDefinition(),
      inventoryRevision: 1)
  }
}

@Test func componentProgressionEnergyAndFlightAxesUseActualAbsoluteValuesWithoutGrantingFeatures()
  throws
{
  let family = ComponentFamily("test-mining-tool")
  let stats: ComponentStatistics = [
    .energyCapacity: 256, .energyRecharge: 2, .speed: 30, .acceleration: 4, .jumpReach: 7,
    .scanPrecision: 10,
  ]
  let origin = ComponentTemplate(
    identity: .init(family: family, id: "origin", version: 1), order: 0,
    statistics: stats, requiredAxes: Set(stats.keys), compatibleFeatures: ["mining-specialization"])
  let limits = stats.mapValues { $0 * 2 }
  let definition = ComponentFamilyDefinition(
    family: family, revision: 1, grades: [origin], terminalLimits: limits)
  let component = ComponentInstance(id: cpID, origin: origin, features: ["mining-specialization"])
  let item = cpItem(
    1, component: component, points: Dictionary(uniqueKeysWithValues: stats.keys.map { ($0, 1000) })
  )
  let upgraded = try cpApply(item, to: component, definition: definition)
  #expect(
    upgraded.statistics[.energyCapacity] == 281.6 && upgraded.statistics[.energyRecharge] == 2.2)
  #expect(upgraded.statistics[.speed] == 33 && upgraded.statistics[.acceleration] == 4.4)
  #expect(abs((upgraded.statistics[.jumpReach] ?? 0) - 7.7) < 1e-12)
  #expect(upgraded.statistics[.scanPrecision] == 11)
  #expect(upgraded.family == family && upgraded.features == ["mining-specialization"])
  #expect(
    !upgraded.features.contains("Targeting: Mining Module")
      && !upgraded.features.contains("Targeting: Salvage Module"))
}

@Test func componentProgressionPreservesCompatibleLaterFitsAndHistoricalGradingRules() throws {
  let original = cpTemplate(0, capacity: 100)
  let current = ComponentTemplate(
    identity: .init(family: cpFamily, id: "current", version: 3), order: 0,
    statistics: original.statistics, requiredAxes: [.frontShieldCapacity, .rearShieldCapacity],
    compatibleFeatures: ["existing-feature", "later-fitting"])
  let definition = ComponentFamilyDefinition(
    family: cpFamily, revision: 3, grades: [current], terminalLimits: cpDefinition().terminalLimits,
    historicalOrigins: [original])
  let component = ComponentInstance(
    id: cpID, origin: original, grade: current.identity,
    features: ["existing-feature", "later-fitting"])
  let updated = try cpApply(cpItem(1, component: component), to: component, definition: definition)
  #expect(updated.origin == original && updated.origin.requiredAxes == cpAxes)
  #expect(updated.statistics[.frontShieldCapacity] == 105 && updated.features == component.features)
}

@Test func componentProgressionBelowThresholdDoesNotPromoteAndLargeFiniteCapsDoNotOverflow() throws
{
  let initial = cpInstance()
  let below = ComponentInstance(
    id: initial.id, origin: initial.origin,
    statistics: [
      .frontShieldCapacity: 104.999999, .rearShieldCapacity: 105,
      .frontShieldRecharge: 10, .rearShieldRecharge: 10,
    ], features: initial.features)
  let quote = try ComponentProgression.quote(
    component: below, item: cpItem(1, component: below), definition: cpDefinition(),
    inventoryRevision: 0)
  #expect(quote.promotions.isEmpty && (quote.after[.frontShieldCapacity] ?? 0) < 110)

  let family = ComponentFamily("large-finite-test")
  let origin = ComponentTemplate(
    identity: .init(family: family, id: "origin", version: 1), order: 0,
    statistics: [.speed: 1e308], requiredAxes: [.speed])
  let component = ComponentInstance(id: cpID, origin: origin, statistics: [.speed: 1.69e308])
  let definition = ComponentFamilyDefinition(
    family: family, revision: 1, grades: [origin], terminalLimits: [.speed: 1.7e308])
  let upgraded = try cpApply(
    cpItem(1, component: component, points: [.speed: 1500]), to: component, definition: definition)
  #expect(upgraded.statistics[.speed] == 1.7e308 && upgraded.statistics[.speed]?.isFinite == true)
}

@Test func componentProgressionKeepsLegacyLowerCostsBelowTheTerminalFloor() throws {
  let family = ComponentFamily("legacy-cost-test")
  let origin = ComponentTemplate(
    identity: .init(family: family, id: "origin", version: 1), order: 0,
    statistics: [.energyDemand: 100, .heat: 100], requiredAxes: [.energyDemand, .heat])
  let definition = ComponentFamilyDefinition(
    family: family, revision: 1, grades: [origin], terminalLimits: [.energyDemand: 60, .heat: 60])
  let legacy = ComponentInstance(
    id: cpID, origin: origin, statistics: [.energyDemand: 50, .heat: 80])
  let upgraded = try cpApply(
    cpItem(1, component: legacy, points: [.energyDemand: 500, .heat: 500]), to: legacy,
    definition: definition)
  #expect(upgraded.statistics[.energyDemand] == 50 && upgraded.statistics[.heat] == 75)
  #expect(upgraded.receipts[0].appliedAbsoluteEffects[.energyDemand] == 0)
  #expect(upgraded.receipts[0].appliedAbsoluteEffects[.heat] == -5)
}

@Test func componentProgressionKeepsRangeAccuracyAndJumpFuelCostEffectsDistinct() throws {
  let family = ComponentFamily("test-navigation")
  let original: ComponentStatistics = [
    .scanRange: 1000, .acquisitionError: 0.2, .automationError: 0.1, .jumpFuelCost: 7,
  ]
  let axes = Set(original.keys)
  let first = ComponentTemplate(
    identity: .init(family: family, id: "a", version: 1), order: 0,
    statistics: original, requiredAxes: axes)
  let second = ComponentTemplate(
    identity: .init(family: family, id: "b", version: 1), order: 1,
    statistics: [
      .scanRange: 1100, .acquisitionError: 0.18, .automationError: 0.09, .jumpFuelCost: 6.3,
    ], requiredAxes: axes)
  let definition = ComponentFamilyDefinition(
    family: family, revision: 1, grades: [first, second],
    terminalLimits: [
      .scanRange: 2000, .acquisitionError: 0, .automationError: 0, .jumpFuelCost: 0,
    ])
  let initial = ComponentInstance(id: cpID, origin: first)
  let rangeOnly = cpItem(1, component: initial, points: [.scanRange: 1000])
  let quote = try ComponentProgression.quote(
    component: initial, item: rangeOnly, definition: definition, inventoryRevision: 10)
  #expect(quote.after[.scanRange] == 1100 && quote.promotions.isEmpty)
  for axis in [ComponentAxis.acquisitionError, .automationError, .jumpFuelCost] {
    #expect(!axis.higherIsBetter)
    #expect(quote.after[axis] == original[axis])
    #expect(quote.progress.first(where: { $0.axis == axis })?.fulfilled == false)
  }
  #expect(ComponentAxis.scanRange.higherIsBetter)

  var component = try cpApply(rangeOnly, to: initial, definition: definition)
  for number in 2...3 {
    let item = cpItem(
      UInt16(number), component: component,
      points: Dictionary(uniqueKeysWithValues: axes.map { ($0, 1000) }))
    component = try cpApply(item, to: component, definition: definition)
  }
  #expect(component.grade == second.identity && component.statistics[.scanRange] == 1300)
  #expect(abs((component.statistics[.acquisitionError] ?? 0) - 0.16) < 1e-12)
  #expect(abs((component.statistics[.automationError] ?? 0) - 0.08) < 1e-12)
  #expect(abs((component.statistics[.jumpFuelCost] ?? 0) - 5.6) < 1e-12)
  #expect(component.statistics[.scanPrecision] == nil && component.statistics[.energyDemand] == nil)
  let effects = component.receipts.last!.appliedAbsoluteEffects
  #expect(effects[.scanRange] == 100)
  #expect(abs((effects[.acquisitionError] ?? 0) + 0.02) < 1e-12)
  #expect(abs((effects[.automationError] ?? 0) + 0.01) < 1e-12)
  #expect(abs((effects[.jumpFuelCost] ?? 0) + 0.7) < 1e-12)
  #expect(component.origin == first && component.id == initial.id)
}

@Test func componentProgressionAcceptsDeclaredDeviceRatiosWithoutNativeHullConversion() throws {
  let family = ComponentFamily("test-shield-ratio")
  let stats: ComponentStatistics = [
    .frontShieldCapacity: 1, .rearShieldCapacity: 1,
    .frontShieldRecharge: 1, .rearShieldRecharge: 1,
  ]
  let origin = ComponentTemplate(
    identity: .init(family: family, id: "origin", version: 1), order: 0,
    statistics: stats, requiredAxes: Set(stats.keys))
  let definition = ComponentFamilyDefinition(
    family: family, revision: 1, grades: [origin],
    terminalLimits: stats.mapValues { $0 * 2 })
  let component = ComponentInstance(id: cpID, origin: origin)
  let item = cpItem(
    1, component: component,
    points: Dictionary(uniqueKeysWithValues: stats.keys.map { ($0, 500) }))
  let upgraded = try cpApply(item, to: component, definition: definition)
  #expect(upgraded.statistics.values.allSatisfy { $0 == 1.05 })
  #expect(upgraded.receipts[0].appliedAbsoluteEffects.values.allSatisfy { abs($0 - 0.05) < 1e-12 })
  #expect(upgraded.origin.statistics == stats && upgraded.features.isEmpty)
}
