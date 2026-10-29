import Foundation

extension Commander {
  mutating func grantMaximumHardware() throws {
    var candidate = self
    try candidate.prepareEquipment()
    for (name, slot) in [
      ("Elite Shield Module", ComponentFittingSlot.shield),
      (NavigationTier.military.equipmentName, .navigation),
      (Equipment.eliteEnergyUnit, .energy),
      (HyperspaceDriveTier.advanced.label, .drive),
      (TargetingTier.military.equipmentName, .targetingCore),
      ("Targeting: Mining Module", .targetingMining),
      ("Targeting: Salvage Module", .targetingSalvage),
    ] {
      try candidate.grantEquipment(name, at: slot, provenance: .xyzzy)
    }
    // The secret reset selects the top stock grade; customized lower-grade hardware stays owned.
    if candidate.fittedComponent(at: .energy)?.grade
      != EquipmentModuleTemplates.energy.grades[3].identity
    {
      guard let inventory = candidate.equipmentInventory,
        let elite = inventory.items.first(where: { $0.node.key == Equipment.eliteEnergyUnit })
      else { throw EquipmentRuntimeError.unavailable }
      try candidate.fitEquipment(elite, at: .energy, expectedRevision: inventory.revision)
    }
    for mount in LaserMount.allCases where candidate.performance.supports(mount) {
      try candidate.grantEquipment(Equipment.navalLaser, at: .laser(mount), provenance: .xyzzy)
    }
    for (name, utility) in EquipmentRuntimeCatalog.utilities {
      if utility == .cargoExpansion && candidate.performance.cargoExpansion == 0 { continue }
      if utility == .salvageCutter,
        candidate.performance.workTools?.contains(.salvageCutter) != true
      {
        continue
      }
      try candidate.grantEquipment(name, at: .utility(utility), provenance: .xyzzy)
    }
    if candidate.performance.workTools?.contains(.miningLaser) == true {
      try candidate.grantEquipment(
        LaserKind.mining.equipmentName, at: .utility(.miningLaser), provenance: .xyzzy)
    }
    for unit in 0..<FuelStorage.maximumCount {
      try candidate.grantEquipment(
        FuelStorage.equipmentName, at: .fuelStorage(unit), provenance: .xyzzy)
    }
    try candidate.grantMaximumMissiles()
    self = candidate
  }

  /// An explicit secret hardware grant, never a capability getter or unlimited shot.
  private mutating func grantMaximumMissiles() throws {
    guard let inventory = equipmentInventory else { throw CommanderEquipmentError.incompleteState }
    var items = inventory.items
    for index in 0..<missileCapacity {
      let location = ComponentFittingLocation(
        hullInstanceID: inventory.activeHull, slot: .missilePylon(index))
      if items.contains(where: { $0.location == location }) { continue }
      if let held = items.firstIndex(where: { item in
        if case .missionIssue = item.provenance { return false }
        return item.node == EquipmentRuntimeCatalog.standardMissile && item.location == nil
          && (item.retainedLegacyState?.pristine ?? true)
      }) {
        items[held] = items[held].moved(to: location)
      } else {
        items.append(
          .init(
            id: UUID(), node: EquipmentRuntimeCatalog.standardMissile,
            provenance: .xyzzy, location: location))
      }
    }
    if items == inventory.items { return }
    let next = try inventory.applyingBatch(
      items: items, expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: nativePerformance))
    var candidate = self
    candidate.savedEquipmentInventory = next
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
  }

  mutating func storeEquipment(
    _ item: OwnedEquipmentItem, expectedRevision: UInt64, command: UUID? = nil
  ) throws {
    try changeEquipmentFitting(
      item, destination: nil, expectedRevision: expectedRevision, command: command)
  }

  mutating func fitEquipment(
    _ item: OwnedEquipmentItem, at slot: ComponentFittingSlot, expectedRevision: UInt64,
    command: UUID? = nil
  ) throws {
    guard let inventory = equipmentInventory else { throw CommanderEquipmentError.incompleteState }
    try changeEquipmentFitting(
      item,
      destination: .init(hullInstanceID: inventory.activeHull, slot: slot),
      expectedRevision: expectedRevision, command: command)
  }

  /// Native own-issue fittings use the same sealed physical provider and retained
  /// restoration receipt as Lua. Personal actions cannot displace an active loan.
  private mutating func changeEquipmentFitting(
    _ item: OwnedEquipmentItem, destination: ComponentFittingLocation?, expectedRevision: UInt64,
    command: UUID?
  ) throws {
    try validateEquipmentState()
    guard var inventory = equipmentInventory else { throw CommanderEquipmentError.incompleteState }
    guard inventory.revision == expectedRevision else { throw OwnedEquipmentError.staleRevision }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull,
      performance: nativePerformance)
    let obligations = try equipmentIssueObligations()
    let occupied = destination.flatMap { location in
      inventory.items.first { $0.location == location }
    }
    var candidate = self
    if let issue = obligations.first(where: { $0.status == .issued && $0.items.contains(item.id) })
    {
      guard let command else { throw EquipmentIssueError.invalidRequest }
      let projection = inventory.items.map { current in
        if current.id == item.id { return current.moved(to: destination) }
        if current.id == occupied?.id { return current.moved(to: nil) }
        return current
      }
      let budget = try equipmentFitBudget(projectedItems: projection)
      let quote = try EquipmentIssueTransactions.quoteFitting(
        command: command, obligation: issue,
        item: item, destination: destination, replacing: occupied, inventory: inventory,
        context: context, obligations: obligations, budget: budget)
      let application = try EquipmentIssueTransactions.applyFitting(
        quote: quote, inventory: inventory,
        context: context, obligations: obligations, budget: budget)
      candidate.savedEquipmentInventory = application.inventory
      candidate.scriptState = try scriptState.applying(application.receipt)
    } else if let destination {
      if let occupied,
        EquipmentIssueTransactions.activeLoan(for: occupied, obligations: obligations) != nil
      {
        throw EquipmentIssueError.foreignLoan(occupied.id)
      }
      if AlienMissileDefinition.profile(for: item.node) != nil {
        let quote = try StandardAmmunitionTransactions.quoteLoad(
          item: item, destination: destination,
          inventory: inventory, context: context, obligations: obligations)
        let application = try StandardAmmunitionTransactions.applyLoad(
          quote: quote, inventory: inventory,
          context: context, obligations: obligations)
        candidate.savedEquipmentInventory = application.inventory
      } else {
        try inventory.fit(
          expected: item, at: destination, replacing: occupied,
          expectedRevision: expectedRevision, context: context)
        candidate.savedEquipmentInventory = inventory
      }
    } else {
      try inventory.store(expected: item, expectedRevision: expectedRevision, context: context)
      candidate.savedEquipmentInventory = inventory
    }
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
  }

  /// Mission transactions may treat absence as a no-op, but must not hide failed custody checks.
  @discardableResult mutating func removeFittedEquipment(_ name: String) throws -> Bool {
    guard var inventory = equipmentInventory else { return equipment.remove(name) != nil }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: performance)
    try validateEquipmentState()
    guard let node = EquipmentRuntimeCatalog.node(for: name) else {
      throw EquipmentRuntimeError.unavailable
    }
    guard let item = inventory.items.first(where: { $0.node == node && $0.location != nil }) else {
      return false
    }
    if let issue = try equipmentIssueObligations().first(where: {
      $0.status == .issued && $0.items.contains(item.id)
    }) {
      if issue.loan { throw EquipmentIssueError.foreignLoan(item.id) }
      throw EquipmentIssueError.unsupportedReplacement
    }
    try inventory.remove(expected: item, expectedRevision: inventory.revision, context: context)
    var candidate = self
    candidate.savedEquipmentInventory = inventory
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
    return true
  }

  mutating func grantMissionEquipment(_ name: String, digest: String) throws {
    guard let node = EquipmentRuntimeCatalog.node(for: name) else {
      throw EquipmentRuntimeError.unavailable
    }
    let slot =
      EquipmentRuntimeCatalog.slot(for: node)
      ?? LaserKind.from(name).map { _ in ComponentFittingSlot.laser(.front) }
    guard let slot else { throw EquipmentRuntimeError.noSlot }
    try grantEquipment(name, at: slot, provenance: .grant("mission-pack:" + digest))
  }

  /// Rewards/grants preserve their source and never create paid prerequisite history.
  mutating func grantEquipment(
    _ name: String, at slot: ComponentFittingSlot,
    provenance: EquipmentAcquisitionProvenance
  ) throws {
    var candidate = self
    try candidate.prepareEquipment()
    guard let node = EquipmentRuntimeCatalog.node(for: name),
      var inventory = candidate.equipmentInventory
    else { throw EquipmentRuntimeError.unavailable }
    if candidate.fittedEquipment(at: slot)?.node == node {
      guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
      self = candidate
      return
    }
    let obligations = try candidate.equipmentIssueObligations()
    if let installed = candidate.fittedEquipment(at: slot),
      EquipmentIssueTransactions.activeLoan(for: installed, obligations: obligations) != nil
    {
      throw EquipmentIssueError.foreignLoan(installed.id)
    }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: candidate.performance)
    let item: OwnedEquipmentItem
    if let held = inventory.items.first(where: { item in
      item.node == node && item.location == nil && (item.retainedLegacyState?.pristine ?? true)
        && !obligations.contains { $0.status == .issued && $0.items.contains(item.id) }
    }) {
      item = held
    } else {
      let id = UUID()
      item = .init(
        id: id, node: node, provenance: provenance,
        component: EquipmentRuntimeCatalog.stockComponent(for: node, id: id),
        boundHull: slot == .utility(.cargoExpansion) ? inventory.activeHull : nil)
      try inventory.admit(item, expectedRevision: inventory.revision, context: context)
    }
    let location = ComponentFittingLocation(hullInstanceID: inventory.activeHull, slot: slot)
    let occupied = inventory.items.first { $0.location == location }
    let weaker =
      occupied?.component.flatMap { before in
        item.component.map { EquipmentRuntimeCatalog.reducesStatistics($0, from: before) }
      } ?? false
    let lowerCore =
      occupied.flatMap { TargetingTier.from($0.node.key) }.flatMap { old in
        TargetingTier.from(item.node.key).map { $0 < old }
      } ?? false
    if !weaker && !lowerCore {
      try inventory.fit(
        expected: item, at: location, replacing: occupied,
        expectedRevision: inventory.revision, context: context)
    }
    candidate.savedEquipmentInventory = inventory
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
  }
}

extension Game {
  mutating func storeEquipment(_ item: OwnedEquipmentItem, expectedRevision: UInt64) throws {
    guard docked, ownedEquipmentEventCapacityAvailable else {
      throw EquipmentRuntimeError.unavailable
    }
    var candidate = self
    try candidate.commander.storeEquipment(
      item, expectedRevision: expectedRevision, command: UUID())
    candidate.preserveEquipmentResourceFractions(from: self)
    self = candidate
    emitScriptEvent(
      "equipment.changed", values: ["item": .string(item.id.uuidString), "fitted": .bool(false)])
  }

  mutating func fitEquipment(
    _ item: OwnedEquipmentItem, at slot: ComponentFittingSlot, expectedRevision: UInt64
  ) throws {
    guard docked, ownedEquipmentEventCapacityAvailable else {
      throw EquipmentRuntimeError.unavailable
    }
    var candidate = self
    try candidate.commander.fitEquipment(
      item, at: slot, expectedRevision: expectedRevision, command: UUID())
    candidate.preserveEquipmentResourceFractions(from: self)
    self = candidate
    emitScriptEvent(
      "equipment.changed", values: ["item": .string(item.id.uuidString), "fitted": .bool(true)])
  }
}
