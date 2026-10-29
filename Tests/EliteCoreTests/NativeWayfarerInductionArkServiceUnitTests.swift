import Foundation
import Testing

@testable import EliteCore

private struct ArkServiceFixture {
  let f: InductionArkProducerFixture
  let contact: NativeArkFuelContact
  let bank: NativeArkFuelEscrow
  init() throws {
    f = try .init()
    let dock = f.key.dock
    contact = .init(
      mission: f.source.mission, ark: f.source.actor,
      station: dock.station, stationActor: dock.actor,
      arkActor: .init(system: dock.station.system, visit: dock.actor.visit, entity: 2),
      sequence: 1, physicalTime: 402)
    bank = try .init(source: f.source)
  }
  func request(
    stock: Int = 1000, revision: UInt64 = 0, time: Double = 403,
    supplier: ActorIdentity? = nil
  ) -> NativeArkFuelRequest {
    .init(
      offer: .init(
        contact: contact, supplierRevision: revision,
        availableTenthsLY: stock, pricePerTenth: Equipment.base[0].price,
        supplierActor: supplier ?? contact.stationActor, quotedAtPhysicalTime: time),
      before: 0, nextHopLY: 9)
  }
}

struct NativeWayfarerInductionArkServiceUnitTests {
  @Test func stationReserveIssuesOnceByWorldAndStationRatherThanArkVisitOrQuote() throws {
    let f = try ArkServiceFixture()
    let supply = try NativeArkStationFuel(contact: f.contact)
    #expect(supply.valid && supply.openingTenthsLY == 1000 && supply.remainingTenthsLY == 1000)
    #expect(supply.purchases.isEmpty && supply.revision == 0)
    let otherContact = NativeArkFuelContact(
      mission: UUID(), ark: UUID(), station: f.contact.station,
      stationActor: .init(system: f.contact.station.system, visit: 20, entity: 1),
      arkActor: .init(system: f.contact.station.system, visit: 20, entity: 4),
      sequence: 4, physicalTime: 500)
    let reopenedIdentity = try NativeArkStationFuel(contact: otherContact)
    #expect(reopenedIdentity.issue == supply.issue)
    let foreign = try ArkServiceFixture()
    #expect(NativeArkStationFuel.identity(foreign.contact.station) != supply.issue)
    #expect(supply.station.world == f.f.source.owner)
  }

  @Test func paidTransferConservesSameCapturedSupplierReserveAndCustodianEscrowAndRejectsReplay()
    throws
  {
    let f = try ArkServiceFixture()
    let supply = try NativeArkStationFuel(contact: f.contact)
    let request = f.request()
    let quote = try f.bank.quote(request)
    let bank = try f.bank.purchasing(quote, current: request)
    let receipt = try #require(bank.purchases.last)
    let depleted = try supply.dispensing(receipt)
    #expect(depleted.valid && depleted.remainingTenthsLY == 910 && depleted.revision == 1)
    #expect(bank.remainingCredits == 10_000 - 90 * Equipment.base[0].price)
    #expect(receipt.fuelAfter == 9 && receipt.billedTenths == 90)
    #expect(supply.remainingTenthsLY == 1000 && f.bank.remainingCredits == 10_000)
    #expect(throws: (any Error).self) { try depleted.dispensing(receipt) }
    let stale = try f.bank.purchasing(
      f.bank.quote(f.request(revision: 1)), current: f.request(revision: 1))
    #expect(throws: (any Error).self) { try supply.dispensing(#require(stale.purchases.last)) }
    let restored = try JSONDecoder().decode(
      NativeArkStationFuel.self, from: JSONEncoder().encode(depleted))
    #expect(restored == depleted && restored.valid && restored.remainingTenthsLY == 910)
  }

  @Test func supplierQuoteNeedsTheActualStationVisitAndBoundedCurrentPhysicalTime() throws {
    let f = try ArkServiceFixture()
    let oldVisit = ActorIdentity(system: f.contact.station.system, visit: 1, entity: 1)
    let wrongActor = ActorIdentity(system: f.contact.station.system, visit: 7, entity: 2)
    for request in [
      f.request(time: 401), f.request(time: .nan), f.request(supplier: oldVisit),
      f.request(supplier: wrongActor),
    ] {
      #expect(!request.offer.valid)
      #expect(throws: NativeArkFuelRefusal.invalidInput) { try f.bank.quote(request) }
    }
    let freshVisit = ActorIdentity(system: f.contact.station.system, visit: 8, entity: 1)
    let request = f.request(time: 900, supplier: freshVisit)
    #expect(request.offer.valid)
    let quote = try f.bank.quote(request)
    #expect(quote.suppliedLY == 9 && quote.cost == 180)
    #expect(throws: NativeArkFuelRefusal.unavailableStock) {
      try f.bank.quote(f.request(stock: 89))
    }
    let refused = try f.bank.recordingRefusal(f.request(stock: 89))
    #expect(refused.remainingCredits == f.bank.remainingCredits && refused.purchases.isEmpty)
    #expect(refused.refusal?.reason == .unavailableStock)
  }

  @Test func dockingContactAndBerthExitKeepOneOriginalManifestAndRequireTheirNativeIdentityLinks()
    throws
  {
    let f = try ArkServiceFixture()
    let initial = try f.f.state()
    let admitted = initial.replacing(admission: .init(actor: f.contact.arkActor, physicalTime: 401))
    let parked = admitted.replacing(fuelContacts: [f.contact], dockedContact: f.contact)
    #expect(parked.shapeValid(source: f.f.source, key: f.f.key))
    #expect(
      parked.livingCrew == 6 && parked.intactSeedTonnes == 40
        && parked.authorization == initial.authorization)
    #expect(
      !admitted.replacing(dockedContact: f.contact).shapeValid(source: f.f.source, key: f.f.key))
    #expect(
      !parked.replacing(clearsDock: true, exitedContacts: [1]).shapeValid(
        source: f.f.source, key: f.f.key))
    let exit = NativeArkBerthExit(
      contactSequence: 1,
      actor: .init(system: f.contact.station.system, visit: 6, entity: 3), physicalTime: 404)
    let launched = parked.replacing(clearsDock: true, exitedContacts: [1], exits: [exit])
    #expect(launched.shapeValid(source: f.f.source, key: f.f.key))
    #expect(launched.dockedContact == nil && launched.exits == [exit])
    let restored = try JSONDecoder().decode(
      NativeInductionArkState.self, from: JSONEncoder().encode(launched))
    #expect(restored == launched && restored.shapeValid(source: f.f.source, key: f.f.key))
    #expect(
      !admitted.replacing(serviceWait: .fuelUnavailable).shapeValid(
        source: f.f.source, key: f.f.key))
  }

  @Test func nativeCrossingNeedsForwardAlignedSlowAttainedEntryAndNeverAnApproachOrDeparture() {
    let station = ShipPose()
    let start = ShipPose(position: .init(0, -2.67, -92))
    let end = ShipPose(position: .init(0, -2.67, -89))
    #expect(
      NativeArkDockCrossing.admits(
        from: start, to: end,
        stationFrom: station, stationTo: station, delta: 0.1))
    for pair in [
      (start, start), (end, start), (end, end),
      (ShipPose(position: .init(0, 0, -110)), end),
    ] {
      #expect(
        !NativeArkDockCrossing.admits(
          from: pair.0, to: pair.1,
          stationFrom: station, stationTo: station, delta: 0.1))
    }
    for delta in [0, -1, Double.nan, 0.2] {
      #expect(
        !NativeArkDockCrossing.admits(
          from: start, to: end,
          stationFrom: station, stationTo: station, delta: delta))
    }
    var inverted = end
    inverted.orientation.rotate(pitch: 0, roll: .pi, yaw: 0)
    #expect(
      !NativeArkDockCrossing.admits(
        from: start, to: inverted,
        stationFrom: station, stationTo: station, delta: 0.1))
    let movedStation = ShipPose(position: .init(10, 0, 0))
    var movedEnd = end
    movedEnd.position = movedEnd.position + movedStation.position
    #expect(
      NativeArkDockCrossing.admits(
        from: start, to: movedEnd,
        stationFrom: station, stationTo: movedStation, delta: 0.1))
  }

  @Test func fuelReserveSchemaPreservesEarlierRegistrationButRejectsOldAndUnknownSupplierClaims()
    throws
  {
    let f = try ArkServiceFixture()
    let supply = try NativeArkStationFuel(contact: f.contact)
    let object = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(supply)) as? [String: Any])
    func data(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["nativeStations": ["arkFuel": [value]]])
    }
    try NativeInductionArkSave.validateFields(data(object), part: .commander, schema: 77)
    try NativeInductionArkSave.validateFields(data(object), part: .commander, schema: 78)
    for schema in [75, 76, 73] {
      #expect(throws: (any Error).self) {
        try NativeInductionArkSave.validateFields(data(object), part: .commander, schema: schema)
      }
    }
    var changed = object
    changed["openingTenthsLY"] = 2000
    #expect(throws: (any Error).self) {
      try NativeInductionArkSave.validateFields(data(changed), part: .commander, schema: 77)
    }
    changed = object
    changed["resupply"] = true
    #expect(throws: (any Error).self) {
      try NativeInductionArkSave.validateFields(data(changed), part: .commander, schema: 77)
    }
    let child = f.f.child(try f.f.state())
    let previous = try JSONSerialization.data(withJSONObject: [
      "instances": [
        child.id.uuidString:
          JSONSerialization.jsonObject(with: JSONEncoder().encode(child))
      ]
    ])
    try NativeInductionArkSave.validateFields(previous, part: .missions, schema: 75)
    #expect(NativeInductionArkSave.lowerSchema(76) == 74)
    #expect(NativeInductionArkSave.lowerSchema(78) == 74)
  }
}
