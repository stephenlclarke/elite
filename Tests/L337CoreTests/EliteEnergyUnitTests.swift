import Foundation
import Testing

@testable import L337Core

private func eliteEnergyShop() throws -> Game {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  let elite = try #require(Equipment.all.first { $0.name == Equipment.eliteEnergyUnit })
  let advanced = try #require(Equipment.all.first { $0.name == Equipment.navalEnergyUnit })
  let requiredTechnology = max(elite.requiredTechnologyLevel, advanced.requiredTechnologyLevel)
  game.commander.system = try #require(
    game.systems.first { $0.technology >= requiredTechnology }?.id)
  try game.commander.prepareEquipment(legacy: false)
  return game
}

private func purchaseEnergy(_ name: String, game: inout Game) throws {
  game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
  game.purchase()
  try #require(game.commander.fittedEquipment(at: .energy)?.node.key == name)
}

private func previousEnergyDefinition() -> ComponentFamilyDefinition {
  .init(
    family: EquipmentModuleTemplates.energyFamily, revision: 1,
    grades: Array(EquipmentModuleTemplates.energy.grades.prefix(3)),
    terminalLimits: [.energyCapacity: 1.3, .energyRecharge: 3.9])
}

struct EliteEnergyUnitTests {
  @Test func normalShopRequiresPaidEnergyPredecessorsAndDebitsEachActualPrice() throws {
    var game = try eliteEnergyShop()
    let elite = try #require(Equipment.all.first { $0.name == Equipment.eliteEnergyUnit })
    let intermediate = try #require(EquipmentRuntimeCatalog.node(for: "Extra Energy Unit"))
    let advanced = try #require(EquipmentRuntimeCatalog.node(for: Equipment.navalEnergyUnit))
    let untouched = game.commander
    #expect(throws: EquipmentPurchaseError.missingPrerequisite(intermediate)) {
      try game.quoteEquipmentPurchase(elite)
    }
    #expect(game.commander == untouched)
    try purchaseEnergy("Extra Energy Unit", game: &game)
    #expect(throws: EquipmentPurchaseError.missingPrerequisite(advanced)) {
      try game.quoteEquipmentPurchase(elite)
    }
    try purchaseEnergy(Equipment.navalEnergyUnit, game: &game)
    try purchaseEnergy(Equipment.eliteEnergyUnit, game: &game)
    #expect(game.commander.credits == untouched.credits - 403000)
    #expect(game.commander.equipmentPurchaseHistory?.paid.map(\.price) == [72000, 196000, 135000])
    #expect(game.commander.energyRechargeMultiplier == 4)
    #expect(game.commander.performance.energy == game.commander.nativePerformance.energy)
    #expect(
      game.commander.fittedComponent(at: .energy)?.grade
        == EquipmentModuleTemplates.energy.grades[3].identity)
    #expect(
      game.commander.equipmentInventory?.items.filter { $0.location?.slot == .energy }.count == 1)
    #expect(game.commander.commonEquipmentUnits >= 4 && game.commander.valid)
    let fitted = try #require(game.commander.fittedEquipment(at: .energy))
    #expect(Commander.commonEquipmentUnitCost(for: fitted) == 4)
    let restored = try JSONDecoder().decode(
      Commander.self, from: JSONEncoder().encode(game.commander))
    #expect(restored == game.commander && restored.energyRechargeMultiplier == 4)
  }

  @Test func ordinaryTechnologyGatesThePaidAdvancedAndEliteRows() throws {
    var game = Game(executive: false)
    let advanced = try #require(Equipment.all.first { $0.name == Equipment.navalEnergyUnit })
    let elite = try #require(Equipment.all.first { $0.name == Equipment.eliteEnergyUnit })
    #expect(advanced.price == 196000 && advanced.technology == 16)
    #expect(elite.price == 135000 && elite.technology == 13)
    #expect(!Equipment.isReward(advanced.name) && !Equipment.isReward(elite.name))
    for item in [advanced, elite] {
      game.commander.system = try #require(
        game.systems.first { $0.technology == item.requiredTechnologyLevel - 1 }?.id)
      #expect(!game.equipmentAvailable(item))
      game.commander.system = try #require(
        game.systems.first { $0.technology >= item.requiredTechnologyLevel }?.id)
      #expect(game.equipmentAvailable(item))
    }
  }

  @Test func xyzzyFitsEliteAndLaterNavalRewardRemainsOwnedWithoutDowngradingIt() throws {
    var game = Game(executive: false)
    game.screen = .status
    for key in "xyzzy" { game.key(String(key)) }
    let elite = try #require(game.commander.fittedEquipment(at: .energy))
    #expect(elite.node.key == Equipment.eliteEnergyUnit && elite.provenance == .xyzzy)
    #expect(game.commander.energyRechargeMultiplier == 4 && game.energy == 256)
    let profile = try EMPPulseProfile.resolve(for: game.commander)
    #expect(profile.power == 80 && profile.range == 7500 && profile.splashRadius == 2500)
    let paid = game.commander.equipmentPurchaseHistory?.paid
    try game.commander.grantEquipment(
      Equipment.navalEnergyUnit, at: .energy, provenance: .reward("thargoid-plans"))
    #expect(game.commander.fittedEquipment(at: .energy) == elite)
    #expect(game.commander.equipmentPurchaseHistory?.paid == paid)
    #expect(
      game.commander.equipmentInventory?.items.contains {
        $0.node.key == Equipment.navalEnergyUnit && $0.location == nil
          && $0.provenance == .reward("thargoid-plans")
      } == true)
    let before = try #require(game.commander.equipmentInventory)
    try game.commander.grantMaximumHardware()
    #expect(game.commander.equipmentInventory == before)
  }

  @Test func xyzzyKeepsCustomizedLowerGradeHardwareWhenSelectingTheTopStockGrade() throws {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let fitted = try #require(commander.fittedEquipment(at: .energy))
    let before = try #require(fitted.component)
    let upgrade = ComponentUpgrade(
      identity: .service(UUID()), boundComponent: before.id,
      origin: before.origin.identity, basisPoints: [.energyCapacity: 1500])
    let quote = try ComponentProgression.quote(
      component: before, item: upgrade, definition: EquipmentModuleTemplates.energy,
      inventoryRevision: 0)
    let application = try ComponentProgression.apply(
      quote, component: before, item: upgrade, definition: EquipmentModuleTemplates.energy,
      inventoryRevision: 0)
    var inventory = try #require(commander.equipmentInventory)
    try inventory.replaceGradedInstance(
      expected: fitted, application: application, expectedRevision: inventory.revision,
      sourceInventoryRevision: 0,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance))
    commander.savedEquipmentInventory = inventory
    commander.mirrorFittedEquipment()
    try commander.grantMaximumHardware()
    #expect(
      commander.fittedComponent(at: .energy)?.grade
        == EquipmentModuleTemplates.energy.grades[3].identity)
    let retained = try #require(commander.equipmentInventory?.items.first { $0.id == fitted.id })
    #expect(retained.location == nil && retained.component == application.component)
    #expect(commander.energyRechargeMultiplier == 4)
  }

  @Test func actualEliteFlightRechargesFourTimesStockWithoutChangingHullCapacity() throws {
    var game = try eliteEnergyShop()
    try game.commander.grantEquipment(
      Equipment.eliteEnergyUnit, at: .energy, provenance: .grant("recharge regression"))
    game.launch()
    game.bodies = []
    game.energy = 100
    let expected = 100 + 0.1 * game.commander.nativePerformance.recharge * 4
    game.tick(delta: 0.1)
    #expect(game.energy == expected)
    #expect(game.commander.performance.energy == game.commander.nativePerformance.energy)
  }

  @Test func oldClampedReceiptsAndEncodedLoadedValuesStayFixedButNewHeadroomCanPromote() throws {
    let old = previousEnergyDefinition()
    let origin = old.grades[2]
    let component = ComponentInstance(
      id: UUID(), origin: origin, statistics: [.energyCapacity: 1.29, .energyRecharge: 3.89])
    let upgrade = ComponentUpgrade(
      identity: .service(UUID()), boundComponent: component.id,
      origin: origin.identity, basisPoints: [.energyCapacity: 1500, .energyRecharge: 1500])
    let quote = try ComponentProgression.quote(
      component: component, item: upgrade, definition: old, inventoryRevision: 0)
    let application = try ComponentProgression.apply(
      quote, component: component, item: upgrade, definition: old, inventoryRevision: 0)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let input = try encoder.encode(application.component)
    let loaded = try JSONDecoder().decode(ComponentInstance.self, from: input)
    let loadedBytes = try encoder.encode(loaded)
    let reconciled = try ComponentProgression.reconcileLoaded(
      loaded, definition: EquipmentModuleTemplates.energy)
    #expect(reconciled == application.component && reconciled.statistics[.energyRecharge] == 3.9)
    #expect(
      reconciled.grade == origin.identity && reconciled.receipts == application.component.receipts)
    #expect(try encoder.encode(reconciled) == loadedBytes)
    #expect(throws: ComponentProgressionError.staleQuote) {
      try ComponentProgression.apply(
        quote, component: component, item: upgrade,
        definition: EquipmentModuleTemplates.energy, inventoryRevision: 0)
    }
    let fresh = ComponentUpgrade(
      identity: .service(UUID()), boundComponent: reconciled.id,
      origin: origin.identity, basisPoints: [.energyRecharge: 1500])
    let nextQuote = try ComponentProgression.quote(
      component: reconciled, item: fresh, definition: EquipmentModuleTemplates.energy,
      inventoryRevision: 1)
    let next = try ComponentProgression.apply(
      nextQuote, component: reconciled, item: fresh, definition: EquipmentModuleTemplates.energy,
      inventoryRevision: 1)
    #expect(next.component.grade == EquipmentModuleTemplates.energy.grades[3].identity)
    #expect(abs((next.component.statistics[.energyRecharge] ?? 0) - 4.35) < 1e-12)
    #expect(next.component.origin == component.origin)
    #expect(next.component.receipts.dropLast() == reconciled.receipts[...])
  }
}
