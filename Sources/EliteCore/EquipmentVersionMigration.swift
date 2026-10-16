import Foundation

extension Commander {
  /// Import the version-1 counter once at an explicit mutation boundary. Getters and
  /// version-2 loads never allocate rounds; an empty version-2 rack stays empty.
  mutating func migrateFiniteAmmunition(allocatingItemIDs: () -> UUID) throws {
    try validateEquipmentState()
    guard savedEquipmentVersion == 1 else { return }
    guard let inventory = equipmentInventory, let history = equipmentPurchaseHistory else {
      throw EquipmentMigrationError.incompleteVersionedState
    }
    guard (0...missileCapacity).contains(missiles) else {
      throw EquipmentMigrationError.invalidLegacyCount
    }
    let rounds = (0..<missiles).map { index in
      OwnedEquipmentItem(
        id: allocatingItemIDs(), node: EquipmentRuntimeCatalog.standardMissile,
        provenance: .legacyUnknown,
        location: .init(hullInstanceID: inventory.activeHull, slot: .missilePylon(index)))
    }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: nativePerformance)
    let next = try inventory.applyingBatch(
      items: inventory.items + rounds, expectedRevision: inventory.revision, context: context)
    let entitlements = try rounds.map { item in
      try EquipmentPurchaseProgression.legacyEntitlement(
        for: .init(id: item.id, node: item.node, provenance: item.provenance),
        owner: inventory.owner, graph: EquipmentRuntimeCatalog.graph)
    }
    var candidate = self
    candidate.savedEquipmentInventory = next
    candidate.savedEquipmentPurchaseHistory = .init(
      owner: history.owner, revision: history.revision, paid: history.paid,
      legacy: history.legacy + entitlements)
    candidate.savedEquipmentVersion = 2
    candidate.mirrorFittedEquipment()
    try candidate.validateEquipmentState()
    self = candidate
  }
}
