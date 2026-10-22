import Foundation

public enum CommodityCategory: String, Sendable, CaseIterable {
  case agricultural = "Agricultural"
  case consumer = "Consumer"
  case industrial = "Industrial"
  case materials = "Materials"
  case restricted = "Restricted cargo"
  public var ink: Ink {
    switch self {
    case .agricultural: .green
    case .consumer: .cyan
    case .industrial: .yellow
    case .materials: .blue
    case .restricted: .orange
    }
  }
  public static func at(_ index: Int) -> Self {
    if [3, 6, 10].contains(index) { return .restricted }
    if [0, 11].contains(index) { return .agricultural }
    if [1, 4, 5].contains(index) { return .consumer }
    if [2, 7, 8, 16].contains(index) { return .industrial }
    return .materials
  }
}
public struct StationLayout: Sendable {
  public let left: Double
  public let width: Double
  public let font: Double
  public let row: Double
  public let bottom: Double
  public let count: Int
  public init(game: Game, width: Double, height: Double, footer: Double = 0) {
    self.width = min(680, width - 48)
    left = (width - self.width) / 2
    font = GameTypography.scale
    row = ceil(font * 7) + 9
    bottom = CockpitLayout(game: game, width: width, height: height).dashboardTop - footer
    count = max(1, Int((bottom - 76) / row))
  }
}
extension Game {
  public func marketAvailability(_ index: Int) -> String {
    if !docked { return "DOCK TO TRADE" }
    if !stationAllowsMarketServices { return "SERVICE UNAVAILABLE" }
    if screen == .sell {
      if index == 3, commander.nativeCaptiveCount > 0, commander.sellableCargo(index) == 0 {
        return "REVIEW CAPTIVE SALE"
      }
      if commander.sellableCargo(index) > 0 { return "SELL" }
      return index == 10 && commander.markedFirearms > 0 ? "RESERVED" : "NONE HELD"
    }
    if market[index].quantity == 0 { return "NO STOCK" }
    if commander.availableCredits < market[index].price { return "NO CASH" }
    if commander.cargo[index] >= Int.max / 17
      || (Commodity.all[index].unit == "t"
        && commander.cargoTonnes >= commander.tradeCargoCapacity)
    {
      return "HOLD FULL"
    }
    return "BUY"
  }
  public var informationRows: [(String, Ink)] {
    if screen == .inventory {
      return inventoryInformationRows(width: viewportWidth).map { ($0.text, $0.ink) }
    }
    let criminalStatus = commander.legal < 50 ? "Offender" : "Fugitive"
    let legal = commander.legal == 0 ? "Clean" : criminalStatus
    var rows: [(String, Ink)] = [
      ("Ship: " + commander.ship.name, .cyan),
      ("Present system: " + currentSystem.name, .white),
      ("Station: " + (nativeStationName ?? "Main orbital station"), .white),
      ("Hyperspace: " + targetSystem.name, .white),
      ("Condition: " + flightStatus, .white),
      (
        String(
          format: "Fuel: %.1f / %.1f LY", Double(commander.fuel) / 10,
          Double(commander.fuelCapacity) / 10), .white
      ),
      (String(format: "Cash: %.1f CR", Double(commander.credits) / 10), .white),
      ("Legal status: " + legal, .white),
      ("Rating: " + commander.rank, .white),
      ("Cargo used: \(commander.cargoTonnes)t", .white),
      ("Missiles: \(commander.missiles)", .white),
      (
        "Shield: "
          + fittedSummary(.shield, fallback: commander.shieldBooster?.equipmentName ?? "Basic")
          + String(
            format: " - front %.0f / rear %.0f", commander.shieldCapacity,
            commander.rearShieldCapacity), .white
      ),
      (
        "Navigation: "
          + fittedSummary(
            .navigation,
            fallback: commander.navigationTier?.label ?? "Basic"), .white
      ),
      (
        "Energy: "
          + fittedSummary(
            .energy,
            fallback:
              commander.equipment.contains(Equipment.eliteEnergyUnit)
              ? Equipment.eliteEnergyUnit
              : commander.equipment.contains(Equipment.navalEnergyUnit)
                ? Equipment.navalEnergyUnit
                : commander.equipment.contains("Extra Energy Unit") ? "Extra Energy Unit" : "Basic"),
        .white
      ),
      (
        "Targeting core: " + (commander.targetingTier?.label ?? "None")
          + (commander.targetingTier.map { $0 > .basic } == true
            ? " (includes lower core tiers)" : ""),
        .white
      ),
      (specialtySummary("Mining", slot: .targetingMining), .white),
      (specialtySummary("Salvage", slot: .targetingSalvage), .white),
      ("Fittings and cargo manifest: Inventory (9)", .cyan),
    ]
    if commander.missionStage != .notStarted { rows.append((commander.missionStage.status, .cyan)) }
    return rows
  }
  private func fittedSummary(_ slot: ComponentFittingSlot, fallback: String) -> String {
    guard let item = commander.fittedEquipment(at: slot) else {
      guard commander.equipmentInventory == nil else { return "None" }
      let canonical =
        EquipmentRuntimeCatalog.node(for: fallback).flatMap { node in
          EquipmentRuntimeCatalog.graph.nodes.first { $0.id == node }?.displayName
        } ?? fallback
      return canonical + " (legacy)"
    }
    return equipmentName(item)
  }
  private func specialtySummary(_ label: String, slot: ComponentFittingSlot) -> String {
    let module = commander.fittedEquipment(at: slot)?.node.key
    let legacy =
      commander.equipmentInventory == nil
      && commander.equipment.contains("Targeting: " + label + " Module")
    let installed = module != nil || legacy
    let core = commander.targetingTier?.label ?? "none"
    return label + ": " + (installed ? "module fitted" : "no module")
      + "; core: " + core
  }
  func equipmentName(_ item: OwnedEquipmentItem) -> String {
    let canonical =
      EquipmentRuntimeCatalog.graph.nodes.first { $0.id == item.node }?.displayName
      ?? item.node.key
    guard let component = item.component,
      let grade = EquipmentModuleTemplates.displayName(for: component.grade)
    else { return canonical }
    let family: String
    switch component.family {
    case EquipmentModuleTemplates.shieldFamily: family = "Shield"
    case EquipmentModuleTemplates.navigationFamily: family = "Navigation"
    case EquipmentModuleTemplates.energyFamily: family = "Energy"
    default: return canonical
    }
    return grade + " " + family
  }
  func equipmentOrigin(_ origin: EquipmentAcquisitionProvenance) -> String {
    switch origin {
    case .standard: "Standard"
    case .paid: "Purchased"
    case .grant: "Granted"
    case .recovered: "Recovered"
    case .reward: "Reward"
    case .earned: "Earned"
    case .xyzzy: "XYZZY grant"
    case .missionIssue: "Mission issued"
    case .legacyUnknown: "Acquisition unknown"
    }
  }
  private func utilityName(_ utility: ComponentUtility) -> String {
    switch utility {
    case .miningLaser: "Mining work tool"
    case .salvageCutter: "Salvage cutter"
    case .empPirateBlaster: Equipment.empPirateBlaster
    case .fuelScoops: "Fuel scoops"
    case .ecm: "ECM system"
    case .escapePod: "Escape pod"
    case .energyBomb: "Energy bomb"
    case .cargoExpansion: "Cargo expansion"
    case .galacticHyperdrive: "Galactic hyperdrive"
    }
  }
  func equipmentSlot(_ slot: ComponentFittingSlot) -> String {
    switch slot {
    case .shield: "Fitted shield"
    case .energy: "Fitted energy"
    case .navigation: "Fitted navigation"
    case .targetingCore: "Fitted targeting core"
    case .targetingMining: "Fitted mining targeting"
    case .targetingSalvage: "Fitted salvage targeting"
    case .drive: "Fitted drive"
    case .laser(let mount): "Fitted " + mount.label + " combat mount"
    case .missilePylon(let index): "Fitted pylon \(index + 1)"
    case .utility(let utility): "Fitted " + utilityName(utility)
    case .fuelStorage(let index): "Fitted fuel storage \(index + 1)"
    case .spareEscapePod(let index): "Spare escape pod \(index + 1)"
    case .hullStructure: "Hull structure"
    }
  }
}
extension Display {
  public static func marketScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let layout = StationLayout(game: game, width: width, height: height, footer: 144)
    frame.label(
      game.docked ? "MARKET - " + (game.screen == .sell ? "SELL" : "BUY") : "MARKET PRICES",
      layout.left, 12, scale: layout.font, ink: .yellow)
    let controls = MarketLayout(game: game, width: width, height: height)
    if game.docked {
      for (text, bounds, selected) in [
        ("Buy", controls.buy, game.screen != .sell),
        ("Sell", controls.sell, game.screen == .sell),
        (game.screen == .sell ? "Sell one" : "Buy one", controls.trade, false),
      ] {
        frame.stroke(bounds.x, bounds.maxY, bounds.maxX, bounds.maxY, selected ? .yellow : .cyan)
        frame.label(
          text, bounds.x + 8, bounds.y + 6, scale: layout.font, ink: selected ? .yellow : .cyan)
      }
    }
    frame.label(
      String(format: "Cash %.1f CR", Double(game.commander.credits) / 10), layout.left, 32,
      scale: layout.font)
    let offsets = [0.0, 0.40, 0.55, 0.69, 0.83]
    for (index, label) in ["Product", "Price CR", "Stock", "Hold", "Action"].enumerated() {
      frame.label(
        label, layout.left + offsets[index] * layout.width, 90, scale: layout.font, ink: .yellow)
    }
    let start = MarketDisplayOrder.start(selection: game.selection, visible: layout.count)
    for (row, index) in MarketDisplayOrder.commodityIDs.dropFirst(start).prefix(layout.count)
      .enumerated()
    {
      let item = Commodity.all[index]
      let y = 114 + Double(row) * layout.row
      frame.label(
        index == game.selection ? ">" : "", layout.left - 12, y, scale: layout.font, ink: .white)
      frame.label(
        item.name, layout.left, y, scale: layout.font, ink: CommodityCategory.at(index).ink)
      let values = [
        String(
          format: "%.1f",
          Double(game.screen == .sell ? game.market[index].bidPrice : game.market[index].price) / 10
        ),
        "\(game.market[index].quantity)\(item.unit)", "\(game.commander.cargo[index])\(item.unit)",
        game.marketAvailability(index),
      ]
      for (column, text) in values.enumerated() {
        frame.label(text, layout.left + offsets[column + 1] * layout.width, y, scale: layout.font)
      }
    }
    for (index, category) in CommodityCategory.allCases.enumerated() {
      let column = index % 3
      let row = index / 3
      frame.label(
        category.rawValue, layout.left + Double(column) * layout.width / 3,
        layout.bottom + 40 + Double(row) * layout.row, scale: layout.font, ink: category.ink)
    }
    frame.label(
      "Category colour; stock/cash/hold determine purchase.", layout.left, layout.bottom + 78,
      scale: layout.font, ink: .cyan)
    frame.label(
      "Restricted cargo affects legal status on launch.", layout.left, layout.bottom + 94,
      scale: layout.font, ink: .orange)
    let actions =
      game.docked
      ? "Up/Down: item  Tab: buy/sell  Return: trade one"
      : "Prices only  Esc: back  K: help"
    frame.label(
      actions, layout.left, layout.bottom + 110,
      scale: layout.font, ink: .cyan)
    if game.docked {
      frame.label(
        "Left: sell one  Right: buy one  Esc: back  K: help", layout.left,
        layout.bottom + 126, scale: layout.font, ink: .cyan)
    }
    return frame
  }
  public static func information(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let layout = StationLayout(game: game, width: width, height: height, footer: 28)
    frame.label(
      game.screen == .inventory ? "INVENTORY" : "COMMANDER " + game.commander.name, layout.left, 12,
      scale: layout.font, ink: .yellow)
    if game.screen == .inventory {
      let rows = game.inventoryInformationRows(width: width)
      let window = ScrollWindow(
        count: rows.count, visible: layout.count, offset: game.informationScroll)
      var interaction = InventoryInteraction()
      interaction.selected = game.inventoryActionSelection
      var buttons: [(label: String, bounds: CanvasRect)] = []
      for (index, row) in rows.dropFirst(window.offset).prefix(layout.count).enumerated() {
        let y = 56 + Double(index) * layout.row
        frame.label(row.text, layout.left, y, scale: layout.font, ink: row.ink)
        if let preview = row.preview, let command = preview.command {
          let bounds = CanvasRect(
            x: layout.left + layout.width - InventoryInteraction.actionWidth,
            y: y - 4, width: InventoryInteraction.actionWidth, height: layout.row)
          interaction.controls.append(.init(bounds: bounds, command: command))
          buttons.append((preview.label, bounds))
        }
      }
      for (index, button) in buttons.enumerated() {
        let selected = interaction.selectedIndex == index
        let ink: Ink = selected ? .cyan : .blue
        let bounds = button.bounds
        frame.stroke(bounds.x, bounds.y, bounds.maxX, bounds.y, ink)
        frame.stroke(bounds.maxX, bounds.y, bounds.maxX, bounds.maxY, ink)
        frame.stroke(bounds.maxX, bounds.maxY, bounds.x, bounds.maxY, ink)
        frame.stroke(bounds.x, bounds.maxY, bounds.x, bounds.y, ink)
        if selected {
          frame.label(
            ">", bounds.x + 4, bounds.y + 4, scale: layout.font, ink: .cyan)
        }
        frame.label(
          button.label,
          bounds.x + (bounds.width - Double(button.label.count) * 6 * layout.font) / 2,
          bounds.y + 4, scale: layout.font, ink: selected ? .cyan : .white)
      }
      frame.inventoryInteraction = interaction
      let notice = game.messageTime > 0 ? game.message : window.hint ?? ""
      let footer =
        MissionNotice.wrap(notice, width: Int(layout.width / (6 * layout.font))).first ?? ""
      frame.label(footer, layout.left, layout.bottom, scale: layout.font, ink: .cyan)
      frame.label(
        interaction.primary == nil
          ? "Esc: back  K: help" : "Tab: action  Return: apply  Esc: back  K: help",
        layout.left, layout.bottom + 18, scale: layout.font, ink: .cyan)
      return frame
    }
    let rows = game.informationRows
    let window = ScrollWindow(
      count: rows.count, visible: layout.count, offset: game.informationScroll)
    let start = window.offset
    for (index, row) in rows.dropFirst(start).prefix(layout.count).enumerated() {
      frame.label(
        row.0, layout.left, 56 + Double(index) * layout.row, scale: layout.font, ink: row.1)
    }
    frame.label(
      [window.hint, "Esc: back  K: help"].compactMap { $0 }.joined(separator: "  "), layout.left,
      layout.bottom,
      scale: layout.font,
      ink: .cyan
    )
    return frame
  }
}
