import Foundation
import Testing

@testable import L337Core

@Test func profitScanDefaultsAndPersistence() throws {
  var game = Game(executive: false)
  #expect(!game.commander.profitScanEnabled && game.profitDestinations.isEmpty)
  game.screen = .status
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.commander.profitScanEnabled)
  game.screen = .shortChart
  game.key("p")
  #expect(!game.commander.profitScanEnabled)
  let saved = try JSONEncoder().encode(game.commander)
  #expect(try !JSONDecoder().decode(Commander.self, from: saved).profitScanEnabled)
  var legacy = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
  legacy.removeValue(forKey: "automaticProfitScan")
  #expect(
    try !JSONDecoder().decode(
      Commander.self,
      from: JSONSerialization.data(withJSONObject: legacy)
    ).profitScanEnabled)
}

@Test func profitScanRanksReachablePositiveDestinationsWithoutMutatingTrade() {
  var game = Game(executive: false)
  game.commander.profitScanEnabled = true
  game.commander.credits = 100000
  let before = game.commander
  let market = game.market
  let expected = game.knownSystems.filter {
    $0.id != game.commander.system
      && game.currentSystem.distance(to: $0) <= game.commander.maximumJumpDistance
      && game.estimatedTradeProfit(to: $0) > 0
  }.sorted {
    let a = game.estimatedTradeProfit(to: $0)
    let b = game.estimatedTradeProfit(to: $1)
    return a == b ? $0.id < $1.id : a > b
  }.prefix(5).map(\.id)
  #expect(!expected.isEmpty)
  #expect(game.profitDestinations.map(\.systemID) == expected)
  #expect(game.commander == before)
  #expect(game.market.map(\.quantity) == market.map(\.quantity))
  game.commander.fuel = 0
  #expect(game.profitDestinations.isEmpty)
  #expect(game.profitScanSummary.contains("NO PROFITABLE"))
}

@Test func profitScanRespectsCashStockAndHold() {
  var game = Game(executive: false)
  game.commander.profitScanEnabled = true
  game.commander.credits = 0
  #expect(game.profitDestinations.isEmpty)
  game.commander.credits = 100000
  for index in game.market.indices { game.market[index].quantity = 0 }
  #expect(game.profitDestinations.isEmpty)
}

@Test func profitScanHighlightsCurrentGalaxyAndCanToggleFromNavigation() {
  var game = Game(executive: false)
  game.commander.profitScanEnabled = true
  game.commander.credits = 100000
  game.screen = .shortChart
  let ranks = game.profitDestinations
  #expect(!ranks.isEmpty)
  let frame = Display.map(game, width: 1512, height: 900)
  #expect(frame.labels.contains { $0.text == "1 " + game.systems[ranks[0].systemID].name })
  game.screen = .navigation
  game.key("p")
  #expect(!game.commander.profitScanEnabled)
  game.key("p")
  #expect(game.commander.profitScanEnabled)
}

@Test func profitScanEconomicsUsesOneSharedBudgetAndHoldInsteadOfSummingFullLoads() {
  var game = Game(executive: false)
  let destination = game.systems[0]
  let prices = MarketItem.minimumPrices(at: destination)
  for index in game.market.indices {
    game.market[index].price = prices[index] + 100
    game.market[index].bidPrice = prices[index] + 90
    game.market[index].quantity = 0
  }
  // Two tonne commodities compete for the same cash and hold; higher margin buys first.
  game.market[0].price = 1
  game.market[0].bidPrice = 1
  game.market[0].quantity = 100
  game.market[1].price = 1
  game.market[1].bidPrice = 1
  game.market[1].quantity = 100
  game.commander.credits = 3
  let bestMargin = max(prices[0], prices[1]) - 1
  #expect(game.estimatedTradeProfit(to: destination) == 3 * bestMargin)
  game.commander.credits = 100000
  let hold = game.commander.capacity
  #expect(game.estimatedTradeProfit(to: destination) == min(100, hold) * bestMargin)
  game.market[0].quantity = 0
  game.market[1].quantity = 0
  game.commander.cargo[0] = 2
  // Carried cargo competes with selling here at the local bid, never the ask.
  game.market[0].bidPrice = prices[0] + 10
  game.market[0].price = game.market[0].bidPrice + 5
  #expect(game.estimatedTradeProfit(to: destination) == -20)
}
