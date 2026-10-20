import Foundation

// Attempt-local owners keep the original value transaction off the confirmation caller's frame.
// They are synchronous, non-Sendable and never stored in Game or carried into publication.
private final class ScriptFreightConfirmationSelection {
  let old: ScriptInstance
  let pack: ScriptPack
  let plan: ScriptFreightPlan
  let cargo: ScriptOwnedCargoState
  let declared: ScriptDialog
  let cause: ScriptEventContext

  init(
    old: consuming ScriptInstance, pack: consuming ScriptPack, plan: consuming ScriptFreightPlan,
    cargo: consuming ScriptOwnedCargoState, declared: consuming ScriptDialog,
    cause: consuming ScriptEventContext
  ) {
    self.old = consume old
    self.pack = consume pack
    self.plan = consume plan
    self.cargo = consume cargo
    self.declared = consume declared
    self.cause = consume cause
  }
}

private final class ScriptFreightConfirmationAttempt {
  let selected: ScriptFreightConfirmationSelection
  var candidate: Game
  var state: ScriptInstance
  var cargo: ScriptOwnedCargoState

  @inline(never)
  init(_ selected: ScriptFreightConfirmationSelection, original: borrowing Game) {
    self.selected = selected
    candidate = copy original
    state = selected.old
    cargo = selected.cargo
  }
}

extension Game {
  func freightContactIsCurrent(
    _ state: borrowing ScriptInstance, commander candidate: borrowing Commander
  ) -> Bool {
    guard let job = state.contract, let plan = job.offer.freightPlan,
      let cargo = state.savedOwnedCargo, cargo.pendingLoss == nil, cargo.terminal == nil,
      state.outcome == .active, state.suspension == nil, !job.settled, !paused,
      nativeMainStationDockEvidenceIsCurrent,
      OriginalConsentedFreightSupply.receiverMatches(plan, game: self),
      candidate.equipmentOwnerID == plan.owner,
      candidate.galaxy == plan.origin.galaxy, candidate.system == plan.path.last,
      plan.permitsDelivery(
        at: candidate.scriptState.clock(.missionCalendar), deadline: job.deadline)
    else { return false }
    return true
  }

  func freightCollectionQuote(
    _ id: String, state: borrowing ScriptInstance, commander candidate: borrowing Commander
  )
    -> ScriptCollectionQuote?
  {
    guard freightContactIsCurrent(state, commander: candidate), let job = state.contract,
      let plan = job.offer.freightPlan, id == plan.template.id,
      let cargo = state.savedOwnedCargo, let commodity = plan.commodity,
      state.collections[id]?.definition == plan.collection,
      let pack = scriptPack(for: state), plan.matches(pack)
    else { return nil }
    return .init(
      collection: id,
      items: [
        .init(
          commodity: commodity.rawValue, unit: "t", requested: plan.quantity,
          delivered: plan.quantity - cargo.held.count, aboard: cargo.held.count,
          available: cargo.held.count)
      ])
  }

  /// Native UI passes only its declared choice, never an authored numeric quantity.
  mutating func confirmFreightDialogue(_ id: UUID, dialogue: ScriptDialogue, choice: String?) throws
  {
    let selected = try prepareFreightConfirmation(id, dialogue: dialogue)
    let attempt = ScriptFreightConfirmationAttempt(selected, original: self)
    try applyFreightConfirmation(attempt, id: id, dialogue: dialogue, choice: choice)
    try Self.finishFreightConfirmation(attempt, id: id)
    try Self.validateFreightConfirmation(attempt)
    publishFreightConfirmation(attempt)
  }

  // Finish the full current-state and cold validation before allocating a candidate Game.
  @inline(never)
  private mutating func prepareFreightConfirmation(_ id: UUID, dialogue: ScriptDialogue) throws
    -> ScriptFreightConfirmationSelection
  {
    guard let old = commander.scriptState.instances[id], let pack = scriptPack(for: old),
      let job = old.contract, let plan = job.offer.freightPlan, plan.matches(pack),
      let cargo = old.savedOwnedCargo, cargo.pendingLoss == nil, cargo.terminal == nil,
      old.outcome == .active, old.suspension == nil, commander.freightStateValid(old),
      scriptOffer == id, scriptPresentedDialogue == dialogue, old.dialogue == dialogue,
      dialogue.revision == old.revision, !paused, nativeMainStationDockEvidenceIsCurrent,
      dialogue.token.hasSuffix(
        ":freight:" + ecmControl.epoch.uuidString + ":" + nativeStationRuntimeEpoch.uuidString),
      dialogue.galaxy == commander.galaxy, dialogue.system == commander.system,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1, old.revision < UInt64.max,
      plan.permitsDelivery(
        at: commander.scriptState.clock(.missionCalendar), deadline: job.deadline),
      let declared = pack.manifest.dialogs?.first(where: { $0.id == dialogue.id })
    else { throw MissionPackError("Reopen this job's station contact.") }
    let cause = scriptEventContext(old)
    guard cause.nativeMainDock != nil,
      cause.nativeMainDock == commander.nativeStations?.currentMainDock
    else { throw MissionPackError("Freight requires an actual current main-station arrival.") }
    return .init(
      old: old, pack: pack, plan: plan, cargo: cargo, declared: declared, cause: cause)
  }

  @inline(never)
  private mutating func applyFreightConfirmation(
    _ attempt: ScriptFreightConfirmationAttempt, id: UUID, dialogue: ScriptDialogue, choice: String?
  ) throws {
    let plan = attempt.selected.plan
    let pack = attempt.selected.pack
    let declared = attempt.selected.declared
    let cause = attempt.selected.cause
    let sequence = attempt.candidate.commander.scriptState.nextEvent + 1
    attempt.candidate.commander.scriptState.nextEvent = sequence
    if dialogue.id == plan.abandonContact {
      guard choice == nil, contractStation == plan.origin else {
        throw MissionPackError("Abandon only at the original freight issuer.")
      }
      try attempt.candidate.finishFreight(
        .abandoned, state: &attempt.state, sequence: sequence, context: cause,
        candidate: &attempt.candidate.commander)
    } else {
      guard dialogue.id == plan.deliveryContact,
        freightContactIsCurrent(attempt.selected.old, commander: commander),
        let choice, ["freight-one", "freight-all"].contains(choice),
        selectedScriptChoice?.id == choice,
        declared.choices?.contains(where: { $0.id == choice && $0.group == nil }) == true,
        dialogue.collectionQuote
          == freightCollectionQuote(
            plan.template.id, state: attempt.selected.old, commander: commander),
        !attempt.cargo.held.isEmpty, var collection = attempt.state.collections[plan.template.id],
        collection.lots[sequence] == nil
      else { throw MissionPackError("Select a real owned-unit delivery at the destination.") }
      let event = ScriptEvent(
        sequence: sequence, kind: "dialogue.confirmed", instance: id,
        values: [
          "token": .string(dialogue.token), "dialogue_id": .string(dialogue.id),
          "choice_id": .string(choice),
        ], context: cause)
      try attempt.candidate.commitScriptChoice(
        ["choice_id": .string(choice)], event: event,
        dialogue: declared, pack: pack, state: &attempt.state)
      let request: ScriptValue = .object([
        "op": .string("freight.deliver"), "id": .string(plan.template.id),
        "token": .string(dialogue.token), "choice_id": .string(choice),
      ])
      let units = try requestedFreightUnits(
        request, plan: plan, cargo: attempt.cargo, dialogue: dialogue)
      attempt.cargo.held.removeFirst(units.count)
      attempt.cargo.transfers[sequence] = .init(units: units, choice: choice)
      attempt.state.savedOwnedCargo = attempt.cargo
      attempt.state.payloads[ScriptOwnedCargoState.payloadKey] = attempt.cargo.held.count
      var committed = attempt.state
      committed.revision += 1
      collection.lots[sequence] = .init(
        instance: id, sequence: sequence, revision: committed.revision,
        dialogue: dialogue.id,
        items: [.init(commodity: attempt.cargo.commodity, unit: "t", quantity: units.count)],
        cause: cause, committed: attempt.candidate.scriptEventContext(committed))
      attempt.state.collections[plan.template.id] = collection
      if attempt.cargo.held.isEmpty {
        try attempt.candidate.finishFreight(
          .delivered, state: &attempt.state, sequence: sequence, context: cause,
          candidate: &attempt.candidate.commander)
      } else {
        attempt.state.revision += 1
        attempt.state.acknowledge(sequence)
        attempt.state.dialogue = .init(
          collectionQuote: attempt.candidate.freightCollectionQuote(
            plan.template.id,
            state: attempt.state, commander: attempt.candidate.commander), id: plan.deliveryContact,
          token: attempt.candidate.freightDialogueToken(
            id.uuidString + ":" + String(sequence) + ":partial"),
          galaxy: attempt.candidate.commander.galaxy, system: attempt.candidate.commander.system,
          revision: attempt.state.revision)
      }
    }
  }

  @inline(never)
  private static func finishFreightConfirmation(
    _ attempt: ScriptFreightConfirmationAttempt, id: UUID
  ) throws {
    attempt.candidate.commander.scriptState.instances[id] = attempt.state
    try attempt.candidate.awardScriptClue(
      previous: attempt.selected.old, next: attempt.state, trust: .production)
    attempt.candidate.commander.scriptState.pendingEvents.removeAll { $0.instance == id }
    if let receipt = attempt.state.completionReceipt {
      try attempt.candidate.enqueueScriptCompletion(receipt)
    }
  }

  // Delivery's temporary full instance has gone before final Commander validation begins.
  @inline(never)
  private static func validateFreightConfirmation(_ attempt: ScriptFreightConfirmationAttempt)
    throws
  {
    guard attempt.candidate.commander.valid else { throw SaveError.invalidCommander }
  }

  @inline(never)
  private mutating func publishFreightConfirmation(_ attempt: ScriptFreightConfirmationAttempt) {
    // The existing key publication barrier commits dialogue, units, lot and payment together.
    self = attempt.candidate
  }

  /// The authenticated native contact creates this closed request. No numeric amount is accepted.
  private func requestedFreightUnits(
    _ command: ScriptValue, plan: ScriptFreightPlan, cargo: ScriptOwnedCargoState,
    dialogue: ScriptDialogue
  ) throws -> [UUID] {
    guard let fields = command.object,
      Set(fields.keys) == ["op", "id", "token", "choice_id"],
      fields["op"]?.string == "freight.deliver", fields["id"]?.string == plan.template.id,
      fields["token"]?.string == dialogue.token,
      let choice = fields["choice_id"]?.string,
      ["freight-one", "freight-all"].contains(choice), selectedScriptChoice?.id == choice,
      !cargo.held.isEmpty
    else {
      throw MissionPackError("Freight delivery requires a declared current owned-unit choice.")
    }
    return Array(cargo.held.prefix(choice == "freight-one" ? 1 : cargo.held.count))
  }
}
