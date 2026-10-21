import Foundation

public struct ProfitDestination: Sendable, Equatable {
  public let systemID: Int
  /// Tenths of a credit, saturated to Int bounds; ranking retains the full estimate.
  public let profit: Int
}

extension Game {
  /// Recomputed from the current hold, market, cash and fuel, so rankings cannot go stale.
  public var profitDestinations: [ProfitDestination] {
    guard commander.profitScanEnabled else { return [] }
    let candidates: [(destination: ProfitDestination, score: Decimal)] = knownSystems.compactMap {
      destination in
      guard destination.id != commander.system,
        currentSystem.distance(to: destination) <= commander.maximumJumpDistance
      else { return nil }
      let profit = estimatedTradeProfitValue(to: destination)
      guard profit > 0 else { return nil }
      return (
        ProfitDestination(systemID: destination.id, profit: Self.representedTradeProfit(profit)),
        profit
      )
    }
    let ranked = candidates.sorted {
      $0.score == $1.score
        ? $0.destination.systemID < $1.destination.systemID : $0.score > $1.score
    }
    return ranked.prefix(5).map { $0.destination }
  }

  public func estimatedTradeProfit(to destination: StarSystem) -> Int {
    Self.representedTradeProfit(estimatedTradeProfitValue(to: destination))
  }

  private static func representedTradeProfit(_ profit: Decimal) -> Int {
    if profit >= Decimal(Int.max) { return Int.max }
    if profit <= Decimal(Int.min) { return Int.min }
    return NSDecimalNumber(decimal: profit).intValue
  }

  private func estimatedTradeProfitValue(to destination: StarSystem) -> Decimal {
    let prices = MarketItem.minimumPrices(at: destination)
    // Admitted counts and native prices fit exactly within Decimal's integer precision.
    // Clamp only the final presentation value so signed terms can cancel and ranking stays exact.
    // Compare carried cargo with selling it here, excluding reserved mission payloads.
    var profit = Commodity.all.indices.reduce(Decimal(0)) {
      $0 + Decimal(commander.sellableCargo($1)) * (Decimal(prices[$1]) - Decimal(market[$1].price))
    }
    var room = max(0, commander.capacity - commander.cargoTonnes)
    var cash = commander.availableCredits
    for item in profitableExports(to: destination) {
      let price = market[item.index].price
      let tonnes = Commodity.all[item.index].unit == "t"
      let storage = tonnes ? room : max(0, 63 - commander.cargo[item.index])
      let affordable = price > 0 ? cash / price : market[item.index].quantity
      let quantity = max(0, min(storage, affordable, market[item.index].quantity))
      profit += Decimal(quantity) * Decimal(item.profit)
      if tonnes { room -= quantity }
      if !commander.unlimitedCash { cash -= quantity * price }
    }
    return profit
  }

  mutating func toggleProfitScan() {
    commander.profitScanEnabled.toggle()
    // The full ranked list belongs in the scrollable navigation summary. A
    // chart toast has one row even in the smallest supported window.
    let count = profitDestinations.count
    notify(
      commander.profitScanEnabled
        ? "PROFIT SCAN ON - \(count) PROFITABLE DESTINATIONS"
        : "PROFIT SCAN OFF")
  }

  public var profitScanSummary: String {
    guard commander.profitScanEnabled else { return "P: PROFIT SCAN OFF" }
    let destinations = profitDestinations
    guard !destinations.isEmpty else { return "P: PROFIT SCAN ON - NO PROFITABLE PLANETS IN RANGE" }
    return "P: PROFIT SCAN ON - "
      + destinations.enumerated().map {
        "\($0.offset + 1) \(systems[$0.element.systemID].name)"
      }.joined(separator: "  ")
  }
}
