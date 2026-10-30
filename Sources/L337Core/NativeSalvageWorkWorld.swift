import Foundation

/// Reconcile one section's current allocator with its reserved planned-index rows.
/// Discarded technology has no issued serial, source property or collection receipt.
enum NativeSalvageWorkWorld {
  static func reconcile(
    _ cycle: NativeSalvageWorkCycle, plan: SalvageLootPlan,
    in world: [AlienStorageWorldRecord]
  ) throws -> [AlienStorageWorldRecord] {
    guard cycle.progress.discarded.count == plan.items.count else {
      throw AlienStorageError.invalidJoin
    }
    return try world.map { record in
      guard case .lot(let lot) = record, lot.plan == cycle.inspection.id,
        cycle.progress.discarded.indices.contains(Int(lot.itemIndex)),
        cycle.progress.discarded[Int(lot.itemIndex)], case .unissued = lot.state
      else { return record }
      guard lot.issuedAt == nil,
        case .technology(let definition, _, _, _) = plan.items[Int(lot.itemIndex)].content,
        AlienModuleDefinition.isAttachmentDefinition(definition)
      else { throw AlienStorageError.invalidJoin }
      return .lot(
        .init(
          id: lot.id, owner: lot.owner, plan: lot.plan, itemIndex: lot.itemIndex,
          issuedAt: nil, state: .discarded(at: cycle.observedAt)))
    }
  }
}
