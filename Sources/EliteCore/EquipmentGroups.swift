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
      ("Fuel & Storage", ["Fuel", FuelStorage.equipmentName]),
      (
        "Lasers",
        ["Pulse Laser", "Mining Laser", "Beam Laser", "Military Laser", Equipment.navalLaser]
      ),
      ("Shield Boosters", ShieldBooster.allCases.map(\.equipmentName)),
      ("Targeting Computers", TargetingTier.allCases.map(\.equipmentName)),
      ("Navigation Computers", NavigationTier.allCases.map(\.equipmentName)),
      ("Energy Systems", ["Extra Energy Unit", Equipment.navalEnergyUnit]),
      ("Defence & Ordnance", ["Missile", "E.C.M. System", "Energy Bomb"]),
      ("Cargo & Collection", ["Large Cargo Bay", "Fuel Scoops"]),
      ("Travel", ["Galactic Hyperdrive"]),
      ("Emergency Equipment", ["Escape Pod"]),
    ]
    return groups.map { title, names in
      EquipmentSection(
        title: title,
        indices: names.compactMap { name in Equipment.all.firstIndex { $0.name == name } })
    }
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
