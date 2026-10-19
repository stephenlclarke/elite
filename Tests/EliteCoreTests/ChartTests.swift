import Testing

@testable import EliteCore

@Test func chartColoursUseExplicitAuthoritativeCategoriesAndStayStableBetweenViews() {
  var game = Game(executive: false)
  game.screen = .chart
  let poor = game.systems.first { $0.economy == 7 }!
  let rich = game.systems.first { $0.economy == 0 }!
  #expect(
    MapColourMode.economy.colour(poor) == .red && MapColourMode.economy.colour(rich) == .green)
  for mode in MapColourMode.allCases {
    game.mapColour = mode
    let galactic = Display.map(game, width: 1512, height: 900)
    #expect(galactic.labels.contains { $0.text.contains(mode.rawValue) })
    for name in mode.legend { #expect(galactic.labels.contains { $0.text == name }) }
    let colour = mode.colour(game.currentSystem)
    game.screen = .shortChart
    let short = Display.map(game, width: 1512, height: 900)
    #expect(
      short.worldGraphics.contains {
        if case .point(_, _, _, let ink) = $0 { return ink == colour }
        return false
      })
    game.screen = .chart
  }
  game.mapColour = .economy
  game.key("m")
  #expect(game.mapColour == .government)
  game.key("5")
  #expect(game.mapColour == .government && game.screen == .shortChart)
  game.key("m")
  #expect(game.mapColour == .technology)
}
@Test func shortChartMarkersAreRadiusProportionalAndLabelsStayWithinNativeBounds() {
  var game = Game(executive: false)
  let sorted = game.knownSystems.sorted { $0.radius < $1.radius }
  for width in [512.0, 768, 1512] {
    for screen in [Screen.chart, .shortChart] {
      game.screen = screen
      let layout = ChartLayout(
        width: width, height: 518, local: screen == .shortChart, docked: game.docked)
      #expect(
        zip(sorted, sorted.dropFirst()).allSatisfy {
          layout.markerRadius($0) <= layout.markerRadius($1)
        })
      if screen == .shortChart {
        #expect(layout.markerRadius(sorted[0]) >= 4 && layout.markerRadius(sorted.last!) <= 12)
      }
      let frame = Display.map(game, width: width, height: 518)
      for label in frame.labels {
        #expect(
          label.bounds.x >= 0 && label.bounds.maxX <= width && label.bounds.y >= 0
            && label.bounds.maxY <= 518)
      }
      let names = frame.labels.filter { game.systems.map(\.name).contains($0.text) }
      for (index, label) in names.enumerated() {
        #expect(!names.dropFirst(index + 1).contains { $0.bounds.overlaps(label.bounds) })
      }
    }
  }
}
@Test func planetSearchBrowsesAllSystemsFiltersCaseInsensitivelyAndIsolatesGameShortcuts() throws {
  var game = Game(executive: false)
  game.screen = .chart
  game.commander.fuel = 0
  game.key("/")
  #expect(game.mapSearch.active && game.searchResults.count == 256)
  let sorted = game.knownSystems.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }
  #expect(game.searchResults == sorted)
  let expected = try Universe.originalWorld(
    galaxy: game.commander.galaxy, system: game.commander.system)
  let mixedCase = expected.name.enumerated().map {
    $0.offset.isMultiple(of: 2) ? String($0.element).lowercased() : String($0.element).uppercased()
  }.joined()
  for key in mixedCase { game.key(String(key)) }
  #expect(
    game.screen == .chart && game.commander.name == "JAMESON"
      && game.searchResults.first?.original?.key == expected.key)
  game.key("return")
  #expect(
    !game.mapSearch.active && game.mapTargetSystem.original?.key == expected.key
      && game.targetSystem.original?.key == expected.key && game.jumpCountdown == nil)
  game.key("/")
  game.key("search-clear")
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.screen == .chart && game.commander.name == "JAMESON" && game.searchResults.isEmpty)
  let empty = Display.map(game, width: 512, height: 518)
  #expect(empty.labels.contains { $0.text == "No matching planets" })
  game.key("search-clear")
  #expect(game.searchResults.count == 256)
  game.key("pagedown")
  #expect(game.mapSearch.highlight > 0)
  game.key("pageup")
  #expect(game.mapSearch.highlight == 0)
  game.key("escape")
  #expect(!game.mapSearch.active && game.screen == .chart)
}
@Test func dropdownKeyboardAndMouseSelectionPlaceCrosshairsAtExactSystemCoordinates() {
  var game = Game(executive: false)
  game.screen = .chart
  game.viewportWidth = 768
  game.viewportHeight = 768
  game.key("/")
  game.key("down")
  game.key("down")
  let expected = game.searchResults[2]
  game.key("return")
  #expect(game.viewedSystemID == expected.id)
  let layout = ChartLayout(width: 768, height: 768, local: false, docked: game.docked)
  let point = layout.point(expected, current: game.currentSystem)
  let frame = Display.map(game, width: 768, height: 768)
  #expect(
    frame.worldGraphics.contains {
      if case .ellipse(let centre, _, _, .white) = $0 { return centre == point }
      return false
    })
  game.key("/")
  game.key("search-clear")
  let mouseExpected = game.searchResults[3]
  game.mapClick(x: layout.searchRect.x + 50, y: layout.searchRect.y + 36 + 3 * 22 + 5)
  #expect(game.viewedSystemID == mouseExpected.id && !game.mapSearch.active)
  let mousePoint = layout.point(mouseExpected, current: game.currentSystem)
  game.mapClick(x: mousePoint.x, y: mousePoint.y)
  #expect(game.viewedSystemID == mouseExpected.id)
  let reach = game.targetReachable
  game.mapColour = .technology
  #expect(game.targetReachable == reach && game.jumpCountdown == nil)
}
