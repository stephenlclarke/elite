import Foundation

public struct StandardAmmunitionLoadQuote: Sendable {
  public let item: OwnedEquipmentItem
  public let destination: ComponentFittingLocation
  fileprivate let inventory: OwnedEquipmentInventory
  fileprivate let context: OwnedEquipmentContext
  fileprivate let obligations: [EquipmentIssueObligationSnapshot]
  // File-private pins seal the synthesized initializer to this implementation file.
}

public struct StandardAmmunitionConsumptionQuote: Sendable {
  public let source: PlayerAmmunitionSource
  public let removedItem: OwnedEquipmentItem?
  fileprivate let unlimited: Bool
  fileprivate let inventory: OwnedEquipmentInventory
  fileprivate let context: OwnedEquipmentContext
  fileprivate let obligations: [EquipmentIssueObligationSnapshot]
  // File-private pins seal the synthesized initializer to this implementation file.
}

public struct StandardAmmunitionLoadApplication: Sendable {
  public let inventory: OwnedEquipmentInventory
  public let fittedItem: OwnedEquipmentItem
  fileprivate init(inventory: OwnedEquipmentInventory, fittedItem: OwnedEquipmentItem) {
    self.inventory = inventory
    self.fittedItem = fittedItem
  }
}

public struct StandardAmmunitionApplication: Sendable {
  public let inventory: OwnedEquipmentInventory
  public let source: PlayerAmmunitionSource
  public let removedItem: OwnedEquipmentItem?
  fileprivate init(
    inventory: OwnedEquipmentInventory, source: PlayerAmmunitionSource,
    removedItem: OwnedEquipmentItem?
  ) {
    self.inventory = inventory
    self.source = source
    self.removedItem = removedItem
  }
}

/// Physical rounds use actual occupied pylons. Virtual use never consumes an issued original.
public enum StandardAmmunitionTransactions {
  public static func quoteLoad(
    item: OwnedEquipmentItem, destination: ComponentFittingLocation,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot]
  ) throws -> StandardAmmunitionLoadQuote {
    try EquipmentIssueTransactions.validateObligations(
      inventory: inventory, context: context,
      obligations: obligations)
    guard inventory.items.contains(item) else { throw StandardAmmunitionError.staleRound }
    try validateRound(item)
    guard item.location == nil else { throw StandardAmmunitionError.staleRound }
    guard item.retainedLegacyState?.pristine ?? true else {
      throw StandardAmmunitionError.unsupportedProfile
    }
    guard destination.hullInstanceID == inventory.activeHull,
      case .missilePylon = destination.slot,
      context.supportedSlots.contains(destination.slot),
      context.nodes[item.node]?.slots.contains(destination.slot) == true
    else { throw StandardAmmunitionError.unsupportedProfile }
    if EquipmentIssueTransactions.activeLoan(for: item, obligations: obligations) != nil {
      throw EquipmentIssueError.foreignLoan(item.id)
    }
    guard !inventory.items.contains(where: { $0.location == destination }) else {
      throw OwnedEquipmentError.occupiedSlot
    }
    let fitted = item.moved(to: destination)
    _ = try inventory.applyingBatch(
      items: inventory.items.map { $0.id == item.id ? fitted : $0 },
      expectedRevision: inventory.revision, context: context)
    return .init(
      item: item, destination: destination, inventory: inventory,
      context: context, obligations: obligations)
  }

  public static func applyLoad(
    quote: StandardAmmunitionLoadQuote,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot]
  ) throws -> StandardAmmunitionLoadApplication {
    guard inventory == quote.inventory, context == quote.context, obligations == quote.obligations
    else { throw StandardAmmunitionError.staleRound }
    _ = try quoteLoad(
      item: quote.item, destination: quote.destination, inventory: inventory,
      context: context, obligations: obligations)
    let fitted = quote.item.moved(to: quote.destination)
    let items = inventory.items.map { $0.id == fitted.id ? fitted : $0 }
    let updated = try inventory.applyingBatch(
      items: items, expectedRevision: inventory.revision,
      context: context)
    return .init(inventory: updated, fittedItem: fitted)
  }

  public static func quoteConsumption(
    unlimited: Bool, inventory: OwnedEquipmentInventory,
    context: OwnedEquipmentContext, obligations: [EquipmentIssueObligationSnapshot]
  ) throws
    -> StandardAmmunitionConsumptionQuote
  {
    try EquipmentIssueTransactions.validateObligations(
      inventory: inventory, context: context,
      obligations: obligations)
    if unlimited {
      return .init(
        source: .virtualUnlimited, removedItem: nil, unlimited: true,
        inventory: inventory, context: context, obligations: obligations)
    }
    let rounds = inventory.items.compactMap { item -> (Int, OwnedEquipmentItem)? in
      guard AlienMissileDefinition.profile(for: item.node) != nil,
        let location = item.location, location.hullInstanceID == inventory.activeHull,
        case .missilePylon(let index) = location.slot
      else { return nil }
      return (index, item)
    }
    guard let selected = rounds.max(by: { $0.0 < $1.0 })?.1 else {
      throw StandardAmmunitionError.noFiniteRound
    }
    try validateRound(selected)
    _ = try inventory.applyingBatch(
      items: inventory.items.filter { $0.id != selected.id },
      expectedRevision: inventory.revision, context: context)
    return .init(
      source: .physical(item: selected.id), removedItem: selected, unlimited: false,
      inventory: inventory, context: context, obligations: obligations)
  }

  public static func applyConsumption(
    quote: StandardAmmunitionConsumptionQuote,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot]
  ) throws -> StandardAmmunitionApplication {
    guard inventory == quote.inventory, context == quote.context, obligations == quote.obligations
    else { throw StandardAmmunitionError.staleRound }
    let checked = try quoteConsumption(
      unlimited: quote.unlimited, inventory: inventory,
      context: context, obligations: obligations)
    guard checked.source == quote.source, checked.removedItem == quote.removedItem else {
      throw StandardAmmunitionError.staleRound
    }
    guard let removed = checked.removedItem else {
      guard checked.source == .virtualUnlimited else {
        throw StandardAmmunitionError.invalidVirtualUse
      }
      return .init(inventory: inventory, source: .virtualUnlimited, removedItem: nil)
    }
    let updated = try inventory.applyingBatch(
      items: inventory.items.filter { $0.id != removed.id },
      expectedRevision: inventory.revision, context: context)
    // Mission consumption is joined by the caller before publishing the outer state.
    return .init(inventory: updated, source: .physical(item: removed.id), removedItem: removed)
  }

  private static func validateRound(_ item: OwnedEquipmentItem) throws {
    guard AlienMissileDefinition.profile(for: item.node) != nil,
      item.component == nil, item.boundHull == nil
    else {
      throw StandardAmmunitionError.unsupportedProfile
    }
  }
}
