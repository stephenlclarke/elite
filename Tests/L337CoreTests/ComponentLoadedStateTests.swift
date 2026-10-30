import Foundation
import Testing

@testable import L337Core

private let clFamily = ComponentFamily("loaded-test-shield")
private let clID = UUID(uuidString: "81000000-0000-0000-0000-000000000001")!
private let clOther = UUID(uuidString: "81000000-0000-0000-0000-000000000002")!
private let clFeatures: Set<String> = ["existing-specialization"]
private func clTemplate(_ order: Int) -> ComponentTemplate {
  let capacities = [100.0, 110, 120]
  let recharges = [1.0, 1, 1.2]
  let heats = [10.0, 9.5, 9]
  return .init(
    identity: .init(family: clFamily, id: "grade-\(order)", version: 1), order: order,
    statistics: [
      .frontShieldCapacity: capacities[order], .rearShieldCapacity: capacities[order],
      .frontShieldRecharge: recharges[order], .rearShieldRecharge: recharges[order],
      .heat: heats[order],
    ],
    requiredAxes: [
      .frontShieldCapacity, .rearShieldCapacity, .frontShieldRecharge,
      .rearShieldRecharge, .heat,
    ], compatibleFeatures: clFeatures)
}
private func clDefinition() -> ComponentFamilyDefinition {
  .init(
    family: clFamily, revision: 1, grades: [clTemplate(0), clTemplate(1), clTemplate(2)],
    terminalLimits: [
      .frontShieldCapacity: 200, .rearShieldCapacity: 200,
      .frontShieldRecharge: 2, .rearShieldRecharge: 2, .heat: 5,
    ])
}
private func clComponent(
  id: UUID = clID, origin: ComponentTemplate = clTemplate(0),
  statistics: ComponentStatistics? = nil, grade: ComponentTemplateVersion? = nil,
  features: Set<String> = clFeatures, receipts: [ComponentUpgradeReceipt] = []
) -> ComponentInstance {
  .init(
    id: id, origin: origin, statistics: statistics, grade: grade,
    features: features, receipts: receipts)
}
private func clItem(
  _ component: ComponentInstance, number: Int = 1,
  points: [ComponentAxis: Int]? = nil
) -> ComponentUpgrade {
  .init(
    identity: .service(UUID(uuidString: String(format: "82000000-0000-0000-0000-%012d", number))!),
    boundComponent: component.id, origin: component.origin.identity,
    basisPoints: points
      ?? Dictionary(uniqueKeysWithValues: component.statistics.keys.map { ($0, 1000) }))
}
private func clApplication(_ before: ComponentInstance = clComponent(), revision: UInt64 = 17)
  throws -> ComponentUpgradeApplication
{
  let item = clItem(before)
  let quote = try ComponentProgression.quote(
    component: before, item: item,
    definition: clDefinition(), inventoryRevision: revision)
  return try ComponentProgression.apply(
    quote, component: before, item: item,
    definition: clDefinition(), inventoryRevision: revision)
}

@Test func componentLoadedStateRoundTripPreservesGradeOriginFeaturesAndReceipts() throws {
  let before = clComponent()
  let upgraded = try clApplication(before).component
  let restored = try JSONDecoder().decode(
    ComponentInstance.self,
    from: JSONEncoder().encode(upgraded))
  try ComponentProgression.validateLoaded(restored, definition: clDefinition())
  let reconciled = try ComponentProgression.reconcileLoaded(restored, definition: clDefinition())
  #expect(restored == upgraded && reconciled == restored)
  #expect(restored.grade == clTemplate(1).identity && restored.origin == before.origin)
  #expect(
    restored.id == before.id && restored.features == clFeatures && restored.receipts.count == 1)
}

@Test func componentLoadedStateReconcilesActualExcessWithoutItemsReceiptsOrStatChanges() throws {
  let earned = try clApplication().component
  let stats: ComponentStatistics = [
    .frontShieldCapacity: 170.123, .rearShieldCapacity: 175.456,
    .frontShieldRecharge: 1.6, .rearShieldRecharge: 1.7, .heat: 8.123,
  ]
  let saved = clComponent(statistics: stats, receipts: earned.receipts)
  try ComponentProgression.validateLoaded(saved, definition: clDefinition())
  let result = try ComponentProgression.reconcileLoaded(saved, definition: clDefinition())
  #expect(result.grade == clTemplate(2).identity && saved.grade == clTemplate(0).identity)
  #expect(result.id == saved.id && result.origin == saved.origin)
  #expect(result.statistics == stats && result.features == saved.features)
  #expect(result.receipts == saved.receipts && result.receipts.count == 1)
  #expect(!result.features.contains("Targeting: Mining Module"))
  #expect(!result.features.contains("Targeting: Salvage Module"))
  #expect(try ComponentProgression.reconcileLoaded(result, definition: clDefinition()) == result)
}

@Test func componentLoadedStatePreservesLegacyOverCapValuesAndHistoricalOrigins() throws {
  let old = ComponentTemplate(
    identity: .init(family: clFamily, id: "legacy", version: 7), order: 0,
    statistics: clTemplate(0).statistics, requiredAxes: [.frontShieldCapacity],
    compatibleFeatures: clFeatures)
  let current = clDefinition()
  let definition = ComponentFamilyDefinition(
    family: current.family, revision: 2, grades: current.grades,
    terminalLimits: current.terminalLimits, historicalOrigins: [old])
  let values: ComponentStatistics = [
    .frontShieldCapacity: 500, .rearShieldCapacity: 700, .frontShieldRecharge: 8,
    .rearShieldRecharge: 9, .heat: 0,
  ]
  let loaded = clComponent(origin: old, statistics: values, grade: clTemplate(1).identity)
  try ComponentProgression.validateLoaded(loaded, definition: definition)
  let result = try ComponentProgression.reconcileLoaded(loaded, definition: definition)
  #expect(result.grade == clTemplate(2).identity && result.statistics == values)
  #expect(result.origin == old && result.id == loaded.id && result.receipts.isEmpty)
  #expect(result.features == loaded.features)
}

@Test func componentLoadedStateRejectsUnknownAndForgedOriginsWithoutDowngrading() throws {
  let initial = clComponent()
  let unknown = ComponentTemplate(
    identity: .init(family: clFamily, id: initial.origin.identity.id, version: 999), order: 0,
    statistics: initial.origin.statistics, requiredAxes: initial.origin.requiredAxes,
    compatibleFeatures: clFeatures)
  var forgedValues = initial.origin.statistics
  forgedValues[.frontShieldCapacity] = 99
  let forged = ComponentTemplate(
    identity: initial.origin.identity, order: 0, statistics: forgedValues,
    requiredAxes: initial.origin.requiredAxes, compatibleFeatures: clFeatures)
  for origin in [unknown, forged] {
    let loaded = clComponent(origin: origin, statistics: initial.statistics)
    #expect(throws: ComponentProgressionError.originMismatch) {
      try ComponentProgression.validateLoaded(loaded, definition: clDefinition())
    }
    #expect(throws: ComponentProgressionError.originMismatch) {
      try ComponentProgression.reconcileLoaded(loaded, definition: clDefinition())
    }
    #expect(loaded.origin == origin && loaded.grade == origin.identity)
  }
  let other = ComponentTemplate(
    identity: .init(family: .init("another-family"), id: "a", version: 1),
    order: 0, statistics: initial.origin.statistics,
    requiredAxes: initial.origin.requiredAxes)
  #expect(throws: ComponentProgressionError.incompatibleFamily) {
    try ComponentProgression.validateLoaded(clComponent(origin: other), definition: clDefinition())
  }
}

@Test func componentLoadedStateRejectsInvalidGradesStatisticsAndFeatures() throws {
  let initial = clComponent()
  var missing = initial.statistics
  missing.removeValue(forKey: .heat)
  var nonfinite = initial.statistics
  nonfinite[.heat] = .nan
  var negative = initial.statistics
  negative[.frontShieldCapacity] = -1
  let invalid = [
    clComponent(grade: .init(family: clFamily, id: "unknown-grade", version: 1)),
    clComponent(grade: clTemplate(2).identity),
    clComponent(statistics: missing), clComponent(statistics: nonfinite),
    clComponent(statistics: negative), clComponent(features: ["unearned-module"]),
  ]
  for loaded in invalid {
    #expect(throws: ComponentProgressionError.invalidInstance) {
      try ComponentProgression.validateLoaded(loaded, definition: clDefinition())
    }
    #expect(throws: ComponentProgressionError.invalidInstance) {
      try ComponentProgression.reconcileLoaded(loaded, definition: clDefinition())
    }
  }
}

@Test func componentLoadedStateRejectsDuplicateMismatchedAndMalformedReceipts() throws {
  let good = try clApplication().component
  let receipt = good.receipts[0]
  let wrongInstance = ComponentUpgradeReceipt(
    item: receipt.item, component: clOther, origin: receipt.origin,
    appliedAbsoluteEffects: receipt.appliedAbsoluteEffects,
    gradeBefore: receipt.gradeBefore, gradeAfter: receipt.gradeAfter)
  let wrongOrigin = ComponentUpgradeReceipt(
    item: receipt.item, component: receipt.component,
    origin: .init(family: clFamily, id: "unknown-origin", version: 1),
    appliedAbsoluteEffects: receipt.appliedAbsoluteEffects,
    gradeBefore: receipt.gradeBefore, gradeAfter: receipt.gradeAfter)
  let wrongGrade = ComponentUpgradeReceipt(
    item: receipt.item, component: receipt.component, origin: receipt.origin,
    appliedAbsoluteEffects: receipt.appliedAbsoluteEffects,
    gradeBefore: receipt.gradeBefore,
    gradeAfter: .init(family: clFamily, id: "unknown-grade", version: 1))
  var invalidReceipts = [[receipt, receipt], [wrongInstance], [wrongOrigin], [wrongGrade]]
  let malformedEffects: [ComponentStatistics] = [
    [:], [.heat: 1], [.heat: .infinity], [.damage: 1], [.heat: 0],
  ]
  for effects in malformedEffects {
    invalidReceipts.append([
      .init(
        item: receipt.item, component: receipt.component, origin: receipt.origin,
        appliedAbsoluteEffects: effects, gradeBefore: receipt.gradeBefore,
        gradeAfter: receipt.gradeAfter)
    ])
  }
  for receipts in invalidReceipts {
    let loaded = clComponent(statistics: good.statistics, grade: good.grade, receipts: receipts)
    #expect(throws: ComponentProgressionError.invalidInstance) {
      try ComponentProgression.validateLoaded(loaded, definition: clDefinition())
    }
  }
}

@Test func componentLoadedStateAndApplicationRejectInvalidOrChangedDefinitions() throws {
  let initial = clComponent()
  let application = try clApplication(initial)
  let current = clDefinition()
  let invalid = ComponentFamilyDefinition(
    family: current.family, revision: 1,
    grades: [clTemplate(0), clTemplate(0)],
    terminalLimits: current.terminalLimits)
  #expect(throws: ComponentProgressionError.invalidDefinition) {
    try ComponentProgression.validateLoaded(initial, definition: invalid)
  }
  #expect(throws: ComponentProgressionError.invalidDefinition) {
    try ComponentProgression.reconcileLoaded(initial, definition: invalid)
  }
  let changed = ComponentFamilyDefinition(
    family: current.family, revision: 2,
    grades: current.grades, terminalLimits: current.terminalLimits)
  #expect(throws: ComponentProgressionError.staleQuote) {
    try ComponentProgression.validateApplication(
      application, before: initial,
      definition: changed, sourceInventoryRevision: 17)
  }
}

@Test func componentLoadedApplicationChecksOriginalStateAndSourceInventoryAuthority() throws {
  let before = clComponent()
  let application = try clApplication(before)
  try ComponentProgression.validateApplication(
    application, before: before,
    definition: clDefinition(), sourceInventoryRevision: 17)
  #expect(application.expectedInventoryRevision == 17 && application.component.id == before.id)
  #expect(throws: ComponentProgressionError.inventoryChanged) {
    try ComponentProgression.validateApplication(
      application, before: before,
      definition: clDefinition(), sourceInventoryRevision: 18)
  }
  var changed = before.statistics
  changed[.frontShieldCapacity] = 101
  for stale in [
    clComponent(statistics: changed), clComponent(id: clOther), clComponent(features: []),
  ] {
    #expect(throws: ComponentProgressionError.staleQuote) {
      try ComponentProgression.validateApplication(
        application, before: stale,
        definition: clDefinition(), sourceInventoryRevision: 17)
    }
  }
  #expect(throws: ComponentProgressionError.replayedItem) {
    try ComponentProgression.validateApplication(
      application, before: application.component,
      definition: clDefinition(), sourceInventoryRevision: 17)
  }
  #expect(before.receipts.isEmpty && before.statistics == before.origin.statistics)
}
