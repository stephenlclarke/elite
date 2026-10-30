import Foundation

extension Commander {
  static func commonEquipmentUnitCost(for node: EquipmentNodeID) -> Int {
    if node.family == EquipmentRuntimeCatalog.laserFamily
      || node.family == EquipmentRuntimeCatalog.ammunitionFamily
    {
      return 0
    }
    if node.family == EquipmentRuntimeCatalog.storageFamily { return 1 }
    if node.key == Equipment.legacyDockingComputer { return 0 }
    if node.key == "Extra Energy Unit" { return 2 }
    if node.key == Equipment.navalEnergyUnit { return 3 }
    if node.key == Equipment.eliteEnergyUnit { return 4 }
    return ShieldBooster.from(node.key) == nil ? 1 : 2
  }

  static func commonEquipmentUnitCost(for item: OwnedEquipmentItem) -> Int {
    EquipmentIssueTransactions.isIntrinsicFoundation(item) || isLegacyDockingItem(item)
      ? 0 : commonEquipmentUnitCost(for: item.node)
  }

  static func isLegacyDockingItem(_ item: OwnedEquipmentItem) -> Bool {
    guard let retained = item.retainedLegacyState, retained.valid, retained.pristine,
      retained.originalEquipmentName == Equipment.legacyDockingComputer,
      let node = EquipmentRuntimeCatalog.node(for: Equipment.legacyDockingComputer),
      item.node == node,
      item.location?.slot == .targetingCore
    else { return false }
    return true
  }

  func ownedGearCounts(fitted: Bool) -> ScriptValue {
    let items = equipmentInventory?.items.filter { ($0.location != nil) == fitted } ?? []
    return .object(
      Dictionary(
        grouping: items,
        by: { item in
          item.retainedLegacyState?.originalEquipmentName
            ?? (item.node == EquipmentRuntimeCatalog.standardMissile ? "Missile" : item.node.key)
        }
      ).mapValues { .integer(Int64($0.count)) })
  }

  /// A temporary physical projection supplies budget facts; it grants no rights or ownership.
  /// The sealed provider independently rechecks its physical plan at application.
  func equipmentFitBudget(projectedItems: [OwnedEquipmentItem]) throws
    -> EquipmentFitBudgetSnapshot
  {
    guard let inventory = equipmentInventory else {
      throw EquipmentMigrationError.incompleteVersionedState
    }
    let profile = try ShipAccommodationProfile(ship: ship)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: nativePerformance)
    let projected = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
      items: projectedItems)
    try projected.validate(context: context)
    var candidate = self
    candidate.savedEquipmentInventory = projected
    candidate.mirrorFittedEquipment()
    var costs = Dictionary(
      uniqueKeysWithValues: EquipmentRuntimeCatalog.graph.nodes.map {
        ($0.id, Self.commonEquipmentUnitCost(for: $0.id))
      })
    for item in projectedItems where Self.isLegacyDockingItem(item) {
      costs[item.node] = 0
    }
    let units = projectedItems.filter { $0.location != nil }.reduce(0) {
      $0 + Self.commonEquipmentUnitCost(for: $1)
    }
    let berths = candidate.accommodation.fittedBerths
    let occupied = candidate.cargoTonnes
    let cabinCargo =
      candidate.accommodation.fittedCabins.count * AccommodationFitting.tonnesPerCabin
    let fit = AccommodationFitting.evaluate(
      profile: profile, holdTonnes: candidate.standardCargoCapacity,
      freightTonnes: occupied - cabinCargo, otherFittedCargoTonnes: 0,
      otherFittedEquipmentUnits: units, cabins: candidate.accommodation.fittedCabins, berths: berths
    )
    return .init(
      equipmentCapacity: profile.equipmentUnits,
      reservedEquipmentUnits: candidate.accommodation.fittedCabins.count
        * AccommodationFitting.equipmentUnitsPerCabin,
      nodeEquipmentUnits: costs, projectedCargoCapacity: candidate.standardCargoCapacity,
      occupiedCargoTonnes: occupied,
      accommodationAllowed: candidate.accommodation.valid && fit.allowed
        && candidate.fuel <= candidate.fuelCapacity)
  }
}
