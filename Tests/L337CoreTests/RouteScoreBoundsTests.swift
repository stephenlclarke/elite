import Testing

@testable import L337Core

struct RouteScoreBoundsTests {
  @Test func actualAutoTradeScoresMaximumSupportedCargoWithoutChangingScaledRoutePreference() {
    func setup(quantity: Int) -> Game {
      var game = Game(executive: false)
      game.commander.unlimitedCargo = true
      game.commander.cargo[0] = quantity
      game.selectedSystem = game.commander.system
      for index in game.market.indices { game.market[index].quantity = 0 }
      return game
    }
    var ordinary = setup(quantity: 50)
    var maximum = setup(quantity: Int.max / 17)
    #expect(ordinary.commander.valid && maximum.commander.valid)
    let fuel = maximum.commander.fuel
    let missiles = maximum.commander.missiles
    ordinary.autoTrade()
    maximum.autoTrade()
    #expect(ordinary.selectedSystem != ordinary.commander.system)
    #expect(maximum.selectedSystem == ordinary.selectedSystem)
    #expect(maximum.commander.valid && maximum.commander.credits >= 0)
    #expect(maximum.commander.credits <= 4_294_967_295)
    #expect(maximum.commander.fuel == fuel && maximum.commander.missiles == missiles)
    #expect(maximum.commander.cargo.allSatisfy { $0 >= 0 && $0 <= Int.max / 17 })
    #expect(maximum.market.allSatisfy { $0.quantity >= 0 })
  }
}
