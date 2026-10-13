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
  public static func systemScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let previewLayout = SystemDataLayout(game: game, width: width, height: height, rowCount: 0)
    let columns = Int(previewLayout.facts.width / (6 * GameTypography.scale))
    let rows = systemRows(game).flatMap { text, ink in
      MissionNotice.wrap(text, width: columns).map { ($0, ink) }
    }
    let layout = SystemDataLayout(game: game, width: width, height: height, rowCount: rows.count)
    frame.label(
      "DATA ON G\(game.inspectedGalaxy + 1) / " + game.inspectedSystem.name,
      layout.facts.x, 12, scale: GameTypography.scale, ink: .yellow)
    frame.stroke(24, 34, width - 24, 34, .yellow)
    for (index, row) in rows.enumerated() {
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
