import Foundation

public enum MapZoom: String, Sendable, CaseIterable {
  case jump = "Max jump"
  case search = "Search"
  case fuel = "Actual fuel"
  public var next: Self {
    Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count]
  }
}
public enum StrokePattern: Sendable, Equatable { case solid, dashed, dotted }
public struct JumpReach: Sendable {
  public let search: Double?
  public let maximum: Double
  public let actual: Double
  public let wholeGalaxyExtent: Double
}
extension Game {
  public var jumpReach: JumpReach {
    .init(
      search: navigationPlanningRadius,
      maximum: min(commander.jumpCap, Double(commander.fuelCapacity) / 10),
      actual: commander.maximumJumpDistance,
      wholeGalaxyExtent: (knownSystems.map { currentSystem.distance(to: $0) }.max() ?? 0) + 0.4)
  }
  public var chartScaleFuel: Int {
    let reach = jumpReach
    let radius: Double
    switch mapZoom {
    case .jump: radius = reach.maximum
    case .fuel: radius = reach.actual
    case .search: radius = reach.search ?? reach.wholeGalaxyExtent
    }
    return max(1, Int(ceil(radius * 10)))
  }
}
extension Display {
  static func reachRings(_ game: Game, layout: ChartLayout, into frame: inout Frame) {
    let current = layout.point(game.currentSystem, current: game.currentSystem)
    let reach = game.jumpReach
    func append(_ radius: Double, ink: Ink, style: StrokePattern) {
      let pixels = radius / 0.4 * layout.scale
      frame.graphics.append(
        .ring(center: current, radiusX: pixels, radiusY: pixels, ink: ink, style: style))
    }
    if game.commander.navigationTier != nil {
      append(reach.search ?? reach.wholeGalaxyExtent, ink: .green, style: .dotted)
    }
    append(reach.maximum, ink: .yellow, style: .dashed)
    if abs(reach.actual - reach.maximum) > 0.001 { append(reach.actual, ink: .cyan, style: .solid) }
    let top = layout.plot.maxY + 8
    let search =
      game.commander.navigationTier == nil
      ? "Not fitted"
      : (reach.search.map { String(format: "%.1f ly", $0) } ?? "Entire galaxy (Z: fit search)")
    let values: [(String, Ink)] = [
      ("Dotted search: " + search, .green),
      (String(format: "Dashed max jump: %.1f ly", reach.maximum), .yellow),
      (
        String(format: "Actual fuel-limited: %.1f ly", reach.actual)
          + (abs(reach.actual - reach.maximum) < 0.001 ? " (same as max)" : " (solid)"), .cyan
      ),
    ]
    for (index, entry) in values.enumerated() {
      frame.label(entry.0, 16, top + Double(index) * 14, scale: layout.font, ink: entry.1)
    }
    frame.label(
      "Z: zoom " + game.mapZoom.rawValue, layout.width - 16 - 24 * 6 * layout.font, 32,
      scale: layout.font, ink: .cyan)
  }
}
