import Foundation

struct ProviderMissionObservationUpdate: Sendable {
  let progressChanged: Bool
  let requiresPublication: Bool
}

private enum ProviderOrderedEvidence {
  case care(ProviderCrewClaim)
  case betrayal(NativeProviderBetrayal)
  var order: UInt64 {
    switch self {
    case .care(let claim): claim.order
    case .betrayal(let proof): proof.order
    }
  }
}

/// Called only by fresh native consumers. These bits authorize presentation, never rewards.
enum ProviderMissionGuidance {
  /// The native caller has already proved the exact current destination dock.
  static func deliveryContactIsAvailable(
    _ available: Bool?, state: inout ScriptProviderContractState
  ) throws -> Bool {
    guard state.eligible, state.branch != nil, state.manifest != nil, state.custody == .aboard
    else {
      throw MissionPackError("Dispatch is not authorized.")
    }
    guard let available else {
      throw MissionPackError("Resolve the actual destination service before delivery.")
    }
    if !available { state.presentOnce(.unavailable) }
    return available
  }

  static func reviewUrgent(_ state: inout ScriptProviderContractState, runtimeEpoch: UUID) throws {
    guard state.eligible, state.manifest != nil, state.branch == nil, state.custody == .aboard
    else {
      throw MissionPackError("Authenticated uncommitted dispatch is required.")
    }
    state.pending = .init(action: .confirmUrgent, token: UUID(), runtimeEpoch: runtimeEpoch)
    state.presentOnce(.urgentChoice)
  }

  static func observe(
    _ availability: NativeProviderAvailability,
    interval: ProviderMissionInterval?, destinationContactAvailable: Bool?, destinationDocked: Bool,
    state: inout ScriptProviderContractState
  ) {
    guard state.eligible, state.custody == .aboard else { return }
    if state.branch == nil {
      switch availability {
      case .disabled:
        state.stage = .crisis
        state.presentOnce(.disabled)
      case .destroyed:
        state.stage = .crisis
        state.presentOnce(.lostSanta)
      case .uncrewed, .ended:
        state.stage = .crisis
        state.presentOnce(.sourceUnavailable)
      case .tracking:
        state.stage = state.manifest == nil ? .rendezvous : .calibration
        if state.progress.requested, state.manifest == nil, let interval,
          interval.provider == state.provider, interval.subject == state.subject,
          ProviderMissionObservation.hasActualContact(interval, terms: state.terms.observation)
        {
          state.presentOnce(.hello)
        }
      case .defending, .unloaded: break
      }
    }
    if state.branch != nil, destinationDocked, destinationContactAvailable == false {
      state.presentOnce(.unavailable)
    }
  }
}

extension ScriptProviderContractState {
  func hasFiniteTransition(since previous: Self) -> Bool {
    receipts != previous.receipts || presentationBits != previous.presentationBits
      || progress.checkpointBits != previous.progress.checkpointBits
      || (custody == .lost && previous.custody != .lost)
  }
  func transitionValues(since previous: Self) -> [String: ScriptValue] {
    [
      "receipts": .array(
        receipts.subtracting(previous.receipts).map(\.rawValue).sorted().map(ScriptValue.string)),
      "checkpoints": .integer(Int64(progress.checkpointBits & ~previous.progress.checkpointBits)),
      "cues": .array(newCues(since: previous).map(\.rawValue).map(ScriptValue.string)),
    ]
  }
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
    var evidence: [ProviderOrderedEvidence] = []
    if let people = commander.nativePeople, people.owner == state.owner {
      for operation in source.personOperations where operation.order > state.acceptedOrder {
        guard let receipt = people.transfers.first(where: { $0.operation == operation.operation }),
          receipt.owner == state.owner,
          let person = receipt.members.first(where: { person in
            person.emp.source == operation.source
              && people.admissions.contains {
                $0.person == person && $0.valid(commander: commander)
              }
          })
        else { continue }
        if receipt.kind == .sale {
          evidence.append(
            .betrayal(
              .init(
                provider: state.provider, member: state.subject,
                incident: nil, personSale: receipt.operation, order: operation.order)))
        } else if receipt.kind == .care, let dock = receipt.dock,
          dock.station == state.origin, dock.commanderOwner == state.owner, dock.valid
        {
          evidence.append(
            .care(
              .init(
                operation: receipt.operation, person: person, dock: dock,
                order: operation.order, disposition: .pending)))
        }
      }
    }
    if let proof = source.betrayal, proof.order > state.acceptedOrder {
      guard proof.valid, proof.provider == state.provider else {
        throw MissionPackError("Foreign convoy incident.")
      }
      // A sale projection must join the same authenticated original-person operation.
      // Combat legality is resolved by G1, rather than inferred from a later care receipt.
      if let sale = proof.personSale {
        guard
          evidence.contains(where: {
            if case .betrayal(let joined) = $0 {
              return joined.personSale == sale && joined.order == proof.order
            }
            return false
          })
        else { throw MissionPackError("Unjoined native person sale.") }
      } else {
        evidence.append(.betrayal(proof))
      }
    }
    guard Set(evidence.map(\.order)).count == evidence.count else {
      throw MissionPackError("Distinct native operations require distinct causal orders.")
    }
    for entry in evidence.sorted(by: { $0.order < $1.order }) {
      switch entry {
      case .betrayal(let proof): try ProviderContractEffects.betray(proof, state: &state)
      case .care(let claim):
        guard state.eligible, state.crew == nil else { continue }
        state.crew = claim
        state.receipts.insert(.care)
        ProviderContractEffects.authorizeManifest(&state)
        if state.branch == nil, state.custody == .aboard {
          try ProviderContractEffects.choose(.recovery, state: &state)
        }
      }
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
  /// It publishes finite receipt/checkpoint/guidance transitions; normal saves capture bounded progress.
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
      ProviderMissionGuidance.observe(
        facts.source.available, interval: interval,
        destinationContactAvailable: nil, destinationDocked: false, state: &state)
      state.progress = result.progress
      if result.contactCompleted { ProviderContractEffects.authorizeManifest(&state) }
      if result.fullReady, state.branch == nil {
        try ProviderContractEffects.choose(.full, state: &state)
      }
    } else {
      state.progress.baseline = nil
      if state.manifest == nil { state.progress.handshakeSeconds = 0 }
    }
    let destinationDocked =
      nativeMainStationArrivalContext(for: state.destination)
      .map { acceptsNativeMainStationArrivalContext($0) } ?? false
    ProviderMissionGuidance.observe(
      facts.source.available, interval: nil,
      destinationContactAvailable: facts.source.destinationContactAvailable,
      destinationDocked: destinationDocked, state: &state)
    if supported, state.custody == .lost, state.crew?.disposition != .pending,
      let pack = scriptPack(for: instance), scriptUnavailable(pack) == nil,
      instance.suspension == nil
    {
      state.stage = .failedCargo
      state.terminalOrder = facts.source.currentOrder
      state.receipts.insert(.terminal)
    }
    instance.savedProviderContract = state
    let transition = state.hasFiniteTransition(since: before)
    if state.stage.terminal { try finishProviderContract(&instance) }
    commander.scriptState.instances[id] = instance
    if let receipt = instance.completionReceipt { try enqueueScriptCompletion(receipt) }
    if transition, !state.stage.terminal {
      emitScriptEvent(
        "provider.transition",
        values: state.transitionValues(since: before), only: id)
    }
    guard commander.valid else { throw SaveError.invalidCommander }
    return .init(
      progressChanged: state != before,
      requiresPublication: transition || state.custody != before.custody)
  }
}
