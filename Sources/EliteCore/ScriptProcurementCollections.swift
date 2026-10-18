import Foundation

/// Only the actual native confirmation factories in this file construct authority.
/// Persisted parameters, dialogue tokens and receipts are descriptive, not admissions.
struct ScriptProcurementAdmission: Sendable {
  enum Kind: Sendable { case delivery, abandon }
  fileprivate let kind: Kind
  fileprivate let instance: UUID
  fileprivate let revision: UInt64
  fileprivate let sequence: UInt64
  fileprivate let epoch: UUID
  fileprivate let stationEpoch: UUID
  fileprivate let owner: UUID
  fileprivate let clock: Double
  fileprivate let cause: ScriptEventContext
  fileprivate let dialogue: String
  fileprivate init(
    kind: Kind, state: ScriptInstance, sequence: UInt64, game: Game,
    owner: UUID, clock: Double, cause: ScriptEventContext, dialogue: String
  ) {
    self.kind = kind
    instance = state.id
    revision = state.revision
    self.sequence = sequence
    epoch = game.ecmControl.epoch
    stationEpoch = game.nativeStationRuntimeEpoch
    self.owner = owner
    self.clock = clock
    self.cause = cause
    self.dialogue = dialogue
  }
  func permits(
    _ outcome: ScriptOutcome, game: Game, state: ScriptInstance, candidate: Commander
  ) -> Bool {
    guard instance == state.id, revision == state.revision,
      epoch == game.ecmControl.epoch, stationEpoch == game.nativeStationRuntimeEpoch,
      game.nativeMainStationDockEvidenceIsCurrent, candidate.equipmentOwnerID == owner,
      clock == candidate.scriptState.clock(.missionCalendar),
      cause.nativeMainDock == candidate.nativeStations?.currentMainDock,
      let job = state.contract, let plan = ScriptProcurementPlan.read(job.offer.parameters),
      plan.owner == owner, ScriptProcurementGeneration.valid(job),
      state.collections[plan.template.id]?.definition == plan.collection, !job.settled
    else { return false }
    switch kind {
    case .delivery:
      guard outcome == .complete, let due = job.deadline, clock <= due,
        let collection = state.collections[plan.template.id], collection.complete,
        let lot = collection.lots[sequence]
      else { return false }
      return dialogue == plan.deliveryContact && lot.instance == instance
        && lot.sequence == sequence && lot.cause == cause
        && lot.dialogue == dialogue && lot.revision == revision + 1
        && cause.galaxy == plan.origin.galaxy && cause.system == plan.path.last
    case .abandon:
      return outcome == .abandoned && dialogue == plan.abandonContact
        && cause.galaxy == job.station.galaxy && cause.system == job.station.system
    }
  }
}

extension Game {
  func resolvedScriptCollectionDefinition(
    _ id: String, pack: ScriptPack, state: ScriptInstance, commander candidate: Commander? = nil
  ) -> ScriptCollectionDefinition? {
    let owner = (candidate ?? commander).equipmentOwnerID
    guard pack.manifest.procurement != nil else {
      guard state.contract.map({ !ScriptProcurementPlan.isMarked($0.offer.parameters) }) ?? true
      else { return nil }
      return pack.manifest.collections?.first { $0.id == id }
    }
    guard let job = state.contract, let plan = ScriptProcurementPlan.read(job.offer.parameters),
      ScriptProcurementGeneration.valid(job), plan.matches(pack), plan.owner == owner,
      state.definition == plan.content.stateID, state.version == plan.content.version,
      state.digest == plan.content.digest, id == plan.template.id,
      (try? ScriptPackLibrary.validateProcurement(pack.manifest)) != nil
    else { return nil }
    return plan.collection
  }

  func procurementContactIsCurrent(_ state: ScriptInstance, commander candidate: Commander) -> Bool
  {
    guard let job = state.contract, let plan = ScriptProcurementPlan.read(job.offer.parameters),
      state.outcome == .active, !job.settled, state.suspension == nil,
      nativeMainStationDockEvidenceIsCurrent, !paused,
      candidate.equipmentOwnerID == plan.owner,
      candidate.galaxy == plan.origin.galaxy, candidate.system == plan.path.last,
      let due = job.deadline, candidate.scriptState.clock(.missionCalendar) <= due
    else { return false }
    return true
  }

  func procurementDialogueToken(_ token: String) -> String {
    token + ":g03:" + ecmControl.epoch.uuidString + ":" + nativeStationRuntimeEpoch.uuidString
  }

  private func procurementConfirmation(
    state: ScriptInstance, dialogue: ScriptDialogue, pack: ScriptPack,
    event: ScriptEvent, candidate: Commander, kind: ScriptProcurementAdmission.Kind
  ) throws -> ScriptProcurementAdmission {
    guard let job = state.contract, let plan = ScriptProcurementPlan.read(job.offer.parameters),
      ScriptProcurementGeneration.valid(job), plan.matches(pack),
      plan.owner == candidate.equipmentOwnerID,
      state.suspension == nil, state.outcome == .active, !job.settled, !paused,
      scriptOffer == state.id, scriptPresentedDialogue == dialogue, state.dialogue == dialogue,
      dialogue.revision == state.revision,
      dialogue.token.hasSuffix(
        ":g03:" + ecmControl.epoch.uuidString + ":" + nativeStationRuntimeEpoch.uuidString),
      event.kind == "dialogue.confirmed", event.instance == state.id,
      event.sequence > 0, event.sequence <= candidate.scriptState.nextEvent,
      !state.hasAcknowledged(event.sequence), event.values["token"]?.string == dialogue.token,
      event.values["dialogue_id"]?.string == dialogue.id,
      let cause = event.context, cause == scriptEventContext(state),
      nativeMainStationDockEvidenceIsCurrent, cause.nativeMainDock != nil,
      cause.nativeMainDock == candidate.nativeStations?.currentMainDock,
      dialogue.galaxy == candidate.galaxy, dialogue.system == candidate.system
    else { throw MissionPackError("Reopen this job's current native station contact.") }
    let now = candidate.scriptState.clock(.missionCalendar)
    guard let due = job.deadline, now <= due else {
      throw MissionPackError("This procurement deadline has passed; no materials transferred.")
    }
    switch kind {
    case .delivery:
      guard dialogue.id == plan.deliveryContact,
        procurementContactIsCurrent(state, commander: candidate)
      else { throw MissionPackError("Deliver at the exact current destination main station.") }
    case .abandon:
      guard dialogue.id == plan.abandonContact, contractStation == job.station else {
        throw MissionPackError("Abandon at the original provider's main station contact.")
      }
    }
    return .init(
      kind: kind, state: state, sequence: event.sequence, game: self, owner: plan.owner,
      clock: now, cause: cause, dialogue: dialogue.id)
  }

  func prepareProcurementDelivery(
    state: ScriptInstance, pack: ScriptPack, event: ScriptEvent, candidate: Commander
  ) throws -> ScriptProcurementAdmission? {
    guard pack.manifest.procurement != nil else { return nil }
    guard let dialogue = state.dialogue else { throw SaveError.invalidCommander }
    return try procurementConfirmation(
      state: state, dialogue: dialogue, pack: pack, event: event, candidate: candidate,
      kind: .delivery)
  }

  func completeProcurementDelivery(
    _ admission: ScriptProcurementAdmission, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    guard let id = pack.manifest.procurement?.collectionTemplate.id,
      state.collections[id]?.complete == true
    else { return }
    state.milestones.insert(0)
    try finishScriptMission(
      .complete, pack: pack, state: &state, candidate: &candidate, procurementAdmission: admission)
  }

  mutating func confirmProcurementAbandon(_ id: UUID, dialogue: ScriptDialogue) throws {
    guard let old = commander.scriptState.instances[id], let pack = scriptPack(for: old),
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw MissionPackError("Restore the exact procurement provider.") }
    var candidate = self
    let sequence = candidate.commander.scriptState.nextEvent + 1
    let event = ScriptEvent(
      sequence: sequence, kind: "dialogue.confirmed", instance: id,
      values: ["token": .string(dialogue.token), "dialogue_id": .string(dialogue.id)],
      context: scriptEventContext(old))
    candidate.commander.scriptState.nextEvent = sequence
    let admission = try procurementConfirmation(
      state: old, dialogue: dialogue, pack: pack, event: event,
      candidate: candidate.commander, kind: .abandon)
    var state = old
    try finishScriptMission(
      .abandoned, pack: pack, state: &state, candidate: &candidate.commander,
      procurementAdmission: admission)
    state.revision += 1
    state.acknowledge(sequence)
    state.completionReceipt = candidate.completionReceipt(state, event: event, pack: pack)
    candidate.commander.scriptState.instances[id] = state
    candidate.commander.scriptState.pendingEvents.removeAll { $0.instance == id }
    if let receipt = state.completionReceipt { try candidate.enqueueScriptCompletion(receipt) }
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    // This method runs only inside the existing key command's private publication barrier.
    self = candidate
  }
}

extension Commander {
  func procurementStateValid(_ state: ScriptInstance) -> Bool {
    guard let job = state.contract, ScriptProcurementPlan.isMarked(job.offer.parameters) else {
      return true
    }
    guard let plan = ScriptProcurementPlan.read(job.offer.parameters),
      ScriptProcurementGeneration.valid(job), plan.owner == equipmentOwnerID,
      state.definition == plan.content.stateID, state.courier == nil,
      Set(state.collections.keys) == [plan.template.id],
      let collection = state.collections[plan.template.id],
      collection.definition == plan.collection,
      scriptState.missionCalendar != nil,
      job.acceptedAt <= scriptState.clock(.missionCalendar),
      job.settledAt.map({ $0 <= scriptState.clock(.missionCalendar) }) ?? true,
      collection.lots.values.allSatisfy({
        $0.dialogue == plan.deliveryContact && $0.cause.nativeMainDock != nil
          && $0.cause.nativeMainDock == $0.committed.nativeMainDock
      })
    else { return false }
    guard state.outcome != .active else { return state.completionReceipt == nil }
    guard let receipt = state.completionReceipt, let cause = receipt.cause,
      receipt.valid(for: state, engine: scriptState), let due = job.deadline,
      let settled = job.settledAt
    else { return false }
    switch state.outcome {
    case .complete:
      guard let lot = collection.lots[receipt.sequence] else { return false }
      return collection.complete && lot.cause == cause && lot.revision == receipt.revision
        && lot.committed == receipt.committed
        && receipt.causeKind == "dialogue.confirmed" && lot.dialogue == plan.deliveryContact
        && cause.nativeMainDock != nil && cause.galaxy == plan.origin.galaxy
        && cause.system == plan.path.last && settled <= due && job.settlementAmount == plan.reward
    case .abandoned:
      return receipt.causeKind == "dialogue.confirmed" && cause.nativeMainDock != nil
        && cause.nativeMainDock == receipt.committed.nativeMainDock
        && cause.galaxy == job.station.galaxy && cause.system == job.station.system
        && job.settlementAmount == 0 && settled <= due
    case .failed:
      return receipt.causeKind == "procurement.terminated" && settled > due
        && job.settlementAmount == 0
    case .active: return false
    }
  }
}
