import Foundation

enum RecoveredEquipmentError: Error, Equatable {
  case missingComponent, invalidBinding, staleQuote, refusedSettlement
}

/// Pins relevant physical custody, rather than the clock or current resource charge.
/// Normal flight may continue while the player considers the before/after statistics.
struct RecoveredEquipmentQuote: Sendable {
  let owner: UUID
  let hull: UUID
  let item: OwnedEquipmentItem
  let ownedRevision: UInt64
  let sourceRevision: UInt64
  let effect: SalvageComponentUpgradeQuote
  let settlement: SalvageSettlementProposal
  fileprivate let sourceLot: SalvageLot
}

extension Commander {
  func previewRecoveredUpgrade(
    lot: SalvageLotIdentity, axis: SalvageUpgradeAxis, slot: ComponentFittingSlot
  ) throws -> SalvageComponentUpgradeQuote {
    try validateEquipmentState()
    guard let inventory = equipmentInventory,
      let item = fittedEquipment(at: slot), let component = item.component,
      let location = item.location,
      let version = UInt32(exactly: component.origin.identity.version)
    else { throw RecoveredEquipmentError.missingComponent }
    let source = salvageLedger
    let binding = SalvageTransactionBinding.equipment(
      target: .hull(instance: inventory.activeHull), expectedComponentInstanceID: component.id,
      templateVersion: version, axis: axis, feature: nil, location: location)
    return try SalvageComponentEffects.quote(
      lotID: lot, ledger: source, component: component,
      liveLocation: location, binding: binding)
  }

  func quoteRecoveredUpgrade(
    lot: SalvageLotIdentity, axis: SalvageUpgradeAxis, slot: ComponentFittingSlot
  ) throws -> RecoveredEquipmentQuote {
    let effect = try previewRecoveredUpgrade(lot: lot, axis: axis, slot: slot)
    guard let inventory = equipmentInventory, let item = fittedEquipment(at: slot) else {
      throw RecoveredEquipmentError.missingComponent
    }
    let source = salvageLedger
    let binding = effect.binding
    guard
      let settlement = source.prepareSettlement(
        command: UUID(), items: [lot], action: .fit(axis: axis, mount: nil), binding: binding)
    else { throw RecoveredEquipmentError.invalidBinding }
    return .init(
      owner: inventory.owner, hull: inventory.activeHull, item: item,
      ownedRevision: inventory.revision, sourceRevision: source.revision,
      effect: effect, settlement: settlement, sourceLot: settlement.items[0])
  }

  mutating func applyRecoveredUpgrade(_ quote: RecoveredEquipmentQuote) throws {
    try validateEquipmentState()
    guard var inventory = equipmentInventory, inventory.owner == quote.owner,
      inventory.activeHull == quote.hull, inventory.revision == quote.ownedRevision,
      inventory.items.contains(quote.item), let component = quote.item.component,
      quote.item.location?.hullInstanceID == inventory.activeHull,
      quote.item.location == quote.effect.binding.location
    else { throw RecoveredEquipmentError.staleQuote }
    var source = salvageLedger
    guard source.revision == quote.sourceRevision,
      quote.settlement.revision == source.revision,
      quote.settlement.items == [quote.sourceLot],
      quote.effect.item.identity == .salvage(quote.sourceLot.identity),
      quote.effect.binding == quote.settlement.binding
    else { throw RecoveredEquipmentError.staleQuote }
    let application = try ComponentProgression.apply(
      quote.effect.progression, component: component, item: quote.effect.item,
      definition: quote.effect.definition, inventoryRevision: source.revision)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: nativePerformance)
    try inventory.replaceGradedInstance(
      expected: quote.item, application: application,
      expectedRevision: inventory.revision, sourceInventoryRevision: source.revision,
      context: context)
    guard source.commitSettlement(quote.settlement) == .committed(quote.settlement) else {
      throw RecoveredEquipmentError.refusedSettlement
    }
    var candidate = self
    candidate.savedEquipmentInventory = inventory
    candidate.salvageLedger = source
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
  }
}

extension Game {
  /// Ordinary compatible recovered upgrades may be fitted immediately, including in flight.
  /// This explicit action does not run automatically when a scoop collects the source item.
  mutating func applyRecoveredUpgrade(_ quote: RecoveredEquipmentQuote) throws {
    var candidate = self
    try candidate.commander.applyRecoveredUpgrade(quote)
    candidate.preserveEquipmentResourceFractions(from: self)
    let after = candidate.commander.equipmentInventory?.items.first { $0.id == quote.item.id }?
      .component
    if let after, after.grade != quote.item.component?.grade,
      let grade = EquipmentModuleTemplates.displayName(for: after.grade)
    {
      candidate.notify("COMPONENT PROMOTED: " + grade.uppercased())
    } else {
      candidate.notify("RECOVERED UPGRADE FITTED")
    }
    self = candidate
  }
}
