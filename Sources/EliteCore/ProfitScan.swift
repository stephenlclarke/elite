import Foundation

public struct ProfitDestination: Sendable, Equatable {
  public let systemID: Int
  /// Tenths of a credit; conservative destination prices, before fuel and risk.
  public let profit: Int
}

extension Game {
  /// Recomputed from the current hold, market, cash and fuel, so rankings cannot go stale.
  public var profitDestinations: [ProfitDestination] {
    guard commander.profitScanEnabled else { return [] }
    return Array(
      knownSystems.compactMap { destination in
        guard destination.id != commander.system,
          currentSystem.distance(to: destination) <= commander.maximumJumpDistance
        else { return nil as ProfitDestination? }
        let profit = estimatedTradeProfit(to: destination)
        return profit > 0 ? ProfitDestination(systemID: destination.id, profit: profit) : nil
      }.sorted {
        $0.profit == $1.profit ? $0.systemID < $1.systemID : $0.profit > $1.profit
      }.prefix(5))
  }

  public func estimatedTradeProfit(to destination: StarSystem) -> Int {
    let prices = MarketItem.minimumPrices(at: destination)
    // Compare carried cargo with selling it here, excluding reserved mission payloads.
    var profit = Commodity.all.indices.reduce(0) {
      $0 + commander.sellableCargo($1) * (prices[$1] - market[$1].price)
    }
    var room = max(0, commander.capacity - commander.cargoTonnes)
    var cash = commander.availableCredits
    for item in profitableExports(to: destination) {
      let price = market[item.index].price
      let tonnes = Commodity.all[item.index].unit == "t"
      let storage = tonnes ? room : max(0, 63 - commander.cargo[item.index])
      let affordable = price > 0 ? cash / price : market[item.index].quantity
      let quantity = max(0, min(storage, affordable, market[item.index].quantity))
      profit += quantity * item.profit
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
