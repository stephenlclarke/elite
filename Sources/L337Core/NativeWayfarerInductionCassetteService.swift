import Foundation

/// One native desk transaction services the same original and records its owner's receipt.
struct NativeInductionCassetteService: Codable, Sendable, Equatable {
  let operation: UUID
  let returnOperation: UUID
  let cassetteOperation: UUID
  let unit: UUID
  let ownerStation: NativeMainStationIdentity
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let before: NativeRepairLoopCondition
  let after: NativeRepairLoopCondition

  func valid(cassette: NativeInductionWorkshopCassette, owner: UUID) -> Bool {
    guard cassetteOperation == cassette.operation, unit == cassette.unit,
      ownerStation == cassette.dock.station, dock.valid,
      dock.commanderOwner == owner, dock.station.world == owner,
      dock.station.system == NativeWayfarerInduction.clinic,
      dock.sequence > cassette.dock.sequence, dock.actor.visit > cassette.dock.actor.visit,
      dock.calendarSeconds >= cassette.dock.calendarSeconds,
      physicalTime.isFinite, physicalTime >= cassette.physicalTime, physicalTime <= 1e12,
      flightSeconds.isFinite, flightSeconds >= cassette.flightSeconds, flightSeconds <= 1e12,
      before == .failed(sourceUnit: cassette.unit),
      after == (try? before.serviced(sourceUnit: cassette.unit, operation: operation)),
      operation
        == (try? NativeWayfarerInduction.continuationOperation(
          target: NativeWayfarerInduction.repairTarget, previous: cassette.operation,
          dock: dock, carrier: carrier, revision: inventoryRevision, flightSeconds: flightSeconds))
    else { return false }
    return returnOperation
      == NativeWayfarerInduction.cassetteReturnOperation(
        service: operation, unit: unit, ownerStation: ownerStation)
  }
}

extension NativeWayfarerInduction {
  static let repairTarget = "renas-cassette-loop-closed"
  static func cassetteReturnOperation(
    service: UUID, unit: UUID, ownerStation: NativeMainStationIdentity
  ) -> UUID {
    ScriptIdentity.uuid(
      "induction-cassette-owner-return-v1:\(service):\(unit):\(ownerStation.key)")
  }
}

extension NativeWayfarerInductionState {
  func servicingCassette(_ receipt: NativeInductionCassetteService) throws -> Self {
    guard valid, cassette != nil, cassetteLoss == nil, cassetteService == nil else {
      throw SaveError.invalidCommander
    }
    let next = Self(
      permission: permission, crate: crate, reception: reception, cassette: cassette,
      cassetteService: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}

extension Game {
  func inductionCassetteService(
    _ state: NativeWayfarerInductionState, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, physicalTime: Double, flightSeconds: Double
  ) throws -> NativeWayfarerInductionState {
    guard let cassette = state.cassette,
      nativeMainStationDockEvidenceIsCurrent, commander.nativeStations?.currentMainDock == dock,
      systemIdentity == NativeWayfarerInduction.clinic, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision
    else { throw SaveError.invalidCommander }
    let operation = try NativeWayfarerInduction.continuationOperation(
      target: NativeWayfarerInduction.repairTarget, previous: cassette.operation,
      dock: dock, carrier: carrier, revision: revision, flightSeconds: flightSeconds)
    let before = NativeRepairLoopCondition.failed(sourceUnit: cassette.unit)
    let after = try before.serviced(sourceUnit: cassette.unit, operation: operation)
    let receipt = NativeInductionCassetteService(
      operation: operation,
      returnOperation: NativeWayfarerInduction.cassetteReturnOperation(
        service: operation, unit: cassette.unit, ownerStation: cassette.dock.station),
      cassetteOperation: cassette.operation, unit: cassette.unit,
      ownerStation: cassette.dock.station, dock: dock, carrier: carrier,
      inventoryRevision: revision, physicalTime: physicalTime, flightSeconds: flightSeconds,
      before: before, after: after)
    return try state.servicingCassette(receipt)
  }
}
