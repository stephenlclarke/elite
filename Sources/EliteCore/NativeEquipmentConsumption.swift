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
    guard let delta = try commander.scriptState.gearConsumptionDelta(for: removed) else { return }
    var staged = try commander.scriptState.applying(delta)
    guard let instance = staged.instances[delta.source.mission] else {
      throw EquipmentMigrationError.obligationMismatch
    }
    if instance.outcome == .active {
      guard staged.nextEvent < UInt64(Int64.max) - 1, staged.pendingEvents.count < 4096 else {
        throw EquipmentIssueError.invalidRequest
      }
      staged.nextEvent += 1
      staged.pendingEvents.append(
        ScriptEvent(
          sequence: staged.nextEvent, kind: "gear.consumed",
          instance: instance.id, values: delta.values, context: scriptEventContext(instance)))
    }
    commander.scriptState = staged
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
