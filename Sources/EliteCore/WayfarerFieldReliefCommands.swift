import Foundation

extension Game {
  /// Called after native replacement, before the existing candidate's Commander validation.
  @inline(never)
  mutating func applyFieldReliefTransition(
    previous: NativeUtilityState, action: NativeUtilityAction?
  ) throws {
    guard let utility = commander.nativeUtility, utility.owner == previous.owner,
      let job = utility.consignments.last
    else { throw SaveError.invalidCommander }
    let id = WayfarerFieldRelief.instance(job.id)
    if action == .collect {
      guard let pack = fieldReliefPack, commander.scriptState.instances[id] == nil,
        utility.consignments.count == previous.consignments.count + 1,
        job.phase == .held, let dock = nativeMainStationArrivalContext(for: utility.source)
      else { throw SaveError.invalidCommander }
      try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
      let sequence = try fieldReliefSequence()
      var state = ScriptInstance(
        id: id, definition: WayfarerFieldRelief.stateID, version: "1.0.0", digest: pack.digest)
      let accepted = scriptEventContext(state)
      let offer = ScriptContractOffer(
        id: WayfarerFieldRelief.offer(job.id), key: job.id.uuidString.lowercased(),
        title: "Remote utility relief / H0 / \(job.rewardTenths / 10) CR",
        briefing: pack.manifest.mission.briefing, destinationGalaxy: 0, destinationSystem: 237,
        reward: job.rewardTenths, deposit: 0, failureReward: 0, refundOnFailure: false,
        duration: 0, parameters: .object([:]))
      var displayed = offer
      displayed.status = .accepted(id)
      let key = WayfarerFieldRelief.boardKey
      var offers = commander.contracts.boards[key]?.offers ?? []
      guard offers.count < 2, !offers.contains(where: { $0.id == offer.id }) else {
        throw SaveError.invalidCommander
      }
      offers.append(displayed)
      commander.contracts.boards[key] = .init(
        id: WayfarerFieldRelief.boardID, provider: pack.manifest.id, version: "1.0.0",
        digest: pack.digest, title: "Remote utility relief", station: WayfarerFieldRelief.source,
        revision: 0, seed: 0, clock: .local, period: 3600, group: WayfarerFieldRelief.stateID,
        offers: offers)
      state.contract = .init(
        boardKey: key, provider: pack.manifest.id, version: "1.0.0", digest: pack.digest,
        station: WayfarerFieldRelief.source, boardRevision: 0,
        group: WayfarerFieldRelief.stateID, offer: offer, clock: .local,
        acceptedAt: commander.scriptState.localSeconds, deadline: nil)
      guard accepted.nativeMainDock == dock.receipt else { throw SaveError.invalidCommander }
      state.savedFieldRelief = .init(
        owner: utility.owner, job: job, acceptanceSequence: sequence, accepted: accepted)
      state.milestones = [0]
      state.revision = 1
      state.acknowledge(sequence)
      state.journal = [
        "Four original tonnes collected. Install these originals at the actual RRS headquarters, then separately Confirm the current engineer's inspection. \(job.rewardTenths / 10) CR only at that verified reception."
      ]
      commander.scriptState.instances[id] = state
      return
    }
    guard var state = commander.scriptState.instances[id], let leaf = state.savedFieldRelief,
      leaf.owner == utility.owner, leaf.job.id == job.id
    else { throw SaveError.invalidCommander }
    // A surviving held batch can be retired after its target-loss failure. Its terminal
    // receipt and first clue history are immutable; the native ledger records the later return.
    if state.outcome != .active {
      guard action == .returnMaterials, state.outcome == .failed,
        leaf.terminalReason == "targetDestroyed", job.phase == .returned
      else { throw SaveError.invalidCommander }
      return
    }
    if action == .install {
      guard job.phase == .installed, job.installation != nil else {
        throw SaveError.invalidCommander
      }
      state.savedFieldRelief = leaf.replacing(job)
      state.suspension = nil
      state.milestones.insert(1)
      state.revision = try fieldReliefRevision(state.revision)
      state.acknowledge(try fieldReliefSequence())
      state.journal.append("The original materials are installed. Ask the current engineer to inspect them; installation alone pays nothing.")
      commander.scriptState.instances[id] = state
      return
    }
    let outcome: ScriptOutcome
    let reason: String
    if action == .receive, job.phase == .received, job.reception != nil {
      outcome = .complete
      reason = "received"
    } else if action == .returnMaterials, job.phase == .returned {
      outcome = .abandoned
      reason = "returned"
    } else if action == nil, job.phase == .lost, let loss = job.loss {
      outcome = .failed
      reason = loss.cause.rawValue
    } else { throw SaveError.invalidCommander }
    try finishFieldRelief(state, job: job, outcome: outcome, reason: reason)
  }

  private func fieldReliefRevision(_ revision: UInt64) throws -> UInt64 {
    guard revision < UInt64(Int64.max) - 1 else { throw SaveError.invalidCommander }
    return revision + 1
  }
  private mutating func fieldReliefSequence() throws -> UInt64 {
    guard commander.scriptState.nextEvent < UInt64(Int64.max) - 1 else {
      throw SaveError.invalidCommander
    }
    commander.scriptState.nextEvent += 1
    return commander.scriptState.nextEvent
  }

  @inline(never)
  private mutating func finishFieldRelief(
    _ previous: ScriptInstance, job: NativeUtilityConsignment, outcome: ScriptOutcome,
    reason: String
  ) throws {
    guard previous.outcome == .active, let leaf = previous.savedFieldRelief else {
      throw SaveError.invalidCommander
    }
    var state = previous
    let cause = scriptEventContext(state)
    var candidate = commander
    try settleContract(outcome, state: &state, candidate: &candidate)
    commander = candidate
    let sequence = try fieldReliefSequence()
    state.outcome = outcome
    state.suspension = nil
    state.revision = try fieldReliefRevision(state.revision)
    state.acknowledge(sequence)
    state.savedFieldRelief = leaf.replacing(job, reason: reason)
    if outcome == .complete { state.milestones.insert(2) }
    state.dialogue = nil
    state.journal.append(
      outcome == .complete
        ? "Current engineer reception verified; \(job.rewardTenths / 10) CR paid. The field relief trace is retained in the journal."
        : "Field relief ended without payment. Original material history remains recorded.")
    state.completionReceipt = .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest, outcome: outcome, sequence: sequence,
      causeKind: outcome == .complete ? "dialogue.confirmed" : "mission.receipted",
      cause: cause, committed: scriptEventContext(state), revision: state.revision,
      milestones: state.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: state.contract?.settlementAmount, choices: nil)
    commander.scriptState.instances[state.id] = state
    try awardScriptClue(previous: previous, next: state, trust: .production)
    if let receipt = state.completionReceipt { try enqueueScriptCompletion(receipt) }
  }

  @inline(never)
  mutating func failFieldReliefAtDestroyedTarget() throws {
    guard let utility = commander.nativeUtility,
      commander.nativeStations?.ledger.records.first(where: {
        $0.identity == utility.target
      })?.tombstone != nil
    else { return }
    for job in utility.consignments {
      let id = WayfarerFieldRelief.instance(job.id)
      guard let state = commander.scriptState.instances[id], state.outcome == .active else {
        continue
      }
      try finishFieldRelief(state, job: job, outcome: .failed, reason: "targetDestroyed")
    }
  }
}

extension GameRuntime {
  func commitFieldReliefTargetLoss() {
    guard let utility = game.commander.nativeUtility,
      utility.consignments.contains(where: {
        game.commander.scriptState.instances[WayfarerFieldRelief.instance($0.id)]?.outcome == .active
      }),
      game.commander.nativeStations?.ledger.records.contains(where: {
        $0.identity == utility.target && $0.tombstone != nil
      }) == true
        || game.bodies.contains(where: {
          $0.nativeStationIdentity == utility.target && $0.energy.isFinite && $0.energy <= 0
        })
    else { return }
    do {
      try scriptCommand {
        try $0.persistNativeStationConditions()
        try $0.failFieldReliefAtDestroyedTarget()
      }
    } catch {
      game.notify("FIELD RELIEF FAILURE NOT SAVED - RETAINED MISSION UNCHANGED")
    }
  }
}
