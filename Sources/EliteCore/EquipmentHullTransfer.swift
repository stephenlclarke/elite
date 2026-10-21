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
      guard candidate.accommodationValid else { throw EquipmentRuntimeError.incompatibleFit }
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
      guard candidate.accommodationValid else { throw EquipmentRuntimeError.incompatibleFit }
      self = candidate
      return
    }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: hullID, performance: candidate.nativePerformance)
    let transferred = try inventory.transferringPortableItems(to: context)
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
