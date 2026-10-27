import Foundation
import Testing

@testable import EliteCore

/// Structural receipt and owned-leg policy only; no fixture executes a native rescue journey.
final class RescueReceivingFixture {
  let f: RescueFlightFixture
  let dock: NativeMainStationDockReceipt
  let contact: NativeArkFuelContact
  init() throws {
    f = try .init()
    let visit = UInt64(33 + f.authorization.route.distancesLY.count)
    dock = NativeWayfarerInductionUnitTests().dock(
      owner: f.f.f.source.manifest.owner,
      system: 0, visit: visit, sequence: 100)
    contact = .init(
      mission: f.f.parent.permission.mission, ark: f.f.f.source.manifest.launch,
      station: dock.station, stationActor: dock.actor,
      arkActor: .init(system: dock.station.system, visit: visit, entity: 3), sequence: 2,
      physicalTime: 999_999)
  }
  func receipt(
    crew: [UUID]? = nil, recorder: UUID? = nil, target: String? = nil,
    dock: NativeMainStationDockReceipt? = nil, capture: UUID? = nil
  ) throws -> NativeInductionRescueReception {
    let dock = dock ?? self.dock
    let original = try #require(f.f.parent.crewLog)
    let crew = crew ?? f.authorization.crew
    let capture = capture ?? original.operation
    let operation = try NativeInductionRescueReception.identity(
      registration: f.f.state.authorization.operation, flight: f.authorization.operation,
      capture: capture, launchDock: contact, playerDock: dock, carrier: original.carrier,
      revision: 1, physicalTime: 1_000_000, flightSeconds: 900_000, crew: crew)
    return .init(
      operation: operation, sequence: 104, owner: f.f.f.source.manifest.owner,
      parent: f.f.parent.permission.mission, job: f.authorization.job,
      registration: f.f.state.authorization.operation, flight: f.authorization.operation,
      capture: capture, launch: f.f.f.source.manifest.launch,
      recorder: recorder ?? original.original,
      target: target ?? NativeInductionRescueReception.receivingTarget, crew: crew,
      launchDock: contact, playerDock: dock, carrier: original.carrier,
      inventoryRevision: 1, physicalTime: 1_000_000, flightSeconds: 900_000)
  }
  func state(receipt: NativeInductionRescueReception) throws -> NativeInductionCrewLogState {
    var state = f.state()
    let service = try interhopService()
    state.flight?.savedFuelContacts = [service.contact, contact]
    state.flight?.savedExits = [service.exit]
    state.flight?.recordBinding(service.contact.arkActor, at: service.contact.physicalTime - 1)
    state.flight?.recordBinding(service.exit.actor, at: service.exit.physicalTime)
    state.flight?.dockedContact = contact
    state.flight?.recordBinding(contact.arkActor, at: 999_998)
    state.rescueFuel = try service.bank.closing(at: receipt)
    state.rescueReception = receipt
    return state
  }
  /// One finite supplier debit at the first hop the original tank cannot cover.
  /// These are typed ledger fixtures, not evidence of an executed native journey.
  func interhopService() throws -> (
    hop: Int, contact: NativeArkFuelContact, exit: NativeArkBerthExit,
    bank: NativeRescueFuelEscrow, supply: NativeArkStationFuel
  ) {
    let plan = f.authorization.route
    var fuel = f.authorization.initialFuelLY
    for hop in plan.distancesLY.indices {
      let distance = plan.distancesLY[hop]
      if fuel >= distance {
        fuel -= distance
        continue
      }
      try #require(hop > 0)
      let world = try Universe.originalWorlds.world(key: plan.worldKeys[hop])
      let visit = UInt64(32 + hop)
      let dock = NativeWayfarerInductionUnitTests().dock(
        owner: f.f.f.source.manifest.owner, system: world.system,
        visit: visit, sequence: visit)
      let physical = 50_000 + Double(hop) * 1000
      let contact = NativeArkFuelContact(
        mission: f.f.parent.permission.mission, ark: f.f.f.source.manifest.launch,
        station: dock.station, stationActor: dock.actor,
        arkActor: .init(system: dock.station.system, visit: visit, entity: 3),
        sequence: 1, physicalTime: physical - 30)
      let supply = try NativeArkStationFuel(contact: contact)
      let request = NativeArkFuelRequest(
        offer: .init(
          contact: contact, supplierRevision: supply.revision,
          availableTenthsLY: supply.remainingTenthsLY,
          pricePerTenth: Equipment.base[0].price,
          quotedAtPhysicalTime: physical - 29),
        before: fuel, nextHopLY: distance)
      let original = try #require(f.state().rescueFuel)
      let bank = try original.purchasing(original.quote(request), current: request)
      let purchase = try #require(bank.purchases.last)
      let depleted = try supply.dispensing(purchase)
      try #require(bank.funding == original.funding && bank.purchases.count == 1)
      try #require(
        bank.remainingCredits == original.remainingCredits - purchase.billedTenths
          * Equipment.base[0].price)
      try #require(depleted.remainingTenthsLY == supply.remainingTenthsLY - purchase.billedTenths)
      return (
        hop, contact,
        .init(
          contactSequence: contact.sequence,
          actor: .init(system: dock.station.system, visit: visit, entity: 4),
          physicalTime: physical - 20),
        bank, depleted
      )
    }
    throw SaveError.invalidCommander
  }
  func routeLegs() throws -> [(NativeRescueHopReference, NativeWormholeLeg)] {
    let systems = Universe.galaxy()
    let catalogue = Universe.originalWorlds
    let plan = f.authorization.route
    var result: [(NativeRescueHopReference, NativeWormholeLeg)] = []
    let service = try interhopService()
    var fuel = f.authorization.initialFuelLY
    for hop in plan.distancesLY.indices {
      let reference = f.reference(hop: hop)
      let origin = try catalogue.world(key: plan.worldKeys[hop])
      let destination = try catalogue.world(key: plan.worldKeys[hop + 1])
      var exit = FlightSimulationState()
      exit.enter(.init(galaxy: 0, system: destination.system), arriving: true)
      let route = NativeWormholeRoute(
        catalogueRevision: plan.catalogueRevision,
        origin: .init(worldID: origin.key, galaxy: 0, system: systems[origin.system]),
        destination: .init(
          worldID: destination.key, galaxy: 0, system: systems[destination.system]),
        distanceLightYears: plan.distancesLY[hop], exit: exit.pose)
      let native = ActorIdentity(
        system: route.origin.location, visit: UInt64(32 + hop),
        entity: hop == service.hop ? service.exit.actor.entity : 3)
      if hop == service.hop {
        let purchase = try #require(service.bank.purchases.last)
        try #require(purchase.request.before == fuel)
        fuel = purchase.fuelAfter
      }
      let after = fuel - route.distanceLightYears
      try #require(after >= 0)
      let time = 200_000 + Double(hop) * 1_000_000
      let physical = 50_000 + Double(hop) * 1000
      var actor = try f.f.f.prepared(.launch)
      actor.body.id = 43
      actor.body.physical = .init(
        identity: native, population: .mission,
        npc: .init(
          role: .mission, origin: route.origin.location, destination: route.destination.location))
      actor.body.scriptNPC?.fuel = after
      let opening = NativeWormholeOpening(
        id: ScriptIdentity.uuid("native-wormhole-v1:\(reference.leg)"),
        leg: reference.leg, route: route, sourceActor: native,
        entrance: .init(position: .init(0, 0, 500)), radius: 100,
        openedAt: time, openedPhysicalTime: physical, expiresAt: time + 120)
      var leg = NativeWormholeLeg(
        id: reference.leg, instance: f.authorization.job,
        actor: f.authorization.actor, encounter: NativeInductionCrewLogPack.encounter,
        alias: "launch", request: reference.request, destinationWorld: destination.key,
        requestedAt: time - 20)
      leg.route = route
      leg.spooledAt = time - 12
      leg.spoolActor = native
      leg.spoolPhysicalTime = physical - 12
      leg.driveComponent = actor.body.scriptNPC?.components["drive"]?.identity
      leg.driveTerms = f.f.f.source.ship.drive
      leg.opening = opening
      leg.departure = .init(
        hole: opening.id, nativeActor: native,
        calendarSeconds: time + 1, physicalTime: physical + 1, revision: 1,
        fuelBefore: fuel, fuelAfter: after, body: actor.body)
      leg.arrival = .init(
        nativeActor: .init(
          system: route.destination.location,
          visit: UInt64(33 + hop), entity: 3), calendarSeconds: time + 1 + route.seconds)
      leg.phase = .arrived
      try #require(leg.valid)
      result.append((reference, leg))
      fuel = after
    }
    return result
  }
}

struct NativeWayfarerInductionRescueReceivingUnitTests {
  @Test func originalSurvivorsAndRecorderReturnReleaseExactlyOneTonneAndOnlyStageNineOnce() throws {
    let f = try RescueReceivingFixture()
    let receipt = try f.receipt()
    let before = f.f.f.parent
    let next = try before.receivingOriginalRescue(receipt)
    #expect(next.valid && next.rescueReception == receipt && next.payloads.isEmpty)
    #expect(next.milestones == [0, 1, 2, 3, 4, 5, 6, 7, 8] && !next.milestones.contains(9))
    #expect(next.crewLog == before.crewLog && next.seedReception == before.seedReception)
    #expect(next.permission == before.permission && next.cassetteService == before.cassetteService)
    #expect(next.action(at: NativeInductionCrewLogSource.receiver) == .progress)
    #expect(throws: (any Error).self) { try next.receivingOriginalRescue(receipt) }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self,
      from: JSONEncoder().encode(next))
    #expect(restored == next && restored.valid && restored.payloads.isEmpty)
    let event = ScriptEventContext(
      galaxy: 0, system: 0, docked: false, mainStation: false,
      revision: 10, frameSeconds: 0.1, localSeconds: 900_001, flightSeconds: 900_001,
      calendarSeconds: 1_000_001, transitSeconds: 0, playerPosition: .init(0, 0, 0))
    let loss = NativeInductionCrateLoss(
      carrier: receipt.carrier, physicalTime: 1_000_001,
      facts: .init(
        cause: .shipDestroyed, sequence: 105, context: event, energy: 0,
        visit: receipt.playerDock.actor.visit))
    #expect(throws: (any Error).self) { try next.losing(loss) }
    let previous = try OwnedEquipmentInventory(
      owner: receipt.owner,
      activeHull: receipt.carrier, revision: 1)
    let moved = try OwnedEquipmentInventory(owner: receipt.owner, activeHull: UUID(), revision: 2)
    #expect(throws: (any Error).self) { try next.transferringCrewLog(from: previous, to: moved) }
  }

  @Test func foreignEmptyDuplicateCrewWrongRecorderOrWrongActualCradleCannotReceive() throws {
    let f = try RescueReceivingFixture()
    let parent = f.f.f.parent
    for receipt in [
      try f.receipt(crew: []), try f.receipt(crew: [UUID(), UUID()]),
      try f.receipt(crew: [f.f.authorization.crew[0], f.f.authorization.crew[0]]),
      try f.receipt(recorder: UUID()), try f.receipt(target: "other-shelter"),
      try f.receipt(dock: f.f.authorization.dock), try f.receipt(capture: UUID()),
    ] {
      #expect(throws: (any Error).self) { try parent.receivingOriginalRescue(receipt) }
    }
    let other = try RescueReceivingFixture()
    #expect(throws: (any Error).self) { try parent.receivingOriginalRescue(other.receipt()) }
    #expect(
      parent.rescueReception == nil
        && parent.payloads == [NativeWayfarerInduction.crewLogPayload: 1])
  }

  @Test func unusedRescueFundsReturnOnlyToOriginalCevilisCustodianOnceAndCloseFuturePurchases()
    throws
  {
    let f = try RescueReceivingFixture()
    let receipt = try f.receipt()
    let bank = try #require(f.f.f.state.rescueFuel)
    let closed = try bank.closing(at: receipt)
    #expect(closed.valid && closed.remainingCredits == 0 && closed.purchases == bank.purchases)
    #expect(
      closed.closure?.returnedCredits == 10_000
        && closed.closure?.recipient == bank.funding.custodian)
    #expect(closed.closure?.receiving == receipt.operation)
    #expect(throws: (any Error).self) { try closed.closing(at: receipt) }
    #expect(throws: (any Error).self) { try closed.quote(f.f.f.request()) }
    #expect(throws: (any Error).self) { try bank.closing(at: RescueReceivingFixture().receipt()) }
    let restored = try NativeRescueFuelEscrow.decodeClosed(JSONEncoder().encode(closed))
    #expect(restored == closed && restored.remainingCredits == 0)
  }

  @Test func owningSourceMustShareReceivingAndClosedBankWithoutLeavingDuplicatePeopleAboard() throws
  {
    let f = try RescueReceivingFixture()
    let receipt = try f.receipt()
    let parent = try f.f.f.parent.receivingOriginalRescue(receipt)
    var state = try f.state(receipt: receipt)
    #expect(state.shapeValid(parent: parent) && state.livingCrew.isEmpty)
    let paid = try #require(state.rescueFuel)
    let purchase = try #require(paid.purchases.last)
    #expect(paid.purchases.count == 1 && purchase.request.before < purchase.request.nextHopLY)
    #expect(
      purchase.billedTenths
        == Int(ceil((purchase.request.nextHopLY - purchase.request.before) * 10)))
    #expect(
      paid.closure?.returnedCredits == NativeRescueFuelEscrow.initialCredits - purchase.billedTenths
        * Equipment.base[0].price)
    #expect(paid.closure?.recipient == paid.funding.custodian)
    let service = try f.interhopService()
    #expect(service.supply.purchases == paid.purchases && service.supply.valid)
    #expect(try NativeRescueFuelEscrow.decodeClosed(JSONEncoder().encode(paid)) == paid)
    #expect(state.rescueReception?.crew == state.authorization.manifest.crew)
    #expect(state.capture == parent.crewLog && state.flight?.dockedContact == f.contact)
    state.rescueFuel = f.f.f.state.rescueFuel
    #expect(!state.shapeValid(parent: parent))
    state = try f.state(receipt: receipt)
    #expect(!state.shapeValid(parent: f.f.f.parent))
    state.losses = [.init(role: "launch", actor: f.contact.arkActor, physicalTime: 999_997)]
    #expect(!state.shapeValid(parent: parent) && state.livingCrew.isEmpty)
  }

  @Test func everyActualOwnedHopNeedsArrivalAndFinalReferenceBeforeReceivingCanBeQualified() throws
  {
    let f = try RescueReceivingFixture()
    let legs = try f.routeLegs()
    var flight = try #require(f.f.state().flight)
    flight.legs = legs.map(\.0)
    var engine = ScriptEngineState()
    engine.wormholeTransit = .init(owner: f.f.f.f.source.manifest.owner)
    for (_, leg) in legs { engine.wormholeTransit?.legs[leg.id] = leg }
    #expect(NativeRescueFlightSave.allHopsReceived(flight, engine: engine))
    let last = try #require(legs.last)
    engine.wormholeTransit?.legs[last.1.id]?.phase = .arrivalPending
    engine.wormholeTransit?.legs[last.1.id]?.arrival = nil
    #expect(!NativeRescueFlightSave.allHopsReceived(flight, engine: engine))
    engine.wormholeTransit?.legs[last.1.id] = last.1
    let first = try #require(legs.first)
    engine.wormholeTransit?.legs[first.1.id] = nil
    #expect(!NativeRescueFlightSave.allHopsReceived(flight, engine: engine))
    engine.wormholeTransit?.legs[first.1.id] = first.1
    flight.legs.removeLast()
    #expect(!NativeRescueFlightSave.allHopsReceived(flight, engine: engine))
  }

  @Test func closedReceivingSchemaRejectsEarlierOrUnknownReceiptAndRetainsUnreceivedService() throws
  {
    let f = try RescueReceivingFixture()
    let receipt = try f.receipt()
    let state = try f.state(receipt: receipt)
    let parent = try f.f.f.parent.receivingOriginalRescue(receipt)
    func data(_ state: NativeInductionCrewLogState, _ parent: NativeWayfarerInductionState) throws
      -> Data
    {
      let leaf = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
      let root = try JSONSerialization.jsonObject(with: JSONEncoder().encode(parent))
      return try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.f.authorization.job.uuidString: [
            "definition": NativeInductionCrewLogPack.stateID,
            "digest": NativeInductionCrewLogPack.digest, "savedNativeCrewLog": leaf,
          ],
          parent.permission.mission.uuidString: [
            "definition": NativeWayfarerInduction.stateID,
            "digest": NativeWayfarerInduction.digest, "savedWayfarerInduction": root,
          ],
        ]
      ])
    }
    for schema in [95, 96] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        data(state, parent), part: .missions, schema: schema)
    }
    for schema in [89, 90, 91, 92, 93, 94, Int.max] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(
          data(state, parent), part: .missions, schema: schema)
      }
    }
    for schema in [91, 92, 93, 94, 95, 96] {
      try NativeInductionCrewLogSave.validateFields(
        data(f.f.state(), f.f.f.parent), part: .missions, schema: schema)
    }
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state.rescueFuel)) as? [String: Any])
    var closure = try #require(raw["closure"] as? [String: Any])
    closure["recipient"] = UUID().uuidString
    raw["closure"] = closure
    #expect(throws: (any Error).self) {
      try NativeRescueFuelEscrow.decodeClosed(JSONSerialization.data(withJSONObject: raw))
    }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: data(state, parent)) as? [String: Any])
    var instances = try #require(envelope["instances"] as? [String: Any])
    var child = try #require(instances[f.f.authorization.job.uuidString] as? [String: Any])
    var childLeaf = try #require(child["savedNativeCrewLog"] as? [String: Any])
    var receiving = try #require(childLeaf["rescueReception"] as? [String: Any])
    receiving["inventedCrew"] = true
    childLeaf["rescueReception"] = receiving
    child["savedNativeCrewLog"] = childLeaf
    instances[f.f.authorization.job.uuidString] = child
    envelope["instances"] = instances
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(
        JSONSerialization.data(withJSONObject: envelope),
        part: .missions, schema: 95)
    }
    #expect(NativeInductionArkSave.isAlien(94) && NativeInductionArkSave.isAlien(96))
  }
}
