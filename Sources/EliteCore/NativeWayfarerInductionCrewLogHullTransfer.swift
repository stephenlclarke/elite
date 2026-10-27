import Foundation

/// Last attained portable-property transfer. Pickup equipment/hull facts stay immutable history.
struct NativeCrewLogHullCustody: Codable, Sendable, Equatable {
  let owner: UUID
  let capture: UUID
  let previousHull: UUID
  let hull: UUID
  let previousRevision: UInt64
  let inventoryRevision: UInt64
  let operation: UUID

  init(
    capture: NativeCrewLogCapture, owner: UUID,
    from previous: OwnedEquipmentInventory, to current: OwnedEquipmentInventory
  ) {
    self.owner = owner
    self.capture = capture.operation
    previousHull = previous.activeHull
    hull = current.activeHull
    previousRevision = previous.revision
    inventoryRevision = current.revision
    operation = Self.identity(
      capture: capture.operation, owner: owner,
      previous: previous.activeHull, hull: current.activeHull,
      previousRevision: previous.revision, revision: current.revision)
  }
  static func identity(
    capture: UUID, owner: UUID, previous: UUID, hull: UUID,
    previousRevision: UInt64, revision: UInt64
  ) -> UUID {
    ScriptIdentity.uuid(
      "induction-recorder-hull-custody-v1:\(capture):\(owner):\(previous):\(hull):\(previousRevision):\(revision)"
    )
  }
  func valid(capture: NativeCrewLogCapture, owner: UUID) -> Bool {
    self.owner == owner && self.capture == capture.operation && previousHull != hull
      && previousRevision >= capture.inventoryRevision && previousRevision < UInt64(Int64.max) - 1
      && inventoryRevision == previousRevision + 1
      && operation
        == Self.identity(
          capture: capture.operation, owner: owner,
          previous: previousHull, hull: hull, previousRevision: previousRevision,
          revision: inventoryRevision)
  }
}

extension NativeWayfarerInductionState {
  var crewLogCarrier: UUID? { crewLogHullCustody?.hull ?? crewLog?.carrier }
  var crewLogInventoryRevision: UInt64? {
    crewLogHullCustody?.inventoryRevision ?? crewLog?.inventoryRevision
  }

  func transferringCrewLog(
    from previous: OwnedEquipmentInventory, to current: OwnedEquipmentInventory
  )
    throws -> NativeWayfarerInductionState
  {
    guard valid, let crewLog, crewLogLoss == nil, rescueReception == nil,
      previous.owner == permission.owner, current.owner == permission.owner,
      previous.activeHull == crewLogCarrier, previous.activeHull != current.activeHull,
      previous.revision >= (crewLogInventoryRevision ?? UInt64.max),
      previous.revision < UInt64(Int64.max) - 1, current.revision == previous.revision + 1
    else { throw SaveError.invalidCommander }
    let custody = NativeCrewLogHullCustody(
      capture: crewLog, owner: permission.owner,
      from: previous, to: current)
    let next = NativeWayfarerInductionState(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogHullCustody: custody)
    guard next.valid, next.payloads == payloads, next.milestones == milestones else {
      throw SaveError.invalidCommander
    }
    return next
  }
}

extension Commander {
  /// Called only by the actual portable-fitting exchange after the owned inventories change.
  mutating func transferInductionCrewLog(
    from previous: OwnedEquipmentInventory,
    to current: OwnedEquipmentInventory
  ) throws {
    guard previous.activeHull != current.activeHull else { return }
    guard equipmentInventory == current, current.owner == previous.owner else {
      throw SaveError.invalidCommander
    }
    for id in scriptState.instances.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard var parent = scriptState.instances[id], let leaf = parent.savedWayfarerInduction,
        leaf.crewLog != nil, leaf.crewLogLoss == nil, leaf.rescueReception == nil
      else { continue }
      guard parent.revision < UInt64(Int64.max) - 1 else { throw SaveError.invalidCommander }
      parent.savedWayfarerInduction = try leaf.transferringCrewLog(from: previous, to: current)
      parent.revision += 1
      scriptState.instances[id] = parent
    }
  }
}
