import Foundation

extension NativeWayfarerInductionAction {
  var capacityOperator: NativeInductionCapacityOperator? {
    switch self {
    case .clinicConsent, .releaseClinicCapacity: .clinic
    case .workshopConsent, .releaseWorkshopCapacity: .workshop
    case .seedConsent, .releaseSeedCapacity: .seed
    default: nil
    }
  }
  var isCapacityRelease: Bool {
    [.releaseClinicCapacity, .releaseWorkshopCapacity, .releaseSeedCapacity].contains(self)
  }
  static func operatorAction(_ operatorID: NativeInductionCapacityOperator, release: Bool = false)
    -> Self
  {
    switch operatorID {
    case .clinic: release ? .releaseClinicCapacity : .clinicConsent
    case .workshop: release ? .releaseWorkshopCapacity : .workshopConsent
    case .seed: release ? .releaseSeedCapacity : .seedConsent
    }
  }
}

extension Game {
  var inductionCharterOperatorRows: [ContractBoardRow] {
    guard let state = wayfarerInductionMission?.savedWayfarerInduction,
      let capacity = state.charterCapacity,
      let operatorID = NativeInductionCapacityOperator.allCases.first(where: {
        $0.station == systemIdentity
      })
    else { return [] }
    let consentAction = NativeWayfarerInductionAction.operatorAction(operatorID)
    var rows: [ContractBoardRow] = []
    let signature = state.charterSignatures?.first { $0.operatorID == operatorID }
    rows.append(
      .init(
        board: consentAction.key, offer: nil,
        title: signature == nil ? consentAction.title : consentAction.title + " / SIGNED",
        reason: wayfarerInductionReview(consentAction).issues.first,
        wayfarerInduction: consentAction))
    guard signature != nil, capacity.allocation.policy == .protectedReservations,
      let slots = try? capacity.projection()
    else { return rows }
    let action = NativeWayfarerInductionAction.operatorAction(operatorID, release: true)
    for slot in slots
    where slot.unit.operatorID == operatorID && !slot.unit.protected
      && slot.release == nil && slot.reservation == nil
    {
      rows.append(
        .init(
          board: action.key, offer: nil,
          title: action.title + " / WINDOW\(slot.unit.slot + 1): " + slot.unit.identity.uuidString,
          reason: wayfarerInductionReview(action, capacityUnit: slot.unit.identity).issues.first,
          wayfarerInduction: action, inductionCapacityUnit: slot.unit.identity))
    }
    return rows
  }

  func inductionCharterOperatorIssues(_ action: NativeWayfarerInductionAction, unit: UUID?)
    -> [String]
  {
    guard let operatorID = action.capacityOperator,
      let mission = wayfarerInductionMission, mission.outcome == .active, mission.suspension == nil,
      let state = mission.savedWayfarerInduction, let capacity = state.charterCapacity,
      state.charterChoice != nil, NativeInductionCrewLogSave.validateClaims(commander)
    else { return ["Restore this owning charter and its original finite capacity source first."] }
    guard let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationDockEvidenceIsCurrent, systemIdentity == operatorID.station,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else {
      return ["Use this original operator's actual living main orbital for separate consent."]
    }
    let signature = state.charterSignatures?.first { $0.operatorID == operatorID }
    if !action.isCapacityRelease {
      return signature == nil
        ? []
        : [
          "This operator already signed the selected charter; this grants no stock or stage12 receipt."
        ]
    }
    guard signature != nil, capacity.allocation.policy == .protectedReservations,
      let unit, let slot = try? capacity.projection().first(where: { $0.unit.identity == unit }),
      slot.unit.operatorID == operatorID, !slot.unit.protected,
      slot.reservation == nil, slot.release == nil
    else {
      return [
        "Choose one named free surplus unit owned by this signed operator. Protected, foreign, reserved and already released units cannot release."
      ]
    }
    return []
  }

  mutating func confirmInductionCharterConsent(
    _ operatorID: NativeInductionCapacityOperator,
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    let action = NativeWayfarerInductionAction.operatorAction(operatorID)
    guard inductionCharterOperatorIssues(action, unit: nil).isEmpty,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      let choice = state.charterChoice, let capacity = state.charterCapacity,
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let sequence = commander.scriptState.nextEvent + 1
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionCharterSignature.identity(
      choice: choice.operation,
      allocation: capacity.allocation.operation, operatorID: operatorID,
      revision: capacity.revision,
      fingerprint: fingerprint, dock: dock, carrier: carrier, fit: revision,
      time: time, flightSeconds: clock, sequence: sequence)
    let signature = NativeInductionCharterSignature(
      operation: operation, sequence: sequence,
      choice: choice.operation, allocation: capacity.allocation.operation,
      epoch: choice.terms.epoch,
      policy: choice.policy, parent: mission.id, commanderOwner: choice.owner,
      operatorID: operatorID, operatorOwner: operatorID.owner(epoch: choice.terms.epoch),
      target: NativeInductionCharterSignature.target(operatorID, policy: choice.policy),
      units: try NativeFlightReception.hash(capacity.units.filter { $0.operatorID == operatorID }),
      capacityRevision: capacity.revision, capacityFingerprint: fingerprint,
      protectedMinimum: choice.terms.protectedMinimum, dock: dock, carrier: carrier,
      inventoryRevision: revision, physicalTime: time, flightSeconds: clock)
    let next = try state.recordingCharterConsent(signature)
    mission.savedWayfarerInduction = next
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      operatorID.rawValue.capitalized + " original owner separately signed " + signature.target
        + " at their actual main orbital against this epoch, fixed minimum, owned units and current ledger revision. No unit release, source stock, consignment, audit or stage12 receipt is inferred."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify(operatorID.rawValue.uppercased() + " OWNER CONSENT RECORDED - RELEASE IS SEPARATE")
  }

  mutating func confirmInductionCharterRelease(
    _ operatorID: NativeInductionCapacityOperator, unit: UUID,
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    let action = NativeWayfarerInductionAction.operatorAction(operatorID, release: true)
    guard inductionCharterOperatorIssues(action, unit: unit).isEmpty,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      let capacity = state.charterCapacity,
      let signature = state.charterSignatures?.first(where: { $0.operatorID == operatorID }),
      let original = capacity.units.first(where: { $0.identity == unit }),
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let sequence = commander.scriptState.nextEvent + 1
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionCapacityRelease.identity(
      allocation: capacity.allocation.operation,
      unit: unit, owner: original.owner, revision: capacity.revision, before: fingerprint,
      dock: dock, carrier: carrier, fit: revision, time: time, flightSeconds: clock,
      sequence: sequence, consent: signature.operation)
    let release = NativeInductionCapacityRelease(
      operation: operation,
      allocation: capacity.allocation.operation, epoch: capacity.allocation.epoch,
      policy: capacity.allocation.policy, revision: capacity.revision, unit: unit,
      owner: original.owner,
      operatorID: operatorID, dock: dock, carrier: carrier, inventoryRevision: revision,
      physicalTime: time, flightSeconds: clock, sequence: sequence, before: fingerprint,
      consent: signature.operation)
    let next = try state.releasingCharterUnit(release)
    mission.savedWayfarerInduction = next
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "Actual " + operatorID.rawValue + " owner separately released exact free surplus unit "
        + unit.uuidString
        + " for this protected charter. Other units retain their owner/policy; no minimum borrowing, consignment booking, source stock or stage12/audit receipt."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify("EXACT OWNER UNIT RELEASED - PROTECTED MINIMUM UNCHANGED")
  }
}

extension Game {
  var inductionCharterOperatorDetail: [String] {
    guard
      let action = contractBoard.wayfarerInductionQuote?.action
        ?? contractBoard.selected?.wayfarerInduction,
      let operatorID = action.capacityOperator,
      let state = wayfarerInductionMission?.savedWayfarerInduction,
      let capacity = state.charterCapacity
    else { return [] }
    var lines = [
      "ORIGINAL " + operatorID.rawValue.uppercased() + " OWNER / "
        + capacity.allocation.policy.title.uppercased(),
      "Consent is separate at this operator's actual main orbital: six original owned windows, protected minimum two; current ledger revision\(capacity.revision).",
    ]
    if action.isCapacityRelease {
      let unit =
        contractBoard.wayfarerInductionQuote?.capacityUnit
        ?? contractBoard.selected?.inductionCapacityUnit
      lines += [
        "RELEASE EXACT UNIT: " + (unit?.uuidString ?? "No free surplus unit selected"),
        "Confirm releases only this named free surplus unit with the original owner's signed authority. The protected two, other owners and unreleased units stay unavailable.",
        "This creates no consignment booking, source stock, cargo, money or stage12/audit receipt. Back/Escape releases nothing.",
      ]
    } else {
      lines += [
        "Confirm records only this original operator's selected-branch signature against the same epoch, owned unit ledger and revision. Other operators must consent separately.",
        "Signature does not release protected-policy units or issue source stock. It grants no consignment, audit, stage12 receipt, payment or accreditation. Back/Escape signs nothing.",
      ]
    }
    return lines
  }
}
