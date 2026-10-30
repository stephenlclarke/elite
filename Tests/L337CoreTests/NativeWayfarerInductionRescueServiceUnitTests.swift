import Foundation
import Testing

@testable import L337Core

/// Policy/ledger records only. No fixture drives a native dock, supply transfer or relaunch.
private final class RescueServiceFixture {
  let f: RescueFlightFixture
  let contact: NativeArkFuelContact
  let request: NativeArkFuelRequest
  let actor: ScriptOwnedActor
  init(stock: Int = 1000) throws {
    let f = try RescueFlightFixture(fuel: 0)
    self.f = f
    let dock = f.authorization.dock
    let native = ActorIdentity(system: dock.station.system, visit: 32, entity: 3)
    contact = .init(
      mission: f.f.parent.permission.mission, ark: f.f.f.source.manifest.launch,
      station: dock.station, stationActor: dock.actor, arkActor: native, sequence: 1,
      physicalTime: 20_004)
    request = .init(
      offer: .init(
        contact: contact, supplierRevision: 0,
        availableTenthsLY: stock, pricePerTenth: Equipment.base[0].price,
        quotedAtPhysicalTime: 20_005), before: 0, nextHopLY: f.authorization.route.distancesLY[0])
    var actor = try f.f.f.prepared(.launch)
    actor.presence = .unloaded
    actor.body.id = 43
    actor.body.physical = .init(
      identity: native, population: .mission,
      npc: .init(
        role: .mission, origin: dock.station.system,
        destination: NativeInductionCrewLogSource.receiver))
    actor.body.scriptNPC?.fuel = 0
    self.actor = actor
  }
  func state() -> NativeInductionCrewLogState {
    var state = f.state()
    state.flight?.savedFuelContacts = [contact]
    state.flight?.dockedContact = contact
    state.flight?.recordBinding(contact.arkActor, at: 20_003.5)
    return state
  }
  func paidState() throws -> NativeInductionCrewLogState {
    var state = state()
    let bank = try #require(state.rescueFuel)
    state.rescueFuel = try bank.purchasing(bank.quote(request), current: request)
    return state
  }
}

struct NativeWayfarerInductionRescueServiceUnitTests {
  @Test func berthHistoryRequiresOriginalVesselObservedBindingAndExactlyOneUnexitedContact() throws
  {
    let f = try RescueServiceFixture()
    var state = f.state()
    #expect(state.shapeValid(parent: f.f.f.parent))
    #expect(state.livingCrew == f.f.f.f.source.manifest.crew)
    #expect(f.f.f.parent.milestones == [0, 1, 2, 3, 4, 5, 6, 7])
    state.flight?.dockedContact = nil
    #expect(!state.shapeValid(parent: f.f.f.parent))
    state = f.state()
    state.flight?.savedFuelContacts = [f.contact, f.contact]
    #expect(!state.shapeValid(parent: f.f.f.parent))
    state = f.state()
    state.flight?.savedBindings = []
    #expect(
      !NativeRescueFlightSave.fuelHistoryValid(
        try #require(state.flight),
        bank: state.rescueFuel, actor: f.actor, engine: .init()))
  }

  @Test func paidServiceConservesOnlyNeededTankFuelOwnCashAndSamePersistentSupplierStock() throws {
    let f = try RescueServiceFixture()
    let state = try f.paidState()
    let bank = try #require(state.rescueFuel)
    let receipt = try #require(bank.purchases.last)
    let supply = try NativeArkStationFuel(contact: f.contact).dispensing(receipt)
    #expect(state.shapeValid(parent: f.f.f.parent))
    #expect(receipt.billedTenths == Int(ceil(f.request.nextHopLY * 10)))
    #expect(bank.remainingCredits == 10_000 - receipt.billedTenths * Equipment.base[0].price)
    #expect(supply.remainingTenthsLY == 1000 - receipt.billedTenths && supply.revision == 1)
    #expect(receipt.fuelAfter < 13 && receipt.fuelAfter >= f.request.nextHopLY)
    var actor = f.actor
    actor.body.scriptNPC?.fuel = receipt.fuelAfter
    let flight = try #require(state.flight)
    #expect(
      NativeRescueFlightSave.fuelHistoryValid(flight, bank: bank, actor: actor, engine: .init()))
    #expect(
      !NativeRescueFlightSave.fuelHistoryValid(flight, bank: nil, actor: actor, engine: .init()))
    #expect(
      !NativeRescueFlightSave.fuelHistoryValid(flight, bank: bank, actor: f.actor, engine: .init()))
    #expect(f.f.f.parent.payloads == [NativeWayfarerInduction.crewLogPayload: 1])
  }

  @Test func servicePurchaseCannotClaimAnotherRouteHopOrFutureQuoteAndStockNeedsOwningBank() throws
  {
    let f = try RescueServiceFixture()
    let state = try f.paidState()
    let bank = try #require(state.rescueFuel)
    let flight = try #require(state.flight)
    let forged = NativeArkFuelRequest(
      offer: f.request.offer, before: 0,
      nextHopLY: f.request.nextHopLY + 0.1)
    #expect(!flight.serviceRequestFitsRoute(forged))
    var commander = try f.f.f.commander()
    while commander.flightSimulation.visit < 32 {
      commander.flightSimulation.enter(NativeInductionCrewLogSource.location, arriving: true)
    }
    commander.flightSimulation.physicalTime = 20_004.5
    #expect(!NativeRescueFlightSave.serviceBoundsValid(flight, bank: bank, commander: commander))
    commander.flightSimulation.physicalTime = 20_006
    #expect(NativeRescueFlightSave.serviceBoundsValid(flight, bank: bank, commander: commander))
    var child = try #require(commander.scriptState.instances[state.authorization.job])
    child.savedNativeCrewLog = state
    commander.scriptState.instances[child.id] = child
    let receipt = try #require(bank.purchases.last)
    commander.nativeStations?.arkFuel = [
      try NativeArkStationFuel(contact: f.contact).dispensing(receipt)
    ]
    #expect(NativeInductionArkSave.supplierClaimsValid(commander))
    commander.scriptState.instances[child.id]?.savedNativeCrewLog?.rescueFuel = f.state().rescueFuel
    #expect(!NativeInductionArkSave.supplierClaimsValid(commander))
  }

  @Test func unavailableSupplyPersistsFiniteRefusalWithoutTankCrewOrStockCreation() throws {
    let f = try RescueServiceFixture(stock: 0)
    var state = f.state()
    let bank = try #require(state.rescueFuel)
    state.rescueFuel = try bank.recordingRefusal(f.request)
    state.flight?.serviceWait = .fuelUnavailable
    #expect(state.shapeValid(parent: f.f.f.parent))
    #expect(state.rescueFuel?.refusal?.reason == .unavailableStock)
    #expect(
      state.rescueFuel?.remainingCredits == 10_000 && state.rescueFuel?.purchases.isEmpty == true)
    #expect(f.actor.body.scriptNPC?.fuel == 0 && state.livingCrew.count == 2)
    let restored = try JSONDecoder().decode(
      NativeInductionCrewLogState.self,
      from: JSONEncoder().encode(state))
    #expect(restored == state)
    #expect(
      restored.flight?.dockedContact == f.contact
        && restored.flight?.serviceWait == .fuelUnavailable)
  }

  @Test func berthExitNeedsSameWorldFreshNativeHullAndPaidContactBeforeItCanClearDock() throws {
    let f = try RescueServiceFixture()
    var state = try f.paidState()
    let exit = ActorIdentity(system: f.contact.station.system, visit: 32, entity: 6)
    state.flight?.dockedContact = nil
    state.flight?.savedExits = [.init(contactSequence: 1, actor: exit, physicalTime: 20_006)]
    state.flight?.recordBinding(exit, at: 20_006)
    #expect(state.shapeValid(parent: f.f.f.parent))
    let receipt = try #require(state.rescueFuel?.purchases.last)
    var actor = f.actor
    actor.body.physical = .init(identity: exit, population: .mission, npc: actor.body.physical?.npc)
    actor.presence = .present
    actor.body.scriptNPC?.fuel = receipt.fuelAfter
    #expect(
      NativeRescueFlightSave.fuelHistoryValid(
        try #require(state.flight),
        bank: state.rescueFuel, actor: actor, engine: .init()))
    state.flight?.savedExits = [.init(contactSequence: 1, actor: exit, physicalTime: 20_004.5)]
    state.flight?.savedBindings = [
      .init(actor: f.contact.arkActor, physicalTime: 20_003.5),
      .init(actor: exit, physicalTime: 20_004.5),
    ]
    #expect(
      !NativeRescueFlightSave.fuelHistoryValid(
        try #require(state.flight),
        bank: state.rescueFuel, actor: actor, engine: .init()))
    state.flight?.savedExits = [
      .init(contactSequence: 1, actor: f.contact.arkActor, physicalTime: 20_006)
    ]
    #expect(!state.shapeValid(parent: f.f.f.parent))
    // Native dock, payment and berth exit may all attain the same simulation frame.
    state = f.state()
    let sameFrame = NativeArkFuelRequest(
      offer: .init(
        contact: f.contact,
        supplierRevision: 0, availableTenthsLY: 1000, pricePerTenth: Equipment.base[0].price),
      before: 0, nextHopLY: f.request.nextHopLY)
    let opening = try #require(state.rescueFuel)
    state.rescueFuel = try opening.purchasing(opening.quote(sameFrame), current: sameFrame)
    state.flight?.dockedContact = nil
    state.flight?.savedExits = [
      .init(contactSequence: 1, actor: exit, physicalTime: f.contact.physicalTime)
    ]
    state.flight?.recordBinding(exit, at: f.contact.physicalTime)
    #expect(state.shapeValid(parent: f.f.f.parent))
    #expect(
      NativeRescueFlightSave.fuelHistoryValid(
        try #require(state.flight),
        bank: state.rescueFuel, actor: actor, engine: .init()))
  }

  @Test func closedServiceEnvelopePreservesEarlierFlightAndRejectsEarlyOrUnknownBerthClaims() throws
  {
    let f = try RescueServiceFixture()
    let leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.state())) as? [String: Any])
    func bytes(_ leaf: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.f.authorization.job.uuidString: [
            "definition": NativeInductionCrewLogPack.stateID,
            "digest": NativeInductionCrewLogPack.digest,
            "savedNativeCrewLog": leaf,
          ]
        ]
      ])
    }
    for schema in [93, 94] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        bytes(leaf), part: .missions, schema: schema)
    }
    for schema in [89, 90, 91, 92, Int.max] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes(leaf), part: .missions, schema: schema)
      }
    }
    let old = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.f.state())) as? [String: Any])
    for schema in [91, 92, 93, 94] {
      try NativeInductionCrewLogSave.validateFields(bytes(old), part: .missions, schema: schema)
    }
    var forged = leaf
    var flight = try #require(forged["flight"] as? [String: Any])
    flight["freeRefuel"] = true
    forged["flight"] = flight
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(bytes(forged), part: .missions, schema: 93)
    }
    #expect(NativeInductionArkSave.isAlien(92) && NativeInductionArkSave.isAlien(94))
  }
}
