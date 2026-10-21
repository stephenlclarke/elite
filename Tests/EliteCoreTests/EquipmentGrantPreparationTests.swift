import Foundation
import Testing

@testable import EliteCore

struct EquipmentGrantPreparationTests {
  @Test(arguments: [false, true])
  func matchingStockGrantPublishesPreparedOwnershipAndKeepsItOnRepeat(navigation: Bool) throws {
    var commander = grantPreparationCommander()
    try #require(commander.valid && commander.equipmentInventory == nil)
    let before = commander
    let name = navigation ? NavigationTier.basic.equipmentName : LaserKind.pulse.equipmentName
    let slot: ComponentFittingSlot = navigation ? .navigation : .laser(.front)
    try commander.grantEquipment(name, at: slot, provenance: .grant("stock-preparation-test"))
    let inventory = try #require(commander.equipmentInventory)
    let fitted = try #require(commander.fittedEquipment(at: slot))
    #expect(fitted.node == EquipmentRuntimeCatalog.node(for: name))
    #expect(fitted.provenance == .standard && inventory.items.contains(fitted))
    #expect(fitted.location == .init(hullInstanceID: inventory.activeHull, slot: slot))
    #expect(
      commander.equipmentOwnerID == inventory.owner
        && commander.hullInstanceID == inventory.activeHull)
    #expect(commander.equipmentPurchaseHistory?.owner == inventory.owner)
    #expect(commander.equipmentPurchaseHistory?.paid.isEmpty == true)
    #expect(commander.valid)
    #expect(commander.credits == before.credits && commander.cargo == before.cargo)
    #expect(commander.fuel == before.fuel && commander.missiles == before.missiles)
    #expect(commander.scriptState == before.scriptState && commander.contracts == before.contracts)
    #expect(commander.accommodation == before.accommodation)
    var expected = before
    expected.savedEquipmentInventory = commander.savedEquipmentInventory
    expected.savedEquipmentPurchaseHistory = commander.savedEquipmentPurchaseHistory
    expected.savedEquipmentVersion = commander.savedEquipmentVersion
    #expect(commander == expected)
    let first = commander
    try commander.grantEquipment(name, at: slot, provenance: .grant("repeat-stock-test"))
    #expect(commander == first && commander.fittedEquipment(at: slot)?.id == fitted.id)
    #expect(commander.equipmentOwnerID == inventory.owner)
    let decoded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(commander))
    #expect(decoded == first && decoded.fittedEquipment(at: slot)?.id == fitted.id)
    #expect(decoded.equipmentOwnerID == inventory.owner && decoded.valid)
  }

  @Test(arguments: [false, true])
  func alreadyCanonicalMatchingStockGrantIsAWholeCommanderNoOp(navigation: Bool) throws {
    var commander = grantPreparationCommander()
    try commander.prepareEquipment()
    try #require(commander.valid && commander.equipmentInventory != nil)
    let name = navigation ? NavigationTier.basic.equipmentName : LaserKind.pulse.equipmentName
    let slot: ComponentFittingSlot = navigation ? .navigation : .laser(.front)
    let fitted = try #require(commander.fittedEquipment(at: slot))
    let before = commander
    try commander.grantEquipment(name, at: slot, provenance: .grant("canonical-no-op-test"))
    #expect(commander == before && commander.fittedEquipment(at: slot) == fitted)
  }

  @Test(arguments: [false, true])
  func invalidGrantPublishesNeitherPreparationNorPartialNewEquipment(prepared: Bool) throws {
    var commander = grantPreparationCommander()
    if prepared { try commander.prepareEquipment() }
    let before = commander
    #expect(throws: EquipmentRuntimeError.unavailable) {
      try commander.grantEquipment(
        "Unknown equipment", at: .navigation, provenance: .grant("invalid"))
    }
    #expect(commander == before)
    #expect(throws: (any Error).self) {
      try commander.grantEquipment(
        TargetingTier.basic.equipmentName, at: .laser(.rear),
        provenance: .grant("wrong-slot"))
    }
    #expect(commander == before)
  }

  @Test func matchingStockGrantCannotPublishAnInvalidPreparedCommander() throws {
    var commander = grantPreparationCommander()
    try commander.prepareEquipment()
    commander.credits = -1
    let before = commander
    #expect(throws: EquipmentRuntimeError.incompatibleFit) {
      try commander.grantEquipment(
        NavigationTier.basic.equipmentName, at: .navigation,
        provenance: .grant("invalid-commander"))
    }
    #expect(commander == before)
  }
}

private func grantPreparationCommander() -> Commander {
  var commander = Commander()
  commander.credits = 2710
  commander.fuel = 43
  commander.cargo[0] = 3
  let id = UUID()
  var mission = ScriptInstance(
    id: id, definition: "test.grant-preparation/mission", version: "1.0.0",
    digest: String(repeating: "a", count: 64))
  mission.data = .object(["retained": .string("equipment preparation must preserve this mission")])
  mission.journal = ["Keep the original assignment."]
  commander.scriptState.instances[id] = mission
  return commander
}
