import Foundation

enum ProviderContractEffects {
  static func authorizeManifest(_ state: inout ScriptProviderContractState) {
    guard state.eligible, state.manifest == nil else { return }
    state.manifest = state.expectedManifest
    state.receipts.insert(.manifest)
    state.progress.requested = false
    state.progress.baseline = nil
    if state.custody == .aboard { state.stage = .calibration }
  }
  static func choose(_ branch: ProviderDispatchBranch, state: inout ScriptProviderContractState)
    throws
  {
    guard state.eligible, state.manifest != nil, state.custody == .aboard else {
      throw MissionPackError("A held relay and authenticated manifest are required.")
    }
    if let previous = state.branch {
      guard previous == branch else { throw MissionPackError("Dispatch branch is already fixed.") }
      return
    }
    if branch == .full {
      guard state.progress.checkpointBits == state.terms.observation.completedBits,
        state.progress.escortSeconds >= state.terms.observation.escortSeconds
      else {
        throw MissionPackError("Actual route calibration is incomplete.")
      }
    }
    if branch == .recovery, state.core == nil && state.crew == nil {
      throw MissionPackError("Original core or safely transferred original crew proof is required.")
    }
    state.branch = branch
    state.receipts.insert(.ready)
    state.pending = nil
    state.stage = .ready
  }
  static func betray(_ proof: NativeProviderBetrayal, state: inout ScriptProviderContractState)
    throws
  {
    guard proof.valid, proof.provider == state.provider, proof.order > state.acceptedOrder else {
      throw MissionPackError("Foreign convoy incident.")
    }
    guard !state.stage.terminal else { return }
    if let prior = state.betrayal {
      if prior.order <= proof.order { return }
    }
    state.betrayal = proof
    state.stage = state.custody == .lost ? .cargoLossPending : .betrayed
    state.pending = nil
    state.progress.requested = false
    state.receipts.insert(.betrayed)
    if state.crew?.disposition == .pending {
      state.crew?.disposition = .voided
      state.receipts.insert(.crewVoided)
    }
  }
  static func settleCrew(_ state: inout ScriptProviderContractState, credits: inout Int) throws {
    guard state.eligible, state.crew?.disposition == .pending else { return }
    let amount = state.terms.crewReward
    guard (0...4_294_967_295).contains(credits) else { throw SaveError.invalidCommander }
    guard credits <= 4_294_967_295 - amount else { return }
    credits += amount
    state.crewPaid = amount
    state.crew?.disposition = .paid
    state.receipts.insert(.crewPaid)
  }
  static func close(
    _ state: inout ScriptProviderContractState, delivery: Bool,
    dock: NativeMainStationDockReceipt, order: UInt64, credits: inout Int
  ) throws {
    guard !state.stage.terminal, state.custody == .aboard, order > state.acceptedOrder,
      order < UInt64(Int64.max),
      [state.core?.order, state.crew?.order, state.betrayal?.order, state.lastRelayOrder]
        .compactMap({ $0 }).allSatisfy({ $0 <= order }),
      dock.valid, dock.commanderOwner == state.owner,
      dock.station == (delivery ? state.destination : state.origin)
    else { throw MissionPackError("Return the exact relay to its assigned current station.") }
    if delivery {
      guard state.eligible, state.branch != nil, state.manifest != nil else {
        throw MissionPackError("Dispatch is not authorized.")
      }
    }
    let base = delivery ? state.terms.reward(state.branch!) : 0
    let crew = state.owedCrewReward
    guard (0...4_294_967_295).contains(credits), credits <= 4_294_967_295 - base - crew else {
      throw MissionPackError("The whole payment cannot fit. Relay custody remains pending.")
    }
    credits += base + crew
    if state.crew?.disposition == .pending, state.eligible {
      state.crew?.disposition = .paid
      state.crewPaid = crew
      state.receipts.insert(.crewPaid)
    }
    state.basePaid = base
    state.custody = delivery ? .delivered : .returned
    state.stage = delivery ? .completed : .cancelled
    state.terminalDock = dock
    state.terminalOrder = order
    state.pending = nil
    state.receipts.insert(.terminal)
  }
}

extension Game {
  func providerContractAcceptanceState(
    _ pack: ScriptPack, facts: NativeProviderMissionFacts,
    instance: UUID
  ) throws -> ScriptProviderContractState {
    guard acceptsProviderMissionFacts(facts), let terms = pack.manifest.providerContract,
      terms.valid,
      facts.source.provider.definition == terms.provider,
      facts.source.provider.system == terms.origin,
      facts.source.origin.system == terms.origin,
      facts.source.destination.system == terms.destination,
      facts.source.operationsReady.isSuperset(
        of: ScriptProviderContractDefinition.requiredOperations),
      facts.source.available == .tracking, facts.source.routeAvailable, !facts.source.playerThreat,
      facts.source.manifest.valid,
      !commander.scriptState.instances.values.contains(where: {
        $0.definition == pack.manifest.stateID
      }),
      let context = nativeMainStationArrivalContext(for: facts.source.origin),
      acceptsNativeMainStationArrivalContext(context),
      let mass = commander.checkedCargoTonnes, mass < commander.standardCargoCapacity,
      scriptDurabilityAvailable
    else {
      throw MissionPackError(
        "Complete native provider support, current origin docking and 1t free hold are required.")
    }
    return .init(
      instance: instance, terms: terms, owner: facts.commanderOwner,
      provider: facts.source.provider, subject: facts.source.subject,
      expectedManifest: facts.source.manifest,
      origin: facts.source.origin, destination: facts.source.destination,
      item: ScriptProviderContractState.itemID(instance: instance, payload: terms.payload),
      acceptedOrder: facts.source.currentOrder)
  }

  mutating func applyProviderMissionAction(
    _ action: ProviderMissionAction, instance id: UUID,
    facts: NativeProviderMissionFacts, reviewToken: UUID?
  ) throws {
    var candidate = self
    try candidate.stageProviderMissionAction(
      action, instance: id, facts: facts, reviewToken: reviewToken)
    self = candidate
  }

  private mutating func stageProviderMissionAction(
    _ action: ProviderMissionAction, instance id: UUID,
    facts: NativeProviderMissionFacts, reviewToken: UUID?
  ) throws {
    guard acceptsProviderMissionFacts(facts), var instance = commander.scriptState.instances[id],
      var state = instance.savedProviderContract, state.valid(instance: instance),
      ScriptProviderVersionedSave.validateClaims(commander),
      facts.source.operationsReady.isSuperset(
        of: ScriptProviderContractDefinition.requiredOperations),
      facts.source.provider == state.provider, facts.source.subject == state.subject,
      facts.source.manifest == state.expectedManifest, !state.stage.terminal
    else {
      throw MissionPackError("Resolve the original provider on this actor turn and review again.")
    }
    let before = state
    if action != .back && action != .continueCalibration {
      try reconcileProviderEvidence(facts, instance: &instance, state: &state)
    }
    switch action {
    case .requestManifest:
      guard state.eligible, state.manifest == nil, state.custody == .aboard,
        facts.source.available == .tracking
      else {
        throw MissionPackError("Manifest request is unavailable.")
      }
      state.progress.requested = true
      state.pending = nil
    case .reviewUrgent:
      guard state.eligible, state.manifest != nil, state.branch == nil else {
        throw MissionPackError("Authenticated uncommitted dispatch is required.")
      }
      state.pending = .init(
        action: .confirmUrgent, token: UUID(), runtimeEpoch: nativeStationRuntimeEpoch)
    case .confirmUrgent:
      guard state.pending?.action == .confirmUrgent, state.pending?.token == reviewToken,
        state.pending?.runtimeEpoch == nativeStationRuntimeEpoch
      else {
        throw MissionPackError("Review the urgent dispatch and explicitly confirm.")
      }
      try ProviderContractEffects.choose(.urgent, state: &state)
    case .back, .continueCalibration: state.pending = nil
    case .recoverCore:
      guard state.eligible, let core = facts.source.core,
        providerCoreClaimIsAuthentic(core, state: state)
      else {
        throw MissionPackError("No lawful original source computer core claim is available.")
      }
      if state.core == nil {
        state.core = core
        state.receipts.insert(.core)
      }
      ProviderContractEffects.authorizeManifest(&state)
      if state.branch == nil { try ProviderContractEffects.choose(.recovery, state: &state) }
    case .deliver, .returnRelay:
      let destination = action == .deliver ? state.destination : state.origin
      guard let context = nativeMainStationArrivalContext(for: destination),
        acceptsNativeMainStationArrivalContext(context)
      else {
        throw MissionPackError("Genuinely dock at the exact assigned station to confirm.")
      }
      try ProviderContractEffects.close(
        &state, delivery: action == .deliver,
        dock: context.receipt, order: facts.source.currentOrder, credits: &commander.credits)
      instance.payloads.removeValue(forKey: state.terms.payload)
    }
    instance.savedProviderContract = state
    if state.stage.terminal { try finishProviderContract(&instance) }
    commander.scriptState.instances[id] = instance
    if let receipt = instance.completionReceipt { try enqueueScriptCompletion(receipt) }
    if !state.stage.terminal, state.receipts != before.receipts {
      emitScriptEvent(
        "provider.transition",
        values: [
          "receipts": .array(
            state.receipts.subtracting(before.receipts).map(\.rawValue).sorted().map(
              ScriptValue.string)),
          "checkpoints": .integer(0),
        ], only: id)
    }
    guard commander.valid else { throw SaveError.invalidCommander }
  }

  mutating func finishProviderContract(_ instance: inout ScriptInstance) throws {
    guard let state = instance.savedProviderContract, state.stage.terminal,
      let pack = scriptPack(for: instance), instance.outcome == .active,
      scriptUnavailable(pack) == nil, instance.suspension == nil,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      instance.revision < UInt64(Int64.max) - 1
    else {
      throw MissionPackError("Restore the accepted contract content before final closure.")
    }
    commander.scriptState.nextEvent += 1
    let event = ScriptEvent(
      sequence: commander.scriptState.nextEvent, kind: "provider.closed",
      instance: instance.id, values: [:], context: scriptEventContext(instance))
    if let handler = pack.manifest.handlers.first(where: { $0.event == "provider.closed" }) {
      let presentation = try ScriptEvaluator.evaluate(
        source: pack.source, handler: handler.function,
        event: event.value, snapshot: scopedScriptSnapshot(instance), state: instance.data)
      // Terminal presentation cannot mutate cargo, cash, actors or completion authority.
      for command in presentation.commands {
        guard let fields = command.object, Set(fields.keys) == ["op", "text"],
          command["op"]?.string == "journal.append", let text = command["text"]?.string,
          (1...12000).contains(text.utf8.count), instance.journal.count < 512
        else {
          throw MissionPackError("Provider terminal presentation must be a bounded journal entry.")
        }
        instance.journal.append(text)
        notify(text)
      }
    }
    if state.stage == .completed {
      // The sole compulsory milestone is the genuinely committed relay handoff.
      guard pack.manifest.mission.milestones.count == 1 else { throw SaveError.invalidCommander }
      instance.milestones.insert(0)
    }
    let outcome: ScriptOutcome =
      state.stage == .completed
      ? .complete : (state.betrayal == nil && state.stage == .cancelled ? .abandoned : .failed)
    var settlement = commander
    try finishScriptMission(outcome, pack: pack, state: &instance, candidate: &settlement)
    commander = settlement
    instance.revision += 1
    instance.acknowledge(event.sequence)
    instance.completionReceipt = completionReceipt(instance, event: event, pack: pack)
  }
}
