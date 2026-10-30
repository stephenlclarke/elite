import Foundation
import Testing

@testable import L337Core

struct ScriptEquipmentLegacyAliasTests {
  @Test(arguments: [Equipment.legacyDockingComputer, TargetingTier.docking.equipmentName])
  func actualDeclaredLegacyAliasAloneRetainsItsOriginalZeroUnitCost(name: String) throws {
    let fixture = try GearScriptFixture(name: name)
    defer { fixture.clean() }
    let game = try fixture.game()
    let state = try #require(game.commander.scriptState.instances.values.first)
    let record = try #require(state.gearIssues["kit"])
    let item = try #require(
      game.commander.equipmentInventory?.items.first { $0.id == record.items[0] })
    let legacy = name == Equipment.legacyDockingComputer
    #expect(game.commander.valid && record.kind.name == name)
    #expect(item.node == EquipmentRuntimeCatalog.node(for: TargetingTier.docking.equipmentName))
    #expect(item.retainedLegacyState?.originalEquipmentName == (legacy ? name : nil))
    #expect(Commander.commonEquipmentUnitCost(for: item) == (legacy ? 0 : 1))
    let budget = try game.commander.equipmentFitBudget(
      projectedItems: try #require(game.commander.equipmentInventory).items)
    #expect(budget.nodeEquipmentUnits[item.node] == (legacy ? 0 : 1))
    #expect(game.commander.ownedGearCounts(fitted: true)[name] == .integer(1))
  }

  @Test func holdingAnActualLegacyAliasCannotMakeTheInstalledModernDockingModuleFree() throws {
    let fixture = try GearScriptFixture(
      name: Equipment.legacyDockingComputer,
      accepted: "{op='gear.issue',id='issue',gear='kit',fit=false}")
    defer { fixture.clean() }
    var game = Game(executive: false)
    try game.commander.grantEquipment(
      TargetingTier.docking.equipmentName, at: .targetingCore,
      provenance: .grant("modern-docking-fixture"))
    let modern = try #require(game.commander.fittedEquipment(at: .targetingCore))
    game.scriptPacks = [fixture.pack]
    let id = try game.acceptScriptMission(fixture.pack)
    let record = try #require(game.commander.scriptState.instances[id]?.gearIssues["kit"])
    let held = try #require(
      game.commander.equipmentInventory?.items.first { $0.id == record.items[0] })
    #expect(
      held.location == nil
        && held.retainedLegacyState?.originalEquipmentName == Equipment.legacyDockingComputer)
    #expect(game.commander.fittedEquipment(at: .targetingCore) == modern && game.commander.valid)
    let budget = try game.commander.equipmentFitBudget(
      projectedItems: try #require(game.commander.equipmentInventory).items)
    #expect(budget.nodeEquipmentUnits[modern.node] == 1)
    #expect(Commander.commonEquipmentUnitCost(for: modern) == 1)
  }
}
