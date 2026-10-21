import Foundation
import Testing

@testable import EliteCore

struct MarketCargoBoundsTests {
  @Test(arguments: [13, 14, 15])
  func maximumSupportedPreciousCargoRefusesAnActorPurchaseWithoutLosingSaveValidity(index: Int)
    async throws
  {
    var game = Game(executive: false)
    game.screen = .buy
    game.selection = index
    game.commander.cargo[index] = Int.max / 17
    game.market[index] = .init(price: 2, quantity: 2)
    try #require(game.commander.valid && Commodity.all[index].unit != "t")
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    #expect(before.marketAvailability(index) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.market == before.market)
    #expect(refused.commander.valid && refused.message == "CANNOT BUY")
  }

  @Test(arguments: [13, 14, 15])
  func lastSupportedPreciousUnitCanBeBoughtSavedAndReloadedButTheNextIsRefused(index: Int)
    async throws
  {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var game = Game(executive: false)
    game.screen = .buy
    game.selection = index
    game.commander.cargo[index] = Int.max / 17 - 1
    game.market[index] = .init(price: 2, quantity: 2)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    #expect(before.marketAvailability(index) == "BUY")
    await runtime.key("return")
    let accepted = await runtime.snapshot()
    #expect(accepted.commander.cargo[index] == Int.max / 17 && accepted.commander.valid)
    #expect(accepted.commander.credits == before.commander.credits - 2)
    #expect(
      accepted.market[index].quantity == 1 && accepted.marketAvailability(index) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == accepted.commander && refused.market == accepted.market)
    try await runtime.save(to: url)
    let loaded = GameRuntime()
    try await loaded.load(from: url)
    #expect(await loaded.snapshot().commander == accepted.commander)
  }

  @Test func fullyFittedCabinsShowTheSameHoldLimitAsTheActorPurchase() async throws {
    var game = Game(executive: false)
    game.commander.credits = 100000
    game.commander.unlimitedCargo = true
    for _ in 0..<4 { try game.confirmPassengerBerth(game.passengerBerthQuote) }
    game.screen = .buy
    game.selection = 0
    game.market[0] = .init(price: 2, quantity: 2)
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    try #require(before.commander.cargoTonnes == before.commander.tradeCargoCapacity)
    #expect(before.marketAvailability(0) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.market == before.market)
    #expect(refused.commander.valid)
  }
}
