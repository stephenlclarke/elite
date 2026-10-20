import Foundation
import Testing

@testable import EliteCore

private func boundedProfitFixture(origin: Int, destination: Int) throws -> (Game, StarSystem) {
  var game = Game(executive: false)
  try #require(Universe.originalWorlds.version == "l337-world-1")
  try #require(
    game.commander.shipID == "SH025" && game.commander.galaxy == 0
      && game.commander.equipmentInventory == nil && game.commander.nativeStations == nil)
  try #require(Commodity.all[13].unit == "kg" && Commodity.all[14].unit == "kg")
  game.commander.system = origin
  game.selectedSystem = origin
  game.commander.unlimitedCargo = true
  game.commander.credits = 0
  game.commander.fuel = game.commander.fuelCapacity
  // Authenticated ask/bid quotes remain intact. Only admitted live stock is mutable.
  var stock = game.market
  for index in stock.indices { stock[index].quantity = 0 }
  game.market = stock
  try #require(game.commander.valid && game.commander.originalMarkets.valid)
  return (game, game.systems[destination])
}

private func requireProfitQuotes(
  _ game: Game, system: Int, rows: [(index: Int, ask: Int, bid: Int)]
) throws {
  let quotes = game.commander.originalMarkets.items(galaxy: 0, system: game.systems[system])
  for row in rows {
    try #require(quotes[row.index].price == row.ask && quotes[row.index].bidPrice == row.bid)
  }
}

struct ProfitScanBoundsTests {
  @Test func finalIntegerBoundsRemainExactWithoutFloatingPointConversion() throws {
    // Native Gold/Platinum bids at G01-S016 minus S000 are exactly 184 and 801.
    // These fixed integer solutions were derived independently from the authored quote bytes.
    let cases:
      [(origin: Int, destination: Int, gold: Int, platinum: Int, raw: String, expected: Int)] = [
        (0, 16, 50_127_021_939_427_755, 86, "9223372036854775806", Int.max - 1),
        (0, 16, 50_127_021_939_427_681, 103, "9223372036854775807", Int.max),
        (0, 16, 50_127_021_939_427_607, 120, "9223372036854775808", Int.max),
        (16, 0, 50_127_021_939_427_607, 120, "-9223372036854775808", Int.min),
        (16, 0, 50_127_021_939_427_681, 103, "-9223372036854775807", Int.min + 1),
        (16, 0, 50_127_021_939_427_533, 137, "-9223372036854775809", Int.min),
      ]
    for input in cases {
      var (game, destination) = try boundedProfitFixture(
        origin: input.origin, destination: input.destination)
      try requireProfitQuotes(game, system: 0, rows: [(13, 5744, 5118), (14, 8390, 7476)])
      try requireProfitQuotes(game, system: 16, rows: [(13, 5862, 5302), (14, 9149, 8277)])
      game.commander.cargo[13] = input.gold
      game.commander.cargo[14] = input.platinum
      try #require(input.gold <= Int.max / 17 && input.platinum <= Int.max / 17)
      let sign = input.origin == 0 ? 1 : -1
      let independent = Decimal(sign) * (Decimal(input.gold) * 184 + Decimal(input.platinum) * 801)
      let expectedRaw = try #require(Decimal(string: input.raw))
      try #require(independent == expectedRaw)
      try #require(game.commander.valid)
      #expect(game.estimatedTradeProfit(to: destination) == input.expected)
    }
  }

  @Test(arguments: [false, true])
  func extremeOpposingTermsCancelBeforeFinalSaturation(positiveFirst: Bool) throws {
    var (game, destination) = try boundedProfitFixture(
      origin: positiveFirst ? 20 : 0, destination: positiveFirst ? 0 : 20)
    try requireProfitQuotes(game, system: 0, rows: [(13, 5744, 5118), (14, 8390, 7476)])
    try requireProfitQuotes(game, system: 20, rows: [(13, 4200, 3876), (14, 8983, 8291)])
    let gold = positiveFirst ? 356_021_985_887_876_635 : 356_021_985_887_877_240
    let platinum = positiveFirst ? 542_551_296_285_573_964 : 542_551_296_285_574_886
    game.commander.cargo[13] = gold
    game.commander.cargo[14] = platinum
    try #require(gold <= Int.max / 17 && platinum <= Int.max / 17)
    let goldTerm = Decimal(gold) * (positiveFirst ? 1242 : -1242)
    let platinumTerm = Decimal(platinum) * (positiveFirst ? -815 : 815)
    try #require(abs(goldTerm) > Decimal(Int.max) && abs(platinumTerm) > Decimal(Int.max))
    try #require((goldTerm > 0) == positiveFirst && goldTerm + platinumTerm == 10)
    try #require(game.commander.valid)
    #expect(game.estimatedTradeProfit(to: destination) == 10)
  }

  @Test func rankingUsesUnsaturatedEstimatesAndKeepsStableTiesForAValidExtremeHold() throws {
    var (game, _) = try boundedProfitFixture(origin: 3, destination: 116)
    try requireProfitQuotes(game, system: 3, rows: [(13, 4803, 4367), (14, 7691, 6993)])
    try requireProfitQuotes(game, system: 116, rows: [(13, 5737, 5295), (14, 9063, 8365)])
    try requireProfitQuotes(game, system: 38, rows: [(13, 5927, 5281), (14, 8202, 7310)])
    try requireProfitQuotes(game, system: 84, rows: [(13, 5359, 4823), (14, 10346, 9312)])
    try #require(game.commander.fuel == 130 && game.commander.maximumJumpDistance == 9)
    for system in [116, 38, 84] {
      try #require(game.currentSystem.distance(to: game.systems[system]) <= 9)
    }
    game.commander.cargo[13] = Int.max / 17
    game.commander.profitScanEnabled = true
    // Independent native bid differences: 928 > 914; both full scores exceed Int.max.
    try #require(Decimal(Int.max / 17) * 914 > Decimal(Int.max))
    try #require(game.commander.valid)
    #expect(game.estimatedTradeProfit(to: game.systems[116]) == Int.max)
    #expect(game.estimatedTradeProfit(to: game.systems[38]) == Int.max)
    let before = game.commander
    let market = game.market
    let ranks = game.profitDestinations
    #expect(ranks.prefix(2).map(\.systemID) == [116, 38])
    #expect(game.profitDestinations == ranks)
    #expect(game.commander == before && game.market == market)
    game.commander.cargo[13] = 947
    game.commander.cargo[14] = 472
    // 947*456 + 472*2319 == 947*928 + 472*1372 == 1,526,400.
    try #require(947 * 456 + 472 * 2319 == 1_526_400)
    try #require(947 * 928 + 472 * 1372 == 1_526_400)
    try #require(game.commander.valid)
    #expect(game.estimatedTradeProfit(to: game.systems[84]) == 1_526_400)
    #expect(game.estimatedTradeProfit(to: game.systems[116]) == 1_526_400)
    #expect(
      game.estimatedTradeProfit(to: game.systems[84])
        == game.estimatedTradeProfit(to: game.systems[116]))
    let tiedCommander = game.commander
    let ties = game.profitDestinations
    #expect(ties.prefix(2).map(\.systemID) == [84, 116])
    #expect(game.profitDestinations == ties)
    #expect(game.commander == tiedCommander && game.market == market)
  }

  @Test func largeProspectiveExportUsesTheSameSafeAccumulator() throws {
    var (game, destination) = try boundedProfitFixture(origin: 1, destination: 168)
    try requireProfitQuotes(game, system: 1, rows: [(0, 129, 117)])
    try requireProfitQuotes(game, system: 168, rows: [(0, 287, 261)])
    game.commander.unlimitedCash = true
    game.market[0].quantity = Int.max / 17
    // Actual ask 129 admits this integer quantity; destination bid 261 pays a 132-unit spread.
    try #require(Int.max / 129 == 71_499_008_037_633_920)
    try #require(Decimal(71_499_008_037_633_920) * 132 > Decimal(Int.max))
    try #require(game.commander.valid && game.commander.originalMarkets.valid)
    #expect(game.estimatedTradeProfit(to: destination) == Int.max)
  }
}
