import Foundation

enum NativeDefensiveFlightAction: String, Sendable {
  case accept, receive, cancel
  var key: String { NativeDefensiveFlight.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "Defensive flight / review and consent"
    case .receive: "Defensive flight / receive verified practice"
    case .cancel: "Defensive flight / close or cancel this attempt"
    }
  }
}

struct NativeDefensiveFlightReview: Sendable {
  let action: NativeDefensiveFlightAction
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let epoch: UUID
  let state: String
  let issues: [String]
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  var defensiveFlightPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeDefensiveFlight.stateID
        && $0.manifest.version == NativeDefensiveFlight.version
        && $0.digest == NativeDefensiveFlight.digest
    }
  }
  var defensiveFlightRows: [ContractBoardRow] {
    guard defensiveFlightPack != nil else { return [] }
    let actions: [NativeDefensiveFlightAction] =
      activeDefensiveFlight == nil ? [.accept] : [.receive, .cancel]
    return actions.map {
      .init(
        board: $0.key, offer: nil, title: $0.title,
        reason: defensiveFlightReview($0).issues.first, defensiveFlight: $0)
    }
  }

  func defensiveFlightReview(_ action: NativeDefensiveFlightAction) -> NativeDefensiveFlightReview {
    var issues: [String] = []
    if paused { issues.append("Resume before confirming practice.") }
    if !nativeMainStationDockEvidenceIsCurrent || systemIdentity != NativeDefensiveFlight.location {
      issues.append("Use actual Avenor main orbital reception in galaxy 1, system 7.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if defensiveFlightPack == nil {
      issues.append("Restore the approved defensive-flight content.")
    }
    let active = activeDefensiveFlight
    if action == .accept {
      if let radius = commander.playerMesh.vertices.map(\.length).max(),
        !NativeDefensiveFlightGeometry.hullFits(radius: radius)
      {
        issues.append("Ship does not fit this practice course.")
      }
      if bodies.contains(where: { body in
        body.physical?.ordnance.map { $0.origin.owner.entity == 0 && $0.termination == nil }
          ?? false
      }) {
        issues.append("Resolve existing player projectiles before accepting practice.")
      }
      if commander.scriptState.instances.values.contains(where: {
        $0.savedNativePractice.map { $0.endedAt == nil } ?? false
      }) {
        issues.append("Finish or close the other active native practice range first.")
      }
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
      if let pack = defensiveFlightPack,
        (commander.contracts.boards[
          pack.digest + "/" + NativeDefensiveFlight.boardID + "/" + contractStation.key]?
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
        if active.state.failure != nil {
          issues.append("This non-firing attempt failed; close it before retrying.")
        } else if !active.state.ready {
          issues.append(
            "Manual acquisition, both ordered gates and safe withdrawal are still required.")
        }
        if commander.hullInstanceID != active.state.permission.carrier {
          issues.append("Use the original practice carrier for reception.")
        }
      }
    } else {
      issues.append("There is no active defensive-flight attempt.")
    }
    let fingerprint = active.flatMap { try? NativeFlightReception.hash($0.state) } ?? "unaccepted"
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, epoch: nativeStationRuntimeEpoch,
      state: fingerprint, issues: issues)
  }

  mutating func confirmDefensiveFlight(_ quote: NativeDefensiveFlightReview) throws {
    let current = defensiveFlightReview(quote.action)
    guard quote.allowed, current.allowed, quote.dock == current.dock,
      quote.carrier == current.carrier, quote.epoch == current.epoch, quote.state == current.state
    else {
      throw MissionPackError(
        "The actual berth, carrier or practice evidence changed. Review again.")
    }
    var candidate = self
    switch quote.action {
    case .accept: try candidate.acceptDefensiveFlight()
    case .receive: try candidate.finishDefensiveFlight(.complete)
    case .cancel:
      try candidate.finishDefensiveFlight(
        candidate.activeDefensiveFlight?.state.failure == nil ? .abandoned : .failed)
    }
    self = candidate
  }

  private mutating func acceptDefensiveFlight() throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard let pack = defensiveFlightPack, activeDefensiveFlight == nil,
      let owner = commander.equipmentOwnerID, let carrier = commander.hullInstanceID,
      let dock = commander.nativeStations?.currentMainDock, nativeMainStationDockEvidenceIsCurrent,
      dock.station.system == NativeDefensiveFlight.location, dock.commanderOwner == owner,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2,
      commander.scriptState.instances.count < 128
    else { throw SaveError.invalidCommander }
    let attempt = commander.scriptState.instances.values.filter(NativeDefensiveFlightSave.marked)
      .count
    let station = contractStation
    let key = pack.digest + "/" + NativeDefensiveFlight.boardID + "/" + station.key
    let offerKey = "defensive-flight-\(attempt)"
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(key):0:\(offerKey)")
    let missionID = Self.contractJobIdentity(offerID)
    let offers = commander.contracts.boards[key]?.offers ?? []
    guard offers.count < 16, commander.scriptState.instances[missionID] == nil else {
      throw SaveError.invalidCommander
    }
    let offer = ScriptContractOffer(
      id: offerID, key: offerKey, title: "Defensive flight / no cash payment",
      briefing: pack.manifest.mission.briefing, destinationGalaxy: 0, destinationSystem: 7,
      reward: 0, deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0,
      parameters: .object([:]))
    var accepted = offer
    accepted.status = .accepted(missionID)
    commander.contracts.boards[key] = .init(
      id: NativeDefensiveFlight.boardID, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, title: "Defensive flight at Avenor", station: station,
      revision: 0, seed: 0, clock: .local, period: 3600, group: NativeDefensiveFlight.stateID,
      offers: offers + [accepted])
    var mission = ScriptInstance(
      id: missionID, definition: NativeDefensiveFlight.stateID, version: pack.manifest.version,
      digest: pack.digest)
    mission.contract = .init(
      boardKey: key, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest,
      station: station, boardRevision: 0, group: NativeDefensiveFlight.stateID, offer: offer,
      clock: .local, acceptedAt: commander.scriptState.localSeconds, deadline: nil)
    let cause = scriptEventContext(mission)
    commander.scriptState.nextEvent += 1
    let sequence = commander.scriptState.nextEvent
    mission.revision = 1
    mission.acknowledge(sequence)
    let consent = ScriptChoiceReceipt(
      instance: mission.id, group: NativePracticeSource.consentGroup,
      choice: NativePracticeSource.consentChoice, label: "Begin defensive flight practice",
      dialogue: "native-defensive-flight-review", sequence: sequence, revision: mission.revision,
      cause: cause, committed: scriptEventContext(mission))
    mission.choiceReceipts[NativePracticeSource.consentGroup] = consent
    mission.savedDefensiveFlight = .init(
      permission: .init(
        mission: missionID, owner: owner, carrier: carrier, dock: dock, consent: consent,
        acceptedAt: commander.flightSimulation.physicalTime))
    mission.milestones = [0]
    commander.scriptState.instances[mission.id] = mission
    emitScriptEvent("mission.accepted", only: mission.id)
    notify("DEFENSIVE FLIGHT ACCEPTED - LAUNCH TO BEGIN THE NATIVE RANGE")
  }

  func defensiveFlightDetail(_ action: NativeDefensiveFlightAction) -> [String] {
    var rows = [
      "Actual Avenor acceptance and separate reception. Zero fee, deposit and cash reward.",
      "Front-view manual practice reference: original centre beacon. No targeting hardware is required or granted.",
      "Approach: x/y within50m, z350-500m behind centre, range350-500m, speed<=5m/s, nose5deg; unobstructed sight for2s.",
      "Gate A (+180,0,-450), then B (-180,0,-450): centre within40m for0.5s each, speed5-30m/s, lateral>=3m/s right then left, nose30deg of velocity. Cross x=0 between them.",
      "Exit: x within250m, y within150m, z450-1450m behind centre. Beyond1100m, separate>=5m/s at5-30m/s with nose150deg away for3s.",
      "Discharge, ordinary harm/collision or unsafe beacon near-pass fails this attempt. Normal effects remain.",
      "Traffic intrusion resets the unfinished window. Pause earns nothing. Escape leaves only this active exercise.",
      "After measured break-off the provider retires. Return through actual Avenor docking and separately Confirm for the existing family trace once.",
    ]
    if let active = activeDefensiveFlight {
      rows.append("Completed native phases: \(active.state.windows.count)/4")
      rows.append("Current active window: \(active.state.pending?.duration ?? 0) seconds")
      if active.state.failure != nil { rows.append("FAILED: no payment or clue.") }
      if active.state.ready { rows.append("READY: return to actual Avenor reception.") }
    }
    return rows + defensiveFlightReview(action).issues
  }
}
