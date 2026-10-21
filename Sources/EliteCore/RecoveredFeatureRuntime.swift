import Foundation

extension Commander {
  func quoteRecoveredFeature(lot: SalvageLotIdentity) throws -> RecoveredFeatureQuote {
    try validateEquipmentState()
    guard let inventory = equipmentInventory else {
      throw CommanderEquipmentError.incompleteState
    }
    return try RecoveredFeatureDevices.quote(
      lotID: lot, ledger: salvageLedger, inventory: inventory,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: performance))
  }

  /// The commit identity also addresses the permanent full-source settlement receipt.
  /// No identity is allocated by a preview, renderer, getter or acquisition-history adapter.
  @discardableResult
  mutating func applyRecoveredFeature(_ quote: RecoveredFeatureQuote) throws -> OwnedEquipmentItem {
    try validateEquipmentState()
    guard let inventory = equipmentInventory else {
      throw CommanderEquipmentError.incompleteState
    }
    let application = try RecoveredFeatureDevices.apply(
      quote: quote, commandID: UUID(), inventory: inventory, ledger: salvageLedger,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: performance))
    var candidate = self
    candidate.savedEquipmentInventory = application.inventory
    candidate.salvageLedger = application.ledger
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
    return application.item
  }
}

extension Game {
  /// Ordinary recovered devices use an explicit action in space as well as at a station.
  /// Collecting a lot leaves it in salvage custody until the player chooses this action.
  mutating func applyRecoveredFeature(_ quote: RecoveredFeatureQuote) throws {
    var candidate = self
    try candidate.commander.applyRecoveredFeature(quote)
    candidate.preserveEquipmentResourceFractions(from: self)
    candidate.notify("RECOVERED DEVICE FITTED")
    self = candidate
  }
}
