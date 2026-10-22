import Foundation
import Testing

@testable import EliteCore

/// Structural route values only: no frame, jump, fuel debit or native admission is executed.
struct TargetTransitRouteUnitTests {
  private func fixture() throws -> (Game, SpaceBody, NativeWormholeLeg) {
    let game = Game(executive: false)
    let context = try #require(
      OriginalWorldJourneyContext.production(in: game, destinationWorld: "G01-S185"))
    let instance = UUID()
    let actor = UUID()
    let native = ActorIdentity(system: game.systemIdentity, visit: 1, entity: 2)
    var body = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 1000))
    body.missionInstanceID = instance
    body.missionActorID = actor
    var npc = NPCState(
      role: .mission, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.routeProvenance = .inferredLocal
    npc.cargoProvenance = .recorded
    npc.ordinaryCargo = [.init(commodity: .gold, quantity: 20)]
    body.physical = .init(identity: native, population: .mission, npc: npc)
    var leg = NativeWormholeLeg(
      id: NativeWormholeLeg.identity(instance: instance, actor: actor, request: "outbound"),
      instance: instance, actor: actor, encounter: "convoy", alias: "leader", request: "outbound",
      destinationWorld: context.route.destination.worldID, requestedAt: 0)
    leg.phase = .spooling
    leg.route = context.route
    leg.spooledAt = 0
    leg.spoolActor = native
    leg.spoolPhysicalTime = 0
    leg.driveComponent = UUID()
    leg.driveTerms = .init(
      component: "drive", rangeLightYears: 200, activationSeconds: 1, massLockScale: 1,
      fuelUnit: "native-light-years")
    try #require(leg.valid)
    return (game, body, leg)
  }
  private func opened(_ input: NativeWormholeLeg) throws -> NativeWormholeLeg {
    var leg = input
    let route = try #require(leg.route)
    leg.phase = .open
    leg.opening = .init(
      id: ScriptIdentity.uuid("native-wormhole-v1:\(leg.id)"), leg: leg.id, route: route,
      sourceActor: try #require(leg.spoolActor), entrance: ShipPose(), radius: 20,
      openedAt: 1, openedPhysicalTime: 1, expiresAt: 121)
    try #require(leg.valid)
    return leg
  }

  @Test func actualSpoolAndOpenEndpointsReplaceOnlyLocalRouteWithoutChangingCargoOrTier() throws {
    let (initialGame, body, leg) = try fixture()
    var game = initialGame
    let originalBody = body
    let before = game.commander
    for current in [leg, try opened(leg)] {
      game.commander.scriptState.wormholeTransit = .init(owner: UUID(), legs: [current.id: current])
      let retained = game.commander
      let facts = game.telemetryFacts(for: body)
      #expect(facts.origin == .init(identity: leg.route!.origin.location, provenance: .recorded))
      #expect(
        facts.destination == .init(identity: leg.route!.destination.location, provenance: .recorded)
      )
      #expect(facts.cargo == [.init(commodity: .gold, quantity: 20)])
      for tier in TargetingTier.allCases {
        let fields = TargetTelemetry.fields(
          facts: facts, tier: tier, targetIsShip: true, observerGalaxy: 0)
        #expect(fields.contains { $0.label == "Cargo" } == (tier >= .pirate))
        #expect(fields.contains { $0.label == "Origin" } == (tier >= .pirate))
        #expect(fields.contains { $0.label == "Destination" } == (tier >= .pirate))
        if tier >= .pirate {
          #expect(fields.first { $0.label == "Origin" }?.value == "Avenor")
          #expect(fields.first { $0.label == "Destination" }?.value == "Renas")
        }
      }
      #expect(game.commander == retained && body == originalBody)
    }
    var arrived = try opened(leg)
    let opening = try #require(arrived.opening)
    let route = try #require(arrived.route)
    arrived.departure = .init(
      hole: opening.id, nativeActor: opening.sourceActor, calendarSeconds: 2,
      physicalTime: 2, revision: 0, fuelBefore: route.distanceLightYears + 1,
      fuelAfter: 1, body: body)
    let arriving = ActorIdentity(system: route.destination.location, visit: 2, entity: 3)
    arrived.arrival = .init(nativeActor: arriving, calendarSeconds: try #require(arrived.dueAt))
    arrived.phase = .arrived
    var target = body
    target.physical = .init(identity: arriving, population: .mission, npc: body.physical?.npc)
    #expect(TargetTransitRouteProjection.route(for: target, legs: [arrived.id: arrived]) == route)
    #expect(game.commander.cargo == before.cargo && game.commander.fuel == before.fuel)
  }

  @Test func foreignActorInstanceVisitAmbiguityAndUnboundPhasesCannotSupplyRoute() throws {
    let (_, body, leg) = try fixture()
    var foreign = body
    foreign.missionActorID = UUID()
    #expect(TargetTransitRouteProjection.route(for: foreign, legs: [leg.id: leg]) == nil)
    foreign = body
    foreign.missionInstanceID = UUID()
    #expect(TargetTransitRouteProjection.route(for: foreign, legs: [leg.id: leg]) == nil)
    foreign = body
    foreign.physical = .init(
      identity: .init(system: leg.route!.origin.location, visit: 2, entity: 2),
      population: .mission, npc: body.physical?.npc)
    #expect(TargetTransitRouteProjection.route(for: foreign, legs: [leg.id: leg]) == nil)
    for phase in [
      NativeWormholeLeg.Phase.requested, .cancelled, .inTransit, .arrivalPending, .arrived,
    ] {
      var unbound = leg
      unbound.phase = phase
      #expect(TargetTransitRouteProjection.route(for: body, legs: [unbound.id: unbound]) == nil)
    }
    let other = NativeWormholeLeg(
      id: NativeWormholeLeg.identity(instance: leg.instance, actor: leg.actor, request: "second"),
      instance: leg.instance, actor: leg.actor, encounter: leg.encounter, alias: leg.alias,
      request: "second", destinationWorld: leg.destinationWorld, requestedAt: 0, phase: leg.phase,
      route: leg.route, spooledAt: leg.spooledAt, spoolActor: leg.spoolActor,
      spoolPhysicalTime: leg.spoolPhysicalTime, driveComponent: leg.driveComponent,
      driveTerms: leg.driveTerms)
    #expect(
      TargetTransitRouteProjection.route(for: body, legs: [leg.id: leg, other.id: other]) == nil)
  }

  @Test func explicitNPCProvenanceAndUnknownCargoRemainIndependentOfTransit() throws {
    let (initialGame, initialBody, leg) = try fixture()
    var game = initialGame
    var body = initialBody
    game.commander.scriptState.wormholeTransit = .init(owner: UUID(), legs: [leg.id: leg])
    for provenance in [NPCFactProvenance.recorded, .generated] {
      body.physical?.npc?.routeProvenance = provenance
      body.physical?.npc?.origin = .init(galaxy: 1, system: 9)
      body.physical?.npc?.destination = .init(galaxy: 1, system: Plugh.systemID)
      let facts = game.telemetryFacts(for: body)
      #expect(facts.origin?.identity == .init(galaxy: 1, system: 9))
      #expect(facts.destination?.identity == .init(galaxy: 1, system: Plugh.systemID))
      #expect(facts.cargo == [.init(commodity: .gold, quantity: 20)])
    }
    body.physical?.npc?.routeProvenance = nil
    body.physical?.npc?.cargoProvenance = nil
    #expect(game.telemetryFacts(for: body).destination?.identity == leg.route?.destination.location)
    #expect(game.telemetryFacts(for: body).cargo == nil)
    body.physical?.npc?.cargoProvenance = .recorded
    body.physical?.npc?.ordinaryCargo = []
    #expect(game.telemetryFacts(for: body).cargo == [])
    body.physical?.npc?.ordinaryCargo = [.init(commodity: .platinum, quantity: 5)]
    #expect(game.telemetryFacts(for: body).cargo == [.init(commodity: .platinum, quantity: 5)])
  }

  @Test func unavailableWorldAndMissingRouteKeepHonestLocalOrUnknownDisclosure() throws {
    var (game, body, leg) = try fixture()
    game.commander.scriptState.wormholeTransit = .init(owner: UUID(), legs: [leg.id: leg])
    game.commander.system = 8
    game.selectedSystem = 8
    let facts = game.telemetryFacts(for: body)
    #expect(facts.destination?.provenance == .inferredLocal)
    #expect(facts.destination?.identity == leg.route?.origin.location)
    leg.route = nil
    #expect(TargetTransitRouteProjection.route(for: body, legs: [leg.id: leg]) == nil)
    body.physical?.npc?.routeProvenance = nil
    #expect(game.telemetryFacts(for: body).origin == nil)
    #expect(game.telemetryFacts(for: body).destination == nil)
  }
}
