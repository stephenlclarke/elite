public struct EquipmentSection: Sendable {
  public let title: String
  public let indices: [Int]
}
public enum EquipmentRow: Sendable, Equatable {
  case heading(String)
  case item(Int)
}
public enum EquipmentGroups {
  public static let sections: [EquipmentSection] = {
    let groups: [(String, [String])] = [
      ("Fuel Storage", ["Fuel", FuelStorage.equipmentName]),
      (
        "Lasers",
        ["Pulse Laser", "Mining Laser", "Beam Laser", "Military Laser", Equipment.navalLaser]
      ),
      ("Shield Modules", ShieldBooster.allCases.map(\.equipmentName)),
      (
        "Targeting Computers",
        TargetingTier.allCases.map(\.equipmentName)
          + ["Targeting: Mining Module", "Targeting: Salvage Module"]
      ),
      ("Navigation Computers", NavigationTier.allCases.map(\.equipmentName)),
      (
        "Energy Systems",
        ["Extra Energy Unit", Equipment.navalEnergyUnit, Equipment.eliteEnergyUnit]
      ),
      (
        "Defence & Ordnance",
        ["Missile", AlienMissileDefinition.name, "E.C.M. System", "Energy Bomb"]
      ),
      ("Electronic Weapons", [Equipment.empPirateBlaster]),
      ("Cargo & Collection", ["Large Cargo Bay", "Fuel Scoops", "Salvage Cutter"]),
      (
        "Travel",
        [
          HyperspaceDriveTier.intermediate.label, HyperspaceDriveTier.advanced.label,
          "Galactic Hyperdrive",
        ]
      ),
      ("Emergency Equipment", ["Escape Pod"]),
      ("Passenger Facilities", PassengerCabinGrade.allCases.map(\.equipmentName)),
    ]
    let catalogue = Dictionary(
      uniqueKeysWithValues: Equipment.all.enumerated().map { ($0.element.name, $0.offset) })
    var result: [EquipmentSection] = []
    for (title, names) in groups {
      result.append(EquipmentSection(title: title, indices: names.compactMap { catalogue[$0] }))
    }
    return result
  }()
  public static let rows: [EquipmentRow] = sections.flatMap { section in
    [.heading(section.title)] + section.indices.map(EquipmentRow.item)
  }
  public static let itemIndices = sections.flatMap(\.indices)
}
extension Game {
  mutating func moveEquipmentSelection(_ delta: Int) {
    let order = EquipmentGroups.itemIndices
    guard !order.isEmpty else { return }
    let current = order.firstIndex(of: selection) ?? 0
    selection = order[max(0, min(order.count - 1, current + delta))]
  }
}
