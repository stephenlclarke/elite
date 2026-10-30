import Foundation
import Testing

@testable import L337Core

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
  @Test func actualOriginalProductivityAndDisplayedMillionCreditUnitAgree() throws {
    let world = try #require(Universe.originalWorlds.worlds.first { $0.name == "Avenor" })
    try #require(world.productivityBillionCR == 158.62)
    var game = Game(executive: false)
    game.commander.galaxy = world.galaxy
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.selectedSystem = world.system
    game.screen = .system
    #expect(game.targetSystem.productivity == 158620)
    #expect(Display.systemRows(game).contains { $0.0 == "Gross productivity: 158620 MCR" })
    for size in [512.0, 768.0] {
      #expect(
        Display.systemScreen(game, width: size, height: 768).labels.contains {
          $0.text == "Gross productivity: 158620 MCR"
        })
    }
  }

  @Test(arguments: [TargetingTier.basic.equipmentName, Equipment.eliteEnergyUnit])
  func actualOriginalShopUsesOneBasedWorldLevelsAtTheEquipmentBoundary(name: String) throws {
    let item = try #require(Equipment.all.first { $0.name == name })
    var game = Game(executive: false)
    game.screen = .equipment
    game.commander.credits = 1_000_000
    try game.commander.prepareEquipment(legacy: false)
    let below = try #require(
      Universe.originalWorlds.worlds.first { $0.technology == item.requiredTechnologyLevel - 1 })
    let at = try #require(
      Universe.originalWorlds.worlds.first { $0.technology == item.requiredTechnologyLevel })
    game.commander.galaxy = below.galaxy
    game.systems = Universe.systemsIncludingPlugh(number: below.galaxy)
    game.commander.system = below.system
    #expect(!game.equipmentAvailable(item))
    #expect(game.equipmentPurchaseRequirement(item) == "Requires TL\(item.requiredTechnologyLevel)")
    #expect(throws: EquipmentRuntimeError.unavailable) { try game.quoteEquipmentPurchase(item) }
    game.commander.galaxy = at.galaxy
    game.systems = Universe.systemsIncludingPlugh(number: at.galaxy)
    game.commander.system = at.system
    #expect(game.equipmentAvailable(item))
    if name == TargetingTier.basic.equipmentName {
      let quote = try game.quoteEquipmentPurchase(item)
      #expect(quote.item.name == name)
      #expect(try game.applyEquipmentPurchase(quote))
      #expect(game.commander.fittedEquipment(at: .targetingCore)?.node.key == name)
    }
  }

  @Test func actualDepletedRemoteStockCannotReappearInRouteTradeEstimates() throws {
    var game = Game(executive: false)
    game.screen = .buy
    game.commander.system = 0  // Explicit initial market fixture, not an invented flight receipt.
    game.commander.credits = 100000
    game.selection = 14
    let destination = game.systems[12]
    try #require(game.profitableExports(to: destination).map(\.index) == [14])
    let quote = game.market[14]
    try #require(quote.quantity == 7 && Commodity.all[14].unit == "kg")
    for _ in 0..<quote.quantity { game.trade(buy: true) }
    try #require(game.market[14].quantity == 0 && game.commander.cargo[14] == quote.quantity)
    try #require(game.commander.credits == 100000 - quote.quantity * quote.price)
    game.commander.system = 7  // Inspect the now-remote market without minting journey evidence.
    let held = game.commander
    #expect(NavigationGraph(game: game).trade(0, destination.id) == 0)
    #expect(game.commander == held)
    var pristine = game
    pristine.commander.originalMarkets = OriginalLiveMarkets()
    #expect(
      pristine.commander.cargo == game.commander.cargo
        && pristine.commander.credits == game.commander.credits
        && pristine.commander.capacity == game.commander.capacity)
    #expect(NavigationGraph(game: pristine).trade(0, destination.id) > 0)
  }

}
