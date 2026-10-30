import Foundation

enum WayfarerRecordRecoveryAction: String, Sendable, Equatable {
  case accept, receive, cancel
  var key: String { WayfarerRecordRecovery.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "SENN / accept depot retrieval permission"
    case .receive: "SENN / return original depot property"
    case .cancel: "SENN / return held property and cancel"
    }
  }
}

struct WayfarerRecordRecoveryReview: Sendable {
  let action: WayfarerRecordRecoveryAction
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
  var recordRecoveryPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == WayfarerRecordRecovery.stateID
        && $0.digest == WayfarerRecordRecovery.digest
        && $0.manifest.recordRecovery?.valid == true
    }
  }

  var recordRecoveryRows: [ContractBoardRow] {
    guard recordRecoveryPack != nil else { return [] }
    let actions: [WayfarerRecordRecoveryAction]
    if let state = recordRecoveryState {
      let active = commander.scriptState.instances[state.permission.mission]?.outcome == .active
      guard state.reception == nil else { return [] }
      if active {
        actions = [.receive, .cancel]
      } else {
        actions = state.held.isEmpty ? [] : [.receive]
      }
    } else {
      guard commander.scriptState.savedRecordRecoverySource == nil,
        contractStation == WayfarerRecordRecovery.source
      else { return [] }
      actions = [.accept]
    }
    return actions.map { action in
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: recordRecoveryReview(action).issues.first, recordRecovery: action)
    }
  }

  func recordRecoveryReview(_ action: WayfarerRecordRecoveryAction)
    -> WayfarerRecordRecoveryReview
  {
    var issues: [String] = []
    if !nativeMainStationDockEvidenceIsCurrent || contractStation != WayfarerRecordRecovery.source {
      issues.append(
        "Use the actual Cedamar flight-record archive; SENN represents that property's owner.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save.") }
    if recordRecoveryPack == nil { issues.append("Restore the original SENN recovery content.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil {
      issues.append("Use the actual owned collecting carrier.")
    }
    let state = recordRecoveryState
    switch action {
    case .accept:
      if commander.scriptState.savedRecordRecoverySource != nil {
        issues.append(
          "This finite archive incident is already allocated; it cannot be replenished.")
      }
      if !hasRecordRecoveryTools {
        issues.append("Fit targeting, Salvage targeting and Fuel Scoops.")
      }
      if WayfarerRecordRecovery.route(reach: ScriptCourierReach(commander)) != [85, 241, 85] {
        issues.append("Refuel or refit for the actual Celalen return route.")
      }
      if let used = commander.checkedCargoTonnes {
        if used > commander.standardCargoCapacity - 1 {
          issues.append("Free one actual hold tonne.")
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
            if state.held.count != 1 || !state.losses.isEmpty {
              issues.append(
                "Identify and separately recover CDR-001 before successful custodian reception.")
            }
          } else if mission.outcome != .failed || state.held.isEmpty {
            issues.append("No surviving held original is waiting for this owner return.")
          }
        }
      } else {
        issues.append("There is no unreconciled original depot permission.")
      }
    }
    let custody: String
    if let state {
      let identification: String = state.identification?.operation.uuidString ?? "unidentified"
      var tokens: [String] = [state.permission.operation.uuidString, identification]
      let captures: [String] = state.captures.map { $0.operation.uuidString }
      let losses: [String] = state.losses.map { $0.operation.uuidString }
      let held: [String] = state.held.map(\.uuidString)
      let reception: String = state.reception?.operation.uuidString ?? "open"
      tokens.append(contentsOf: captures)
      tokens.append(contentsOf: losses)
      tokens.append(contentsOf: held)
      tokens.append(reception)
      custody = tokens.joined(separator: ":")
    } else {
      custody = "unallocated"
    }
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      epoch: nativeStationRuntimeEpoch, custody: custody, issues: issues)
  }

  mutating func confirmRecordRecovery(_ review: WayfarerRecordRecoveryReview) throws {
    let current = recordRecoveryReview(review.action)
    guard review.allowed, current.allowed, review.dock == current.dock,
      review.carrier == current.carrier, review.inventoryRevision == current.inventoryRevision,
      review.epoch == current.epoch, review.custody == current.custody,
      let pack = recordRecoveryPack
    else { throw MissionPackError("The depot, carrier or original custody changed. Review again.") }
    var candidate = self
    switch review.action {
    case .accept: try candidate.acceptRecordRecovery(pack)
    case .receive, .cancel: try candidate.receiveRecordRecovery(cancel: review.action == .cancel)
    }
    self = candidate
  }

  private mutating func acceptRecordRecovery(_ pack: ScriptPack) throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard commander.scriptState.savedRecordRecoverySource == nil,
      let dock = commander.nativeStations?.currentMainDock,
      let collector = commander.flightSimulation.player, let carrier = commander.hullInstanceID,
      let inventory = commander.equipmentInventory, let definition = pack.manifest.recordRecovery
    else { throw SaveError.invalidCommander }
    let sourceID = WayfarerRecordRecovery.sourceIdentity(dock.station)
    let key = pack.digest + "/record-recovery/" + WayfarerRecordRecovery.source.key
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(key):0:\(WayfarerRecordRecovery.batch)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw SaveError.invalidCommander
    }
    let offer = ScriptContractOffer(
      id: offerID, key: WayfarerRecordRecovery.batch, title: "SENN / L2 H0 / 650 CR / untimed",
      briefing: pack.manifest.mission.briefing, destinationGalaxy: 0, destinationSystem: 85,
      reward: WayfarerRecordRecovery.reward, deposit: 0, failureReward: 0,
      refundOnFailure: false, duration: 0, parameters: .object([:]))
    var accepted = offer
    accepted.status = .accepted(missionID)
    commander.contracts.boards[key] = .init(
      id: WayfarerRecordRecovery.boardID, provider: pack.manifest.id,
      version: pack.manifest.version, digest: pack.digest, title: "SENN original archive recovery",
      station: WayfarerRecordRecovery.source, revision: 0, seed: 0, clock: .local,
      period: 3600, group: WayfarerRecordRecovery.stateID, offers: [accepted])
    let source = WayfarerRecordRecoverySource(
      id: sourceID, owner: dock.station, batch: WayfarerRecordRecovery.batch,
      originals: WayfarerRecordRecovery.originals(dock.station),
      allocatedMission: missionID, registration: dock)
    let state = WayfarerRecordRecoveryState(
      source: sourceID, definition: definition,
      permission: .init(
        mission: missionID,
        operation: ScriptIdentity.uuid("record-recovery-permit-v1:\(sourceID):\(missionID)"),
        source: sourceID, dock: dock, collector: collector, carrier: carrier,
        inventoryRevision: inventory.revision, reach: ScriptCourierReach(commander),
        path: [85, 241, 85], physicalTime: commander.flightSimulation.physicalTime,
        epoch: nativeStationRuntimeEpoch))
    var mission = ScriptInstance(
      id: missionID, definition: WayfarerRecordRecovery.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = .init(
      boardKey: key, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, station: WayfarerRecordRecovery.source, boardRevision: 0,
      group: WayfarerRecordRecovery.stateID, offer: offer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    mission.savedRecordRecovery = state
    mission.payloads = WayfarerRecordRecovery.payloads(state, outcome: .active, source: source)
    mission.milestones = [0]
    commander.scriptState.savedRecordRecoverySource = source
    commander.scriptState.instances[missionID] = mission
    emitScriptEvent("mission.accepted", only: missionID)
    notify("SENN PERMISSION RECORDED - 1T RESERVED; ORIGINALS AT CELALEN")
  }

  private mutating func receiveRecordRecovery(cancel: Bool) throws {
    guard var state = recordRecoveryState,
      var source = commander.scriptState.savedRecordRecoverySource,
      var mission = commander.scriptState.instances[state.permission.mission],
      let dock = commander.nativeStations?.currentMainDock, dock.station == source.owner,
      nativeMainStationDockEvidenceIsCurrent, state.reception == nil,
      commander.hullInstanceID == state.permission.carrier
    else { throw SaveError.invalidCommander }
    let held = Set(state.held)
    let returning = source.originals.filter { held.contains($0.id) }.map(\.id)
    let complete =
      !cancel && mission.outcome == .active && returning.count == 1 && state.losses.isEmpty
    guard complete || cancel || (mission.outcome == .failed && !returning.isEmpty) else {
      throw MissionPackError("The owner requires the original recorder for a successful return.")
    }
    let cause = scriptEventContext(mission)
    state.reception = .init(
      operation: ScriptIdentity.uuid(
        "record-recovery-receive-v1:\(state.permission.operation):\(dock.sequence)"),
      dock: dock, carrier: state.permission.carrier, originals: returning, complete: complete,
      cause: cause, committed: cause)
    guard let reception = state.reception else { throw SaveError.invalidCommander }
    for index in source.originals.indices where returning.contains(source.originals[index].id) {
      source.originals[index].custody = .returned(reception.operation)
    }
    commander.scriptState.savedRecordRecoverySource = source
    if mission.outcome == .active {
      try finishRecordRecoveryMission(state, outcome: complete ? .complete : .abandoned)
    } else {
      mission.savedRecordRecovery = state
      mission.payloads = WayfarerRecordRecovery.payloads(
        state, outcome: mission.outcome, source: source)
      commander.scriptState.instances[mission.id] = mission
    }
    nativeRecordRecoveryPending = nil
    nativeRecordRecoveryIdentificationPending = nil
    notify(
      complete
        ? "SENN ORIGINALS RETURNED - 650 CR PAYMENT RECORDED"
        : "SENN OWNER RETURN RECORDED - NO SUCCESS PAYMENT")
  }

  /// Native reception and native loss share settlement, never another family's custody proof.
  mutating func finishRecordRecoveryMission(
    _ state: WayfarerRecordRecoveryState, outcome: ScriptOutcome
  ) throws {
    guard var mission = commander.scriptState.instances[state.permission.mission],
      mission.outcome == .active, mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let source = commander.scriptState.savedRecordRecoverySource
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
    mission.savedRecordRecovery = next
    mission.payloads = WayfarerRecordRecovery.payloads(next, outcome: outcome, source: source)
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

  func recordRecoveryDetail(_ action: WayfarerRecordRecoveryAction) -> [String] {
    var lines = [
      "SENN represents the actual Cedamar flight-record archive, which retains legal title.",
      "CDR-001 sealed flight/custody recorder; one tonne.",
      "Cedamar - Celalen exterior cradle - Cedamar; L2 H0; 650 CR only for original recorder owner reception.",
      "Fit targeting, Salvage targeting and Fuel Scoops. One real tonne reserved; pickup fills each slot once.",
      "First identify CDR-001: front view, 2 degree aim, nearest physical surface 250-1500 units, one positive native frame. Separately later use safe scoop approach.",
      "This protected flight/custody recorder is not living crew, a commodity or fit-able player equipment. No cutter, cabins, deposit or deadline.",
      "A lost original cannot be replaced. Cancellation requires actual archive return of any held recorder without success payment.",
      "Back changes no source, permission, custody, capacity, cash or clue.",
    ]
    if let state = recordRecoveryState,
      let source = commander.scriptState.savedRecordRecoverySource
    {
      lines += source.originals.map { item in
        let status =
          state.held.contains(item.id)
          ? "held owner property"
          : state.losses.contains(where: { $0.original == item.id })
            ? "genuinely lost"
            : state.reception?.originals.contains(item.id) == true
              ? "returned to custodian"
              : (state.identification == nil ? "unidentified at cradle" : "identified at cradle")
        return "\(item.serial): \(item.name) / \(status)."
      }
    }
    return lines + (contractBoard.recordRecoveryQuote ?? recordRecoveryReview(action)).issues
  }
}
