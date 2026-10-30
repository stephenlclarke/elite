import Foundation
import Testing

@testable import L337Core

/// Typed original stock/condition/ownership fixtures, not a native player journey.
final class InductionWorkshopFixture {
  let f: InductionClinicAcceptanceFixture
  let signature: NativeInductionCharterSignature
  let issue: NativeInductionWorkshopIssue
  let source: NativeInductionWorkshopSource
  let available: NativeWayfarerInductionState
  let quote: NativeInductionWorkshopQuote
  let booking: NativeInductionWorkshopBooking
  let held: NativeWayfarerInductionState
  init() throws {
    f = try .init()
    let capacity = try #require(f.held.charterCapacity)
    signature = try f.f.f.signature(
      .workshop, capacity: capacity, sequence: 170,
      time: 1_000_170, flightSeconds: 900_170)
    let signed = try f.held.recordingCharterConsent(signature)
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionWorkshopIssue.identity(
      consent: signature.operation,
      allocation: capacity.allocation.operation, revision: capacity.revision,
      fingerprint: fingerprint,
      dock: signature.dock, carrier: f.booking.carrier, fit: 1, time: 1_000_180,
      flightSeconds: 900_180, sequence: 180)
    issue = .init(
      operation: operation, sequence: 180, parent: f.booking.parent,
      commanderOwner: f.booking.commanderOwner, operatorOwner: signature.operatorOwner,
      epoch: signature.epoch, policy: signature.policy, consent: signature.operation,
      allocation: capacity.allocation.operation, capacityRevision: capacity.revision,
      capacityFingerprint: fingerprint, familyDigest: NativeInductionWorkshopPack.digest,
      profile: .original,
      dock: signature.dock, carrier: f.booking.carrier, inventoryRevision: 1,
      physicalTime: 1_000_180, flightSeconds: 900_180)
    source = try .init(issue: issue, parent: signed)
    let issued = try signed.issuingWorkshopBatch(source)
    let release = try f.f.f.release(
      signature, capacity: capacity, sequence: 181,
      time: 1_000_181, flightSeconds: 900_181)
    available = try issued.releasingCharterUnit(release)
    quote = try .prepare(
      source: source, parent: available, unit: source.units[0].id,
      scope: .ownerStation, dock: signature.dock, carrier: issue.carrier, fit: 1,
      runtimeEpoch: ScriptIdentity.uuid("original-workshop-unit-runtime"), firstReachLY: 7,
      fullReachLY: 7)
    let before = try #require(available.charterCapacity)
    let instance = NativeInductionWorkshopSource.instance(
      source: source.identity, unit: source.units[0].id, revision: 0)
    let window = try before.quote(consignment: instance, unit: release.unit)
    booking = .init(
      operation: NativeInductionWorkshopBooking.identity(
        instance: instance, offer: quote.offer.id,
        window: window.operation, time: 1_000_190, flightSeconds: 900_190, sequence: 190),
      instance: instance, sequence: 190, parent: issue.parent, commanderOwner: issue.commanderOwner,
      operatorOwner: issue.operatorOwner, source: source.identity, issue: issue.operation,
      unit: source.units[0].id, serial: source.units[0].serial, epoch: issue.epoch,
      familyDigest: issue.familyDigest,
      offer: quote.offer.id, stockRevision: 0, window: window, route: quote.route,
      rewardNative: quote.offer.rewardNative, dock: quote.dock, carrier: quote.carrier,
      inventoryRevision: 1, runtimeEpoch: quote.runtimeEpoch, physicalTime: 1_000_190,
      flightSeconds: 900_190)
    held = try available.updatingWorkshop(
      source.applying(NativeInductionWorkshopSave.stockEvent(booking)),
      capacity: before.reserving(window))
  }
  func dock(_ system: Int, sequence: UInt64, visit: UInt64) -> NativeMainStationDockReceipt {
    NativeWayfarerInductionUnitTests().dock(
      owner: issue.commanderOwner, system: system, visit: visit, sequence: sequence)
  }
  func context(_ dock: NativeMainStationDockReceipt? = nil, sequence: UInt64, revision: UInt64)
    -> ScriptEventContext
  {
    var context = ScriptEventContext(
      galaxy: 0, system: dock?.station.system.system ?? 0,
      docked: dock != nil, mainStation: dock != nil, revision: revision,
      frameSeconds: 900_000 + Double(sequence), localSeconds: 900_000 + Double(sequence),
      flightSeconds: 900_000 + Double(sequence), calendarSeconds: 1_000_000 + Double(sequence),
      transitSeconds: 0, playerPosition: nil)
    context.nativeMainDock = dock
    return context
  }
  func picked() throws -> NativeInductionWorkshopContract {
    let contact = WayfarerColdChainContact(
      sequence: 200, dock: issue.dock,
      context: context(issue.dock, sequence: 200, revision: 0))
    let operation = try NativeInductionWorkshopPickup.identity(
      booking: booking.operation,
      contact: contact, carrier: booking.carrier, fit: 1, time: 1_000_200)
    return .init(
      booking: booking,
      pickup: .init(
        operation: operation, booking: booking.operation,
        contact: contact, carrier: booking.carrier, inventoryRevision: 1, physicalTime: 1_000_200))
  }
  func serviced() throws -> NativeInductionWorkshopContract {
    let picked = try picked()
    let pickup = try #require(picked.pickup)
    let serviceDock = dock(185, sequence: 106, visit: issue.dock.actor.visit + 1)
    let contact = WayfarerColdChainContact(
      sequence: 210, dock: serviceDock, context: context(serviceDock, sequence: 210, revision: 1))
    let operation = try NativeInductionWorkshopService.identity(
      pickup: pickup.operation, unit: booking.unit,
      serial: booking.serial, contact: contact, carrier: booking.carrier, fit: 1, time: 1_000_210)
    let before = picked.condition
    let after = try before.serviced(sourceUnit: booking.unit, operation: operation)
    return .init(
      booking: booking, pickup: pickup,
      service: .init(
        operation: operation,
        pickup: pickup.operation, unit: booking.unit, serial: booking.serial, contact: contact,
        carrier: booking.carrier, inventoryRevision: 1, physicalTime: 1_000_210, before: before,
        after: after))
  }
  func cancelled(serviced: Bool = false) throws -> NativeInductionWorkshopContract {
    let previous = serviced ? try self.serviced() : try picked()
    let pickup = try #require(previous.pickup)
    let sequence: UInt64 = serviced ? 215 : 205
    let contact = WayfarerColdChainContact(
      sequence: sequence, dock: previous.service?.contact.dock ?? issue.dock,
      context: context(
        previous.service?.contact.dock ?? issue.dock, sequence: sequence, revision: serviced ? 2 : 1
      ))
    let operation = try NativeInductionWorkshopCancellation.identity(
      pickup: pickup.operation,
      contact: contact, time: 1_000_000 + Double(sequence))
    return .init(
      booking: booking, pickup: pickup, service: previous.service,
      cancellation: .init(
        operation: operation, pickup: pickup.operation, contact: contact,
        physicalTime: 1_000_000 + Double(sequence)))
  }
  func child(_ contract: NativeInductionWorkshopContract) -> ScriptInstance {
    var child = ScriptInstance(
      id: booking.instance, definition: NativeInductionWorkshopPack.stateID,
      version: NativeInductionWorkshopPack.version, digest: NativeInductionWorkshopPack.digest)
    child.savedNativeInductionWorkshop = contract
    child.payloads = contract.payloads
    child.acknowledge(190)
    if contract.pickup != nil {
      child.revision += 1
      child.acknowledge(200)
    }
    if contract.service != nil {
      child.revision += 1
      child.acknowledge(210)
    }
    if let cancel = contract.cancellation {
      child.revision += 1
      child.acknowledge(cancel.contact.sequence)
    }
    return child
  }
  func commander(_ contract: NativeInductionWorkshopContract) throws -> Commander {
    var commander = try f.commander()
    let receiver = dock(0, sequence: 107, visit: issue.dock.actor.visit + 2)
    while commander.flightSimulation.visit < receiver.actor.visit {
      commander.flightSimulation.enter(receiver.actor.system, arriving: true)
    }
    commander.flightSimulation.physicalTime = 1_000_500
    commander.scriptState.localSeconds = 900_500
    commander.scriptState.flightSeconds = 900_500
    commander.scriptState.calendarSeconds = 1_000_500
    commander.scriptState.nextEvent = 219
    let service = dock(185, sequence: 106, visit: issue.dock.actor.visit + 1)
    for station in [issue.dock.station, service.station]
    where commander.nativeStations?.mainStations.contains(station) != true {
      commander.nativeStations?.mainStations.append(station)
    }
    commander.nativeStations?.nextMainDockSequence = 109
    commander.scriptState.instances[issue.parent]?.savedWayfarerInduction = held
    commander.scriptState.instances[issue.parent]?.acknowledge(215)
    commander.scriptState.instances[booking.instance] = child(contract)
    return commander
  }
  func end(_ kind: NativeInductionWorkshopEndFacts.Kind, contract: NativeInductionWorkshopContract)
    throws -> NativeInductionWorkshopEnd
  {
    let capacity = try #require(held.charterCapacity)
    let window = try capacity.returnQuote(
      reservation: booking.window.operation, reason: kind == .returned ? .completed : .cancelled)
    let receiver = dock(0, sequence: 107, visit: issue.dock.actor.visit + 2)
    let contact: WayfarerColdChainContact? =
      [.returned, .cancelledHeld, .cancelledBeforePickup].contains(kind)
      ? .init(
        sequence: 220, dock: receiver,
        context: context(receiver, sequence: 220, revision: child(contract).revision)) : nil
    let context =
      contact?.context ?? self.context(sequence: 220, revision: child(contract).revision)
    let loss: WayfarerColdChainPhysicalLoss? =
      kind == .carrierExit
      ? .init(
        cause: .shipDestroyed, sequence: 220, context: context, energy: 0,
        visit: receiver.actor.visit) : nil
    let sourceLoss: ScriptStationResource? =
      kind == .sourceLost
      ? .init(
        identity: issue.dock.station.resource, galaxy: 0, system: 0, energy: 0, destroyed: true)
      : nil
    let facts = NativeInductionWorkshopEndFacts(
      booking: booking.operation, kind: kind, sequence: 220,
      stockRevision: 1, window: window, carrier: booking.carrier, inventoryRevision: 1,
      physicalTime: 1_000_220, context: context, contact: contact, loss: loss,
      sourceLoss: sourceLoss,
      creditsBefore: kind == .returned ? 1000 : nil,
      creditsAfter: kind == .returned ? 1000 + booking.rewardNative : nil)
    return .init(operation: try NativeInductionWorkshopEnd.identity(facts), facts: facts)
  }
  func commit(_ end: NativeInductionWorkshopEnd, contract: NativeInductionWorkshopContract) throws
    -> Commander
  {
    var commander = try self.commander(contract)
    commander.credits = 1000
    var child = self.child(contract)
    let committed = context(end.facts.contact?.dock, sequence: 220, revision: child.revision + 1)
    try NativeInductionWorkshopSave.commitEnd(
      end, child: &child, commander: &commander, committedContext: committed)
    if let sourceLoss = end.facts.sourceLoss {
      commander.scriptState.stationResources[sourceLoss.key] = sourceLoss
    }
    return commander
  }
}

struct NativeWayfarerInductionWorkshopUnitTests {
  @Test func originalBatchKeepsSixDistinctFailedSerialsSeparateFromClinicCargoAndAllWindows() throws
  {
    let f = try InductionWorkshopFixture()
    #expect(f.source.valid(parent: f.available) && f.source.units.count == 6)
    #expect(
      Set(f.source.units.map(\.id)).count == 6 && Set(f.source.units.map(\.serial)).count == 6)
    #expect(
      f.source.units.allSatisfy {
        $0.status == .available && $0.originalCondition == .failed(sourceUnit: $0.id)
      })
    #expect(Set(f.source.units.map(\.id)).isDisjoint(with: f.f.f.source.units.map(\.id)))
    let capacity = try #require(f.available.charterCapacity)
    #expect(Set(f.source.units.map(\.id)).isDisjoint(with: capacity.units.map(\.identity)))
    #expect(f.source.issue.operatorOwner != f.source.issue.commanderOwner)
    #expect(
      f.held.charterClinicSource == f.f.held.charterClinicSource
        && f.held.milestones == f.f.held.milestones)
    #expect(throws: (any Error).self) { try f.available.issuingWorkshopBatch(f.source) }
  }
  @Test func wholeReachableOutAndReturnItinerarySetsExactFrozenPriceWithoutGenericW03Weakening()
    throws
  {
    let f = try InductionWorkshopFixture()
    let route = f.quote.route
    #expect(
      route.valid && route.worldKeys.first == "G01-S000" && route.worldKeys.last == "G01-S000")
    #expect(route.outward.last == "G01-S185" && route.returning.first == "G01-S185")
    #expect(route.distancesLY.count == route.outward.count + route.returning.count - 2)
    #expect(f.booking.rewardNative == 4300 + 900 * route.distancesLY.count)
    #expect(f.quote.offer.tonnes == 2 && f.quote.offer.hazardTier == 0)
    let oldDefinition = WayfarerRepairLoopDefinition(
      source: .init(galaxy: 0, system: 0, resourceKey: "main-orbital:0:0"),
      workshop: .init(galaxy: 0, system: 185, resourceKey: "main-orbital:0:185"),
      receiver: .init(galaxy: 0, system: 0, resourceKey: "main-orbital:0:0"),
      batch: "original-probe",
      stockUnits: 6, tonnes: 2, maximumActive: 3, route: [0, 185, 0], hazardTier: 0,
      rewardNative: 6100)
    #expect(oldDefinition.valid)
    #expect(
      WayfarerRepairLoopStockSource.identity(owner: f.issue.operatorOwner, terms: oldDefinition)
        != f.source.identity)
    #expect(throws: (any Error).self) {
      try NativeInductionWorkshopRoute(firstReachLY: 0, fullReachLY: 7)
    }
  }
  @Test func nativeBookingReservesSameOwnerWindowAndTwoRealTonnesBeforeUntimedPickup() throws {
    let f = try InductionWorkshopFixture()
    let booked = NativeInductionWorkshopContract(booking: f.booking)
    #expect(
      booked.valid(parent: f.held) && booked.reservedCargoTonnes == 2 && booked.payloads.isEmpty)
    #expect(f.booking.window.owner == f.issue.operatorOwner)
    let commander = try f.commander(booked)
    #expect(NativeInductionWorkshopSave.validateClaims(commander))
    #expect(OriginalServiceReservationPolicy.activeCount(commander.scriptState) == 2)
    #expect(
      commander.requiresContractFit
        && commander.tradeCargoCapacity == commander.standardCargoCapacity)
    let picked = try f.picked()
    var after = commander
    after.scriptState.instances[f.booking.instance] = f.child(picked)
    #expect(NativeInductionWorkshopSave.validateClaims(after))
    #expect(
      after.checkedCargoTonnes == commander.checkedCargoTonnes && picked.reservedCargoTonnes == 0)
    #expect(
      f.child(picked).timers.isEmpty
        && picked.payloads == [NativeInductionWorkshopContract.payload: 2])
    after.scriptState.flightSeconds = 10_000_000
    #expect(NativeInductionWorkshopSave.validateClaims(after))
  }
  @Test func actualRenasServiceKeepsSameSerialAndConditionAndOnlyOriginalOwnerReturnPaysOnce()
    throws
  {
    let f = try InductionWorkshopFixture()
    let serviced = try f.serviced()
    #expect(serviced.valid(parent: f.held) && serviced.booking.serial == f.booking.serial)
    let service = try #require(serviced.service)
    #expect(service.before == .failed(sourceUnit: f.booking.unit))
    #expect(service.after == .operational(sourceUnit: f.booking.unit, operation: service.operation))
    let end = try f.end(.returned, contract: serviced)
    var commander = try f.commit(end, contract: serviced)
    #expect(NativeInductionWorkshopSave.validateClaims(commander))
    #expect(commander.credits == 1000 + f.booking.rewardNative)
    let child = try #require(commander.scriptState.instances[f.booking.instance])
    #expect(
      child.outcome == .complete && child.milestones == [0] && child.payloads.isEmpty
        && child.timers.isEmpty)
    let parent = try #require(
      commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction)
    #expect(
      parent.milestones == f.held.milestones
        && parent.charterWorkshopSource?.units[0].returnedCondition == service.after)
    var repeated = child
    #expect(throws: (any Error).self) {
      try NativeInductionWorkshopSave.commitEnd(
        end, child: &repeated, commander: &commander, committedContext: end.facts.context)
    }
  }
  @Test func cancellationBeforePickupReturnsUnchangedWarehouseSerialWindowAndSpaceWithoutPayment()
    throws
  {
    let f = try InductionWorkshopFixture()
    let booked = NativeInductionWorkshopContract(booking: f.booking)
    let end = try f.end(.cancelledBeforePickup, contract: booked)
    let commander = try f.commit(end, contract: booked)
    #expect(NativeInductionWorkshopSave.validateClaims(commander) && commander.credits == 1000)
    let parent = try #require(
      commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction)
    #expect(parent.charterWorkshopSource?.units == f.source.units)
    #expect(commander.scriptState.instances[f.booking.instance]?.outcome == .abandoned)
    let capacity = try #require(parent.charterCapacity)
    let slots = try capacity.projection()
    #expect(!slots.contains { $0.unit.owner == f.issue.operatorOwner && capacity.eligible($0) })
  }
  @Test
  func heldCancellationRetainsActualFailedOrServicedConditionUntilOwnerReturnAndNeverRestocks()
    throws
  {
    let f = try InductionWorkshopFixture()
    for repaired in [false, true] {
      let cancelled = try f.cancelled(serviced: repaired)
      #expect(
        cancelled.valid(parent: f.held) && cancelled.outcome == .active
          && cancelled.payloads.values.first == 2)
      let end = try f.end(.cancelledHeld, contract: cancelled)
      let commander = try f.commit(end, contract: cancelled)
      #expect(NativeInductionWorkshopSave.validateClaims(commander) && commander.credits == 1000)
      let source = commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction?
        .charterWorkshopSource
      #expect(
        source?.units[0].status == .returned
          && source?.units[0].returnedCondition == cancelled.condition)
      #expect(source?.units.filter { $0.status == .available }.count == 5)
      #expect(commander.scriptState.instances[f.booking.instance]?.outcome == .abandoned)
    }
  }
  @Test func carrierExitAndKnownSourceLossPreserveWarehouseOrLostOriginalTruthWithoutCash() throws {
    let f = try InductionWorkshopFixture()
    let booked = NativeInductionWorkshopContract(booking: f.booking)
    for (contract, kind): (NativeInductionWorkshopContract, NativeInductionWorkshopEndFacts.Kind)
      in [
        (booked, .carrierExit), (try f.serviced(), .carrierExit), (booked, .sourceLost),
      ]
    {
      let end = try f.end(kind, contract: contract)
      let commander = try f.commit(end, contract: contract)
      #expect(NativeInductionWorkshopSave.validateClaims(commander) && commander.credits == 1000)
      let source = commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction?
        .charterWorkshopSource
      #expect(
        source?.units[0].status
          == (contract.pickup == nil && kind == .carrierExit ? .available : .lost))
      #expect(commander.scriptState.instances[f.booking.instance]?.outcome == .failed)
    }
  }
  @Test func reverseStockWindowAcknowledgementAndCapturedReadonlyScopeCannotInventNativeCustody()
    throws
  {
    let f = try InductionWorkshopFixture()
    let booked = NativeInductionWorkshopContract(booking: f.booking)
    var commander = try f.commander(booked)
    #expect(NativeInductionWorkshopSave.validateClaims(commander))
    commander.scriptState.instances.removeValue(forKey: f.booking.instance)
    #expect(!NativeInductionWorkshopSave.validateClaims(commander))
    commander.scriptState.instances[f.booking.instance] = f.child(booked)
    commander.scriptState.instances[f.booking.instance]?.acknowledgedThrough = 189
    #expect(!NativeInductionWorkshopSave.validateClaims(commander))
    let auditor = dockForAudit(f)
    let quote = try NativeInductionWorkshopQuote.prepare(
      source: f.source, parent: f.available,
      unit: f.source.units[0].id, scope: .avenorReadOnlyAudit, dock: auditor,
      carrier: f.booking.carrier,
      fit: 1, runtimeEpoch: f.quote.runtimeEpoch, firstReachLY: 7, fullReachLY: 7)
    var game = Game()
    game.commander = try f.commander(booked)
    game.commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction = f.available
    #expect(throws: (any Error).self) { try game.inductionWorkshopWindow(quote: quote) }
    #expect(quote.offer.serial == f.quote.offer.serial && quote.offer.id != f.quote.offer.id)
  }
  private func dockForAudit(_ f: InductionWorkshopFixture) -> NativeMainStationDockReceipt {
    f.dock(7, sequence: 108, visit: f.issue.dock.actor.visit + 2)
  }
  @Test func contextualBoardAndPinnedInternalFamilyKeepOriginalOperationsSeparateWithoutLoadGrants()
    throws
  {
    let f = try InductionWorkshopFixture()
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledInductionWorkshopDirectory)
    #expect(NativeInductionWorkshopPack.matches(pack) && pack.manifest.repairLoop == nil)
    #expect(
      !pack.manifest.capabilities.contains("local-flight-clocks-v2") && pack.manifest.trial == nil)
    var game = Game()
    game.scriptPacks = [pack]
    game.commander = try f.commander(try f.picked())
    game.commander.system = 185
    let before = game.commander
    #expect(game.inductionWorkshopRows.contains { $0.wayfarerInduction == .serviceWorkshopUnit })
    #expect(!game.inductionWorkshopRows.contains { $0.wayfarerInduction == .receiveWorkshopUnit })
    #expect(game.commander == before)
    #expect(
      !game.scriptGallery.contains(where: {
        $0.savedInstance == f.booking.instance || $0.trialDigest == pack.digest
      }))
    game.commander.scriptState.instances[f.booking.instance] = f.child(try f.serviced())
    game.commander.system = 0
    #expect(game.inductionWorkshopRows.contains { $0.wayfarerInduction == .receiveWorkshopUnit })
    #expect(
      game.inductionWorkshopRows.map(\.key).count
        == Set(game.inductionWorkshopRows.map(\.key)).count)
  }
  @Test func changedSerialConditionOrStaleCashCannotRepairClonePayOrPartiallyReturnOriginal() throws
  {
    let f = try InductionWorkshopFixture()
    let serviced = try f.serviced()
    let service = try #require(serviced.service)
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(service)) as? [String: Any])
    raw["serial"] = UUID().uuidString
    let changed = try JSONDecoder().decode(
      NativeInductionWorkshopService.self, from: JSONSerialization.data(withJSONObject: raw))
    let pickup = try #require(serviced.pickup)
    #expect(!changed.valid(booking: f.booking, pickup: pickup))
    #expect(throws: (any Error).self) {
      try service.after.serviced(sourceUnit: f.booking.unit, operation: UUID())
    }
    let end = try f.end(.returned, contract: serviced)
    var commander = try f.commander(serviced)
    commander.credits = 1001
    let before = commander
    var child = f.child(serviced)
    let original = child
    let committed = f.context(end.facts.contact?.dock, sequence: 220, revision: child.revision + 1)
    #expect(throws: (any Error).self) {
      try NativeInductionWorkshopSave.commitEnd(
        end, child: &child, commander: &commander, committedContext: committed)
    }
    #expect(commander == before && child == original)
  }
  @Test
  func closedWorkshopSchemaPreservesEarlierClinicAndRejectsEarlyEmbeddedUnknownOrOrphanClaims()
    throws
  {
    let f = try InductionWorkshopFixture()
    let child = f.child(try f.serviced())
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(child)) as? [String: Any])
    func data() throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [child.id.uuidString: raw]])
    }
    for schema in [115, 116] {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
    }
    for schema in [109, 110, 111, 112, 113, 114] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
      }
    }
    let restored = try JSONDecoder().decode(ScriptInstance.self, from: JSONEncoder().encode(child))
    #expect(restored == child)
    var leaf = try #require(raw["savedNativeInductionWorkshop"] as? [String: Any])
    leaf["freeRepair"] = true
    raw["savedNativeInductionWorkshop"] = leaf
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: 115)
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": try JSONSerialization.jsonObject(with: data())
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(embedded, part: .commander, schema: 115)
    }
    let alias = try JSONSerialization.data(withJSONObject: ["nativeInductionWorkshopSource": [:]])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(alias, part: .missions, schema: 115)
    }
    #expect(NativeInductionArkSave.isAlien(114) && NativeInductionArkSave.isAlien(116))
  }
}
