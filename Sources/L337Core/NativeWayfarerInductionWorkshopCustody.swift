import Foundation

extension Game {
  func inductionWorkshopChild(_ id: UUID, forLoss: Bool = false) throws -> ScriptInstance {
    guard let child = commander.scriptState.instances[id], child.outcome == .active,
      forLoss || (child.suspension == nil && nativeInductionWorkshopPack != nil),
      let contract = child.savedNativeInductionWorkshop, contract.end == nil,
      contract.booking.commanderOwner == commander.equipmentOwnerID,
      contract.booking.carrier == commander.hullInstanceID,
      (commander.equipmentInventory?.revision ?? 0)
        >= (contract.service?.inventoryRevision ?? contract.pickup?.inventoryRevision
          ?? contract.booking.inventoryRevision),
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      throw MissionPackError(
        "The original workshop serial, same owned carrier and native custody are required.")
    }
    return child
  }
  private mutating func commitWorkshopProgress(
    _ contract: NativeInductionWorkshopContract,
    child: inout ScriptInstance, sequence: UInt64, message: String
  ) throws {
    guard var parent = commander.scriptState.instances[contract.booking.parent],
      let state = parent.savedWayfarerInduction, contract.valid(parent: state), contract.end == nil,
      parent.revision < UInt64(Int64.max) - 1, child.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      sequence == commander.scriptState.nextEvent + 1
    else { throw SaveError.invalidCommander }
    let occupied = commander.checkedCargoTonnes
    child.savedNativeInductionWorkshop = contract
    child.payloads = contract.payloads
    child.revision += 1
    child.acknowledge(sequence)
    child.journal.append(message)
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    guard commander.checkedCargoTonnes == occupied,
      NativeInductionCrewLogSave.validateClaims(commander)
    else { throw SaveError.invalidCommander }
  }
  mutating func confirmInductionWorkshopPickup(_ id: UUID) throws {
    var child = try inductionWorkshopChild(id)
    guard let contract = child.savedNativeInductionWorkshop, contract.pickup == nil,
      let fit = commander.equipmentInventory?.revision,
      let occupied = commander.checkedCargoTonnes, occupied <= commander.standardCargoCapacity,
      commander.passengerFit?.allowed == true,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let dock = try inductionClinicCurrentDock(NativeInductionWorkshopProfile.original.source)
    guard dock.station == contract.booking.dock.station else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let contact = WayfarerColdChainContact(
      sequence: sequence, dock: dock, context: scriptEventContext(child))
    let time = commander.flightSimulation.physicalTime
    let operation = try NativeInductionWorkshopPickup.identity(
      booking: contract.booking.operation,
      contact: contact, carrier: contract.booking.carrier, fit: fit, time: time)
    let pickup = NativeInductionWorkshopPickup(
      operation: operation, booking: contract.booking.operation,
      contact: contact, carrier: contract.booking.carrier, inventoryRevision: fit,
      physicalTime: time)
    let next = NativeInductionWorkshopContract(booking: contract.booking, pickup: pickup)
    try commitWorkshopProgress(
      next, child: &child, sequence: sequence,
      message:
        "The same original failed2t workshop serial is aboard, replacing its existing hold reservation. Actual Renas service and original Enmadan return remain required. Untimed; no perishability clock or hidden deadline."
    )
    notify("ORIGINAL FAILED WORKSHOP SERIAL ABOARD - 2T / UNTIMED")
  }
  mutating func confirmInductionWorkshopService(_ id: UUID) throws {
    var child = try inductionWorkshopChild(id)
    guard let contract = child.savedNativeInductionWorkshop, let pickup = contract.pickup,
      contract.service == nil, contract.cancellation == nil,
      let fit = commander.equipmentInventory?.revision,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let dock = try inductionClinicCurrentDock(NativeInductionWorkshopProfile.original.workshop)
    let sequence = commander.scriptState.nextEvent + 1
    let contact = WayfarerColdChainContact(
      sequence: sequence, dock: dock, context: scriptEventContext(child))
    let time = commander.flightSimulation.physicalTime
    let operation = try NativeInductionWorkshopService.identity(
      pickup: pickup.operation,
      unit: contract.booking.unit, serial: contract.booking.serial, contact: contact,
      carrier: contract.booking.carrier, fit: fit, time: time)
    let before = contract.condition
    let after = try before.serviced(sourceUnit: contract.booking.unit, operation: operation)
    let service = NativeInductionWorkshopService(
      operation: operation, pickup: pickup.operation,
      unit: contract.booking.unit, serial: contract.booking.serial, contact: contact,
      carrier: contract.booking.carrier, inventoryRevision: fit, physicalTime: time, before: before,
      after: after)
    let next = NativeInductionWorkshopContract(
      booking: contract.booking, pickup: pickup, service: service)
    try commitWorkshopProgress(
      next, child: &child, sequence: sequence,
      message:
        "Actual Renas service restored continuity on the same original failed serial. The workshop retains ownership; its2t cargo and window remain held until actual original Enmadan receiving. No cloned unit, equipment grant or payment."
    )
    notify("ORIGINAL WORKSHOP SERIAL SERVICED - RETURN TO ENMADAN")
  }
  mutating func confirmInductionWorkshopHeldCancellation(_ id: UUID) throws {
    var child = try inductionWorkshopChild(id)
    guard let contract = child.savedNativeInductionWorkshop, let pickup = contract.pickup,
      contract.cancellation == nil, commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let dock = try inductionClinicCurrentDock()
    let sequence = commander.scriptState.nextEvent + 1
    let contact = WayfarerColdChainContact(
      sequence: sequence, dock: dock, context: scriptEventContext(child))
    let time = commander.flightSimulation.physicalTime
    let operation = try NativeInductionWorkshopCancellation.identity(
      pickup: pickup.operation, contact: contact, time: time)
    let cancellation = NativeInductionWorkshopCancellation(
      operation: operation, pickup: pickup.operation,
      contact: contact, physicalTime: time)
    let next = NativeInductionWorkshopContract(
      booking: contract.booking, pickup: pickup,
      service: contract.service, cancellation: cancellation)
    try commitWorkshopProgress(
      next, child: &child, sequence: sequence,
      message:
        "Workshop delivery cancelled after pickup. Keep the same original serial, actual current condition,2t cargo and owner's window until actual Enmadan return or recorded irretrievable loss. No cash or immediate reservation release."
    )
    notify("ORIGINAL WORKSHOP RETURN REQUIRED - SERIAL / WINDOW STILL HELD")
  }
}
