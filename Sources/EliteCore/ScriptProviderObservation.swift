import Foundation

struct ProviderMissionObservationUpdate: Sendable {
  let progressChanged: Bool
  let requiresPublication: Bool
}

extension Game {
  func providerCoreClaimIsAuthentic(
    _ claim: NativeProviderCoreClaim,
    state: ScriptProviderContractState
  ) -> Bool {
    guard claim.provider == state.provider, claim.subject == state.subject,
      claim.manifest == state.expectedManifest, claim.owner == state.owner,
      claim.order > state.acceptedOrder
    else { return false }
    let lots: [SalvageLot]
    if let operation = claim.settlement {
      guard
        case .committed(let receipt)? = commander.salvageLedger.settlementReceipt(for: operation)
      else { return false }
      lots = receipt.items
    } else {
      lots = commander.salvageLedger.inventory
    }
    return lots.contains { lot in
      guard lot.identity == claim.lot,
        case .technology(let definition, _, _) = lot.content
      else { return false }
      return definition == "computer-core"
    }
  }

  /// The native owner authenticates each original source and supplies one common causal order.
  /// Every care claim is additionally joined to the actual outbound native custody receipt.
  mutating func reconcileProviderEvidence(
    _ facts: NativeProviderMissionFacts,
    instance: inout ScriptInstance, state: inout ScriptProviderContractState
  ) throws {
    let source = facts.source
    guard acceptsProviderMissionFacts(facts), source.provider == state.provider,
      source.subject == state.subject, source.manifest == state.expectedManifest,
      source.currentOrder >= state.acceptedOrder
    else { throw MissionPackError("Foreign provider evidence.") }
    if let people = commander.nativePeople, people.owner == state.owner {
      for operation in source.personOperations.sorted(by: { $0.order < $1.order })
      where operation.order > state.acceptedOrder {
        guard let receipt = people.transfers.first(where: { $0.operation == operation.operation }),
          receipt.owner == state.owner
        else { continue }
        let members = receipt.members.filter { person in
          person.emp.source == operation.source
            && people.admissions.contains { $0.person == person && $0.valid(commander: commander) }
        }
        guard let person = members.first else { continue }
        if receipt.kind == .sale {
          try ProviderContractEffects.betray(
            .init(
              provider: state.provider, member: state.subject,
              incident: nil, personSale: receipt.operation, order: operation.order), state: &state)
        } else if receipt.kind == .care, let dock = receipt.dock,
          dock.station == state.origin, dock.commanderOwner == state.owner, dock.valid,
          state.crew == nil, state.betrayal == nil
        {
          state.crew = .init(
            operation: receipt.operation, person: person, dock: dock,
            order: operation.order, disposition: .pending)
          state.receipts.insert(.care)
          ProviderContractEffects.authorizeManifest(&state)
          if state.branch == nil, state.custody == .aboard {
            try ProviderContractEffects.choose(.recovery, state: &state)
          }
        }
      }
    }
    if let proof = source.betrayal, proof.order > state.acceptedOrder {
      // A sale must also have its actual native receipt. Combat legality is resolved by G1.
      if let sale = proof.personSale {
        guard
          let operation = source.personOperations.first(where: {
            $0.operation == sale && $0.order == proof.order
          }),
          commander.nativePeople?.transfers.contains(where: {
            $0.operation == sale && $0.kind == .sale && $0.owner == state.owner
              && $0.members.contains(where: { $0.emp.source == operation.source })
          }) == true
        else { throw MissionPackError("Unjoined native person sale.") }
      }
      try ProviderContractEffects.betray(proof, state: &state)
    }
    if source.operationsReady.isSuperset(of: ScriptProviderContractDefinition.requiredOperations) {
      try ProviderContractEffects.settleCrew(&state, credits: &commander.credits)
    }
    if let relay = source.relay {
      guard relay.instance == state.instance, relay.item == state.item,
        relay.order > state.acceptedOrder, relay.order <= source.currentOrder,
        ![.delivered, .returned].contains(relay.custody),
        relay.custody != .world
          || relay.worldPayload == .mission(instance: state.instance, payload: state.terms.payload)
      else { throw MissionPackError("Foreign or unsupported relay custody observation.") }
      if state.custody != .lost, relay.custody != .unavailable,
        relay.order > (state.lastRelayOrder ?? state.acceptedOrder)
      {
        if relay.custody == .aboard, state.custody != .aboard {
          guard let tonnes = commander.checkedCargoTonnes, tonnes < commander.standardCargoCapacity
          else {
            throw MissionPackError("Native recovered relay requires one free tonne.")
          }
        }
        state.custody = relay.custody
        state.lastRelayOrder = relay.order
        if relay.custody == .lost {
          state.cargoLossOrder = relay.order
          state.stage = .cargoLossPending
          state.pending = nil
          state.progress.requested = false
        }
        instance.payloads[state.terms.payload] = relay.custody == .aboard ? 1 : nil
      }
    }
  }

  /// G1 calls after admitting physical movement. Ordinary frame progress never emits a command.
  /// It publishes only finite receipt/checkpoint transitions; normal saves capture bounded progress.
  mutating func observeProviderMission(_ facts: NativeProviderMissionFacts, instance id: UUID)
    throws
    -> ProviderMissionObservationUpdate
  {
    var candidate = self
    let result = try candidate.foldProviderMission(facts, instance: id)
    self = candidate
    return result
  }

  private mutating func foldProviderMission(_ facts: NativeProviderMissionFacts, instance id: UUID)
    throws
    -> ProviderMissionObservationUpdate
  {
    guard acceptsProviderMissionFacts(facts), var instance = commander.scriptState.instances[id],
      var state = instance.savedProviderContract, state.valid(instance: instance),
      ScriptProviderVersionedSave.validateClaims(commander)
    else {
      throw MissionPackError("No authenticated provider contract.")
    }
    guard !state.stage.terminal else {
      return .init(progressChanged: false, requiresPublication: false)
    }
    let before = state
    try reconcileProviderEvidence(facts, instance: &instance, state: &state)
    if state.eligible, state.branch == nil, state.custody == .aboard {
      if [.disabled, .uncrewed, .destroyed, .ended].contains(facts.source.available) {
        state.stage = .crisis
      } else if facts.source.available == .tracking {
        state.stage = state.manifest == nil ? .rendezvous : .calibration
      }
    }
    let supported = facts.source.operationsReady.isSuperset(
      of: ScriptProviderContractDefinition.requiredOperations)
    if supported, state.eligible, state.custody == .aboard, facts.source.available == .tracking,
      let interval = facts.source.interval
    {
      guard interval.provider == state.provider, interval.subject == state.subject,
        interval.endTime == facts.physicalTime
      else { throw MissionPackError("Foreign route interval.") }
      let result = try ProviderMissionObservation.fold(
        state.progress, interval: interval,
        runtimeEpoch: facts.runtimeEpoch, terms: state.terms.observation,
        manifestReceived: state.manifest != nil,
        calibrationOpen: state.branch == nil && facts.source.available == .tracking)
      state.progress = result.progress
      if result.contactCompleted { ProviderContractEffects.authorizeManifest(&state) }
      if result.fullReady, state.branch == nil {
        try ProviderContractEffects.choose(.full, state: &state)
      }
    } else {
      state.progress.baseline = nil
      if state.manifest == nil { state.progress.handshakeSeconds = 0 }
    }
    if supported, state.custody == .lost, state.crew?.disposition != .pending,
      let pack = scriptPack(for: instance), scriptUnavailable(pack) == nil,
      instance.suspension == nil
    {
      state.stage = .failedCargo
      state.terminalOrder = facts.source.currentOrder
      state.receipts.insert(.terminal)
    }
    instance.savedProviderContract = state
    let transition =
      state.receipts != before.receipts
      || state.progress.checkpointBits != before.progress.checkpointBits
      || (state.custody == .lost && before.custody != .lost)
    if state.stage.terminal { try finishProviderContract(&instance) }
    commander.scriptState.instances[id] = instance
    if let receipt = instance.completionReceipt { try enqueueScriptCompletion(receipt) }
    if transition, !state.stage.terminal {
      emitScriptEvent(
        "provider.transition",
        values: [
          "receipts": .array(
            state.receipts.subtracting(before.receipts).map(\.rawValue).sorted().map(
              ScriptValue.string)),
          "checkpoints": .integer(
            Int64(state.progress.checkpointBits & ~before.progress.checkpointBits)),
        ], only: id)
    }
    guard commander.valid else { throw SaveError.invalidCommander }
    return .init(
      progressChanged: state != before,
      requiresPublication: transition || state.custody != before.custody)
  }
}
