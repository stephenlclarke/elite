import Foundation

extension Game {
  func inductionClinicWindow(quote: NativeInductionClinicQuote) throws
    -> NativeInductionCapacityReservation
  {
    guard quote.scope == .ownerStation,
      let parent = wayfarerInductionMission?.savedWayfarerInduction,
      let source = parent.charterClinicSource, let capacity = parent.charterCapacity,
      quote.issue == source.issue.operation, quote.stockRevision == source.revision,
      quote.capacityRevision == capacity.revision,
      quote.capacityFingerprint == (try? capacity.fingerprint),
      let slot = try capacity.projection().first(where: {
        $0.unit.owner == source.issue.operatorOwner && capacity.eligible($0)
      })
    else { throw SaveError.invalidCommander }
    let instance = NativeInductionClinicBooking.instance(
      source: source.identity,
      unit: quote.offer.stockUnit, revision: source.revision)
    return try capacity.quote(consignment: instance, unit: slot.unit.identity)
  }
  func inductionClinicBookingIssues(unit: UUID?) -> [String] {
    guard let unit, let mission = wayfarerInductionMission,
      mission.hasInductionServiceAuthority(in: commander.scriptState),
      mission.suspension == nil, let state = mission.savedWayfarerInduction,
      let source = state.charterClinicSource, let capacity = state.charterCapacity,
      source.units.contains(where: {
        $0.id == unit && $0.status == .available && $0.instance == nil
      }),
      let resource = commander.scriptState.stationResources[
        source.issue.profile.source.resourceKey],
      !resource.destroyed, resource.energy > 0,
      resource.identity == source.issue.dock.station.resource,
      commander.scriptState.stationResources[source.issue.profile.receiver.resourceKey]?.destroyed
        != true,
      nativeInductionClinicPack != nil,
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "Restore the original available sample, living source/receiver and current clinic authority."
      ]
    }
    guard OriginalServiceReservationPolicy.activeCount(commander.scriptState) < 3 else {
      return ["Three Original contracts or Wayfarer services are already active."]
    }
    guard commander.scriptState.instances.count < 128, source.revision < 511,
      capacity.revision < 511,
      let occupied = commander.checkedCargoTonnes,
      occupied < commander.standardCargoCapacity,
      commander.passengerFit?.allowed == true
    else {
      return [
        "Keep one real free hold tonne, a valid fitting and room for the booking/return records."
      ]
    }
    guard let slots = try? capacity.projection(),
      slots.contains(where: {
        $0.unit.owner == source.issue.operatorOwner && capacity.eligible($0)
      })
    else {
      return ["No eligible clinic-owned window. Protected policy needs a separate owner release."]
    }
    return []
  }
  func inductionClinicCancellationIssues(instance: UUID?) -> [String] {
    guard let instance, let child = commander.scriptState.instances[instance],
      let contract = child.savedNativeInductionClinic, contract.close == nil,
      contract.custody == nil,
      contract.booking.commanderOwner == commander.equipmentOwnerID,
      child.outcome == .active, child.suspension == nil,
      NativeInductionCrewLogSave.validateClaims(commander)
    else { return ["Only the actual owner's uncollected original booking can be cancelled once."] }
    return []
  }
  mutating func confirmInductionClinicBooking(
    quote: NativeInductionClinicQuote,
    window: NativeInductionCapacityReservation
  ) throws {
    let fresh = try inductionClinicReadOnlyQuote(unit: quote.offer.stockUnit)
    guard inductionClinicBookingIssues(unit: quote.offer.stockUnit).isEmpty,
      fresh.offer.id == quote.offer.id, window == (try inductionClinicWindow(quote: fresh)),
      var parent = wayfarerInductionMission, let state = parent.savedWayfarerInduction,
      let source = state.charterClinicSource, let capacity = state.charterCapacity,
      commander.scriptState.instances[window.consignment] == nil,
      parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let operation = try NativeInductionClinicBooking.identity(
      instance: window.consignment,
      offer: fresh.offer.id, window: window.operation, dock: fresh.dock,
      carrier: fresh.carrier, fit: fresh.inventoryRevision, time: time,
      flightSeconds: clock, sequence: sequence)
    let booking = NativeInductionClinicBooking(
      operation: operation, instance: window.consignment,
      sequence: sequence, parent: parent.id, commanderOwner: source.issue.commanderOwner,
      operatorOwner: source.issue.operatorOwner, source: source.identity,
      issue: source.issue.operation,
      unit: fresh.offer.stockUnit, epoch: source.issue.epoch, familyDigest: fresh.familyDigest,
      offer: fresh.offer.id, stockRevision: source.revision, window: window,
      route: fresh.route, terms: fresh.terms, dock: fresh.dock, carrier: fresh.carrier,
      inventoryRevision: fresh.inventoryRevision, runtimeEpoch: fresh.runtimeEpoch,
      physicalTime: time, flightSeconds: clock)
    let stock = try source.applying(NativeInductionClinicSave.stockEvent(booking))
    let nextCapacity = try capacity.reserving(window)
    let next = try state.updatingClinic(stock, capacity: nextCapacity)
    guard booking.valid(parent: next) else { throw SaveError.invalidCommander }
    var child = ScriptInstance(
      id: booking.instance, definition: NativeInductionClinicPack.stateID,
      version: NativeInductionClinicPack.version, digest: NativeInductionClinicPack.digest)
    child.savedNativeInductionClinic = .init(booking: booking)
    child.acknowledge(sequence)
    child.journal = [
      "Original sample/window and1t hold space reserved. No pickup or integrity clock yet; quoted route sets price, not compulsory flight hops."
    ]
    parent.savedWayfarerInduction = next
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    guard NativeInductionClinicSave.validateClaims(commander),
      let occupied = commander.checkedCargoTonnes, occupied <= commander.standardCargoCapacity
    else { throw SaveError.invalidCommander }
    notify("CLINIC SAMPLE / WINDOW / 1T RESERVED - PICKUP IS SEPARATE")
  }
  mutating func closeInductionClinicBooking(
    instance: UUID,
    cause: WayfarerColdChainLossCause? = nil, sourceDestroyed: Bool = false
  ) throws {
    guard var child = commander.scriptState.instances[instance],
      let contract = child.savedNativeInductionClinic, contract.close == nil,
      contract.custody == nil,
      child.outcome == .active, child.revision < UInt64(Int64.max) - 1,
      var parent = commander.scriptState.instances[contract.booking.parent],
      let state = parent.savedWayfarerInduction, let source = state.charterClinicSource,
      let capacity = state.charterCapacity,
      contract.booking.commanderOwner == commander.equipmentOwnerID,
      let player = commander.flightSimulation.player,
      let carrier = commander.hullInstanceID, let fit = commander.equipmentInventory?.revision,
      parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    if let cause {
      guard !docked, energy.isFinite,
        cause == .shipDestroyed ? screen == .gameOver && energy <= 0 : screen.isFlight && energy > 0
      else { throw MissionPackError("Actual attained native carrier exit is required.") }
    }
    let sourceLoss = commander.scriptState.stationResources[source.issue.profile.source.resourceKey]
    let lost = sourceLoss?.destroyed == true
    if sourceDestroyed && !lost { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let kind: NativeInductionClinicUncollectedClose.Kind =
      lost ? .sourceLost : cause == nil ? .cancelled : .carrierExit
    let window = try capacity.returnQuote(
      reservation: contract.booking.window.operation, reason: .cancelled)
    let operation = try NativeInductionClinicUncollectedClose.identity(
      booking: contract.booking.operation,
      stockRevision: source.revision, kind: kind, window: window.operation, player: player,
      carrier: carrier, fit: fit, time: time, flightSeconds: clock, sequence: sequence)
    let loss =
      !lost
      ? cause.map {
        WayfarerColdChainPhysicalLoss(
          cause: $0, sequence: sequence, context: scriptEventContext(child),
          energy: max(0, energy), visit: commander.flightSimulation.visit)
      } : nil
    let close = NativeInductionClinicUncollectedClose(
      operation: operation, sequence: sequence,
      instance: instance, booking: contract.booking.operation, stockRevision: source.revision,
      kind: kind, window: window, player: player, carrier: carrier, inventoryRevision: fit,
      physicalTime: time, flightSeconds: clock,
      dock: cause == nil ? commander.nativeStations?.currentMainDock : nil,
      loss: loss, sourceLoss: lost ? sourceLoss : nil)
    let next = try state.updatingClinic(
      source.applying(NativeInductionClinicSave.stockEvent(close, booking: contract.booking)),
      capacity: capacity.returning(window))
    let closed = NativeInductionClinicContract(booking: contract.booking, close: close)
    guard closed.valid(parent: next) else { throw SaveError.invalidCommander }
    child.savedNativeInductionClinic = closed
    child.outcome = closed.outcome
    child.revision += 1
    child.acknowledge(sequence)
    child.journal.append(
      lost
        ? "Original source destroyed; sample failed, no restock or payment. Window and hold reservation released."
        : "Uncollected booking closed; the original unchanged warehouse sample, same owner's window and hold space are released. No payment or success."
    )
    parent.savedWayfarerInduction = next
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[instance] = child
  }
}
