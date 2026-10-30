import Foundation

enum NativeOriginalSurveyAction: String, Sendable, Equatable {
  case accept, receive, cancel

  var title: String {
    switch self {
    case .accept: "Avenor / accept consented survey permission"
    case .receive: "Avenor / receive three signed measurements"
    case .cancel: "Avenor / cancel survey permission"
    }
  }
  var key: String { NativeOriginalSurvey.stateID + "/" + rawValue }
}

struct NativeOriginalSurveyReview: Sendable {
  let action: NativeOriginalSurveyAction
  let digest: String
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let epoch: UUID
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  var originalSurveyPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeOriginalSurvey.stateID
        && $0.digest == NativeOriginalSurvey.digest
        && $0.manifest.originalSurvey?.valid == true
    }
  }

  var originalSurveyRows: [ContractBoardRow] {
    guard originalSurveyPack != nil, originalSurveyState?.terminalOperation == nil else {
      return []
    }
    let actions: [NativeOriginalSurveyAction]
    if originalSurveyState == nil {
      guard contractStation == NativeOriginalSurvey.source else { return [] }
      actions = [.accept]
    } else {
      actions = contractStation == NativeOriginalSurvey.source ? [.receive, .cancel] : [.receive]
    }
    return actions.map { action in
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: originalSurveyReview(action).issues.first, survey: action)
    }
  }

  func originalSurveyReview(_ action: NativeOriginalSurveyAction) -> NativeOriginalSurveyReview {
    var issues: [String] = []
    if !nativeMainStationDockEvidenceIsCurrent || contractStation != NativeOriginalSurvey.source {
      issues.append("Use the actual Avenor main orbital survey office.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save.") }
    if originalSurveyPack == nil { issues.append("The original survey content is unavailable.") }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil {
      issues.append("The survey needs the actual owned carrier.")
    }
    switch action {
    case .accept:
      if originalSurveyState != nil { issues.append("This original permission is already issued.") }
      if commander.fittedEquipment(at: .targetingCore) == nil || commander.targetingTier == nil {
        issues.append("Fit a targeting computer before accepting survey permission.")
      }
      if OriginalServiceReservationPolicy.activeCount(commander.scriptState)
        >= OriginalServiceReservationPolicy.maximumActive
      {
        issues.append("Three Original contracts or services are already active.")
      }
      if NativeOriginalSurvey.route(reach: ScriptCourierReach(commander)) != [7, 185, 7] {
        issues.append("Refuel or refit for the actual Renas route.")
      }
    case .receive, .cancel:
      if let source = originalSurveyState, let permission = source.permission,
        source.terminalOperation == nil,
        commander.scriptState.instances[permission.mission]?.outcome == .active
      {
        if commander.hullInstanceID != permission.carrier {
          issues.append("Return with the same survey carrier.")
        }
        if action == .receive,
          commander.nativeStations?.currentMainDock.map({
            NativeOriginalSurvey.returnReady(source, dock: $0)
          }) != true
        {
          issues.append("Complete the three registered readings, then actually return to Avenor.")
        }
      } else {
        issues.append("There is no active original survey permission.")
      }
    }
    return .init(
      action: action, digest: originalSurveyPack?.digest ?? "",
      dock: commander.nativeStations?.currentMainDock, carrier: commander.hullInstanceID,
      inventoryRevision: commander.equipmentInventory?.revision,
      epoch: nativeStationRuntimeEpoch, issues: issues)
  }

  mutating func confirmOriginalSurvey(_ review: NativeOriginalSurveyReview) throws {
    let current = originalSurveyReview(review.action)
    guard review.allowed, current.allowed, review.digest == current.digest,
      review.dock == current.dock, review.carrier == current.carrier,
      review.inventoryRevision == current.inventoryRevision, review.epoch == current.epoch,
      let pack = originalSurveyPack
    else { throw MissionPackError("The survey context changed. Review the native terms again.") }
    var candidate = self
    switch review.action {
    case .accept: try candidate.acceptOriginalSurvey(pack)
    case .receive: try candidate.closeOriginalSurvey(receive: true)
    case .cancel: try candidate.closeOriginalSurvey(receive: false)
    }
    self = candidate
  }

  private mutating func acceptOriginalSurvey(_ pack: ScriptPack) throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard let owner = commander.equipmentOwnerID, let carrier = commander.hullInstanceID,
      let collector = commander.flightSimulation.player,
      let inventory = commander.equipmentInventory,
      let dock = commander.nativeStations?.currentMainDock,
      let definition = pack.manifest.originalSurvey
    else { throw SaveError.invalidCommander }
    let boardKey = pack.digest + "/consented-survey/" + NativeOriginalSurvey.source.key
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(boardKey):0:\(definition.batch)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw MissionPackError("This original survey permission has already been used.")
    }
    let offer = ScriptContractOffer(
      id: offerID, key: definition.batch, title: "Consented survey / L2 H0 / 730 CR / untimed",
      briefing: pack.manifest.mission.briefing, destinationGalaxy: 0, destinationSystem: 7,
      reward: NativeOriginalSurvey.reward, deposit: 0, failureReward: 0,
      refundOnFailure: false, duration: 0, parameters: .object([:]))
    var accepted = offer
    accepted.status = .accepted(missionID)
    commander.contracts.boards[boardKey] = .init(
      id: NativeOriginalSurvey.boardID, provider: pack.manifest.id,
      version: pack.manifest.version, digest: pack.digest, title: "Original consented survey",
      station: NativeOriginalSurvey.source, revision: 0, seed: 0, clock: .local,
      period: 3600, group: NativeOriginalSurvey.stateID, offers: [accepted])
    var mission = ScriptInstance(
      id: missionID, definition: NativeOriginalSurvey.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = .init(
      boardKey: boardKey, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, station: NativeOriginalSurvey.source, boardRevision: 0,
      group: NativeOriginalSurvey.stateID, offer: offer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    mission.savedOriginalSurvey = .init(
      owner: owner, definition: definition, version: pack.manifest.version, digest: pack.digest,
      permission: .init(
        mission: missionID,
        operation: ScriptIdentity.uuid("native-survey-permission-v1:\(owner):\(missionID)"),
        dock: dock, collector: collector, carrier: carrier, inventoryRevision: inventory.revision,
        reach: ScriptCourierReach(commander), path: [7, 185, 7],
        physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch))
    mission.milestones = [0]
    commander.scriptState.instances[missionID] = mission
    emitScriptEvent("mission.accepted", only: missionID)
  }

  private mutating func closeOriginalSurvey(receive: Bool) throws {
    guard var source = originalSurveyState, let permission = source.permission,
      var mission = commander.scriptState.instances[permission.mission],
      mission.outcome == .active, source.terminalOperation == nil,
      commander.scriptState.nextEvent < UInt64.max - 1, mission.revision < UInt64.max
    else { throw SaveError.invalidCommander }
    let previous = mission
    let cause = scriptEventContext(mission)
    let outcome: ScriptOutcome = receive ? .complete : .abandoned
    var candidate = commander
    try settleContract(outcome, state: &mission, candidate: &candidate)
    candidate.scriptState.nextEvent += 1
    let sequence = candidate.scriptState.nextEvent
    mission.outcome = outcome
    mission.revision += 1
    mission.dialogue = nil
    if receive { mission.milestones.insert(4) }
    mission.acknowledge(sequence)
    source.terminalOperation = ScriptIdentity.uuid(
      "native-survey-terminal-v1:\(permission.operation):\(outcome.rawValue)")
    source.terminalDock = commander.nativeStations?.currentMainDock
    mission.savedOriginalSurvey = source
    commander = candidate
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition,
      version: mission.version, digest: mission.digest, outcome: outcome, sequence: sequence,
      causeKind: "mission.receipted", cause: cause, committed: scriptEventContext(mission),
      revision: mission.revision, milestones: mission.milestones.sorted(), destroyedEncounters: [],
      deliveredParties: [], returnedEquipment: [],
      settlementAmount: mission.contract?.settlementAmount, choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
    nativeOriginalSurveyRuntime = nil
  }

  func originalSurveyDetail(_ action: NativeOriginalSurveyAction) -> [String] {
    [
      "Avenor permission: three registered Renas calibration targets, in declared order.",
      "Route Avenor - Renas - Avenor; L2 H0; 730 CR at actual measurement reception.",
      "Zero cargo, berths, deposit and deadline. Fit a targeting computer before acceptance.",
      "Each reading: 12 continuous native seconds, front view, 2 degree aim, 250-1500 surface units and clear nearest-hit sight.",
      "Pause freezes observation. Interruption or load resets unfinished dwell; completed readings persist.",
      "The third reading alone pays nothing. Return all measurements to actual Avenor reception.",
      "Back changes no permission, cash, measurement or clue.",
    ] + (contractBoard.surveyQuote ?? originalSurveyReview(action)).issues
  }
}
