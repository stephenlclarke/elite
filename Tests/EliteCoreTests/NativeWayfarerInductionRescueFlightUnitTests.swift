import Foundation
import Testing

@testable import EliteCore

/// Typed native-ledger records only; no fixture executes a departure, arrival or flight journey.
private struct RescueFlightFixture {
  let f: RescueFinanceFixture
  let authorization: NativeRescueFlightAuthorization
  init(fuel: Double = 13) throws {
    let f = try RescueFinanceFixture(legacy: true)
    self.f = f
    let root = f.state.authorization
    let capture = try #require(f.state.capture)
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: root.manifest.owner, system: 211, visit: 32, sequence: 32)
    let route = try NativeRescueRoutePlan(source: f.f.source, escortReachLY: 7)
    let operation = try NativeRescueFlightAuthorization.identity(
      registration: root.operation,
      funding: f.funding.issue, capture: capture.operation, dock: dock, carrier: capture.carrier,
      revision: 1, physicalTime: 20_003, flightSeconds: 10_002, calendarSeconds: 100_002,
      initialFuel: fuel, sequence: 103, route: route)
    authorization = .init(
      registration: root.operation, funding: f.funding.issue,
      capture: capture.operation, job: root.job,
      actor: NativeInductionCrewLogPack.actor(job: root.job, role: .launch),
      operation: operation, sequence: 103, dock: dock, carrier: capture.carrier,
      inventoryRevision: 1, physicalTime: 20_003, flightSeconds: 10_002,
      calendarSeconds: 100_002, initialFuelLY: fuel, crew: root.manifest.crew, route: route)
  }
  func state() -> NativeInductionCrewLogState {
    var state = f.state
    state.flight = .init(authorization: authorization)
    return state
  }
  func reference(hop: Int = 0, attempt: Int = 0) -> NativeRescueHopReference {
    let request = "native-rescue-hop-\(hop)-\(attempt)"
    return .init(
      hop: hop, attempt: attempt,
      leg: NativeWormholeLeg.identity(
        instance: authorization.job, actor: authorization.actor, request: request))
  }
  func departure() throws -> (NativeRescueHopReference, NativeWormholeLeg, ScriptOwnedActor) {
    let reference = reference()
    let plan = authorization.route
    let catalogue = Universe.originalWorlds
    let worlds = Universe.galaxy()
    let origin = try catalogue.world(key: plan.worldKeys[0])
    let destination = try catalogue.world(key: plan.worldKeys[1])
    var exit = FlightSimulationState()
    exit.enter(.init(galaxy: 0, system: destination.system), arriving: true)
    let route = NativeWormholeRoute(
      catalogueRevision: plan.catalogueRevision,
      origin: .init(worldID: origin.key, galaxy: 0, system: worlds[origin.system]),
      destination: .init(worldID: destination.key, galaxy: 0, system: worlds[destination.system]),
      distanceLightYears: plan.distancesLY[0], exit: exit.pose)
    let native = ActorIdentity(system: route.origin.location, visit: 32, entity: 3)
    var actor = try f.f.prepared(.launch)
    actor.body.id = 43
    actor.body.physical = .init(
      identity: native, population: .mission,
      npc: .init(
        role: .mission, origin: route.origin.location, destination: route.destination.location))
    actor.body.scriptNPC?.fuel = authorization.initialFuelLY - route.distanceLightYears
    let opening = NativeWormholeOpening(
      id: ScriptIdentity.uuid("native-wormhole-v1:\(reference.leg)"),
      leg: reference.leg, route: route, sourceActor: native,
      entrance: .init(position: .init(0, 0, 500)), radius: 100,
      openedAt: 200_000, openedPhysicalTime: 50_000, expiresAt: 200_120)
    var leg = NativeWormholeLeg(
      id: reference.leg, instance: authorization.job,
      actor: authorization.actor, encounter: NativeInductionCrewLogPack.encounter,
      alias: "launch", request: reference.request, destinationWorld: destination.key,
      requestedAt: 199_980)
    leg.route = route
    leg.spooledAt = 199_988
    leg.spoolActor = native
    leg.spoolPhysicalTime = 49_988
    leg.driveComponent = actor.body.scriptNPC?.components["drive"]?.identity
    leg.driveTerms = f.f.source.ship.drive
    leg.opening = opening
    leg.departure = .init(
      hole: opening.id, nativeActor: native,
      calendarSeconds: 200_001, physicalTime: 50_001, revision: 1,
      fuelBefore: authorization.initialFuelLY,
      fuelAfter: authorization.initialFuelLY - route.distanceLightYears, body: actor.body)
    leg.phase = .inTransit
    actor.presence = .inTransit
    try #require(leg.valid)
    return (reference, leg, actor)
  }
}

struct NativeWayfarerInductionRescueFlightUnitTests {
  @Test func routeConsentBindsTheSameOriginalPeopleFundingAndCapturedRetainedFuelWithoutProgress()
    throws
  {
    let f = try RescueFlightFixture(fuel: 6)
    let state = f.state()
    #expect(state.shapeValid(parent: f.f.parent))
    #expect(f.authorization.initialFuelLY == 6 && f.authorization.route.tankCapacityLY == 13)
    #expect(f.authorization.crew == f.f.f.source.manifest.crew && f.authorization.crew.count == 2)
    #expect(
      f.f.parent.milestones == [0, 1, 2, 3, 4, 5, 6, 7] && !f.f.parent.milestones.contains(8))
    #expect(f.f.parent.payloads == [NativeWayfarerInduction.crewLogPayload: 1])
    #expect(
      state.rescueFuel?.remainingCredits == 10_000 && state.rescueFuel?.purchases.isEmpty == true)
    let foreign = try RescueFlightFixture()
    #expect(
      !f.authorization.valid(
        root: foreign.f.state.authorization, funding: foreign.f.funding,
        parent: foreign.f.parent, source: foreign.f.f.source))
    let invalid = try RescueFlightFixture(fuel: 13.1)
    #expect(!invalid.state().shapeValid(parent: invalid.f.parent))
    let restored = try JSONDecoder().decode(
      NativeInductionCrewLogState.self, from: JSONEncoder().encode(state))
    #expect(restored == state && restored.flight?.authorization.initialFuelLY == 6)
  }

  @Test func hopReferencesAreOriginalJobBoundAndSequentialWithBoundedRetryRatherThanTeleport()
    throws
  {
    let f = try RescueFlightFixture()
    var flight = try #require(f.state().flight)
    flight.legs = [f.reference()]
    #expect(
      flight.shapeValid(
        root: f.f.state.authorization, funding: f.f.funding, parent: f.f.parent,
        source: f.f.f.source))
    flight.legs.append(f.reference(attempt: 1))
    #expect(
      flight.shapeValid(
        root: f.f.state.authorization, funding: f.f.funding, parent: f.f.parent,
        source: f.f.f.source))
    #expect(!f.reference(attempt: 128).valid(authorization: f.authorization))
    #expect(!f.reference(hop: -1).valid(authorization: f.authorization))
    flight.legs = [f.reference(attempt: 1)]
    #expect(
      !flight.shapeValid(
        root: f.f.state.authorization, funding: f.f.funding, parent: f.f.parent,
        source: f.f.f.source))
    let foreign = try RescueFlightFixture()
    #expect(!f.reference().valid(authorization: foreign.authorization))
  }

  @Test func actualOwnedDepartureReferenceSpendsExactlyCapturedFuelAndCannotInventAnotherLeg()
    throws
  {
    let f = try RescueFlightFixture()
    let (reference, leg, actor) = try f.departure()
    var flight = try #require(f.state().flight)
    flight.legs = [reference]
    var engine = ScriptEngineState()
    engine.wormholeTransit = .init(owner: f.f.f.source.manifest.owner)
    engine.wormholeTransit?.legs[leg.id] = leg
    #expect(
      NativeRescueFlightSave.legsValid(flight, source: f.f.f.source, actor: actor, engine: engine))
    var altered = actor
    altered.body.scriptNPC?.fuel = 13
    #expect(
      !NativeRescueFlightSave.legsValid(
        flight, source: f.f.f.source, actor: altered, engine: engine))
    engine.wormholeTransit?.legs[leg.id] = nil
    #expect(
      !NativeRescueFlightSave.legsValid(flight, source: f.f.f.source, actor: actor, engine: engine))
  }

  @Test func movingOrRelocatedLaunchNeedsItsOwnActualTransitAndCannotUseAnArrivalMarker() throws {
    let f = try RescueFlightFixture()
    let (reference, leg, actor) = try f.departure()
    var flight = try #require(f.state().flight)
    flight.legs = [reference]
    var commander = try f.f.commander()
    commander.flightSimulation.enter(NativeInductionCrewLogSource.location, arriving: true)
    commander.scriptState.wormholeTransit = .init(owner: f.f.f.source.manifest.owner)
    commander.scriptState.wormholeTransit?.legs[leg.id] = leg
    #expect(
      NativeRescueFlightSave.actorValid(
        actor, flight: flight, root: f.f.state.authorization, commander: commander))
    var relocated = actor
    relocated.transitLocation = leg.route?.destination.location
    #expect(
      !NativeRescueFlightSave.actorValid(
        relocated, flight: flight, root: f.f.state.authorization, commander: commander))
    commander.scriptState.wormholeTransit?.legs[leg.id] = nil
    #expect(
      !NativeRescueFlightSave.actorValid(
        actor, flight: flight, root: f.f.state.authorization, commander: commander))
    var cleared = try f.f.f.prepared(.launch)
    cleared.presence = .present
    cleared.body.id = 43
    cleared.body.physical = .init(
      identity: f.f.f.admission.launch, population: .mission,
      npc: .init(
        role: .mission, origin: NativeInductionCrewLogSource.location,
        destination: NativeInductionCrewLogSource.receiver))
    cleared.body.scriptNPC?.intent = .init(
      request: "native-rescue-workarea-exit", mode: .approach,
      target: nil, player: false,
      offset: NativeInductionCrewLogRole.launch.offset + Vector3(0, 0, 1200),
      speed: min(1, 144 / f.f.f.source.ship.speed), tolerance: 50)
    flight.legs = []
    #expect(
      NativeRescueFlightSave.actorValid(
        cleared, flight: flight, root: f.f.state.authorization, commander: commander))
    cleared.body.scriptNPC?.intent = .init(
      request: "native-rescue-workarea-exit", mode: .approach,
      target: nil, player: false, offset: .init(0, 0, 0),
      speed: min(1, 144 / f.f.f.source.ship.speed), tolerance: 50)
    #expect(
      !NativeRescueFlightSave.actorValid(
        cleared, flight: flight, root: f.f.state.authorization, commander: commander))
  }

  @Test func realLaunchLossAlongTheAuthoredRouteKeepsOriginalCrewLostAndRecorderHistoryHeld() throws
  {
    let f = try RescueFlightFixture()
    var state = f.state()
    let world = try Universe.originalWorlds.world(key: f.authorization.route.worldKeys[1])
    let loss = NativeCrewLogActorLoss(
      role: "launch",
      actor: .init(system: .init(galaxy: world.galaxy, system: world.system), visit: 33, entity: 3),
      physicalTime: 50_003)
    state.losses = [loss]
    #expect(state.shapeValid(parent: f.f.parent) && state.livingCrew.isEmpty)
    #expect(state.authorization.manifest.crew.count == 2 && state.capture == f.f.parent.crewLog)
    #expect(f.f.parent.payloads == [NativeWayfarerInduction.crewLogPayload: 1])
    #expect(f.f.parent.milestones == [0, 1, 2, 3, 4, 5, 6, 7])
    var withoutRoute = f.f.state
    withoutRoute.losses = [loss]
    #expect(!withoutRoute.shapeValid(parent: f.f.parent))
  }

  @Test func closedFlightEnvelopeRetainsEarlierFundingButRefusesEarlyForeignOrUnknownTravel() throws
  {
    let f = try RescueFlightFixture()
    let leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.state())) as? [String: Any])
    func bytes(_ leaf: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.authorization.job.uuidString: [
            "definition": NativeInductionCrewLogPack.stateID,
            "digest": NativeInductionCrewLogPack.digest,
            "savedNativeCrewLog": leaf,
          ]
        ]
      ])
    }
    for schema in [91, 92] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        bytes(leaf), part: .missions, schema: schema)
    }
    for schema in [85, 86, 87, 88, 89, 90, Int.max] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes(leaf), part: .missions, schema: schema)
      }
    }
    var old = leaf
    old["flight"] = nil
    for schema in [89, 90, 91, 92] {
      try NativeInductionCrewLogSave.validateFields(bytes(old), part: .missions, schema: schema)
    }
    var altered = leaf
    var flight = try #require(altered["flight"] as? [String: Any])
    flight["fabricatedArrival"] = true
    altered["flight"] = flight
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(bytes(altered), part: .missions, schema: 91)
    }
    #expect(NativeInductionArkSave.isAlien(90) && NativeInductionArkSave.isAlien(92))
  }
}
