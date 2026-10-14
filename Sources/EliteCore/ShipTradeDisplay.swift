import Foundation

public struct ShipTradeLayout: Sendable {
  public let left: Double
  public let width: Double
  public let back: CanvasRect
  public let confirm: CanvasRect
  public let count: Int
  public init(width: Double, height: Double) {
    self.width = min(680, width - 48)
    left = (width - self.width) / 2
    back = .init(x: left, y: height - 58, width: self.width / 2 - 8, height: 30)
    confirm = .init(
      x: left + self.width / 2 + 8, y: height - 58, width: self.width / 2 - 8, height: 30)
    count = max(1, Int((height - 180) / GameTypography.row))
  }
}
extension Display {
  static func shipTradeRows(_ game: Game, width: Double) -> [String] {
    let layout = ShipTradeLayout(width: width, height: game.viewportHeight)
    let rows = game.shipTradeQuote?.rows ?? ["This object is not a flyable hull."]
    return rows.flatMap {
      ShowroomText.wrap($0, width: Int(layout.width / (6 * GameTypography.scale)))
    }
  }
  static func shipTradeScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let layout = ShipTradeLayout(width: width, height: height)
    frame.label("EXCHANGE SHIP", layout.left, 16, scale: GameTypography.scale, ink: .yellow)
    frame.label("Owned: " + game.commander.ship.name, layout.left, 40, scale: GameTypography.scale)
    let rows = shipTradeRows(game, width: width)
    let window = ScrollWindow(
      count: rows.count, visible: layout.count, offset: game.showroom.tradeScroll)
    for (index, row) in rows.dropFirst(window.offset).prefix(layout.count).enumerated() {
      frame.label(
        row, layout.left, 70 + Double(index) * GameTypography.row, scale: GameTypography.scale)
    }
    if let hint = window.hint {
      frame.label(hint, layout.left, height - 100, scale: GameTypography.scale, ink: .cyan)
    }
    let allowed = game.shipTradeQuote?.allowed == true && !game.paused
    frame.label(
      (game.showroom.confirmTrade ? "  " : "> ") + "Back", layout.back.x + 8, layout.back.y + 10,
      scale: GameTypography.scale, ink: .cyan)
    frame.label(
      (game.showroom.confirmTrade ? "> " : "  ") + (allowed ? "Confirm trade" : "Trade blocked"),
      layout.confirm.x + 8, layout.confirm.y + 10, scale: GameTypography.scale,
      ink: allowed ? .green : .orange)
    frame.label(
      "Left/Right: choose  Return: select  Esc: back", layout.left, height - 20,
      scale: GameTypography.scale, ink: .cyan)
    return frame
  }
}
