import Testing

@testable import EliteCore

@Test func galaxySelectorBrowsesEightRealCataloguesWithoutChangingFlightState() {
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  game.commander.navigationPlan = .init(galaxy: 0, path: [7, 129], tier: .military, originFuel: 70)
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
    #expect(frame.labels.contains { $0.text == "Viewing Galaxy \(galaxy + 1)" })
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
  for galaxy in 0..<8 {
    game.viewGalaxy(galaxy)
    game.key("/")
    for key in "xyzzy" { game.key(String(key)) }
    #expect(game.commander.name == "JAMESON" && game.screen == .chart)
    game.key("search-clear")
    game.key("down")
    let expected = game.searchResults[1]
    game.key("return")
    #expect(game.mapTargetSystem == expected)
    let layout = ChartLayout(width: 768, height: 768, local: false, docked: game.docked)
    let point = layout.point(expected, current: game.currentSystem)
    let frame = Display.presentation(game, width: 768, height: 768)
    #expect(
      frame.worldGraphics.contains {
        if case .ellipse(let p, _, _, .white) = $0 { return p == point }
        return false
      })
    game.key("6")
    #expect(game.inspectedGalaxy == galaxy && game.inspectedSystem == expected)
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

@Test func browsingDuplicateSystemIDsAndNamesDoesNotRebindTheTravelDestination() {
  var game = Game(executive: false)
  game.screen = .chart
  let galaxies = (0..<8).map { Universe.galaxy(number: $0) }
  var names: [String: (Int, Int)] = [:]
  var foundDuplicate = false
  for (galaxy, systems) in galaxies.enumerated() {
    for system in systems {
      if let previous = names[system.name], previous.0 != galaxy {
        game.viewGalaxy(previous.0)
        game.selectChartSystem(previous.1)
        #expect(game.mapTargetSystem == galaxies[previous.0][previous.1])
        game.viewGalaxy(galaxy)
        game.selectChartSystem(system.id)
        #expect(game.mapTargetSystem == system && game.viewedGalaxy == galaxy)
        foundDuplicate = true
      }
      names[system.name] = (galaxy, system.id)
    }
  }
  #expect(foundDuplicate && game.selectedSystem == 7 && game.commander.galaxy == 0)
}

@Test func hyperspaceCommitsACurrentGalaxyPreviewBeforeTestingTheDestination() {
  var game = Game(executive: false)
  game.launch()
  game.bodies = []
  game.selectedSystem = game.commander.system
  game.key("4")
  let next = game.systems.first {
    $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
  }!
  game.selectChartSystem(next.id)
  #expect(game.selectedSystem == game.commander.system)
  game.key("h")
  #expect(game.selectedSystem == next.id && game.jumpCountdown != nil)
}
