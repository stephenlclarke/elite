import Foundation

public struct SystemDataLayout: Sendable {
  public let facts: CanvasRect
  public let planet: CanvasRect
  public let bottom: Double
  public init(game: Game, width: Double, height: Double, rowCount: Int) {
    bottom = CockpitLayout(game: game, width: width, height: height).dashboardTop
    let wide = width >= 1000
    let factsWidth = wide ? min(600, width * 0.44) : min(680, width - 48)
    let left = wide ? 24 : (width - factsWidth) / 2
    facts = .init(x: left, y: 56, width: factsWidth, height: Double(rowCount) * GameTypography.row)
    let availableWidth = wide ? width - facts.maxX - 56 : width - 48
    let top = wide ? 60 : facts.maxY + 12
    let diameter = max(0, min(wide ? 520 : 360, availableWidth, bottom - top - 68))
    let x = wide ? facts.maxX + 32 + (availableWidth - diameter) / 2 : (width - diameter) / 2
    planet = .init(x: x, y: top, width: diameter, height: diameter)
  }
}
extension Display {
  static func systemDataRows(_ game: Game, width: Double, height: Double) -> [(String, Ink)] {
    let layout = SystemDataLayout(game: game, width: width, height: height, rowCount: 0)
    let columns = Int(layout.facts.width / (6 * GameTypography.scale))
    return systemRows(game).flatMap { text, ink in
      MissionNotice.wrap(text, width: columns).map { ($0, ink) }
    }
  }
  static func systemWindow(_ game: Game, width: Double, height: Double) -> ScrollWindow {
    let bottom = CockpitLayout(game: game, width: width, height: height).dashboardTop
    return .init(
      count: systemDataRows(game, width: width, height: height).count,
      visible: max(1, Int((bottom - 126) / GameTypography.row)), offset: game.informationScroll)
  }
  public static func systemScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let rows = systemDataRows(game, width: width, height: height)
    let window = systemWindow(game, width: width, height: height)
    let layout = SystemDataLayout(
      game: game, width: width, height: height, rowCount: min(rows.count, window.visible))
    frame.label(
      "DATA ON G\(game.inspectedGalaxy + 1) / " + game.inspectedSystem.name,
      layout.facts.x, 12, scale: GameTypography.scale, ink: .yellow)
    frame.stroke(24, 34, width - 24, 34, .yellow)
    for (index, row) in rows.dropFirst(window.offset).prefix(window.visible).enumerated() {
      frame.label(
        row.0, layout.facts.x, layout.facts.y + Double(index) * GameTypography.row,
        scale: GameTypography.scale, ink: row.1)
    }
    if layout.planet.width >= 32 {
      frame.graphics.append(
        .planet(
          .init(
            galaxy: game.inspectedGalaxy, system: game.inspectedSystem,
            bounds: layout.planet, time: game.time)))
      let caption = "Generated planet view"
      let x = max(
        24,
        min(
          width - 24 - Double(caption.count) * 6 * GameTypography.scale,
          layout.planet.x + (layout.planet.width - Double(caption.count) * 6 * GameTypography.scale)
            / 2))
      frame.label(caption, x, layout.planet.maxY + 8, scale: GameTypography.scale, ink: .cyan)
    }
    if let hint = window.hint {
      frame.label(hint, layout.facts.x, layout.bottom - 62, scale: GameTypography.scale, ink: .cyan)
    }
    if game.messageTime > 0 {
      frame.label(
        game.message, layout.facts.x, layout.bottom - 44, scale: GameTypography.scale, ink: .orange)
    }
    frame.label(
      game.paused ? "PAUSED - COMMAND-P TO RESUME" : "Esc: back  K: help", layout.facts.x,
      layout.bottom - 22, scale: GameTypography.scale, ink: .cyan)
    return frame
  }
}
