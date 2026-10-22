import Foundation

extension Game {
  func inductionWorkshopReadOnlyQuote(
    unit: UUID? = nil,
    scope: NativeInductionWorkshopQuoteScope = .ownerStation
  ) throws -> NativeInductionWorkshopQuote {
    guard let mission = wayfarerInductionMission,
      mission.hasInductionServiceAuthority(in: commander.scriptState),
      mission.suspension == nil,
      let parent = mission.savedWayfarerInduction, let source = parent.charterWorkshopSource,
      nativeInductionWorkshopPack != nil,
      commander.equipmentOwnerID == source.issue.commanderOwner,
      let carrier = commander.hullInstanceID, let fit = commander.equipmentInventory?.revision,
      let resource = commander.scriptState.stationResources[
        source.issue.profile.source.resourceKey],
      resource.valid, !resource.destroyed, resource.energy > 0,
      resource.identity == source.issue.dock.station.resource,
      commander.scriptState.stationResources[source.issue.profile.workshop.resourceKey]?.destroyed
        != true,
      let unit = unit
        ?? source.units.first(where: { $0.status == .available && $0.instance == nil })?.id
    else {
      throw MissionPackError(
        "Restore the original available workshop serial, living source/service and owned fitting.")
    }
    let dock = try inductionClinicCurrentDock()
    return try .prepare(
      source: source, parent: parent, unit: unit, scope: scope, dock: dock,
      carrier: carrier, fit: fit, runtimeEpoch: nativeStationRuntimeEpoch,
      firstReachLY: commander.maximumJumpDistance, fullReachLY: commander.fullTankJumpDistance)
  }
  func inductionWorkshopSourceIssues() -> [String] {
    guard let mission = wayfarerInductionMission,
      mission.hasInductionServiceAuthority(in: commander.scriptState),
      mission.suspension == nil,
      let state = mission.savedWayfarerInduction, state.charterWorkshopSource == nil,
      state.charterSignatures?.contains(where: { $0.operatorID == .workshop }) == true,
      state.charterCapacity != nil, nativeInductionWorkshopPack != nil,
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "Original workshop consent and finite capacity must exist; this epoch's batch issues once only."
      ]
    }
    do { _ = try inductionClinicCurrentDock(NativeInductionWorkshopProfile.original.source) } catch
    { return ["Use the original workshop owner's actual living Enmadan main orbital."] }
    return []
  }
  mutating func confirmInductionWorkshopIssue(
    dock: NativeMainStationDockReceipt, carrier: UUID, fit: UInt64
  ) throws {
    guard inductionWorkshopSourceIssues().isEmpty,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == fit,
      var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      let choice = state.charterChoice, let capacity = state.charterCapacity,
      let consent = state.charterSignatures?.first(where: { $0.operatorID == .workshop }),
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionWorkshopIssue.identity(
      consent: consent.operation,
      allocation: capacity.allocation.operation, revision: capacity.revision,
      fingerprint: fingerprint,
      dock: dock, carrier: carrier, fit: fit, time: time, flightSeconds: clock, sequence: sequence)
    let issue = NativeInductionWorkshopIssue(
      operation: operation, sequence: sequence, parent: mission.id,
      commanderOwner: choice.owner,
      operatorOwner: NativeInductionCapacityOperator.workshop.owner(epoch: choice.terms.epoch),
      epoch: choice.terms.epoch, policy: choice.policy, consent: consent.operation,
      allocation: capacity.allocation.operation, capacityRevision: capacity.revision,
      capacityFingerprint: fingerprint, familyDigest: NativeInductionWorkshopPack.digest,
      profile: .original,
      dock: dock, carrier: carrier, inventoryRevision: fit, physicalTime: time, flightSeconds: clock
    )
    let source = try NativeInductionWorkshopSource(issue: issue, parent: state)
    mission.savedWayfarerInduction = try state.issuingWorkshopBatch(source)
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "Actual Enmadan owner issued this epoch's one original batch: six new unique2t failed workshop serials for Renas service and actual owner return. Separate Avenor read-only quote/refusal delegation. No cargo, window, payment, timer or stage12 grant."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify("ORIGINAL WORKSHOP BATCH RECORDED - SIX UNIQUE FAILED SERIALS")
  }
  func inductionWorkshopWindow(quote: NativeInductionWorkshopQuote) throws
    -> NativeInductionCapacityReservation
  {
    guard quote.scope == .ownerStation,
      let state = wayfarerInductionMission?.savedWayfarerInduction,
      let source = state.charterWorkshopSource, let capacity = state.charterCapacity,
      quote.issue == source.issue.operation, quote.stockRevision == source.revision,
      quote.capacityRevision == capacity.revision,
      quote.capacityFingerprint == (try? capacity.fingerprint),
      let slot = try capacity.projection().first(where: {
        $0.unit.owner == source.issue.operatorOwner && capacity.eligible($0)
      })
    else { throw SaveError.invalidCommander }
    let instance = NativeInductionWorkshopSource.instance(
      source: source.identity, unit: quote.offer.stockUnit, revision: source.revision)
    return try capacity.quote(consignment: instance, unit: slot.unit.identity)
  }
  func inductionWorkshopBookingIssues(unit: UUID?) -> [String] {
    guard let unit, let state = wayfarerInductionMission?.savedWayfarerInduction,
      let source = state.charterWorkshopSource, let capacity = state.charterCapacity,
      source.units.contains(where: {
        $0.id == unit && $0.status == .available && $0.instance == nil
      }),
      nativeInductionWorkshopPack != nil, NativeInductionCrewLogSave.validateClaims(commander)
    else { return ["Restore the original available workshop stock and native owner authority."] }
    guard OriginalServiceReservationPolicy.activeCount(commander.scriptState) < 3 else {
      return ["Three Original contracts or Wayfarer services are already active."]
    }
    guard let occupied = commander.checkedCargoTonnes,
      occupied <= commander.standardCargoCapacity - 2,
      commander.passengerFit?.allowed == true, commander.scriptState.instances.count < 128,
      source.revision < 511, capacity.revision < 511
    else {
      return [
        "Keep two real free hold tonnes, valid fitting and room for original reservation/return records."
      ]
    }
    guard let slots = try? capacity.projection(),
      slots.contains(where: { $0.unit.owner == source.issue.operatorOwner && capacity.eligible($0) }
      )
    else {
      return [
        "No eligible workshop-owned window; protected policy needs a separate actual owner release."
      ]
    }
    return []
  }
  mutating func confirmInductionWorkshopBooking(
    quote: NativeInductionWorkshopQuote, window: NativeInductionCapacityReservation
  ) throws {
    let fresh = try inductionWorkshopReadOnlyQuote(unit: quote.offer.stockUnit)
    guard inductionWorkshopBookingIssues(unit: quote.offer.stockUnit).isEmpty,
      fresh.offer.id == quote.offer.id,
      window == (try inductionWorkshopWindow(quote: fresh)),
      var parent = wayfarerInductionMission, let state = parent.savedWayfarerInduction,
      let source = state.charterWorkshopSource, let capacity = state.charterCapacity,
      commander.scriptState.instances[window.consignment] == nil,
      parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let operation = NativeInductionWorkshopBooking.identity(
      instance: window.consignment, offer: fresh.offer.id,
      window: window.operation, time: time, flightSeconds: clock, sequence: sequence)
    let booking = NativeInductionWorkshopBooking(
      operation: operation, instance: window.consignment,
      sequence: sequence, parent: parent.id, commanderOwner: source.issue.commanderOwner,
      operatorOwner: source.issue.operatorOwner, source: source.identity,
      issue: source.issue.operation,
      unit: fresh.offer.stockUnit, serial: fresh.offer.serial, epoch: source.issue.epoch,
      familyDigest: source.issue.familyDigest, offer: fresh.offer.id,
      stockRevision: source.revision,
      window: window, route: fresh.route, rewardNative: fresh.offer.rewardNative, dock: fresh.dock,
      carrier: fresh.carrier, inventoryRevision: fresh.inventoryRevision,
      runtimeEpoch: fresh.runtimeEpoch,
      physicalTime: time, flightSeconds: clock)
    let next = try state.updatingWorkshop(
      source.applying(NativeInductionWorkshopSave.stockEvent(booking)),
      capacity: capacity.reserving(window))
    guard booking.valid(parent: next) else { throw SaveError.invalidCommander }
    var child = ScriptInstance(
      id: booking.instance, definition: NativeInductionWorkshopPack.stateID,
      version: NativeInductionWorkshopPack.version, digest: NativeInductionWorkshopPack.digest)
    child.savedNativeInductionWorkshop = .init(booking: booking)
    child.acknowledge(sequence)
    child.journal = [
      "Original failed workshop serial, same owner's window and2t actual hold space reserved. Pickup/service/owner return are separate. Untimed; no cargo, payment or progress yet."
    ]
    parent.savedWayfarerInduction = next
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    guard NativeInductionWorkshopSave.validateClaims(commander) else {
      throw SaveError.invalidCommander
    }
    notify("ORIGINAL WORKSHOP SERIAL / WINDOW / 2T RESERVED")
  }
}
