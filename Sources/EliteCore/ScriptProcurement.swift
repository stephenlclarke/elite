import Foundation

extension Game {
  mutating func prepareProcurementTrial(_ pack: ScriptPack) throws {
    try ScriptPackLibrary.validateProcurement(pack.manifest)
    guard isMissionTrial, trialDigest == pack.digest, pack.manifest.trial?.flight == true,
      docked, !paused
    else {
      throw MissionPackError("Procurement trials require their declared ordinary flight scene.")
    }
    let previousVisit = commander.flightSimulation.visit
    let owner = commander.equipmentOwnerID
    let credits = commander.credits
    let cargo = commander.cargo
    launch()
    guard !docked, !paused, screen.isFlight, commander.equipmentOwnerID == owner,
      commander.credits == credits, commander.cargo == cargo,
      commander.flightSimulation.visit == previousVisit + 1,
      commander.flightSimulation.system == systemIdentity,
      commander.flightSimulation.player != nil,
      bodies.contains(where: {
        $0.id == 0 && $0.hull == .station
          && $0.physical?.identity == commander.flightSimulation.anchors?.station.identity
      }),
      commander.nativeStations?.mainStations.contains(where: { $0.system == systemIdentity })
        == true,
      commander.scriptState.instances.isEmpty
    else { throw MissionPackError("The native procurement trial launch did not complete.") }
    // The player must actually fly, dock, review and Confirm; no trial acceptance is fabricated.
  }

  func requireProcurementResources(_ plan: ScriptProcurementPlan) throws {
    guard plan.valid, plan.owner == commander.equipmentOwnerID,
      contractStation == plan.origin, nativeMainStationDockEvidenceIsCurrent, !paused,
      plan.calendarLowerBoundSeconds < plan.duration,
      commander.scriptState.missionCalendar != nil,
      commander.scriptState.clock(.missionCalendar) <= 1e12 - plan.duration,
      plan.commodity != nil
    else { throw MissionPackError("Review this reachable job at its actual native main station.") }
    guard plan.capacityFits(commander) else {
      throw MissionPackError("Make room for the requested goods; protected goods cannot count.")
    }
    let systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
    for (index, edge) in zip(plan.path, plan.path.dropFirst()).enumerated() {
      let cap = index == 0 ? commander.maximumJumpDistance : commander.fullTankJumpDistance
      guard systems[edge.0].distance(to: systems[edge.1]) <= cap else {
        throw MissionPackError("Refuel or refit for the frozen route; this job will not reroll.")
      }
    }
  }

  func procurementContentIssue(_ state: ScriptInstance, pack: ScriptPack) -> String? {
    guard let job = state.contract, ScriptProcurementPlan.isMarked(job.offer.parameters) else {
      return pack.manifest.procurement == nil
        ? nil : "Procurement requires its native accepted job."
    }
    guard let plan = ScriptProcurementPlan.read(job.offer.parameters), plan.matches(pack),
      let definition = resolvedScriptCollectionDefinition(
        plan.template.id, pack: pack, state: state),
      state.collections[plan.template.id]?.definition == definition
    else { return "Restore the exact procurement terms and collection template." }
    return nil
  }

  func validateInstalledProcurementContent() throws {
    for board in commander.contracts.boards.values {
      for offer in board.offers where ScriptProcurementPlan.isMarked(offer.parameters) {
        guard let plan = ScriptProcurementPlan.read(offer.parameters), plan.matches(offer),
          plan.owner == commander.equipmentOwnerID, ScriptProcurementGeneration.valid(board)
        else { throw SaveError.invalidCommander }
        if let pack = scriptPacks.first(where: { $0.digest == board.digest }) {
          guard plan.matches(pack),
            (try? ScriptPackLibrary.validateProcurement(pack.manifest)) != nil
          else { throw SaveError.invalidCommander }
        }
      }
    }
    for state in commander.scriptState.instances.values {
      guard let job = state.contract, ScriptProcurementPlan.isMarked(job.offer.parameters) else {
        continue
      }
      guard commander.procurementStateValid(state) else { throw SaveError.invalidCommander }
      if let pack = scriptPack(for: state), procurementContentIssue(state, pack: pack) != nil {
        throw SaveError.invalidCommander
      }
    }
  }

  /// The no-due frame path holds no plan, candidate or receipt buffers and replays no routes.
  mutating func resolveProcurementTerminals(publish: ScriptPublisher?) {
    let now = commander.scriptState.clock(.missionCalendar)
    let due = commander.scriptState.instances.compactMap { id, state -> UUID? in
      guard state.outcome == .active, let job = state.contract, !job.settled,
        job.offer.courier == nil, job.clock == .missionCalendar,
        job.deadlinePolicy == .inclusiveConfirmation,
        job.group == job.provider + "/" + ScriptProcurementPlan.group,
        ScriptProcurementPlan.isMarked(job.offer.parameters), let deadline = job.deadline,
        now > deadline
      else { return nil }
      return id
    }.sorted { $0.uuidString < $1.uuidString }
    for id in due { finalizeProcurementExpiry(id, publish: publish) }
  }

  // Enter this cold frame only after the cheap predicate has returned its IDs.
  @inline(never)
  private mutating func finalizeProcurementExpiry(_ id: UUID, publish: ScriptPublisher?) {
    do {
      try validateProcurementExpirySource(id)
      try publishProcurementExpiryCandidate(id, publish: publish)
    } catch { notify("PROCUREMENT OUTCOME NOT SAVED - DELIVERY UNAVAILABLE") }
  }

  @inline(never)
  private func validateProcurementExpirySource(_ id: UUID) throws {
    guard let state = commander.scriptState.instances[id], state.outcome == .active,
      let job = state.contract, !job.settled, let due = job.deadline,
      commander.scriptState.clock(.missionCalendar) > due,
      commander.procurementStateValid(state),
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
  }

  @inline(never)
  private mutating func publishProcurementExpiryCandidate(_ id: UUID, publish: ScriptPublisher?)
    throws
  {
    var candidate = self
    guard var state = candidate.commander.scriptState.instances[id] else {
      throw SaveError.invalidCommander
    }
    let sequence = candidate.commander.scriptState.nextEvent + 1
    let cause = candidate.scriptEventContext(state)
    candidate.commander.scriptState.nextEvent = sequence
    try candidate.settleContract(.failed, state: &state, candidate: &candidate.commander)
    state.outcome = .failed
    state.dialogue = nil
    state.timers = [:]
    state.revision += 1
    state.acknowledge(sequence)
    state.completionReceipt = .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest,
      outcome: .failed, sequence: sequence, causeKind: "procurement.terminated", cause: cause,
      committed: candidate.scriptEventContext(state), revision: state.revision,
      milestones: state.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: 0,
      choices: state.choiceReceipts.isEmpty ? nil : state.choiceReceipts)
    candidate.commander.scriptState.instances[id] = state
    candidate.commander.scriptState.pendingEvents.removeAll { $0.instance == id }
    if let receipt = state.completionReceipt { try candidate.enqueueScriptCompletion(receipt) }
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    try publish?(&candidate)
    self = candidate
  }
}
