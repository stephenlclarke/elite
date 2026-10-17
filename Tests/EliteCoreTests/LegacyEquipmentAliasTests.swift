import Foundation
import Testing

@testable import EliteCore

struct LegacyEquipmentAliasTests {
  @Test func anActualVersionOneInventoryRetainsOnlyItsSavedHistoricalAliasOnce() throws {
    for names in [
      [Equipment.legacyDockingComputer], [TargetingTier.docking.equipmentName],
      [Equipment.legacyDockingComputer, TargetingTier.docking.equipmentName],
    ] {
      var commander = Commander()
      commander.missiles = 2
      commander.equipment.formUnion(names)
      try commander.prepareEquipment()
      let inventory = try #require(commander.equipmentInventory)
      let history = try #require(commander.equipmentPurchaseHistory)
      let oldItems = inventory.items.filter {
        $0.node != EquipmentRuntimeCatalog.standardMissile
          && $0.node.family != HyperspaceDriveDefinition.purchaseFamily
      }
      .map { item in
        OwnedEquipmentItem(
          id: item.id, node: item.node, provenance: item.provenance,
          component: item.component, location: item.location, boundHull: item.boundHull)
      }
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner, activeHull: inventory.activeHull,
        revision: 9, items: oldItems)
      commander.savedEquipmentPurchaseHistory = .init(
        owner: history.owner, revision: history.revision,
        paid: history.paid,
        legacy: history.legacy.filter { $0.source.node != EquipmentRuntimeCatalog.standardMissile })
      commander.savedEquipmentVersion = 1
      commander.equipment = Set([LaserKind.pulse.equipmentName] + names)
      #expect(commander.valid)
      let originalCore = try #require(commander.fittedEquipment(at: .targetingCore))
      let originalHistory = try #require(commander.equipmentPurchaseHistory)
      var allocated = 0
      try commander.migrateFiniteAmmunition {
        allocated += 1
        return UUID()
      }
      let core = try #require(commander.fittedEquipment(at: .targetingCore))
      #expect(core.id == originalCore.id && core.provenance == originalCore.provenance)
      #expect(core.component == originalCore.component && core.location == originalCore.location)
      #expect(
        core.retainedLegacyState?.originalEquipmentName
          == (names == [Equipment.legacyDockingComputer] ? Equipment.legacyDockingComputer : nil))
      #expect(
        commander.equipmentOwnerID == inventory.owner
          && commander.hullInstanceID == inventory.activeHull)
      #expect(
        commander.equipmentInventory?.revision == 10 && commander.missiles == 2 && allocated == 2)
      let nextHistory = try #require(commander.equipmentPurchaseHistory)
      #expect(
        nextHistory.paid == originalHistory.paid && nextHistory.revision == originalHistory.revision
      )
      #expect(
        Array(nextHistory.legacy.prefix(originalHistory.legacy.count)) == originalHistory.legacy)
      let migrated = commander
      try commander.prepareEquipment()
      #expect(commander.savedEquipmentVersion == 3 && commander.valid)
      #expect(commander.fittedEquipment(at: .targetingCore) == core)
      #expect(
        commander.equipmentInventory?.items.filter { !$0.isReservedStockDrive }
          == migrated.equipmentInventory?.items)
      #expect(commander.equipmentPurchaseHistory == migrated.equipmentPurchaseHistory)
      let once = commander
      try commander.prepareEquipment()
      #expect(commander == once)
    }
  }

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
