import Foundation
import Testing

@testable import EliteCore

struct NativeWormholeTransitTests {
  @Test(arguments: ["units", "component", "range", "activation", "capability", "calendar"])
  func closedDriveDeclarationRejectsMissingAuthorityOrUnresolvedUnits(field: String) throws {
    let edit: (String, String)
    switch field {
    case "units": edit = ("native-light-years", "source-unspecified")
    case "component": edit = ("component = \"drive\"", "component = \"missing\"")
    case "range": edit = ("rangeLightYears = 7.0", "rangeLightYears = -1.0")
    case "activation": edit = ("activationSeconds = 1.0", "activationSeconds = 0.0")
    case "capability": edit = ("\"npc-wormhole-transit-v2\", ", "")
    default: edit = ("\"mission-calendar-v2\", ", "")
    }
    #expect(throws: (any Error).self) { try NativeWormholeTransitFixture(edits: [edit]) }
  }

  @Test func unresolvedProductionWorldRemainsPendingWithoutFuelDebitOrDeparture() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, id, _) = try fixture.game()
    let legID = try fixture.request(&game, instance: id, destinationWorld: "Missing-world")
    let actor = try #require(game.commander.scriptState.wormholeTransit?.legs[legID]?.actor)
    let original = try #require(game.bodies.first { $0.missionActorID == actor })
    game.advanceNativeNPCTransit(from: nil, publish: fixture.publisher)
    let pending = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    #expect(pending.phase == .requested && pending.refusal == "worldUnavailable")
    #expect(pending.departure == nil && pending.opening == nil)
    #expect(game.bodies.first { $0.missionActorID == actor } == original)
    let same = try fixture.request(&game, instance: id, destinationWorld: "Missing-world")
    #expect(same == legID && game.commander.scriptState.wormholeTransit?.legs.count == 1)
    let beforeReads = game.commander
    let instance = try #require(game.commander.scriptState.instances[id])
    _ = game.nativeTransitQuery(instance)
    #expect(game.commander == beforeReads && game.commander.valid)
    #expect(game.commander.scriptState.transitSeconds == 0)
  }

  @Test(arguments: ["fuel", "component", "electrical", "mass-lock", "range", "wrong-world"])
  func actualSourceRechecksResourcesComponentAndActorRelativeMassLock(condition: String) throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, id, context) = try fixture.game()
    if condition == "range" {
      let far = try #require(
        game.systems.first {
          game.currentSystem.distance(to: $0) > 7 && game.currentSystem.distance(to: $0) <= 200
            && $0.id != Plugh.systemID
        })
      let world = try #require(far.original?.key)
      context = try #require(
        OriginalWorldJourneyContext.production(in: game, destinationWorld: world))
    }
    let legID = try fixture.request(
      &game, instance: id, destinationWorld: context.route.destination.worldID)
    let leg = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    let index = try #require(game.bodies.firstIndex { $0.missionActorID == leg.actor })
    switch condition {
    case "fuel": game.bodies[index].scriptNPC?.fuel = 0
    case "component": game.bodies[index].scriptNPC?.components["drive"]?.energy = 0
    case "electrical":
      let resources = try #require(game.bodies[index].physical?.npc?.resources)
      var reserve = try #require(
        ElectricalReserve(
          capacity: resources.energyCapacity,
          recharge: resources.electricalRecharge, at: game.commander.flightSimulation.physicalTime))
      let drained = reserve.drain(
        resources.energyCapacity, at: game.commander.flightSimulation.physicalTime)
      try #require(drained)
      game.bodies[index].physical?.npc?.resources?.electrical = reserve
    case "mass-lock":
      // Controlled actor-relative geometry boundary; move the player frame while retaining world actors.
      let point = game.commander.flightSimulation.pose.systemPoint(game.bodies[index].position)
      NativeStationTestFixture.reframe(&game, to: .init(position: point + .init(0, 0, 100)))
    case "range": break
    default:
      let route = context.route
      context = .init(
        route: .init(
          catalogueRevision: route.catalogueRevision,
          origin: .init(worldID: route.origin.worldID, galaxy: 1, system: route.origin.system),
          destination: .init(
            worldID: route.destination.worldID, galaxy: 1, system: route.destination.system),
          distanceLightYears: route.distanceLightYears, exit: route.exit))
    }
    let before = game.commander
    let bodies = game.bodies
    let expected: NativeWormholeRefusal
    switch condition {
    case "fuel": expected = .insufficientFuel
    case "component": expected = .driveUnavailable
    case "electrical": expected = .disabled
    case "mass-lock": expected = .massLocked
    case "range": expected = .outOfRange
    default: expected = .worldUnavailable
    }
    var refusal: NativeWormholeRefusal?
    do { _ = try NativeNPCDriveSource.resolve(in: game, leg: leg, context: context) } catch let
      error as NativeWormholeRefusal
    { refusal = error }
    #expect(refusal == expected)
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.commander.scriptState.wormholeTransit?.legs[legID]?.departure == nil)
  }

  @Test func openingAloneAndExpiredWakeDoNotDepartOrDebitTheActor() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, id, context) = try fixture.game()
    let legID = try fixture.request(&game, instance: id)
    for _ in 0..<100 {
      if game.commander.scriptState.wormholeTransit?.legs[legID]?.opening != nil { break }
      try fixture.step(&game, context: context)
    }
    let opened = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    let hole = try #require(opened.opening)
    #expect(opened.phase == .open && opened.departure == nil)
    let body = try #require(game.bodies.first { $0.missionActorID == opened.actor })
    #expect(body.scriptNPC?.fuel == 7)
    // Controlled expiry boundary, explicitly not a travelled duration or arrival receipt.
    game.commander.scriptState.calendarSeconds = hole.expiresAt + 0.1
    game.advanceNativeNPCTransit(from: nil, publish: fixture.publisher)
    let expired = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    #expect(expired.phase == .cancelled && expired.departure == nil && expired.arrival == nil)
    #expect(game.bodies.first { $0.missionActorID == opened.actor }?.scriptNPC?.fuel == 7)
    #expect(game.commander.scriptState.transitSeconds == 0 && game.commander.valid)
  }

  @Test func spoolPersistsAndCalendarCatchupCannotReplaceObservedDriveActivation() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, id, _) = try fixture.game()
    let legID = try fixture.request(&game, instance: id)
    game.advanceNativeNPCTransit(from: nil, publish: fixture.publisher)
    let spool = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    #expect(spool.phase == .spooling && spool.opening == nil)
    let loaded = try ScriptSaveStore.read(
      Data(contentsOf: fixture.storage.url), from: fixture.storage.url
    ).0
    #expect(loaded.scriptState.wormholeTransit?.legs[legID] == spool)
    // Controlled clock jump exercises refusal of calendar-only/offline spooling, not travel.
    game.commander.scriptState.calendarSeconds += 86400
    game.advanceNativeNPCTransit(from: nil, publish: fixture.publisher)
    let waiting = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    #expect(waiting.phase == .spooling && waiting.opening == nil && waiting.departure == nil)
    #expect(waiting.attempts == spool.attempts)
    #expect(
      waiting.spoolActor == spool.spoolActor && waiting.spoolPhysicalTime == spool.spoolPhysicalTime
    )
  }

  @Test func actualCrossingDebitsOnceAndFailedWriterKeepsTheAttainedSourceIntact() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, id, context) = try fixture.game()
    #expect(game.wayfarerInductionMission == nil && game.inductionCrewLogChild == nil)
    let legID = try fixture.request(&game, instance: id)
    for _ in 0..<100 {
      if game.commander.scriptState.wormholeTransit?.legs[legID]?.opening != nil { break }
      try fixture.step(&game, context: context)
    }
    let opened = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    let hole = try #require(opened.opening)
    let files = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    try fixture.storage.blockWriter()
    var crossed = false
    for _ in 0..<200 {
      let sample = try fixture.physicalStep(&game)
      let body = try #require(game.bodies.first { $0.missionActorID == opened.actor })
      let previous = try #require(sample.bodies.first { $0.missionActorID == opened.actor })
      let radius = try PreparedHull(mesh: try #require(game.scriptNPCMesh(body))).radius
      crossed = NativeWormholeSweep.crosses(
        opening: hole,
        from: sample.pose.systemPoint(previous.position),
        to: game.commander.flightSimulation.pose.systemPoint(body.position), hullRadius: radius)
      verifyRefusedTransit(&game, sample: sample, fixture: fixture)
      if crossed { break }
    }
    try #require(crossed)
    #expect(game.wayfarerInductionMission == nil && game.inductionCrewLogChild == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.backup) == files)
    try fixture.storage.restoreWriter()
    // A later accepted departure must come from new actual motion, not a forged removal.
    for _ in 0..<800 {
      if game.commander.scriptState.wormholeTransit?.legs[legID]?.departure != nil { break }
      try fixture.step(&game, context: context)
    }
    try verifyAcceptedDepartureAndPendingSave(
      &game, instance: id, legID: legID, distanceLightYears: context.route.distanceLightYears,
      fixture: fixture)
  }

  // The comparison owns its Commander snapshot only after this frame's physical step returns.
  @inline(never)
  private func verifyRefusedTransit(
    _ game: inout Game, sample: NativeWormholeMotionSample, fixture: NativeWormholeTransitFixture
  ) {
    let before = game.commander
    let physical = game.bodies
    game.advanceNativeNPCTransit(from: sample, publish: fixture.publisher)
    #expect(game.commander == before && game.bodies == physical)
  }

  // Keep later readback values out of the stack used for actual physical motion.
  @inline(never)
  private func verifyAcceptedDepartureAndPendingSave(
    _ game: inout Game, instance id: UUID, legID: UUID, distanceLightYears: Double,
    fixture: NativeWormholeTransitFixture
  ) throws {
    let departed = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    let receipt = try #require(departed.departure)
    #expect(
      departed.phase == .inTransit && receipt.fuelAfter == 7 - distanceLightYears)
    #expect(!game.bodies.contains { $0.missionActorID == departed.actor })
    let retained = try #require(
      game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors["lead"])
    #expect(retained.presence == .inTransit && retained.body == receipt.body)
    let instance = try #require(game.commander.scriptState.instances[id])
    let observed = game.scriptEncounterSnapshot(instance)
    #expect(
      observed.object?["opponents"]?.object?["actors"]?.object?["lead"]?.object?["position"]
        == .null)
    let same = try fixture.request(&game, instance: id)
    #expect(
      same == legID && game.commander.scriptState.wormholeTransit?.legs[legID]?.departure == receipt
    )
    try game.restoreScriptActors()
    #expect(!game.bodies.contains { $0.missionActorID == departed.actor })
    try GameRuntime.writeCommander(&game, to: fixture.storage.url)
    let loaded = try ScriptSaveStore.read(
      Data(contentsOf: fixture.storage.url), from: fixture.storage.url
    ).0
    #expect(loaded.scriptState.wormholeTransit == game.commander.scriptState.wormholeTransit)
    #expect(loaded.scriptState.nativeWormholeStateValid && loaded.valid)
    #expect(loaded.scriptState.transitSeconds == 0)
    // A due-time boundary with the destination still unloaded must retain pending custody.
    // This assigned test clock is not an arrival and creates no commander transit time.
    game.commander.scriptState.calendarSeconds = try #require(departed.dueAt) + 1
    game.advanceNativeNPCTransit(from: nil, publish: fixture.publisher)
    let pending = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    #expect(
      pending.phase == .arrivalPending && pending.arrival == nil && pending.departure == receipt)
    let restored = try ScriptSaveStore.read(
      Data(contentsOf: fixture.storage.url), from: fixture.storage.url
    ).0
    #expect(restored.scriptState.wormholeTransit == game.commander.scriptState.wormholeTransit)
    #expect(restored.scriptState.transitSeconds == 0 && restored.valid)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(pending)) as? [String: Any])
    var forgedDeparture = try #require(object["departure"] as? [String: Any])
    forgedDeparture["fuelAfter"] = receipt.fuelAfter + 1
    object["departure"] = forgedDeparture
    let forged = try JSONDecoder().decode(
      NativeWormholeLeg.self,
      from: JSONSerialization.data(withJSONObject: object))
    #expect(!forged.valid)
  }

  @Test func controlledModuleLossInterruptsTheObservedSpoolWithoutBankingActivation() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, id, _) = try fixture.game()
    let legID = try fixture.request(&game, instance: id)
    game.advanceNativeNPCTransit(from: nil, publish: fixture.publisher)
    let spool = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    try #require(spool.phase == .spooling)
    let index = try #require(game.bodies.firstIndex { $0.missionActorID == spool.actor })
    // Controlled component-loss boundary, not a claimed native weapon-hit acceptance test.
    game.bodies[index].scriptNPC?.components["drive"]?.energy = 0
    _ = try fixture.physicalStep(&game)
    let interrupted = try #require(game.commander.scriptState.wormholeTransit?.legs[legID])
    #expect(interrupted.phase == .requested && interrupted.refusal == "driveUnavailable")
    #expect(interrupted.spoolActor == nil && interrupted.spoolPhysicalTime == nil)
    #expect(interrupted.opening == nil && interrupted.departure == nil)
    #expect(game.bodies[index].scriptNPC?.fuel == 7 && game.commander.valid)
  }

  @Test func physicalPlayerWakeEntryRejoinsSameSurvivorsAndAdvancesGlobalTransitOnlyOnce() throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    var (game, id, context) = try fixture.game()
    let lead = try fixture.request(&game, instance: id)
    let wing = try fixture.request(&game, instance: id, alias: "wing")
    for _ in 0..<400 {
      if [lead, wing].allSatisfy({
        game.commander.scriptState.wormholeTransit?.legs[$0]?.departure != nil
      }) {
        break
      }
      try fixture.step(&game, context: context)
    }
    let departed = try #require(game.commander.scriptState.wormholeTransit?.legs[lead])
    let wingDeparture = try #require(
      game.commander.scriptState.wormholeTransit?.legs[wing]?.departure)
    let original = try #require(departed.departure)
    let hole = try #require(departed.opening)
    #expect(
      game.commander.scriptState.transitSeconds == 0
        && wingDeparture.fuelAfter < wingDeparture.fuelBefore)
    #expect(game.commander.scriptState.instances[id]?.data.object?["transitPulses"] == .integer(0))
    // Controlled visible-aperture entry boundary. Actual native flight, crossing, fuel, visit,
    // destination admission and calendar follow; this is not a flown route from the station.
    var approach = hole.entrance
    approach.position = hole.entrance.position + hole.entrance.orientation.z * (hole.radius + 100)
    approach.orientation.x = approach.orientation.x * -1
    approach.orientation.z = approach.orientation.z * -1
    NativeStationTestFixture.reframe(&game, to: approach)
    game.speed = game.commander.performance.speed
    let cash = game.commander.credits
    let fuel = game.commander.fuel
    let beforeTransit = game.commander.scriptState.transitSeconds
    for _ in 0..<100 {
      if game.systemIdentity == context.route.destination.location { break }
      try fixture.step(&game, context: context)
    }
    try #require(game.systemIdentity == context.route.destination.location)
    let passage = try #require(
      game.commander.scriptState.wormholeTransit?.commanderPassages[hole.id])
    #expect(game.commander.scriptState.transitSeconds == beforeTransit + context.route.seconds)
    #expect(game.commander.fuel == fuel - passage.fuelDebit && game.commander.credits == cash)
    for _ in 0..<300 {
      if [lead, wing].allSatisfy({
        game.commander.scriptState.wormholeTransit?.legs[$0]?.arrival != nil
      }) {
        break
      }
      try fixture.step(&game, context: context)
    }
    let arrived = try #require(game.commander.scriptState.wormholeTransit?.legs[lead]?.arrival)
    let survivor = try #require(game.bodies.first { $0.missionActorID == departed.actor })
    #expect(
      survivor.physical?.identity == arrived.nativeActor
        && arrived.nativeActor != original.nativeActor)
    #expect(
      survivor.scriptNPC?.fuel == original.fuelAfter && survivor.missiles == original.body.missiles)
    #expect(survivor.scriptNPC?.fit == original.body.scriptNPC?.fit)
    #expect(survivor.scriptNPC?.components == original.body.scriptNPC?.components)
    #expect(survivor.physical?.npc?.ordinaryCargo == original.body.physical?.npc?.ordinaryCargo)
    #expect(game.commander.scriptState.wormholeTransit?.legs[wing]?.arrival != nil)
    #expect(game.commander.scriptState.transitSeconds == context.route.seconds)
    #expect(game.commander.scriptState.instances[id]?.data.object?["transitPulses"] == .integer(1))
    #expect(
      game.commander.credits == cash && game.commander.scriptState.instances[id]?.outcome == .active
    )
    #expect(game.commander.nativeStations?.currentMainDock == nil && game.commander.valid)
    let before = game.commander
    game.advanceNativeCommanderWakeEntry(from: nil, publish: fixture.publisher)
    #expect(game.commander == before)
    let completed = try #require(game.commander.scriptState.wormholeTransit?.legs[lead])
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(completed)) as? [String: Any])
    var arrival = try #require(object["arrival"] as? [String: Any])
    var address = try #require(arrival["nativeActor"] as? [String: Any])
    address["visit"] = game.commander.flightSimulation.visit + 1
    arrival["nativeActor"] = address
    object["arrival"] = arrival
    let future = try JSONDecoder().decode(
      NativeWormholeLeg.self,
      from: JSONSerialization.data(withJSONObject: object))
    var forged = game.commander
    forged.scriptState.wormholeTransit?.legs[lead] = future
    #expect(!forged.nativeWormholeHistoryValid && !forged.valid)
  }
}
