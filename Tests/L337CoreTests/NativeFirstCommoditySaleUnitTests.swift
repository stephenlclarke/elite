import Foundation
import Testing

@testable import L337Core

struct NativeFirstCommoditySaleUnitTests {
  private func fixture(
    quantity: Int = 1, owner: UUID? = nil, commodity: Int = 13, priceDelta: Int = 0,
    stockAfterDelta: Int = 0, cargoAfterDelta: Int = 0, cashAfterDelta: Int = 0
  ) throws -> NativeFirstCommoditySale {
    let dockOwner = UUID()
    let system = SystemIdentity(galaxy: 0, system: 7)
    let station = NativeMainStationIdentity(
      world: dockOwner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
    let dock = NativeMainStationDockReceipt(
      station: station, actor: .init(system: system, visit: 1, entity: 1),
      commanderOwner: dockOwner, sequence: 1, calendarSeconds: 0)
    let price =
      try #require(
        OriginalLiveMarkets.initialQuote(galaxy: 0, system: 7, commodity: 13)
      ).bidPrice + priceDelta
    return .init(
      operation: UUID(), owner: owner ?? dockOwner, commodity: commodity, dock: dock,
      physicalTime: 0, calendarOperation: 0, unitPrice: price, quantity: quantity,
      before: .init(stock: 20, cargo: quantity, credits: 100),
      after: .init(
        stock: 20 + quantity + stockAfterDelta, cargo: cargoAfterDelta,
        credits: 100 + quantity * price + cashAfterDelta))
  }

  @Test func nativeSingleAndBatchSalesRequireAllThreeActualBalancesAndTheOriginalQuote() throws {
    let single = try fixture()
    #expect(single.valid && single.quantity == 1)
    let batch = try fixture(quantity: 12)
    #expect(batch.valid && batch.after.stock == 32 && batch.after.cargo == 0)
    #expect(batch.after.credits - batch.before.credits == 12 * batch.unitPrice)
    for invalid in [
      try fixture(quantity: 0), try fixture(owner: UUID()), try fixture(commodity: 17),
      try fixture(priceDelta: 1), try fixture(stockAfterDelta: -1),
      try fixture(cargoAfterDelta: 1), try fixture(cashAfterDelta: 1),
    ] { #expect(!invalid.valid) }
  }

  @Test func saturatedCashAndHugeFiniteBatchRevenuePreserveTheActualCreditCapWithoutOverflow()
    throws
  {
    let base = try fixture()
    #expect(base.unitPrice > 17)
    let quantity = Int.max / 17
    let large = NativeFirstCommoditySale(
      operation: UUID(), owner: base.owner, commodity: base.commodity, dock: base.dock,
      physicalTime: 0, calendarOperation: 0, unitPrice: base.unitPrice, quantity: quantity,
      before: .init(stock: 0, cargo: quantity, credits: 4_294_967_294),
      after: .init(stock: quantity, cargo: 0, credits: 4_294_967_295))
    #expect(large.valid)
    let saturated = NativeFirstCommoditySale(
      operation: UUID(), owner: base.owner, commodity: base.commodity, dock: base.dock,
      physicalTime: 0, calendarOperation: 0, unitPrice: base.unitPrice, quantity: 1,
      before: .init(stock: 0, cargo: 1, credits: 4_294_967_295),
      after: .init(stock: 1, cargo: 0, credits: 4_294_967_295))
    #expect(saturated.valid)
    #expect(
      !NativeSaleBalance(stock: Int.max, cargo: 1, credits: 0).valid)
    #expect(
      !NativeSaleBalance(stock: 0, cargo: 0, credits: 4_294_967_296).valid)
  }

  @Test func immutableSaleRoundTripRetainsEvidenceWithoutGrantingCampaignOrClueProgress() throws {
    let sale = try fixture()
    let restored = try JSONDecoder().decode(
      NativeFirstCommoditySale.self, from: JSONEncoder().encode(sale))
    #expect(restored == sale && restored.valid)
    var engine = ScriptEngineState()
    engine.firstNativeCommoditySale = restored
    #expect(engine.instances.isEmpty && engine.savedClueJournal == nil)
    #expect(engine.firstNativeCommoditySale?.operation == sale.operation)
  }

  @Test(arguments: [false, true])
  func strictSaleSchemaRejectsOldMisplacedUnknownAndMissingEvidenceAndLowersAllEarlierFeatures(
    alien: Bool
  ) throws {
    let sale = try fixture()
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(sale)) as? [String: Any])
    func bytes(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["firstNativeCommoditySale": value])
    }
    let schema = alien ? 66 : 65
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      try bytes(leaf), part: .missions, schema: schema)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        try bytes(leaf), part: .missions, schema: schema - 2)
    }
    #expect(throws: (any Error).self) {
      try NativeFirstCommoditySaleSave.validateFields(
        try bytes(leaf), part: .commander, schema: schema)
    }
    leaf["accredited"] = true
    #expect(throws: (any Error).self) {
      try NativeFirstCommoditySaleSave.validateFields(
        try bytes(leaf), part: .missions, schema: schema)
    }
    leaf.removeValue(forKey: "accredited")
    leaf.removeValue(forKey: "dock")
    #expect(throws: (any Error).self) {
      try NativeFirstCommoditySaleSave.validateFields(
        try bytes(leaf), part: .missions, schema: schema)
    }
    let glass = NativeFirstCommoditySaleSave.lowerSchema(schema)
    #expect(glass == (alien ? 64 : 63))
    let fleet = NativeGlassMeridianSave.lowerSchema(glass)
    #expect(fleet == (alien ? 62 : 61))
    #expect(NativeFleetDiscoverySave.lowerSchema(fleet) == (alien ? 60 : 59))
  }
}
