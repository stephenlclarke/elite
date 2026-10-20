import Foundation

extension Commander {
  /// Read-only exchange projection reuses the real portable-fit rules and existing IDs.
  func projectedEquipmentTransfer(to shipID: String) throws -> Commander {
    guard ShipCatalogue.ship(shipID)?.game != nil else { throw EquipmentRuntimeError.unavailable }
    if shipID == self.shipID { return self }
    var candidate = self
    if let inventory = equipmentInventory {
      try candidate.transferEquipment(to: shipID, hullID: inventory.activeHull)
    } else {
      candidate.shipID = shipID
    }
    return candidate
  }

  /// A bound fitting leaves with the sold hull. Portable devices keep their identities,
  /// component receipts and acquisition facts; only their current fitting address changes.
  mutating func transferEquipment(to shipID: String, hullID: UUID) throws {
    guard ShipCatalogue.ship(shipID)?.game != nil else { throw EquipmentRuntimeError.unavailable }
    var candidate = self
    candidate.shipID = shipID
    guard candidate.freightCargoValid else { throw EquipmentRuntimeError.incompatibleFit }
    guard let inventory = equipmentInventory else {
      self = candidate
      return
    }
    guard inventory.revision < UInt64.max else { throw OwnedEquipmentError.revisionExhausted }
    let portable = inventory.items.filter { $0.boundHull == nil }.map { item in
      OwnedEquipmentItem(
        id: item.id, node: item.node, provenance: item.provenance, component: item.component,
        location: item.location.map { .init(hullInstanceID: hullID, slot: $0.slot) },
        preferredSlot: item.preferredSlot, retainedLegacyState: item.retainedLegacyState,
        nativeRepairLoopCondition: item.nativeRepairLoopCondition)
    }
    let transferred = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: hullID, revision: inventory.revision + 1, items: portable)
    try transferred.validate(
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: hullID, performance: candidate.nativePerformance))
    candidate.savedEquipmentInventory = transferred
    // Quotes reuse the current hull identity and must not create transfer history.
    if inventory.activeHull != hullID {
      try candidate.transferAlienFittings(from: inventory.activeHull, to: hullID)
    }
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
  }
}
