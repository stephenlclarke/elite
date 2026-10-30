import Testing

@testable import L337Core

@Test func unifiedMarketModesPreserveProductAndBackWithoutTradingOnModeChange() {
  var game = Game(executive: false)
  game.screen = .status
  game.key("7")
  #expect(game.screen == .buy)
  game.selection = 0
  let before = game.commander
  game.key("tab")
  #expect(game.screen == .sell && game.commander == before)
  game.key("tab")
  #expect(game.screen == .buy && game.selection == 0)
  game.key("return")
  #expect(game.commander.cargo[0] == before.cargo[0] + 1)
  game.key("tab")
  game.key("return")
  #expect(game.commander.cargo[0] == before.cargo[0])
  game.key("escape")
  #expect(game.screen == .status)
  game.launch()
  game.key("7")
  #expect(game.screen == .market)
  let flight = game.commander
  game.key("return")
  #expect(game.commander == flight)
  game.key("1")
  #expect(game.screen == .rear)
}

@Test func marketPointerSelectsModesAndTradesOnlyThroughExplicitAction() {
  var game = Game(executive: false)
  game.screen = .status
  game.key("7")
  game.viewportWidth = 512
  game.viewportHeight = 650
  let layout = MarketLayout(game: game, width: 512, height: 650)
  let before = game.commander
  game.marketClick(x: layout.sell.x + 1, y: layout.sell.y + 1)
  #expect(game.screen == .sell && game.commander == before)
  game.marketClick(x: layout.buy.x + 1, y: layout.buy.y + 1)
  game.marketClick(x: layout.trade.x + 1, y: layout.trade.y + 1)
  #expect(game.commander.cargo[0] == before.cargo[0] + 1)
  game.paused = true
  let paused = game.commander
  game.marketClick(x: layout.trade.x + 1, y: layout.trade.y + 1)
  #expect(game.commander == paused)
}

struct MarketInventoryProjectionUnitTests {
  @Test func statusSummaryAndInventoryHaveDistinctResponsibilities() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    try game.commander.grantEquipment(
      "Energy Bomb", at: .utility(.energyBomb), provenance: .grant("inventory display fixture"))
    let before = game.commander
    game.screen = .status
    let summary = game.informationRows.map(\.0)
    #expect(summary.contains { $0.hasPrefix("Legal status:") })
    #expect(!summary.contains("Equipment - fitted and held") && !summary.contains("Energy Bomb"))
    game.screen = .inventory
    let inventory = game.informationRows.map(\.0)
    #expect(inventory.contains("Protected property - not ordinary trade cargo"))
    #expect(inventory.contains("Equipment - fitted") && inventory.contains("Equipment - held"))
    #expect(inventory.contains("Energy Bomb"))
    #expect(inventory.contains("Fitted Energy bomb - Granted"))
    #expect(game.commander.fittedEquipment(at: .utility(.energyBomb)) != nil)
    #expect(!inventory.contains { $0.hasPrefix("Legal status:") })
    #expect(game.commander == before)
  }
}

@Test func consolidatedMarketCannotSellReservedMissionCargoOrTradeWhilePaused() {
  var game = Game(executive: false)
  game.screen = .status
  game.key("7")
  game.commander.blackjack.stage = .deliverFirearm
  game.commander.cargo[10] = 1
  game.market[10].quantity = 2
  game.commander.credits = 10_000
  game.selection = 10
  game.key("tab")
  let before = game.commander
  game.key("return")
  #expect(game.commander == before && game.marketAvailability(10) == "RESERVED")
  game.key("right")
  #expect(game.commander.cargo[10] == 2)
  game.key("left")
  #expect(game.commander.cargo[10] == 1)
  game.paused = true
  let paused = game.commander
  game.key("right")
  #expect(game.commander == paused)
}
