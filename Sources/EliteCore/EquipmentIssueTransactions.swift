import Foundation

public struct EquipmentIssueReceipt: Equatable, Sendable {
  public let command: UUID
  public let source: EquipmentIssueSource
  public let operation: EquipmentIssueOperation
  public let originalItems: [UUID]
  public let affectedItems: [UUID]
  public let consumedItems: Set<UUID>
  public let displacements: [EquipmentIssueDisplacement]
  fileprivate init(
    command: UUID, source: EquipmentIssueSource, operation: EquipmentIssueOperation,
    originalItems: [UUID], affectedItems: [UUID], consumedItems: Set<UUID>,
    displacements: [EquipmentIssueDisplacement]
  ) {
    self.command = command
    self.source = source
    self.operation = operation
    self.originalItems = originalItems
    self.affectedItems = affectedItems
    self.consumedItems = consumedItems
    self.displacements = displacements
  }
}

public struct EquipmentIssueApplication: Sendable {
  public let inventory: OwnedEquipmentInventory
  public let receipt: EquipmentIssueReceipt
  fileprivate init(inventory: OwnedEquipmentInventory, receipt: EquipmentIssueReceipt) {
    self.inventory = inventory
    self.receipt = receipt
  }
}

/// Read-only proposed physical layout; it carries no authority to publish or settle rights.
public struct EquipmentIssueSettlementProjection: Sendable {
  public let items: [OwnedEquipmentItem]
  fileprivate init(items: [OwnedEquipmentItem]) { self.items = items }
}

private struct EquipmentIssueSettlementPlan {
  let items: [OwnedEquipmentItem]
  let affected: [UUID]
  let operation: EquipmentIssueOperation
}

private struct EquipmentIssueFacts: Sendable {
  let inventory: OwnedEquipmentInventory
  let context: OwnedEquipmentContext
  let obligations: [EquipmentIssueObligationSnapshot]
  let budget: EquipmentFitBudgetSnapshot
  func validate(
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws {
    guard self.inventory.revision == inventory.revision else {
      throw OwnedEquipmentError.staleRevision
    }
    guard self.inventory == inventory else { throw OwnedEquipmentError.staleItem }
    guard self.context == context else { throw OwnedEquipmentError.invalidContext }
    guard self.obligations == obligations else { throw EquipmentIssueError.staleObligation }
    guard self.budget == budget else { throw EquipmentIssueError.invalidBudget }
  }
}

// Fileprivate facts also seal each synthesized memberwise initializer to this file.
public struct EquipmentIssueQuote: Sendable {
  fileprivate let request: EquipmentIssueRequest
  fileprivate let facts: EquipmentIssueFacts
}

public struct EquipmentIssueSettlementQuote: Sendable {
  fileprivate let command: UUID
  fileprivate let operation: EquipmentIssueSettlement
  fileprivate let obligation: EquipmentIssueObligationSnapshot
  fileprivate let facts: EquipmentIssueFacts
}

public struct EquipmentIssueFittingQuote: Sendable {
  fileprivate let command: UUID
  fileprivate let obligation: EquipmentIssueObligationSnapshot
  fileprivate let item: OwnedEquipmentItem
  fileprivate let destination: ComponentFittingLocation?
  fileprivate let replacing: OwnedEquipmentItem?
  fileprivate let facts: EquipmentIssueFacts
}

/// Pure physical candidates. The outer transaction publishes the matching issue ledger,
/// resources and events together; receipts never create a second inventory owner.
public enum EquipmentIssueTransactions {
  public static func quoteAdmission(
    request: EquipmentIssueRequest,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueQuote {
    _ = try admission(
      request, inventory: inventory, context: context, obligations: obligations, budget: budget)
    return .init(
      request: request,
      facts: .init(
        inventory: inventory, context: context,
        obligations: obligations, budget: budget))
  }

  public static func applyAdmission(
    quote: EquipmentIssueQuote,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueApplication {
    try quote.facts.validate(
      inventory: inventory, context: context, obligations: obligations, budget: budget)
    return try admission(
      quote.request, inventory: inventory, context: context, obligations: obligations,
      budget: budget)
  }

  public static func projectSettlement(
    operation: EquipmentIssueSettlement, obligation: EquipmentIssueObligationSnapshot,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot]
  ) throws -> EquipmentIssueSettlementProjection {
    let plan = try settlementPlan(
      operation: operation, obligation: obligation, inventory: inventory,
      context: context, obligations: obligations)
    let projected = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull,
      revision: inventory.revision, items: plan.items)
    try projected.validate(context: context)
    return .init(items: plan.items)
  }

  public static func quoteSettlement(
    command: UUID, operation: EquipmentIssueSettlement,
    obligation: EquipmentIssueObligationSnapshot, inventory: OwnedEquipmentInventory,
    context: OwnedEquipmentContext, obligations: [EquipmentIssueObligationSnapshot],
    budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueSettlementQuote {
    _ = try settlement(
      command: command, operation: operation, obligation: obligation,
      inventory: inventory, context: context, obligations: obligations, budget: budget)
    return .init(
      command: command, operation: operation, obligation: obligation,
      facts: .init(inventory: inventory, context: context, obligations: obligations, budget: budget)
    )
  }

  public static func applySettlement(
    quote: EquipmentIssueSettlementQuote,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueApplication {
    try quote.facts.validate(
      inventory: inventory, context: context, obligations: obligations, budget: budget)
    return try settlement(
      command: quote.command, operation: quote.operation, obligation: quote.obligation,
      inventory: inventory, context: context, obligations: obligations, budget: budget)
  }

  public static func quoteFitting(
    command: UUID, obligation: EquipmentIssueObligationSnapshot,
    item: OwnedEquipmentItem, destination: ComponentFittingLocation?,
    replacing: OwnedEquipmentItem?,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueFittingQuote {
    _ = try fitting(
      command: command, obligation: obligation, item: item, destination: destination,
      replacing: replacing, inventory: inventory, context: context, obligations: obligations,
      budget: budget)
    return .init(
      command: command, obligation: obligation, item: item, destination: destination,
      replacing: replacing,
      facts: .init(
        inventory: inventory, context: context,
        obligations: obligations, budget: budget))
  }

  public static func applyFitting(
    quote: EquipmentIssueFittingQuote,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueApplication {
    try quote.facts.validate(
      inventory: inventory, context: context, obligations: obligations, budget: budget)
    return try fitting(
      command: quote.command, obligation: quote.obligation, item: quote.item,
      destination: quote.destination, replacing: quote.replacing, inventory: inventory,
      context: context, obligations: obligations, budget: budget)
  }

  /// Shared by ammunition providers. Missing content does not remove retained obligations.
  static func validateObligations(
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot]
  ) throws {
    try inventory.validate(context: context)
    let actual = Dictionary(uniqueKeysWithValues: inventory.items.map { ($0.id, $0) })
    var originals: Set<UUID> = []
    var sources: Set<String> = []
    for obligation in obligations {
      guard obligation.valid,
        !(obligation.status == .released && !obligation.loan),
        !(obligation.status == .returned && !obligation.returnRemaining
          && !obligation.consumed.isEmpty),
        Set(obligation.displacements.map(\.location)).count == obligation.displacements.count,
        sources.insert(obligation.source.mission.uuidString + ":" + obligation.source.resource)
          .inserted
      else { throw EquipmentIssueError.staleObligation }
      for (index, id) in obligation.items.enumerated() {
        guard originals.insert(id).inserted else { throw EquipmentIssueError.identityMismatch }
        if obligation.status == .returned || obligation.consumed.contains(id)
          || obligation.legacyMissingItems.contains(id)
        {
          guard actual[id] == nil else { throw EquipmentIssueError.identityMismatch }
        } else {
          guard let item = actual[id] else { throw EquipmentIssueError.missingOriginal(id) }
          guard matches(item, obligation: obligation, index: index) else {
            throw EquipmentIssueError.sourceMismatch
          }
        }
      }
    }
    for item in inventory.items {
      guard case .missionIssue(let mission, let resource, let index, let digest) = item.provenance
      else { continue }
      guard
        let obligation = obligations.first(where: {
          $0.source.mission == mission && $0.source.resource == resource
            && $0.source.packDigest == digest
        }), obligation.status != .returned, obligation.items.indices.contains(index),
        obligation.items[index] == item.id, obligation.node == item.node,
        !obligation.consumed.contains(item.id), !obligation.legacyMissingItems.contains(item.id)
      else { throw EquipmentIssueError.sourceMismatch }
    }
  }

  static func activeLoan(
    for item: OwnedEquipmentItem,
    obligations: [EquipmentIssueObligationSnapshot]
  ) -> EquipmentIssueObligationSnapshot? {
    obligations.first { $0.loan && $0.status == .issued && $0.items.contains(item.id) }
  }

  private static func matches(
    _ item: OwnedEquipmentItem,
    obligation: EquipmentIssueObligationSnapshot, index: Int
  ) -> Bool {
    item.node == obligation.node
      && item.provenance
        == .missionIssue(
          mission: obligation.source.mission, resource: obligation.source.resource,
          index: index, packDigest: obligation.source.packDigest)
  }

  /// Only the three native basic foundations are intrinsic equipment-capacity exemptions.
  /// Acquisition provenance and actual fitted slot matter even when node identities match.
  public static func isIntrinsicFoundation(_ item: OwnedEquipmentItem) -> Bool {
    guard item.provenance == .standard,
      EquipmentRuntimeCatalog.graph.nodes.contains(where: {
        $0.id == item.node && $0.policy == .standardFoundation
      }), let slot = item.location?.slot
    else { return false }
    switch (item.node.family, slot) {
    case (EquipmentPurchaseCatalog.shields, .shield),
      (EquipmentPurchaseCatalog.energy, .energy),
      (EquipmentPurchaseCatalog.navigation, .navigation):
      return true
    default:
      return false
    }
  }

  private static func validateBudget(
    _ budget: EquipmentFitBudgetSnapshot,
    items: [OwnedEquipmentItem]
  ) throws {
    guard budget.valid, budget.accommodationAllowed,
      budget.occupiedCargoTonnes <= budget.projectedCargoCapacity,
      budget.reservedEquipmentUnits <= budget.equipmentCapacity
    else { throw EquipmentIssueError.invalidBudget }
    var used = budget.reservedEquipmentUnits
    for item in items where item.location != nil {
      if isIntrinsicFoundation(item) { continue }
      guard let cost = budget.nodeEquipmentUnits[item.node], cost <= budget.equipmentCapacity - used
      else { throw EquipmentIssueError.invalidBudget }
      used += cost
    }
  }

  private static func currentObligation(
    _ obligation: EquipmentIssueObligationSnapshot,
    in obligations: [EquipmentIssueObligationSnapshot]
  ) throws {
    guard obligations.contains(obligation) else { throw EquipmentIssueError.staleObligation }
  }

  private static func admission(
    _ request: EquipmentIssueRequest,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueApplication {
    try validateObligations(inventory: inventory, context: context, obligations: obligations)
    guard request.source.valid, (1...32).contains(request.devices.count),
      Set(request.devices.map(\.id)).count == request.devices.count,
      request.devices.enumerated().allSatisfy({ $0.offset == $0.element.index }),
      let node = request.devices.first?.node, request.devices.allSatisfy({ $0.node == node }),
      !obligations.contains(where: {
        $0.source.mission == request.source.mission && $0.source.resource == request.source.resource
      })
    else { throw EquipmentIssueError.invalidRequest }
    let retainedIdentities = Set(
      obligations.flatMap { obligation in
        obligation.items + obligation.displacements.map(\.item)
      })
    guard request.devices.allSatisfy({ !retainedIdentities.contains($0.id) }) else {
      throw EquipmentIssueError.identityMismatch
    }
    guard request.devices.count <= OwnedEquipmentInventory.maximumCount - inventory.items.count
    else { throw OwnedEquipmentError.capacity }
    guard EquipmentRuntimeCatalog.graph.nodes.contains(where: { $0.id == node })
    else { throw OwnedEquipmentError.unknownNode }
    var items = inventory.items
    for device in request.devices {
      if let original = device.originalEquipmentName {
        guard original == Equipment.legacyDockingComputer,
          EquipmentRuntimeCatalog.node(for: original) == device.node
        else { throw EquipmentIssueError.invalidRequest }
      }
      guard !items.contains(where: { $0.id == device.id }) else {
        throw OwnedEquipmentError.duplicateItem
      }
      if let preferred = device.preferredSlot {
        let compatible: Bool
        if node == EquipmentRuntimeCatalog.standardMissile {
          if case .missilePylon = preferred {
            compatible = preferred.valid
          } else {
            compatible = false
          }
        } else {
          compatible = context.nodes[node]?.slots.contains(preferred) == true
        }
        guard compatible else { throw OwnedEquipmentError.unsupportedSlot }
      }
      items.append(
        .init(
          id: device.id, node: node,
          provenance: .missionIssue(
            mission: request.source.mission, resource: request.source.resource,
            index: device.index, packDigest: request.source.packDigest),
          component: EquipmentRuntimeCatalog.stockComponent(for: node, id: device.id),
          boundHull: node == EquipmentRuntimeCatalog.node(for: "Large Cargo Bay")
            ? inventory.activeHull : nil,
          preferredSlot: device.preferredSlot,
          retainedLegacyState: device.originalEquipmentName.map {
            .init(conditionBasisPoints: 10000, modifications: [:], originalEquipmentName: $0)
          }))
    }
    var displacements: [EquipmentIssueDisplacement] = []
    if case .fitAll(let plans) = request.fitting {
      guard plans.count == request.devices.count,
        Set(plans.map(\.item)) == Set(request.devices.map(\.id)),
        Set(plans.map(\.location)).count == plans.count
      else { throw EquipmentIssueError.invalidRequest }
      for plan in plans {
        let index = try index(plan.item, in: items)
        try fit(
          index: index, destination: plan.location, replacing: plan.replacing,
          ownSource: request.source, items: &items, obligations: obligations,
          displacements: &displacements)
      }
    }
    try validateBudget(budget, items: items)
    let candidate = try inventory.applyingBatch(
      items: items, expectedRevision: inventory.revision, context: context)
    return .init(
      inventory: candidate,
      receipt: .init(
        command: request.command, source: request.source,
        operation: .issued, originalItems: request.devices.map(\.id),
        affectedItems: request.devices.map(\.id) + displacements.map(\.item),
        consumedItems: [], displacements: displacements))
  }

  private static func settlement(
    command: UUID, operation: EquipmentIssueSettlement,
    obligation: EquipmentIssueObligationSnapshot, inventory: OwnedEquipmentInventory,
    context: OwnedEquipmentContext, obligations: [EquipmentIssueObligationSnapshot],
    budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueApplication {
    let plan = try settlementPlan(
      operation: operation, obligation: obligation, inventory: inventory,
      context: context, obligations: obligations)
    try validateBudget(budget, items: plan.items)
    let candidate = try inventory.applyingBatch(
      items: plan.items, expectedRevision: inventory.revision, context: context)
    return .init(
      inventory: candidate,
      receipt: .init(
        command: command, source: obligation.source,
        operation: plan.operation, originalItems: obligation.items, affectedItems: plan.affected,
        consumedItems: obligation.consumed, displacements: obligation.displacements))
  }

  private static func settlementPlan(
    operation: EquipmentIssueSettlement, obligation: EquipmentIssueObligationSnapshot,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot]
  ) throws -> EquipmentIssueSettlementPlan {
    try validateObligations(inventory: inventory, context: context, obligations: obligations)
    try currentObligation(obligation, in: obligations)
    guard obligation.status == .issued else { throw EquipmentIssueError.staleObligation }
    var items = inventory.items
    var affected: [UUID] = []
    let receiptOperation: EquipmentIssueOperation
    switch operation {
    case .releaseLoan:
      guard obligation.loan else { throw EquipmentIssueError.invalidRequest }
      receiptOperation = .released
    case .returnOriginals:
      if !obligation.returnRemaining,
        let consumed = obligation.items.first(where: obligation.consumed.contains)
      {
        throw EquipmentIssueError.consumedOriginalRequired(consumed)
      }
      for id in obligation.items where !obligation.consumed.contains(id) {
        guard items.contains(where: { $0.id == id }) else {
          throw EquipmentIssueError.missingOriginal(id)
        }
        affected.append(id)
      }
      items.removeAll { affected.contains($0.id) }
      for displacement in obligation.displacements {
        let index = try index(displacement.item, in: items)
        let retained = items[index]
        guard activeLoan(for: retained, obligations: obligations) == nil else {
          throw EquipmentIssueError.unsupportedReplacement
        }
        // A portable hull exchange changes the restoration destination, never the history.
        let destination = ComponentFittingLocation(
          hullInstanceID: inventory.activeHull, slot: displacement.location.slot)
        guard !items.contains(where: { $0.id != retained.id && $0.location == destination }) else {
          throw OwnedEquipmentError.occupiedSlot
        }
        items[index] = retained.moved(to: destination)
        affected.append(retained.id)
      }
      receiptOperation = .returned
    }
    return .init(items: items, affected: affected, operation: receiptOperation)
  }

  private static func fitting(
    command: UUID, obligation: EquipmentIssueObligationSnapshot,
    item: OwnedEquipmentItem, destination: ComponentFittingLocation?,
    replacing: OwnedEquipmentItem?,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext,
    obligations: [EquipmentIssueObligationSnapshot], budget: EquipmentFitBudgetSnapshot
  ) throws -> EquipmentIssueApplication {
    try validateObligations(inventory: inventory, context: context, obligations: obligations)
    try currentObligation(obligation, in: obligations)
    guard obligation.status != .returned,
      let originalIndex = obligation.items.firstIndex(of: item.id),
      !obligation.consumed.contains(item.id),
      matches(item, obligation: obligation, index: originalIndex)
    else { throw EquipmentIssueError.sourceMismatch }
    var items = inventory.items
    let index = try index(item.id, in: items)
    guard items[index] == item else { throw OwnedEquipmentError.staleItem }
    guard item.location != destination else { throw OwnedEquipmentError.noChange }
    var displacements = obligation.displacements
    var affected = [item.id]
    if let destination {
      try fit(
        index: index, destination: destination, replacing: replacing, ownSource: obligation.source,
        items: &items, obligations: obligations, displacements: &displacements)
      if let replacing { affected.append(replacing.id) }
    } else {
      guard replacing == nil else { throw EquipmentIssueError.invalidRequest }
      items[index] = item.moved(to: nil)
    }
    try validateBudget(budget, items: items)
    let candidate = try inventory.applyingBatch(
      items: items, expectedRevision: inventory.revision, context: context)
    return .init(
      inventory: candidate,
      receipt: .init(
        command: command, source: obligation.source,
        operation: destination == nil ? .stored : .refitted, originalItems: obligation.items,
        affectedItems: affected, consumedItems: obligation.consumed, displacements: displacements))
  }

  private static func index(_ id: UUID, in items: [OwnedEquipmentItem]) throws -> Int {
    guard let index = items.firstIndex(where: { $0.id == id }) else {
      throw OwnedEquipmentError.staleItem
    }
    return index
  }

  private static func fit(
    index: Int, destination: ComponentFittingLocation,
    replacing: OwnedEquipmentItem?, ownSource: EquipmentIssueSource,
    items: inout [OwnedEquipmentItem], obligations: [EquipmentIssueObligationSnapshot],
    displacements: inout [EquipmentIssueDisplacement]
  ) throws {
    let item = items[index]
    guard item.retainedLegacyState?.pristine ?? true else {
      throw EquipmentIssueError.loanModificationRefused(item.id)
    }
    if [.targetingMining, .targetingSalvage].contains(destination.slot),
      !items.contains(where: { $0.location?.slot == .targetingCore })
    {
      throw OwnedEquipmentError.unsupportedSlot
    }
    if let occupied = items.firstIndex(where: { $0.location == destination }) {
      let actual = items[occupied]
      guard let replacing else { throw OwnedEquipmentError.occupiedSlot }
      guard actual == replacing else { throw OwnedEquipmentError.staleItem }
      if let loan = activeLoan(for: actual, obligations: obligations), loan.source != ownSource {
        throw EquipmentIssueError.foreignLoan(actual.id)
      }
      if let before = actual.component, let after = item.component,
        EquipmentRuntimeCatalog.reducesStatistics(after, from: before)
      {
        throw EquipmentIssueError.unsupportedReplacement
      }
      if destination.slot == .targetingCore,
        actual.node.family == EquipmentPurchaseCatalog.targeting,
        item.node.family == EquipmentPurchaseCatalog.targeting,
        let before = TargetingTier.from(actual.node.key),
        let after = TargetingTier.from(item.node.key), after < before
      {
        throw EquipmentIssueError.unsupportedReplacement
      }
      let sameIssue: Bool
      if case .missionIssue(let mission, let resource, _, let digest) = actual.provenance {
        sameIssue =
          EquipmentIssueSource(mission: mission, resource: resource, packDigest: digest)
          == ownSource
      } else {
        sameIssue = false
      }
      if !sameIssue && !displacements.contains(where: { $0.item == actual.id }) {
        guard displacements.count < 32,
          !displacements.contains(where: { $0.location == destination })
        else { throw EquipmentIssueError.unsupportedReplacement }
        displacements.append(.init(item: actual.id, location: destination))
      }
      items[occupied] = actual.moved(to: nil)
    } else if replacing != nil {
      throw OwnedEquipmentError.staleItem
    }
    items[index] = item.moved(to: destination)
  }
}
