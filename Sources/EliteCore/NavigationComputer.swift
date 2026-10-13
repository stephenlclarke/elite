import Foundation

public enum NavigationTier: Int, Sendable, Codable, CaseIterable, Comparable {
  case basic = 1
  case advanced, military
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
  public var label: String {
    switch self {
    case .basic: "Basic"
    case .advanced: "Advanced"
    case .military: "Military"
    }
  }
  public var equipmentName: String { "Navigation: " + label }
  public var price: Int { [10000, 30000, 90000][rawValue - 1] }
  public var jumpCap: Double { Double(rawValue * 7) }
  public var technology: Int { [4, 7, 10][rawValue - 1] }
  public func radius(capacity: Int) -> Double? {
    self == .military ? nil : Double(capacity) / 10 + (self == .basic ? 7 : 14)
  }
  static func from(_ name: String) -> Self? { allCases.first { $0.equipmentName == name } }
}
public struct NavigationPlan: Sendable, Codable, Equatable {
  public let galaxy: Int
  public let path: [Int]
  public let tier: NavigationTier
  public let originFuel: Int
  public var originCapacity: Int? = nil
  public var capacityAtPlanning: Int { originCapacity ?? 70 }
  public var stopIndex = 0
  public var complete: Bool { stopIndex == path.count - 1 }
  public var nextSystem: Int? { valid && !complete ? path[stopIndex + 1] : nil }
  public var destination: Int { path.last ?? 0 }
  public var valid: Bool {
    (0..<8).contains(galaxy) && (2...257).contains(path.count)
      && path.allSatisfy { (0...256).contains($0) }
      && Set(path).count == path.count && path.indices.contains(stopIndex)
      && (1...(10000 + FuelStorage.maximumCount * FuelStorage.unitCapacity)).contains(
        capacityAtPlanning)
      && (0...capacityAtPlanning).contains(originFuel)
  }
}
public struct RouteAlternative: Sendable {
  public var labels: [String]
  public let plan: NavigationPlan
  public let distance: Double
  public let fuelUnits: Int
  public let risk: Double
  public let cargoSale: Double
  public let tradeEstimate: Double
}
extension Commander {
  public var navigationTier: NavigationTier? { equipment.compactMap(NavigationTier.from).max() }
  public mutating func installNavigationComputer(_ tier: NavigationTier) {
    let effective = max(tier, navigationTier ?? tier)
    equipment.subtract(NavigationTier.allCases.map(\.equipmentName))
    equipment.insert(effective.equipmentName)
  }
}

/// Every hop obeys the installed computer and tank; later stops assume station refuelling.
struct NavigationGraph {
  let game: Game
  let edges: [[Int]]
  init(game: Game) {
    self.game = game
    edges = game.systems.map { source in
      game.knownSystems.filter {
        $0.id != source.id
          && source.distance(to: $0)
            <= min(game.commander.jumpCap, Double(game.commander.fuelCapacity) / 10)
      }.map(\.id)
    }
  }
  func trade(_ a: Int, _ b: Int) -> Double {
    let market =
      a == game.commander.system
      ? game.market : MarketItem.at(game.systems[a], fluctuation: 0)
    let sale = MarketItem.minimumPrices(at: game.systems[b])
    return Commodity.all.indices.map { index in
      Double(max(0, sale[index] - market[index].price))
        * min(63, Double(market[index].quantity), Double(game.commander.capacity))
    }.max() ?? 0
  }
  func cargoSale(_ id: Int) -> Double {
    zip(game.commander.cargo, MarketItem.minimumPrices(at: game.systems[id])).reduce(0) {
      $0 + Double($1.0) * Double($1.1)
    }
  }
  func path(from origin: Int, to destination: Int, fuel: Int, scoring: Int) -> [Int]? {
    let count = game.systems.count
    var costs = [Double](repeating: .infinity, count: count)
    costs[origin] = 0
    var previous = [Int?](repeating: nil, count: count)
    var visited: Set<Int> = []
    for _ in 0..<count {
      guard
        let node = costs.indices.filter({ !visited.contains($0) && costs[$0].isFinite }).min(by: {
          costs[$0] == costs[$1] ? $0 < $1 : costs[$0] < costs[$1]
        })
      else { break }
      if node == destination { break }
      visited.insert(node)
      for next in edges[node] where !visited.contains(next) {
        let distance = game.systems[node].distance(to: game.systems[next])
        if node == origin && distance > Double(fuel) / 10 { continue }
        let risk = Double(7 - game.systems[next].government) * 0.15
        let weight: Double
        switch scoring {
        case 1: weight = 1 + risk
        case 2: weight = max(0.25, 1 + risk * 0.2 - trade(node, next) / 10000)
        default: weight = 1 + distance * 0.0001
        }
        let cost = costs[node] + weight
        if cost < costs[next] {
          costs[next] = cost
          previous[next] = node
        }
      }
    }
    guard costs[destination].isFinite else { return nil }
    var path = [destination]
    while path.last != origin {
      guard let parent = previous[path.last!], path.count <= count else { return nil }
      path.append(parent)
    }
    return path.reversed()
  }
  func alternatives(destination: Int, tier: NavigationTier) -> [RouteAlternative] {
    let origin = game.commander.system
    let fuel = game.commander.availableJumpFuel
    var candidates: [(String, [Int])] = []
    for (score, label) in [(0, "Fewest Jumps"), (1, "Safest"), (2, "Trade Opportunities")] {
      if let path = path(from: origin, to: destination, fuel: fuel, scoring: score) {
        if score == 2 && zip(path, path.dropFirst()).reduce(0.0, { $0 + trade($1.0, $1.1) }) <= 0 {
          continue
        }
        candidates.append((label, path))
      }
    }
    if game.commander.cargo.contains(where: { $0 > 0 }) {
      let waypoints = game.knownSystems.filter { $0.id != origin && $0.id != destination }.sorted {
        a, b in cargoSale(a.id) == cargoSale(b.id) ? a.id < b.id : cargoSale(a.id) > cargoSale(b.id)
      }.prefix(8)
      var best: (path: [Int], value: Double)?
      for waypoint in waypoints {
        guard let first = path(from: origin, to: waypoint.id, fuel: fuel, scoring: 0),
          let last = path(
            from: waypoint.id, to: destination, fuel: game.commander.fuelCapacity, scoring: 0)
        else { continue }
        let combined = first + last.dropFirst()
        guard Set(combined).count == combined.count else { continue }
        let value = cargoSale(waypoint.id)
        if best == nil || value > best!.value { best = (combined, value) }
      }
      if let best, best.value > cargoSale(destination) {
        candidates.append(("Best Cargo Sale", best.path))
      }
    }
    var result: [RouteAlternative] = []
    for (label, path) in candidates {
      if let index = result.firstIndex(where: { $0.plan.path == path }) {
        result[index].labels.append(label)
        continue
      }
      result.append(
        summary(
          plan: .init(
            galaxy: game.commander.galaxy, path: path, tier: tier, originFuel: fuel,
            originCapacity: game.commander.fuelCapacity),
          labels: [label]))
    }
    return result
  }
  func summary(plan: NavigationPlan, labels: [String]) -> RouteAlternative {
    let legs = Array(zip(plan.path, plan.path.dropFirst()))
    let distance = legs.reduce(0.0) { $0 + game.systems[$1.0].distance(to: game.systems[$1.1]) }
    let units = legs.reduce(0) {
      $0 + Int((game.systems[$1.0].distance(to: game.systems[$1.1]) * 10).rounded())
    }
    let risk = plan.path.dropFirst().reduce(0.0) {
      $0 + Double(7 - game.systems[$1].government) * 0.15
    }
    return .init(
      labels: labels, plan: plan, distance: distance, fuelUnits: units, risk: risk,
      cargoSale: plan.path.dropFirst().map(cargoSale).max() ?? 0,
      tradeEstimate: legs.reduce(0) { $0 + trade($1.0, $1.1) })
  }

}

extension Game {
  public var navigationPlanningRadius: Double? {
    commander.navigationTier?.radius(capacity: commander.fuelCapacity)
  }
  public func canPlan(to system: StarSystem) -> Bool {
    guard let tier = commander.navigationTier, knownSystems.contains(system) else { return false }
    return tier == .military
      || currentSystem.distance(to: system) <= (tier.radius(capacity: commander.fuelCapacity) ?? 0)
  }
  mutating func openNavigation() {
    if screen == .chart && !mapIsCurrentGalaxy {
      _ = prepareChartTravel()
      return
    }
    if commander.navigationPlan == nil && !prepareChartTravel() { return }
    if let plan = commander.navigationPlan, plan.valid, plan.galaxy == commander.galaxy,
      !plan.complete, selectedSystem == plan.nextSystem
    {
      navigationOptions = [
        NavigationGraph(game: self).summary(plan: plan, labels: ["Current route"])
      ]
      navigationReturn = screen
      navigationSelection = 0
      navigationScroll = 0
      screen = .navigation
      return
    }
    guard let tier = commander.navigationTier else {
      notify("FIT A NAVIGATIONAL COMPUTER")
      return
    }
    guard commander.availableJumpFuel > 0 else {
      notify("REFUELLING NEEDED BEFORE PLANNING")
      return
    }
    guard canPlan(to: targetSystem), selectedSystem != commander.system else {
      notify("DESTINATION OUTSIDE PLANNING RANGE")
      return
    }
    navigationOptions = NavigationGraph(game: self).alternatives(
      destination: selectedSystem, tier: tier)
    guard !navigationOptions.isEmpty else {
      notify("NO FEASIBLE ROUTE - CHECK FUEL")
      return
    }
    navigationReturn = screen
    navigationSelection = 0
    navigationScroll = 0
    screen = .navigation
  }
  mutating func navigationKey(_ key: String) {
    switch key {
    case "escape", "n": screen = navigationReturn
    case "k":
      helpReturn = .navigation
      helpPage = 0
      screen = .help
    case "up":
      navigationSelection = max(0, navigationSelection - 1)
      navigationScroll = 0
    case "down":
      navigationSelection = min(navigationOptions.count - 1, navigationSelection + 1)
      navigationScroll = 0
    case "pageup", "pagedown":
      navigationScroll = Display.navigationWindow(
        self, width: viewportWidth, height: viewportHeight
      ).moved(key == "pageup" ? -4 : 4)
    case "c":
      cancelNavigation()
      screen = navigationReturn
    case "return":
      guard navigationOptions.indices.contains(navigationSelection) else { return }
      commander.navigationPlan = navigationOptions[navigationSelection].plan
      if let next = commander.navigationPlan?.nextSystem { selectedSystem = next }
      screen = navigationReturn
      notify("ROUTE SET TO " + systems[commander.navigationPlan!.destination].name)
    default:
      if key.hasPrefix("route-scroll:"), let amount = Int(key.dropFirst(13)) {
        navigationScroll = Display.navigationWindow(
          self, width: viewportWidth, height: viewportHeight
        ).moved(amount)
      }
    }
  }
  public mutating func cancelNavigation() {
    commander.navigationPlan = nil
    jumpCountdown = nil
    selectedSystem = commander.system
    notify("NAVIGATION ROUTE CLEARED")
  }
  mutating func manuallySelectSystem(_ id: Int) {
    if commander.navigationPlan != nil {
      commander.navigationPlan = nil
      notify("ROUTE CLEARED - MANUAL DESTINATION")
    }
    jumpCountdown = nil
    selectedSystem = id
  }
  mutating func navigationDocked() {
    guard var plan = commander.navigationPlan else { return }
    guard commander.navigationTier != nil, plan.valid,
      zip(plan.path, plan.path.dropFirst()).allSatisfy({
        systems[$0].distance(to: systems[$1])
          <= min(commander.jumpCap, Double(commander.fuelCapacity) / 10)
      })
    else {
      commander.navigationPlan = nil
      notify("NAVIGATION ROUTE INVALID")
      return
    }
    guard plan.galaxy == commander.galaxy else {
      commander.navigationPlan = nil
      return
    }
    if plan.nextSystem == commander.system {
      plan.stopIndex += 1
      commander.navigationPlan = plan
      if plan.complete { notify("NAVIGATION DESTINATION REACHED") }
    } else if plan.path[plan.stopIndex] != commander.system {
      commander.navigationPlan = nil
      notify("ROUTE CANCELLED - OFF ROUTE")
    }
  }
  mutating func preloadNavigation() {
    guard let plan = commander.navigationPlan, !plan.complete else { return }
    guard plan.valid, commander.navigationTier != nil, plan.galaxy == commander.galaxy,
      plan.path[plan.stopIndex] == commander.system, let next = plan.nextSystem,
      currentSystem.distance(to: systems[next])
        <= min(commander.jumpCap, Double(commander.fuelCapacity) / 10)
    else {
      commander.navigationPlan = nil
      notify("NAVIGATION ROUTE INVALID")
      return
    }
    selectedSystem = next
    let cost = Int((currentSystem.distance(to: systems[next]) * 10).rounded())
    notify(
      "NEXT: " + systems[next].name
        + (cost <= commander.availableJumpFuel ? "" : " - REFUEL REQUIRED"))
  }
}
