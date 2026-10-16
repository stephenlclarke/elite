import Foundation
import Testing

@testable import EliteCore

private func navigationGame() -> Game {
  var game = Game(executive: false)
  game.screen = .chart
  game.commander.installNavigationComputer(.military)
  game.commander.credits = 500_000
  return game
}
private func longRoute(_ game: Game) -> [Int] {
  let graph = NavigationGraph(game: game)
  for system in game.systems where game.currentSystem.distance(to: system) > 14 {
    if let path = graph.path(
      from: game.commander.system, to: system.id, fuel: game.commander.fuel, scoring: 0),
      path.count > 3
    {
      return path
    }
  }
  return []
}
@Test func navigationTiersUseSpecifiedPricesFuelBasedScopeAndOneInstalledUpgrade() throws {
  var game = Game(executive: false)
  game.screen = .chart
  game.commander.credits = 500_000
  game.commander.system = try #require(game.systems.firstIndex { $0.technology >= 10 })
  try game.commander.prepareEquipment(legacy: false)
  let basic = try #require(game.commander.fittedEquipment(at: .navigation))
  #expect(basic.provenance == .standard && game.commander.navigationTier == .basic)
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == NavigationTier.basic.equipmentName })
  let standard = game.commander
  game.purchase()
  #expect(
    game.commander == standard && game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  #expect(game.message == "STANDARD OR ACQUISITION HARDWARE - NOT FOR SALE")
  game.commander.fuel = 20
  #expect(game.navigationPlanningRadius == 14 && game.commander.maximumJumpDistance == 2)
  #expect(game.commander.fittedComponent(at: .navigation)?.statistics[.jumpReach] == 7)
  #expect(
    game.systems.filter { game.canPlan(to: $0) }.allSatisfy {
      game.currentSystem.distance(to: $0) <= 14
    })
  for (tier, reach) in [(NavigationTier.advanced, 14.0), (.military, 21.0)] {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == tier.equipmentName })
    let cash = game.commander.credits
    game.purchase()
    #expect(game.commander.credits == cash - tier.price && game.commander.navigationTier == tier)
    #expect(game.commander.fittedComponent(at: .navigation)?.statistics[.jumpReach] == reach)
    #expect(game.commander.equipmentPurchaseHistory?.paid.last?.node.key == tier.equipmentName)
    #expect(game.commander.fuel == 20)
    if tier == .advanced { #expect(game.navigationPlanningRadius == 21) }
  }
  #expect(game.navigationPlanningRadius == nil && game.knownSystems.allSatisfy(game.canPlan))
  #expect(NavigationTier.allCases.map(\.price) == [10000, 30000, 90000])
  #expect(game.commander.equipmentPurchaseHistory?.paid.count == 2 && game.commander.valid)
  game.commander.fuel = 0
  game.selectedSystem = 129
  game.key("n")
  #expect(game.screen == .chart && game.message == "REFUELLING NEEDED BEFORE PLANNING")
}
@Test func routeAlternativesHaveLegalFuelAwareHopsStableEstimatesAndNoDuplicatePaths() {
  var game = navigationGame()
  game.commander.cargo[0] = 10
  let path = longRoute(game)
  #expect(path.count > 3)
  let options = NavigationGraph(game: game).alternatives(destination: path.last!, tier: .military)
  #expect(!options.isEmpty && Set(options.map { $0.plan.path }).count == options.count)
  for route in options {
    #expect(
      route.plan.valid && route.plan.path.first == game.commander.system
        && route.plan.destination == path.last!)
    #expect(
      zip(route.plan.path, route.plan.path.dropFirst()).allSatisfy {
        game.systems[$0].distance(to: game.systems[$1]) <= 7
      })
    #expect(
      route.distance > 0 && route.fuelUnits > 0 && route.cargoSale >= 0 && route.tradeEstimate >= 0)
  }
  game.commander.fuel = 1
  #expect(
    NavigationGraph(game: game).path(
      from: game.commander.system, to: path.last!, fuel: 1, scoring: 0) == nil)
}
@Test func routesAdvanceOnlyOnDockingAndLaunchPreloadsEveryNextLegWithoutStartingJump() throws {
  var game = navigationGame()
  let path = longRoute(game)
  #expect(path.count > 3)
  game.commander.navigationPlan = .init(galaxy: 0, path: path, tier: .military, originFuel: 70)
  game.commander.autoTrade = true
  for stop in 0..<(path.count - 1) {
    game.launch()
    #expect(game.selectedSystem == path[stop + 1] && game.jumpCountdown == nil)
    game.bodies = []
    game.arrive()
    #expect(game.commander.navigationPlan?.stopIndex == stop)
    game.dock()
    #expect(game.commander.navigationPlan?.stopIndex == stop + 1 && game.commander.fuel == 70)
  }
  #expect(game.commander.navigationPlan?.complete == true)
  game.launch()
  #expect(game.jumpCountdown == nil)
}
@Test func autoTradePaysForFullFuelBeforeExportsAndLeavesNavigationRouteIntact() {
  var game = navigationGame()
  let path = longRoute(game)
  game.commander.navigationPlan = .init(galaxy: 0, path: path, tier: .military, originFuel: 70)
  game.commander.fuel = 0
  game.commander.credits = 140
  game.autoTrade()
  #expect(
    game.commander.fuel == 70 && game.commander.credits == 0
      && game.commander.cargo.allSatisfy { $0 == 0 })
  #expect(game.commander.navigationPlan?.path == path)
  game.commander.fuel = 0
  game.commander.credits = 139
  game.autoTrade()
  #expect(
    game.commander.fuel == 0 && game.commander.credits == 139
      && game.message == "INSUFFICIENT FUNDS FOR FULL FUEL")
  game.commander.unlimitedCash = true
  game.autoTrade()
  #expect(game.commander.fuel == 70 && game.commander.credits == 139)
  game.commander.fuel = 0
  game.commander.unlimitedFuel = true
  game.commander.unlimitedCash = false
  game.commander.credits = 0
  game.commander.cargo = Array(repeating: 0, count: 17)
  game.autoTrade()
  #expect(game.commander.fuel == 70 && game.commander.credits == 0)
  game.launch()
  game.commander.fuel = 10
  game.autoTrade()
  #expect(game.commander.fuel == 10)
}
@Test func navigationSaveLoadManualSelectionAndGalaxyChangesCannotLeaveStalePreloads() async throws
{
  var game = navigationGame()
  let path = longRoute(game)
  game.commander.navigationPlan = .init(galaxy: 0, path: path, tier: .military, originFuel: 70)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().commander.navigationPlan?.path == path)
  await runtime.key("0")
  #expect(await runtime.snapshot().selectedSystem == path[1])
  game.manuallySelectSystem(129)
  #expect(game.commander.navigationPlan == nil && game.selectedSystem == 129)
  game.commander.navigationPlan = .init(galaxy: 0, path: path, tier: .military, originFuel: 70)
  game.launch()
  game.selectedSystem = (path[1] + 1) % 256
  game.arrive()
  #expect(game.commander.navigationPlan == nil)
  game.commander.navigationPlan = .init(galaxy: 0, path: path, tier: .military, originFuel: 70)
  game.commander.equipment.insert("Galactic Hyperdrive")
  game.galacticJump()
  #expect(game.commander.navigationPlan == nil)
}
@Test func routePlanningScreenFreezesFlightAndCanCommitOrCancelWithoutJumping() {
  var game = navigationGame()
  let path = longRoute(game)
  game.selectedSystem = path.last!
  game.docked = false
  game.speed = 8
  game.key("n")
  #expect(game.screen == .navigation && !game.navigationOptions.isEmpty)
  let time = game.time
  game.tick(delta: 0.1)
  #expect(game.time == time)
  for width in [512.0, 1512] {
    let frame = Display.navigation(game, width: width, height: 518)
    for label in frame.labels { #expect(label.bounds.maxX <= width && label.bounds.maxY <= 518) }
  }
  game.key("down")
  game.key("up")
  game.key("pagedown")
  game.key("pageup")
  game.key("return")
  #expect(
    game.screen == .chart && game.commander.navigationPlan != nil && game.jumpCountdown == nil)
  game.cancelNavigation()
  #expect(game.commander.navigationPlan == nil)
  game.key("/")
  game.key("n")
  #expect(game.mapSearch.query == "n" && game.screen == .chart)
}

@Test func activeRouteInspectionUsesFixedOriginScopeAfterHopsAndMapBrowsingPreservesIt() {
  var game = navigationGame()
  let path = longRoute(game)
  game.commander.navigationPlan = .init(galaxy: 0, path: path, tier: .basic, originFuel: 70)
  game.launch()
  game.arrive()
  game.dock()
  game.launch()
  let next = game.selectedSystem
  game.screen = .chart
  game.commander.fuel = 1
  game.key("n")
  #expect(game.screen == .navigation && game.navigationOptions.first?.plan.path == path)
  #expect(
    game.navigationOptions.first?.plan.originFuel == 70
      && game.navigationOptions.first?.plan.stopIndex == 1)
  game.key("escape")
  let layout = ChartLayout(
    width: game.viewportWidth, height: game.viewportHeight, local: false, docked: game.docked)
  let point = layout.point(game.systems[next], current: game.currentSystem)
  game.mapClick(x: point.x, y: point.y)
  #expect(game.commander.navigationPlan?.path == path && game.selectedSystem == next)
}
@Test func infeasibleGraphAndInvalidSavedLegNeverProduceInventedHops() {
  var game = navigationGame()
  let invalid = NavigationPlan(galaxy: 0, path: [7, 0], tier: .military, originFuel: 70)
  game.commander.navigationPlan = invalid
  game.navigationDocked()
  #expect(game.commander.navigationPlan == nil)
  game.systems = game.systems.map { value in
    StarSystem(
      id: value.id, name: value.name, x: value.id == 7 ? 0 : 255, y: value.id == 7 ? 0 : 255,
      economy: value.economy, government: value.government, technology: value.technology,
      population: value.population, productivity: value.productivity, radius: value.radius,
      seed: value.seed)
  }
  #expect(NavigationGraph(game: game).alternatives(destination: 0, tier: .military).isEmpty)
}
