import Foundation
import Testing

@testable import EliteCore

private func pulseCommander(_ energy: String? = nil) throws -> Commander {
  var commander = Commander()
  try commander.prepareEquipment(legacy: false)
  if let energy {
    try commander.grantEquipment(
      energy, at: .energy, provenance: .grant("pulse profile regression"))
  }
  return commander
}

private func applyPulseEnergyUpgrade(_ axis: ComponentAxis, commander: inout Commander) throws {
  let fitted = try #require(commander.fittedEquipment(at: .energy))
  let component = try #require(fitted.component)
  var inventory = try #require(commander.equipmentInventory)
  let definition = EquipmentModuleTemplates.energy
  let upgrade = ComponentUpgrade(
    identity: .service(UUID()), boundComponent: component.id,
    origin: component.origin.identity, basisPoints: [axis: 1500])
  let quote = try ComponentProgression.quote(
    component: component, item: upgrade, definition: definition, inventoryRevision: 0)
  let application = try ComponentProgression.apply(
    quote, component: component, item: upgrade, definition: definition, inventoryRevision: 0)
  let context = EquipmentRuntimeCatalog.context(
    owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance)
  try inventory.replaceGradedInstance(
    expected: fitted, application: application, expectedRevision: inventory.revision,
    sourceInventoryRevision: 0, context: context)
  commander.savedEquipmentInventory = inventory
  commander.mirrorFittedEquipment()
  try commander.validateEquipmentState()
}

struct EMPPulseProfileTests {
  @Test func actualEnergyFitsResolveAdditivePowerAndReachWithoutMutatingCommander() throws {
    let cases: [(String?, Int, Double, Double)] = [
      (nil, 0, 32, 3000), ("Extra Energy Unit", 1, 48, 4500),
      (Equipment.navalEnergyUnit, 2, 64, 6000), (Equipment.eliteEnergyUnit, 3, 80, 7500),
    ]
    for (name, stage, power, range) in cases {
      let commander = try pulseCommander(name)
      let retained = commander
      let profile = try EMPPulseProfile.resolve(for: commander)
      #expect(profile.energyStage == stage && profile.power == power && profile.range == range)
      #expect(profile.energyCost == 8 && profile.heatCost == 18 && profile.cooldown == 1.5)
      #expect(profile.warmup == 10 && profile.splashRadius == range / 3)
      #expect(commander == retained)
      let restored = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(commander))
      let reloaded = try EMPPulseProfile.resolve(for: restored)
      #expect(reloaded == profile && restored == retained)
    }
  }

  @Test func heldAdvancedSystemAndLegacyLabelCannotStrengthenTheFittedBasicSystem() throws {
    var commander = try pulseCommander(Equipment.navalEnergyUnit)
    let advanced = try #require(commander.fittedEquipment(at: .energy))
    try commander.storeEquipment(
      advanced, expectedRevision: #require(commander.equipmentInventory?.revision))
    #expect(throws: EMPPulseProfileError.missingEnergySystem) {
      try EMPPulseProfile.resolve(for: commander)
    }
    let basic = try #require(
      commander.equipmentInventory?.items.first { $0.node.key == "Basic Energy System" })
    try commander.fitEquipment(
      basic, at: .energy, expectedRevision: #require(commander.equipmentInventory?.revision))
    commander.equipment.insert(Equipment.navalEnergyUnit)
    let retained = commander
    let profile = try EMPPulseProfile.resolve(for: commander)
    #expect(profile.power == 32 && profile.range == 3000)
    #expect(
      commander.equipmentInventory?.items.contains { $0.id == advanced.id && $0.location == nil }
        == true)
    #expect(commander == retained)
  }

  @Test func actualUpgradeChangesPowerOnlyWhenItsFittedCanonicalGradePromotes() throws {
    var commander = try pulseCommander()
    let original = try #require(commander.fittedEquipment(at: .energy))
    try applyPulseEnergyUpgrade(.energyCapacity, commander: &commander)
    let capacityOnly = try EMPPulseProfile.resolve(for: commander)
    #expect(capacityOnly.power == 32)
    try applyPulseEnergyUpgrade(.energyRecharge, commander: &commander)
    let subgrade = try EMPPulseProfile.resolve(for: commander)
    #expect(subgrade.power == 32)
    for _ in 0..<6 { try applyPulseEnergyUpgrade(.energyRecharge, commander: &commander) }
    let promoted = try #require(commander.fittedEquipment(at: .energy))
    let profile = try EMPPulseProfile.resolve(for: commander)
    #expect(promoted.id == original.id && promoted.node == original.node)
    #expect(promoted.component?.origin == original.component?.origin)
    #expect(promoted.component?.grade == EquipmentModuleTemplates.energy.grades[1].identity)
    #expect(promoted.component?.receipts.count == 8)
    #expect(profile.power == 48 && profile.range == 4500)
  }

  @Test func existingExplicitLegacyMigrationRetainsItsActualEnergyGrade() throws {
    for (names, power) in [
      (["Extra Energy Unit"], 48.0),
      (["Extra Energy Unit", Equipment.navalEnergyUnit], 64.0),
    ] {
      var commander = Commander()
      commander.equipment.formUnion(names)
      #expect(throws: EMPPulseProfileError.missingEnergySystem) {
        try EMPPulseProfile.resolve(for: commander)
      }
      try commander.prepareEquipment()
      let before = commander
      let profile = try EMPPulseProfile.resolve(for: commander)
      #expect(profile.power == power && commander == before)
      #expect(
        commander.equipmentInventory?.items.filter { $0.location?.slot == .energy }.count == 1)
    }
  }

  @Test func malformedFittedGradesAndNonfiniteStatisticsCannotGrantPulsePower() throws {
    let valid = try pulseCommander()
    let inventory = try #require(valid.equipmentInventory)
    let fitted = try #require(valid.fittedEquipment(at: .energy))
    let component = try #require(fitted.component)
    var nonfinite = component.statistics
    nonfinite[.energyRecharge] = .nan
    let bad = [
      ComponentInstance(
        id: component.id, origin: component.origin, statistics: nonfinite),
      ComponentInstance(
        id: component.id, origin: component.origin,
        grade: .init(family: component.family, id: "unknown", version: 1)),
      ComponentInstance(
        id: component.id, origin: component.origin,
        grade: EquipmentModuleTemplates.energy.grades[2].identity),
    ]
    for malformed in bad {
      let replacement = OwnedEquipmentItem(
        id: fitted.id, node: fitted.node, provenance: fitted.provenance,
        component: malformed, location: fitted.location)
      var commander = valid
      commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.map { $0.id == fitted.id ? replacement : $0 })
      #expect(throws: (any Error).self) { try EMPPulseProfile.resolve(for: commander) }
    }
    let unchanged = try EMPPulseProfile.resolve(for: valid)
    #expect(unchanged.power == 32)
  }

  @Test func targetCentredFalloffClipsReserveAfterAttenuationAndRejectsInvalidInputs() throws {
    let profile = try EMPPulseProfile.resolve(for: pulseCommander())
    let primary = try profile.primaryDrain(remainingReserve: 100)
    let half = try profile.splashDrain(distance: 500, remainingReserve: 100)
    let clipped = try profile.splashDrain(distance: 500, remainingReserve: 5)
    let low = try profile.splashDrain(distance: 500, remainingReserve: 20)
    #expect(primary == 32 && half == 16 && clipped == 5 && low == 16)
    for distance in [1000.0, 1001, Double.greatestFiniteMagnitude] {
      let outside = try profile.splashDrain(distance: distance, remainingReserve: 100)
      #expect(outside == 0)
    }
    let zero = try profile.splashDrain(distance: 0, remainingReserve: 0)
    let coincident = try profile.splashDrain(distance: 0, remainingReserve: 100)
    #expect(zero == 0 && coincident == primary)
    for distance in [-1.0, .nan, .infinity, -.infinity] {
      #expect(throws: EMPPulseProfileError.invalidDistance) {
        try profile.splashDrain(distance: distance, remainingReserve: 100)
      }
    }
    for reserve in [-1.0, .nan, .infinity, -.infinity] {
      #expect(throws: EMPPulseProfileError.invalidReserve) {
        try profile.primaryDrain(remainingReserve: reserve)
      }
      #expect(throws: EMPPulseProfileError.invalidReserve) {
        try profile.splashDrain(distance: 1, remainingReserve: reserve)
      }
    }
  }
}
