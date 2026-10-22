import Foundation

enum NativeIsolationWorkParentAction: String, Sendable {
  case accept, progress
  var key: String { NativeIsolationWorkParent.stateID + "/" + rawValue }
}
struct NativeIsolationWorkParentReview: Sendable {
  let action: NativeIsolationWorkParentAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let resources: CommanderSnapshot
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { action == .accept && issues.isEmpty }
}

extension Game {
  var isolationWorkParentMission: ScriptInstance? {
    commander.scriptState.instances.values.first(where: NativeIsolationWorkParent.marked)
  }
  var isolationWorkParentRows: [ContractBoardRow] {
    guard scriptPacks.contains(where: NativeIsolationWorkParent.matches),
      isolationWorkParentMission != nil || contractStation == NativeIsolationWorkParent.station
    else { return [] }
    let action: NativeIsolationWorkParentAction =
      isolationWorkParentMission == nil ? .accept : .progress
    return [
      .init(
        board: action.key, offer: nil, title: "Lerr / External isolation work",
        reason: isolationWorkParentReview(action).issues.first, isolationWorkParent: action)
    ]
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
    return .init(
      action: action, arrival: arrival, owner: commander.equipmentOwnerID,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
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
      quote.resources.value == commander.contractQuoteResources,
      let arrival = current.arrival, let revision = current.inventoryRevision
    else {
      throw MissionPackError("The isolation commission or actual property changed; review again.")
    }
    var candidate = self
    let parent = try candidate.stageIsolationParent(
      arrival: arrival, expectedInventoryRevision: revision)
    try candidate.authorizeIsolationWork(parentID: parent.parentID)
    candidate.emitScriptEvent("mission.accepted", only: parent.parentID)
    candidate.notify("LERR COMMISSION ACCEPTED - ORIGINAL PROGRAMMER HELD, 1t")
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
    if isolationWorkParentMission != nil {
      lines.append(
        "Original commission retained. Receiving/payment is not yet available in this bridge.")
    }
    lines += (contractBoard.isolationWorkParentQuote ?? isolationWorkParentReview(.accept)).issues
    return lines
  }
}
