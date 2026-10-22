import Foundation

extension Game {
  var activeDefensiveFlight: (instance: ScriptInstance, state: NativeDefensiveFlightState)? {
    for instance in commander.scriptState.instances.values
    where instance.definition == NativeDefensiveFlight.stateID && instance.outcome == .active {
      if let state = instance.savedDefensiveFlight { return (instance, state) }
    }
    return nil
  }

  mutating func beginDefensiveFlightIfNeeded() {
    guard !paused, !docked, !isMissionTrial, screen.isFlight,
      let active = activeDefensiveFlight, active.state.failure == nil, !active.state.workVerified,
      active.instance.suspension == nil,
      active.state.permission.owner == commander.equipmentOwnerID,
      active.state.permission.carrier == commander.hullInstanceID,
      systemIdentity == NativeDefensiveFlight.location,
      let radius = commander.playerMesh.vertices.map(\.length).max(),
      NativeDefensiveFlightGeometry.hullFits(radius: radius)
    else { return }
    if active.state.original != nil {
      if let provider = active.instance.savedNativePractice,
        nativePracticeCurrent(provider, instance: active.instance),
        provider.beacons.contains(where: { beacon in
          !bodies.contains(where: { $0.physical?.identity == beacon.actor })
        })
      {
        try? restoreNativePractice(instance: active.instance.id)
      }
      return
    }
    var candidate = self
    do {
      try candidate.beginNativePractice(instance: active.instance.id)
      guard var instance = candidate.commander.scriptState.instances[active.instance.id],
        let provider = instance.savedNativePractice, var state = instance.savedDefensiveFlight
      else { return }
      try state.begin(provider, radius: radius)
      instance.savedDefensiveFlight = state
      instance.milestones = state.milestones
      candidate.commander.scriptState.instances[instance.id] = instance
      self = candidate
    } catch {
      if message != "DEFENSIVE PRACTICE COURSE NOT CLEAR" || messageTime <= 0 {
        notify("DEFENSIVE PRACTICE COURSE NOT CLEAR", voiced: false)
      }
    }
  }

  mutating func recordDefensiveFlightFailure(_ reason: NativeDefensiveFlightFailure) {
    guard let active = activeDefensiveFlight, !active.state.workVerified else { return }
    var instance = active.instance
    var state = active.state
    state.recordFailure(reason)
    instance.savedDefensiveFlight = state
    commander.scriptState.instances[instance.id] = instance
    // Never remove bodies while an ordinary damage/contact kernel retains their indices.
  }

  mutating func observeDefensiveFlightDischarge(emission: UInt64? = nil) {
    guard let player = commander.flightSimulation.player, let active = activeDefensiveFlight,
      active.state.permission.owner == commander.equipmentOwnerID,
      active.state.permission.carrier == commander.hullInstanceID
    else { return }
    recordDefensiveFlightFailure(
      .discharge(
        player: player, emission: emission, time: commander.flightSimulation.physicalTime))
  }

  mutating func observeDefensiveFlightOrdinaryHit(_ incident: CombatIncident) {
    guard let player = commander.flightSimulation.player else { return }
    if incident.kind == .collision && (incident.origin.owner == player || incident.victim == player)
    {
      recordDefensiveFlightFailure(.collision(player: player, time: incident.physicalTime))
    } else if incident.origin.owner == player {
      recordDefensiveFlightFailure(.ordinaryHit(incident))
    }
  }

  mutating func observeDefensiveFlightCollision() {
    if let player = commander.flightSimulation.player {
      recordDefensiveFlightFailure(
        .collision(player: player, time: commander.flightSimulation.physicalTime))
    }
  }

  /// Both endpoints are freshly produced by the actual tick, after retained native motion.
  mutating func advanceDefensiveFlight(before: NativeDefensiveFlightObservation?, delta: Double) {
    guard let active = activeDefensiveFlight, active.state.failure == nil,
      !active.state.workVerified, active.state.original != nil
    else { return }
    var instance = active.instance
    var state = active.state
    do {
      try state.observe(
        before: before?.sample, after: defensiveFlightObservation()?.sample, delta: delta)
      if state.workVerified {
        try state.sealDisengagement(calendar: commander.scriptState.calendarSeconds)
      }
    } catch { return }
    instance.savedDefensiveFlight = state
    instance.milestones = state.milestones
    commander.scriptState.instances[instance.id] = instance
  }

  /// The tick's outer defer safely handles native loss, failure and completed break-off.
  mutating func closeDefensiveFlightIfNeeded() {
    guard let active = activeDefensiveFlight else { return }
    if !active.state.workVerified, active.state.original != nil, active.state.failure == nil {
      let reason: NativeDefensiveFlightFailure.Interruption?
      if docked {
        reason = .docked
      } else if energy <= 0 || screen == .gameOver {
        reason = .shipLost
      } else if commander.hullInstanceID != active.state.permission.carrier {
        reason = .hullChanged
      } else if commander.flightSimulation.player != active.state.original?.permission.player {
        reason = .visitChanged
      } else {
        reason = nil
      }
      if let reason, let player = active.state.original?.permission.player {
        recordDefensiveFlightFailure(
          .interruption(
            player: player, time: commander.flightSimulation.physicalTime, reason: reason))
      }
    }
    guard let current = activeDefensiveFlight,
      current.state.failure != nil || current.state.ready
    else { return }
    if current.instance.savedNativePractice?.endedAt == nil,
      current.instance.savedNativePractice != nil
    {
      try? endNativePractice(instance: current.instance.id)
    }
    if current.state.failure != nil { try? finishDefensiveFlight(.failed) }
  }

  mutating func finishDefensiveFlight(_ outcome: ScriptOutcome) throws {
    var candidate = self
    try candidate.commitDefensiveFlightTerminal(outcome)
    self = candidate
  }

  private mutating func commitDefensiveFlightTerminal(_ outcome: ScriptOutcome) throws {
    guard let active = activeDefensiveFlight, active.state.valid,
      active.state.terminalOperation == nil, [.complete, .failed, .abandoned].contains(outcome),
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      active.instance.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let dock = commander.nativeStations?.currentMainDock
    if outcome == .complete {
      guard let dock, nativeMainStationDockEvidenceIsCurrent,
        let owner = commander.equipmentOwnerID, let carrier = commander.hullInstanceID,
        let provider = active.instance.savedNativePractice,
        NativeDefensiveFlightReception.allowed(
          state: active.state, provider: provider, dock: dock, owner: owner, carrier: carrier)
      else { throw SaveError.invalidCommander }
    }
    if outcome == .failed, active.state.failure == nil { throw SaveError.invalidCommander }
    if active.instance.savedNativePractice?.endedAt == nil,
      active.instance.savedNativePractice != nil
    {
      try endNativePractice(instance: active.instance.id)
    }
    guard var mission = commander.scriptState.instances[active.instance.id],
      var state = mission.savedDefensiveFlight
    else { throw SaveError.invalidCommander }
    let previous = mission
    let cause = scriptEventContext(mission)
    var stagedCommander = commander
    try settleContract(outcome, state: &mission, candidate: &stagedCommander)
    stagedCommander.scriptState.nextEvent += 1
    let sequence = stagedCommander.scriptState.nextEvent
    mission.outcome = outcome
    mission.revision += 1
    mission.dialogue = nil
    mission.acknowledge(sequence)
    if outcome == .complete { mission.milestones.insert(6) }
    state.retireEndpoints()
    state.terminalOperation = ScriptIdentity.uuid(
      "defensive-flight-terminal-v1:\(mission.id):\(outcome.rawValue)")
    state.terminalOutcome = outcome
    state.terminalDock = outcome == .complete ? dock : nil
    mission.savedDefensiveFlight = state
    commander = stagedCommander
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition, version: mission.version,
      digest: mission.digest, outcome: outcome, sequence: sequence, causeKind: "mission.receipted",
      cause: cause, committed: scriptEventContext(mission), revision: mission.revision,
      milestones: mission.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: mission.contract?.settlementAmount,
      choices: mission.choiceReceipts)
    commander.scriptState.instances[mission.id] = mission
    if outcome == .complete {
      try awardScriptClue(previous: previous, next: mission, trust: .production)
    }
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
  }
}
