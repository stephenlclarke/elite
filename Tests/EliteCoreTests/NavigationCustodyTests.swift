import Foundation
import Testing

@testable import EliteCore

private func markedFirearmRoute() throws -> Game {
  var game = Game(executive: false)
  game.commander.galaxy = 1
  game.commander.system = 233
  game.systems = Universe.systemsIncludingPlugh(number: 1)
  game.commander.blackjack.stage = .deliverFirearm
  game.commander.blackjack.transfers = [
    .contact, .goldAward, .goldDelivery, .report, .firearmPickup,
  ]
  game.commander.cargo[10] = 1
  try game.commander.grantEquipment(
    NavigationTier.military.equipmentName, at: .navigation, provenance: .grant("route-custody-test")
  )
  #expect(game.commander.valid)
  return game
}

struct NavigationCustodyTests {
  @Test func markedOnlyFirearmsProduceNoSaleValueOrCargoDetour() throws {
    let game = try markedFirearmRoute()
    let graph = NavigationGraph(game: game)
    #expect(game.commander.sellableCargo(10) == 0)
    #expect(game.knownSystems.allSatisfy { graph.cargoSale($0.id) == 0 })
    let routes = graph.alternatives(destination: 127, tier: .military)
    #expect(!routes.isEmpty)
    #expect(routes.allSatisfy { $0.cargoSale == 0 && !$0.labels.contains("Best Cargo Sale") })
  }

  @Test func mixedPersonalAndMarkedCargoValuesOnlyTheItemsThatCanActuallyBeSold() throws {
    var game = try markedFirearmRoute()
    game.commander.cargo[10] = 4
    game.commander.cargo[13] = 2
    let destination = game.systems[127]
    let prices = MarketItem.minimumPrices(at: destination)
    #expect(
      NavigationGraph(game: game).cargoSale(destination.id)
        == Double(3 * prices[10] + 2 * prices[13]))
    game.selection = 10
    for _ in 0..<3 { game.trade(buy: false) }
    game.trade(buy: false)
    #expect(game.commander.cargo[10] == 1 && game.commander.sellableCargo(10) == 0)
    game.selection = 13
    for _ in 0..<2 { game.trade(buy: false) }
    #expect(NavigationGraph(game: game).cargoSale(destination.id) == 0)
    #expect(game.commander.blackjack.stage == .deliverFirearm && game.commander.valid)
  }

  @Test func acceptedMaximumSaleQuantityIsFiniteWithoutIntegerMultiplication() {
    var game = Game(executive: false)
    game.commander.unlimitedCargo = true
    game.commander.cargo[0] = Int.max / 17
    #expect(game.commander.valid)
    let value = NavigationGraph(game: game).cargoSale(55)
    #expect(value.isFinite && value > Double(Int.max))
  }
}
