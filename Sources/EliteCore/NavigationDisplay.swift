import Foundation

extension Display {
  static func navigationSummary(_ game: Game, width: Double) -> [String] {
    guard game.navigationOptions.indices.contains(game.navigationSelection) else { return [] }
    let route = game.navigationOptions[game.navigationSelection]
    let profits = game.profitDestinations
    let scan =
      [game.profitScanSummary]
      + profits.enumerated().map {
        String(
          format: "%d %@: %.1f CR estimated profit", $0.offset + 1,
          game.systems[$0.element.systemID].name, Double($0.element.profit) / 10)
      }
    let range =
      route.plan.tier.radius(capacity: route.plan.capacityAtPlanning).map {
        String(format: "%.1f ly", $0)
      } ?? "whole galaxy"
    let summary =
      [
        "To " + game.systems[route.plan.destination].name + " / " + route.plan.tier.label
          + " search " + range,

        String(
          format: "%d jumps  %.1f ly  Fuel estimate %.1f CR",
          route.plan.path.count - 1 - route.plan.stopIndex,
          route.distance, Double(route.fuelUnits * 2) / 10),
        String(
          format: "Risk index %.2f  Cargo sale estimate %.1f CR", route.risk, route.cargoSale / 10),
        String(
          format: "Trade opportunities estimate %.1f CR (not guaranteed)", route.tradeEstimate / 10),
        "Dock at every stop; launch preloads the next leg.",
        "Route: "
          + route.plan.path.dropFirst(route.plan.stopIndex).map { game.systems[$0].name }.joined(
            separator: " > "),
        "Active: "
          + (game.commander.navigationPlan.map { game.systems[$0.destination].name } ?? "none")
          + " (dotted white)",
      ] + scan + [
        "Profit estimates: carried cargo vs selling here plus affordable exports; before fuel/risk."
      ]
    return summary.flatMap {
      MissionNotice.wrap($0, width: Int((width - 32) / (6 * GameTypography.scale)))
    }
  }
  static func navigationWindow(_ game: Game, width: Double, height: Double) -> ScrollWindow {
    let layout = NavigationPreviewLayout(game: game, width: width, height: height)
    return .init(
      count: navigationSummary(game, width: width).count,
      visible: max(1, layout.summaryRows), offset: game.navigationScroll)
  }

  public static func navigation(_ game: Game, width: Double, height: Double) -> Frame {
    routePreview(game, width: width, height: height)
  }
}
