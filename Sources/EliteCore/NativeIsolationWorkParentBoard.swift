import Foundation

enum NativeIsolationWorkParentAction: String, Sendable {
  case accept, progress, receive, returnUnpaid, abandon
  var key: String { NativeIsolationWorkParent.stateID + "/" + rawValue }
}
struct NativeIsolationWorkParentReview: Sendable {
  let action: NativeIsolationWorkParentAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let parentRevision: UInt64?
  let sourceRevision: UInt64?
  let epoch: UUID
  let resources: CommanderSnapshot
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { action != .progress && issues.isEmpty }
}

extension Game {
  var isolationWorkParentMission: ScriptInstance? {
    commander.scriptState.instances.values.first(where: NativeIsolationWorkParent.marked)
  }
  var isolationWorkParentRows: [ContractBoardRow] {
    guard scriptPacks.contains(where: NativeIsolationWorkParent.matches),
      isolationWorkParentMission != nil || contractStation == NativeIsolationWorkParent.station
    else { return [] }
    guard let parent = isolationWorkParentMission else {
      return [
        .init(
          board: NativeIsolationWorkParentAction.accept.key, offer: nil,
          title: "Lerr / External isolation work",
          reason: isolationWorkParentReview(.accept).issues.first,
          isolationWorkParent: .accept)
      ]
    }
    var actions: [NativeIsolationWorkParentAction] = [.progress]
    if contractStation == NativeIsolationWorkParent.station {
      if parent.outcome == .active { actions.append(.receive) }
      if (try? NativeIsolationProgrammerCustody.resolve(parent: parent, commander: commander))
        != nil
      {
        actions.append(.returnUnpaid)
      }
    }
    if parent.outcome == .active { actions.append(.abandon) }
    return actions.map { action in
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: isolationWorkParentReview(action).issues.first, isolationWorkParent: action)
    }
  }
  func isolationWorkParentReview(_ action: NativeIsolationWorkParentAction)
    -> NativeIsolationWorkParentReview
  {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    var issues: [String] = []
    if action == .accept {
      if isMissionTrial || paused || arrival == nil
        || contractStation != NativeIsolationWorkParent.station
      {
        issues.append("Confirm at Lerr's actual living Avenor main berth while unpaused.")
      }
      if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
      if !scriptPacks.contains(where: NativeIsolationWorkParent.matches)
        || !scriptPacks.contains(where: NativeIsolationWorkPack.matches)
      {
        issues.append("Restore the approved external isolation commission.")
      }
      if isolationWorkParentMission != nil
        || NativeIsolationProgrammerCustody.hasIssuedOriginal(in: commander)
      {
        issues.append(
          "The one original source/programmer is already reserved or issued; no replacement stock is available."
        )
      }
      if commander.scriptState.instances.count >= 127 {
        issues.append("The mission record capacity is full.")
      }
      do { try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState) } catch
      { issues.append(error.localizedDescription) }
      if commander.equipmentInventory == nil || commander.hullInstanceID == nil {
        issues.append("Restore the actual owned hull and inventory.")
      }
      if let reason = isolationWorkParentRouteIssue { issues.append(reason) }
      // Use the real issue machinery in a discarded candidate to quote the existing projected budget.
      if issues.isEmpty {
        var preview = commander
        var parent = ScriptInstance(
          id: Self.contractJobIdentity(
            NativeIsolationWorkParent.offer(owner: preview.equipmentOwnerID!).id),
          definition: NativeIsolationWorkParent.stateID, version: NativeIsolationWorkParent.version,
          digest: NativeIsolationWorkParent.digest)
        do {
          _ = try issueScriptGearWithReceipt(
            NativeIsolationProgrammerDefinition.gear, fields: ["fit": .bool(false)],
            command: UUID(),
            state: &parent, candidate: &preview)
        } catch {
          issues.append(
            "The original programmer requires one real free tonne and valid canonical custody.")
        }
      }
    }
    if [.receive, .returnUnpaid, .abandon].contains(action) {
      if isMissionTrial || paused || !scriptDurabilityAvailable || !docked
        || (arrival == nil && nativeStationBoardContext == nil)
      {
        issues.append("Review at a living native station with a writable commander save.")
      }
      guard let parent = isolationWorkParentMission else {
        return .init(
          action: action, arrival: arrival, owner: commander.equipmentOwnerID,
          carrier: commander.hullInstanceID,
          inventoryRevision: commander.equipmentInventory?.revision,
          parentRevision: nil, sourceRevision: isolationWorkChild?.revision,
          epoch: nativeStationRuntimeEpoch,
          resources: CommanderSnapshot(commander.contractQuoteResources),
          issues: ["No original isolation job is reserved."])
      }
      if action == .receive {
        if let arrival, let issue = isolationWorkReceptionIssue(at: arrival) {
          issues.append(issue)
        }
        if arrival == nil { issues.append("Use Lerr's actual later Avenor doorway.") }
      } else if action == .returnUnpaid {
        if arrival?.receipt.station != parent.savedIsolationWorkParent?.acceptance.station {
          issues.append("Return the original only to Lerr at Avenor.")
        }
        if (try? NativeIsolationProgrammerCustody.resolve(parent: parent, commander: commander))
          == nil
        {
          issues.append("The original is already returned or lost; no replacement can be returned.")
        }
      } else if parent.outcome != .active {
        issues.append("This job is already ended; no further settlement is available.")
      }
    }
    return .init(
      action: action, arrival: arrival, owner: commander.equipmentOwnerID,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      parentRevision: isolationWorkParentMission?.revision,
      sourceRevision: isolationWorkChild?.revision,
      epoch: nativeStationRuntimeEpoch,
      resources: CommanderSnapshot(commander.contractQuoteResources), issues: issues)
  }
  var isolationWorkParentRouteIssue: String? {
    let systems = Universe.systemsIncludingPlugh(number: 0)
    let distance = systems[7].distance(to: systems[185])
    let reach = ScriptCourierReach(commander)
    if distance > reach.firstReach {
      return "The direct Avenor-Renas leg exceeds current usable fuel or fitted range."
    }
    if distance > reach.laterReach {
      return "The direct Renas-Avenor return exceeds this hull's full-tank reach."
    }
    return nil
  }
  mutating func confirmIsolationWorkParent(_ quote: NativeIsolationWorkParentReview) throws {
    let current = isolationWorkParentReview(quote.action)
    guard quote.allowed, current.allowed, quote.arrival == current.arrival,
      quote.owner == current.owner, quote.carrier == current.carrier,
      quote.inventoryRevision == current.inventoryRevision,
      quote.parentRevision == current.parentRevision,
      quote.sourceRevision == current.sourceRevision,
      quote.epoch == nativeStationRuntimeEpoch,
      quote.resources.value == commander.contractQuoteResources,
      quote.action == current.action
    else {
      throw MissionPackError("The isolation commission or actual property changed; review again.")
    }
    var candidate = self
    switch quote.action {
    case .accept:
      guard let arrival = current.arrival, let revision = current.inventoryRevision else {
        throw SaveError.invalidCommander
      }
      let parent = try candidate.stageIsolationParent(
        arrival: arrival, expectedInventoryRevision: revision)
      try candidate.authorizeIsolationWork(parentID: parent.parentID)
      candidate.emitScriptEvent("mission.accepted", only: parent.parentID)
      candidate.notify("LERR COMMISSION ACCEPTED - ORIGINAL PROGRAMMER HELD, 1t")
    case .receive:
      guard let arrival = current.arrival else { throw SaveError.invalidCommander }
      try candidate.receiveIsolationWork(at: arrival)
    case .returnUnpaid:
      guard let arrival = current.arrival else { throw SaveError.invalidCommander }
      try candidate.returnIsolationProgrammerUnpaid(at: arrival)
    case .abandon: try candidate.abandonIsolationWork()
    case .progress: throw SaveError.invalidCommander
    }
    self = candidate
  }
  func isolationWorkParentDetail() -> [String] {
    var lines = [
      "LERR / EXTERNAL ISOLATION WORK",
      "Avenor -> Renas -> Avenor / L2 H0 / frozen reward 970 CR.",
      "No fee, deposit or deadline. Refuelling is separate and is not prepaid.",
      "Carry the one original 1t programmer; isolate and verify both original Renas feeders.",
      "Return the same programmer to Lerr at Avenor. No replacement or second original stock.",
      "Payment and the family clue require both verified isolations and actual original return.",
    ]
    if let parent = isolationWorkParentMission {
      lines.append("JOB " + parent.outcome.rawValue.uppercased())
      if let source = isolationWorkChild?.savedIsolationWork {
        for module in source.modules {
          lines.append(
            module.role.name + ": "
              + (module.verification == nil ? "ZERO FLOW NOT YET VERIFIED" : "ZERO FLOW VERIFIED"))
        }
      }
      if parent.outcome != .active {
        lines.append(
          "This original source remains retained. No second attempt or replacement stock is available."
        )
      }
    }
    let action =
      contractBoard.selected?.isolationWorkParent
      ?? (isolationWorkParentMission == nil ? .accept : .progress)
    lines += (contractBoard.isolationWorkParentQuote ?? isolationWorkParentReview(action)).issues
    return lines
  }
}

extension NativeIsolationWorkParentAction {
  var title: String {
    switch self {
    case .accept: "Lerr / External isolation work"
    case .progress: "Lerr / Original isolation job progress"
    case .receive: "Complete isolation / return original - 970 CR"
    case .returnUnpaid: "Return original unpaid / abandon job"
    case .abandon: "End job unpaid / keep original owed until Lerr return"
    }
  }
}
