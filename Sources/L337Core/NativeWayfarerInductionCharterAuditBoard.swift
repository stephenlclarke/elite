import Foundation

extension Game {
  var inductionCharterAuditRows: [ContractBoardRow] {
    guard systemIdentity == NativeWayfarerInduction.source,
      let state = wayfarerInductionMission?.savedWayfarerInduction,
      state.charterChoice != nil, state.charterCapacity != nil, state.charterAudit == nil
    else { return [] }
    let action = NativeWayfarerInductionAction.auditCharter
    return [
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: inductionCharterAuditIssues().first, wayfarerInduction: action)
    ]
  }
  func inductionCharterAuditIssues() -> [String] {
    guard let mission = wayfarerInductionMission, mission.outcome == .active,
      mission.suspension == nil, let parent = mission.savedWayfarerInduction,
      parent.charterAudit == nil, parent.charterSignatures?.count == 3,
      parent.charterCapacity != nil, NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "Obtain all three actual operator signatures for this charter before Avenor's capacity audit."
      ]
    }
    guard !paused, docked, energy > 0, nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock,
      dock.station.system == NativeWayfarerInduction.source,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else { return ["Return to the actual living Avenor main orbital to review the charter audit."] }
    return []
  }

  /// Route search happens only at review opening/Confirm, never board/detail drawing.
  func inductionCharterAuditCandidate() throws -> NativeInductionCharterAuditCandidate {
    guard inductionCharterAuditIssues().isEmpty,
      let parent = wayfarerInductionMission?.savedWayfarerInduction,
      let capacity = parent.charterCapacity, let choice = parent.charterChoice
    else { throw SaveError.invalidCommander }
    let slots = try capacity.projection()
    for operatorID in NativeInductionCapacityOperator.allCases {
      guard
        slots.contains(where: {
          $0.unit.operatorID == operatorID && $0.reservation == nil
            && (choice.policy == .pooledWindows
              ? $0.unit.protected : (!$0.unit.protected && $0.release == nil))
        })
      else { continue }
      let candidate: NativeInductionCharterAuditCandidate?
      switch operatorID {
      case .clinic:
        candidate = (try? inductionClinicReadOnlyQuote(scope: .avenorReadOnlyAudit)).map {
          .clinic($0)
        }
      case .workshop:
        candidate = (try? inductionWorkshopReadOnlyQuote(scope: .avenorReadOnlyAudit)).map {
          .workshop($0)
        }
      case .seed:
        candidate = (try? inductionSeedReadOnlyQuote(scope: .avenorReadOnlyAudit)).map { .seed($0) }
      }
      if let candidate { return candidate }
    }
    throw MissionPackError(
      "No real issued available source lot, current reachable quote and protected/unreleased same-owner window are available for the delegated audit."
    )
  }

  mutating func confirmInductionCharterAudit(_ candidate: NativeInductionCharterAuditCandidate)
    throws
  {
    guard inductionCharterAuditIssues().isEmpty,
      var mission = wayfarerInductionMission, let parent = mission.savedWayfarerInduction,
      commander.nativeStations?.currentMainDock == candidate.dock,
      commander.hullInstanceID == candidate.carrier,
      commander.equipmentInventory?.revision == candidate.inventoryRevision,
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let receipt = try NativeInductionCharterAudit.prepare(
      parent: parent, candidate: candidate,
      sequence: sequence, time: commander.flightSimulation.physicalTime,
      clock: commander.scriptState.flightSeconds)
    let next = try parent.auditingCharter(receipt)
    mission.savedWayfarerInduction = next
    mission.milestones = next.milestones
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "Avenor audited a real original available consignment under its actual source delegation and all three selected-policy signatures. The same finite acceptance policy refused its named protected/unreleased window unchanged. No booking, stock, cargo or cash moved. Stage12 charter record only; Veil certification remains separate."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify("CHARTER AUDIT RECORDED - VEIL CERTIFICATION NEXT")
  }

  var inductionCharterAuditDetail: [String] {
    var lines = [
      "AVENOR / ACTUAL CHARTER CAPACITY AUDIT",
      "Obtain clinic, workshop and seed signatures at their actual owner stations. At least one owner must issue its original finite batch and Avenor read-only delegation.",
      "A current reachable quote for an original still-available consignment supplies the candidate. The same acceptance policy must refuse a named protected minimum window (Pooled) or unreleased free surplus window (Protected).",
      "Confirm records that actual unchanged-state refusal and the three matching signatures. It creates no contract and changes no window, stock, cargo or cash. The independent three-active limit is not an audit proof.",
      "This records stage12 only. Veil certification and Senn's final payment/accreditation/clue need later separate receiving reviews. Back/Escape records nothing.",
    ]
    if let candidate = contractBoard.wayfarerInductionQuote?.charterAuditCandidate {
      lines.append(
        "Captured original operator: " + candidate.operatorID.rawValue
          + "; stock revision\(candidate.stockRevision), capacity revision\(candidate.capacityRevision). Confirm rechecks this exact quote."
      )
    }
    return lines + (contractBoard.wayfarerInductionQuote?.issues ?? [])
  }
}
