import Foundation

struct NativeSaleBalance: Codable, Sendable, Equatable {
  let stock: Int
  let cargo: Int
  let credits: Int
  var valid: Bool {
    (0...Int.max / 17).contains(stock) && (0...Int.max / 17).contains(cargo)
      && (0...4_294_967_295).contains(credits)
  }
}

/// Historical first-sale evidence, never a mutable stock ledger or a reward entitlement.
/// Immutable reference storage keeps the complete dock/balance witness out of inline Game copies.
final class NativeFirstCommoditySale: Codable, Sendable, Equatable {
  let operation: UUID
  let owner: UUID
  let commodity: Int
  let dock: NativeMainStationDockReceipt
  let physicalTime: Double
  let calendarOperation: UInt64
  let unitPrice: Int
  let quantity: Int
  let before: NativeSaleBalance
  let after: NativeSaleBalance

  init(
    operation: UUID, owner: UUID, commodity: Int, dock: NativeMainStationDockReceipt,
    physicalTime: Double, calendarOperation: UInt64, unitPrice: Int, quantity: Int,
    before: NativeSaleBalance, after: NativeSaleBalance
  ) {
    self.operation = operation
    self.owner = owner
    self.commodity = commodity
    self.dock = dock
    self.physicalTime = physicalTime
    self.calendarOperation = calendarOperation
    self.unitPrice = unitPrice
    self.quantity = quantity
    self.before = before
    self.after = after
  }

  var valid: Bool {
    dock.valid && dock.commanderOwner == owner && dock.station.world == owner
      && Commodity.all.indices.contains(commodity)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && calendarOperation < UInt64(Int64.max) && (0...1_000_000).contains(unitPrice)
      && OriginalLiveMarkets.initialQuote(
        galaxy: dock.station.system.galaxy, system: dock.station.system.system,
        commodity: commodity)?.bidPrice == unitPrice
      && before.valid && after.valid && (1...Int.max / 17).contains(quantity)
      && before.cargo - after.cargo == quantity && after.stock - before.stock == quantity
      && after.credits
        == Self.credited(
          before: before.credits, quantity: quantity, unitPrice: unitPrice)
  }

  private static func credited(before: Int, quantity: Int, unitPrice: Int) -> Int {
    let revenue = quantity.multipliedReportingOverflow(by: unitPrice)
    if revenue.overflow { return 4_294_967_295 }
    return min(4_294_967_295, before + min(revenue.partialValue, 4_294_967_295))
  }

  static func == (lhs: NativeFirstCommoditySale, rhs: NativeFirstCommoditySale) -> Bool {
    lhs.operation == rhs.operation && lhs.owner == rhs.owner && lhs.commodity == rhs.commodity
      && lhs.dock == rhs.dock && lhs.physicalTime == rhs.physicalTime
      && lhs.calendarOperation == rhs.calendarOperation && lhs.unitPrice == rhs.unitPrice
      && lhs.quantity == rhs.quantity
      && lhs.before == rhs.before && lhs.after == rhs.after
  }
}

extension Game {
  /// Called immediately after this exact ordinary sale, before any refuel or next trade.
  /// Missing native evidence never invents history or changes the ordinary market outcome.
  mutating func recordFirstNativeCommoditySale(
    index: Int, before: NativeSaleBalance, unitPrice: Int
  ) {
    guard commander.scriptState.firstNativeCommoditySale == nil, !paused,
      nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock,
      let owner = commander.equipmentOwnerID,
      market.indices.contains(index), commander.cargo.indices.contains(index)
    else { return }
    let evidence = NativeFirstCommoditySale(
      operation: UUID(), owner: owner, commodity: index, dock: dock,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarOperation: commander.scriptState.calendarLedger?.operation ?? 0,
      unitPrice: unitPrice, quantity: before.cargo - commander.cargo[index],
      before: before,
      after: .init(
        stock: market[index].quantity, cargo: commander.cargo[index], credits: commander.credits))
    guard evidence.valid else { return }
    commander.scriptState.firstNativeCommoditySale = evidence
  }
}
