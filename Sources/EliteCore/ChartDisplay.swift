import Foundation

public enum MapColourMode: String, Sendable, CaseIterable {
  case economy = "Economy"
  case government = "Government"
  case technology = "Technology"
  public var next: Self {
    Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count]
  }
  public func colour(_ system: StarSystem) -> Ink {
    let colours: [Ink] = [.red, .redOrange, .orange, .gold, .yellow, .lime, .leaf, .green]
    let index: Int
    switch self {
    case .economy: index = 7 - system.economy
    case .government: index = system.government
    case .technology: index = min(7, system.technology * 7 / 14)
    }
    return colours[index]
  }
  public func category(_ system: StarSystem) -> String {
    switch self {
    case .economy: system.economyName
    case .government: system.governmentName
    case .technology: "Tech level \(system.technology + 1)"
    }
  }
  public var legend: [String] {
    switch self {
    case .economy:
      [
        "Poor Agricultural", "Average Agricultural", "Rich Agricultural", "Mainly Agricultural",
        "Mainly Industrial", "Poor Industrial", "Average Industrial", "Rich Industrial",
      ]
    case .government:
      [
        "Anarchy", "Feudal", "Multi-government", "Dictatorship", "Communist", "Confederacy",
        "Democracy", "Corporate State",
      ]
    case .technology:
      ["Level 1", "Level 3", "Level 5", "Level 7", "Level 9", "Level 11", "Level 13", "Level 15+"]
    }
  }
}
public struct PlanetSearchState: Sendable {
  public var active = false
  public var query = ""
  public var highlight = 0
  public var offset = 0
  public init() {}
}
public struct ChartLayout: Sendable {
  public let width: Double
  public let height: Double
  public let plot: CanvasRect
  public let wide: Bool
  public let local: Bool
  public let scale: Double
  public let font: Double
  public var searchRect: CanvasRect {
    .init(
      x: width - min(320, width - 32) - 16, y: local ? 44 : 96, width: min(320, width - 32),
      height: min(320, height - (local ? 80 : 132)))
  }
  public var searchRows: Int { max(1, Int((searchRect.height - 36) / 22)) }
  public init(width: Double, height: Double, local: Bool, fuel: Int = 70) {
    self.width = width
    self.height = height
    self.local = local
    wide = width >= 1000
    font = GameTypography.scale
    let wideFooter = local ? 276.0 : 226.0
    let narrowFooter = local ? 320.0 : 270.0
    plot = .init(
      x: 16, y: local ? 58 : 96, width: width - (wide ? 336 : 32),
      height: max(80, height - (wide ? wideFooter : narrowFooter) - (local ? 0 : 38)))
    scale =
      local
      ? min(
        (plot.width - 32) / max(64, Double(fuel) / 4 * 2.2),
        (plot.height - 32) / max(64, Double(fuel) / 4 * 2.2))
      : min((plot.width - 32) / 255, (plot.height - 32) / 127.5)
  }
  public func point(_ system: StarSystem, current: StarSystem) -> ScreenPoint {
    let cx = plot.x + plot.width / 2
    let cy = plot.y + plot.height / 2
    if local {
      return .init(
        cx + Double(system.x - current.x) * scale, cy + Double(system.y - current.y) * scale / 2)
    }
    return .init(
      cx + (Double(system.x) - 127.5) * scale, cy + (Double(system.y) - 127.5) * scale / 2)
  }
  public func markerRadius(_ system: StarSystem) -> Double {
    local
      ? max(4, min(12, Double(system.radius) * 0.0017))
      : max(1.3, min(2.8, Double(system.radius) * 0.0004))
  }
}
extension CanvasRect {
  func overlaps(_ other: Self) -> Bool {
    x < other.maxX && maxX > other.x && y < other.maxY && maxY > other.y
  }
}
extension Game {
  public var searchResults: [StarSystem] {
    let query = mapSearch.query.lowercased()
    return mapSystems.filter { query.isEmpty || $0.name.lowercased().contains(query) }.sorted {
      a, b in
      let ap = a.name.lowercased().hasPrefix(query)
      let bp = b.name.lowercased().hasPrefix(query)
      if ap != bp { return ap }
      return a.name == b.name ? a.id < b.id : a.name < b.name
    }
  }
  public var targetReachable: Bool {
    guard mapIsCurrentGalaxy else { return false }
    let distance = currentSystem.distance(to: mapTargetSystem)
    return distance <= commander.maximumJumpDistance
  }
  mutating func searchKey(_ key: String) {
    let layout = ChartLayout(width: viewportWidth, height: viewportHeight, local: false)
    switch key {
    case "escape": mapSearch.active = false
    case "return":
      if searchResults.indices.contains(mapSearch.highlight) {
        selectChartSystem(searchResults[mapSearch.highlight].id)
        mapSearch.active = false
      }
    case "up", "down": mapSearch.highlight += key == "up" ? -1 : 1
    case "pageup", "pagedown":
      mapSearch.highlight += key == "pageup" ? -layout.searchRows : layout.searchRows
    case "backspace":
      if !mapSearch.query.isEmpty { mapSearch.query.removeLast() }
      mapSearch.highlight = 0
    case "search-clear":
      mapSearch.query = ""
      mapSearch.highlight = 0
      mapSearch.offset = 0
    default:
      if key.hasPrefix("map-scroll:"), let amount = Int(key.dropFirst(11)) {
        mapSearch.highlight += amount
      } else if key.count == 1 && mapSearch.query.count < 16 {
        mapSearch.query += key
        mapSearch.highlight = 0
      }
    }
    mapSearch.highlight = max(0, min(max(0, searchResults.count - 1), mapSearch.highlight))
    if mapSearch.highlight < mapSearch.offset { mapSearch.offset = mapSearch.highlight }
    if mapSearch.highlight >= mapSearch.offset + layout.searchRows {
      mapSearch.offset = mapSearch.highlight - layout.searchRows + 1
    }
  }
  public mutating func mapClick(x: Double, y: Double) {
    guard screen == .chart || screen == .shortChart else { return }
    let layout = ChartLayout(
      width: viewportWidth, height: viewportHeight, local: screen == .shortChart,
      fuel: chartScaleFuel)
    if screen == .chart {
      if let index = layout.galaxyButtons.firstIndex(where: { $0.contains(.init(x, y)) }) {
        viewGalaxy(index)
        return
      }
      if layout.currentLocationButton.contains(.init(x, y)) {
        returnChartToCurrentLocation()
        return
      }
    }
    if screen == .chart && y < 28 && x > viewportWidth - 170 {
      mapSearch.active = true
      return
    }
    if mapSearch.active {
      if x > layout.searchRect.maxX - 60 && y < layout.searchRect.y + 28 {
        searchKey("search-clear")
        return
      }
      let index = mapSearch.offset + Int((y - layout.searchRect.y - 36) / 22)
      if layout.searchRect.contains(.init(x, y)), y >= layout.searchRect.y + 36,
        searchResults.indices.contains(index)
      {
        selectChartSystem(searchResults[index].id)
        mapSearch.active = false
      } else {
        mapSearch.active = false
      }
      return
    }
    guard layout.plot.contains(.init(x, y)) else { return }
    let visible = mapSystems.filter {
      layout.plot.contains(layout.point($0, current: currentSystem))
    }
    let selected =
      visible.min { a, b in
        func distance(_ system: StarSystem) -> Double {
          let p = layout.point(system, current: currentSystem)
          return hypot(p.x - x, p.y - y)
        }
        return distance(a) == distance(b) ? a.id < b.id : distance(a) < distance(b)
      }?.id ?? selectedSystem
    selectChartSystem(selected)
  }
}
extension Display {
  public static func map(_ game: Game, width: Double, height: Double) -> Frame {
    let layout = ChartLayout(
      width: width, height: height, local: game.screen == .shortChart,
      fuel: game.chartScaleFuel)
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    frame.flightClip = layout.plot
    frame.label(
      layout.local ? "SHORT RANGE CHART" : "Viewing Galaxy \(game.viewedGalaxy + 1)", 16, 10,
      scale: layout.font, ink: .yellow)
    frame.label(
      "M: " + game.mapColour.rawValue, layout.local ? 16 : 220, layout.local ? 32 : 10,
      scale: layout.font, ink: .cyan)
    if !layout.local {
      frame.label(
        "/: Search planets", width - 16 - 17 * 6 * layout.font, 10, scale: layout.font, ink: .cyan)
    }
    if !layout.local { galaxySelector(game, layout: layout, into: &frame) }
    let current = layout.point(game.currentSystem, current: game.currentSystem)
    if layout.local {
      reachRings(game, layout: layout, into: &frame)
    } else if game.mapIsCurrentGalaxy {
      let radius = game.commander.maximumJumpDistance / 0.4 * layout.scale
      frame.ellipse(current.x, current.y, radius, radius, .blue)
    }
    let visible = game.mapSystems.filter {
      layout.plot.contains(layout.point($0, current: game.currentSystem))
    }
    let markerBoxes = visible.map { system -> CanvasRect in
      let point = layout.point(system, current: game.currentSystem)
      let radius = layout.markerRadius(system) + (system.id == game.viewedSystemID ? 12 : 3)
      return .init(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
    }
    for system in visible {
      let point = layout.point(system, current: game.currentSystem)
      let radius = layout.markerRadius(system)
      frame.point(point.x, point.y, radius: radius, ink: game.mapColour.colour(system))
      if game.mapIsCurrentGalaxy && system.id == game.commander.system {
        frame.ellipse(point.x, point.y, radius + 3, radius + 3, .cyan)
      }
      if system.id == game.viewedSystemID {
        frame.ellipse(point.x, point.y, radius + 5, radius + 5, .white)
        frame.stroke(point.x - radius - 9, point.y, point.x - radius - 3, point.y, .white)
        frame.stroke(point.x + radius + 3, point.y, point.x + radius + 9, point.y, .white)
        frame.stroke(point.x, point.y - radius - 9, point.x, point.y - radius - 3, .white)
        frame.stroke(point.x, point.y + radius + 3, point.x, point.y + radius + 9, .white)
      }
    }
    frame.worldGraphics = frame.graphics
    frame.graphics = []
    var occupied: [CanvasRect] = []
    let labelled = visible.sorted { a, b in
      func priority(_ value: StarSystem) -> Int {
        if value.id == game.viewedSystemID { return 0 }
        return game.mapIsCurrentGalaxy && value.id == game.commander.system ? 1 : 2
      }
      return priority(a) == priority(b) ? a.id < b.id : priority(a) < priority(b)
    }.filter {
      layout.local || $0.id == game.viewedSystemID
        || (game.mapIsCurrentGalaxy && $0.id == game.commander.system)
    }
    for system in labelled {
      chartLabel(
        system, game: game, layout: layout, markerBoxes: markerBoxes, occupied: &occupied,
        into: &frame)
    }
    mapDetails(game, layout: layout, into: &frame)
    mapLegend(game, layout: layout, into: &frame)
    frame.label(
      "[/]: galaxy  Arrows: planet  O: current  K: help", 16, height - 20,
      scale: layout.font, ink: .cyan)
    if game.messageTime > 0 {
      frame.label(game.message, 16, height - 40, scale: layout.font, ink: .orange)
    }
    if game.mapSearch.active { searchDropdown(game, layout: layout, into: &frame) }
    return frame
  }
  private static func chartLabel(
    _ system: StarSystem, game: Game, layout: ChartLayout, markerBoxes: [CanvasRect],
    occupied: inout [CanvasRect], into frame: inout Frame
  ) {
    let point = layout.point(system, current: game.currentSystem)
    let radius = layout.markerRadius(system) + (system.id == game.viewedSystemID ? 14 : 6)
    let width = Double(system.name.count) * 6 * layout.font
    let height = 7 * layout.font
    let candidates = [
      CanvasRect(x: point.x + radius, y: point.y - height / 2, width: width, height: height),
      .init(x: point.x - radius - width, y: point.y - height / 2, width: width, height: height),
      .init(x: point.x - width / 2, y: point.y - radius - height, width: width, height: height),
      .init(x: point.x - width / 2, y: point.y + radius, width: width, height: height),
    ]
    guard
      let box = candidates.first(where: { box in
        layout.plot.contains(.init(box.x, box.y)) && layout.plot.contains(.init(box.maxX, box.maxY))
          && !occupied.contains(where: { $0.overlaps(box) })
          && !markerBoxes.contains(where: { $0.overlaps(box) })
      })
    else { return }
    occupied.append(box)
    frame.label(system.name, box.x, box.y, scale: layout.font)
  }
  private static func mapDetails(_ game: Game, layout: ChartLayout, into frame: inout Frame) {
    let system = game.mapTargetSystem
    let x = layout.wide ? layout.width - 300 : 16
    let y = layout.wide ? 96.0 : layout.height - 198
    let row = layout.wide ? 20.0 : 13.0
    let values = [
      "Selected: G\(game.viewedGalaxy + 1) / " + system.name, "Economy: " + system.economyName,
      "Government: " + system.governmentName,
      "Tech \(system.technology + 1)  Radius \(system.radius) km",
      game.mapIsCurrentGalaxy
        ? String(format: "Distance %.1f light-years", game.currentSystem.distance(to: system))
        : "Distance: unavailable across galaxies",
      (game.mapIsCurrentGalaxy
        ? "Reachable: \(game.targetReachable ? "Yes" : "No")  Range: "
        : "Local range unavailable: ")
        + String(format: "%.1f ly", game.commander.maximumJumpDistance),
    ]
    let nav =
      game.commander.navigationTier.map { tier in
        "Nav: " + tier.label + " "
          + (tier.radius(capacity: game.commander.fuelCapacity).map {
            String(format: "%.1f ly", $0)
          }
            ?? "Whole galaxy")
      } ?? "Nav: not fitted"
    let route = game.commander.navigationPlan
    let navLine =
      route.map {
        "Route: " + game.systems[$0.destination].name + ($0.complete ? " arrived" : " N: inspect")
      } ?? (nav + "  N: routes")
    frame.label(
      game.mapIsCurrentGalaxy ? navLine : "Routes: current galaxy only", x, y + 6 * row,
      scale: layout.font, ink: .cyan)
    for (index, value) in values.enumerated() {
      frame.label(
        value, x, y + Double(index) * row, scale: layout.font, ink: index == 0 ? .yellow : .white)
    }
  }
  private static func mapLegend(_ game: Game, layout: ChartLayout, into frame: inout Frame) {
    let colours: [Ink] = [.red, .redOrange, .orange, .gold, .yellow, .lime, .leaf, .green]
    for (index, name) in game.mapColour.legend.enumerated() {
      let x = 22 + Double(index / 4) * (layout.width / 2)
      let y = layout.height - 104 + Double(index % 4) * 16
      frame.point(x, y + 4, radius: 3, ink: colours[index])
      frame.label(name, x + 10, y, scale: layout.font)
    }
  }
  private static func searchDropdown(_ game: Game, layout: ChartLayout, into frame: inout Frame) {
    let rect = layout.searchRect
    let font = GameTypography.scale
    frame.graphics.append(
      .panel(
        .init(
          vertices: [
            .init(rect.x, rect.y), .init(rect.maxX, rect.y), .init(rect.maxX, rect.maxY),
            .init(rect.x, rect.maxY),
          ], colour: Ink.black.rawValue)))
    // Remove map labels behind this popup; its own text stays readable.
    frame.labels.removeAll { $0.bounds.overlaps(rect) }
    frame.label(
      "Search: " + game.mapSearch.query + "_", rect.x + 10, rect.y + 10, scale: font, ink: .cyan)
    frame.label("Clear", rect.maxX - 40, rect.y + 10, scale: font, ink: .yellow)
    let results = game.searchResults
    if results.isEmpty { frame.label("No matching planets", rect.x + 10, rect.y + 42, scale: font) }
    for (row, system) in results.dropFirst(game.mapSearch.offset).prefix(layout.searchRows)
      .enumerated()
    {
      let index = game.mapSearch.offset + row
      let y = rect.y + 36 + Double(row) * 22
      frame.point(rect.x + 12, y + 4, radius: 4, ink: game.mapColour.colour(system))
      frame.label(
        (index == game.mapSearch.highlight ? "> " : "  ") + "G\(game.viewedGalaxy + 1) "
          + system.name, rect.x + 24, y,
        scale: font, ink: .white)
      frame.label(game.mapColour.category(system), rect.x + 130, y, scale: font, ink: .yellow)
      if game.mapIsCurrentGalaxy && game.commander.navigationTier != nil
        && !game.canPlan(to: system)
      {
        frame.label("Outside planning range", rect.x + 130, y + 10, scale: font, ink: .orange)
      }
    }
  }
}

extension Display {
  private static func galaxySelector(_ game: Game, layout: ChartLayout, into frame: inout Frame) {
    frame.label(
      "Current location: Galaxy \(game.commander.galaxy + 1) / " + game.currentSystem.name,
      16, 32, scale: layout.font)
    frame.label(
      "O: Current", layout.currentLocationButton.x + 4, 32, scale: layout.font, ink: .cyan)
    frame.label("Galaxy", 16, 66, scale: layout.font, ink: .yellow)
    for (index, bounds) in layout.galaxyButtons.enumerated() {
      let ink: Ink = index == game.viewedGalaxy ? .cyan : .blue
      frame.stroke(bounds.x, bounds.y, bounds.maxX, bounds.y, ink)
      frame.stroke(bounds.maxX, bounds.y, bounds.maxX, bounds.maxY, ink)
      frame.stroke(bounds.maxX, bounds.maxY, bounds.x, bounds.maxY, ink)
      frame.stroke(bounds.x, bounds.maxY, bounds.x, bounds.y, ink)
      frame.label(
        "\(index + 1)", bounds.x + (bounds.width - 6 * layout.font) / 2,
        bounds.y + 8, scale: layout.font, ink: index == game.viewedGalaxy ? .cyan : .white)
    }
  }
}
