import Foundation

/// Explicit adapters between saved shop keys, physical fitting slots and component units.
/// The inventory and purchase graph keep their independent family namespaces.
enum EquipmentRuntimeCatalog {
  static let laserFamily = EquipmentFamilyID("laser")
  static let storageFamily = EquipmentFamilyID("fuel-storage")
  static let ammunitionFamily = EquipmentFamilyID("ammunition")
  static let standardMissile = EquipmentNodeID(family: ammunitionFamily, key: "missile-standard")
  static let utilities: [(String, ComponentUtility)] = [
    ("Fuel Scoops", .fuelScoops), ("E.C.M. System", .ecm), ("Escape Pod", .escapePod),
    ("Energy Bomb", .energyBomb), ("Large Cargo Bay", .cargoExpansion),
    ("Galactic Hyperdrive", .galacticHyperdrive), ("Salvage Cutter", .salvageCutter),
    (Equipment.empPirateBlaster, .empPirateBlaster),
  ]

  static func utilityFamily(_ utility: ComponentUtility) -> EquipmentFamilyID {
    .init("utility-" + utility.rawValue)
  }

  static var graph: EquipmentPurchaseGraph {
    let modular = EquipmentPurchaseCatalog.modularGraph()
    let lasers = LaserKind.allCases.map { kind in
      EquipmentPurchaseNode(
        id: .init(family: laserFamily, key: kind.equipmentName), displayName: kind.equipmentName,
        policy: .repeatable(maximumCount: kind == .mining ? 5 : 4))
    }
    let utilityNodes = utilities.map { name, utility in
      EquipmentPurchaseNode(id: .init(family: utilityFamily(utility), key: name), displayName: name)
    }
    let storage = EquipmentPurchaseNode(
      id: .init(family: storageFamily, key: FuelStorage.equipmentName),
      displayName: FuelStorage.equipmentName,
      policy: .repeatable(maximumCount: FuelStorage.maximumCount))
    let ammunition = EquipmentPurchaseNode(
      id: standardMissile, displayName: "Missile", policy: .repeatable(maximumCount: 256))
    return .init(
      revision: modular.revision,
      nodes: modular.nodes + lasers + utilityNodes + [storage, ammunition],
      aliases: modular.aliases + [
        .init(alias: .init(family: ammunitionFamily, key: "Missile"), canonical: standardMissile)
      ])
  }

  static func node(for savedKey: String) -> EquipmentNodeID? {
    if savedKey == "Missile" { return standardMissile }
    if let node = graph.nodes.first(where: { $0.id.key == savedKey }) { return node.id }
    return graph.aliases.first(where: { $0.alias.key == savedKey })?.canonical
  }

  static func definition(for family: EquipmentFamilyID) -> ComponentFamilyDefinition? {
    switch family {
    case EquipmentPurchaseCatalog.shields: EquipmentModuleTemplates.shield
    case EquipmentPurchaseCatalog.navigation: EquipmentModuleTemplates.navigation
    case EquipmentPurchaseCatalog.energy: EquipmentModuleTemplates.energy
    default: nil
    }
  }

  static func stockComponent(for node: EquipmentNodeID, id: UUID) -> ComponentInstance? {
    guard let definition = definition(for: node.family) else { return nil }
    let familyNodes = graph.nodes.filter { $0.id.family == node.family }
    guard let index = familyNodes.firstIndex(where: { $0.id == node }),
      definition.grades.indices.contains(index)
    else { return nil }
    let template = definition.grades[index]
    return .init(
      id: id, origin: template, statistics: template.statistics, grade: template.identity)
  }

  static func reducesStatistics(_ after: ComponentInstance, from before: ComponentInstance) -> Bool
  {
    before.statistics.contains { axis, value in
      guard let next = after.statistics[axis] else { return true }
      return axis.higherIsBetter ? next < value : next > value
    }
  }

  static func purchaseLocation(_ location: ComponentFittingLocation?) -> EquipmentFittingLocation? {
    guard let location else { return nil }
    let slot: String
    switch location.slot {
    case .laser(let mount): slot = "laser." + mount.rawValue
    case .utility(let utility): slot = "utility." + utility.rawValue
    case .fuelStorage(let unit): slot = "fuel-storage.\(unit)"
    case .missilePylon(let index): slot = "missile-pylon.\(index)"
    case .shield: slot = "shield"
    case .energy: slot = "energy"
    case .navigation: slot = "navigation"
    case .targetingCore: slot = "targeting.core"
    case .targetingMining: slot = "targeting.mining"
    case .targetingSalvage: slot = "targeting.salvage"
    default: return nil
    }
    return .init(hull: location.hullInstanceID, slot: slot)
  }

  static func slot(for node: EquipmentNodeID) -> ComponentFittingSlot? {
    switch node.family {
    case EquipmentPurchaseCatalog.shields: return .shield
    case EquipmentPurchaseCatalog.navigation: return .navigation
    case EquipmentPurchaseCatalog.energy: return .energy
    case EquipmentPurchaseCatalog.targeting: return .targetingCore
    case EquipmentPurchaseCatalog.mining: return .targetingMining
    case EquipmentPurchaseCatalog.salvage: return .targetingSalvage
    default:
      return utilities.first(where: { utilityFamily($0.1) == node.family }).map { .utility($0.1) }
    }
  }

  static func context(owner: UUID, hull: UUID, performance: ShipPerformance)
    -> OwnedEquipmentContext
  {
    let pylonCount = (1...32).contains(performance.missiles) ? performance.missiles : 0
    let pylonSlots = Set((0..<pylonCount).map(ComponentFittingSlot.missilePylon))
    var slots: Set<ComponentFittingSlot> = [
      .shield, .energy, .navigation, .targetingCore, .targetingMining, .targetingSalvage,
    ]
    slots.formUnion(
      LaserMount.allCases.filter { performance.supports($0) }.map(ComponentFittingSlot.laser))
    slots.formUnion(
      utilities.compactMap { _, utility -> ComponentFittingSlot? in
        if utility == .cargoExpansion && performance.cargoExpansion == 0 { return nil }
        if utility == .salvageCutter && performance.workTools?.contains(utility) != true {
          return nil
        }
        return .utility(utility)
      })
    if performance.workTools?.contains(.miningLaser) == true {
      slots.insert(.utility(.miningLaser))
    }
    slots.formUnion((0..<FuelStorage.maximumCount).map(ComponentFittingSlot.fuelStorage))
    slots.formUnion(pylonSlots)
    var nodes: [EquipmentNodeID: OwnedEquipmentNodeCapability] = [:]
    var limits: [EquipmentFamilyID: Int] = [:]
    for node in graph.nodes {
      let allowed: Set<ComponentFittingSlot>
      if node.id.family == laserFamily {
        var laserSlots = Set(LaserMount.allCases.map(ComponentFittingSlot.laser))
        if node.id.key == LaserKind.mining.equipmentName {
          laserSlots.insert(.utility(.miningLaser))
        }
        allowed = laserSlots
        limits[node.id.family] = performance.workTools?.contains(.miningLaser) == true ? 5 : 4
      } else if node.id.family == ammunitionFamily {
        allowed = pylonSlots
        limits[node.id.family] = pylonCount
      } else if node.id.family == storageFamily {
        allowed = Set((0..<FuelStorage.maximumCount).map(ComponentFittingSlot.fuelStorage))
        limits[node.id.family] = FuelStorage.maximumCount
      } else {
        allowed = slot(for: node.id).map { Set([$0]) } ?? []
        limits[node.id.family] = 1
      }
      nodes[node.id] = .init(
        slots: allowed, componentFamily: definition(for: node.id.family)?.family)
    }
    return .init(
      owner: owner, activeHull: hull, supportedSlots: slots, nodes: nodes,
      familyLimits: limits,
      definitions: Dictionary(
        uniqueKeysWithValues: EquipmentModuleTemplates.definitions.map { ($0.family, $0) }))
  }
}
