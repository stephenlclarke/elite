import Foundation

struct NativeConsumableApplication: Sendable {
  let inventory: OwnedEquipmentInventory
  let removedItem: OwnedEquipmentItem
}

extension Commander {
  /// Pure exact-item application. The outer native action stages Script rights and
  /// event allocation alongside this inventory before publishing the whole Game.
  func nativeConsumableApplication(_ name: String) throws -> NativeConsumableApplication? {
    guard ["Energy Bomb", "Escape Pod", "Galactic Hyperdrive"].contains(name) else {
      throw EquipmentRuntimeError.unavailable
    }
    try validateEquipmentState()
    guard let inventory = equipmentInventory else { throw CommanderEquipmentError.incompleteState }
    guard let node = EquipmentRuntimeCatalog.node(for: name),
      let item = inventory.items.first(where: { $0.node == node && $0.location != nil })
    else { return nil }
    let next = try inventory.applyingBatch(
      items: inventory.items.filter { $0.id != item.id },
      expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: nativePerformance))
    return .init(inventory: next, removedItem: item)
  }
}

extension Game {
  /// Capacity failure refuses the physical action; it cannot silently drop the
  /// consumption event or publish a partial issue ledger/allocator change.
  mutating func stageGearConsumption(_ removed: OwnedEquipmentItem) throws {
    var staged = commander.scriptState
    let values: [String: ScriptValue]
    if let delta = try staged.gearConsumptionDelta(for: removed) {
      staged = try staged.applying(delta)
      values = delta.values
    } else {
      guard EquipmentRuntimeCatalog.graph.nodes.contains(where: { $0.id == removed.node })
      else { throw EquipmentRuntimeError.unavailable }
      values = removed.scriptConsumptionValues
    }
    let recipients = orderedScriptInstances.compactMap { id in
      staged.instances[id].flatMap { $0.outcome == .active ? $0 : nil }
    }
    guard recipients.count <= 4096, staged.pendingEvents.count <= 4096 - recipients.count,
      staged.nextEvent <= UInt64(Int64.max) - 1 - UInt64(recipients.count)
    else { throw EquipmentIssueError.invalidRequest }
    commander.scriptState = staged
    for instance in recipients {
      commander.scriptState.nextEvent += 1
      let context = scriptEventContext(instance)
      commander.scriptState.pendingEvents.append(
        ScriptEvent(
          sequence: commander.scriptState.nextEvent, kind: "gear.consumed",
          instance: instance.id, values: values, context: context))
    }
  }

  /// Called only on an outer copied Game; all effects of the native action share
  /// its single publication, including a later docking or projectile refusal.
  mutating func consumeNativeEquipment(_ name: String) throws -> Bool {
    try commander.prepareEquipment()
    _ = try commander.equipmentIssueObligations()
    guard let application = try commander.nativeConsumableApplication(name) else { return false }
    commander.savedEquipmentInventory = application.inventory
    commander.mirrorFittedEquipment()
    try stageGearConsumption(application.removedItem)
    guard commander.valid else { throw EquipmentRuntimeError.incompatibleFit }
    return true
  }
}
