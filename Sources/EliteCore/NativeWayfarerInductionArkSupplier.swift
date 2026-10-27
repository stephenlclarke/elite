import Foundation

/// A separate mission-service reserve, never the ordinary player Fuel shop's total stock.
struct NativeArkStationFuel: Codable, Sendable, Equatable {
  static let openingTenths = 1000  // Explicit project allocation: 100 LY per real main station.
  let station: NativeMainStationIdentity
  let issue: UUID
  let openingContact: NativeArkFuelContact
  let openingTenthsLY: Int
  let purchases: [NativeArkFuelPurchase]
  var revision: UInt64 { UInt64(purchases.count) }
  var remainingTenthsLY: Int {
    var stock = openingTenthsLY
    for purchase in purchases {
      guard purchase.billedTenths >= 0, purchase.billedTenths <= stock else { return 0 }
      stock -= purchase.billedTenths
    }
    return max(0, stock)
  }

  init(contact: NativeArkFuelContact) throws {
    guard contact.valid else { throw SaveError.invalidCommander }
    station = contact.station
    issue = Self.identity(station)
    openingContact = contact
    openingTenthsLY = Self.openingTenths
    purchases = []
  }
  private init(_ previous: Self, purchase: NativeArkFuelPurchase) {
    station = previous.station
    issue = previous.issue
    openingContact = previous.openingContact
    openingTenthsLY = previous.openingTenthsLY
    purchases = previous.purchases + [purchase]
  }
  static func identity(_ station: NativeMainStationIdentity) -> UUID {
    ScriptIdentity.uuid(
      "native-ark-station-fuel-issue-v1:\(station.world):\(station.key):\(station.resource)")
  }
  var valid: Bool {
    guard station.valid, openingContact.valid, openingContact.station == station,
      issue == Self.identity(station), openingTenthsLY == Self.openingTenths,
      purchases.count <= 128, Set(purchases.map(\.operation)).count == purchases.count
    else { return false }
    var stock = openingTenthsLY
    var lastTime = openingContact.physicalTime
    for (index, purchase) in purchases.enumerated() {
      let offer = purchase.request.offer
      guard offer.valid, offer.contact.station == station,
        offer.supplierRevision == UInt64(index), offer.availableTenthsLY == stock,
        offer.quotedAtPhysicalTime >= lastTime,
        purchase.billedTenths > 0, purchase.billedTenths <= stock,
        purchase.stockAfterTenths == stock - purchase.billedTenths
      else { return false }
      stock = purchase.stockAfterTenths
      lastTime = offer.quotedAtPhysicalTime
    }
    return stock >= 0
  }
  func dispensing(_ purchase: NativeArkFuelPurchase) throws -> Self {
    guard valid, purchases.count < 128,
      purchase.request.offer.supplierRevision == revision,
      purchase.request.offer.availableTenthsLY == remainingTenthsLY,
      !purchases.contains(where: { $0.operation == purchase.operation })
    else { throw NativeArkFuelRefusal.staleQuote }
    let next = Self(self, purchase: purchase)
    guard next.valid else { throw NativeArkFuelRefusal.staleQuote }
    return next
  }
}

extension NativeInductionArkSave {
  static func supplierClaimsValid(_ commander: borrowing Commander) -> Bool {
    let banks = commander.scriptState.instances.values.compactMap { $0.savedNativeArk }
    let supplies = commander.nativeStations?.arkFuel ?? []
    let rescues = commander.scriptState.instances.values.compactMap { $0.savedNativeCrewLog }
    let purchases =
      banks.flatMap { $0.fuel.purchases }
      + rescues.flatMap { $0.rescueFuel?.purchases ?? [] }
    let contacts = banks.flatMap(\.fuelContacts) + rescues.flatMap { $0.flight?.fuelContacts ?? [] }
    guard supplies.allSatisfy(\.valid),
      Set(supplies.flatMap { $0.purchases.map(\.operation) }) == Set(purchases.map(\.operation)),
      supplies.reduce(0, { $0 + $1.purchases.count }) == purchases.count
    else { return false }
    for supply in supplies {
      guard contacts.contains(supply.openingContact),
        supply.purchases.allSatisfy({ purchases.contains($0) })
      else { return false }
    }
    return true
  }
}
