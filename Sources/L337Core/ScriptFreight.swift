import Foundation

// Synchronous per-terminal ownership only; no actor hop, persisted cache or new authority.
private final class ScriptFreightTerminalAttempt {
  var candidate: Game
  var stage: ScriptRefusalStage

  @inline(never)
  init(original: borrowing Game) {
    candidate = copy original
    stage = .freightGuard
  }
}

/// Unencoded acceptance authority travels through the existing private prepared candidate.
struct ScriptFreightIssueAdmission: Sendable {
  fileprivate let job: ScriptContractJob
  fileprivate let instance: UUID
  fileprivate let epoch: UUID
  fileprivate let stationEpoch: UUID
  fileprivate let proof: ScriptFreightIssueReceipt

  func issue(into state: inout ScriptInstance, game: borrowing Game) throws
    -> OriginalConsentedFreightSupplyDelta?
  {
    var acceptedOffer = job.offer
    acceptedOffer.status = .accepted(instance)
    guard state.id == instance, state.contract == job, let plan = job.offer.freightPlan,
      state.savedOwnedCargo == nil, state.payloads.isEmpty,
      game.ecmControl.epoch == epoch, game.nativeStationRuntimeEpoch == stationEpoch,
      game.nativeMainStationDockEvidenceIsCurrent,
      proof.context.nativeMainDock == game.commander.nativeStations?.currentMainDock,
      game.commander.equipmentOwnerID == plan.owner,
      game.commander.contracts.boards[job.boardKey]?.offers.first(where: { $0.id == job.offer.id })
        == acceptedOffer,
      proof.sequence == game.commander.scriptState.nextEvent + 1,
      proof.clock == game.commander.scriptState.clock(.missionCalendar),
      let definition = plan.collection, plan.capacityFits(game.commander)
    else { throw MissionPackError("Review and confirm this job at its issuing station.") }
    let consignment = ScriptOwnedCargoState.consignmentID(owner: plan.owner, instance: instance)
    let delta =
      try plan.isConsented
      ? OriginalConsentedFreightSupply.allocate(plan: plan, instance: instance, game: game) : nil
    let units =
      delta?.units
      ?? ScriptOwnedCargoState.unitIDs(consignment: consignment, quantity: plan.quantity)
    state.savedOwnedCargo = .init(
      schema: 1, owner: plan.owner, instance: instance, issuer: plan.origin,
      commodity: definition.items[0].commodity, consignment: consignment, issued: units,
      issue: proof, held: units)
    state.payloads[ScriptOwnedCargoState.payloadKey] = units.count
    state.collections[definition.id] = .init(definition: definition)
    return delta
  }
}

extension Game {
  mutating func prepareFreightTrial(_ pack: ScriptPack) throws {
    try ScriptPackLibrary.validateFreight(pack.manifest)
    guard isMissionTrial, trialDigest == pack.digest, pack.manifest.trial?.flight == true,
      docked, !paused
    else {
      throw MissionPackError("Freight trials require their declared ordinary flight scene.")
    }
    try prepareG03FlightEquipment()
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
    else { throw MissionPackError("The native freight trial launch did not complete.") }
    // The player must actually fly, dock, review and Confirm; no trial acceptance is fabricated.
  }

  func requireFreightResources(_ plan: ScriptFreightPlan) throws {
    guard plan.valid, plan.owner == commander.equipmentOwnerID,
      nativeMainStationDockEvidenceIsCurrent, contractStation == plan.origin, !paused,
      commander.scriptState.missionCalendar != nil,
      commander.scriptState.clock(.missionCalendar) <= 1e12 - plan.duration,
      plan.routeFitsDuration, plan.capacityFits(commander)
    else {
      throw MissionPackError(
        "Review freight at its actual issuer with room for every supplied tonne.")
    }
    try OriginalConsentedFreightSupply.requireAvailable(plan, game: self)
    let systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
    for (index, edge) in zip(plan.path, plan.path.dropFirst()).enumerated() {
      let cap = index == 0 ? commander.maximumJumpDistance : commander.fullTankJumpDistance
      guard systems[edge.0].distance(to: systems[edge.1]) <= cap else {
        throw MissionPackError("Refuel or refit for the frozen freight route.")
      }
    }
  }

  func prepareFreightIssue(job: ScriptContractJob, instance: UUID) throws
    -> ScriptFreightIssueAdmission
  {
    guard let plan = job.offer.freightPlan, ScriptFreightGeneration.valid(job),
      instance == Self.contractJobIdentity(job.offer.id),
      commander.contracts.boards[job.boardKey]?.offers.first(where: { $0.id == job.offer.id })
        == job.offer,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    try requireFreightResources(plan)
    let state = ScriptInstance(
      id: instance, definition: plan.content.stateID, version: plan.content.version,
      digest: plan.content.digest)
    return .init(
      job: job, instance: instance, epoch: ecmControl.epoch,
      stationEpoch: nativeStationRuntimeEpoch,
      proof: .init(
        sequence: commander.scriptState.nextEvent + 1, clock: job.acceptedAt,
        context: scriptEventContext(state)))
  }

  func freightContentIssue(_ state: ScriptInstance, pack: ScriptPack) -> String? {
    guard let plan = state.contract?.offer.freightPlan else {
      return pack.manifest.freight == nil ? nil : "Freight requires its native accepted job."
    }
    guard plan.matches(pack), state.savedOwnedCargo != nil,
      state.collections[plan.template.id]?.definition == plan.collection
    else { return "Restore the exact freight issuer and collection terms." }
    return nil
  }

  func freightDialogueToken(_ token: String) -> String {
    token + ":freight:" + ecmControl.epoch.uuidString + ":" + nativeStationRuntimeEpoch.uuidString
  }

  mutating func markFreightFatalLoss() {
    for id in orderedScriptInstances {
      guard var state = commander.scriptState.instances[id], state.outcome == .active,
        var cargo = state.savedOwnedCargo, cargo.terminal == nil, cargo.pendingLoss == nil,
        !cargo.held.isEmpty
      else { continue }
      cargo.pendingLoss = .init(
        id: ScriptIdentity.uuid("freight-fatal-v1:" + cargo.consignment.uuidString),
        units: cargo.held, clock: commander.scriptState.clock(.missionCalendar),
        context: scriptEventContext(state))
      state.savedOwnedCargo = cargo
      commander.scriptState.instances[id] = state
    }
  }

  mutating func loseFreightOnEscape() -> Bool {
    resolveFreightTerminals(escape: true)
    return !commander.scriptState.instances.values.contains {
      $0.outcome == .active && $0.savedOwnedCargo != nil
    }
  }

  /// No route replay or history decoding on the common no-due frame path.
  mutating func resolveFreightTerminals(
    escape: Bool = false, publish: ScriptPublisher? = nil,
    diagnostics: ScriptRefusalDiagnostic? = nil
  ) {
    let now = commander.scriptState.clock(.missionCalendar)
    let due = commander.scriptState.instances.compactMap { id, state -> UUID? in
      guard state.outcome == .active, let cargo = state.savedOwnedCargo,
        cargo.terminal == nil, let job = state.contract, let plan = job.offer.freightPlan,
        cargo.pendingLoss != nil || escape || plan.permitsExpiry(at: now, deadline: job.deadline)
      else { return nil }
      return id
    }.sorted { $0.uuidString < $1.uuidString }
    for id in due {
      resolveFreightTerminal(id, escape: escape, publish: publish, diagnostics: diagnostics)
    }
  }

  @inline(never)
  private mutating func resolveFreightTerminal(
    _ id: UUID, escape: Bool, publish: ScriptPublisher?, diagnostics: ScriptRefusalDiagnostic?
  ) {
    let attempt = ScriptFreightTerminalAttempt(original: self)
    do {
      try Self.prepareFreightTerminal(attempt, id: id, escape: escape)
      try Self.validateFreightTerminal(attempt)
      try Self.writeFreightTerminal(attempt, publish: publish)
      publishFreightTerminalValue(attempt)
    } catch {
      Self.recordFreightTerminalFailure(attempt, id: id, error: error, diagnostics: diagnostics)
      notify("FREIGHT OUTCOME NOT SAVED - CONSIGNMENT NOT DELIVERABLE")
    }
  }

  // The full mutable mission and completion receipt return before cold validation/publication.
  @inline(never)
  private static func prepareFreightTerminal(
    _ attempt: ScriptFreightTerminalAttempt, id: UUID, escape: Bool
  ) throws {
    guard var state = attempt.candidate.commander.scriptState.instances[id],
      let cargo = state.savedOwnedCargo, attempt.candidate.commander.freightStateValid(state),
      attempt.candidate.commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let cause: ScriptFreightTerminalCause
    if cargo.pendingLoss != nil {
      cause = .shipDestroyed
    } else if escape {
      cause = .escapePod
    } else {
      cause = .expired
    }
    let context = cargo.pendingLoss?.context ?? attempt.candidate.scriptEventContext(state)
    let sequence = attempt.candidate.commander.scriptState.nextEvent + 1
    attempt.candidate.commander.scriptState.nextEvent = sequence
    attempt.stage = .freightFinish
    try attempt.candidate.finishFreight(
      cause, state: &state, sequence: sequence, context: context,
      candidate: &attempt.candidate.commander)
    attempt.candidate.commander.scriptState.instances[id] = state
    attempt.candidate.commander.scriptState.pendingEvents.removeAll { $0.instance == id }
    attempt.stage = .completionEnqueue
    if let receipt = state.completionReceipt {
      try attempt.candidate.enqueueScriptCompletion(receipt)
    }
  }

  @inline(never)
  private static func validateFreightTerminal(_ attempt: ScriptFreightTerminalAttempt) throws {
    attempt.stage = .freightCommander
    guard attempt.candidate.commander.valid else { throw SaveError.invalidCommander }
  }

  @inline(never)
  private static func writeFreightTerminal(
    _ attempt: ScriptFreightTerminalAttempt, publish: ScriptPublisher?
  ) throws {
    attempt.stage = .freightPublish
    try publish?(&attempt.candidate)
  }

  @inline(never)
  private mutating func publishFreightTerminalValue(_ attempt: ScriptFreightTerminalAttempt) {
    self = attempt.candidate
  }

  @inline(never)
  private static func recordFreightTerminalFailure(
    _ attempt: ScriptFreightTerminalAttempt, id: UUID, error: any Error,
    diagnostics: ScriptRefusalDiagnostic?
  ) {
    guard let diagnostics, !diagnostics.contains(.resolver) else { return }
    let checks = freightTerminalFailureChecks(attempt, id: id)
    recordFreightTerminalFailureSnapshot(
      attempt, error: error, diagnostics: diagnostics, checks: checks)
  }

  // Finish the original cold checks before constructing the error observation's Game value.
  @inline(never)
  private static func freightTerminalFailureChecks(
    _ attempt: ScriptFreightTerminalAttempt, id: UUID
  )
    -> UInt16
  {
    // Bits 1/2/4: retained freight proof, engine, whole commander; observations only.
    let freight =
      attempt.candidate.commander.scriptState.instances[id].map {
        attempt.candidate.commander.freightStateValid($0)
      } ?? false
    let checks: UInt16 =
      (freight ? 1 : 0)
      | (attempt.candidate.commander.scriptState.valid ? 2 : 0)
      | (attempt.candidate.commander.valid ? 4 : 0)
    return checks
  }

  @inline(never)
  private static func recordFreightTerminalFailureSnapshot(
    _ attempt: ScriptFreightTerminalAttempt, error: any Error, diagnostics: ScriptRefusalDiagnostic,
    checks: UInt16
  ) {
    diagnostics.record(
      .resolver, .init(stage: attempt.stage, error: error, game: attempt.candidate, checks: checks))
  }

  /// Only native issue/contact/physical-terminal factories in this feature call settlement.
  func finishFreight(
    _ cause: ScriptFreightTerminalCause, state: inout ScriptInstance, sequence: UInt64,
    context: ScriptEventContext, candidate: inout Commander
  ) throws {
    guard var cargo = state.savedOwnedCargo, cargo.terminal == nil,
      let job = state.contract, let plan = job.offer.freightPlan,
      state.outcome == .active, state.revision < UInt64.max
    else { throw SaveError.invalidCommander }
    let now = candidate.scriptState.clock(.missionCalendar)
    guard plan.deadlineMatches(job),
      cause != .delivered
        || (cargo.held.isEmpty && plan.permitsDelivery(at: now, deadline: job.deadline)),
      cause != .expired || plan.permitsExpiry(at: now, deadline: job.deadline)
    else { throw SaveError.invalidCommander }
    cargo.terminal = .init(cause: cause, sequence: sequence, clock: now, removed: cargo.held)
    cargo.held = []
    cargo.pendingLoss = nil
    state.savedOwnedCargo = cargo
    state.payloads[ScriptOwnedCargoState.payloadKey] = 0
    try settleContract(cause.outcome, state: &state, candidate: &candidate)
    // Settlement receives the same live candidate commander as ordinary contract settlement.
    // The caller installs this state only after every native confirmation has succeeded.
    state.outcome = cause.outcome
    state.dialogue = nil
    state.timers = [:]
    if cause == .delivered { state.milestones.insert(0) }
    state.revision += 1
    state.acknowledge(sequence)
    state.completionReceipt = .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest,
      outcome: cause.outcome, sequence: sequence,
      causeKind: cause == .delivered || cause == .abandoned
        ? "dialogue.confirmed" : "freight.terminated",
      cause: context, committed: scriptEventContext(state), revision: state.revision,
      milestones: state.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: cause == .delivered ? plan.successPayment : 0,
      choices: nil)
  }

  var freightPageFacts: [String] {
    commander.scriptState.instances.values.filter { $0.savedOwnedCargo != nil }
      .sorted { $0.id.uuidString < $1.id.uuidString }.flatMap { state -> [String] in
        guard let cargo = state.savedOwnedCargo else { return [] }
        return [
          state.id.uuidString, String(state.revision), cargo.consignment.uuidString,
          cargo.held.map(\.uuidString).joined(separator: ","), String(describing: cargo.terminal),
        ]
      }
  }
}
