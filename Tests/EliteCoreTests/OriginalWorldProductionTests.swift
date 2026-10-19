import Foundation
import Testing

@testable import EliteCore

struct OriginalWorldProductionTests {
  @Test func actualMarketTradeUsesSeparateAskAndBidAndOwnsStockAcrossWorlds() throws {
    var game = Game(executive: false)
    game.commander.credits = 1_000_000
    game.screen = .buy
    let index = try #require(
      game.market.indices.first {
        game.market[$0].quantity > 0 && Commodity.all[$0].unit == "t"
      })
    game.selection = index
    let original = game.market
    let cash = game.commander.credits
    game.trade(buy: true)
    #expect(game.commander.credits == cash - original[index].price)
    #expect(game.commander.cargo[index] == 1)
    #expect(game.market[index].quantity == original[index].quantity - 1)
    let purchased = game.market
    let current = game.commander.system
    game.commander.system = (current + 1) % 256
    #expect(game.market == MarketItem.at(game.currentSystem))
    game.commander.system = current
    #expect(game.market == purchased)
    game.trade(buy: false)
    #expect(game.commander.credits == cash - original[index].price + original[index].bidPrice)
    #expect(game.commander.cargo[index] == 0 && game.market == original)
    #expect(game.commander.originalMarkets.valid)
  }

  @Test func actualRuntimeSaveAndColdLoadRetainPaidStockAndOriginalWorld() async throws {
    var game = Game(executive: false)
    game.commander.credits = 1_000_000
    game.screen = .buy
    game.selection = try #require(game.market.indices.first { game.market[$0].quantity > 0 })
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let save = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    await runtime.key("right")
    let bought = await runtime.snapshot()
    try #require(bought.market[game.selection].quantity == game.market[game.selection].quantity - 1)
    try #require(bought.commander.cargo[game.selection] == game.commander.cargo[game.selection] + 1)
    try #require(
      bought.commander.credits == game.commander.credits - game.market[game.selection].price)
    try await runtime.save(to: save)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: save)
    let restored = await cold.snapshot()
    #expect(restored.market == bought.market)
    #expect(restored.commander.originalMarkets == bought.commander.originalMarkets)
    #expect(restored.commander.credits == bought.commander.credits)
    #expect(restored.commander.cargo == bought.commander.cargo)
    #expect(restored.currentSystem.original == bought.currentSystem.original)
  }

  @Test(arguments: ["version", "foreign-world", "short", "negative", "ask", "bid"])
  func currentMarketDecoderRejectsForeignOrForgedState(condition: String) throws {
    var game = Game(executive: false)
    var items = game.market
    items[0].quantity += 1
    game.market = items
    let data = try JSONEncoder().encode(game.commander.originalMarkets)
    var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var changed = try #require(root["changed"] as? [String: Any])
    let key = try #require(changed.keys.first)
    var quotes = try #require(changed[key] as? [[String: Any]])
    switch condition {
    case "version": root["worldVersion"] = "foreign"
    case "foreign-world": changed["G09-S000"] = quotes
    case "short": quotes.removeLast()
    case "negative": quotes[0]["quantity"] = -1
    case "ask": quotes[0]["price"] = items[0].price + 1
    default: quotes[0]["bidPrice"] = items[0].bidPrice + 1
    }
    changed[key] = quotes
    root["changed"] = changed
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        OriginalLiveMarkets.self,
        from: JSONSerialization.data(withJSONObject: root))
    }
  }

  @Test func productionEndpointsRequireExactOriginalRecordsAndExcludeSecretWorlds() throws {
    var game = Game(executive: false)
    game.selectedSystem = (game.commander.system + 1) % 256
    let binding = try #require(ScriptNavigationTradeBinding.production(in: game))
    #expect(binding.valid && binding.matches(game))
    #expect(binding.training.worldID == game.currentSystem.original?.key)
    #expect(binding.destination.worldID == game.targetSystem.original?.key)
    #expect(
      !ScriptNavigationTradeEndpoint(
        worldID: "G01-S999", galaxy: 0,
        system: game.currentSystem
      ).valid)
    #expect(
      !ScriptNavigationTradeEndpoint(
        worldID: binding.training.worldID, galaxy: 1,
        system: game.currentSystem
      ).valid)
    game.selectedSystem = Plugh.systemID
    #expect(ScriptNavigationTradeBinding.production(in: game) == nil)
    game.commander.system = Plugh.systemID
    game.selectedSystem = 1
    #expect(ScriptNavigationTradeBinding.production(in: game) == nil)
  }

  @Test func nativeChartHasEqualCartesianScalesForAllEightNegativeCoordinateWorlds() throws {
    for galaxy in 0..<8 {
      let systems = Universe.galaxy(number: galaxy)
      let origin = systems[7]
      let layout = ChartLayout(width: 768, height: 768, local: false, galaxy: galaxy)
      for system in systems {
        let point = layout.point(system, current: origin)
        #expect(point.x.isFinite && point.y.isFinite && layout.plot.contains(point))
      }
      let a = layout.point(systems[0], current: origin)
      let b = layout.point(systems[1], current: origin)
      #expect(
        abs(
          hypot(a.x - b.x, a.y - b.y) / layout.scale
            - systems[0].distance(to: systems[1])) < 1e-10)
    }
  }
}
