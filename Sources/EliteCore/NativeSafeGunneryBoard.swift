import Foundation

enum NativeSafeGunneryAction: String, Sendable {
  case accept, receive, cancel
  var key: String { NativeSafeGunnery.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "Safe gunnery / review and consent"
    case .receive: "Safe gunnery / receive verified practice"
    case .cancel: "Safe gunnery / close or cancel this attempt"
    }
  }
}

struct NativeSafeGunneryReview: Sendable {
  let action: NativeSafeGunneryAction
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let epoch: UUID
  let state: String
  let issues: [String]
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  var safeGunneryPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeSafeGunnery.stateID
        && $0.manifest.version == NativeSafeGunnery.version && $0.digest == NativeSafeGunnery.digest
    }
  }
  var safeGunneryRows: [ContractBoardRow] {
    guard safeGunneryPack != nil else { return [] }
    let actions: [NativeSafeGunneryAction] =
      activeSafeGunnery == nil ? [.accept] : [.receive, .cancel]
    return actions.map {
      .init(
        board: $0.key, offer: nil, title: $0.title,
        reason: safeGunneryReview($0).issues.first, safeGunnery: $0)
    }
  }

  func safeGunneryReview(_ action: NativeSafeGunneryAction) -> NativeSafeGunneryReview {
    var issues: [String] = []
    if paused { issues.append("Resume before confirming practice.") }
    if !nativeMainStationDockEvidenceIsCurrent || systemIdentity != NativeSafeGunnery.location {
      issues.append("Use actual Avenor main orbital reception in galaxy 1, system 7.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if safeGunneryPack == nil { issues.append("Restore the approved safe-gunnery content.") }
    let active = activeSafeGunnery
    if action == .accept {
      if active != nil { issues.append("Close the current practice before accepting another.") }
      if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil {
        issues.append("The actual owned carrier must be available.")
      }
      if commander.scriptState.instances.count >= 128 {
        issues.append("The native mission record capacity is full.")
      }
      if OriginalServiceReservationPolicy.activeCount(commander.scriptState)
        >= OriginalServiceReservationPolicy.maximumActive
      {
        issues.append("Three Original contracts or services are already active.")
      }
      if let pack = safeGunneryPack,
        (commander.contracts.boards[
          pack.digest + "/" + NativeSafeGunnery.boardID + "/" + contractStation.key]?
          .offers.count ?? 0) >= 16
      {
        issues.append("The retained native practice offer capacity is full.")
      }
    } else if let active {
      if commander.nativeStations?.currentMainDock?.station != active.state.permission.dock.station
      {
        issues.append("Return to the original actual Avenor reception.")
      }
      if action == .receive {
        if active.state.ordinaryHit != nil {
          issues.append("An ordinary actor was hit. This attempt failed; close it before retrying.")
        } else if !active.state.ready {
          issues.append(
            "Three distinct native beacon hits and three safe flight seconds are still required.")
        }
        if commander.hullInstanceID != active.state.permission.carrier {
          issues.append("Use the original practice carrier for reception.")
        }
      }
    } else {
      issues.append("There is no active safe-gunnery attempt.")
    }
    let fingerprint = active.flatMap { try? NativeFlightReception.hash($0.state) } ?? "unaccepted"
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, epoch: nativeStationRuntimeEpoch,
      state: fingerprint, issues: issues)
  }

  mutating func confirmSafeGunnery(_ quote: NativeSafeGunneryReview) throws {
    let current = safeGunneryReview(quote.action)
    guard quote.allowed, current.allowed, quote.dock == current.dock,
      quote.carrier == current.carrier, quote.epoch == current.epoch, quote.state == current.state
    else {
      throw MissionPackError(
        "The actual berth, carrier or practice evidence changed. Review again.")
    }
    var candidate = self
    switch quote.action {
    case .accept: try candidate.acceptSafeGunnery()
    case .receive: try candidate.finishSafeGunnery(.complete)
    case .cancel:
      try candidate.finishSafeGunnery(
        candidate.activeSafeGunnery?.state.ordinaryHit == nil ? .abandoned : .failed)
    }
    self = candidate
  }

  private mutating func acceptSafeGunnery() throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard let pack = safeGunneryPack, activeSafeGunnery == nil,
      let owner = commander.equipmentOwnerID, let carrier = commander.hullInstanceID,
      let dock = commander.nativeStations?.currentMainDock, nativeMainStationDockEvidenceIsCurrent,
      dock.station.system == NativeSafeGunnery.location, dock.commanderOwner == owner,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2,
      commander.scriptState.instances.count < 128
    else { throw SaveError.invalidCommander }
    let attempt = commander.scriptState.instances.values.filter(NativeSafeGunnerySave.marked).count
    let station = contractStation
    let key = pack.digest + "/" + NativeSafeGunnery.boardID + "/" + station.key
    let offerKey = "safe-gunnery-\(attempt)"
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(key):0:\(offerKey)")
    let missionID = Self.contractJobIdentity(offerID)
    let offers = commander.contracts.boards[key]?.offers ?? []
    guard offers.count < 16, commander.scriptState.instances[missionID] == nil else {
      throw SaveError.invalidCommander
    }
    let offer = ScriptContractOffer(
      id: offerID, key: offerKey, title: "Safe gunnery / no cash payment",
      briefing: pack.manifest.mission.briefing, destinationGalaxy: 0, destinationSystem: 7,
      reward: 0, deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0,
      parameters: .object([:]))
    var accepted = offer
    accepted.status = .accepted(missionID)
    commander.contracts.boards[key] = .init(
      id: NativeSafeGunnery.boardID, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, title: "Safe gunnery at Avenor", station: station,
      revision: 0, seed: 0, clock: .local, period: 3600, group: NativeSafeGunnery.stateID,
      offers: offers + [accepted])
    var mission = ScriptInstance(
      id: missionID, definition: NativeSafeGunnery.stateID, version: pack.manifest.version,
      digest: pack.digest)
    mission.contract = .init(
      boardKey: key, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest,
      station: station, boardRevision: 0, group: NativeSafeGunnery.stateID, offer: offer,
      clock: .local, acceptedAt: commander.scriptState.localSeconds, deadline: nil)
    let cause = scriptEventContext(mission)
    commander.scriptState.nextEvent += 1
    let sequence = commander.scriptState.nextEvent
    mission.revision = 1
    mission.acknowledge(sequence)
    let consent = ScriptChoiceReceipt(
      instance: mission.id, group: NativePracticeSource.consentGroup,
      choice: NativePracticeSource.consentChoice, label: "Begin safe gunnery practice",
      dialogue: "native-safe-gunnery-review", sequence: sequence, revision: mission.revision,
      cause: cause, committed: scriptEventContext(mission))
    mission.choiceReceipts[NativePracticeSource.consentGroup] = consent
    mission.savedSafeGunnery = .init(
      permission: .init(
        mission: missionID, owner: owner, carrier: carrier, dock: dock, consent: consent,
        acceptedAt: commander.flightSimulation.physicalTime))
    mission.milestones = [0]
    commander.scriptState.instances[mission.id] = mission
    emitScriptEvent("mission.accepted", only: mission.id)
    notify("SAFE GUNNERY ACCEPTED - LAUNCH TO BEGIN THE NATIVE RANGE")
  }

  func safeGunneryDetail(_ action: NativeSafeGunneryAction) -> [String] {
    var rows = [
      "Actual Avenor consent and reception. Zero fee, deposit and cash reward.",
      "Launch in your current owned carrier. The native range admits three original uncrewed 6 m beacons only when clear.",
      "Hit each with an actual fitted laser or player missile. Normal finite weapon costs remain.",
      "After all three hits: three unpaused flight seconds with no discharge or unresolved attempt missile.",
      "Any discharge restarts quiet time. Pause advances nothing. EMP, utility, bombs and proximity cannot substitute.",
      "An actual player hit on an ordinary actor permanently fails this attempt; normal law and damage remain.",
      "Return through actual Avenor docking and separately Confirm reception for the existing family trace once.",
    ]
    if let active = activeSafeGunnery {
      rows.append("Distinct native hits: \(active.state.progress?.hits.count ?? 0)/3")
      rows.append("Safe quiet flight: \(active.state.quietSeconds)/3 seconds")
      rows.append("Unresolved attempt missiles: \(active.state.pendingProjectiles.count)")
      if active.state.ordinaryHit != nil {
        rows.append("FAILED: ordinary actor hit. No clue or payment.")
      }
    }
    return rows + safeGunneryReview(action).issues
  }
}
