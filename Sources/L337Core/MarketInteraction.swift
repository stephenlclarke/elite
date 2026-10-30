import Foundation

public struct MarketLayout: Sendable {
  public let buy: CanvasRect
  public let sell: CanvasRect
  public let trade: CanvasRect
  let station: StationLayout
  public init(game: Game, width: Double, height: Double) {
    station = StationLayout(game: game, width: width, height: height, footer: 144)
    let cell = station.width / 3
    buy = .init(x: station.left, y: 52, width: cell - 8, height: 28)
    sell = .init(x: station.left + cell, y: 52, width: cell - 8, height: 28)
    trade = .init(x: station.left + 2 * cell, y: 52, width: cell - 8, height: 28)
  }
}
extension Game {
  mutating func marketKey(_ key: String) -> Bool {
    guard docked, [.buy, .sell, .market].contains(screen) else { return false }
    switch key {
    case "tab": screen = screen == .sell ? .buy : .sell
    case "market-buy": screen = .buy
    case "market-sell": screen = .sell
    case "market-trade", "return": trade(buy: screen != .sell)
    case "left": trade(buy: false)
    case "right": trade(buy: true)
    default: return false
    }
    return true
  }
  public mutating func marketClick(x: Double, y: Double) {
    guard !paused, [.buy, .sell, .market].contains(screen) else { return }
    let layout = MarketLayout(game: self, width: viewportWidth, height: viewportHeight)
    let point = ScreenPoint(x, y)
    if docked {
      if layout.buy.contains(point) {
        _ = marketKey("market-buy")
        return
      }
      if layout.sell.contains(point) {
        _ = marketKey("market-sell")
        return
      }
      if layout.trade.contains(point) {
        _ = marketKey("market-trade")
        return
      }
    }
    guard x >= layout.station.left, x < layout.station.left + layout.station.width, y >= 114 else {
      return
    }
    let row = Int((y - 114) / layout.station.row)
    let start = MarketDisplayOrder.start(selection: selection, visible: layout.station.count)
    guard row < layout.station.count, MarketDisplayOrder.commodityIDs.indices.contains(start + row)
    else { return }
    selection = MarketDisplayOrder.commodityIDs[start + row]
  }
}
