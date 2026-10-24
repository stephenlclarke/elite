import Foundation

enum NativeFlightReceptionAction: String, Sendable, Equatable {
  case accept, receive, cancel
  var key: String { NativeFlightReception.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "Training berth / review current-fit flight practice"
    case .receive: "Training berth / receive actual flight practice"
    case .cancel: "Training berth / cancel practice without payment"
    }
  }
}
struct NativeFlightReceptionReview: Sendable {
  let action: NativeFlightReceptionAction
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let epoch: UUID
  let state: String
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  var flightReceptionPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeFlightReception.stateID
        && $0.digest == NativeFlightReception.digest && $0.manifest.flightReception?.valid == true
    }
  }
  var flightReceptionRows: [ContractBoardRow] {
    guard flightReceptionPack != nil else { return [] }
    let actions: [NativeFlightReceptionAction] =
      activeFlightReception == nil ? [.accept] : [.receive, .cancel]
    return actions.map {
      .init(
        board: $0.key, offer: nil, title: $0.title,
        reason: flightReceptionReview($0).issues.first, flightReception: $0)
    }
  }
  func flightReceptionReview(_ action: NativeFlightReceptionAction) -> NativeFlightReceptionReview {
    var issues: [String] = []
    if paused { issues.append("Resume before confirming practice.") }
    if !nativeMainStationDockEvidenceIsCurrent || commander.system >= 256
      || currentSystem.original == nil
    {
      issues.append("Use an actual original-world main orbital training berth.")
    }
    if let dock = commander.nativeStations?.currentMainDock,
      commander.scriptState.stationResources[dock.station.key].map({
        $0.identity == dock.station.resource && !$0.destroyed && $0.energy > 0
      }) != true
    {
      issues.append("The actual training station must still be available to receive you.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if flightReceptionPack == nil { issues.append("Restore the approved flight practice content.") }
    let active = activeFlightReception
    if action == .accept {
      if active != nil { issues.append("Finish or cancel the current practice first.") }
      if commander.equipmentInventory == nil || commander.equipmentOwnerID == nil
        || commander.hullInstanceID == nil || commander.flightSimulation.player == nil
      {
        issues.append("The current owned carrier and fitting must be available.")
      }
      if commander.performance.speed <= 0 || commander.performance.pitch <= 0
        || commander.performance.roll <= 0
      {
        issues.append("Choose a carrier with actual flight and steering capability.")
      }
      if let pack = flightReceptionPack {
        let key = pack.digest + "/" + NativeFlightReception.boardID + "/" + contractStation.key
        if (commander.contracts.boards[key]?.offers.count ?? 0) >= 16 {
          issues.append(
            "This berth’s sixteen retained practice records are full. Choose another berth.")
        }
      }
      if commander.scriptState.instances.count >= 128 {
        issues.append("The mission record capacity is full.")
      }
      if OriginalServiceReservationPolicy.activeCount(commander.scriptState)
        >= OriginalServiceReservationPolicy.maximumActive
      {
        issues.append("Three Original contracts or services are already active.")
      }
    } else if let active {
      if commander.nativeStations?.currentMainDock?.station != active.state.permission.dock.station
      {
        issues.append("Return to the actual issuing training berth.")
      }
      if commander.hullInstanceID != active.state.permission.carrier {
        issues.append("Use the practice's original carrier or cancel it.")
      }
      if action == .receive,
        commander.nativeStations?.currentMainDock.map({
          NativeFlightReception.returnReady(active.state, dock: $0)
        }) != true
      {
        issues.append(
          "Launch, make a measured aligned approach, then return through the real doorway.")
      }
    } else {
      issues.append("There is no active flight practice.")
    }
    let state =
      active.map {
        $0.instance.id.uuidString + ":" + ($0.state.reading?.operation.uuidString ?? "unmeasured")
      } ?? "unaccepted"
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      epoch: nativeStationRuntimeEpoch, state: state, issues: issues)
  }
  mutating func confirmFlightReception(_ quote: NativeFlightReceptionReview) throws {
    let current = flightReceptionReview(quote.action)
    guard quote.allowed, current.allowed, quote.dock == current.dock,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.epoch == current.epoch, quote.state == current.state, let pack = flightReceptionPack
    else {
      throw MissionPackError(
        "The actual practice berth, fitting or evidence changed. Review again.")
    }
    var candidate = self
    switch quote.action {
    case .accept: try candidate.acceptFlightReception(pack)
    case .receive: try candidate.finishFlightReception(.complete)
    case .cancel: try candidate.finishFlightReception(.abandoned)
    }
    self = candidate
  }
  private mutating func acceptFlightReception(_ pack: ScriptPack) throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard activeFlightReception == nil, let owner = commander.equipmentOwnerID,
      let carrier = commander.hullInstanceID, let inventory = commander.equipmentInventory,
      let dock = commander.nativeStations?.currentMainDock, nativeMainStationDockEvidenceIsCurrent,
      dock.commanderOwner == owner, let snapshot = try? commander.purchaseSnapshot(),
      commander.scriptState.instances.count < 128
    else { throw SaveError.invalidCommander }
    let station = contractStation
    let key = pack.digest + "/" + NativeFlightReception.boardID + "/" + station.key
    let attempt = commander.scriptState.instances.values.filter {
      $0.definition == NativeFlightReception.stateID
    }.count
    let offerKey = "flight-reception-\(attempt)"
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(key):0:\(offerKey)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw SaveError.invalidCommander
    }
    let offer = ScriptContractOffer(
      id: offerID, key: offerKey,
      title: "Flight and reception practice / no extra payment / untimed",
      briefing: pack.manifest.mission.briefing, destinationGalaxy: commander.galaxy,
      destinationSystem: commander.system, reward: 0, deposit: 0, failureReward: 0,
      refundOnFailure: false, duration: 0, parameters: .object([:]))
    var accepted = offer
    accepted.status = .accepted(missionID)
    let previousOffers = commander.contracts.boards[key]?.offers ?? []
    guard previousOffers.count < 16 else { throw SaveError.invalidCommander }
    commander.contracts.boards[key] = .init(
      id: NativeFlightReception.boardID, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, title: "Original flight and reception practice", station: station,
      revision: 0, seed: 0, clock: .local, period: 3600, group: NativeFlightReception.stateID,
      offers: previousOffers + [accepted])
    var mission = ScriptInstance(
      id: missionID, definition: NativeFlightReception.stateID, version: pack.manifest.version,
      digest: pack.digest)
    mission.contract = .init(
      boardKey: key, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest,
      station: station, boardRevision: 0, group: NativeFlightReception.stateID, offer: offer,
      clock: .local, acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    mission.savedFlightReception = .init(
      permission: .init(
        mission: missionID,
        operation: try NativeFlightReception.permissionOperation(
          mission: missionID, owner: owner, carrier: carrier, revision: inventory.revision,
          dock: dock, fit: snapshot.items),
        owner: owner, carrier: carrier, inventoryRevision: inventory.revision, dock: dock,
        fit: snapshot.items, epoch: nativeStationRuntimeEpoch))
    mission.milestones = [0]
    commander.scriptState.instances[missionID] = mission
    emitScriptEvent("mission.accepted", only: missionID)
    notify("PRACTICE ACCEPTED - CURRENT COMMANDER AND FIT RETAINED")
  }

  mutating func finishFlightReception(_ outcome: ScriptOutcome) throws {
    guard let active = activeFlightReception, active.state.terminalOperation == nil,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      active.instance.revision < UInt64(Int64.max) - 1,
      [.complete, .abandoned, .failed].contains(outcome)
    else { throw SaveError.invalidCommander }
    let dock = commander.nativeStations?.currentMainDock
    if outcome != .failed {
      guard nativeMainStationDockEvidenceIsCurrent,
        dock?.station == active.state.permission.dock.station,
        commander.hullInstanceID == active.state.permission.carrier
      else { throw SaveError.invalidCommander }
    }
    if outcome == .complete {
      guard let dock, NativeFlightReception.returnReady(active.state, dock: dock) else {
        throw SaveError.invalidCommander
      }
    }
    let previous = active.instance
    var mission = previous
    var state = active.state
    let cause = scriptEventContext(mission)
    var candidate = commander
    try settleContract(outcome, state: &mission, candidate: &candidate)
    candidate.scriptState.nextEvent += 1
    let sequence = candidate.scriptState.nextEvent
    mission.outcome = outcome
    mission.revision += 1
    mission.dialogue = nil
    mission.acknowledge(sequence)
    if outcome == .complete { mission.milestones.insert(2) }
    state.terminalOutcome = outcome
    state.terminalDock = outcome == .failed ? nil : dock
    state.terminalOperation = ScriptIdentity.uuid(
      "flight-reception-terminal-v1:\(state.permission.operation):\(outcome.rawValue)")
    mission.savedFlightReception = state
    commander = candidate
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition, version: mission.version,
      digest: mission.digest, outcome: outcome, sequence: sequence, causeKind: "mission.receipted",
      cause: cause, committed: scriptEventContext(mission), revision: mission.revision,
      milestones: mission.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: mission.contract?.settlementAmount, choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
    nativeFlightReceptionPending = nil
    notify(
      outcome == .complete
        ? "PRACTICE RECEIVED - NO EXTRA PAYMENT; JOURNAL TRACE RECORDED"
        : "PRACTICE CLOSED - CURRENT COMMANDER AND SAVE RETAINED")
  }

  /// The same immutable proposal participates in ordinary saves as well as automatic publication.
  mutating func applyFlightReceptionPending() throws -> Bool {
    guard let pending = nativeFlightReceptionPending else { return false }
    guard let active = activeFlightReception, active.state.reading == nil,
      pending.reading.first.permission == active.state.permission.operation,
      pending.reading.first.mission == active.instance.id,
      pending.reading.first.epoch == nativeStationRuntimeEpoch,
      NativeFlightReception.readingValid(pending.reading)
    else { throw SaveError.invalidCommander }
    var state = active.state
    var mission = active.instance
    state.reading = pending.reading
    mission.savedFlightReception = state
    mission.milestones.insert(1)
    commander.scriptState.instances[mission.id] = mission
    nativeFlightReceptionPending = nil
    return true
  }

  mutating func recordFlightReceptionFailureIfNeeded() throws {
    guard let active = activeFlightReception else { return }
    if (screen == .gameOver && energy.isFinite && energy <= 0)
      || commander.hullInstanceID != active.state.permission.carrier
    {
      try finishFlightReception(.failed)
    }
  }

  func flightReceptionDetail(_ action: NativeFlightReceptionAction) -> [String] {
    var rows = [
      "Practice uses your current commander and actual owned fit. No private trial or reset.",
      "Accept here, launch, and face this same live berth in front view within 2 degrees.",
      "At 1000-1500 centre flight units, close toward it during a positive native frame with clear sight.",
      "Space accelerates; Delete brakes. Up/Down pitches; Left/Right rolls; 0/1/2/3 selects front/rear/left/right.",
      "Two trackpad fingers steer, one brakes and three accelerate. Lift to centre and cruise; K opens help.",
      "Pause freezes progress; completed evidence survives saving.",
      "Make the real safe doorway arrival, then separately Confirm reception at this issuing berth.",
      "Zero cargo, berths, payment, deposit or deadline. Cancellation grants no clue and never wipes a save.",
      "Changing carrier ends the attempt; changed fitting cannot supply the reserved-fit measurement.",
    ]
    rows += FlightControlAuthority.ActionID.allCases.map(FlightControlInput.helpRow)
    if let active = activeFlightReception {
      rows.append(
        active.state.reading == nil
          ? "Aligned approach: not yet measured" : "Aligned approach: native evidence retained")
      rows += active.state.permission.fit.filter { $0.location != nil }.map {
        "Fitted: " + $0.node.key
      }
    } else if let inventory = commander.equipmentInventory {
      rows += inventory.items.filter { $0.location != nil }.map { "Fitted: " + $0.node.key }
    }
    return rows + (contractBoard.flightReceptionQuote ?? flightReceptionReview(action)).issues
  }
}

extension GameRuntime {
  func commitFlightReception(start: NativeFlightReceptionSample?) {
    guard game.activeFlightReception != nil, let publish = scriptPublisher() else { return }
    if game.nativeFlightReceptionPending == nil, let start, let end = game.flightReceptionSample(),
      let reading = try? NativeFlightReception.measure(first: start, last: end)
    {
      game.nativeFlightReceptionPending = .init(reading)
    }
    var candidate = game
    do {
      let failed =
        (candidate.screen == .gameOver && candidate.energy <= 0)
        || candidate.commander.hullInstanceID
          != candidate.activeFlightReception?.state.permission.carrier
      if failed {
        try candidate.recordFlightReceptionFailureIfNeeded()
      } else {
        guard try candidate.applyFlightReceptionPending() else { return }
      }
      try publish(&candidate)
      game = candidate
    } catch { game.notify("PRACTICE EVIDENCE NOT SAVED - SAME ATTEMPT RETAINED") }
  }
}
