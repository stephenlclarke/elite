import Foundation

enum EquipmentRuntimeError: Error, Equatable {
  case unavailable, alreadyOwned, noSlot, staleCommander, incompatibleFit
}

/// The simulation owns the trusted offer and complete pre-mutation commander binding.
/// A later Save remains explicit; this transaction never chooses an autosave destination.
struct EquipmentRuntimePurchaseQuote: Sendable {
  let source: Commander
  let prepared: Commander
  let item: Equipment
  let mount: LaserMount
  let workTool: Bool
  let shop: String
  let location: ComponentFittingLocation?
  let request: EquipmentPurchaseRequest
  let purchase: EquipmentPurchaseQuote
}

extension Commander {
  func fittedEquipment(at slot: ComponentFittingSlot) -> OwnedEquipmentItem? {
    equipmentInventory?.items.first { $0.location?.slot == slot }
  }

  func fittedComponent(at slot: ComponentFittingSlot) -> ComponentInstance? {
    guard let inventory = equipmentInventory else { return nil }
    for index in inventory.items.indices {
      if Self.item(inventory.items[index], fits: slot) {
        return Self.component(of: inventory.items[index])
      }
    }
    return nil
  }

  @inline(never)
  private static func item(_ item: borrowing OwnedEquipmentItem, fits slot: ComponentFittingSlot)
    -> Bool
  {
    item.location?.slot == slot
  }

  @inline(never)
  private static func component(of item: borrowing OwnedEquipmentItem) -> ComponentInstance? {
    item.component
  }

  mutating func prepareEquipment(legacy: Bool = true) throws {
    if legacyOwnedEquipment == nil, savedEquipmentVersion == 3 {
      try validateEquipmentState()
      return
    }
    try prepareEquipmentMigration(legacy: legacy)
  }

  /// Current commanders never enter this owned candidate frame; migrations still publish atomically.
  @inline(never)
  private mutating func prepareEquipmentMigration(legacy: Bool) throws {
    var candidate = self
    try candidate.prepareEquipmentCandidate(legacy: legacy)
    self = candidate
  }

  /// All migration stages publish together, including finite ammunition and the stock drive.
  private mutating func prepareEquipmentCandidate(legacy: Bool) throws {
    if legacyOwnedEquipment != nil {
      try migrateLegacyOwnedEquipment(owner: UUID(), hull: UUID()) { UUID() }
      try migrateStockHyperspaceDrive { UUID() }
      return
    }
    guard equipmentInventory == nil else {
      try validateEquipmentState()
      if savedEquipmentVersion == 1 { try migrateFiniteAmmunition { UUID() } }
      try migrateStockHyperspaceDrive { UUID() }
      return
    }
    try initializeEquipment(owner: UUID(), hull: UUID(), legacy: legacy) { UUID() }
  }

  func purchaseSnapshot() throws -> EquipmentPurchaseSnapshot {
    guard let inventory = equipmentInventory else { throw CommanderEquipmentError.incompleteState }
    return .init(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
      funds: availableCredits,
      items: inventory.items.map {
        .init(
          id: $0.id, node: $0.node,
          location: EquipmentRuntimeCatalog.purchaseLocation($0.location), provenance: $0.provenance
        )
      })
  }

  /// Held items stay in physical custody; only fitted devices supply the legacy capability mirror.
  mutating func mirrorFittedEquipment() {
    guard let inventory = equipmentInventory else { return }
    equipment = Set(
      inventory.items.filter {
        $0.location != nil
          && !($0.node.key == NavigationTier.basic.equipmentName && $0.provenance == .standard)
      }.map(\.node.key)
        .filter { Equipment.validNames.contains($0) })
    var mounts = LaserMounts()
    for mount in LaserMount.allCases {
      mounts[mount] = fittedEquipment(at: .laser(mount)).flatMap { LaserKind.from($0.node.key) }
    }
    laserMounts = mounts
    fuelStorageUnits =
      inventory.items.filter {
        if case .fuelStorage = $0.location?.slot { return true }
        return false
      }.count
    if (savedEquipmentVersion ?? 0) >= 2 {
      missiles =
        inventory.items.filter {
          AlienMissileDefinition.profile(for: $0.node) != nil && $0.location != nil
        }.count
    }
  }

  mutating func acceptEquipmentPurchase(_ quote: EquipmentRuntimePurchaseQuote) throws -> Bool {
    guard self == quote.prepared, let inventory = equipmentInventory,
      let history = equipmentPurchaseHistory
    else { throw EquipmentRuntimeError.staleCommander }
    let application = try EquipmentPurchaseProgression.apply(
      quote.purchase, request: quote.request, snapshot: purchaseSnapshot(), history: history,
      graph: EquipmentRuntimeCatalog.graph)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: performance)
    let item = OwnedEquipmentItem(
      id: application.item.id, node: application.item.node, provenance: application.item.provenance,
      component: EquipmentRuntimeCatalog.stockComponent(
        for: application.item.node, id: application.item.id),
      boundHull: quote.location?.slot == .utility(.cargoExpansion) ? inventory.activeHull : nil)
    var items = inventory.items
    if let location = quote.location {
      items = items.map { $0.location == location ? $0.moved(to: nil) : $0 }
    }
    items.append(item.moved(to: quote.location))
    let next = try inventory.applyingBatch(
      items: items, expectedRevision: inventory.revision, context: context)
    var candidate = self
    candidate.savedEquipmentInventory = next
    candidate.savedEquipmentPurchaseHistory = application.history
    if !candidate.unlimitedCash { candidate.credits -= application.requiredDebit }
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
    return quote.location != nil
  }
}

extension Game {
  func quoteEquipmentPurchase(_ item: Equipment) throws -> EquipmentRuntimePurchaseQuote {
    guard stationAllowsEquipmentServices, equipmentAvailable(item),
      let authoritative = Equipment.all.first(where: { $0.name == item.name }),
      item.price == authoritative.price, item.technology == authoritative.technology,
      let node = EquipmentRuntimeCatalog.node(for: item.name)
    else { throw EquipmentRuntimeError.unavailable }
    var prepared = commander
    try prepared.prepareEquipment()
    let history = prepared.equipmentPurchaseHistory!
    let location = try equipmentPurchaseLocation(node, commander: prepared)
    let newID = UUID()
    let shop = "galaxy:\(commander.galaxy)/system:\(commander.system)"
    let request = EquipmentPurchaseRequest(
      transaction: UUID(), newItem: newID,
      offer: .init(node: node, price: shopPrice(item), shop: shop, revision: 1),
      location: EquipmentRuntimeCatalog.purchaseLocation(location))
    let purchase = try EquipmentPurchaseProgression.quote(
      request: request, snapshot: prepared.purchaseSnapshot(), history: history,
      graph: EquipmentRuntimeCatalog.graph)
    return .init(
      source: commander, prepared: prepared, item: item, mount: equipmentMount,
      workTool: equipmentWorkTool, shop: shop,
      location: location, request: request, purchase: purchase)
  }

  func equipmentPurchaseRequirement(_ item: Equipment) -> String? {
    if let grade = PassengerCabinGrade.equipment(item.name) {
      return passengerCabinQuote(grade).issues.first
    }
    guard equipmentAvailable(item) else {
      if item.name == AlienMissileDefinition.name {
        return "Research an alien artefact at PLUGH first"
      }
      return Equipment.isReward(item.name)
        ? Equipment.rewardLabel(item.name) : "Requires TL\(item.requiredTechnologyLevel)"
    }
    guard commander.equipmentInventory != nil, let history = commander.equipmentPurchaseHistory,
      let node = EquipmentRuntimeCatalog.node(for: item.name)
    else { return nil }
    do {
      _ = try equipmentPurchaseLocation(node, commander: commander)
      try EquipmentPurchaseProgression.validateEligibility(
        offer: .init(
          node: node, price: shopPrice(item),
          shop: "galaxy:\(commander.galaxy)/system:\(commander.system)", revision: 1),
        snapshot: commander.purchaseSnapshot(), history: history,
        graph: EquipmentRuntimeCatalog.graph)
      return nil
    } catch EquipmentRuntimeError.alreadyOwned {
      return "Already owned"
    } catch EquipmentRuntimeError.noSlot {
      return "Cannot fit selected destination"
    } catch EquipmentPurchaseError.missingPrerequisite(let required) {
      return "Buy " + required.key + " first"
    } catch EquipmentPurchaseError.missingFittedPrerequisite(let required) {
      return "Fit " + required.key + " first"
    } catch EquipmentPurchaseError.notForSale {
      return "Standard or acquisition hardware"
    } catch EquipmentPurchaseError.insufficientFunds {
      return "Not enough cash"
    } catch EquipmentPurchaseError.maximumCount {
      return "Ownership limit reached"
    } catch { return "Purchase unavailable" }
  }

  mutating func applyEquipmentPurchase(_ quote: EquipmentRuntimePurchaseQuote) throws -> Bool {
    guard stationAllowsEquipmentServices, commander == quote.source, equipmentMount == quote.mount,
      equipmentWorkTool == quote.workTool,
      equipmentAvailable(quote.item), shopPrice(quote.item) == quote.purchase.requiredDebit,
      quote.shop == "galaxy:\(commander.galaxy)/system:\(commander.system)"
    else { throw EquipmentRuntimeError.staleCommander }
    var candidate = self
    candidate.commander = quote.prepared
    let fitted = try candidate.commander.acceptEquipmentPurchase(quote)
    candidate.preserveEquipmentResourceFractions(from: self)
    self = candidate
    return fitted
  }

  private func equipmentPurchaseLocation(
    _ node: EquipmentNodeID, commander: Commander
  ) throws -> ComponentFittingLocation? {
    try commander.validateEquipmentState()
    guard let inventory = commander.equipmentInventory,
      let history = commander.equipmentPurchaseHistory,
      let policy = EquipmentRuntimeCatalog.graph.nodes.first(where: { $0.id == node })?.policy
    else { throw EquipmentRuntimeError.unavailable }
    if policy == .shop,
      history.paid.contains(where: { $0.node == node }),
      inventory.items.contains(where: { $0.node == node })
    {
      throw EquipmentRuntimeError.alreadyOwned
    }
    let slot: ComponentFittingSlot
    if node.family == EquipmentRuntimeCatalog.laserFamily {
      if equipmentWorkTool {
        guard node.key == LaserKind.mining.equipmentName,
          commander.performance.workTools?.contains(.miningLaser) == true
        else { throw EquipmentRuntimeError.noSlot }
        slot = .utility(.miningLaser)
      } else {
        guard commander.performance.supports(equipmentMount) else {
          throw EquipmentRuntimeError.noSlot
        }
        slot = .laser(equipmentMount)
      }
      guard commander.fittedEquipment(at: slot)?.node != node else {
        throw EquipmentRuntimeError.alreadyOwned
      }
    } else if AlienMissileDefinition.profile(for: node) != nil {
      guard
        let pylon = (0..<commander.missileCapacity).first(where: {
          commander.fittedEquipment(at: .missilePylon($0)) == nil
        })
      else { throw EquipmentRuntimeError.noSlot }
      slot = .missilePylon(pylon)
    } else if node.family == EquipmentRuntimeCatalog.storageFamily {
      guard
        let unit = (0..<FuelStorage.maximumCount).first(where: {
          commander.fittedEquipment(at: .fuelStorage($0)) == nil
        })
      else { throw EquipmentRuntimeError.noSlot }
      slot = .fuelStorage(unit)
    } else if let declared = EquipmentRuntimeCatalog.slot(for: node) {
      slot = declared
    } else {
      throw EquipmentRuntimeError.noSlot
    }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance)
    guard context.supportedSlots.contains(slot) else { throw EquipmentRuntimeError.noSlot }
    if let installed = commander.fittedEquipment(at: slot) {
      if EquipmentIssueTransactions.activeLoan(
        for: installed,
        obligations: try commander.equipmentIssueObligations()) != nil
      {
        throw EquipmentIssueError.foreignLoan(installed.id)
      }
      if let before = installed.component,
        let after = EquipmentRuntimeCatalog.stockComponent(for: node, id: before.id),
        EquipmentRuntimeCatalog.reducesStatistics(after, from: before)
      {
        return nil
      }
      if let old = TargetingTier.from(installed.node.key), let next = TargetingTier.from(node.key),
        next <= old
      {
        return nil
      }
    }
    return .init(hullInstanceID: inventory.activeHull, slot: slot)
  }

  static func equipmentResourceLevel(
    _ value: Double, from capacity: Double, to newCapacity: Double
  ) -> Double {
    guard value.isFinite, capacity.isFinite, capacity > 0, newCapacity.isFinite else { return 0 }
    return max(0, min(1, value / capacity)) * newCapacity
  }

  mutating func preserveEquipmentResourceFractions(from before: Game) {
    energy = Self.equipmentResourceLevel(
      before.energy, from: before.commander.performance.energy, to: commander.performance.energy)
    frontShield = Self.equipmentResourceLevel(
      before.frontShield, from: before.commander.shieldCapacity, to: commander.shieldCapacity)
    rearShield = Self.equipmentResourceLevel(
      before.rearShield, from: before.commander.rearShieldCapacity, to: commander.rearShieldCapacity
    )
  }
}
