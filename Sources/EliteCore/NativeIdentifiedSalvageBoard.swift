import Foundation

enum NativeIdentifiedSalvageAction: String, Sendable, Equatable {
  case accept, receive, cancel
  var key: String { NativeIdentifiedSalvage.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "PELL / accept depot retrieval permission"
    case .receive: "PELL / return original depot property"
    case .cancel: "PELL / return held property and cancel"
    }
  }
}

struct NativeIdentifiedSalvageReview: Sendable {
  let action: NativeIdentifiedSalvageAction
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let epoch: UUID
  let custody: String
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  var identifiedSalvagePack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeIdentifiedSalvage.stateID
        && $0.digest == NativeIdentifiedSalvage.digest
        && $0.manifest.identifiedSalvage?.valid == true
    }
  }

  var identifiedSalvageRows: [ContractBoardRow] {
    guard identifiedSalvagePack != nil else { return [] }
    let actions: [NativeIdentifiedSalvageAction]
    if let state = identifiedSalvageState {
      let active = commander.scriptState.instances[state.permission.mission]?.outcome == .active
      guard state.reception == nil else { return [] }
      if active {
        actions = [.receive, .cancel]
      } else {
        actions = state.held.isEmpty ? [] : [.receive]
      }
    } else {
      guard commander.scriptState.savedIdentifiedSalvageSource == nil,
        contractStation == NativeIdentifiedSalvage.source
      else { return [] }
      actions = [.accept]
    }
    return actions.map { action in
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: identifiedSalvageReview(action).issues.first, identifiedSalvage: action)
    }
  }

  func identifiedSalvageReview(_ action: NativeIdentifiedSalvageAction)
    -> NativeIdentifiedSalvageReview
  {
    var issues: [String] = []
    if !nativeMainStationDockEvidenceIsCurrent || contractStation != NativeIdentifiedSalvage.source
    {
      issues.append("Use the actual Avenor recovery depot; PELL represents that property's owner.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save.") }
    if identifiedSalvagePack == nil { issues.append("Restore the original PELL recovery content.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil {
      issues.append("Use the actual owned collecting carrier.")
    }
    let state = identifiedSalvageState
    switch action {
    case .accept:
      if commander.scriptState.savedIdentifiedSalvageSource != nil {
        issues.append("This finite depot incident is already allocated; it cannot be replenished.")
      }
      if !hasIdentifiedSalvageTools {
        issues.append("Fit targeting, Salvage targeting and Fuel Scoops.")
      }
      if NativeIdentifiedSalvage.route(reach: ScriptCourierReach(commander)) != [7, 185, 7] {
        issues.append("Refuel or refit for the actual Renas return route.")
      }
      if let used = commander.checkedCargoTonnes {
        if used > commander.standardCargoCapacity - 2 {
          issues.append("Free two actual hold tonnes.")
        }
      } else {
        issues.append("The current hold claim is invalid.")
      }
      if OriginalServiceReservationPolicy.activeCount(commander.scriptState)
        >= OriginalServiceReservationPolicy.maximumActive
      {
        issues.append("Three Original contracts or services are already active.")
      }
    case .receive, .cancel:
      if let state, state.reception == nil,
        let mission = commander.scriptState.instances[state.permission.mission]
      {
        if commander.hullInstanceID != state.permission.carrier {
          issues.append("Return in the same collecting carrier.")
        }
        if action == .cancel, mission.outcome != .active {
          issues.append("This job has already failed; return any surviving held original.")
        }
        if action == .receive {
          if mission.outcome == .active {
            if state.held.count != 2 || !state.losses.isEmpty {
              issues.append(
                "Recover both exact original serials before successful owner reception.")
            }
          } else if mission.outcome != .failed || state.held.isEmpty {
            issues.append("No surviving held original is waiting for this owner return.")
          }
        }
      } else {
        issues.append("There is no unreconciled original depot permission.")
      }
    }
    let custody =
      state.map { state in
        ([state.permission.operation.uuidString]
          + state.captures.map { $0.operation.uuidString }
          + state.losses.map { $0.operation.uuidString }
          + state.held.map(\.uuidString)
          + [state.reception?.operation.uuidString ?? "open"]).joined(separator: ":")
      } ?? "unallocated"
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      epoch: nativeStationRuntimeEpoch, custody: custody, issues: issues)
  }

  mutating func confirmIdentifiedSalvage(_ review: NativeIdentifiedSalvageReview) throws {
    let current = identifiedSalvageReview(review.action)
    guard review.allowed, current.allowed, review.dock == current.dock,
      review.carrier == current.carrier, review.inventoryRevision == current.inventoryRevision,
      review.epoch == current.epoch, review.custody == current.custody,
      let pack = identifiedSalvagePack
    else { throw MissionPackError("The depot, carrier or original custody changed. Review again.") }
    var candidate = self
    switch review.action {
    case .accept: try candidate.acceptIdentifiedSalvage(pack)
    case .receive, .cancel: try candidate.receiveIdentifiedSalvage(cancel: review.action == .cancel)
    }
    self = candidate
  }

  private mutating func acceptIdentifiedSalvage(_ pack: ScriptPack) throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard commander.scriptState.savedIdentifiedSalvageSource == nil,
      let dock = commander.nativeStations?.currentMainDock,
      let collector = commander.flightSimulation.player, let carrier = commander.hullInstanceID,
      let inventory = commander.equipmentInventory, let definition = pack.manifest.identifiedSalvage
    else { throw SaveError.invalidCommander }
    let sourceID = NativeIdentifiedSalvage.sourceIdentity(dock.station)
    let key = pack.digest + "/identified-salvage/" + NativeIdentifiedSalvage.source.key
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(key):0:\(NativeIdentifiedSalvage.batch)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw SaveError.invalidCommander
    }
    let offer = ScriptContractOffer(
      id: offerID, key: NativeIdentifiedSalvage.batch, title: "PELL / L2 H0 / 880 CR / untimed",
      briefing: pack.manifest.mission.briefing, destinationGalaxy: 0, destinationSystem: 7,
      reward: NativeIdentifiedSalvage.reward, deposit: 0, failureReward: 0,
      refundOnFailure: false, duration: 0, parameters: .object([:]))
    var accepted = offer
    accepted.status = .accepted(missionID)
    commander.contracts.boards[key] = .init(
      id: NativeIdentifiedSalvage.boardID, provider: pack.manifest.id,
      version: pack.manifest.version, digest: pack.digest, title: "PELL original depot recovery",
      station: NativeIdentifiedSalvage.source, revision: 0, seed: 0, clock: .local,
      period: 3600, group: NativeIdentifiedSalvage.stateID, offers: [accepted])
    let source = NativeIdentifiedSalvageSource(
      id: sourceID, owner: dock.station, batch: NativeIdentifiedSalvage.batch,
      originals: NativeIdentifiedSalvage.originals(dock.station),
      allocatedMission: missionID, registration: dock)
    let state = NativeIdentifiedSalvageState(
      source: sourceID, definition: definition,
      permission: .init(
        mission: missionID,
        operation: ScriptIdentity.uuid("identified-salvage-permit-v1:\(sourceID):\(missionID)"),
        source: sourceID, dock: dock, collector: collector, carrier: carrier,
        inventoryRevision: inventory.revision, reach: ScriptCourierReach(commander),
        path: [7, 185, 7], physicalTime: commander.flightSimulation.physicalTime,
        epoch: nativeStationRuntimeEpoch))
    var mission = ScriptInstance(
      id: missionID, definition: NativeIdentifiedSalvage.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = .init(
      boardKey: key, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, station: NativeIdentifiedSalvage.source, boardRevision: 0,
      group: NativeIdentifiedSalvage.stateID, offer: offer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    mission.savedIdentifiedSalvage = state
    mission.payloads = NativeIdentifiedSalvage.payloads(state, outcome: .active, source: source)
    mission.milestones = [0]
    commander.scriptState.savedIdentifiedSalvageSource = source
    commander.scriptState.instances[missionID] = mission
    emitScriptEvent("mission.accepted", only: missionID)
    notify("PELL PERMISSION RECORDED - 2T RESERVED; ORIGINALS AT RENAS")
  }

  private mutating func receiveIdentifiedSalvage(cancel: Bool) throws {
    guard var state = identifiedSalvageState,
      var source = commander.scriptState.savedIdentifiedSalvageSource,
      var mission = commander.scriptState.instances[state.permission.mission],
      let dock = commander.nativeStations?.currentMainDock, dock.station == source.owner,
      nativeMainStationDockEvidenceIsCurrent, state.reception == nil,
      commander.hullInstanceID == state.permission.carrier
    else { throw SaveError.invalidCommander }
    let held = Set(state.held)
    let returning = source.originals.filter { held.contains($0.id) }.map(\.id)
    let complete =
      !cancel && mission.outcome == .active && returning.count == 2 && state.losses.isEmpty
    guard complete || cancel || (mission.outcome == .failed && !returning.isEmpty) else {
      throw MissionPackError("The owner requires both originals for a successful return.")
    }
    let cause = scriptEventContext(mission)
    state.reception = .init(
      operation: ScriptIdentity.uuid(
        "identified-salvage-receive-v1:\(state.permission.operation):\(dock.sequence)"),
      dock: dock, carrier: state.permission.carrier, originals: returning, complete: complete,
      cause: cause, committed: cause)
    guard let reception = state.reception else { throw SaveError.invalidCommander }
    for index in source.originals.indices where returning.contains(source.originals[index].id) {
      source.originals[index].custody = .returned(reception.operation)
    }
    commander.scriptState.savedIdentifiedSalvageSource = source
    if mission.outcome == .active {
      try finishIdentifiedSalvageMission(state, outcome: complete ? .complete : .abandoned)
    } else {
      mission.savedIdentifiedSalvage = state
      mission.payloads = NativeIdentifiedSalvage.payloads(
        state, outcome: mission.outcome, source: source)
      commander.scriptState.instances[mission.id] = mission
    }
    nativeIdentifiedSalvagePending = nil
    notify(
      complete
        ? "PELL ORIGINALS RETURNED - 880 CR PAYMENT RECORDED"
        : "PELL OWNER RETURN RECORDED - NO SUCCESS PAYMENT")
  }

  /// Native reception and native loss share settlement, never another family's custody proof.
  mutating func finishIdentifiedSalvageMission(
    _ state: NativeIdentifiedSalvageState, outcome: ScriptOutcome
  ) throws {
    guard var mission = commander.scriptState.instances[state.permission.mission],
      mission.outcome == .active, mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let source = commander.scriptState.savedIdentifiedSalvageSource
    else { throw SaveError.invalidCommander }
    let previous = mission
    let cause = scriptEventContext(mission)
    var candidate = commander
    try settleContract(outcome, state: &mission, candidate: &candidate)
    candidate.scriptState.nextEvent += 1
    let sequence = candidate.scriptState.nextEvent
    mission.outcome = outcome
    mission.revision += 1
    mission.dialogue = nil
    mission.acknowledge(sequence)
    if outcome == .complete { mission.milestones.insert(3) }
    var next = state
    commander = candidate
    let committed = scriptEventContext(mission)
    if let receipt = next.reception {
      next.reception = .init(
        operation: receipt.operation, dock: receipt.dock, carrier: receipt.carrier,
        originals: receipt.originals, complete: receipt.complete,
        cause: receipt.cause, committed: committed)
    }
    mission.savedIdentifiedSalvage = next
    mission.payloads = NativeIdentifiedSalvage.payloads(next, outcome: outcome, source: source)
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition, version: mission.version,
      digest: mission.digest, outcome: outcome, sequence: sequence,
      causeKind: "mission.receipted", cause: cause, committed: committed,
      revision: mission.revision, milestones: mission.milestones.sorted(), destroyedEncounters: [],
      deliveredParties: [], returnedEquipment: [],
      settlementAmount: mission.contract?.settlementAmount,
      choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
  }

  func identifiedSalvageDetail(_ action: NativeIdentifiedSalvageAction) -> [String] {
    var lines = [
      "PELL represents the actual Avenor recovery depot, which retains legal title.",
      "PELL-01 sealed utility controller; PELL-02 sealed power regulator; one tonne each.",
      "Avenor - Renas exterior cradle - Avenor; L2 H0; 880 CR only for both-original owner reception.",
      "Fit targeting, Salvage targeting and Fuel Scoops. Two real tonnes reserved; pickup fills each slot once.",
      "Use ordinary recovery selection and safe scoop approach. No cutter, cabins, deposit or deadline.",
      "These are protected original packages, not commodities or fit-able player equipment.",
      "Lost originals cannot be replaced. Return surviving held property without success payment.",
      "Back changes no source, permission, custody, capacity, cash or clue.",
    ]
    if let state = identifiedSalvageState,
      let source = commander.scriptState.savedIdentifiedSalvageSource
    {
      lines += source.originals.map { item in
        let status =
          state.held.contains(item.id)
          ? "held owner property"
          : state.losses.contains(where: { $0.original == item.id })
            ? "genuinely lost"
            : state.reception?.originals.contains(item.id) == true
              ? "returned to owner" : "at cradle"
        return "\(item.serial): \(item.name) / \(status)."
      }
    }
    return lines + (contractBoard.identifiedSalvageQuote ?? identifiedSalvageReview(action)).issues
  }
}
