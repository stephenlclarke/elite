import Foundation

extension Game {
  func freightContactIsCurrent(_ state: ScriptInstance, commander candidate: Commander) -> Bool {
    guard let job = state.contract, let plan = job.offer.freightPlan,
      let cargo = state.savedOwnedCargo, cargo.pendingLoss == nil, cargo.terminal == nil,
      state.outcome == .active, state.suspension == nil, !job.settled, !paused,
      nativeMainStationDockEvidenceIsCurrent, candidate.equipmentOwnerID == plan.owner,
      candidate.galaxy == plan.origin.galaxy, candidate.system == plan.path.last,
      let due = job.deadline, candidate.scriptState.clock(.missionCalendar) <= due
    else { return false }
    return true
  }

  func freightCollectionQuote(_ id: String, state: ScriptInstance, commander candidate: Commander)
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
    guard let old = commander.scriptState.instances[id], let pack = scriptPack(for: old),
      let job = old.contract, let plan = job.offer.freightPlan, plan.matches(pack),
      var cargo = old.savedOwnedCargo, cargo.pendingLoss == nil, cargo.terminal == nil,
      old.outcome == .active, old.suspension == nil, commander.freightStateValid(old),
      scriptOffer == id, scriptPresentedDialogue == dialogue, old.dialogue == dialogue,
      dialogue.revision == old.revision, !paused, nativeMainStationDockEvidenceIsCurrent,
      dialogue.token.hasSuffix(
        ":freight:" + ecmControl.epoch.uuidString + ":" + nativeStationRuntimeEpoch.uuidString),
      dialogue.galaxy == commander.galaxy, dialogue.system == commander.system,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1, old.revision < UInt64.max,
      let due = job.deadline, commander.scriptState.clock(.missionCalendar) <= due,
      let declared = pack.manifest.dialogs?.first(where: { $0.id == dialogue.id })
    else { throw MissionPackError("Reopen this job's station contact.") }
    let cause = scriptEventContext(old)
    guard cause.nativeMainDock != nil,
      cause.nativeMainDock == commander.nativeStations?.currentMainDock
    else { throw MissionPackError("Freight requires an actual current main-station arrival.") }
    var candidate = self
    var state = old
    let sequence = candidate.commander.scriptState.nextEvent + 1
    candidate.commander.scriptState.nextEvent = sequence
    if dialogue.id == plan.abandonContact {
      guard choice == nil, contractStation == plan.origin else {
        throw MissionPackError("Abandon only at the original freight issuer.")
      }
      try candidate.finishFreight(
        .abandoned, state: &state, sequence: sequence, context: cause,
        candidate: &candidate.commander)
    } else {
      guard dialogue.id == plan.deliveryContact, freightContactIsCurrent(old, commander: commander),
        let choice, ["freight-one", "freight-all"].contains(choice),
        selectedScriptChoice?.id == choice,
        declared.choices?.contains(where: { $0.id == choice && $0.group == nil }) == true,
        dialogue.collectionQuote
          == freightCollectionQuote(plan.template.id, state: old, commander: commander),
        !cargo.held.isEmpty, var collection = state.collections[plan.template.id],
        collection.lots[sequence] == nil
      else { throw MissionPackError("Select a real owned-unit delivery at the destination.") }
      let event = ScriptEvent(
        sequence: sequence, kind: "dialogue.confirmed", instance: id,
        values: [
          "token": .string(dialogue.token), "dialogue_id": .string(dialogue.id),
          "choice_id": .string(choice),
        ], context: cause)
      try candidate.commitScriptChoice(
        ["choice_id": .string(choice)], event: event,
        dialogue: declared, pack: pack, state: &state)
      let request: ScriptValue = .object([
        "op": .string("freight.deliver"), "id": .string(plan.template.id),
        "token": .string(dialogue.token), "choice_id": .string(choice),
      ])
      let units = try requestedFreightUnits(request, plan: plan, cargo: cargo, dialogue: dialogue)
      cargo.held.removeFirst(units.count)
      cargo.transfers[sequence] = .init(units: units, choice: choice)
      state.savedOwnedCargo = cargo
      state.payloads[ScriptOwnedCargoState.payloadKey] = cargo.held.count
      var committed = state
      committed.revision += 1
      collection.lots[sequence] = .init(
        instance: id, sequence: sequence, revision: committed.revision,
        dialogue: dialogue.id,
        items: [.init(commodity: cargo.commodity, unit: "t", quantity: units.count)],
        cause: cause, committed: candidate.scriptEventContext(committed))
      state.collections[plan.template.id] = collection
      if cargo.held.isEmpty {
        try candidate.finishFreight(
          .delivered, state: &state, sequence: sequence, context: cause,
          candidate: &candidate.commander)
      } else {
        state.revision += 1
        state.acknowledge(sequence)
        state.dialogue = .init(
          collectionQuote: candidate.freightCollectionQuote(
            plan.template.id,
            state: state, commander: candidate.commander), id: plan.deliveryContact,
          token: candidate.freightDialogueToken(
            id.uuidString + ":" + String(sequence) + ":partial"),
          galaxy: candidate.commander.galaxy, system: candidate.commander.system,
          revision: state.revision)
      }
    }
    candidate.commander.scriptState.instances[id] = state
    candidate.commander.scriptState.pendingEvents.removeAll { $0.instance == id }
    if let receipt = state.completionReceipt { try candidate.enqueueScriptCompletion(receipt) }
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    // The existing key publication barrier commits dialogue, units, lot and payment together.
    self = candidate
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
