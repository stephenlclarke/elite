import Foundation

extension Display {
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
      let route = game.navigationOptions[game.navigationSelection]
      let top = 88 + Double(game.navigationOptions.count * 3) * row
      let summary = [
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
      let lines = summary.flatMap { MissionNotice.wrap($0, width: Int((width - 32) / (6 * font))) }
      let visible = max(1, Int((height - top - 52) / row))
      let offset = min(game.navigationScroll, max(0, lines.count - visible))
      for (index, line) in lines.dropFirst(offset).prefix(visible).enumerated() {
        frame.label(line, 16, top + Double(index) * row, scale: font)
      }
    }
    frame.label(
      "Up/Down: route  Enter: set  C: clear  Esc: back", 16, height - 34, scale: font, ink: .cyan)
    frame.label(
      "Fn-Up/Fn-Down: scroll  H still starts each jump manually", 16, height - 17, scale: font,
      ink: .cyan)
    return frame
  }
}
