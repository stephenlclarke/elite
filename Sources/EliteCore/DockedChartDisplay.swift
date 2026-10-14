import Foundation

extension Display {
  static func dockedMapDetails(_ game: Game, layout: ChartLayout, into frame: inout Frame) {
    let x = layout.wide ? layout.width - 300 : 16
    let y = layout.detailsTop
    let bottom = layout.height - (layout.wide ? 48 : 126)
    let diameter = layout.wide ? 0.0 : min(140, bottom - y - 24)
    let factsWidth = layout.wide ? 284 : layout.width - 48 - max(0, diameter) - 16
    let rows = dockedPlanetRows(game)
    let columns = max(1, Int(factsWidth / (6 * layout.font)))
    let wrapped = rows.flatMap { text, ink in
      MissionNotice.wrap(text, width: columns).map { ($0, ink) }
    }
    let visible = max(1, Int((bottom - y - 20 - (layout.wide ? 174 : 0)) / GameTypography.row))
    let window = ScrollWindow(
      count: wrapped.count, visible: visible, offset: game.chartInformationScroll)
    let offset = window.offset
    for (index, row) in wrapped.dropFirst(offset).prefix(visible).enumerated() {
      frame.label(row.0, x, y + Double(index) * GameTypography.row, scale: layout.font, ink: row.1)
    }
    if let hint = window.hint {
      frame.label(hint, x, bottom - 14, scale: layout.font, ink: .cyan)
    }
    let planetSize =
      layout.wide
      ? min(240, bottom - y - Double(min(wrapped.count, visible)) * GameTypography.row - 34)
      : diameter
    if planetSize >= 32 {
      let planetX = layout.wide ? x + (284 - planetSize) / 2 : layout.width - 16 - planetSize
      let planetY = layout.wide ? bottom - planetSize - 26 : y
      frame.graphics.append(
        .planet(
          .init(
            galaxy: game.inspectedGalaxy, system: game.inspectedSystem,
            bounds: .init(x: planetX, y: planetY, width: planetSize, height: planetSize),
            time: game.time)))
    }
  }

  static func chartDataWindow(_ game: Game) -> ScrollWindow {
    let layout = ChartLayout(
      width: game.viewportWidth, height: game.viewportHeight, local: game.screen == .shortChart,
      fuel: game.commander.fuel, docked: game.docked)
    let y = layout.detailsTop
    let bottom = layout.height - (layout.wide ? 48 : 126)
    let diameter = layout.wide ? 0.0 : min(140, bottom - y - 24)
    let factsWidth = layout.wide ? 284 : layout.width - 48 - max(0, diameter) - 16
    let columns = max(1, Int(factsWidth / (6 * layout.font)))
    let count = dockedPlanetRows(game).reduce(0) {
      $0 + MissionNotice.wrap($1.0, width: columns).count
    }
    let visible = max(1, Int((bottom - y - 20 - (layout.wide ? 174 : 0)) / GameTypography.row))
    return .init(count: count, visible: visible, offset: game.chartInformationScroll)
  }

  private static func dockedPlanetRows(_ game: Game) -> [(String, Ink)] {
    var rows = [
      ("Selected: G\(game.inspectedGalaxy + 1) / " + game.inspectedSystem.name, Ink.yellow)
    ]
    rows += systemRows(game)
    rows.append(
      (
        game.mapIsCurrentGalaxy
          ? String(
            format: "Distance: %.1f light-years",
            game.currentSystem.distance(to: game.inspectedSystem))
          : "Distance: unavailable across galaxies", .white
      ))
    rows.append(
      (
        game.mapIsCurrentGalaxy
          ? String(
            format: "Reachable: %@  Range: %.1f ly", game.targetReachable ? "Yes" : "No",
            game.commander.maximumJumpDistance)
          : "Local range unavailable", .white
      ))
    rows.append(
      (game.mapIsCurrentGalaxy ? "N: navigation routes" : "Routes: current galaxy only", .cyan))
    return rows
  }
}

extension ChartLayout {
  var detailsTop: Double { wide ? 96 : plot.maxY + (local ? 72 : 12) }
}
