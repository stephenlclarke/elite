import Foundation

extension Commander {
  var hyperspaceDrivePolicy: HyperspaceDrivePolicy? {
    let ratio = fittedComponent(at: .navigation)?.statistics[.jumpSpool] ?? 1
    return try? HyperspaceDrivePolicy.normal(
      component: fittedComponent(at: .drive),
      navigationSpoolMultiplier: ratio)
  }
  var usesModularDriveSaveVersion: Bool {
    savedEquipmentVersion == 3
      || equipmentInventory?.items.contains {
        $0.node.family == HyperspaceDriveDefinition.purchaseFamily
      } == true
  }
  /// Add one real standard device once at an existing explicit equipment-migration boundary.
  /// Stored items, earned component values, paid history and resources remain unchanged.
  mutating func migrateStockHyperspaceDrive(allocatingItemIDs: () -> UUID) throws {
    try validateEquipmentState()
    guard savedEquipmentVersion != 3 else { return }
    try migrateStockHyperspaceDriveCandidate(allocatingItemIDs: allocatingItemIDs)
  }

  /// Allocate migration values only after the public validation/current-version boundary.
  @inline(never)
  private mutating func migrateStockHyperspaceDriveCandidate(allocatingItemIDs: () -> UUID) throws {
    guard let inventory = equipmentInventory,
      !inventory.items.contains(where: {
        $0.node.family == HyperspaceDriveDefinition.purchaseFamily
      })
    else { throw CommanderEquipmentError.incompleteState }
    let id = allocatingItemIDs()
    let node = HyperspaceDriveDefinition.node(for: .basic)
    let item = OwnedEquipmentItem(
      id: id, node: node, provenance: .standard,
      component: EquipmentRuntimeCatalog.stockComponent(for: node, id: id),
      location: .init(hullInstanceID: inventory.activeHull, slot: .drive))
    var candidate = self
    candidate.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items + [item],
      expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner,
        hull: inventory.activeHull, performance: nativePerformance))
    candidate.savedEquipmentVersion = 3
    candidate.mirrorFittedEquipment()
    try candidate.validateEquipmentState()
    self = candidate
  }
}

extension Game {
  var hyperspaceMassLocked: Bool {
    guard let policy = commander.hyperspaceDrivePolicy else { return true }
    if case .immediate = policy.activation { return false }
    let scale = policy.massLockScale
    return bodies.contains { $0.hull != .cargo && $0.position.length < 600 * scale }
      || celestials.contains { $0.position.length < $0.radius * 4 * scale }
  }
}

enum HyperspaceDriveVersionedSave {
  static func rejectFields(_ bytes: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let inventory = root["savedEquipmentInventory"] as? [String: Any]
    let items = inventory?["items"] as? [[String: Any]] ?? []
    let drive = items.contains { item in
      let node = item["node"] as? [String: Any]
      let family = node?["family"] as? [String: Any]
      return (node?["family"] as? String == HyperspaceDriveDefinition.purchaseFamily.rawValue)
        || (family?["rawValue"] as? String == HyperspaceDriveDefinition.purchaseFamily.rawValue)
        || (node?["key"] as? String).map { key in
          HyperspaceDriveTier.allCases.contains { $0.label == key }
        } == true
    }
    guard (root["savedEquipmentVersion"] as? Int ?? 0) < 3, !drive,
      !(root["equipment"] as? [String] ?? []).contains(where: { key in
        HyperspaceDriveTier.allCases.contains { $0.label == key }
      })
    else { throw SaveError.invalidCommander }
  }
}

extension OwnedEquipmentItem {
  /// One born-stock Basic drive has a reserved migration place even after promotion.
  /// Purchased/reward devices and a matching label alone never qualify.
  var isReservedStockDrive: Bool {
    guard provenance == .standard,
      node == HyperspaceDriveDefinition.node(for: .basic),
      let component, component.id == id,
      component.origin == HyperspaceDriveDefinition.template(for: .basic)
    else { return false }
    return
      (try? ComponentProgression.validateLoaded(
        component, definition: HyperspaceDriveDefinition.componentDefinition)) != nil
  }
}
