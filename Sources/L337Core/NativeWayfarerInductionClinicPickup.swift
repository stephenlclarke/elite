import Foundation

extension Game {
  func inductionClinicCurrentDock(_ site: WayfarerColdChainSite? = nil) throws
    -> NativeMainStationDockReceipt
  {
    guard !isMissionTrial, !paused, docked, energy.isFinite, energy > 0,
      nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock,
      dock.commanderOwner == commander.equipmentOwnerID,
      site == nil || site?.matches(dock.station) == true,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else { throw MissionPackError("Use the actual declared living main orbital berth.") }
    return dock
  }
  func inductionClinicHeldChild(_ id: UUID, requiresTime: Bool = true) throws -> ScriptInstance {
    guard let child = commander.scriptState.instances[id], child.outcome == .active,
      let contract = child.savedNativeInductionClinic, let custody = contract.custody,
      custody.end == nil, contract.close == nil,
      contract.booking.commanderOwner == commander.equipmentOwnerID,
      contract.booking.carrier == commander.hullInstanceID,
      (commander.equipmentInventory?.revision ?? 0) >= custody.pickup.inventoryRevision,
      !requiresTime
        || (child.suspension == nil && child.timers == [custody.timer.id: custody.timer]
          && commander.scriptState.flightSeconds < custody.timer.due),
      nativeInductionClinicPack != nil,
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      throw MissionPackError(
        "The same original held sample, owned carrier and live integrity timer are required.")
    }
    return child
  }
  mutating func confirmInductionClinicPickup(_ id: UUID) throws {
    guard var child = commander.scriptState.instances[id], child.outcome == .active,
      child.suspension == nil, let contract = child.savedNativeInductionClinic,
      contract.close == nil, contract.custody == nil,
      contract.booking.commanderOwner == commander.equipmentOwnerID,
      contract.booking.carrier == commander.hullInstanceID,
      let fit = commander.equipmentInventory?.revision, fit >= contract.booking.inventoryRevision,
      var parent = commander.scriptState.instances[contract.booking.parent],
      let state = parent.savedWayfarerInduction, contract.valid(parent: state),
      let occupied = commander.checkedCargoTonnes, occupied <= commander.standardCargoCapacity,
      commander.passengerFit?.allowed == true, nativeInductionClinicPack != nil,
      NativeInductionCrewLogSave.validateClaims(commander),
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1
    else {
      throw MissionPackError(
        "The original reservation and actual hold/fitting must still be available.")
    }
    let dock = try inductionClinicCurrentDock(contract.booking.terms.source)
    guard dock.station == contract.booking.dock.station else { throw SaveError.invalidCommander }
    let now = commander.scriptState.flightSeconds
    guard now <= 1e12 - contract.booking.terms.flightAllowance else {
      throw SaveError.invalidCommander
    }
    let sequence = commander.scriptState.nextEvent + 1
    let context = scriptEventContext(child)
    let contact = WayfarerColdChainContact(sequence: sequence, dock: dock, context: context)
    let time = commander.flightSimulation.physicalTime
    let operation = try NativeInductionClinicPickup.identity(
      booking: contract.booking.operation,
      contact: contact, carrier: contract.booking.carrier, fit: fit, time: time)
    let pickup = NativeInductionClinicPickup(
      operation: operation, booking: contract.booking.operation,
      contact: contact, carrier: contract.booking.carrier, inventoryRevision: fit,
      physicalTime: time)
    let timer = ScriptTimer(
      id: NativeInductionClinicCustody.timerID, domain: .flight,
      due: now + contract.booking.terms.flightAllowance, interval: 0, policy: .once)
    let binding = WayfarerColdChainBinding(
      owner: contract.booking.commanderOwner,
      instance: id, consignment: contract.booking.unit,
      receiver: Self.worldResourceIdentity(
        "main-station-v1:" + contract.booking.terms.receiver.resourceKey), timerID: timer.id)
    let integrity = try WayfarerColdChain(
      snapshot: .init(binding: binding, timer: timer, context: context),
      allowance: contract.booking.terms.flightAllowance, issueSequence: sequence)
    let custody = NativeInductionClinicCustody(pickup: pickup, timer: timer, integrity: integrity)
    guard custody.valid(booking: contract.booking, parent: state) else {
      throw SaveError.invalidCommander
    }
    child.savedNativeInductionClinic = .init(booking: contract.booking, custody: custody)
    child.payloads = [NativeInductionClinicCustody.payload: 1]
    child.timers = [timer.id: timer]
    child.revision += 1
    child.acknowledge(sequence)
    child.journal.append(
      "The same original1t clinic sample is aboard. Its1800 qualifying-flight-second integrity clock starts at this actual pickup; the reserved tonne is now carried cargo."
    )
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[id] = child
    guard commander.checkedCargoTonnes == occupied,
      NativeInductionCrewLogSave.validateClaims(commander)
    else { throw SaveError.invalidCommander }
    notify("ORIGINAL CLINIC SAMPLE ABOARD - INTEGRITY 1800 FLIGHT SECONDS")
  }
  mutating func confirmInductionClinicHeldCancellation(_ id: UUID) throws {
    var child = try inductionClinicHeldChild(id)
    guard let contract = child.savedNativeInductionClinic, var custody = contract.custody,
      custody.cancellation == nil,
      var parent = commander.scriptState.instances[contract.booking.parent],
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let dock = try inductionClinicCurrentDock()
    let sequence = commander.scriptState.nextEvent + 1
    let context = scriptEventContext(child)
    let contact = WayfarerColdChainContact(sequence: sequence, dock: dock, context: context)
    let time = commander.flightSimulation.physicalTime
    let operation = try NativeInductionClinicHeldCancellation.identity(
      pickup: custody.pickup.operation,
      contact: contact, time: time)
    custody.cancellation = .init(
      operation: operation, pickup: custody.pickup.operation,
      contact: contact, physicalTime: time)
    custody = .init(
      pickup: custody.pickup, timer: custody.timer,
      integrity: try custody.integrity.observing(
        .init(binding: custody.integrity.binding, timer: custody.timer, context: context)),
      cancellation: custody.cancellation)
    child.savedNativeInductionClinic = .init(booking: contract.booking, custody: custody)
    child.revision += 1
    child.acknowledge(sequence)
    child.journal.append(
      "Delivery cancelled after pickup. Keep the same original sample and window reserved; return it to the original Renas owner. No stock, space, window or cash is released yet; integrity continues."
    )
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[id] = child
    notify("CLINIC RETURN REQUIRED - ORIGINAL SAMPLE / WINDOW STILL HELD")
  }
}
