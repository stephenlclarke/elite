import Foundation
import Testing

@testable import EliteCore

/// Structural financial/dock facts only; constructed contacts cannot perform native service.
private struct ArkFuelFixture {
  let helpers: InductionVaultKeyFixture
  let source: NativeInductionArkSource
  let bank: NativeArkFuelEscrow
  init() throws {
    let helpers = try InductionVaultKeyFixture()
    self.helpers = helpers
    source = try .init(
      loan: helpers.key(), permission: helpers.serviced.permission,
      service: #require(helpers.serviced.cassetteService))
    bank = try .init(source: source)
  }
  func request(
    before: Double = 1.25, next: Double = 4, stock: Int = 130, revision: UInt64 = 1,
    sequence: UInt64 = 1, time: Double? = nil, owner: UUID? = nil, ark: UUID? = nil
  ) -> NativeArkFuelRequest {
    let dock = helpers.helpers.helpers.helpers.dock(
      owner: owner ?? source.owner, system: 8, visit: 7, sequence: 1)
    let contact = NativeArkFuelContact(
      mission: source.mission, ark: ark ?? source.actor, station: dock.station,
      stationActor: dock.actor,
      arkActor: .init(system: dock.station.system, visit: 7, entity: 2),
      sequence: sequence, physicalTime: time ?? Double(sequence))
    return .init(
      offer: .init(
        contact: contact, supplierRevision: revision,
        availableTenthsLY: stock, pricePerTenth: Equipment.base[0].price),
      before: before, nextHopLY: next)
  }
}

struct NativeWayfarerInductionArkFuelUnitTests {
  @Test func actualCatalogueRouteUsesReachableHopsAndAdvertisesItsRealRefuellingDependency() throws
  {
    let f = try ArkFuelFixture()
    let plan = try NativeArkRoutePlan(source: f.source)
    #expect(plan.matches(source: f.source) && plan.worldKeys.first == "G01-S162")
    #expect(plan.worldKeys.last == "G01-S091" && plan.legDistancesLY.count >= 2)
    #expect(plan.driveReachLY == 9 && plan.initialFuelLY == 13)
    #expect(plan.legDistancesLY.allSatisfy { $0 > 0 && $0 <= 9 })
    let direct = try Universe.originalWorlds.distanceLY(from: "G01-S162", to: "G01-S091")
    #expect(abs(direct - 13.078405306840741) < 1e-12)
    #expect(plan.totalDistanceLY >= direct && plan.minimumAdditionalFuelLY > 0)
    #expect(plan.catalogueRevision == OriginalWorldCatalogue.approvedFingerprints["catalogue.json"])
    let other = try ArkFuelFixture()
    #expect(!plan.matches(source: other.source))
    #expect(f.bank.purchases.isEmpty && f.bank.remainingCredits == 10_000)
  }

  @Test func quoteBuysOnlyNeededNativeTenthsWithinTheRealDriveAndTankAndConservesEscrowAndStock()
    throws
  {
    let f = try ArkFuelFixture()
    #expect(f.bank.valid && f.bank.remainingCredits == 10_000 && f.bank.purchases.isEmpty)
    let request = f.request()
    let quote = try f.bank.quote(request)
    #expect(quote.cost == 28 * Equipment.base[0].price)
    #expect(abs(quote.suppliedLY - 2.8) < 1e-12 && abs(quote.fuelAfter - 4.05) < 1e-12)
    #expect(quote.supplierStockAfterTenths == 102)
    let paid = try f.bank.purchasing(quote, current: request)
    #expect(paid.valid && paid.remainingCredits == 10_000 - quote.cost)
    #expect(paid.purchases.count == 1 && paid.purchases[0].balanceBefore == 10_000)
    #expect(f.bank.remainingCredits == 10_000 && f.bank.purchases.isEmpty)
    let maximumHop = try f.bank.quote(f.request(before: 0, next: 9))
    #expect(maximumHop.fuelAfter == 9 && maximumHop.fuelAfter < f.source.definition.fuel)
    for invalid in [
      f.request(before: -1), f.request(before: .nan), f.request(before: 14),
      f.request(next: 0), f.request(next: 9.01), f.request(next: .infinity),
    ] { #expect(throws: NativeArkFuelRefusal.invalidInput) { try f.bank.quote(invalid) } }
    #expect(throws: NativeArkFuelRefusal.noFuelNeeded) {
      try f.bank.quote(f.request(before: 9, next: 8))
    }
  }

  @Test func wrongNativeDockChangedSupplierQuoteAndRepeatedContactCannotDebitOrRefill() throws {
    let f = try ArkFuelFixture()
    let request = f.request()
    let quote = try f.bank.quote(request)
    #expect(throws: NativeArkFuelRefusal.foreignDock) { try f.bank.quote(f.request(owner: UUID())) }
    #expect(throws: NativeArkFuelRefusal.foreignDock) { try f.bank.quote(f.request(ark: UUID())) }
    #expect(throws: NativeArkFuelRefusal.staleQuote) {
      try f.bank.purchasing(quote, current: f.request(revision: 2))
    }
    #expect(throws: NativeArkFuelRefusal.staleQuote) {
      try f.bank.purchasing(quote, current: f.request(stock: 129))
    }
    #expect(throws: NativeArkFuelRefusal.staleQuote) {
      try f.bank.purchasing(quote, current: f.request(before: 1.26))
    }
    let paid = try f.bank.purchasing(quote, current: request)
    #expect(throws: NativeArkFuelRefusal.staleQuote) {
      try paid.purchasing(quote, current: request)
    }
    #expect(throws: NativeArkFuelRefusal.staleQuote) {
      try paid.quote(f.request(sequence: 2, time: 0.5))
    }
    #expect(f.bank.purchases.isEmpty && paid.purchases.count == 1)
  }

  @Test func finiteOpeningIssueCanRunOutAndRecordsARefusalWithoutMintingCashFuelOrNewStock()
    throws
  {
    let f = try ArkFuelFixture()
    let cost = 90 * Equipment.base[0].price
    try #require(cost > 0)
    var bank = f.bank
    var sequence: UInt64 = 1
    while bank.remainingCredits >= cost {
      let request = f.request(before: 0, next: 9, sequence: sequence)
      bank = try bank.purchasing(bank.quote(request), current: request)
      sequence += 1
    }
    #expect(bank.valid && bank.remainingCredits >= 0 && bank.remainingCredits < cost)
    let request = f.request(before: 0, next: 9, sequence: sequence)
    #expect(throws: NativeArkFuelRefusal.insufficientEscrow) { try bank.quote(request) }
    let refused = try bank.recordingRefusal(request)
    #expect(refused.valid && refused.refusal?.reason == .insufficientEscrow)
    #expect(
      refused.remainingCredits == bank.remainingCredits && refused.purchases == bank.purchases)
    let restored = try NativeArkFuelEscrow.decodeClosed(JSONEncoder().encode(refused))
    #expect(restored == refused && restored.openingCredits == 10_000)
    #expect(throws: NativeArkFuelRefusal.insufficientEscrow) { try restored.quote(request) }
    let unavailable = try f.bank.recordingRefusal(f.request(stock: 0))
    #expect(
      unavailable.refusal?.reason == .unavailableStock && unavailable.remainingCredits == 10_000)
    #expect(unavailable.purchases.isEmpty)
  }

  @Test(arguments: [false, true])
  func closedEscrowRoundTripRetainsPurchasesAndRefusalsAndRejectsInventedFundsOrNestedClaims(
    refused: Bool
  ) throws {
    let f = try ArkFuelFixture()
    let request = f.request()
    let state: NativeArkFuelEscrow
    if refused {
      state = try f.bank.recordingRefusal(f.request(stock: 0))
    } else {
      state = try f.bank.purchasing(f.bank.quote(request), current: request)
    }
    let bytes = try JSONEncoder().encode(state)
    #expect(try NativeArkFuelEscrow.decodeClosed(bytes) == state)
    let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    for field in ["openingCredits", "remainingCredits", "playerReward"] {
      var changed = original
      changed[field] = 20_000
      #expect(throws: (any Error).self) {
        try NativeArkFuelEscrow.decodeClosed(JSONSerialization.data(withJSONObject: changed))
      }
    }
    var changed = original
    if refused {
      var record = try #require(changed["refusal"] as? [String: Any])
      record["freeFuelGranted"] = true
      changed["refusal"] = record
    } else {
      var purchases = try #require(changed["purchases"] as? [[String: Any]])
      purchases[0]["freeFuelGranted"] = true
      changed["purchases"] = purchases
    }
    #expect(throws: (any Error).self) {
      try NativeArkFuelEscrow.decodeClosed(JSONSerialization.data(withJSONObject: changed))
    }
  }
}
