import Foundation
import Testing

@testable import EliteCore

private func performanceWithPrice(_ price: Int, fuel: Int? = nil) throws -> ShipPerformance {
  let original = try #require(ShipCatalogue.ship("SH013")?.game)
  let bytes = try JSONEncoder().encode(original)
  let decoded = try JSONSerialization.jsonObject(with: bytes)
  var fields = try #require(decoded as? [String: Any])
  fields["price"] = price
  if let fuel { fields["fuel"] = fuel }
  let changed = try JSONSerialization.data(withJSONObject: fields)
  return try JSONDecoder().decode(ShipPerformance.self, from: changed)
}

@Test func unpricedPerformanceRequiresNeverPolicyAndPreservesEveryOtherBound() throws {
  let policies: [ShipCataloguePurchasePolicy] = [
    .blueprintFabrication, .pendingFabrication, .xyzzyOnly, .never,
  ]
  for policy in policies {
    for price in [-1, 0, 1, 100_000_000, 100_000_001] {
      let performance = try performanceWithPrice(price)
      let expected = price >= (policy == .never ? 0 : 1) && price <= 100_000_000
      let admitted = performance.valid(purchasePolicy: policy)
      #expect(admitted == expected)
      #expect(performance.valid == (price >= 1 && price <= 100_000_000))
    }
  }
  let emptyFuel = try performanceWithPrice(0, fuel: 0)
  let admittedEmptyFuel = emptyFuel.valid(purchasePolicy: .never)
  #expect(!admittedEmptyFuel)
}

private func priceAdmissionTOML(policy: ShipCataloguePurchasePolicy, price: Int) throws -> String {
  let originalShip = try #require(ShipCatalogue.ship("SH013"))
  let performance = try #require(originalShip.game)
  let original = try String(
    contentsOf: ShipCatalogue.folder.appendingPathComponent("SH013.toml"), encoding: .utf8)
  let catalogueStart = try #require(original.range(of: "[catalogue]"))
  let gameStart = try #require(
    original.range(of: "[game]", range: catalogueStart.upperBound..<original.endIndex))
  let designStart = try #require(
    original.range(of: "[design]", range: gameStart.upperBound..<original.endIndex))
  var catalogue = String(original[catalogueStart.lowerBound..<gameStart.lowerBound])
  if policy == .never {
    catalogue =
      catalogue
      .replacingOccurrences(
        of: "purchasePolicy = \"blueprintFabrication\"", with: "purchasePolicy = \"never\""
      )
      .replacingOccurrences(
        of: "normalPurchaseEligible = true", with: "normalPurchaseEligible = false"
      )
      .replacingOccurrences(of: "discoveryEligible = true", with: "discoveryEligible = false")
      .replacingOccurrences(
        of: "collectionMilestone = \"blueprintAndFabrication\"",
        with: "collectionMilestone = \"none\"")
    catalogue = catalogue.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { !$0.hasPrefix("minimumBuildTechLevel =") }.joined(separator: "\n")
  }
  let game = String(original[gameStart.lowerBound..<designStart.lowerBound])
    .replacingOccurrences(
      of: "price = " + String(performance.price), with: "price = " + String(price))
  return String(original[..<catalogueStart.lowerBound]) + catalogue + game
    + String(original[designStart.lowerBound...])
}

@Test func actualLoaderAdmitsUnpricedNeverButRejectsFreePurchaseAndNegativePrices() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "unpriced-ship-admission-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("SH013.toml")
  let policies: [ShipCataloguePurchasePolicy] = [.blueprintFabrication, .never]
  for policy in policies {
    for price in [-1, 0, 1] {
      let text = try priceAdmissionTOML(policy: policy, price: price)
      try text.write(to: file, atomically: true, encoding: .utf8)
      let shouldLoad = price > 0 || (price == 0 && policy == .never)
      if shouldLoad {
        let loaded = try ShipCatalogue.load(from: directory)
        let ship = try #require(loaded.first)
        #expect(ship.game?.price == price && ship.catalogue.purchasePolicy == policy)
        #expect(ship.catalogue.playerFlyable)
      } else {
        #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
      }
    }
  }
  let never = try priceAdmissionTOML(policy: .never, price: 0)
  let contradictory = never.replacingOccurrences(
    of: "normalPurchaseEligible = false", with: "normalPurchaseEligible = true")
  try contradictory.write(to: file, atomically: true, encoding: .utf8)
  #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
}

@Test func actualTradeQuoteRefusesUnpricedNeverWithoutChangingPositiveQuoteOrCommander() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "unpriced-ship-quote-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("SH013.toml")
  let source = try String(
    contentsOf: ShipCatalogue.folder.appendingPathComponent("SH013.toml"), encoding: .utf8)
  try source.write(to: file, atomically: true, encoding: .utf8)
  let positiveShips = try ShipCatalogue.load(from: directory)
  let positive = try #require(positiveShips.first)
  var game = Game(executive: false)
  game.commander.credits = 10_000_000
  let destinationHull = try #require(positive.game)
  game.commander.fuel = destinationHull.fuel
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  try #require(game.commander.valid)
  let before = game.commander
  let optionalPositiveQuote = game.shipTradeQuote(for: positive)
  let positiveQuote = try #require(optionalPositiveQuote)
  #expect(positiveQuote.allowed && positiveQuote.purchase == positive.game!.price * 10)

  let unpricedText = try priceAdmissionTOML(policy: .never, price: 0)
  try unpricedText.write(to: file, atomically: true, encoding: .utf8)
  let unpricedShips = try ShipCatalogue.load(from: directory)
  let unpriced = try #require(unpricedShips.first)
  let optionalQuote = game.shipTradeQuote(for: unpriced)
  let quote = try #require(optionalQuote)
  #expect(quote.purchase == 0 && quote.allowance == positiveQuote.allowance)
  #expect(!quote.allowed && quote.issues.contains("This hull is unpriced and not for sale."))
  let unchanged = game.commander == before
  #expect(unchanged)
}
