import Testing

@testable import L337Core

struct OriginalMarketQuoteJoinUnitTests {
  private func fixture() throws -> (
    worlds: OriginalWorldCatalogue, state: OriginalMarketInitialState
  ) {
    let worlds = try OriginalWorldCatalogue.loadBundled()
    let world = try worlds.world(galaxy: 0, system: 0)
    let quotes = worlds.authoring.commodities.sorted { $0.index < $1.index }.map {
      OriginalMarketInitialQuote(
        system: world.system, index: $0.index, name: $0.name, unit: $0.unit,
        askTenthsCR: 1000 + $0.index * 31, bidTenthsCR: 500 + $0.index * 17,
        stock: 7 + $0.index, targetStock: 100 + $0.index, epoch: 0,
        worldVersion: worlds.version)
    }
    return (
      worlds, .init(key: world.key, galaxy: world.galaxy, system: world.system, quotes: quotes)
    )
  }

  private func expectIdentityJoin(_ items: [MarketItem], state: OriginalMarketInitialState) throws {
    try #require(items.count == 17)
    for quote in state.quotes {
      #expect(items[quote.index].price == quote.askTenthsCR)
      #expect(items[quote.index].bidPrice == quote.bidTenthsCR)
      #expect(items[quote.index].quantity == quote.stock)
    }
  }

  @Test func reversedValidatedQuotesKeepStableCommodityPriceAndStockSlots() throws {
    let (worlds, canonical) = try fixture()
    let reversed = OriginalMarketInitialState(
      key: canonical.key, galaxy: canonical.galaxy, system: canonical.system,
      quotes: Array(canonical.quotes.reversed()))
    try OriginalMarketCatalogue.validateInitialState(reversed, worlds: worlds)
    #expect(reversed.quotes.first?.index == 16 && reversed.quotes.last?.index == 0)
    let before = reversed
    let items = OriginalLiveMarkets.initialItems(from: reversed)
    try expectIdentityJoin(items, state: canonical)
    #expect(reversed == before)
  }

  @Test func authoredDisplayOrderAndRotationPreserveSourceOrderAndCommodityIdentity() throws {
    let (worlds, canonical) = try fixture()
    let displayOrder = MarketDisplayOrder.commodityIDs
    #expect(displayOrder == [9, 8, 10, 2, 7, 12, 13, 15, 14, 1, 4, 5, 0, 11, 6, 3, 16])
    for order in [displayOrder, Array(1..<17) + [0]] {
      let quotes = try order.map { index in
        try #require(canonical.quotes.first { $0.index == index })
      }
      let state = OriginalMarketInitialState(
        key: canonical.key, galaxy: canonical.galaxy, system: canonical.system, quotes: quotes)
      try OriginalMarketCatalogue.validateInitialState(state, worlds: worlds)
      let before = state
      let items = OriginalLiveMarkets.initialItems(from: state)
      try expectIdentityJoin(items, state: canonical)
      #expect(state == before && state.quotes.map(\.index) == order)
    }
    #expect(MarketDisplayOrder.commodityIDs == displayOrder)
  }

  @Test func canonicalBundledSeedsAndSecretPortDiscountKeepExistingValues() throws {
    let worlds = try OriginalWorldCatalogue.loadBundled()
    let markets = try OriginalMarketCatalogue.loadBundled()
    for (galaxy, system) in [(0, 0), (4, 19), (7, 255)] {
      let state = try markets.initialState(galaxy: galaxy, system: system)
      let projected = OriginalLiveMarkets.initialItems(from: state)
      try expectIdentityJoin(projected, state: state)
      let world = try worlds.world(galaxy: galaxy, system: system)
      #expect(
        OriginalLiveMarkets.initial(galaxy: galaxy, system: Universe.nativeSystem(world))
          == projected)
    }
    let anchor = try markets.initialState(galaxy: 0, system: Plugh.rumourStation)
    let secret = OriginalLiveMarkets.initial(galaxy: 0, system: Plugh.system(galaxy: 0))
    try #require(secret.count == 17)
    for quote in anchor.quotes {
      #expect(secret[quote.index].price == Plugh.discount(quote.askTenthsCR))
      #expect(secret[quote.index].bidPrice == Plugh.discount(quote.bidTenthsCR))
      #expect(secret[quote.index].quantity == 63)
    }
  }
}
