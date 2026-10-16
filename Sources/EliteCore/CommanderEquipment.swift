import Foundation

enum CommanderEquipmentError: Error, Equatable {
  case invalidVersion, incompleteState, invalidRuntimeStatistics
  case unknownLegacyItem(String)
}

extension Commander {
  public var equipmentInventory: OwnedEquipmentInventory? { savedEquipmentInventory }
  public var equipmentPurchaseHistory: EquipmentPurchaseHistory? { savedEquipmentPurchaseHistory }
  public var equipmentOwnerID: UUID? { savedEquipmentInventory?.owner }
  public var hullInstanceID: UUID? { savedEquipmentInventory?.activeHull }
  public var salvageLedger: SalvageLedger {
    get { savedSalvageLedger ?? SalvageLedger() }
    set { savedSalvageLedger = newValue }
  }

  var equipmentStateValid: Bool { (try? validateEquipmentState()) != nil }

  func validateEquipmentState() throws {
    try validateEffectiveEquipmentStatistics()
    guard let inventory = savedEquipmentInventory else {
      guard savedEquipmentVersion == nil, savedEquipmentPurchaseHistory == nil else {
        throw CommanderEquipmentError.incompleteState
      }
      return
    }
    guard savedEquipmentVersion == 1 || savedEquipmentVersion == 2 else {
      throw CommanderEquipmentError.invalidVersion
    }
    guard let history = savedEquipmentPurchaseHistory, history.owner == inventory.owner else {
      throw CommanderEquipmentError.incompleteState
    }
    if savedEquipmentVersion == 1 {
      guard
        inventory.items.allSatisfy({ item in
          if case .missionIssue = item.provenance { return false }
          return item.preferredSlot == nil && item.retainedLegacyState == nil
            && item.node.family != EquipmentRuntimeCatalog.ammunitionFamily
        }),
        !history.paid.contains(where: { $0.node.family == EquipmentRuntimeCatalog.ammunitionFamily }
        ),
        !history.legacy.contains(where: {
          $0.source.node.family == EquipmentRuntimeCatalog.ammunitionFamily
        })
      else { throw EquipmentMigrationError.mixedRepresentations }
    } else {
      guard
        missiles
          == inventory.items.filter({
            $0.node == EquipmentRuntimeCatalog.standardMissile && $0.location != nil
          }).count
      else { throw EquipmentMigrationError.invalidCrosswalk }
    }
    try EquipmentPurchaseProgression.validateHistory(history, graph: EquipmentRuntimeCatalog.graph)
    try inventory.validate(
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: performance))
    try RecoveredFeatureDevices.validateRecoveredFeatures(
      inventory: inventory, ledger: salvageLedger)
  }

  /// Called explicitly at a runtime mutation boundary, never by a getter or decoder.
  /// IDs are allocated by that caller once and saved with the physical inventory.
  mutating func initializeEquipment(
    owner: UUID, hull: UUID, legacy: Bool, xyzzyGrant: Bool = false, allocatingItemIDs: () -> UUID
  ) throws {
    try validateEquipmentState()
    guard savedEquipmentInventory == nil else { return }
    var items: [OwnedEquipmentItem] = []
    var represented = Set<EquipmentNodeID>()
    func append(_ name: String, at slot: ComponentFittingSlot?, standard: Bool = false) throws {
      guard let node = EquipmentRuntimeCatalog.node(for: name) else {
        throw CommanderEquipmentError.unknownLegacyItem(name)
      }
      let id = allocatingItemIDs()
      let provenance: EquipmentAcquisitionProvenance
      if standard {
        provenance = .standard
      } else if capitalRewardClaimed && name == ShieldBooster.capital.equipmentName {
        provenance = .reward("elite-rank")
      } else if missionStage == .plansDelivered && name == Equipment.navalEnergyUnit {
        provenance = .reward("thargoid-plans")
      } else if xyzzyGrant {
        provenance = .xyzzy
      } else {
        provenance = legacy ? .legacyUnknown : .standard
      }
      let component = try migratedComponent(node: node, name: name, id: id)
      items.append(
        .init(
          id: id, node: node, provenance: provenance, component: component,
          location: slot.map { .init(hullInstanceID: hull, slot: $0) },
          boundHull: slot == .utility(.cargoExpansion) ? hull : nil))
      represented.insert(node)
    }
    let shield =
      equipment.contains("Elite Shield Module")
      ? "Elite Shield Module" : shieldBooster?.equipmentName ?? "Basic Shield"
    try append(shield, at: .shield, standard: shield == "Basic Shield")
    let navigation = navigationTier?.equipmentName ?? NavigationTier.basic.equipmentName
    try append(navigation, at: .navigation, standard: navigationTier == nil)
    let energy: String
    if equipment.contains(Equipment.navalEnergyUnit) {
      energy = Equipment.navalEnergyUnit
    } else if equipment.contains("Extra Energy Unit") {
      energy = "Extra Energy Unit"
    } else {
      energy = "Basic Energy System"
    }
    try append(energy, at: .energy, standard: energy == "Basic Energy System")
    if let core = targetingTier { try append(core.equipmentName, at: .targetingCore) }
    for mount in LaserMount.allCases {
      if let laser = laser(on: mount) {
        try append(
          laser.equipmentName, at: performance.supports(mount) ? .laser(mount) : nil,
          standard: laser == .pulse && mount == .front)
      }
    }
    if xyzzyGrant && equipment.contains(LaserKind.mining.equipmentName),
      performance.workTools?.contains(.miningLaser) == true
    {
      try append(LaserKind.mining.equipmentName, at: .utility(.miningLaser))
    }
    for (name, utility) in EquipmentRuntimeCatalog.utilities where equipment.contains(name) {
      let supported =
        utility == .salvageCutter
        ? performance.workTools?.contains(.salvageCutter) == true
        : utility != .cargoExpansion || performance.cargoExpansion > 0
      try append(name, at: supported ? .utility(utility) : nil)
    }
    for unit in 0..<fuelStorageUnits {
      try append(FuelStorage.equipmentName, at: .fuelStorage(unit))
    }
    guard (0...missileCapacity).contains(missiles) else {
      throw EquipmentMigrationError.invalidLegacyCount
    }
    for pylon in 0..<missiles { try append("Missile", at: .missilePylon(pylon)) }
    // Old sets can retain replaced devices. Preserve them as held items; aliases name
    // the same device and do not create a second physical copy.
    for name in equipment.sorted() where name != "Fuel" && name != "Missile" {
      guard let node = EquipmentRuntimeCatalog.node(for: name) else {
        throw CommanderEquipmentError.unknownLegacyItem(name)
      }
      if !represented.contains(node) { try append(name, at: nil) }
    }
    let inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: items)
    try inventory.validate(
      context: EquipmentRuntimeCatalog.context(
        owner: owner, hull: hull, performance: performance))
    let legacyEntitlements = try items.filter { $0.provenance == .legacyUnknown }.map { item in
      try EquipmentPurchaseProgression.legacyEntitlement(
        for: .init(id: item.id, node: item.node, provenance: item.provenance),
        owner: owner, graph: EquipmentRuntimeCatalog.graph)
    }
    savedEquipmentInventory = inventory
    savedEquipmentPurchaseHistory = .init(owner: owner, legacy: legacyEntitlements)
    savedEquipmentVersion = 2
  }

  private func migratedComponent(node: EquipmentNodeID, name: String, id: UUID) throws
    -> ComponentInstance?
  {
    guard let definition = EquipmentRuntimeCatalog.definition(for: node.family) else { return nil }
    let mapping = EquipmentModuleTemplates.legacyMapping(family: definition.family, key: name)
    if mapping == nil, let stock = EquipmentRuntimeCatalog.stockComponent(for: node, id: id) {
      return stock
    }
    let origin = mapping?.origin ?? definition.grades[0]
    let component = ComponentInstance(
      id: id, origin: origin, statistics: origin.statistics,
      grade: mapping?.grade ?? origin.identity)
    return try ComponentProgression.reconcileLoaded(component, definition: definition)
  }
}
