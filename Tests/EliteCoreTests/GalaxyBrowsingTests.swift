import Testing

@testable import EliteCore

@Test func galaxySelectorBrowsesEightRealCataloguesWithoutChangingFlightState() throws {
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  let neighbour = try #require(
    game.knownSystems.first {
      $0.id != game.commander.system
        && game.currentSystem.distance(to: $0) <= game.commander.maximumJumpDistance
    })
  game.commander.navigationPlan = .init(
    galaxy: game.commander.galaxy, path: [game.commander.system, neighbour.id],
    tier: .military, originFuel: game.commander.fuel,
    originCapacity: game.commander.fuelCapacity)
  game.screen = .chart
  let commander = game.commander
  let market = game.market
  let universe = game.systems
  let destination = game.selectedSystem
  for galaxy in 0..<8 {
    game.viewGalaxy(galaxy)
    #expect(game.viewedGalaxy == galaxy && game.mapSystems == Universe.galaxy(number: galaxy))
    #expect(game.searchResults.count == 256)
    game.selectChartSystem(88)
    #expect(game.mapTargetSystem == Universe.galaxy(number: galaxy)[88])
    #expect(game.commander == commander && game.market == market && game.systems == universe)
    #expect(game.selectedSystem == destination)
    let frame = Display.presentation(game, width: 1512, height: 982)
    #expect(
      frame.labels.contains {
        $0.text == "Viewing " + Universe.originalWorlds.authoring.galaxies[galaxy].name
      })
    #expect(frame.labels.contains { $0.text.contains("Current location: Galaxy 1") })
    let rings = frame.worldGraphics.filter {
      if case .ellipse(_, _, _, .blue) = $0 { return true }
      return false
    }
    #expect(rings.isEmpty == (galaxy != commander.galaxy))
    if galaxy != commander.galaxy {
      game.key("h")
      game.key("n")
      #expect(game.jumpCountdown == nil && game.commander == commander && game.screen == .chart)
      #expect(frame.labels.contains { $0.text.contains("unavailable across galaxies") })
    }
  }
  game.key("]")
  #expect(game.viewedGalaxy == 7)
  for _ in 0..<10 { game.key("[") }
  #expect(game.viewedGalaxy == 0)
  game.key("o")
  #expect(game.viewedGalaxy == commander.galaxy && game.viewedSystemID == commander.system)
  #expect(game.commander == commander && game.selectedSystem == destination)
}

@Test func foreignGalaxySearchCrosshairsInspectionAndReturnStayBoundToGalaxyIdentity() {
  var game = Game(executive: false)
  game.screen = .chart
  game.viewportWidth = 768
  game.viewportHeight = 768
  let originalName = game.commander.name
  for galaxy in 0..<8 {
    game.viewGalaxy(galaxy)
    game.key("/")
    for key in "xyzzy" { game.key(String(key)) }
    #expect(game.commander.name == originalName && game.screen == .chart)
    game.key("search-clear")
    game.key("down")
    let expected = game.searchResults[1]
    game.key("return")
    #expect(game.mapTargetSystem == expected)
    let layout = ChartLayout(
      width: 768, height: 768, local: false, docked: game.docked, galaxy: galaxy)
    let point = layout.point(expected, current: game.currentSystem)
    let frame = Display.presentation(game, width: 768, height: 768)
    #expect(
      frame.worldGraphics.contains {
        if case .ellipse(let p, _, _, .white) = $0 { return p == point }
        return false
      })
    #expect(game.inspectedGalaxy == galaxy && game.inspectedSystem == expected)
    game.key("6")
    #expect(game.screen == .showroom)
    game.key("4")
    #expect(game.viewedGalaxy == galaxy && game.mapTargetSystem == expected)
  }
  game.key("/")
  game.key("w")
  #expect(game.mapSearch.query == "w" && game.screen == .chart)
  game.key("u")
  #expect(game.mapSearch.query == "wu")
  game.viewGalaxy(3)
  #expect(game.mapSearch.active && game.mapSearch.query.isEmpty && game.mapSearch.offset == 0)
  game.key("escape")
  let layout = ChartLayout(width: 768, height: 768, local: false, docked: game.docked)
  for (galaxy, bounds) in layout.galaxyButtons.enumerated() {
    game.mapClick(x: bounds.x + 5, y: bounds.y + 5)
    #expect(game.viewedGalaxy == galaxy)
  }
  game.mapClick(x: layout.currentLocationButton.x + 5, y: layout.currentLocationButton.y + 5)
  #expect(game.viewedGalaxy == 0 && game.viewedSystemID == 7)
}

@Test func browsingRepeatedSystemIDsWithDistinctOriginalNamesDoesNotRebindTheTravelDestination()
  throws
{
  var game = Game(executive: false)
  game.screen = .chart
  let origin = game.commander
  let destination = game.selectedSystem
  let catalogue = Universe.originalWorlds
  #expect(Set(catalogue.worlds.map(\.name)).count == 2048)
  for id in [0, 7, 88, 255] {
    var keys = Set<String>()
    var names = Set<String>()
    for galaxy in 0..<8 {
      let expected = try catalogue.world(galaxy: galaxy, system: id)
      game.viewGalaxy(galaxy)
      game.selectChartSystem(id)
      #expect(game.viewedGalaxy == galaxy && game.mapTargetSystem.id == id)
      #expect(
        game.mapTargetSystem.original?.key == expected.key
          && game.mapTargetSystem.name == expected.name)
      keys.insert(expected.key)
      names.insert(expected.name)
      #expect(game.commander == origin && game.selectedSystem == destination)
    }
    #expect(keys.count == 8 && names.count == 8)
  }
}

@Test func hyperspaceCommitsACurrentGalaxyPreviewBeforeTestingTheDestination() throws {
  var game = Game(executive: false)
  game.launch()
  try #require(!game.docked && game.commander.valid, "Native launch refused: \(game.message)")
  game.bodies = []
  game.selectedSystem = game.commander.system
  game.key("4")
  let next = try #require(
    game.knownSystems.first {
      $0.id != game.commander.system
        && game.currentSystem.distance(to: $0) <= game.commander.maximumJumpDistance
    })
  game.selectChartSystem(next.id)
  #expect(game.selectedSystem == game.commander.system)
  game.key("h")
  #expect(game.selectedSystem == next.id && game.jumpCountdown != nil)
}
