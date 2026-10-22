import Foundation

extension NativeWayfarerInductionAction {
  var charterPolicy: NativeInductionCharterPolicy? {
    switch self {
    case .pooledCharter: .pooledWindows
    case .protectedCharter: .protectedReservations
    default: nil
    }
  }
}

extension Game {
  func inductionCharterChoiceIssues() -> [String] {
    guard let mission = wayfarerInductionMission, mission.outcome == .active,
      mission.suspension == nil, let state = mission.savedWayfarerInduction,
      state.utilityReception != nil, state.charterChoice == nil,
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "Complete Enron's original three-handoff receiving first; an existing charter choice cannot be replaced."
      ]
    }
    guard let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationDockEvidenceIsCurrent,
      dock.station.system == NativeWayfarerInduction.source,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else { return ["Use the actual living Avenor main orbital to review both charter policies."] }
    return []
  }

  mutating func confirmInductionCharterChoice(
    _ policy: NativeInductionCharterPolicy,
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    guard inductionCharterChoiceIssues().isEmpty,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      let utility = state.utilityReception, mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let sequence = commander.scriptState.nextEvent + 1
    let epoch = NativeInductionCharterChoice.epoch(
      owner: state.permission.owner,
      parent: mission.id, utility: utility.operation)
    let terms = NativeInductionCharterTerms.original(epoch: epoch)
    let operation = try NativeInductionCharterChoice.identity(
      utility: utility.operation,
      policy: policy, terms: terms, dock: dock, carrier: carrier, revision: revision,
      time: time, flightSeconds: clock, sequence: sequence)
    let receipt = NativeInductionCharterChoice(
      operation: operation, sequence: sequence,
      owner: state.permission.owner, parent: mission.id, utility: utility.operation,
      policy: policy, terms: terms, dock: dock, carrier: carrier, inventoryRevision: revision,
      physicalTime: time, flightSeconds: clock)
    let chosen = try state.choosingCharter(receipt)
    let allocation = try NativeInductionCapacityAllocation(
      choice: receipt, dock: dock, carrier: carrier,
      revision: revision, time: time, flightSeconds: clock, sequence: sequence)
    let next = try chosen.allocatingCharterCapacity(.init(allocation: allocation))
    mission.savedWayfarerInduction = next
    mission.milestones = next.milestones
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "Avenor recorded the separately confirmed " + policy.rawValue
        + " charter choice. Each clinic/workshop/seed operator has six service-window units with protected minimum two in the same persistent epoch. "
        + policy.consequence
        + " Choice alone supplies no signatures, stage12 receipt, money or accreditation.")
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify("CHARTER CHOSEN: " + policy.title.uppercased() + " - OPERATOR SIGNATURES NEXT")
  }

  var inductionCharterDetail: [String] {
    guard let state = wayfarerInductionMission?.savedWayfarerInduction,
      state.utilityReception != nil
    else { return [] }
    let policy =
      contractBoard.wayfarerInductionQuote?.action.charterPolicy
      ?? contractBoard.selected?.wayfarerInduction?.charterPolicy
      ?? state.charterChoice?.policy
    if let accreditation = state.accreditation {
      return [
        "Stage14 complete: Senn accredited this commander under " + accreditation.policy.title
          + ", paid7600CR once and recorded the Exchange clue. The same entitlement opens advanced offered services; current original obligations and the shared three-active limit remain."
      ]
    }
    if state.networkCertification != nil {
      return [
        "Stage13: Veil certified the original network and selected charter. Senn's separate final receiving remains next; certification pays nothing and grants no accreditation or clue."
      ]
    }
    if let audit = state.charterAudit {
      return [
        "Stage12: actual Avenor charter audit recorded under the three matching signatures. The named "
          + audit.candidate.operatorID.rawValue
          + " window request was refused without changing capacity or original stock. Veil certification remains next; no payment, accreditation or clue."
      ]
    }
    let operatorDetail = inductionCharterOperatorDetail
    var lines =
      operatorDetail + [
        "Avenor charter choice: compare both policies before Confirm. Back/Escape changes nothing.",
        "Clinic, workshop and seed custodians each retain six indivisible service-window units for the same persistent charter epoch; protected minimum two each, eighteen total.",
        "One unit authorizes one concurrent independently quoted consignment. It is separate from ship cargo, tools, passenger space and the three-active-contract limit.",
        "POOLED WINDOWS: only each owner's free surplus above two can enter the pool (at most four per owner / twelve total); protected minimums cannot be borrowed.",
        "PROTECTED RESERVATIONS: no unit enters the pool until its original owner signs release of that exact free surplus unit. At most four per owner may release; the protected two stay unavailable.",
        "Saving, loading and revisiting cannot reset the epoch or replenish capacity. Completion/cancellation must return the same reservation to its original owner and selected policy.",
      ]
    if let policy, operatorDetail.isEmpty {
      lines.insert(
        "SELECTED POLICY: " + policy.title.uppercased() + ". " + policy.consequence, at: 0)
    }
    if let capacity = state.charterCapacity, let slots = try? capacity.projection() {
      lines.append(
        "Original persistent capacity: \(capacity.units.count) units / \(slots.filter { capacity.eligible($0) }.count) eligible free surplus / ledger revision\(capacity.revision). Actual owner consent/release remains separate from the choice; actual consignment booking/source audit is still pending."
      )
    } else if state.charterChoice != nil {
      lines.append(
        "This earlier choice has no capacity allocation. At actual Avenor, separately review/Confirm the still-unissued original ledger. Loading never issues units."
      )
    }
    if let choice = state.charterChoice {
      lines.append(
        "Stage11 choice recorded: " + choice.policy.title
          + ". Actual owner consents \(state.charterSignatures?.count ?? 0)/3. Visit Renas, Enmadan and Enlirin separately. Protected free-unit release needs its own review. Real consignment source/quote audit remains next; no stage12, payment, accreditation or clue."
      )
    } else {
      lines.append(
        "Confirm commits only this policy and its fixed original capacity source. Each operator must consent separately at their actual main orbital; protected unit release is a separate action. Real consignment/source audit remains next."
      )
    }
    return lines
  }
}
