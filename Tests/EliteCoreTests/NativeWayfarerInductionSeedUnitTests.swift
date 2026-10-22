import Foundation
import Testing

@testable import EliteCore

/// Three-operator ownership, custody and native timer receipts only; no native journey is executed.
final class InductionSeedFixture {
  let f: InductionWorkshopFixture
  let signature: NativeInductionCharterSignature
  let issue: NativeInductionSeedIssue
  let source: NativeInductionSeedSource
  let available: NativeWayfarerInductionState
  let quote: NativeInductionSeedQuote
  let booking: NativeInductionSeedBooking
  let held: NativeWayfarerInductionState
  let custody: NativeInductionSeedCustody
  init() throws {
    f = try .init()
    let capacity = try #require(f.held.charterCapacity)
    signature = try f.f.f.f.signature(
      .seed, capacity: capacity, sequence: 230,
      time: 1_000_230, flightSeconds: 900_230)
    let signed = try f.held.recordingCharterConsent(signature)
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionSeedIssue.identity(
      consent: signature.operation,
      allocation: capacity.allocation.operation, revision: capacity.revision,
      fingerprint: fingerprint,
      dock: signature.dock, carrier: f.booking.carrier, fit: 1, time: 1_000_240,
      flightSeconds: 900_240, sequence: 240)
    issue = .init(
      operation: operation, sequence: 240, parent: f.booking.parent,
      commanderOwner: f.booking.commanderOwner, operatorOwner: signature.operatorOwner,
      epoch: signature.epoch, policy: signature.policy, consent: signature.operation,
      allocation: capacity.allocation.operation, capacityRevision: capacity.revision,
      capacityFingerprint: fingerprint, family: NativeInductionSeedPack.stateID,
      familyVersion: NativeInductionSeedPack.version, familyDigest: NativeInductionSeedPack.digest,
      profile: .original, dock: signature.dock, carrier: f.booking.carrier,
      inventoryRevision: 1, physicalTime: 1_000_240, flightSeconds: 900_240)
    source = try .init(issue: issue, parent: signed)
    let issued = try signed.issuingSeedBatch(source)
    let release = try f.f.f.f.release(
      signature, capacity: capacity, sequence: 241,
      time: 1_000_241, flightSeconds: 900_241)
    available = try issued.releasingCharterUnit(release)
    quote = try .prepare(
      source: source, parent: available, unit: source.units[0].id,
      scope: .ownerStation, dock: issue.dock, carrier: issue.carrier, revision: 1,
      runtimeEpoch: ScriptIdentity.uuid("original-seed-unit-runtime"), firstReachLY: 7,
      fullReachLY: 7)
    let before = try #require(available.charterCapacity)
    let instance = NativeInductionSeedBooking.instance(
      source: source.identity, unit: source.units[0].id, revision: 0)
    let window = try before.quote(consignment: instance, unit: release.unit)
    let acceptance = try NativeInductionSeedBooking.identity(
      instance: instance, offer: quote.offer.id,
      window: window.operation, dock: quote.dock, carrier: quote.carrier, fit: 1,
      time: 1_000_250, flightSeconds: 900_250, sequence: 250)
    booking = .init(
      operation: acceptance, instance: instance, sequence: 250, parent: issue.parent,
      commanderOwner: issue.commanderOwner, operatorOwner: issue.operatorOwner,
      source: source.identity, issue: issue.operation, unit: source.units[0].id,
      epoch: issue.epoch, familyDigest: issue.familyDigest, offer: quote.offer.id, stockRevision: 0,
      window: window, route: quote.route, terms: quote.terms, dock: quote.dock,
      carrier: quote.carrier,
      inventoryRevision: 1, runtimeEpoch: quote.runtimeEpoch, physicalTime: 1_000_250,
      flightSeconds: 900_250)
    held = try available.updatingSeed(
      source.applying(NativeInductionSeedSave.stockEvent(booking)),
      capacity: before.reserving(window))
    let contact = WayfarerColdChainContact(
      sequence: 260, dock: issue.dock,
      context: Self.context(dock: issue.dock, clock: 900_260, revision: 0))
    let pickupOperation = try NativeInductionSeedPickup.identity(
      booking: booking.operation,
      contact: contact, carrier: booking.carrier, fit: 1, time: 1_000_260)
    let pickup = NativeInductionSeedPickup(
      operation: pickupOperation, booking: booking.operation,
      contact: contact, carrier: booking.carrier, inventoryRevision: 1, physicalTime: 1_000_260)
    let timer = ScriptTimer(
      id: NativeInductionSeedCustody.timerID, domain: .flight,
      due: 907_460, interval: 0, policy: .once)
    let binding = WayfarerColdChainBinding(
      owner: booking.commanderOwner, instance: booking.instance,
      consignment: booking.unit,
      receiver: Game.worldResourceIdentity("main-station-v1:" + booking.terms.receiver.resourceKey),
      timerID: timer.id)
    custody = .init(
      pickup: pickup, timer: timer,
      integrity: try WayfarerColdChain(
        snapshot: .init(binding: binding, timer: timer, context: contact.context), allowance: 7200,
        issueSequence: 260))
  }
  static func context(dock: NativeMainStationDockReceipt? = nil, clock: Double, revision: UInt64)
    -> ScriptEventContext
  {
    var context = ScriptEventContext(
      galaxy: 0, system: dock?.station.system.system ?? 162,
      docked: dock != nil, mainStation: dock != nil, revision: revision,
      frameSeconds: clock, localSeconds: clock, flightSeconds: clock,
      calendarSeconds: clock + 100_000, transitSeconds: 0, playerPosition: nil)
    context.nativeMainDock = dock
    return context
  }
  func dock(_ system: Int, sequence: UInt64, visit: UInt64) -> NativeMainStationDockReceipt {
    NativeWayfarerInductionUnitTests().dock(
      owner: booking.commanderOwner, system: system, visit: visit, sequence: sequence)
  }
  var receiver: NativeMainStationDockReceipt {
    dock(91, sequence: 108, visit: issue.dock.actor.visit + 1)
  }
  var returned: NativeMainStationDockReceipt {
    dock(162, sequence: 109, visit: issue.dock.actor.visit + 2)
  }
  func child(
    custody: NativeInductionSeedCustody? = nil, close: NativeInductionSeedUncollectedClose? = nil
  ) -> ScriptInstance {
    var child = ScriptInstance(
      id: booking.instance, definition: NativeInductionSeedPack.stateID,
      version: NativeInductionSeedPack.version, digest: NativeInductionSeedPack.digest)
    let contract = NativeInductionSeedContract(booking: booking, close: close, custody: custody)
    child.savedNativeInductionSeed = contract
    child.outcome = contract.outcome
    child.acknowledge(250)
    if let custody {
      child.payloads = [NativeInductionSeedCustody.payload: 3]
      child.timers = [custody.timer.id: custody.timer]
      child.revision = 1
      child.acknowledge(260)
      if let cancellation = custody.cancellation {
        child.revision += 1
        child.acknowledge(cancellation.contact.sequence)
      }
    }
    if let close { child.acknowledge(close.sequence) }
    return child
  }
  func commander(custody: NativeInductionSeedCustody? = nil, clock: Double = 900_500) throws
    -> Commander
  {
    var commander = try f.commander(.init(booking: f.booking))
    while commander.flightSimulation.visit < returned.actor.visit {
      commander.flightSimulation.enter(returned.actor.system, arriving: true)
    }
    commander.flightSimulation.physicalTime = 2_000_000
    commander.scriptState.localSeconds = 950_000
    commander.scriptState.flightSeconds = clock
    commander.scriptState.calendarSeconds = 2_000_000
    commander.scriptState.nextEvent = 299
    for station in [issue.dock.station, receiver.station]
    where commander.nativeStations?.mainStations.contains(station) != true {
      commander.nativeStations?.mainStations.append(station)
    }
    commander.nativeStations?.nextMainDockSequence = 111
    commander.scriptState.instances[issue.parent]?.savedWayfarerInduction = held
    commander.scriptState.instances[issue.parent]?.acknowledge(280)
    commander.scriptState.instances[booking.instance] = child(custody: custody)
    return commander
  }
  /// Full parent-save callers retain the exact original sale and historical receiving stations.
  func restoreOriginalParentSaveClaims(_ commander: inout Commander) throws {
    let sale = f.f.f.f.f.f.work.f.originalSale
    guard held.permission.trade == .sale(sale.operation), sale.owner == held.permission.owner,
      sale.valid,
      let state = commander.scriptState.instances[held.permission.mission]?.savedWayfarerInduction
    else { throw SaveError.invalidCommander }
    commander.scriptState.firstNativeCommoditySale = sale
    var docks = [state.permission.dock]
    docks += [
      state.crate?.dock, state.reception?.dock, state.cassette?.dock,
      state.cassetteService?.dock, state.seedKey?.dock, state.seedReception?.playerDock,
      state.rescueReception?.playerDock, state.utilityReception?.dock,
      state.charterChoice?.dock, state.charterClinicSource?.issue.dock,
      state.charterWorkshopSource?.issue.dock, state.charterSeedSource?.issue.dock,
    ].compactMap { $0 }
    for dock in docks where commander.nativeStations?.mainStations.contains(dock.station) != true {
      commander.nativeStations?.mainStations.append(dock.station)
    }
  }
  /// Complete-network callers keep the same original received crew and repaired utility records.
  func restoreOriginalNetworkChildren(_ commander: inout Commander) throws {
    let work = f.f.f.f.f.f.work
    let utility = work.f
    let rescue = utility.receivingFixture
    let parent = try #require(
      commander.scriptState.instances[held.permission.mission]?.savedWayfarerInduction)
    let received = try #require(parent.rescueReception)
    let utilityReceived = try #require(parent.utilityReception)
    var crew = try #require(rescue.f.f.commander().scriptState.instances[received.job])
    var crewState = try rescue.state(receipt: received)
    let legs = try rescue.routeLegs()
    crewState.flight?.legs = legs.map(\.0)
    if commander.scriptState.wormholeTransit == nil {
      commander.scriptState.wormholeTransit = .init(owner: parent.permission.owner)
    }
    var fuel = rescue.f.authorization.initialFuelLY
    for (_, originalLeg) in legs {
      var leg = originalLeg
      let departure = try #require(leg.departure)
      let route = try #require(leg.route)
      let after = fuel - route.distanceLightYears
      try #require(after >= 0)
      var body = departure.body
      body.scriptNPC?.fuel = after
      leg.departure = .init(
        hole: departure.hole, nativeActor: departure.nativeActor,
        calendarSeconds: departure.calendarSeconds, physicalTime: departure.physicalTime,
        revision: departure.revision, fuelBefore: fuel, fuelAfter: after, body: body)
      try #require(leg.valid)
      commander.scriptState.wormholeTransit?.legs[leg.id] = leg
      fuel = after
    }
    let encounter = NativeInductionCrewLogPack.encounter
    var group = try #require(crew.ownedEncounters[encounter])
    var launch = try #require(group.actors["launch"])
    launch.presence = .unloaded
    launch.transitLocation = rescue.contact.station.system
    launch.body.physical = .init(
      identity: rescue.contact.arkActor, population: .mission,
      npc: .init(
        role: .mission, origin: NativeInductionCrewLogSource.location,
        destination: NativeInductionCrewLogSource.receiver))
    launch.body.scriptNPC?.fuel = fuel
    launch.body.scriptNPC?.velocity = .init(0, 0, 0)
    launch.body.scriptNPC?.intent = nil
    group.actors["launch"] = launch
    crew.ownedEncounters[encounter] = group
    crew.savedNativeCrewLog = crewState
    crew.revision = 1000
    crew.milestones = [0, 1]
    crew.acknowledge(received.sequence)
    commander.scriptState.instances[crew.id] = crew
    if commander.nativeStations?.mainStations.contains(rescue.f.authorization.dock.station) != true
    {
      commander.nativeStations?.mainStations.append(rescue.f.authorization.dock.station)
    }
    var utilityState = try work.state()
    utilityState.receiving = utilityReceived
    var child = utility.child()
    child.savedNativeInductionUtility = utilityState
    child.revision = 1000
    child.milestones = [0]
    child.acknowledge(utilityReceived.sequence)
    var actors: [String: ScriptOwnedActor] = [:]
    for role in NativeInductionUtilityRole.allCases {
      var actor = try utility.prepared(role)
      let resources = try NativeInductionUtilityPack.initialResources(
        state: utility.child(), actor: actor)
      let arm = try work.arm(role)
      actor.body.id = Int(arm.actor.entity)
      actor.presence = .unloaded
      actor.body.physical = .init(identity: arm.actor, population: .mission, npc: resources)
      actors[role.rawValue] = actor
    }
    var utilityGroup = ScriptOwnedEncounter(
      id: NativeInductionUtilityPack.encounter,
      galaxy: 0, system: 190, actors: actors)
    utilityGroup.admitted = true
    child.ownedEncounters[utilityGroup.id] = utilityGroup
    commander.scriptState.instances[child.id] = child
    while commander.flightSimulation.nextActor <= 44 {
      _ = commander.flightSimulation.allocateActor()
    }
  }
  func cancelled() throws -> NativeInductionSeedCustody {
    let contact = WayfarerColdChainContact(
      sequence: 265, dock: issue.dock,
      context: Self.context(dock: issue.dock, clock: 900_265, revision: 1))
    let operation = try NativeInductionSeedHeldCancellation.identity(
      pickup: custody.pickup.operation, contact: contact, time: 1_000_265)
    return .init(
      pickup: custody.pickup, timer: custody.timer,
      integrity: try custody.integrity.observing(
        .init(binding: custody.integrity.binding, timer: custody.timer, context: contact.context)),
      cancellation: .init(
        operation: operation, pickup: custody.pickup.operation, contact: contact,
        physicalTime: 1_000_265))
  }
  func event() -> ScriptEvent {
    .init(
      sequence: 290, kind: "timer.fired", instance: booking.instance,
      values: [
        "timer_id": .string(custody.timer.id), "pulse": .integer(1),
        "due": .number(custody.timer.due),
        "fired_at": .number(custody.timer.due), "has_been_run": .bool(true),
        "clock_exhausted": .bool(false),
        "counters": .object([:]), "reset_counters": .array([]),
      ],
      context: Self.context(clock: custody.timer.due, revision: 1))
  }
  func ending(_ kind: NativeInductionSeedCustodyEnd.Kind) throws -> NativeInductionSeedCustody {
    var custody = kind == .returned ? try cancelled() : self.custody
    let capacity = try #require(held.charterCapacity)
    let window = try capacity.returnQuote(
      reservation: booking.window.operation, reason: kind == .received ? .completed : .cancelled)
    let contact: WayfarerColdChainContact? =
      [.received, .returned].contains(kind)
      ? .init(
        sequence: 300, dock: kind == .received ? receiver : returned,
        context: Self.context(
          dock: kind == .received ? receiver : returned, clock: 900_300,
          revision: kind == .returned ? 2 : 1)) : nil
    let context =
      contact?.context
      ?? Self.context(clock: kind == .spoiled ? custody.timer.due : 900_300, revision: 1)
    let loss: WayfarerColdChainPhysicalLoss? =
      kind == .carrierExit
      ? .init(
        cause: .shipDestroyed, sequence: 300, context: context, energy: 0,
        visit: returned.actor.visit) : nil
    let expiry = kind == .spoiled ? event() : nil
    let payment: ScriptCourierTerminalReceipt? =
      kind == .received
      ? .init(
        id: ScriptCourierCustody.terminalIdentity(booking.unit), item: booking.unit,
        cause: .delivered,
        proof: .init(
          sequence: 300, token: "induction-original-seed-reception", revision: 1, epoch: UUID(),
          clock: context.calendarSeconds,
          station: .init(galaxy: 0, system: 91, stationClass: "main-orbital")),
        amount: booking.terms.rewardNative) : nil
    let integrity: WayfarerColdChain
    if let expiry {
      integrity = try custody.integrity.spoiling(binding: custody.integrity.binding, event: expiry)
    } else if let payment {
      integrity = try custody.integrity.receiving(
        .init(binding: custody.integrity.binding, timer: custody.timer, context: context),
        receipt: payment)
    } else {
      integrity = try custody.integrity.observing(
        .init(binding: custody.integrity.binding, timer: custody.timer, context: context))
    }
    let before = kind == .received ? 1000 : nil
    let after = before.map { $0 + booking.terms.rewardNative }
    let clock = kind == .spoiled ? 950_000 : context.flightSeconds
    let operation = try NativeInductionSeedCustodyEnd.identity(
      booking: booking.operation, pickup: custody.pickup.operation,
      kind: kind, sequence: 300, stockRevision: 1, window: window, time: 1_100_000,
      context: context,
      closedFlightSeconds: clock, contact: contact, loss: loss, expiry: expiry, payment: payment,
      before: before, after: after)
    custody = .init(
      pickup: custody.pickup, timer: custody.timer, integrity: integrity,
      cancellation: custody.cancellation,
      end: .init(
        operation: operation, booking: booking.operation, pickup: custody.pickup.operation,
        kind: kind,
        sequence: 300, stockRevision: 1, window: window, physicalTime: 1_100_000, context: context,
        closedFlightSeconds: clock, contact: contact, loss: loss, expiry: expiry, payment: payment,
        creditsBefore: before, creditsAfter: after))
    return custody
  }
  func close(_ kind: NativeInductionSeedUncollectedClose.Kind = .cancelled) throws
    -> NativeInductionSeedUncollectedClose
  {
    let capacity = try #require(held.charterCapacity)
    let window = try capacity.returnQuote(reservation: booking.window.operation, reason: .cancelled)
    let player = ActorIdentity(
      system: issue.dock.actor.system, visit: returned.actor.visit, entity: 0)
    let operation = try NativeInductionSeedUncollectedClose.identity(
      booking: booking.operation,
      stockRevision: 1, kind: kind, window: window.operation, player: player,
      carrier: booking.carrier,
      fit: 1, time: 1_000_280, flightSeconds: 900_280, sequence: 280)
    let context = Self.context(clock: 900_280, revision: 0)
    return .init(
      operation: operation, sequence: 280, instance: booking.instance,
      booking: booking.operation, stockRevision: 1, kind: kind, window: window,
      player: player, carrier: booking.carrier, inventoryRevision: 1, physicalTime: 1_000_280,
      flightSeconds: 900_280, dock: kind == .cancelled ? returned : nil,
      loss: kind == .carrierExit
        ? .init(
          cause: .shipDestroyed, sequence: 280, context: context, energy: 0, visit: player.visit)
        : nil,
      sourceLoss: kind == .sourceLost
        ? .init(
          identity: issue.dock.station.resource, galaxy: 0, system: 162, energy: 0, destroyed: true)
        : nil)
  }
}

struct NativeWayfarerInductionSeedUnitTests {
  @Test func sixOriginalThreeTonneLotsAreDistinctFromClinicWorkshopInductionAndGenericW03Stock()
    throws
  {
    let f = try InductionSeedFixture()
    #expect(f.source.valid(parent: f.available) && f.source.units.count == 6)
    #expect(Set(f.source.units.map(\.id)).count == 6)
    #expect(Set(f.source.units.map(\.id)).isDisjoint(with: f.f.source.units.map(\.id)))
    #expect(Set(f.source.units.map(\.id)).isDisjoint(with: f.f.f.f.source.units.map(\.id)))
    #expect(f.issue.operatorOwner != f.issue.commanderOwner && f.quote.terms.tonnes == 3)
    #expect(f.quote.terms.flightAllowance == 7200 && f.quote.terms.valid)
    #expect(
      f.held.charterClinicSource == f.f.held.charterClinicSource
        && f.held.charterWorkshopSource == f.f.held.charterWorkshopSource)
    #expect(throws: (any Error).self) { try f.available.issuingSeedBatch(f.source) }
  }
  @Test
  func currentReachableEnlirinLareriaQuoteUsesExactWholeItineraryPriceAndCannotRelabelGenericSeed()
    throws
  {
    let f = try InductionSeedFixture()
    #expect(
      f.quote.route.valid && f.quote.route.worldKeys.first == "G01-S162"
        && f.quote.route.worldKeys.last == "G01-S091")
    #expect(f.quote.offer.rewardNative == 5100 + 950 * f.quote.route.distancesLY.count)
    let generic = WayfarerColdChainDefinition(
      source: f.quote.terms.source, objective: f.quote.terms.receiver,
      receiver: f.quote.terms.receiver, batch: "different-original-seed", stockUnits: 6, tonnes: 3,
      maximumActive: 3,
      route: f.quote.terms.route, hazardTier: 0, flightAllowance: 7200,
      rewardNative: f.quote.terms.rewardNative,
      profile: .seedTransfer, sourceCustodian: .init(id: "first", name: "Source custodian"),
      receiverCustodian: .init(id: "second", name: "Receiver custodian"))
    #expect(!generic.valid && f.quote.terms.valid)
    #expect(throws: (any Error).self) {
      try NativeInductionSeedRoute(firstReachLY: 0, fullReachLY: 7)
    }
  }
  @Test func bookingUsesThirdSharedSlotAndSameOwnerWindowAndPickupSwapsExactlyThreeRealTonnes()
    throws
  {
    let f = try InductionSeedFixture()
    var commander = try f.commander()
    #expect(NativeInductionSeedSave.validateClaims(commander))
    #expect(OriginalServiceReservationPolicy.activeCount(commander.scriptState) == 3)
    #expect(throws: (any Error).self) {
      try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    }
    #expect(
      f.child().savedNativeInductionSeed?.reservedCargoTonnes == 3 && f.child().payloads.isEmpty)
    let mass = commander.checkedCargoTonnes
    commander.scriptState.instances[f.booking.instance] = f.child(custody: f.custody)
    #expect(
      NativeInductionSeedSave.validateClaims(commander) && commander.checkedCargoTonnes == mass)
    #expect(
      commander.requiresContractFit
        && commander.tradeCargoCapacity == commander.standardCargoCapacity)
    #expect(f.child(custody: f.custody).payloads == [NativeInductionSeedCustody.payload: 3])
    #expect(f.custody.timer.due == f.custody.pickup.contact.context.flightSeconds + 7200)
  }
  @Test
  func actualOriginalReceivingPaysFrozenQuoteOnceAndReturnsOnlyItsWindowWithoutParentProgress()
    throws
  {
    let f = try InductionSeedFixture()
    let custody = try f.ending(.received)
    let end = try #require(custody.end)
    var commander = try f.commander(custody: f.custody)
    commander.credits = 1000
    var child = f.child(custody: f.custody)
    let committed = InductionSeedFixture.context(dock: f.receiver, clock: 900_300, revision: 2)
    try NativeInductionSeedSave.commitEnd(
      end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    #expect(NativeInductionSeedSave.validateClaims(commander))
    #expect(commander.credits == 1000 + f.booking.terms.rewardNative && child.outcome == .complete)
    #expect(child.payloads.isEmpty && child.timers.isEmpty && child.milestones == [0])
    let parent = try #require(
      commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction)
    #expect(
      parent.milestones == f.held.milestones
        && parent.charterSeedSource?.units[0].status == .received)
    #expect(throws: (any Error).self) {
      try NativeInductionSeedSave.commitEnd(
        end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    }
  }
  @Test
  func beforePickupCancellationReturnsSameWarehouseLotWindowAndThreeTonnesWithoutStartingTimer()
    throws
  {
    let f = try InductionSeedFixture()
    let close = try f.close()
    let source = try #require(f.held.charterSeedSource)
    let capacity = try #require(f.held.charterCapacity)
    let next = try f.held.updatingSeed(
      source.applying(NativeInductionSeedSave.stockEvent(close, booking: f.booking)),
      capacity: capacity.returning(close.window))
    var commander = try f.commander()
    commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction = next
    commander.scriptState.instances[f.booking.instance] = f.child(close: close)
    #expect(NativeInductionSeedSave.validateClaims(commander))
    #expect(next.charterSeedSource?.units == f.source.units)
    #expect(
      f.child(close: close).timers.isEmpty
        && f.child(close: close).savedNativeInductionSeed?.reservedCargoTonnes == 0)
    #expect(f.child(close: close).outcome == .abandoned && next.milestones == f.held.milestones)
  }
  @Test
  func
    heldCancellationRetainsOriginalCargoWindowAndDeadlineUntilActualOwnerReturnWithoutFreshStock()
    throws
  {
    let f = try InductionSeedFixture()
    let cancelled = try f.cancelled()
    #expect(
      cancelled.valid(booking: f.booking, parent: f.held) && cancelled.timer == f.custody.timer)
    #expect(
      f.child(custody: cancelled).payloads.values.first == 3
        && f.child(custody: cancelled).outcome == .active)
    let custody = try f.ending(.returned)
    let end = try #require(custody.end)
    var commander = try f.commander(custody: cancelled)
    let money = commander.credits
    var child = f.child(custody: cancelled)
    let committed = InductionSeedFixture.context(dock: f.returned, clock: 900_300, revision: 3)
    try NativeInductionSeedSave.commitEnd(
      end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    #expect(NativeInductionSeedSave.validateClaims(commander) && commander.credits == money)
    #expect(child.outcome == .abandoned && child.payloads.isEmpty && child.timers.isEmpty)
    let source = commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction?
      .charterSeedSource
    #expect(
      source?.units[0].status == .received
        && source?.units.filter { $0.status == .available }.count == 5)
  }
  @Test func exactNativeExpiryKeepsOriginalQualityProofAndUsesCurrentPublicationForTheWindowReturn()
    throws
  {
    let f = try InductionSeedFixture()
    var commander = try f.commander(custody: f.custody, clock: 950_000)
    var child = f.child(custody: f.custody)
    child.timers = [:]
    let event = f.event()
    commander.scriptState.pendingEvents = [event]
    commander.scriptState.instances[child.id] = child
    #expect(NativeInductionSeedSave.pendingExpiry(child, engine: commander.scriptState) == event)
    let money = commander.credits
    try Game().applyInductionSeedExpiry(event: event, state: &child, candidate: &commander)
    let end = try #require(child.savedNativeInductionSeed?.custody?.end)
    #expect(end.expiry == event && end.sequence == 300 && end.closedFlightSeconds == 950_000)
    #expect(end.context.flightSeconds == 907_460 && child.outcome == .failed)
    #expect(child.payloads.isEmpty && child.timers.isEmpty && commander.credits == money)
    #expect(commander.scriptState.pendingEvents.isEmpty && child.hasAcknowledged(300))
  }
  @Test func actualCarrierLossAndUncollectedSourceDestructionNeverRestockOrPayForLostLots() throws {
    let f = try InductionSeedFixture()
    for kind: NativeInductionSeedUncollectedClose.Kind in [.carrierExit, .sourceLost] {
      let close = try f.close(kind)
      let source = try #require(f.held.charterSeedSource)
      let capacity = try #require(f.held.charterCapacity)
      let next = try f.held.updatingSeed(
        source.applying(NativeInductionSeedSave.stockEvent(close, booking: f.booking)),
        capacity: capacity.returning(close.window))
      #expect(close.valid(booking: f.booking, parent: next))
      #expect(
        next.charterSeedSource?.units[0].status == (kind == .sourceLost ? .failed : .available))
    }
    let custody = try f.ending(.carrierExit)
    let end = try #require(custody.end)
    var commander = try f.commander(custody: f.custody)
    let money = commander.credits
    var child = f.child(custody: f.custody)
    try NativeInductionSeedSave.commitEnd(
      end, custody: custody, child: &child, commander: &commander,
      committedContext: InductionSeedFixture.context(clock: 900_300, revision: 2))
    #expect(NativeInductionSeedSave.validateClaims(commander) && commander.credits == money)
    #expect(child.outcome == .failed && child.milestones.isEmpty && child.payloads.isEmpty)
  }
  @Test func pauseAndColdRestoreKeepSameOriginalLotAndAbsolute7200SecondIntegrityWithoutRefill()
    throws
  {
    let f = try InductionSeedFixture()
    let restored = try JSONDecoder().decode(
      NativeInductionSeedCustody.self, from: JSONEncoder().encode(f.custody))
    #expect(restored == f.custody && restored.integrity.remaining == 7200)
    let same = try restored.integrity.observing(
      .init(
        binding: restored.integrity.binding, timer: restored.timer,
        context: restored.pickup.contact.context))
    #expect(same.remaining == 7200)
    let advanced = try same.observing(
      .init(
        binding: same.binding, timer: restored.timer,
        context: InductionSeedFixture.context(clock: 900_860, revision: 1)))
    #expect(advanced.remaining == 6600)
    #expect(throws: (any Error).self) {
      try advanced.observing(
        .init(
          binding: advanced.binding, timer: restored.timer, context: restored.pickup.contact.context
        ))
    }
  }
  @Test func sourceStockChildWindowAcknowledgementAndNativeClockClaimsMustJoinBothDirections()
    throws
  {
    let f = try InductionSeedFixture()
    var commander = try f.commander()
    #expect(NativeInductionSeedSave.validateClaims(commander))
    let child = try #require(commander.scriptState.instances[f.booking.instance])
    commander.scriptState.instances.removeValue(forKey: child.id)
    #expect(!NativeInductionSeedSave.validateClaims(commander))
    commander.scriptState.instances[child.id] = child
    commander.scriptState.instances[child.id]?.acknowledgedThrough = 249
    #expect(!NativeInductionSeedSave.validateClaims(commander))
    commander.scriptState.instances[child.id] = child
    commander.scriptState.flightSeconds = 900_249
    #expect(!NativeInductionSeedSave.validateClaims(commander))
    commander.scriptState.flightSeconds = 900_500
    commander.scriptState.instances[child.id] = f.child(custody: f.custody)
    commander.scriptState.instances[child.id]?.payloads = [NativeInductionSeedCustody.payload: 1]
    #expect(!NativeInductionSeedSave.validateClaims(commander))
  }
  @Test func otherOwnerUpdatesKeepAllThreeSourcesAndAvenorReadonlyCannotBecomeRemotePickup() throws
  {
    let f = try InductionSeedFixture()
    let capacity = try #require(f.held.charterCapacity)
    let clinic = try #require(f.held.charterSignatures?.first(where: { $0.operatorID == .clinic }))
    let unit = try #require(
      capacity.units.first(where: { $0.operatorID == .clinic && $0.slot == 3 }))
    let laterClinic = f.dock(185, sequence: 110, visit: f.returned.actor.visit + 1)
    let release = try f.f.f.f.f.release(
      clinic, capacity: capacity, unit: unit, dock: laterClinic, sequence: 270, time: 1_000_270,
      flightSeconds: 900_270
    )
    let next = try f.held.releasingCharterUnit(release)
    #expect(
      next.charterSeedSource == f.held.charterSeedSource
        && next.charterWorkshopSource == f.held.charterWorkshopSource
        && next.charterClinicSource == f.held.charterClinicSource)
    #expect(release.dock == laterClinic && release.revision == capacity.revision)
    let auditor = f.dock(7, sequence: 111, visit: laterClinic.actor.visit + 1)
    let quote = try NativeInductionSeedQuote.prepare(
      source: f.source, parent: f.available, unit: f.source.units[0].id,
      scope: .avenorReadOnlyAudit, dock: auditor, carrier: f.booking.carrier, revision: 1,
      runtimeEpoch: f.quote.runtimeEpoch, firstReachLY: 7, fullReachLY: 7)
    var game = Game()
    game.commander = try f.commander()
    game.commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction = f.available
    #expect(throws: (any Error).self) { try game.inductionSeedWindow(quote: quote) }
    #expect(quote.offer.id != f.quote.offer.id && quote.offer.stockUnit == f.quote.offer.stockUnit)
  }
  @Test func changedLotTermsOrStaleCashCannotPartiallyReceiveReleaseCargoOrCreateSeedPayment()
    throws
  {
    let f = try InductionSeedFixture()
    let custody = try f.ending(.received)
    let end = try #require(custody.end)
    var commander = try f.commander(custody: f.custody)
    commander.credits = 1001
    let before = commander
    var child = f.child(custody: f.custody)
    let original = child
    let committed = InductionSeedFixture.context(dock: f.receiver, clock: 900_300, revision: 2)
    #expect(throws: (any Error).self) {
      try NativeInductionSeedSave.commitEnd(
        end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    }
    #expect(commander == before && child == original)
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.booking.terms)) as? [String: Any])
    raw["tonnes"] = 1
    let changed = try JSONDecoder().decode(
      NativeInductionSeedTerms.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(!changed.valid)
  }
  @Test func contextualSeedRowsAndCapturedQuoteKeepPickupReceivingReturnAndHelpSeparate() throws {
    let f = try InductionSeedFixture()
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledInductionSeedDirectory)
    #expect(NativeInductionSeedPack.matches(pack) && pack.manifest.coldChain == nil)
    var game = Game()
    game.scriptPacks = [pack]
    game.commander = try f.commander(custody: f.custody)
    game.commander.system = 91
    #expect(game.inductionSeedCustodyRows.contains { $0.wayfarerInduction == .receiveSeedLot })
    #expect(!game.inductionSeedCustodyRows.contains { $0.wayfarerInduction == .pickupSeedLot })
    game.commander.scriptState.instances[f.booking.instance] = f.child(custody: try f.cancelled())
    game.commander.system = 162
    #expect(game.inductionSeedCustodyRows.contains { $0.wayfarerInduction == .returnSeedLot })
    game.screen = .contracts
    game.contractBoard.rows = [
      .init(
        board: NativeWayfarerInductionAction.viewSeedStock.key, offer: nil,
        title: "Read-only seed quote", reason: "Read-only", wayfarerInduction: .viewSeedStock)
    ]
    game.contractBoard.wayfarerInductionQuote = .init(
      action: .viewSeedStock, dock: f.issue.dock,
      carrier: f.booking.carrier, inventoryRevision: 1, trade: nil, epoch: f.quote.runtimeEpoch,
      missionRevision: 1, arkRevision: nil, rescueRevision: nil, utilityRevision: nil,
      capacityRevision: f.quote.capacityRevision, capacityUnit: nil, clinicQuote: nil,
      issues: ["Read-only"], seedQuote: f.quote)
    let before = game.commander
    #expect(game.inductionSeedDetail.contains { $0.contains(f.quote.offer.stockUnit.uuidString) })
    #expect(
      game.commander == before && PlayerHelp.pages(for: game).first?.title == "ORIGINAL SEED LOT")
  }
  @Test func closedSeedSchemaPreservesEarlierOperatorsAndRejectsEarlyEmbeddedUnknownOrOrphanClaims()
    throws
  {
    let f = try InductionSeedFixture()
    let child = f.child(custody: f.custody)
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(child)) as? [String: Any])
    func data() throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [child.id.uuidString: raw]])
    }
    for schema in [117, 118] {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
    }
    for schema in [113, 114, 115, 116] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
      }
    }
    let restored = try JSONDecoder().decode(ScriptInstance.self, from: JSONEncoder().encode(child))
    #expect(restored == child)
    var leaf = try #require(raw["savedNativeInductionSeed"] as? [String: Any])
    leaf["resetIntegrity"] = true
    raw["savedNativeInductionSeed"] = leaf
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: 117)
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": try JSONSerialization.jsonObject(with: data())
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(embedded, part: .commander, schema: 117)
    }
    #expect(NativeInductionArkSave.isAlien(116) && NativeInductionArkSave.isAlien(118))
  }
}
