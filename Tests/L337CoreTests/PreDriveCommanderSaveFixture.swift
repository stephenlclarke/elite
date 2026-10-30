import Foundation
import Testing

@testable import L337Core

/// Independent historical inventory; no current Commander is downgraded or stripped.
enum PreDriveCommanderSaveFixture {
  static func commander(emp: Bool = false) throws -> Commander {
    var commander = Commander()
    let owner = UUID()
    let hull = UUID()
    var fittings: [(String, ComponentFittingSlot)] = [
      ("Basic Shield", .shield), (NavigationTier.basic.equipmentName, .navigation),
      ("Basic Energy System", .energy), (LaserKind.pulse.equipmentName, .laser(.front)),
    ]
    for pylon in 0..<commander.missiles { fittings.append(("Missile", .missilePylon(pylon))) }
    if emp { fittings.append((Equipment.empPirateBlaster, .utility(.empPirateBlaster))) }
    var items: [OwnedEquipmentItem] = []
    for (name, slot) in fittings {
      let node = try #require(EquipmentRuntimeCatalog.node(for: name))
      let id = UUID()
      let component = try Commander.migratedComponent(node: node, name: name, id: id)
      items.append(
        .init(
          id: id, node: node,
          provenance: name == Equipment.empPirateBlaster
            ? .grant("Historical pre-drive EMP device") : .standard,
          component: component, location: .init(hullInstanceID: hull, slot: slot)))
    }
    commander.savedEquipmentInventory = try .init(owner: owner, activeHull: hull, items: items)
    commander.savedEquipmentPurchaseHistory = .init(owner: owner)
    commander.savedEquipmentVersion = 2
    commander.mirrorFittedEquipment()
    try #require(commander.valid)
    try #require(!commander.usesModularDriveSaveVersion && !commander.usesEconomyMiningSaveVersion)
    #expect(commander.usesEMPSaveVersion == emp)
    return commander
  }

  /// Only the newly allocated, validated stock drive may differ after strict historical reading.
  static func verifyMigration(from original: Commander, to loaded: Commander) throws {
    let before = try #require(original.equipmentInventory)
    let after = try #require(loaded.equipmentInventory)
    let oldIDs = Set(before.items.map(\.id))
    let additions = after.items.filter { !oldIDs.contains($0.id) }
    try #require(additions.count == 1)
    let drive = try #require(additions.first)
    try #require(drive.isReservedStockDrive && drive.location?.slot == .drive)
    #expect(after.owner == before.owner && after.activeHull == before.activeHull)
    for item in before.items { #expect(after.items.first { $0.id == item.id } == item) }
    #expect(loaded.equipmentPurchaseHistory == original.equipmentPurchaseHistory)
    var expected = original
    expected.savedEquipmentInventory = try before.applyingBatch(
      items: before.items + [drive], expectedRevision: before.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: before.owner, hull: before.activeHull, performance: original.nativePerformance))
    expected.savedEquipmentVersion = 3
    expected.mirrorFittedEquipment()
    #expect(loaded == expected && loaded.valid)
  }
}
