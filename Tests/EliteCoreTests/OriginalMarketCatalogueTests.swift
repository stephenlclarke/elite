import Foundation
import Testing

@testable import EliteCore

struct OriginalMarketCatalogueTests {
  private var resourceDirectory: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/EliteCore/Resources/OriginalMarkets")
  }

  private func mustRefuse(_ operation: () throws -> Void) {
    do {
      try operation()
      Issue.record("Malformed initial market was accepted")
    } catch {}
  }

  @Test func allOriginalWorldSeedsAndPreciseRepresentativeQuoteLoad() throws {
    let markets = try OriginalMarketCatalogue.loadBundled()
    #expect(markets.allInitialStates.count == 2048)
    #expect(markets.allInitialStates.reduce(0) { $0 + $1.quotes.count } == 34816)
    let quote = try markets.initialQuote(galaxy: 0, system: 0, commodityIndex: 0)
    #expect(quote.name == "Food" && quote.unit == "t" && quote.index == 0)
    #expect(quote.askTenthsCR == 202 && quote.bidTenthsCR == 180)
    #expect(quote.stock == 105 && quote.targetStock == 130 && quote.epoch == 0)
    let same = try markets.initialQuote(worldKey: "G01-S000", commodityIndex: 0)
    #expect(quote == same)
    let worlds = try OriginalWorldCatalogue.loadBundled()
    let world = try worlds.world(galaxy: 0, system: 0)
    mustRefuse { _ = try markets.initialState(worldKey: world.name) }
    mustRefuse { _ = try markets.initialQuote(worldKey: world.key, commodityIndex: 17) }
    mustRefuse { _ = try markets.initialState(galaxy: 8, system: 0) }
  }

  @Test func authenticatedResourcesRefuseMissingChangedAndOversizedFiles() throws {
    let worlds = try OriginalWorldCatalogue.loadBundled()
    let missing = URL(fileURLWithPath: "/nonexistent/original-market-fixture")
    mustRefuse { _ = try OriginalMarketCatalogue.load(from: missing, worlds: worlds) }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let manifest = try Data(contentsOf: resourceDirectory.appendingPathComponent("manifest.json"))
    try manifest.write(to: folder.appendingPathComponent("manifest.json"))
    try Data("{}".utf8).write(to: folder.appendingPathComponent("markets.json"))
    mustRefuse { _ = try OriginalMarketCatalogue.load(from: folder, worlds: worlds) }
    try Data(repeating: 0, count: 131_073).write(to: folder.appendingPathComponent("manifest.json"))
    mustRefuse { _ = try OriginalMarketCatalogue.load(from: folder, worlds: worlds) }
  }

  @Test func malformedExactSchemaTypesAndCountsAreRefused() throws {
    let worlds = try OriginalWorldCatalogue.loadBundled()
    for text in [
      "{\"version\":\"l337-world-1\",\"markets\":[],\"unknown\":true}",
      "{\"version\":\"foreign\",\"markets\":[]}",
      "{\"version\":\"l337-world-1\",\"markets\":[{\"key\":\"G01-S000\",\"galaxy\":true,\"system\":0,\"quotes\":[]}]}",
      "{\"version\":\"l337-world-1\",\"markets\":[{\"key\":\"G01-S000\",\"galaxy\":0,\"system\":0,\"quotes\":[]}]}",
    ] {
      let data = Data(text.utf8)
      mustRefuse { _ = try OriginalMarketCatalogue.decode(data: data, worlds: worlds) }
    }
  }

  @Test func smallQuotesRejectForeignIdentityCommodityUnitsAndCrossedMoney() throws {
    let worlds = try OriginalWorldCatalogue.loadBundled()
    let world = try worlds.world(galaxy: 0, system: 0)
    for mutation in ["system", "index", "name", "unit", "version", "spread", "stock"] {
      let quote = OriginalMarketInitialQuote(
        system: mutation == "system" ? 1 : 0, index: mutation == "index" ? 17 : 0,
        name: mutation == "name" ? "foreign" : "Food", unit: mutation == "unit" ? "kg" : "t",
        askTenthsCR: 202, bidTenthsCR: mutation == "spread" ? 203 : 180,
        stock: mutation == "stock" ? -1 : 105, targetStock: 130, epoch: 0,
        worldVersion: mutation == "version" ? "foreign" : worlds.version)
      mustRefuse {
        try OriginalMarketCatalogue.validateQuote(quote, world: world, authoring: worlds.authoring)
      }
    }
  }

  @Test func smallInitialStateRefusesDuplicateAndForeignJoins() throws {
    let worlds = try OriginalWorldCatalogue.loadBundled()
    let quotes = worlds.authoring.commodities.sorted { $0.index < $1.index }.map {
      OriginalMarketInitialQuote(
        system: 0, index: $0.index, name: $0.name, unit: $0.unit,
        askTenthsCR: 1, bidTenthsCR: 1, stock: 0, targetStock: 0, epoch: 0,
        worldVersion: worlds.version)
    }
    let complete = OriginalMarketInitialState(key: "G01-S000", galaxy: 0, system: 0, quotes: quotes)
    try OriginalMarketCatalogue.validateInitialState(complete, worlds: worlds)
    let optionalFirst = quotes.first
    let first = try #require(optionalFirst)
    let duplicate = OriginalMarketInitialState(
      key: "G01-S000", galaxy: 0, system: 0, quotes: Array(repeating: first, count: 17))
    let foreign = OriginalMarketInitialState(key: "foreign", galaxy: 0, system: 0, quotes: quotes)
    mustRefuse { try OriginalMarketCatalogue.validateInitialState(duplicate, worlds: worlds) }
    mustRefuse { try OriginalMarketCatalogue.validateInitialState(foreign, worlds: worlds) }
  }
}
