import Foundation

extension Game {
  var activeSafeGunnery: (instance: ScriptInstance, state: NativeSafeGunneryState)? {
    for instance in commander.scriptState.instances.values
    where instance.definition == NativeSafeGunnery.stateID && instance.outcome == .active {
      if let state = instance.savedSafeGunnery { return (instance, state) }
    }
    return nil
  }

  /// Called at the real positive flight frame before weapon admission.
  mutating func beginSafeGunneryIfNeeded() {
    guard !paused, !docked, !isMissionTrial, screen.isFlight,
      let active = activeSafeGunnery,
      active.state.ordinaryHit == nil, active.instance.suspension == nil,
      active.state.permission.carrier == commander.hullInstanceID,
      systemIdentity == NativeSafeGunnery.location
    else { return }
    if active.state.progress != nil {
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
        var state = instance.savedSafeGunnery, let provider = instance.savedNativePractice
      else { return }
      try state.begin(provider)
      instance.savedSafeGunnery = state
      instance.milestones.insert(1)
      candidate.commander.scriptState.instances[instance.id] = instance
      self = candidate
    } catch {
      if message != "PRACTICE RANGE NOT CLEAR" || messageTime <= 0 {
        notify("PRACTICE RANGE NOT CLEAR", voiced: false)
      }
    }
  }

  mutating func synchronizeSafeGunneryHit(instance id: UUID) {
    guard let active = activeSafeGunnery, active.instance.id == id,
      var instance = commander.scriptState.instances[id],
      let provider = instance.savedNativePractice, var state = instance.savedSafeGunnery,
      state.ordinaryHit == nil
    else { return }
    do { try state.synchronize(provider) } catch { return }
    if state.progress?.threeDistinctHits == true { instance.milestones.insert(2) }
    instance.savedSafeGunnery = state
    commander.scriptState.instances[id] = instance
  }

  /// These observers only amend this exact active native lesson. Ordinary effects are untouched.
  mutating func observeSafeGunneryDischarge(emission: UInt64? = nil) {
    guard let active = activeSafeGunnery, active.state.ordinaryHit == nil,
      active.state.permission.owner == commander.equipmentOwnerID,
      active.state.permission.carrier == commander.hullInstanceID
    else { return }
    var instance = active.instance
    var state = active.state
    state.discharge(time: commander.flightSimulation.physicalTime, emission: emission)
    instance.milestones.remove(3)
    instance.savedSafeGunnery = state
    commander.scriptState.instances[instance.id] = instance
  }

  mutating func observeSafeGunneryMissileLaunch(_ origin: AttackOrigin) {
    guard let active = activeSafeGunnery,
      origin.owner == commander.flightSimulation.player,
      active.state.permission.owner == commander.equipmentOwnerID,
      active.state.permission.carrier == commander.hullInstanceID
    else { return }
    var instance = active.instance
    var state = active.state
    do {
      try state.launch(origin, time: commander.flightSimulation.physicalTime)
    } catch {
      // A missing native lesson join cannot create quiet-time credit.
      state.discharge(time: commander.flightSimulation.physicalTime)
    }
    instance.milestones.remove(3)
    instance.savedSafeGunnery = state
    commander.scriptState.instances[instance.id] = instance
  }

  mutating func observeSafeGunneryMissileEnd(_ state: OrdnanceState) {
    guard state.termination != nil, let active = activeSafeGunnery,
      state.origin.owner == commander.flightSimulation.player
    else { return }
    var instance = active.instance
    var lesson = active.state
    lesson.endedProjectile(state.origin, time: commander.flightSimulation.physicalTime)
    instance.savedSafeGunnery = lesson
    commander.scriptState.instances[instance.id] = instance
  }

  mutating func observeSafeGunneryOrdinaryHit(_ incident: CombatIncident) {
    guard let active = activeSafeGunnery,
      incident.origin.owner == commander.flightSimulation.player,
      active.state.permission.owner == commander.equipmentOwnerID,
      active.state.permission.carrier == commander.hullInstanceID
    else { return }
    var instance = active.instance
    var state = active.state
    state.recordOrdinaryHit(incident)
    if state.ordinaryHit != nil { instance.milestones.remove(3) }
    instance.savedSafeGunnery = state
    commander.scriptState.instances[instance.id] = instance
    // No body removal here: an ordinary hit's native kernel may still hold body indices.
  }

  /// Runs after native weapon/ordnance processing; pause never reaches this producer.
  mutating func advanceSafeGunnery(delta: Double, discharged: Bool) {
    guard !paused, !docked, !isMissionTrial, delta.isFinite, delta > 0,
      let active = activeSafeGunnery
    else { return }
    if active.state.ordinaryHit != nil {
      closeFailedSafeGunneryIfNeeded()
      return
    }
    guard var instance = commander.scriptState.instances[active.instance.id],
      var state = instance.savedSafeGunnery, let provider = instance.savedNativePractice,
      nativePracticeCurrent(provider, instance: instance),
      state.progress?.matches(provider) == true
    else { return }
    if discharged { state.discharge(time: commander.flightSimulation.physicalTime) }
    do {
      try state.observeFlight(time: commander.flightSimulation.physicalTime, delta: delta)
    } catch { return }
    if state.ready { instance.milestones.insert(3) } else { instance.milestones.remove(3) }
    instance.savedSafeGunnery = state
    commander.scriptState.instances[instance.id] = instance
  }

  mutating func closeFailedSafeGunneryIfNeeded() {
    guard let active = activeSafeGunnery, active.state.ordinaryHit != nil else { return }
    if active.instance.savedNativePractice?.endedAt == nil,
      active.instance.savedNativePractice != nil
    {
      try? endNativePractice(instance: active.instance.id)
    }
    try? finishSafeGunnery(.failed)
  }

  mutating func finishSafeGunnery(_ outcome: ScriptOutcome) throws {
    var candidate = self
    try candidate.commitSafeGunneryTerminal(outcome)
    self = candidate
  }

  private mutating func commitSafeGunneryTerminal(_ outcome: ScriptOutcome) throws {
    guard let active = activeSafeGunnery, active.state.valid,
      active.state.terminalOperation == nil, [.complete, .failed, .abandoned].contains(outcome),
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      active.instance.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let dock = commander.nativeStations?.currentMainDock
    if outcome == .complete {
      guard let dock, nativeMainStationDockEvidenceIsCurrent,
        let owner = commander.equipmentOwnerID, let carrier = commander.hullInstanceID,
        let provider = active.instance.savedNativePractice,
        NativeSafeGunneryReception.allowed(
          state: active.state, provider: provider, dock: dock, owner: owner, carrier: carrier)
      else { throw SaveError.invalidCommander }
    }
    if outcome == .failed, active.state.ordinaryHit == nil { throw SaveError.invalidCommander }
    if active.instance.savedNativePractice?.endedAt == nil,
      active.instance.savedNativePractice != nil
    {
      try endNativePractice(instance: active.instance.id)
    }
    guard var mission = commander.scriptState.instances[active.instance.id],
      var state = mission.savedSafeGunnery
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
    if outcome == .complete { mission.milestones.insert(4) }
    state.terminalOperation = ScriptIdentity.uuid(
      "safe-gunnery-terminal-v1:\(mission.id):\(outcome.rawValue)")
    state.terminalOutcome = outcome
    state.terminalDock = outcome == .complete ? dock : nil
    mission.savedSafeGunnery = state
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
