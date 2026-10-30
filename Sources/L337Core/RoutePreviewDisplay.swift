import Foundation

public struct NavigationPreviewLayout: Sendable {
  public let chart: ChartLayout
  public let candidateRects: [CanvasRect]
  public let setRect: CanvasRect
  public let backRect: CanvasRect
  public let summaryTop: Double
  public let summaryRows: Int
  public var plot: CanvasRect { chart.plot }
  public init(game: Game, width: Double, height: Double) {
    let font = GameTypography.scale
    let row = ceil(font * 7) + 8
    let count = game.navigationOptions.count
    let candidateHeight = height < 480 ? row : row * 2
    let plotHeight = max(
      64,
      min(
        height * 0.4,
        height - 52 - 22 - Double(count) * candidateHeight - 64 - row * 2))
    let plot = CanvasRect(x: 16, y: 52, width: max(1, width - 32), height: plotHeight)
    chart = ChartLayout(
      width: width, height: height, local: game.navigationReturn == .shortChart,
      fuel: game.chartScaleFuel, docked: game.docked, plotOverride: plot,
      galaxy: game.commander.galaxy)
    let top = plot.maxY + 22
    candidateRects = (0..<count).map {
      .init(
        x: 16, y: top + Double($0) * candidateHeight, width: width - 32, height: candidateHeight)
    }
    summaryTop = top + Double(count) * candidateHeight + 6
    summaryRows = max(0, Int((height - 64 - summaryTop) / row))
    setRect = .init(x: 16, y: height - 52, width: min(160, width / 2 - 20), height: 24)
    backRect = .init(x: width - 116, y: height - 52, width: 100, height: 24)
  }
}

extension Display {
  // Liang-Barsky clipping keeps local route legs inside the map without changing its scale.
  static func clippedRouteLeg(_ a: ScreenPoint, _ b: ScreenPoint, to rect: CanvasRect)
    -> (ScreenPoint, ScreenPoint)?
  {
    let dx = b.x - a.x
    let dy = b.y - a.y
    var start = 0.0
    var end = 1.0
    for (p, q) in [
      (-dx, a.x - rect.x), (dx, rect.maxX - a.x),
      (-dy, a.y - rect.y), (dy, rect.maxY - a.y),
    ] {
      if p == 0 {
        if q < 0 { return nil }
      } else {
        let t = q / p
        if p < 0 { start = max(start, t) } else { end = min(end, t) }
        if start > end { return nil }
      }
    }
    return (
      .init(a.x + start * dx, a.y + start * dy),
      .init(a.x + end * dx, a.y + end * dy)
    )
  }

  static func routePath(
    _ plan: NavigationPlan, game: Game, layout: ChartLayout, style: Int, ink: Ink,
    into frame: inout Frame
  ) {
    guard plan.valid, plan.galaxy == game.commander.galaxy,
      plan.path.allSatisfy({ game.systems.indices.contains($0) })
    else { return }
    let path = plan.path.dropFirst(plan.stopIndex)
    for (a, b) in zip(path, path.dropFirst()) {
      let first = layout.point(game.systems[a], current: game.currentSystem)
      let last = layout.point(game.systems[b], current: game.currentSystem)
      guard let (from, to) = clippedRouteLeg(first, last, to: layout.plot) else { continue }
      if style == 0 {
        frame.stroke(from.x, from.y, to.x, to.y, ink)
      } else {
        let length = hypot(to.x - from.x, to.y - from.y)
        let dash = style == 5 ? 2.0 : Double(style * 4 + 3)
        let steps = max(1, Int(ceil(length / (dash + 4))))
        for step in 0..<steps {
          let t = Double(step) / Double(steps)
          let u = min(1, t + dash / max(1, length))
          frame.stroke(
            from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t,
            from.x + (to.x - from.x) * u, from.y + (to.y - from.y) * u, ink)
        }
      }
    }
  }

  private static let routeColours: [Ink] = [.cyan, .orange, .lime, .white]

  private static func previewText(
    _ text: String, x: Double = 16, y: Double,
    width: Double, ink: Ink = .white, into frame: inout Frame
  ) {
    let columns = max(1, Int((width - x - 16) / (6 * GameTypography.scale)))
    frame.label(String(text.prefix(columns)), x, y, scale: GameTypography.scale, ink: ink)
  }

  private static func previewWorld(_ game: Game, chart: ChartLayout, into frame: inout Frame) {
    for (index, option) in game.navigationOptions.enumerated()
    where index != game.navigationSelection {
      routePath(
        option.plan, game: game, layout: chart, style: index + 1,
        ink: routeColours[index % routeColours.count], into: &frame)
    }
    if let active = game.commander.navigationPlan {
      routePath(active, game: game, layout: chart, style: 5, ink: .white, into: &frame)
    }
    if game.navigationOptions.indices.contains(game.navigationSelection) {
      routePath(
        game.navigationOptions[game.navigationSelection].plan, game: game,
        layout: chart, style: 0, ink: .cyan, into: &frame)
    }
    let profits = Set(game.profitDestinations.map(\.systemID))
    for system in game.knownSystems {
      let point = chart.point(system, current: game.currentSystem)
      guard chart.plot.contains(point) else { continue }
      frame.point(point.x, point.y, radius: 2.5, ink: game.mapColour.colour(system))
      if profits.contains(system.id) { frame.ellipse(point.x, point.y, 6, 6, .gold) }
      if system.id == game.commander.system { frame.ellipse(point.x, point.y, 4, 4, .cyan) }
    }
    if let id = game.navigationOptions.first?.plan.destination {
      let p = chart.point(game.systems[id], current: game.currentSystem)
      if chart.plot.contains(p) {
        frame.ellipse(p.x, p.y, 7, 7, .white)
      }
    }
    frame.worldGraphics = frame.graphics
    frame.graphics = []
  }

  private static func placeRouteLabel(
    _ text: String, at point: ScreenPoint, plot: CanvasRect,
    ink: Ink, occupied: inout [CanvasRect], into frame: inout Frame
  ) {
    let font = GameTypography.scale
    let width = Double(text.count) * 6 * font
    let height = 7 * font
    let positions = [
      (point.x + 7, point.y + 7), (point.x + 7, point.y - height - 7),
      (point.x - width - 7, point.y + 7), (point.x - width - 7, point.y - height - 7),
    ]
    for (x, y) in positions {
      let box = CanvasRect(x: x, y: y, width: width, height: height)
      if x >= plot.x && y >= plot.y && box.maxX <= plot.maxX && box.maxY <= plot.maxY
        && !occupied.contains(where: { $0.overlaps(box) })
      {
        occupied.append(box)
        frame.label(text, x, y, scale: font, ink: ink)
        return
      }
    }
  }

  private static func previewMapLabels(_ game: Game, chart: ChartLayout, into frame: inout Frame) {
    guard game.navigationOptions.indices.contains(game.navigationSelection) else { return }
    let plan = game.navigationOptions[game.navigationSelection].plan
    let path = Array(plan.path.dropFirst(plan.stopIndex))
    var occupied: [CanvasRect] = []
    let priorities = path.indices.sorted { a, b in
      let ap = a == 0 || a == path.count - 1 ? 0 : 1
      let bp = b == 0 || b == path.count - 1 ? 0 : 1
      return ap == bp ? a < b : ap < bp
    }
    for index in priorities {
      let point = chart.point(game.systems[path[index]], current: game.currentSystem)
      guard chart.plot.contains(point) else { continue }
      placeRouteLabel(
        "\(index) " + game.systems[path[index]].name, at: point, plot: chart.plot,
        ink: .cyan, occupied: &occupied, into: &frame)
    }
    for (index, option) in game.navigationOptions.enumerated()
    where index != game.navigationSelection {
      previewAlternativeLabel(
        option, index: index, game: game, chart: chart,
        occupied: &occupied, into: &frame)
    }
  }

  private static func previewAlternativeLabel(
    _ option: RouteAlternative, index: Int,
    game: Game, chart: ChartLayout, occupied: inout [CanvasRect], into frame: inout Frame
  ) {
    let path = option.plan.path.dropFirst(option.plan.stopIndex)
    for (first, next) in zip(path, path.dropFirst()) {
      guard
        let (a, b) = clippedRouteLeg(
          chart.point(game.systems[first], current: game.currentSystem),
          chart.point(game.systems[next], current: game.currentSystem), to: chart.plot)
      else { continue }
      let oldCount = occupied.count
      placeRouteLabel(
        "R\(index + 1)", at: .init((a.x + b.x) / 2, (a.y + b.y) / 2),
        plot: chart.plot, ink: routeColours[index % routeColours.count], occupied: &occupied,
        into: &frame)
      if occupied.count > oldCount { break }
    }
  }

  private static func previewChoices(
    _ game: Game, layout: NavigationPreviewLayout,
    width: Double, into frame: inout Frame
  ) {
    let row = ceil(GameTypography.scale * 7) + 8
    for (index, option) in game.navigationOptions.enumerated() {
      let rect = layout.candidateRects[index]
      let selected = index == game.navigationSelection
      let pattern = selected ? "solid" : "dash\(index + 1)"
      let title =
        (selected ? "> " : "  ") + "\(index + 1) [" + pattern + "] "
        + option.labels.joined(separator: "/")
      previewText(
        title, y: rect.y, width: width,
        ink: selected ? .cyan : routeColours[index % routeColours.count], into: &frame)
      if rect.height > row {
        let fuel =
          game.routeCandidateIsFeasible(option.plan)
          ? "fuel OK; refuel at stops" : "UNAVAILABLE - replan"
        previewText(
          String(
            format: "%d jumps / %.1f ly / %@",
            option.plan.path.count - 1 - option.plan.stopIndex, option.distance, fuel),
          y: rect.y + row, width: width, into: &frame)
      }
    }
  }

  private static func previewFooter(
    _ game: Game, layout: NavigationPreviewLayout,
    width: Double, height: Double, into frame: inout Frame
  ) {
    let lines = navigationSummary(game, width: width)
    let window = ScrollWindow(
      count: lines.count, visible: max(1, layout.summaryRows), offset: game.navigationScroll)
    let row = ceil(GameTypography.scale * 7) + 8
    for (index, text) in lines.dropFirst(window.offset).prefix(layout.summaryRows).enumerated() {
      previewText(text, y: layout.summaryTop + Double(index) * row, width: width, into: &frame)
    }
    let feasible =
      game.navigationOptions.indices.contains(game.navigationSelection)
      && game.routeCandidateIsFeasible(game.navigationOptions[game.navigationSelection].plan)
    previewText(
      feasible ? "[Set route]" : "[Unavailable]", x: layout.setRect.x,
      y: layout.setRect.y + 6, width: width, ink: .yellow, into: &frame)
    previewText(
      "[Back]", x: layout.backRect.x, y: layout.backRect.y + 6,
      width: width, ink: .cyan, into: &frame)
    let active =
      game.commander.navigationPlan.map {
        "Active: " + game.systems[$0.destination].name + " / "
      } ?? ""
    let hint =
      game.navigationOptions.isEmpty
      ? "Route changed - Back and replan"
      : active + "Esc: back  PgUp/PgDn: details"
    previewText(hint, y: height - 18, width: width, ink: .cyan, into: &frame)
  }

  static func routePreview(_ game: Game, width: Double, height: Double) -> Frame {
    let layout = NavigationPreviewLayout(game: game, width: width, height: height)
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    frame.flightClip = layout.plot
    previewText(
      layout.chart.local ? "SHORT RANGE - ROUTE PREVIEW" : "GALAXY - ROUTE PREVIEW",
      y: 10, width: width, ink: .yellow, into: &frame)
    let destination = game.navigationOptions.first?.plan.destination
    let name = destination.map { game.systems[$0].name } ?? "Replan required"
    previewText(
      "To " + name + " - preview only; Return sets", y: 30, width: width, ink: .cyan, into: &frame)
    previewWorld(game, chart: layout.chart, into: &frame)
    previewMapLabels(game, chart: layout.chart, into: &frame)
    let path =
      game.navigationOptions.indices.contains(game.navigationSelection)
      ? game.navigationOptions[game.navigationSelection].plan.path : []
    let outside = path.filter {
      !layout.plot.contains(layout.chart.point(game.systems[$0], current: game.currentSystem))
    }.count
    let legend =
      layout.chart.local && outside > 0
      ? "Solid preview; \(outside) stops off map (4: galaxy)"
      : "Solid preview; dash1-4/R1-R4 alternatives; dotted active"
    previewText(legend, y: layout.plot.maxY + 4, width: width, ink: .cyan, into: &frame)
    previewChoices(game, layout: layout, width: width, into: &frame)
    previewFooter(game, layout: layout, width: width, height: height, into: &frame)
    return frame
  }
}
