import Foundation
import Testing

@testable import EliteCore

private func openedCohort(_ fixture: NativeWormholeTransitFixture) throws
  -> (Game, [UUID], OriginalWorldJourneyContext)
{
  var (game, instance, context) = try fixture.game()
  let lead = try fixture.request(&game, instance: instance)
  let wing = try fixture.request(&game, instance: instance, alias: "wing")
  let ids = [lead, wing].sorted { $0.uuidString < $1.uuidString }
  for _ in 0..<100 {
    if ids.allSatisfy({ game.commander.scriptState.wormholeTransit?.legs[$0]?.opening != nil }) {
      break
    }
    try fixture.step(&game, context: context)
  }
  try #require(
    ids.allSatisfy { game.commander.scriptState.wormholeTransit?.legs[$0]?.opening != nil })
  return (game, ids, context)
}

private func approachAperture(_ id: UUID, game: inout Game, standOff: Double = 2) throws {
  let leg = try #require(game.commander.scriptState.wormholeTransit?.legs[id])
  let hole = try #require(leg.opening)
  let index = try #require(game.bodies.firstIndex { $0.missionActorID == leg.actor })
  let pose = game.commander.flightSimulation.pose
  // Explicit controlled crossing boundary; no receipt, identity, fuel or calendar is assigned.
  let point = hole.entrance.position + hole.entrance.orientation.z * standOff
  var forward = hole.entrance.orientation
  forward.x = forward.x * -1
  forward.z = forward.z * -1
  game.bodies[index].position = pose.shipPoint(point)
  game.bodies[index].orientation = forward.relative(to: pose.orientation)
  game.bodies[index].scriptNPC?.velocity = pose.shipVector(forward.z * 100)
  game.synchronizeScriptNPCPhysicalVelocities()
  game.persistScriptActors()
}

private func requireActualCrossings(
  _ ids: [UUID], sample: NativeWormholeMotionSample,
  game: borrowing Game
) throws {
  for id in ids {
    let leg = try #require(game.commander.scriptState.wormholeTransit?.legs[id])
    let hole = try #require(leg.opening)
    let before = try #require(sample.bodies.first { $0.missionActorID == leg.actor })
    let after = try #require(game.bodies.first { $0.missionActorID == leg.actor })
    let radius = try NativeWormholeSweep.radius(try #require(game.scriptNPCMesh(after)))
    try #require(
      NativeWormholeSweep.crosses(
        opening: hole,
        from: sample.pose.systemPoint(before.position),
        to: game.commander.flightSimulation.pose.systemPoint(after.position), hullRadius: radius))
  }
}

struct NativeWormholeCohortTests {
  @Test(arguments: [false, true])
  func sameFrameSeparatedCrossingsSurviveAnEarlierDetachOrRefusedPublication(refuseFirst: Bool)
    throws
  {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, ids, _) = try openedCohort(fixture)
    for id in ids { try approachAperture(id, game: &game) }
    let sample = try fixture.physicalStep(&game)
    try requireActualCrossings(ids, sample: sample, game: game)
    let before = game.commander
    let bodies = game.bodies
    let first = ids[0]
    let url = fixture.storage.url
    let publisher: ScriptPublisher = { candidate in
      if refuseFirst
        && candidate.commander.scriptState.wormholeTransit?.legs[first]?.departure != nil
      {
        throw SaveError.invalidCommander
      }
      try GameRuntime.writeCommander(&candidate, to: url)
    }
    game.advanceNativeWormholeFrame(from: sample, publish: publisher)
    for id in ids {
      let leg = try #require(game.commander.scriptState.wormholeTransit?.legs[id])
      if refuseFirst && id == first {
        #expect(leg.departure == nil && leg.phase == .open)
        #expect(
          game.bodies.first { $0.missionActorID == leg.actor }
            == bodies.first { $0.missionActorID == leg.actor })
      } else {
        let departure = try #require(leg.departure)
        let route = try #require(leg.route)
        #expect(departure.physicalTime == game.commander.flightSimulation.physicalTime)
        #expect(departure.nativeActor == leg.opening?.sourceActor)
        #expect(departure.fuelAfter == departure.fuelBefore - route.distanceLightYears)
        #expect(!game.bodies.contains { $0.missionActorID == leg.actor })
      }
    }
    #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
    #expect(
      game.commander.fuel == before.fuel
        && game.commander.scriptState.transitSeconds == before.scriptState.transitSeconds)
    #expect(game.commander.scriptState.calendarSeconds == before.scriptState.calendarSeconds)
    let departures = game.commander.scriptState.wormholeTransit?.legs.mapValues(\.departure)
    if refuseFirst {
      _ = try fixture.physicalStep(&game)
      game.advanceNativeWormholeFrame(from: sample, publish: fixture.publisher)
      // A previous frame's crossing cannot be consumed after a writer refusal.
      #expect(game.commander.scriptState.wormholeTransit?.legs.mapValues(\.departure) == departures)
    }
  }

  @Test func sameFramePlayerPassageUsesTheAttainedSceneBeforeAnotherWakeDetaches() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, ids, context) = try openedCohort(fixture)
    try approachAperture(ids[0], game: &game)
    // A second, spatially separated wake allows a concurrent player crossing without hull overlap.
    try approachAperture(ids[1], game: &game, standOff: 1500)
    let playerHole = try #require(game.commander.scriptState.wormholeTransit?.legs[ids[1]]?.opening)
    var pose = playerHole.entrance
    pose.position = pose.position + pose.orientation.z * 2
    pose.orientation.x = pose.orientation.x * -1
    pose.orientation.z = pose.orientation.z * -1
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = game.commander.performance.speed
    let sample = try fixture.physicalStep(&game)
    try requireActualCrossings([ids[0]], sample: sample, game: game)
    let radius = try NativeWormholeSweep.radius(game.commander.playerMesh)
    try #require(
      NativeWormholeSweep.crosses(
        opening: playerHole, from: sample.pose.position,
        to: game.commander.flightSimulation.pose.position, hullRadius: radius))
    let before = game.commander
    game.advanceNativeWormholeFrame(from: sample, publish: fixture.publisher)
    let departure = try #require(
      game.commander.scriptState.wormholeTransit?.legs[ids[0]]?.departure)
    let passage = try #require(
      game.commander.scriptState.wormholeTransit?.commanderPassages[playerHole.id])
    #expect(departure.physicalTime == before.flightSimulation.physicalTime)
    #expect(game.systemIdentity == context.route.destination.location)
    #expect(game.commander.fuel == before.fuel - passage.fuelDebit)
    #expect(
      game.commander.scriptState.transitSeconds == before.scriptState.transitSeconds
        + context.route.seconds)
    #expect(game.commander.credits == before.credits)
    #expect(game.commander.scriptState.wormholeTransit?.legs[ids[1]]?.departure == nil)
  }

  @Test func departureCannotBorrowAnotherActuallyAllocatedSourceAddress() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, ids, _) = try openedCohort(fixture)
    for id in ids { try approachAperture(id, game: &game) }
    let sample = try fixture.physicalStep(&game)
    try requireActualCrossings(ids, sample: sample, game: game)
    game.advanceNativeWormholeFrame(from: sample, publish: fixture.publisher)
    let original = try #require(game.commander.scriptState.wormholeTransit?.legs[ids[0]])
    let other = try #require(
      game.commander.scriptState.wormholeTransit?.legs[ids[1]]?.departure?.nativeActor)
    try #require(original.valid && other != original.opening?.sourceActor)
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    var departure = try #require(fields["departure"] as? [String: Any])
    var body = try #require(departure["body"] as? [String: Any])
    var physical = try #require(body["physical"] as? [String: Any])
    let address = try JSONSerialization.jsonObject(with: JSONEncoder().encode(other))
    departure["nativeActor"] = address
    physical["identity"] = address
    body["physical"] = physical
    departure["body"] = body
    fields["departure"] = departure
    let forged = try JSONDecoder().decode(
      NativeWormholeLeg.self,
      from: JSONSerialization.data(withJSONObject: fields))
    #expect(!forged.valid)
  }

  @Test func relocationRequiresTheLatestArrivalAndCannotLoseItsLocation() throws {
    let fixture = try NativeWormholeTransitFixture(edits: [("fuel = 7.0", "fuel = 400.0")])
    defer { fixture.storage.clean() }
    var (game, ids, _) = try openedCohort(fixture)
    for id in ids { try approachAperture(id, game: &game) }
    let sample = try fixture.physicalStep(&game)
    try requireActualCrossings(ids, sample: sample, game: game)
    game.advanceNativeWormholeFrame(from: sample, publish: fixture.publisher)
    var outbound = try #require(game.commander.scriptState.wormholeTransit?.legs[ids[0]])
    let route = try #require(outbound.route)
    let departure = try #require(outbound.departure)
    let terms = try #require(outbound.driveTerms)
    let firstDue = try #require(outbound.dueAt)

    // Constructed receipt-chain values exercise only the current-format validator. These
    // are never installed in Game, published, or offered to native admission as authority.
    let firstArrival = ActorIdentity(
      system: route.destination.location,
      visit: departure.nativeActor.visit + 1, entity: departure.nativeActor.entity)
    outbound.phase = .arrived
    outbound.arrival = .init(nativeActor: firstArrival, calendarSeconds: firstDue)
    let returnRoute = NativeWormholeRoute(
      catalogueRevision: route.catalogueRevision,
      origin: route.destination, destination: route.origin,
      distanceLightYears: route.distanceLightYears, exit: route.exit)
    let returnID = NativeWormholeLeg.identity(
      instance: outbound.instance,
      actor: outbound.actor, request: "return")
    let returnOpenedAt = firstDue + 2
    let returnOpening = NativeWormholeOpening(
      id: ScriptIdentity.uuid("native-wormhole-v1:\(returnID)"), leg: returnID,
      route: returnRoute, sourceActor: firstArrival, entrance: route.exit,
      radius: try #require(outbound.opening?.radius), openedAt: returnOpenedAt,
      openedPhysicalTime: departure.physicalTime + terms.activationSeconds + 2,
      expiresAt: returnOpenedAt + 120)
    var returnBody = departure.body
    returnBody.scriptNPC?.fuel = departure.fuelAfter - returnRoute.distanceLightYears
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(returnBody)) as? [String: Any])
    var physical = try #require(fields["physical"] as? [String: Any])
    physical["identity"] = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(firstArrival))
    fields["physical"] = physical
    returnBody = try JSONDecoder().decode(
      SpaceBody.self,
      from: JSONSerialization.data(withJSONObject: fields))
    var returning = NativeWormholeLeg(
      id: returnID, instance: outbound.instance,
      actor: outbound.actor, encounter: outbound.encounter, alias: outbound.alias,
      request: "return", destinationWorld: returnRoute.destination.worldID,
      requestedAt: firstDue + 1)
    returning.route = returnRoute
    returning.phase = .arrived
    returning.spooledAt = firstDue + 1
    returning.spoolPhysicalTime = departure.physicalTime + 1
    returning.spoolActor = firstArrival
    returning.driveComponent = outbound.driveComponent
    returning.driveTerms = terms
    returning.opening = returnOpening
    returning.departure = .init(
      hole: returnOpening.id, nativeActor: firstArrival,
      calendarSeconds: returnOpening.openedAt, physicalTime: returnOpening.openedPhysicalTime,
      revision: departure.revision, fuelBefore: departure.fuelAfter,
      fuelAfter: departure.fuelAfter - returnRoute.distanceLightYears, body: returnBody)
    let returnDue = try #require(returning.dueAt)
    returning.arrival = .init(
      nativeActor: .init(
        system: route.origin.location,
        visit: firstArrival.visit + 1, entity: firstArrival.entity), calendarSeconds: returnDue)
    try #require(outbound.valid && returning.valid)
    var state = game.commander.scriptState
    state.wormholeTransit?.legs[outbound.id] = outbound
    state.wormholeTransit?.legs[returnID] = returning
    state.calendarSeconds = returnDue
    var actor = try #require(
      state.instances[outbound.instance]?.ownedEncounters[outbound.encounter]?.actors[
        outbound.alias])
    actor.presence = .unloaded
    actor.body = returnBody
    actor.transitLocation = returnRoute.destination.location
    state.instances[outbound.instance]?.ownedEncounters[outbound.encounter]?.actors[
      outbound.alias] = actor
    try #require(state.nativeWormholeStateValid)
    actor.transitLocation = route.destination.location
    state.instances[outbound.instance]?.ownedEncounters[outbound.encounter]?.actors[
      outbound.alias] = actor
    #expect(!state.nativeWormholeStateValid)
    actor.transitLocation = nil
    state.instances[outbound.instance]?.ownedEncounters[outbound.encounter]?.actors[
      outbound.alias] = actor
    #expect(!state.nativeWormholeStateValid)
  }
}
