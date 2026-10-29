import Foundation
import Testing

@testable import EliteCore

/// Typed custody/timer/settlement fixtures; they do not execute a native gameplay journey.
private final class InductionClinicCustodyFixture {
  let f: InductionClinicAcceptanceFixture
  let custody: NativeInductionClinicCustody
  init() throws {
    f = try .init()
    let contact = WayfarerColdChainContact(
      sequence: 170, dock: f.booking.dock,
      context: Self.context(dock: f.booking.dock, clock: 900_170, revision: 0))
    let operation = try NativeInductionClinicPickup.identity(
      booking: f.booking.operation,
      contact: contact, carrier: f.booking.carrier, fit: 1, time: 1_000_170)
    let pickup = NativeInductionClinicPickup(
      operation: operation, booking: f.booking.operation,
      contact: contact, carrier: f.booking.carrier, inventoryRevision: 1, physicalTime: 1_000_170)
    let timer = ScriptTimer(
      id: NativeInductionClinicCustody.timerID, domain: .flight,
      due: 901_970, interval: 0, policy: .once)
    let binding = WayfarerColdChainBinding(
      owner: f.booking.commanderOwner,
      instance: f.booking.instance, consignment: f.booking.unit,
      receiver: Game.worldResourceIdentity(
        "main-station-v1:" + f.booking.terms.receiver.resourceKey), timerID: timer.id)
    custody = .init(
      pickup: pickup, timer: timer,
      integrity: try WayfarerColdChain(
        snapshot: .init(binding: binding, timer: timer, context: contact.context),
        allowance: 1800, issueSequence: 170))
  }
  static func context(
    dock: NativeMainStationDockReceipt? = nil, clock: Double,
    revision: UInt64, system: Int = 185
  ) -> ScriptEventContext {
    var context = ScriptEventContext(
      galaxy: 0, system: dock?.station.system.system ?? system,
      docked: dock != nil, mainStation: dock != nil, revision: revision,
      frameSeconds: clock, localSeconds: clock, flightSeconds: clock,
      calendarSeconds: 1_000_000 + clock, transitSeconds: 0, playerPosition: nil)
    context.nativeMainDock = dock
    return context
  }
  var receiver: NativeMainStationDockReceipt {
    NativeWayfarerInductionUnitTests().dock(
      owner: f.booking.commanderOwner, system: 164,
      visit: f.booking.dock.actor.visit + 1, sequence: 107)
  }
  func child(_ custody: NativeInductionClinicCustody? = nil) -> ScriptInstance {
    var child = f.child()
    let custody = custody ?? self.custody
    child.savedNativeInductionClinic = .init(booking: f.booking, custody: custody)
    child.payloads = [NativeInductionClinicCustody.payload: 1]
    child.timers = [custody.timer.id: custody.timer]
    child.revision = custody.cancellation == nil ? 1 : 2
    child.acknowledge(custody.cancellation?.contact.sequence ?? 170)
    return child
  }
  func commander(_ custody: NativeInductionClinicCustody? = nil, clock: Double = 900_200) throws
    -> Commander
  {
    var commander = try f.commander()
    commander.flightSimulation.physicalTime = 2_000_000
    while commander.flightSimulation.visit < receiver.actor.visit {
      commander.flightSimulation.enter(receiver.actor.system, arriving: true)
    }
    commander.scriptState.localSeconds = 950_000
    commander.scriptState.flightSeconds = clock
    commander.scriptState.calendarSeconds = 2_000_000
    commander.scriptState.nextEvent = 199
    commander.nativeStations?.mainStations.append(receiver.station)
    commander.nativeStations?.nextMainDockSequence = 109
    commander.scriptState.instances[f.booking.parent]?.acknowledge(175)
    commander.scriptState.instances[f.booking.instance] = child(custody)
    return commander
  }
  func cancelled() throws -> NativeInductionClinicCustody {
    let contact = WayfarerColdChainContact(
      sequence: 175, dock: f.booking.dock,
      context: Self.context(dock: f.booking.dock, clock: 900_175, revision: 1))
    let operation = try NativeInductionClinicHeldCancellation.identity(
      pickup: custody.pickup.operation,
      contact: contact, time: 1_000_175)
    return .init(
      pickup: custody.pickup, timer: custody.timer,
      integrity: try custody.integrity.observing(
        .init(binding: custody.integrity.binding, timer: custody.timer, context: contact.context)),
      cancellation: .init(
        operation: operation, pickup: custody.pickup.operation, contact: contact,
        physicalTime: 1_000_175))
  }
  func event(sequence: UInt64 = 190, clock: Double? = nil) -> ScriptEvent {
    let clock = clock ?? custody.timer.due
    return .init(
      sequence: sequence, kind: "timer.fired", instance: f.booking.instance,
      values: [
        "timer_id": .string(custody.timer.id), "pulse": .integer(1),
        "due": .number(custody.timer.due), "fired_at": .number(clock), "has_been_run": .bool(true),
        "clock_exhausted": .bool(false), "counters": .object([:]), "reset_counters": .array([]),
      ],
      context: Self.context(clock: clock, revision: 1))
  }
  func ending(_ kind: NativeInductionClinicCustodyEnd.Kind) throws -> NativeInductionClinicCustody {
    var custody = kind == .returned ? try cancelled() : self.custody
    let capacity = try #require(f.held.charterCapacity)
    let window = try capacity.returnQuote(
      reservation: f.booking.window.operation,
      reason: kind == .received ? .completed : .cancelled)
    let revision: UInt64 = kind == .returned ? 2 : 1
    let context = Self.context(
      dock: kind == .received ? receiver : kind == .returned ? f.booking.dock : nil,
      clock: kind == .spoiled ? custody.timer.due : 900_180, revision: revision)
    let contact: WayfarerColdChainContact? =
      [.received, .returned].contains(kind)
      ? .init(sequence: 200, dock: kind == .received ? receiver : f.booking.dock, context: context)
      : nil
    let loss: WayfarerColdChainPhysicalLoss? =
      kind == .carrierExit
      ? .init(
        cause: .shipDestroyed, sequence: 200, context: context, energy: 0,
        visit: f.booking.dock.actor.visit + 1) : nil
    let expiry: ScriptEvent? = kind == .spoiled ? event() : nil
    let payment: ScriptCourierTerminalReceipt? =
      kind == .received
      ? .init(
        id: ScriptCourierCustody.terminalIdentity(f.booking.unit), item: f.booking.unit,
        cause: .delivered,
        proof: .init(
          sequence: 200, token: "induction-original-clinic-reception", revision: revision,
          epoch: UUID(), clock: context.calendarSeconds,
          station: .init(galaxy: 0, system: 164, stationClass: "main-orbital")),
        amount: f.booking.terms.rewardNative) : nil
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
    let after = before.map { $0 + f.booking.terms.rewardNative }
    let operation = try NativeInductionClinicCustodyEnd.identity(
      booking: f.booking.operation,
      pickup: custody.pickup.operation, kind: kind, sequence: 200, stockRevision: 1,
      window: window, time: 1_100_000, context: context, closedFlightSeconds: 950_000,
      contact: contact, loss: loss, expiry: expiry, payment: payment, before: before, after: after)
    // Non-expiry publication occurs at the same native context clock.
    let closedClock = kind == .spoiled ? 950_000 : context.flightSeconds
    let finalOperation =
      kind == .spoiled
      ? operation
      : try NativeInductionClinicCustodyEnd.identity(
        booking: f.booking.operation, pickup: custody.pickup.operation, kind: kind, sequence: 200,
        stockRevision: 1, window: window, time: 1_100_000, context: context,
        closedFlightSeconds: closedClock, contact: contact, loss: loss, expiry: expiry,
        payment: payment, before: before, after: after)
    custody = .init(
      pickup: custody.pickup, timer: custody.timer, integrity: integrity,
      cancellation: custody.cancellation,
      end: .init(
        operation: finalOperation, booking: f.booking.operation, pickup: custody.pickup.operation,
        kind: kind, sequence: 200, stockRevision: 1, window: window, physicalTime: 1_100_000,
        context: context, closedFlightSeconds: closedClock, contact: contact, loss: loss,
        expiry: expiry, payment: payment, creditsBefore: before, creditsAfter: after))
    return custody
  }
}

struct NativeWayfarerInductionClinicCustodyUnitTests {
  @Test
  func pickupReplacesReservedTonneWithSameOriginalCargoAndStartsOnlyItsAbsoluteFlightDeadline()
    throws
  {
    let f = try InductionClinicCustodyFixture()
    #expect(f.custody.valid(booking: f.f.booking, parent: f.f.held))
    #expect(f.custody.timer.due == f.custody.pickup.contact.context.flightSeconds + 1800)
    #expect(f.child().savedNativeInductionClinic?.reservedCargoTonnes == 0)
    var commander = try f.commander()
    #expect(NativeInductionClinicSave.validateClaims(commander))
    #expect(
      commander.requiresContractFit
        && commander.tradeCargoCapacity == commander.standardCargoCapacity)
    let carried = commander.checkedCargoTonnes
    commander.scriptState.instances[f.f.booking.instance] = f.f.child()
    #expect(commander.checkedCargoTonnes == carried)
    #expect(f.child().payloads == [NativeInductionClinicCustody.payload: 1])
  }
  @Test func pauseAndColdRestoreKeepOriginalSerialQualityTimerAndRemainingAllowance() throws {
    let f = try InductionClinicCustodyFixture()
    let restored = try JSONDecoder().decode(
      NativeInductionClinicCustody.self, from: JSONEncoder().encode(f.custody))
    #expect(restored == f.custody && restored.integrity.remaining == 1800)
    let same = try restored.integrity.observing(
      .init(
        binding: restored.integrity.binding,
        timer: restored.timer, context: restored.pickup.contact.context))
    #expect(same.remaining == 1800)
    let context = InductionClinicCustodyFixture.context(clock: 900_770, revision: 1)
    let advanced = try same.observing(
      .init(binding: same.binding, timer: restored.timer, context: context))
    #expect(advanced.remaining == 1200)
    #expect(throws: (any Error).self) {
      try advanced.observing(
        .init(
          binding: advanced.binding, timer: restored.timer, context: restored.pickup.contact.context
        ))
    }
  }
  @Test
  func receivingPaysFrozenQuoteOnceAndClosesOriginalWindowCargoAndNativeReceiptWithoutStageTwelve()
    throws
  {
    let f = try InductionClinicCustodyFixture()
    let custody = try f.ending(.received)
    let end = try #require(custody.end)
    var commander = try f.commander()
    commander.credits = 1000
    var child = f.child()
    let committed = InductionClinicCustodyFixture.context(
      dock: f.receiver, clock: 900_180, revision: 2)
    try NativeInductionClinicSave.commitEnd(
      end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    #expect(NativeInductionClinicSave.validateClaims(commander))
    #expect(
      child.outcome == .complete && child.milestones == [0] && child.payloads.isEmpty
        && child.timers.isEmpty)
    #expect(commander.credits == 1000 + f.f.booking.terms.rewardNative)
    let parent = try #require(
      commander.scriptState.instances[f.f.booking.parent]?.savedWayfarerInduction)
    #expect(
      parent.milestones == f.f.held.milestones
        && parent.charterClinicSource?.units[0].status == .received)
    #expect(throws: (any Error).self) {
      try NativeInductionClinicSave.commitEnd(
        end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    }
  }
  @Test func heldCancellationKeepsCargoWindowAndDeadlineUntilActualOwnerReturnWithoutReissueOrCash()
    throws
  {
    let f = try InductionClinicCustodyFixture()
    let cancelled = try f.cancelled()
    #expect(cancelled.valid(booking: f.f.booking, parent: f.f.held))
    #expect(f.child(cancelled).outcome == .active && f.child(cancelled).payloads.values.first == 1)
    #expect(cancelled.timer == f.custody.timer && f.f.held.charterCapacity?.revision == 2)
    let custody = try f.ending(.returned)
    let end = try #require(custody.end)
    var commander = try f.commander(cancelled)
    let money = commander.credits
    var child = f.child(cancelled)
    let committed = InductionClinicCustodyFixture.context(
      dock: f.f.booking.dock, clock: 900_180, revision: 3)
    try NativeInductionClinicSave.commitEnd(
      end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    #expect(NativeInductionClinicSave.validateClaims(commander))
    #expect(commander.credits == money && child.outcome == .abandoned && child.milestones.isEmpty)
    let source = commander.scriptState.instances[f.f.booking.parent]?.savedWayfarerInduction?
      .charterClinicSource
    #expect(
      source?.units[0].status == .received && source?.units[0].instance == f.f.booking.instance)
    #expect(source?.units.filter { $0.status == .available }.count == 5)
  }
  @Test
  func nativeExpiryRequiresExactOriginalQueuedEventAndPreservesItsProofAcrossLaterPublication()
    throws
  {
    let f = try InductionClinicCustodyFixture()
    var commander = try f.commander(clock: 950_000)
    var child = f.child()
    child.timers = [:]
    let event = f.event()
    commander.scriptState.pendingEvents = [event]
    commander.scriptState.instances[child.id] = child
    #expect(NativeInductionClinicSave.pendingExpiry(child, engine: commander.scriptState) == event)
    var candidate = commander
    var proposed = child
    try Game().applyInductionClinicExpiry(event: event, state: &proposed, candidate: &candidate)
    let end = try #require(proposed.savedNativeInductionClinic?.custody?.end)
    #expect(end.expiry == event && end.sequence == 200 && end.closedFlightSeconds == 950_000)
    #expect(end.context.flightSeconds == f.custody.timer.due)
    #expect(proposed.outcome == .failed && proposed.payloads.isEmpty && proposed.timers.isEmpty)
    #expect(candidate.credits == commander.credits && candidate.scriptState.pendingEvents.isEmpty)
    #expect(proposed.hasAcknowledged(200))
    commander.scriptState.pendingEvents = [event, event]
    #expect(NativeInductionClinicSave.pendingExpiry(child, engine: commander.scriptState) == nil)
    #expect(throws: (any Error).self) {
      try f.custody.integrity.spoiling(
        binding: f.custody.integrity.binding, event: f.event(clock: f.custody.timer.due - 0.01))
    }
  }
  @Test func attainedCarrierLossFailsHeldOriginalWithoutPayingRestockingOrBorrowingAWindow() throws
  {
    let f = try InductionClinicCustodyFixture()
    let custody = try f.ending(.carrierExit)
    let end = try #require(custody.end)
    var commander = try f.commander()
    let money = commander.credits
    var child = f.child()
    try NativeInductionClinicSave.commitEnd(
      end, custody: custody, child: &child, commander: &commander,
      committedContext: InductionClinicCustodyFixture.context(clock: 900_180, revision: 2))
    #expect(NativeInductionClinicSave.validateClaims(commander))
    #expect(child.outcome == .failed && child.milestones.isEmpty && child.payloads.isEmpty)
    #expect(commander.credits == money)
    let parent = try #require(
      commander.scriptState.instances[f.f.booking.parent]?.savedWayfarerInduction)
    #expect(parent.charterClinicSource?.units[0].status == .failed)
    #expect(parent.charterCapacity?.events.last == .returned(end.window))
    #expect(parent.milestones == f.f.held.milestones)
  }
  @Test func alteredPickupTimerCargoAndMissingCompletionCannotClaimOriginalCustody() throws {
    let f = try InductionClinicCustodyFixture()
    var commander = try f.commander()
    #expect(NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.instances[f.f.booking.instance]?.payloads = [:]
    #expect(!NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.instances[f.f.booking.instance] = f.child()
    commander.scriptState.instances[f.f.booking.instance]?.timers = [:]
    #expect(!NativeInductionClinicSave.validateClaims(commander))
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.custody)) as? [String: Any])
    var timer = try #require(raw["timer"] as? [String: Any])
    timer["due"] = 902_000
    raw["timer"] = timer
    let changed = try JSONDecoder().decode(
      NativeInductionClinicCustody.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(!changed.valid(booking: f.f.booking, parent: f.f.held))
  }
  @Test func contextualBoardKeepsPickupReceivingAndHeldReturnSeparateWithoutChangingCustody() throws
  {
    let f = try InductionClinicCustodyFixture()
    var game = Game()
    game.commander = try f.commander()
    game.commander.system = 185
    let before = game.commander
    #expect(
      game.inductionClinicCustodyRows.contains { $0.wayfarerInduction == .cancelHeldClinicSample })
    #expect(
      !game.inductionClinicCustodyRows.contains {
        $0.wayfarerInduction == .pickupClinicSample || $0.wayfarerInduction == .receiveClinicSample
      })
    #expect(game.commander == before)
    game.commander.system = 164
    #expect(
      game.inductionClinicCustodyRows.contains { $0.wayfarerInduction == .receiveClinicSample })
    game.commander.scriptState.instances[f.f.booking.instance] = f.child(try f.cancelled())
    game.commander.system = 185
    #expect(
      game.inductionClinicCustodyRows.contains { $0.wayfarerInduction == .returnClinicSample })
    #expect(
      !game.inductionClinicCustodyRows.contains { $0.wayfarerInduction == .receiveClinicSample })
  }
  @Test func staleCashOrAlteredEndCannotPartiallyPayReleaseStockOrConsumeOriginalCargo() throws {
    let f = try InductionClinicCustodyFixture()
    let custody = try f.ending(.received)
    let end = try #require(custody.end)
    var commander = try f.commander()
    commander.credits = 1001
    let before = commander
    var child = f.child()
    let original = child
    let committed = InductionClinicCustodyFixture.context(
      dock: f.receiver, clock: 900_180, revision: 2)
    #expect(throws: (any Error).self) {
      try NativeInductionClinicSave.commitEnd(
        end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    }
    #expect(commander == before && child == original)
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(custody)) as? [String: Any])
    var ending = try #require(raw["end"] as? [String: Any])
    ending["creditsAfter"] = 999999
    raw["end"] = ending
    let changed = try JSONDecoder().decode(
      NativeInductionClinicCustody.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(throws: (any Error).self) {
      try NativeInductionClinicSave.commitEnd(
        try #require(changed.end), custody: changed, child: &child, commander: &commander,
        committedContext: committed)
    }
    #expect(commander == before && child == original)
  }
  @Test
  func closedCustodySchemaPreservesEarlierBookingsAndRejectsEarlyEmbeddedUnknownAndGenericClaims()
    throws
  {
    let f = try InductionClinicCustodyFixture()
    let child = f.child()
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(child)) as? [String: Any])
    func data() throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [child.id.uuidString: raw]])
    }
    for schema in [113, 114] {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
    }
    for schema in [109, 110, 111, 112] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
      }
    }
    let restored = try JSONDecoder().decode(ScriptInstance.self, from: JSONEncoder().encode(child))
    #expect(restored == child)
    var leaf = try #require(raw["savedNativeInductionClinic"] as? [String: Any])
    leaf["unlimitedIntegrity"] = true
    raw["savedNativeInductionClinic"] = leaf
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: 113)
    }
    let returned = try f.ending(.returned)
    let end = try #require(returned.end)
    let source = try #require(f.f.held.charterClinicSource)
    let capacity = try #require(f.f.held.charterCapacity)
    let parent = try f.f.held.updatingClinic(
      source.applying(NativeInductionClinicSave.stockEvent(end, booking: f.f.booking)),
      capacity: capacity.returning(end.window))
    let parentRaw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(parent))
    let parentBytes = try JSONSerialization.data(withJSONObject: [
      "instances": [
        f.f.booking.parent.uuidString: [
          "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
          "savedWayfarerInduction": parentRaw,
        ]
      ]
    ])
    try NativeInductionCrewLogSave.validateFields(parentBytes, part: .missions, schema: 113)
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(parentBytes, part: .missions, schema: 111)
    }
    #expect(NativeInductionArkSave.isAlien(112) && NativeInductionArkSave.isAlien(114))
  }
}
