import Testing

@testable import EliteCore

/// A diamond with two legal two-hop routes and no invented cross-galaxy links.
private func routePreviewGame(local: Bool = false) -> Game {
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  game.commander.system = 7
  game.commander.fuel = 70
  game.systems = game.systems.map { system in
    let coordinates: (Double, Double)
    switch system.id {
    case 7: coordinates = (0, 0)
    case 0: coordinates = (4, 0)
    case 1: coordinates = (8, 0)
    case 2: coordinates = (4, 3.2)
    default: coordinates = (255, 255)
    }
    return StarSystem(
      id: system.id, name: system.name, x: coordinates.0, y: coordinates.1,
      economy: 5, government: system.id == 0 ? 0 : 7, technology: system.technology,
      population: system.population, productivity: system.productivity, radius: system.radius,
      seed: system.seed)
  }
  game.market = MarketItem.at(game.currentSystem)
  game.screen = local ? .shortChart : .chart
  game.selectedSystem = 1
  game.galacticBrowse.targets[0] = 1
  return game
}

@Test func routePreviewDiamondOffersDistinctLegalAlternativesWithMergedLabels() throws {
  let game = routePreviewGame()
  let routes = NavigationGraph(game: game).alternatives(destination: 1, tier: .military)
  #expect(routes.count >= 2)
  #expect(Set(routes.map { $0.plan.path }).count == routes.count)
  for route in routes {
    #expect(route.plan.valid && route.plan.path.first == 7 && route.plan.destination == 1)
    #expect(route.plan.path.count == 3)
    #expect(
      zip(route.plan.path, route.plan.path.dropFirst()).allSatisfy {
        game.systems[$0].distance(to: game.systems[$1]) <= 7
      })
    #expect(game.currentSystem.distance(to: game.systems[route.plan.path[1]]) <= 7)
  }
}

@Test func routePreviewPlannerHandlesOneNoAndSameTargetRoutes() {
  var game = routePreviewGame()
  let one = NavigationGraph(game: game).alternatives(destination: 0, tier: .military)
  #expect(one.count == 1 && one.first?.plan.path == [7, 0])
  #expect((one.first?.labels.count ?? 0) >= 2)
  game.commander.fuel = 1
  #expect(NavigationGraph(game: game).alternatives(destination: 1, tier: .military).isEmpty)
  game.commander.fuel = 70
  #expect(NavigationGraph(game: game).alternatives(destination: 7, tier: .military).isEmpty)
}

@Test func routePreviewKeyboardChangesPreviewOnlyThenExplicitlyCommits() throws {
  for local in [false, true] {
    var game = routePreviewGame(local: local)
    let before = game.commander
    let target = game.selectedSystem
    game.key("n")
    #expect(game.screen == .navigation)
    #expect(game.navigationOptions.count >= 2)
    game.key("down")
    #expect(game.navigationSelection == 1)
    #expect(game.commander == before && game.selectedSystem == target && game.jumpCountdown == nil)
    let chosen = game.navigationOptions[game.navigationSelection].plan
    game.key("return")
    #expect(game.screen == (local ? .shortChart : .chart))
    #expect(game.commander.navigationPlan == chosen)
    #expect(game.selectedSystem == chosen.nextSystem && game.jumpCountdown == nil)
  }
}

@Test func routePreviewEscapePreservesExistingRouteAndTravelTarget() throws {
  var game = routePreviewGame()
  let original = NavigationPlan(galaxy: 0, path: [7, 0, 1], tier: .military, originFuel: 70)
  game.commander.navigationPlan = original
  game.selectedSystem = 0
  game.galacticBrowse.targets[0] = 1
  let commander = game.commander
  game.key("n")
  #expect(game.screen == .navigation)
  game.key("down")
  #expect(game.commander == commander && game.selectedSystem == 0)
  game.key("escape")
  #expect(game.screen == .chart && game.commander == commander && game.selectedSystem == 0)
}

@Test func routePreviewRejectsStaleFuelTierGalaxyAndOriginWithoutReplacingPlan() {
  for change in 0..<6 {
    var game = routePreviewGame()
    game.key("n")
    #expect(game.screen == .navigation && !game.navigationOptions.isEmpty)
    switch change {
    case 0: game.commander.fuel = 0
    case 1: game.commander.equipment.remove(NavigationTier.military.equipmentName)
    case 2: game.commander.galaxy = 1
    case 3: game.commander.system = 0
    case 4: game.commander.fuelStorageUnits = 1
    default:
      let unknown = NavigationPlan(galaxy: 0, path: [7, 256, 1], tier: .military, originFuel: 70)
      game.navigationOptions = [
        NavigationGraph(game: game).summary(plan: unknown, labels: ["Unknown stop"])
      ]
    }
    let before = game.commander.navigationPlan
    let target = game.selectedSystem
    game.key("return")
    #expect(game.commander.navigationPlan == before && game.selectedSystem == target)
    #expect(game.jumpCountdown == nil)
  }
}

@Test func routePreviewPointerSelectionRequiresSetAndBackCancelsWithoutMutation() throws {
  var game = routePreviewGame(local: true)
  game.key("n")
  let layout = NavigationPreviewLayout(
    game: game, width: game.viewportWidth, height: game.viewportHeight)
  #expect(layout.candidateRects.count == game.navigationOptions.count)
  let candidate = try #require(layout.candidateRects.dropFirst().first)
  let before = game.commander
  let target = game.selectedSystem
  game.mapClick(x: candidate.x + candidate.width / 2, y: candidate.y + candidate.height / 2)
  #expect(game.navigationSelection == 1)
  #expect(game.commander == before && game.selectedSystem == target)
  game.mapClick(x: layout.backRect.x + 2, y: layout.backRect.y + 2)
  #expect(game.screen == .shortChart && game.commander == before && game.selectedSystem == target)
  game.key("n")
  let chosen = game.navigationOptions[game.navigationSelection].plan
  let confirm = NavigationPreviewLayout(
    game: game, width: game.viewportWidth, height: game.viewportHeight)
  game.mapClick(x: confirm.setRect.x + 2, y: confirm.setRect.y + 2)
  #expect(game.commander.navigationPlan == chosen && game.jumpCountdown == nil)
}

@Test func routePreviewUsesReturningChartAndKeepsCompactControlsInsideCanvas() {
  for local in [false, true] {
    var game = routePreviewGame(local: local)
    game.key("n")
    for (width, height) in [(512.0, 518.0), (768, 600), (1512, 900)] {
      let layout = NavigationPreviewLayout(game: game, width: width, height: height)
      #expect(layout.chart.local == local)
      #expect(layout.plot.width > 0 && layout.plot.height > 0)
      for rect in layout.candidateRects + [layout.setRect, layout.backRect, layout.plot] {
        #expect(rect.x >= 0 && rect.y >= 0 && rect.maxX <= width && rect.maxY <= height)
      }
      let frame = Display.navigation(game, width: width, height: height)
      #expect(frame.responsive && !frame.worldGraphics.isEmpty)
      #expect(frame.flightClip == layout.plot)
      for graphic in frame.worldGraphics {
        if case .line(let line) = graphic {
          for (x, y) in [(line.x0, line.y0), (line.x1, line.y1)] {
            #expect(x >= layout.plot.x - 1e-8 && x <= layout.plot.maxX + 1e-8)
            #expect(y >= layout.plot.y - 1e-8 && y <= layout.plot.maxY + 1e-8)
          }
        }
      }
      for label in frame.labels {
        #expect(label.bounds.x >= 0 && label.bounds.y >= 0)
        #expect(label.bounds.maxX <= width && label.bounds.maxY <= height)
      }
    }
  }
}

@Test func routePreviewCurrentRouteInspectionRetainsConsumedLegsAndCancelsSafely() {
  var game = routePreviewGame(local: true)
  let active = NavigationPlan(
    galaxy: 0, path: [7, 0, 1], tier: .military, originFuel: 70, stopIndex: 1)
  game.commander.system = 0
  game.commander.navigationPlan = active
  game.selectedSystem = 1
  game.key("n")
  #expect(game.screen == .navigation)
  #expect(game.navigationOptions.contains { $0.plan == active })
  game.key("escape")
  #expect(game.commander.navigationPlan == active && game.selectedSystem == 1)
  game.key("n")
  game.key("return")
  #expect(game.commander.navigationPlan == active && game.selectedSystem == 1)
  #expect(game.jumpCountdown == nil)
}

@Test func routePreviewLegClippingPreservesCrossingsAndRejectsOutsideParallelSegments() throws {
  let rect = CanvasRect(x: 10, y: 20, width: 100, height: 80)
  let crossing = try #require(Display.clippedRouteLeg(.init(-40, 60), .init(160, 60), to: rect))
  #expect(crossing.0 == ScreenPoint(10, 60) && crossing.1 == ScreenPoint(110, 60))
  let reverse = try #require(Display.clippedRouteLeg(.init(160, 60), .init(-40, 60), to: rect))
  #expect(reverse.0 == crossing.1 && reverse.1 == crossing.0)
  let vertical = try #require(Display.clippedRouteLeg(.init(60, 0), .init(60, 140), to: rect))
  #expect(vertical.0 == ScreenPoint(60, 20) && vertical.1 == ScreenPoint(60, 100))
  #expect(Display.clippedRouteLeg(.init(-1, 0), .init(-1, 140), to: rect) == nil)
  #expect(Display.clippedRouteLeg(.init(11, 21), .init(11, 21), to: rect) != nil)
  #expect(Display.clippedRouteLeg(.init(0, 0), .init(0, 0), to: rect) == nil)
}

@Test func routePreviewFourCandidatesKeepHitTargetsSeparateInSmallWindows() throws {
  var game = routePreviewGame(local: true)
  game.key("n")
  let route = try #require(game.navigationOptions.first)
  game.navigationOptions = Array(repeating: route, count: 4)
  for (width, height) in [(320.0, 400.0), (400, 320)] {
    let layout = NavigationPreviewLayout(game: game, width: width, height: height)
    #expect(layout.candidateRects.count == 4)
    for rect in layout.candidateRects {
      #expect(rect.x >= 0 && rect.maxX <= width && rect.y >= layout.plot.maxY)
      #expect(rect.maxY <= layout.setRect.y)
      #expect(!rect.overlaps(layout.setRect) && !rect.overlaps(layout.backRect))
    }
    let frame = Display.navigation(game, width: width, height: height)
    for label in frame.labels {
      #expect(label.bounds.x >= 0 && label.bounds.y >= 0)
      #expect(label.bounds.maxX <= width && label.bounds.maxY <= height)
    }
  }
}

@Test func routePreviewExplicitCommitReplacesPendingJumpButBackAndStaleCandidatePreserveIt() {
  var game = routePreviewGame(local: true)
  game.docked = false
  game.jumpCountdown = 3
  let commander = game.commander
  let selected = game.selectedSystem
  game.key("n")
  #expect(game.screen == .navigation)
  #expect(game.jumpCountdown == 3 && game.selectedSystem == selected && game.commander == commander)
  game.key("down")
  game.key("escape")
  #expect(game.screen == .shortChart && game.jumpCountdown == 3)
  #expect(game.commander == commander && game.selectedSystem == selected)
  game.key("n")
  game.key("down")
  let chosen = game.navigationOptions[game.navigationSelection].plan
  game.key("return")
  #expect(game.commander.navigationPlan == chosen && game.selectedSystem == chosen.nextSystem)
  #expect(game.jumpCountdown == nil && game.screen == .shortChart)
  #expect(game.message.contains("JUMP CANCELLED"))

  var stale = routePreviewGame(local: true)
  stale.docked = false
  stale.jumpCountdown = 3
  stale.key("n")
  stale.commander.fuel = 0
  let before = stale.commander
  let target = stale.selectedSystem
  stale.key("return")
  #expect(stale.commander == before && stale.selectedSystem == target && stale.jumpCountdown == 3)
  #expect(stale.message.contains("ROUTE CHANGED"))
}

@Test func routePreviewChartSwitchingPreservesCandidatesPreviewAndActiveTravel() {
  var game = routePreviewGame(local: true)
  game.key("n")
  game.key("down")
  let paths = game.navigationOptions.map { $0.plan.path }
  let selection = game.navigationSelection
  let commander = game.commander
  let target = game.selectedSystem
  for key in ["4", "5", "4"] {
    game.key(key)
    #expect(
      game.screen == .navigation && game.navigationReturn == (key == "5" ? .shortChart : .chart))
    #expect(
      game.navigationOptions.map { $0.plan.path } == paths && game.navigationSelection == selection)
    #expect(
      game.commander == commander && game.selectedSystem == target && game.jumpCountdown == nil)
    let layout = NavigationPreviewLayout(game: game, width: 768, height: 600)
    #expect(layout.chart.local == (key == "5"))
  }
}

@Test func routePreviewConsumedLegsAreExcludedFromEveryRemainingEstimate() {
  var game = routePreviewGame(local: true)
  let plan = NavigationPlan(
    galaxy: 0, path: [7, 0, 1], tier: .military, originFuel: 70, stopIndex: 1)
  game.commander.system = 0
  game.commander.navigationPlan = plan
  game.commander.cargo[0] = 2
  game.selectedSystem = 1
  game.market = MarketItem.at(game.currentSystem)
  for index in game.market.indices { game.market[index].quantity = 0 }
  game.market[0].price = 1
  game.market[0].quantity = 3
  let destinationPrices = MarketItem.minimumPrices(at: game.systems[1])
  let remaining = NavigationGraph(game: game).summary(plan: plan, labels: ["Current route"])
  #expect(remaining.plan == plan)
  #expect(remaining.distance == 4 && remaining.fuelUnits == 40)
  #expect(remaining.risk == 0)
  #expect(remaining.tradeEstimate == Double(max(0, destinationPrices[0] - 1) * 3))
  #expect(remaining.cargoSale == Double(destinationPrices[0] * 2))
  game.key("n")
  let lines = Display.navigationSummary(game, width: 1512)
  #expect(lines.contains { $0.hasPrefix("1 jumps") })
  #expect(!lines.contains { $0.hasPrefix("2 jumps") })
  let remainingPath = "Route: " + game.systems[0].name + " > " + game.systems[1].name
  #expect(lines.contains(remainingPath))
}

@Test func routePreviewPausedPointerAndReturnCannotChangePreviewOrTravel() throws {
  var game = routePreviewGame(local: true)
  game.docked = false
  game.jumpCountdown = 3
  game.key("n")
  game.paused = true
  let commander = game.commander
  let target = game.selectedSystem
  let preview = game.navigationSelection
  let paths = game.navigationOptions.map { $0.plan.path }
  let layout = NavigationPreviewLayout(
    game: game, width: game.viewportWidth, height: game.viewportHeight)
  let candidate = try #require(layout.candidateRects.dropFirst().first)
  for rect in [candidate, layout.setRect, layout.backRect] {
    game.mapClick(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
    #expect(game.commander == commander && game.selectedSystem == target && game.jumpCountdown == 3)
    #expect(
      game.navigationSelection == preview && game.navigationOptions.map { $0.plan.path } == paths)
    #expect(game.screen == .navigation && game.paused)
  }
  game.key("return")
  #expect(game.commander == commander && game.selectedSystem == target && game.jumpCountdown == 3)
  #expect(game.navigationSelection == preview && game.screen == .navigation && game.paused)
}
