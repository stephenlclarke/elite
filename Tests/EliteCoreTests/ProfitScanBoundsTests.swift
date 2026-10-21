import Foundation
import Testing

@testable import EliteCore

private func boundedProfitFixture() -> (Game, StarSystem) {
  var game = Game(executive: false)
  game.commander.unlimitedCargo = true
  game.commander.credits = 0
  let destination = game.systems.first { $0.economy == 0 }!
  let prices = MarketItem.minimumPrices(at: destination)
  game.market = prices.map { .init(price: $0, quantity: 0) }
  return (game, destination)
}

struct ProfitScanBoundsTests {
  @Test func finalIntegerBoundsRemainExactWithoutFloatingPointConversion() {
    var (game, destination) = boundedProfitFixture()
    let prices = MarketItem.minimumPrices(at: destination)
    game.commander.cargo[0] = Int.max / 17
    game.commander.cargo[13] = Int.max % 17 - 1
    game.market[0].price = prices[0] - 17
    game.market[13].price = prices[13] - 1
    #expect(game.commander.valid)
    #expect(game.estimatedTradeProfit(to: destination) == Int.max - 1)
    game.commander.cargo[13] += 1
    #expect(game.estimatedTradeProfit(to: destination) == Int.max)
    game.commander.cargo[13] += 1
    #expect(game.estimatedTradeProfit(to: destination) == Int.max)
    game.market[0].price = prices[0] + 17
    game.market[13].price = prices[13] + 1
    #expect(game.estimatedTradeProfit(to: destination) == Int.min)
    game.commander.cargo[13] -= 1
    #expect(game.estimatedTradeProfit(to: destination) == Int.min + 1)
    game.commander.cargo[13] += 2
    #expect(game.estimatedTradeProfit(to: destination) == Int.min)
  }

  @Test(arguments: [false, true])
  func extremeOpposingTermsCancelBeforeFinalSaturation(positiveFirst: Bool) {
    var (game, destination) = boundedProfitFixture()
    let prices = MarketItem.minimumPrices(at: destination)
    let sign = positiveFirst ? 1 : -1
    game.commander.cargo[13] = Int.max / 17
    game.commander.cargo[14] = Int.max / 17
    game.commander.cargo[15] = 5
    game.market[13].price = prices[13] - sign * 64
    game.market[14].price = prices[14] + sign * 64
    game.market[15].price = prices[15] - 2
    #expect(game.commander.valid)
    #expect(game.estimatedTradeProfit(to: destination) == 10)
  }

  @Test func rankingUsesUnsaturatedEstimatesAndKeepsStableTiesForAValidExtremeHold() {
    var game = Game(executive: false)
    game.commander.unlimitedCargo = true
    game.commander.credits = 0
    game.commander.cargo[0] = Int.max / 17
    game.commander.profitScanEnabled = true
    #expect(game.commander.valid)
    #expect(game.estimatedTradeProfit(to: game.systems[55]) == Int.max)
    #expect(game.estimatedTradeProfit(to: game.systems[129]) == Int.max)
    let before = game.commander
    let market = game.market
    let ranks = game.profitDestinations
    #expect(ranks.prefix(2).map(\.systemID) == [129, 55])
    #expect(game.profitDestinations == ranks)
    #expect(game.commander == before && game.market == market)
    game.commander.cargo[0] = 1
    game.market = game.market.map { .init(price: $0.price, quantity: 0) }
    let previous = game.systems[129]
    game.systems[129] = .init(
      id: previous.id, name: previous.name, x: previous.x, y: previous.y,
      economy: game.systems[55].economy, government: previous.government,
      technology: previous.technology, population: previous.population,
      productivity: previous.productivity, radius: previous.radius, seed: previous.seed)
    #expect(
      game.estimatedTradeProfit(to: game.systems[55])
        == game.estimatedTradeProfit(to: game.systems[129]))
    #expect(game.profitDestinations.prefix(2).map(\.systemID) == [55, 129])
  }

  @Test func largeProspectiveExportUsesTheSameSafeAccumulator() {
    var (game, destination) = boundedProfitFixture()
    game.commander.unlimitedCash = true
    game.market[0] = .init(price: 1, quantity: Int.max / 17)
    #expect(game.commander.valid)
    #expect(game.estimatedTradeProfit(to: destination) == Int.max)
  }
}
