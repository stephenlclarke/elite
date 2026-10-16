import Foundation
import Testing

@testable import EliteCore

struct LegacyEquipmentAliasTests {
  @Test func onlyAnActualLegacyDockingNameRetainsTheHistoricalAliasFact() throws {
    for name in [Equipment.legacyDockingComputer, TargetingTier.docking.equipmentName] {
      var commander = Commander()
      commander.equipment.insert(name)
      try commander.prepareEquipment()
      let core = try #require(commander.fittedEquipment(at: .targetingCore))
      #expect(core.node == EquipmentRuntimeCatalog.node(for: TargetingTier.docking.equipmentName))
      #expect(
        core.retainedLegacyState?.originalEquipmentName
          == (name == Equipment.legacyDockingComputer ? Equipment.legacyDockingComputer : nil))
      let original = commander
      try commander.prepareEquipment()
      #expect(commander == original && commander.valid)
    }
  }

  @Test func theAliasFactRoundTripsAndMovesWithoutBecomingADeviceModification() throws {
    let node = try #require(EquipmentRuntimeCatalog.node(for: Equipment.legacyDockingComputer))
    let state = LegacyEquipmentState(
      conditionBasisPoints: 10000, modifications: [:],
      originalEquipmentName: Equipment.legacyDockingComputer)
    #expect(state.valid && state.pristine)
    let item = OwnedEquipmentItem(
      id: UUID(), node: node, provenance: .legacyUnknown,
      preferredSlot: .targetingCore, retainedLegacyState: state)
    let restored = try JSONDecoder().decode(
      OwnedEquipmentItem.self, from: JSONEncoder().encode(item))
    #expect(restored == item)
    let moved = item.moved(to: .init(hullInstanceID: UUID(), slot: .targetingCore))
    #expect(moved.retainedLegacyState == state && moved.moved(to: nil) == item)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    object.removeValue(forKey: "originalEquipmentName")
    let old = try JSONDecoder().decode(
      LegacyEquipmentState.self,
      from: JSONSerialization.data(withJSONObject: object))
    #expect(old.originalEquipmentName == nil && old.pristine)
  }

  @Test func anAliasCannotDescribeADifferentDeviceOrAnArbitraryDiscountFlag() throws {
    let owner = UUID()
    let hull = UUID()
    let state = LegacyEquipmentState(
      conditionBasisPoints: 10000, modifications: [:],
      originalEquipmentName: Equipment.legacyDockingComputer)
    let wrong = OwnedEquipmentItem(
      id: UUID(), node: EquipmentRuntimeCatalog.standardMissile,
      provenance: .legacyUnknown, retainedLegacyState: state)
    #expect(throws: OwnedEquipmentError.invalidStructure) {
      try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [wrong])
    }
    #expect(
      !LegacyEquipmentState(
        conditionBasisPoints: 10000, modifications: [:],
        originalEquipmentName: "free-equipment"
      ).valid)
    let request = IssuedDeviceRequest(
      id: UUID(), node: EquipmentRuntimeCatalog.standardMissile,
      index: 0, preferredSlot: nil)
    #expect(request.originalEquipmentName == nil)
  }
}
