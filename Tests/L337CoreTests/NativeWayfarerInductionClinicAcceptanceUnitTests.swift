import Foundation
import Testing

@testable import L337Core

/// Typed native receipts and ownership joins. No fixture performs a native player journey.
final class InductionClinicAcceptanceFixture {
  let f: InductionClinicFixture
  let available: NativeWayfarerInductionState
  let booking: NativeInductionClinicBooking
  let held: NativeWayfarerInductionState
  init() throws {
    f = try .init()
    let release = try f.f.release(
      f.signature, sequence: 151, time: 1_000_151, flightSeconds: 900_151)
    available = try f.issued.releasingCharterUnit(release)
    let capacity = try #require(available.charterCapacity)
    let quote = try f.quote(parent: available)
    let instance = NativeInductionClinicBooking.instance(
      source: f.source.identity,
      unit: quote.offer.stockUnit, revision: 0)
    let window = try capacity.quote(consignment: instance, unit: release.unit)
    let operation = try NativeInductionClinicBooking.identity(
      instance: instance,
      offer: quote.offer.id, window: window.operation, dock: quote.dock,
      carrier: quote.carrier, fit: 1, time: 1_000_160, flightSeconds: 900_160, sequence: 160)
    booking = .init(
      operation: operation, instance: instance, sequence: 160, parent: f.issue.parent,
      commanderOwner: f.issue.commanderOwner, operatorOwner: f.issue.operatorOwner,
      source: f.source.identity, issue: f.issue.operation, unit: quote.offer.stockUnit,
      epoch: f.issue.epoch, familyDigest: quote.familyDigest, offer: quote.offer.id,
      stockRevision: 0, window: window, route: quote.route, terms: quote.terms,
      dock: quote.dock, carrier: quote.carrier, inventoryRevision: 1,
      runtimeEpoch: quote.runtimeEpoch, physicalTime: 1_000_160, flightSeconds: 900_160)
    held = try available.updatingClinic(
      f.source.applying(NativeInductionClinicSave.stockEvent(booking)),
      capacity: capacity.reserving(window))
  }
  func child(close: NativeInductionClinicUncollectedClose? = nil) -> ScriptInstance {
    var child = ScriptInstance(
      id: booking.instance, definition: NativeInductionClinicPack.stateID,
      version: NativeInductionClinicPack.version, digest: NativeInductionClinicPack.digest)
    let contract = NativeInductionClinicContract(booking: booking, close: close)
    child.savedNativeInductionClinic = contract
    child.outcome = contract.outcome
    child.acknowledge(160)
    if let close { child.acknowledge(close.sequence) }
    return child
  }
  func commander() throws -> Commander {
    var commander = try f.f.f.f.work.f.commander()
    let inventory = try #require(commander.equipmentInventory)
    commander.savedEquipmentInventory = try .init(
      owner: inventory.owner, activeHull: inventory.activeHull,
      revision: booking.inventoryRevision, items: inventory.items)
    while commander.flightSimulation.visit < f.issue.dock.actor.visit {
      commander.flightSimulation.enter(
        NativeInductionCapacityOperator.clinic.station, arriving: true)
    }
    commander.flightSimulation.physicalTime = 1_000_200
    commander.scriptState.flightSeconds = 900_200
    commander.scriptState.nextEvent = 170
    commander.nativeStations?.mainStations += [f.issue.dock.station, f.source.delegation.auditor]
    commander.nativeStations?.nextMainDockSequence = 106
    commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction = held
    for sequence: UInt64 in [150, 151, 160, 161] {
      commander.scriptState.instances[f.issue.parent]?.acknowledge(sequence)
    }
    commander.scriptState.instances[booking.instance] = child()
    return commander
  }
  func close(_ kind: NativeInductionClinicUncollectedClose.Kind = .cancelled) throws
    -> NativeInductionClinicUncollectedClose
  {
    let capacity = try #require(held.charterCapacity)
    let window = try capacity.returnQuote(reservation: booking.window.operation, reason: .cancelled)
    let player = ActorIdentity(
      system: booking.dock.actor.system, visit: booking.dock.actor.visit, entity: 0)
    let operation = try NativeInductionClinicUncollectedClose.identity(
      booking: booking.operation,
      stockRevision: 1, kind: kind, window: window.operation, player: player,
      carrier: booking.carrier, fit: 1, time: 1_000_161, flightSeconds: 900_161, sequence: 161)
    let resource = ScriptStationResource(
      identity: booking.dock.station.resource,
      galaxy: 0, system: 185, energy: 0, destroyed: true)
    let context = ScriptEventContext(
      galaxy: 0, system: 185, docked: false, mainStation: false,
      revision: 0, frameSeconds: 900_161, localSeconds: 900_161, flightSeconds: 900_161,
      calendarSeconds: 1_000_161, transitSeconds: 0, playerPosition: nil)
    let loss = WayfarerColdChainPhysicalLoss(
      cause: .shipDestroyed, sequence: 161,
      context: context, energy: 0, visit: player.visit)
    return .init(
      operation: operation, sequence: 161, instance: booking.instance,
      booking: booking.operation, stockRevision: 1, kind: kind, window: window,
      player: player, carrier: booking.carrier, inventoryRevision: 1,
      physicalTime: 1_000_161, flightSeconds: 900_161,
      dock: kind == .cancelled ? booking.dock : nil,
      loss: kind == .carrierExit ? loss : nil, sourceLoss: kind == .sourceLost ? resource : nil)
  }
  func closing(_ close: NativeInductionClinicUncollectedClose) throws
    -> NativeWayfarerInductionState
  {
    let source = try #require(held.charterClinicSource)
    let capacity = try #require(held.charterCapacity)
    return try held.updatingClinic(
      source.applying(NativeInductionClinicSave.stockEvent(close, booking: booking)),
      capacity: capacity.returning(close.window))
  }
}

struct NativeWayfarerInductionClinicAcceptanceUnitTests {
  @Test func acceptanceReservesSameOriginalSampleOwnerWindowAndOneRealTonneWithoutPickupOrProgress()
    throws
  {
    let f = try InductionClinicAcceptanceFixture()
    #expect(f.held.valid && f.booking.valid(parent: f.held))
    let source = try #require(f.held.charterClinicSource)
    #expect(source.units[0].status == .held && source.units[0].instance == f.booking.instance)
    #expect(source.units.dropFirst().allSatisfy { $0.status == .available })
    #expect(f.booking.window.owner == source.issue.operatorOwner)
    #expect(f.held.milestones == f.available.milestones && f.held.payloads == f.available.payloads)
    #expect(f.booking.terms.rewardNative == 3200 + 850 * f.booking.route.distancesLY.count)
    let child = f.child()
    #expect(child.savedNativeInductionClinic?.reservedCargoTonnes == 1)
    #expect(child.payloads.isEmpty && child.timers.isEmpty && child.milestones.isEmpty)
    #expect(NativeInductionClinicSave.shapeValid(child))
    var commander = try f.commander()
    #expect(NativeInductionClinicSave.validateClaims(commander))
    let occupied = try #require(commander.checkedCargoTonnes)
    commander.scriptState.instances.removeValue(forKey: child.id)
    #expect(commander.checkedCargoTonnes == occupied - 1)
  }
  @Test func cancellationReturnsSameWarehouseSampleAndWindowOnceAndRequiresFreshProtectedRelease()
    throws
  {
    let f = try InductionClinicAcceptanceFixture()
    let close = try f.close()
    let next = try f.closing(close)
    #expect(next.valid && close.valid(booking: f.booking, parent: next))
    let stock = try #require(next.charterClinicSource)
    #expect(stock.units == f.f.source.units && stock.revision == 2)
    let capacity = try #require(next.charterCapacity)
    let slots = try capacity.projection()
    #expect(slots.filter { $0.unit.protected }.count == 6)
    #expect(slots.allSatisfy { $0.reservation == nil })
    #expect(!slots.contains { capacity.eligible($0) })
    #expect(throws: (any Error).self) {
      try f.closing(close).updatingClinic(stock, capacity: capacity)
    }
    #expect(f.child(close: close).savedNativeInductionClinic?.reservedCargoTonnes == 0)
    #expect(f.child(close: close).outcome == .abandoned)
    #expect(next.milestones == f.held.milestones && next.payloads == f.held.payloads)
    #expect(
      NativeInductionClinicBooking.instance(
        source: stock.identity, unit: f.booking.unit, revision: 2) != f.booking.instance)
  }
  @Test func uncollectedCarrierLossReleasesUnchangedWarehouseStockButDestroyedSourceNeverRestocks()
    throws
  {
    let f = try InductionClinicAcceptanceFixture()
    for kind: NativeInductionClinicUncollectedClose.Kind in [.carrierExit, .sourceLost] {
      let close = try f.close(kind)
      let next = try f.closing(close)
      #expect(close.valid(booking: f.booking, parent: next))
      let child = f.child(close: close)
      #expect(
        child.outcome == .failed && child.savedNativeInductionClinic?.reservedCargoTonnes == 0)
      let stock = try #require(next.charterClinicSource)
      #expect(stock.units[0].status == (kind == .sourceLost ? .failed : .available))
      #expect(stock.units[0].instance == (kind == .sourceLost ? f.booking.instance : nil))
      #expect(next.milestones == f.held.milestones)
      var commander = try f.commander()
      commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction = next
      commander.scriptState.instances[f.booking.instance] = child
      if let resource = close.sourceLoss {
        commander.scriptState.stationResources[resource.key] = resource
      }
      #expect(NativeInductionClinicSave.validateClaims(commander))
    }
  }
  @Test func stockHistoryCannotReorderRepeatReuseOldInstanceOrInventHeldSerials() throws {
    let f = try InductionClinicAcceptanceFixture()
    var source = try #require(f.held.charterClinicSource)
    let reserve = NativeInductionClinicSave.stockEvent(f.booking)
    #expect(throws: (any Error).self) { try source.applying(reserve) }
    source.history = [reserve, reserve]
    #expect(!source.valid(parent: f.held))
    source = try #require(f.held.charterClinicSource)
    source.units[1].status = .held
    source.units[1].instance = f.booking.instance
    #expect(!source.valid(parent: f.held))
    let close = try f.close()
    let closed = try f.closing(close)
    source = try #require(closed.charterClinicSource)
    source.history?.reverse()
    #expect(!source.valid(parent: closed))
  }
  @Test func saveJoinsRequireOriginalChildAcknowledgementsClockAndExactStockWindowReceipt() throws {
    let f = try InductionClinicAcceptanceFixture()
    var commander = try f.commander()
    #expect(NativeInductionClinicSave.validateClaims(commander))
    let child = try #require(commander.scriptState.instances[f.booking.instance])
    commander.scriptState.instances.removeValue(forKey: child.id)
    #expect(!NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.instances[child.id] = child
    commander.scriptState.instances[child.id]?.acknowledgedEvents = []
    commander.scriptState.instances[child.id]?.acknowledgedThrough = nil
    #expect(!NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.instances[child.id] = child
    commander.scriptState.flightSeconds = 900_159
    #expect(!NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.flightSeconds = 900_200
    commander.scriptState.instances[child.id]?.payloads = ["invented": 1]
    #expect(!NativeInductionClinicSave.validateClaims(commander))
  }
  @Test func globalThreeContractLimitAndActualCargoFitIncludeUncollectedClinicBookings() throws {
    let f = try InductionClinicAcceptanceFixture()
    var commander = try f.commander()
    #expect(
      commander.requiresContractFit
        && commander.tradeCargoCapacity == commander.standardCargoCapacity)
    #expect(OriginalServiceReservationPolicy.activeCount(commander.scriptState) == 1)
    // Occupancy is derived; fabricated identity copies must still fail the independent authority join.
    for _ in 0..<2 {
      var child = ScriptInstance(
        id: UUID(), definition: NativeInductionClinicPack.stateID,
        version: NativeInductionClinicPack.version, digest: NativeInductionClinicPack.digest)
      child.savedNativeInductionClinic = f.child().savedNativeInductionClinic
      commander.scriptState.instances[child.id] = child
    }
    #expect(OriginalServiceReservationPolicy.activeCount(commander.scriptState) == 3)
    #expect(throws: (any Error).self) {
      try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    }
    #expect(!NativeInductionClinicSave.validateClaims(commander))
  }
  @Test func laterOperatorConsentUsesActualHistoricalReservationClockWithoutDroppingClinicState()
    throws
  {
    let f = try InductionClinicAcceptanceFixture()
    let capacity = try #require(f.held.charterCapacity)
    let signature = try f.f.f.signature(
      .workshop, capacity: capacity,
      sequence: 162, time: 1_000_162, flightSeconds: 900_162)
    let next = try f.held.recordingCharterConsent(signature)
    #expect(next.valid && next.charterClinicSource == f.held.charterClinicSource)
    var commander = try f.commander()
    commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction = next
    commander.scriptState.instances[f.booking.parent]?.acknowledge(162)
    while commander.flightSimulation.visit < signature.dock.actor.visit {
      commander.flightSimulation.enter(signature.dock.actor.system, arriving: true)
    }
    if commander.nativeStations?.mainStations.contains(signature.dock.station) != true {
      commander.nativeStations?.mainStations.append(signature.dock.station)
    }
    let previousDockSequence = commander.nativeStations?.nextMainDockSequence ?? 0
    commander.nativeStations?.nextMainDockSequence = max(
      previousDockSequence, signature.dock.sequence + 1)
    let parent = try #require(commander.scriptState.instances[f.booking.parent])
    #expect(
      NativeInductionCharterConsentSave.signaturesValid(
        [signature], mission: parent, commander: commander))
    let early = try f.f.f.signature(
      .workshop, capacity: capacity,
      sequence: 159, time: 1_000_159, flightSeconds: 900_159)
    #expect(
      !NativeInductionCharterConsentSave.signaturesValid(
        [early], mission: parent, commander: commander))
  }
  @Test func bookingWindowUsesOnlyClinicOwnerAndRefusesDelegatedReadOnlyScope() throws {
    let f = try InductionClinicAcceptanceFixture()
    var game = Game()
    game.commander = try f.commander()
    game.commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction = f.available
    let quote = try f.f.quote(parent: f.available)
    let window = try game.inductionClinicWindow(quote: quote)
    #expect(window == f.booking.window && window.owner == f.f.issue.operatorOwner)
    let audit = try f.f.quote(
      parent: f.available, scope: .avenorReadOnlyAudit, dock: f.f.auditorDock)
    #expect(throws: (any Error).self) { try game.inductionClinicWindow(quote: audit) }
    game.commander.scriptState.instances[f.booking.parent]?.savedWayfarerInduction = f.held
    #expect(throws: (any Error).self) { try game.inductionClinicWindow(quote: quote) }
  }
  @Test func changedSourceUnitOwnerOfferPriceAndCarrierCannotKeepAcceptedAuthority() throws {
    let f = try InductionClinicAcceptanceFixture()
    let original = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.booking)) as? [String: Any])
    for key in ["unit", "operatorOwner", "offer", "carrier", "source", "issue", "epoch"] {
      var raw = original
      raw[key] = UUID().uuidString
      let bytes = try JSONSerialization.data(withJSONObject: raw)
      let booking = try JSONDecoder().decode(NativeInductionClinicBooking.self, from: bytes)
      #expect(!booking.valid(parent: f.held))
    }
    var raw = original
    var terms = try #require(raw["terms"] as? [String: Any])
    terms["rewardNative"] = 999999
    raw["terms"] = terms
    let bytes = try JSONSerialization.data(withJSONObject: raw)
    let changed = try JSONDecoder().decode(NativeInductionClinicBooking.self, from: bytes)
    #expect(!changed.valid(parent: f.held))
  }
  @Test func closedAcceptanceSchemaRejectsEarlierEmbeddedUnknownOrUnpairedNativeClaims() throws {
    let f = try InductionClinicAcceptanceFixture()
    let child = f.child()
    let bytes = try JSONEncoder().encode(child)
    var raw = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    func data() throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [child.id.uuidString: raw]])
    }
    for schema in [111, 112] {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
    }
    for schema in [107, 108, 109, 110] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: schema)
      }
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": try JSONSerialization.jsonObject(with: data())
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(embedded, part: .commander, schema: 111)
    }
    let alias = try JSONSerialization.data(withJSONObject: ["nativeInductionClinic": [:]])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(alias, part: .missions, schema: 111)
    }
    let restored = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
    #expect(restored == child)
    var leaf = try #require(raw["savedNativeInductionClinic"] as? [String: Any])
    leaf["freeCargo"] = true
    raw["savedNativeInductionClinic"] = leaf
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: 111)
    }
    raw.removeValue(forKey: "savedNativeInductionClinic")
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(data(), part: .missions, schema: 111)
    }
    #expect(NativeInductionArkSave.isAlien(110) && NativeInductionArkSave.isAlien(112))
  }
}
