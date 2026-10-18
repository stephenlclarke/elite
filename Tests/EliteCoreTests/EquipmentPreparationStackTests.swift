import Foundation
import Testing

@testable import EliteCore

struct EquipmentPreparationStackTests {
  @Test(arguments: [false, true])
  func currentPreparationAndDirectMigrationAreWholeCommanderNoOpsWithoutNewIDs(legacy: Bool) throws
  {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    try #require(commander.savedEquipmentVersion == 3 && commander.legacyOwnedEquipment == nil)
    let before = commander
    try commander.prepareEquipment(legacy: legacy)
    #expect(commander == before)
    var allocations = 0
    try commander.migrateStockHyperspaceDrive {
      allocations += 1
      return UUID()
    }
    #expect(allocations == 0 && commander == before)
  }

  @Test(arguments: [
    "missing-inventory", "missing-history", "foreign-history", "missing-drive",
    "missile-mirror", "runtime-statistics", "component-statistics", "unknown-held-node",
    "mixed-legacy",
  ])
  func currentVersionNeverBypassesMalformedStateOrRepairsItDuringPreparation(change: String) throws
  {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let inventory = try #require(commander.equipmentInventory)
    switch change {
    case "missing-inventory": commander.savedEquipmentInventory = nil
    case "missing-history": commander.savedEquipmentPurchaseHistory = nil
    case "foreign-history": commander.savedEquipmentPurchaseHistory = .init(owner: UUID())
    case "missing-drive":
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner,
        activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.location?.slot != .drive })
    case "missile-mirror": commander.missiles += 1
    case "runtime-statistics": commander.fuelStorageUnits = FuelStorage.maximumCount + 1
    case "component-statistics":
      let drive = try #require(commander.fittedEquipment(at: .drive))
      let original = try #require(drive.component)
      var statistics = original.statistics
      statistics[.jumpSpool] = .infinity
      let component = ComponentInstance(
        id: original.id, origin: original.origin,
        statistics: statistics, grade: original.grade, features: original.features,
        receipts: original.receipts)
      let item = OwnedEquipmentItem(
        id: drive.id, node: drive.node, provenance: drive.provenance,
        component: component, location: drive.location)
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner,
        activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.map { $0.id == drive.id ? item : $0 })
    case "unknown-held-node":
      let item = OwnedEquipmentItem(
        id: UUID(),
        node: .init(family: EquipmentRuntimeCatalog.laserFamily, key: "Unregistered laser"),
        provenance: .standard)
      commander.savedEquipmentInventory = try .init(
        owner: inventory.owner,
        activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items + [item])
    default: commander.legacyOwnedEquipment = .init()
    }
    try #require(commander.savedEquipmentVersion == 3)
    let before = commander
    #expect(throws: (any Error).self) { try commander.prepareEquipment() }
    #expect(commander == before)
    var allocations = 0
    #expect(throws: (any Error).self) {
      try commander.migrateStockHyperspaceDrive {
        allocations += 1
        return UUID()
      }
    }
    #expect(allocations == 0 && commander == before)
  }

  @Test func actualHistoricalVersionTwoMigratesOnceAndPreservesEveryExistingOwnedFact() throws {
    var commander = try PreDriveCommanderSaveFixture.commander()
    let before = commander
    try #require(
      commander.savedEquipmentVersion == 2 && commander.fittedEquipment(at: .drive) == nil)
    try commander.prepareEquipment()
    try PreDriveCommanderSaveFixture.verifyMigration(from: before, to: commander)
    let once = commander
    try commander.prepareEquipment()
    #expect(commander == once)
  }

  @Test func directVersionTwoIDCollisionRollsBackTheWholeMigrationAfterItsRealAllocation() throws {
    var commander = try PreDriveCommanderSaveFixture.commander()
    let before = commander
    let existingID = try #require(commander.equipmentInventory?.items.first?.id)
    var allocations = 0
    #expect(throws: OwnedEquipmentError.duplicateItem) {
      try commander.migrateStockHyperspaceDrive {
        allocations += 1
        return existingID
      }
    }
    #expect(allocations == 1 && commander == before && commander.savedEquipmentVersion == 2)
  }

  @Test func preparationRevisionRefusalKeepsTheActualHistoricalInventoryAndResources() throws {
    var commander = try PreDriveCommanderSaveFixture.commander()
    let inventory = try #require(commander.equipmentInventory)
    commander.savedEquipmentInventory = try .init(
      owner: inventory.owner,
      activeHull: inventory.activeHull, revision: .max, items: inventory.items)
    try commander.validateEquipmentState()
    let before = commander
    #expect(throws: OwnedEquipmentError.revisionExhausted) { try commander.prepareEquipment() }
    #expect(commander == before && commander.savedEquipmentVersion == 2)
    #expect(commander.missiles == before.missiles && commander.credits == before.credits)
    #expect(commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  }
}
