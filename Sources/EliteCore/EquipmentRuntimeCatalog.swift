import Foundation

/// Explicit adapters between saved shop keys, physical fitting slots and component units.
/// The inventory and purchase graph keep their independent family namespaces.
enum EquipmentRuntimeCatalog {
  static let laserFamily = EquipmentFamilyID("laser")
  static let storageFamily = EquipmentFamilyID("fuel-storage")
  static let utilities: [(String, ComponentUtility)] = [
    ("Fuel Scoops", .fuelScoops), ("E.C.M. System", .ecm), ("Escape Pod", .escapePod),
    ("Energy Bomb", .energyBomb), ("Large Cargo Bay", .cargoExpansion),
    ("Galactic Hyperdrive", .galacticHyperdrive), ("Salvage Cutter", .salvageCutter),
  ]

  static func utilityFamily(_ utility: ComponentUtility) -> EquipmentFamilyID {
    .init("utility-" + utility.rawValue)
  }

  static var graph: EquipmentPurchaseGraph {
    let modular = EquipmentPurchaseCatalog.modularGraph()
    let lasers = LaserKind.allCases.map { kind in
      EquipmentPurchaseNode(
        id: .init(family: laserFamily, key: kind.equipmentName), displayName: kind.equipmentName,
        policy: kind == .naval ? .acquisitionOnly : .repeatable(maximumCount: 4))
    }
    let utilityNodes = utilities.map { name, utility in
      EquipmentPurchaseNode(id: .init(family: utilityFamily(utility), key: name), displayName: name)
    }
    let storage = EquipmentPurchaseNode(
      id: .init(family: storageFamily, key: FuelStorage.equipmentName),
      displayName: FuelStorage.equipmentName,
      policy: .repeatable(maximumCount: FuelStorage.maximumCount))
    return .init(
      revision: modular.revision, nodes: modular.nodes + lasers + utilityNodes + [storage],
      aliases: modular.aliases)
  }

  static func node(for savedKey: String) -> EquipmentNodeID? {
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
