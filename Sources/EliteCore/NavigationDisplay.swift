import Foundation

extension Display {
  static func navigationSummary(_ game: Game, width: Double) -> [String] {
    guard game.navigationOptions.indices.contains(game.navigationSelection) else { return [] }
    let route = game.navigationOptions[game.navigationSelection]
    let profits = game.profitDestinations
    let scan = [game.profitScanSummary] + profits.enumerated().map {
      String(format: "%d %@: %.1f CR estimated profit", $0.offset + 1,
        game.systems[$0.element.systemID].name, Double($0.element.profit) / 10)
    }
    let summary = scan + [
      "Profit estimates: carried cargo vs selling here plus affordable exports; before fuel/risk.",
      String(
        format: "%d jumps  %.1f ly  Fuel estimate %.1f CR", route.plan.path.count - 1,
        route.distance, Double(route.fuelUnits * 2) / 10),
      String(
        format: "Risk index %.2f  Cargo sale estimate %.1f CR", route.risk, route.cargoSale / 10),
      String(
        format: "Trade opportunities estimate %.1f CR (not guaranteed)", route.tradeEstimate / 10),
      "Dock at every stop; launch preloads the next leg.",
      "Route: " + route.plan.path.map { game.systems[$0].name }.joined(separator: " > "),
    ]
    return summary.flatMap {
      MissionNotice.wrap($0, width: Int((width - 32) / (6 * GameTypography.scale)))
    }
  }
  static func navigationWindow(_ game: Game, width: Double, height: Double) -> ScrollWindow {
    let row = ceil(GameTypography.scale * 7) + 8
    let top = 88 + Double(game.navigationOptions.count * 3) * row
    return .init(
      count: navigationSummary(game, width: width).count,
      visible: max(1, Int((height - top - 52) / row)), offset: game.navigationScroll)
  }

  public static func navigation(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let font = GameTypography.scale
    let row = ceil(font * 7) + 8
    frame.label("NAVIGATIONAL COMPUTER", 16, 12, scale: font, ink: .yellow)
    frame.label(
      game.docked ? "Docked - route planning" : "Flight paused - route planning", 16, 36,
      scale: font, ink: .cyan)
    let plan = game.navigationOptions.first?.plan
    let radius =
      plan?.tier.radius(capacity: plan?.capacityAtPlanning ?? game.commander.fuelCapacity).map {
        String(format: "%.1f ly", $0)
      } ?? "Whole galaxy"
    frame.label(
      "Planning range: " + radius + "  Origin: "
        + game.systems[plan?.path.first ?? game.commander.system].name, 16, 58, scale: font)
    for (index, option) in game.navigationOptions.enumerated() {
      let text =
        (index == game.navigationSelection ? "> " : "  ") + option.labels.joined(separator: " / ")
      let names = MissionNotice.wrap(text, width: Int((width - 32) / (6 * font)))
      for (line, name) in names.prefix(2).enumerated() {
        frame.label(
          name, 16, 88 + Double(index * 3 + line) * row, scale: font,
          ink: index == game.navigationSelection ? .cyan : .white)
      }
    }
    if game.navigationOptions.indices.contains(game.navigationSelection) {
      let top = 88 + Double(game.navigationOptions.count * 3) * row
      let lines = navigationSummary(game, width: width)
      let visible = max(1, Int((height - top - 52) / row))
      let window = ScrollWindow(count: lines.count, visible: visible, offset: game.navigationScroll)
      let offset = window.offset
      for (index, line) in lines.dropFirst(offset).prefix(visible).enumerated() {
        frame.label(line, 16, top + Double(index) * row, scale: font)
      }
    }
    frame.label(
      "Arrows: route  Return: set  P: profit scan  C: clear  Esc: back", 16, height - 34, scale: font, ink: .cyan)
    frame.label(
      navigationWindow(game, width: width, height: height).hint.map { "Option-" + $0 }
        ?? "Set route, then launch; H starts a jump in flight", 16, height - 17, scale: font,
      ink: .cyan)
    return frame
  }
}
