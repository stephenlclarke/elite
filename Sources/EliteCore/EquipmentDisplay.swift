import Foundation

extension Display {
  public static func equipmentScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let cockpit = CockpitLayout(game: game, width: width, height: height)
    let layout = EquipmentLayout(game: game, width: width, height: height)
    let accommodation = game.commander.accommodation
    let fittedCabins = accommodation.fitted.count
    let storedCabins = max(0, accommodation.ownedBerths.count - fittedCabins)
    let right = layout.left + layout.contentWidth
    frame.label("EQUIP SHIP", layout.left, 12, scale: layout.font, ink: .yellow)
    func rightLabel(_ text: String, y: Double, ink: Ink) -> BitmapLabel {
      .init(
        text: text, x: right - Double(text.count) * 6 * layout.font, y: y, scale: layout.font,
        ink: ink)
    }
    func equipmentName(_ item: Equipment) -> String {
      guard let node = EquipmentRuntimeCatalog.node(for: item.name) else { return item.name }
      return EquipmentRuntimeCatalog.graph.nodes.first { $0.id == node }?.displayName ?? item.name
    }
    func requirementLabel(_ requirement: String) -> String {
      for node in EquipmentRuntimeCatalog.graph.nodes {
        for action in ["Buy", "Fit"] where requirement == action + " " + node.id.key + " first" {
          return action + " " + node.displayName + " first"
        }
      }
      return requirement
    }
    for cell in layout.mounts {
      let selected = !game.equipmentWorkTool && cell.mount == game.equipmentMount
      let bounds = cell.bounds
      let ink: Ink = selected ? .cyan : .blue
      frame.stroke(bounds.x, bounds.y, bounds.maxX, bounds.y, ink)
      frame.stroke(bounds.maxX, bounds.y, bounds.maxX, bounds.maxY, ink)
      frame.stroke(bounds.maxX, bounds.maxY, bounds.x, bounds.maxY, ink)
      frame.stroke(bounds.x, bounds.maxY, bounds.x, bounds.y, ink)
      frame.label(
        cell.mount.label, bounds.x + 8, bounds.y + 6, scale: layout.font,
        ink: selected ? .cyan : .white)
      frame.label(
        game.commander.laser(on: cell.mount)?.equipmentName ?? "Empty",
        bounds.x + 8, bounds.y + 24, scale: layout.font,
        ink: selected ? .cyan : .white)
    }
    if let bounds = layout.workToolBounds {
      let ink: Ink = game.equipmentWorkTool ? .cyan : .blue
      frame.stroke(bounds.x, bounds.y, bounds.maxX, bounds.y, ink)
      frame.stroke(bounds.maxX, bounds.y, bounds.maxX, bounds.maxY, ink)
      frame.stroke(bounds.maxX, bounds.maxY, bounds.x, bounds.maxY, ink)
      frame.stroke(bounds.x, bounds.maxY, bounds.x, bounds.y, ink)
      frame.label("Mining work tool", bounds.x + 8, bounds.y + 6, scale: layout.font, ink: ink)
      frame.label(
        game.commander.fittedMiningWorkTool == nil ? "Empty" : "Mining Laser",
        bounds.x + 8, bounds.y + 24, scale: layout.font, ink: .white)
    }
    let buyingFor = game.equipmentWorkTool ? "Mining work tool" : game.equipmentMount.label
    func ownership(_ item: Equipment) -> (fitted: Bool, held: Bool) {
      if item.name == PassengerCabin.equipmentName {
        return (fittedCabins > 0, storedCabins > 0)
      }
      if let inventory = game.commander.equipmentInventory,
        let node = EquipmentRuntimeCatalog.node(for: item.name)
      {
        let slot =
          LaserKind.from(item.name).map { _ in
            game.equipmentWorkTool
              ? ComponentFittingSlot.utility(.miningLaser) : .laser(game.equipmentMount)
          } ?? EquipmentRuntimeCatalog.slot(for: node)
        let matches = inventory.items.filter { owned in
          if let component = owned.component,
            let stock = EquipmentRuntimeCatalog.stockComponent(for: node, id: owned.id)
          {
            return component.family == stock.family && component.grade == stock.grade
          }
          return owned.node == node
        }
        return (
          matches.contains { $0.location?.slot == slot && $0.location != nil },
          matches.contains { $0.location == nil }
        )
      }
      if game.equipmentWorkTool && LaserKind.from(item.name) != nil {
        return (false, false)
      }
      return (
        LaserKind.from(item.name).map { game.commander.laser(on: game.equipmentMount) == $0 }
          ?? game.commander.equipment.contains(item.name), false
      )
    }
    frame.label(
      "Buying for: " + buyingFor, layout.left, layout.buyingTop,
      scale: layout.font, ink: .cyan)
    frame.label(
      "Equipment", layout.left + 32, layout.listTop - 22,
      scale: layout.font, ink: .yellow)
    frame.labels.append(rightLabel("PRICE / STATUS", y: layout.listTop - 22, ink: .yellow))
    for visual in layout.start..<min(EquipmentGroups.rows.count, layout.start + layout.count) {
      let y = layout.listTop + Double(visual - layout.start) * layout.row
      switch EquipmentGroups.rows[visual] {
      case .heading(let title):
        frame.label(title.uppercased(), layout.left, y, scale: layout.font, ink: .yellow)
      case .item(let index):
        let item = Equipment.all[index]
        let owned = ownership(item)
        let fitted = owned.fitted
        let requirement = game.equipmentPurchaseRequirement(item)
        let available = requirement == nil
        frame.label(
          index == game.selection ? ">" : "", layout.left + 14, y, scale: layout.font, ink: .cyan)
        frame.label(
          equipmentName(item), layout.left + 32, y, scale: layout.font,
          ink: available || fitted ? .white : .red)
        var status =
          fitted
          ? "FITTED"
          : owned.held ? "STORED" : String(format: "%.1f CR", Double(game.shopPrice(item)) / 10)
        if Equipment.isReward(item.name) && !game.atPlugh {
          status =
            fitted
            ? "FITTED" : owned.held ? "STORED" : Equipment.rewardLabel(item.name).uppercased()
        } else if item.name == PassengerCabin.equipmentName {
          status = "\(fittedCabins) FIT / \(storedCabins) STORED"
        } else if item.name == FuelStorage.equipmentName {
          status =
            "\(game.commander.fuelStorageUnits)/4 "
            + (game.commander.fuelStorageUnits == 4
              ? "MAX" : String(format: "%.1f CR", Double(game.shopPrice(item)) / 10))
        } else if item.name == "Fuel" {
          status =
            game.commander.fuel == game.commander.fuelCapacity
            ? "FULL" : String(format: "Refill %.1f CR", Double(game.refillCost) / 10)
        }
        let statusInk: Ink = available ? .white : .red
        frame.labels.append(rightLabel(status, y: y, ink: fitted ? .green : statusInk))
      }
    }
    if game.messageTime > 0 {
      frame.label(
        game.message, layout.left, cockpit.dashboardTop - 82, scale: layout.font, ink: .orange)
    }
    if Equipment.all.indices.contains(game.selection) {
      let item = Equipment.all[game.selection]
      var description = equipmentName(item) + ": "
      let owned = ownership(item)
      if let requirement = game.equipmentPurchaseRequirement(item) {
        description += requirementLabel(requirement) + ". "
      }
      if LaserKind.from(item.name) != nil {
        description += "Buying for " + buyingFor + ". "
      }
      if let node = EquipmentRuntimeCatalog.node(for: item.name),
        let slot = EquipmentRuntimeCatalog.slot(for: node),
        let component = game.commander.fittedComponent(at: slot)
      {
        description +=
          "Fitted grade: "
          + (EquipmentModuleTemplates.displayName(for: component.grade) ?? "Unknown") + ". "
      } else if owned.fitted {
        description += "Fitted. "
      }
      if owned.held { description += "Stored item owned. " }
      if item.name == PassengerCabin.equipmentName {
        description +=
          String(format: "Price: project estimate %.1f CR. ", Double(game.shopPrice(item)) / 10)
          + "5t / 1 equipment unit. S: store empty cabin. R: refit stored cabin. Return: buy."
      } else if item.name == FuelStorage.equipmentName {
        description += "Fuel storage \(game.commander.fuelStorageUnits)/4. Refuel separately."
      } else if game.equipmentPurchaseRequirement(item) == nil {
        description += "Return: buy. A weaker purchase is stored."
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
  public let listTop: Double
  public let buyingTop: Double
  public let workToolBounds: CanvasRect?
  public let mounts: [(mount: LaserMount, bounds: CanvasRect)]
  public let font: Double
  public let row: Double
  public let count: Int
  public let start: Int
  public init(game: Game, width: Double, height: Double) {
    contentWidth = min(680, width - 48)
    left = (width - contentWidth) / 2
    font = GameTypography.scale
    let columns = width < 700 ? 2 : 4
    let columnWidth = contentWidth / Double(columns)
    let gridLeft = left
    mounts = LaserMount.allCases.enumerated().map { index, mount in
      (
        mount,
        CanvasRect(
          x: gridLeft + Double(index % columns) * columnWidth,
          y: 36 + Double(index / columns) * 52,
          width: columnWidth - 8, height: 44)
      )
    }
    let combatBottom = mounts.last!.bounds.maxY
    workToolBounds =
      game.commander.nativePerformance.workTools?.contains(.miningLaser) == true
      ? CanvasRect(x: left, y: combatBottom + 8, width: contentWidth - 8, height: 44) : nil
    let mountBottom = workToolBounds?.maxY ?? combatBottom
    buyingTop = mountBottom + 14
    listTop = mountBottom + 66
    row = ceil(font * 7) + 9
    let top = CockpitLayout(game: game, width: width, height: height).dashboardTop
    // Include the last row only when its complete glyph fits above the message reserve.
    // Compact cockpits may have room for the selected item without its category heading.
    let available = top - 82 - listTop - 7 * font
    count = max(1, Int(floor(available / row)) + 1)
    let selected = EquipmentGroups.rows.firstIndex(of: .item(game.selection)) ?? 1
    var candidate =
      count == 1
      ? selected : max(0, min(selected - count + 2, EquipmentGroups.rows.count - count))
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
    if let x {
      if let cell = layout.mounts.first(where: { $0.bounds.contains(.init(x, y)) }) {
        equipmentMount = cell.mount
        equipmentWorkTool = false
        return
      }
      if layout.workToolBounds?.contains(.init(x, y)) == true {
        equipmentWorkTool = true
        return
      }
      guard x >= layout.left && x < layout.left + layout.contentWidth else { return }
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
