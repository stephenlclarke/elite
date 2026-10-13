import Foundation

extension Display {
  public static func equipmentScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let cockpit = CockpitLayout(game: game, width: width, height: height)
    let layout = EquipmentLayout(game: game, width: width, height: height)
    let right = layout.left + layout.contentWidth
    frame.label("EQUIP SHIP", layout.left, 12, scale: layout.font, ink: .yellow)
    func rightLabel(_ text: String, y: Double, ink: Ink) -> BitmapLabel {
      .init(
        text: text, x: right - Double(text.count) * 6 * layout.font, y: y, scale: layout.font,
        ink: ink)
    }
    frame.labels.append(rightLabel("PRICE / STATUS", y: 12, ink: .yellow))
    for (index, mount) in LaserMount.allCases.enumerated() {
      let title = (mount == game.equipmentMount ? "> " : "  ") + mount.label
      frame.label(
        title, layout.left + Double(index) * layout.contentWidth / 4, 36, scale: layout.font,
        ink: mount == game.equipmentMount ? .cyan : .white)
    }
    let summaries = game.commander.laserMountSummary
    for index in 0..<2 {
      frame.label(
        summaries[index * 2] + "   " + summaries[index * 2 + 1], layout.left,
        56 + Double(index) * 16, scale: layout.font, ink: .cyan)
    }
    for visual in layout.start..<min(EquipmentGroups.rows.count, layout.start + layout.count) {
      let y = layout.listTop + Double(visual - layout.start) * layout.row
      switch EquipmentGroups.rows[visual] {
      case .heading(let title):
        frame.label(title.uppercased(), layout.left, y, scale: layout.font, ink: .yellow)
      case .item(let index):
        let item = Equipment.all[index]
        let fitted =
          LaserKind.from(item.name).map { game.commander.laser(on: game.equipmentMount) == $0 }
          ?? game.commander.equipment.contains(item.name)
        let available = item.technology <= game.currentSystem.technology
        frame.label(
          index == game.selection ? ">" : "", layout.left + 14, y, scale: layout.font, ink: .cyan)
        frame.label(
          item.name, layout.left + 32, y, scale: layout.font,
          ink: available || fitted ? .white : .red)
        var status = fitted ? "FITTED" : String(format: "%.1f CR", Double(item.price) / 10)
        if Equipment.isReward(item.name) {
          status = fitted ? "FITTED" : Equipment.rewardLabel(item.name).uppercased()
        } else if item.name == FuelStorage.equipmentName {
          status =
            "\(game.commander.fuelStorageUnits)/4 "
            + (game.commander.fuelStorageUnits == 4 ? "MAX" : "2000.0 CR")
        } else if !available && !fitted {
          status += " TL\(item.technology + 1)"
        }
        frame.labels.append(
          rightLabel(status, y: y, ink: fitted ? .green : (available ? .white : .red)))
      }
    }
    if Equipment.all.indices.contains(game.selection) {
      let item = Equipment.all[game.selection]
      var description = item.name + ": "
      if Equipment.isReward(item.name) {
        description += Equipment.rewardLabel(item.name) + ". Not for sale."
      } else if let laser = LaserKind.from(item.name) {
        description +=
          "Mount " + game.equipmentMount.label + ". "
          + (game.commander.laser(on: game.equipmentMount) == laser
            ? "Fitted here. " : "Return fits/replaces only this mount. ")
          + "Left/Right or click mount to choose."
      } else if item.name == FuelStorage.equipmentName {
        description +=
          "Fitted \(game.commander.fuelStorageUnits)/4. Total fuel \(game.commander.fuelCapacity / 10) LY. Refuel separately."
      } else if let booster = ShieldBooster.from(item.name) {
        description += String(
          format: "Front/rear capacity x%.4g. Recharge unchanged.", booster.multiplier)
      } else if item.technology > game.currentSystem.technology {
        description += "Unavailable: requires tech level \(item.technology + 1)."
      } else {
        description += "Up/Down: select. Return: buy. Scroll: browse."
      }
      let lines = MissionNotice.wrap(
        description, width: Int(layout.contentWidth / (6 * layout.font)))
      for (index, line) in lines.prefix(3).enumerated() {
        frame.label(
          line, layout.left, cockpit.dashboardTop - 62 + Double(index) * layout.row,
          scale: layout.font,
          ink: .cyan)
      }
    }
    return frame
  }
}

public struct EquipmentLayout: Sendable {
  public let contentWidth: Double
  public let left: Double
  public let listTop = 100.0
  public let font: Double
  public let row: Double
  public let count: Int
  public let start: Int
  public init(game: Game, width: Double, height: Double) {
    contentWidth = min(680, width - 48)
    left = (width - contentWidth) / 2
    font = width < 700 ? 1.0 : 1.25
    row = ceil(font * 7) + 9
    let top = CockpitLayout(game: game, width: width, height: height).dashboardTop
    count = max(2, Int((top - 182) / row))
    let selected = EquipmentGroups.rows.firstIndex(of: .item(game.selection)) ?? 1
    var candidate = max(0, min(selected - count + 2, EquipmentGroups.rows.count - count))
    // Keep an item's category visible even when the list is scrolled into its middle.
    if case .item = EquipmentGroups.rows[candidate], candidate > 0,
      selected < candidate + count - 1,
      case .heading = EquipmentGroups.rows[candidate - 1]
    {
      candidate -= 1
    }
    start = candidate
  }
}
extension Game {
  public mutating func equipmentClick(y: Double, x: Double? = nil) {
    guard screen == .equipment else { return }
    let layout = EquipmentLayout(game: self, width: viewportWidth, height: viewportHeight)
    if let x, y >= 32 && y < 52, x >= layout.left && x < layout.left + layout.contentWidth {
      equipmentMount = LaserMount.allCases[Int((x - layout.left) / (layout.contentWidth / 4))]
      return
    }
    guard y >= layout.listTop else { return }
    let row = Int((y - layout.listTop) / layout.row)
    let visual = layout.start + row
    if row < layout.count, EquipmentGroups.rows.indices.contains(visual),
      case .item(let index) = EquipmentGroups.rows[visual]
    {
      selection = index
    }
  }
}
