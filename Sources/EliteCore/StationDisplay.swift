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
    if screen == .sell {
      if commander.sellableCargo(index) > 0 { return "SELL" }
      return index == 10 && commander.markedFirearms > 0 ? "RESERVED" : "NONE HELD"
    }
    if market[index].quantity == 0 { return "NO STOCK" }
    if commander.availableCredits < market[index].price { return "NO CASH" }
    if Commodity.all[index].unit == "t" && commander.cargoTonnes >= commander.capacity {
      return "HOLD FULL"
    }
    return "BUY"
  }
  public var informationRows: [(String, Ink)] {
    if screen == .inventory {
      var rows: [(String, Ink)] = [
        (
          "Cargo: \(commander.cargoTonnes) tonnes"
            + (commander.unlimitedCargo ? " (unlimited capacity)" : "/\(commander.capacity)"),
          .white
        )
      ]
      rows += commander.cargo.indices.filter { commander.cargo[$0] > 0 }.map { index in
        (
          Commodity.all[index].name + ": \(commander.cargo[index]) \(Commodity.all[index].unit)"
            + (index == 10 && commander.markedFirearms > 0 ? " (1 mission item)" : ""),
          CommodityCategory.at(index).ink
        )
      }
      rows += [("Lasers", .yellow)] + commander.laserMountSummary.map { ("  " + $0, .cyan) }
      return rows
    }
    let criminalStatus = commander.legal < 50 ? "Offender" : "Fugitive"
    let legal = commander.legal == 0 ? "Clean" : criminalStatus
    var rows: [(String, Ink)] = [
      ("Present system: " + currentSystem.name, .white),
      ("Hyperspace: " + targetSystem.name, .white),
      ("Condition: " + flightStatus, .white),
      (
        String(
          format: "Fuel: %.1f / %.1f LY", Double(commander.fuel) / 10,
          Double(commander.fuelCapacity) / 10), .white
      ),
      (String(format: "Cash: %.1f CR", Double(commander.credits) / 10), .white),
      ("Legal status: " + legal, .white),
      ("Rating: " + commander.rank, .white), ("Lasers", .yellow),
    ]
    rows += commander.laserMountSummary.map { ("  " + $0, .cyan) }
    rows += [
      ("Equipment", .yellow),
      ("  Targeting: " + (commander.targetingTier?.label ?? "None"), .white),
      ("  Navigation: " + (commander.navigationTier?.label ?? "None"), .white),
      ("  Fuel storage: \(commander.fuelStorageUnits)/4", .white),
    ]
    rows += commander.equipment.sorted().filter {
      LaserKind.from($0) == nil && TargetingTier.from($0) == nil && NavigationTier.from($0) == nil
        && !["Fuel", "Missile"].contains($0)
    }.map { ("  " + $0, .white) }
    if commander.missionStage != .notStarted { rows.append((commander.missionStage.status, .cyan)) }
    return rows
  }
}
extension Display {
  public static func marketScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let layout = StationLayout(game: game, width: width, height: height, footer: 92)
    let marketTitle = game.screen == .sell ? "SELL CARGO" : "MARKET PRICES"
    let title = game.screen == .buy ? "BUY CARGO" : marketTitle
    frame.label(title, layout.left, 12, scale: layout.font, ink: .yellow)
    frame.label(
      String(format: "Cash %.1f CR", Double(game.commander.credits) / 10), layout.left, 32,
      scale: layout.font)
    let offsets = [0.0, 0.40, 0.55, 0.69, 0.83]
    for (index, label) in ["Product", "Price CR", "Stock", "Hold", "Action"].enumerated() {
      frame.label(
        label, layout.left + offsets[index] * layout.width, 52, scale: layout.font, ink: .yellow)
    }
    let start = max(0, min(game.selection - layout.count + 1, Commodity.all.count - layout.count))
    for index in start..<min(Commodity.all.count, start + layout.count) {
      let item = Commodity.all[index]
      let y = 76 + Double(index - start) * layout.row
      frame.label(
        index == game.selection ? ">" : "", layout.left - 12, y, scale: layout.font, ink: .white)
      frame.label(
        item.name, layout.left, y, scale: layout.font, ink: CommodityCategory.at(index).ink)
      let values = [
        String(format: "%.1f", Double(game.market[index].price) / 10),
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
        layout.bottom + 4 + Double(row) * layout.row, scale: layout.font, ink: category.ink)
    }
    frame.label(
      "Category colour; stock/cash/hold determine purchase.", layout.left, layout.bottom + 42,
      scale: layout.font, ink: .cyan)
    frame.label(
      "Restricted cargo affects legal status on launch.", layout.left, layout.bottom + 58,
      scale: layout.font, ink: .orange)
    frame.label(
      "Up/Down: select  Return: trade  K: help", layout.left, layout.bottom + 74,
      scale: layout.font, ink: .cyan)
    return frame
  }
  public static func information(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let layout = StationLayout(game: game, width: width, height: height, footer: 28)
    frame.label(
      game.screen == .inventory ? "INVENTORY" : "COMMANDER " + game.commander.name, layout.left, 12,
      scale: layout.font, ink: .yellow)
    let rows = game.informationRows
    let start = max(0, min(game.informationScroll, rows.count - layout.count))
    for (index, row) in rows.dropFirst(start).prefix(layout.count).enumerated() {
      frame.label(
        row.0, layout.left, 56 + Double(index) * layout.row, scale: layout.font, ink: row.1)
    }
    frame.label(
      "Up/Down: more  U: rumours  W: showroom  K: help", layout.left, layout.bottom,
      scale: layout.font,
      ink: .cyan
    )
    return frame
  }
}
