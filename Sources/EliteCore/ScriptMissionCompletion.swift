import Foundation

// Completion uses an explicit receipt snapshot, never the whole simulation value.
// Callers retain the original authored or pre-command pledge read view.
enum ScriptMissionCompletion {
  static func finish(
    _ outcome: ScriptOutcome, pack: ScriptPack, receiptView: borrowing ScriptEngineState,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    guard pack.manifest.capabilities.contains("story-v2") else {
      throw MissionPackError("Command requires declared story-v2")
    }
    guard state.outcome == .active else {
      throw MissionPackError("Terminal mission cannot issue more actions.")
    }
    if pack.manifest.pledge != nil, outcome == .complete {
      guard let receipt = candidate.scriptState.pledgeLedger?.receipt(instance: state.id),
        state.pledgeReceiptID == receipt.id
      else {
        throw MissionPackError("A completed donation requires its native pledge receipt.")
      }
    }
    guard outcome != .active,
      outcome != .complete
        || (state.milestones.count == pack.manifest.mission.milestones.count
          && (pack.manifest.mission.requiredDestructionEncounters ?? []).allSatisfy {
            state.ownedEncounters[$0]?.destroyed == true
          }
          && (pack.manifest.mission.requiredPassengerParties ?? []).allSatisfy {
            passengersDelivered($0, pack: pack, instance: state, commander: candidate)
          }
          && (pack.manifest.mission.requiredChoiceGroups ?? []).allSatisfy {
            state.choiceReceipts[$0] != nil
          }
          && (pack.manifest.mission.requiredBooks ?? []).allSatisfy {
            let book = candidate.scriptState.books[pack.manifest.id + "/" + $0]
            return book?.version == pack.manifest.version && book?.digest == pack.digest
          }
          && (pack.manifest.mission.requiredCollections ?? []).allSatisfy { id in
            state.collections[id]?.complete == true
              && state.collections[id]?.definition
                == pack.manifest.collections?.first(where: { $0.id == id })
          }
          && scriptAnswersSatisfied(pack, state: state)
          && state.gearIssues.values.allSatisfy { !$0.loan || $0.status != .issued }
          && (pack.manifest.mission.requiredEquipmentReturns ?? []).allSatisfy {
            state.gearIssues[$0]?.status == .returned
          })
    else {
      throw MissionPackError("Complete every required objective before reporting.")
    }
    if outcome == .complete, let job = state.contract, let due = job.deadline,
      candidate.scriptState.clock(job.clock) >= due
    {
      throw MissionPackError(
        "This contract's deadline has passed; use its declared failure handoff.")
    }
    if outcome == .complete {
      state.receiptJoins = try scriptReceiptJoins(
        pack, stage: .acceptance, existing: state.receiptJoins ?? [:], parent: state,
        receiptView: receiptView)
      state.receiptJoins = try scriptReceiptJoins(
        pack, stage: .completion, existing: state.receiptJoins ?? [:], parent: state,
        receiptView: receiptView)
    }
    try settleContract(outcome, state: &state, candidate: &candidate)
    state.outcome = outcome
    state.dialogue = nil
    state.timers = [:]
  }
  static func passengersDelivered(
    _ partyID: String, pack: ScriptPack, instance: ScriptInstance, commander: Commander
  ) -> Bool {
    guard let party = pack.manifest.passengerParties?.first(where: { $0.id == partyID }) else {
      return false
    }
    return party.names.indices.allSatisfy { index in
      let id = ShipAccommodation.personID(mission: instance.id, party: partyID, index: index)
      guard let person = commander.accommodation.people[id], person.id == id,
        person.mission == instance.id, person.party == partyID
      else { return false }
      return person.location
        == .delivered(galaxy: party.destinationGalaxy, system: party.destinationSystem)
    }
  }
  static func scriptAnswersSatisfied(_ pack: ScriptPack, state: ScriptInstance) -> Bool {
    (pack.manifest.answerRequirements ?? []).allSatisfy { requirement in
      state.conversationReceipts.values.filter {
        $0.dialogue == requirement.dialogue && $0.choice == requirement.choice
      }.count >= requirement.minimumCount
    }
  }
  static func settleContract(
    _ outcome: ScriptOutcome, state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    guard var job = state.contract else { return }
    guard !job.settled else { throw MissionPackError("This contract is already settled.") }
    let reward =
      outcome == .complete ? job.offer.reward : (outcome == .failed ? job.offer.failureReward : 0)
    let refund =
      outcome == .complete || (outcome == .failed && job.offer.refundOnFailure)
      ? job.offer.deposit : 0
    let amount = reward + refund
    guard candidate.credits <= 4_294_967_295 - amount else {
      throw MissionPackError("Spend credits before collecting this contract payment.")
    }
    candidate.credits += amount
    job.settled = true
    job.settlementOutcome = outcome
    job.settlementAmount = amount
    job.settledAt = candidate.scriptState.clock(job.clock)
    state.contract = job
  }
  static func matchingScriptReceipts(
    _ requirement: ScriptReceiptRequirement, parent: ScriptInstance? = nil,
    receiptView: borrowing ScriptEngineState
  ) -> [UUID] {
    let childID = requirement.child.flatMap { parent?.campaignChildren[$0]?.child }
    return receiptView.instances.values.filter {
      requirement.child == nil || $0.id == childID
    }.compactMap { state in
      state.completionReceipt.flatMap {
        $0.valid(for: state, engine: receiptView) ? $0 : nil
      }
    }
    .filter { requirement.matches($0) }
    .sorted { ($0.sequence, $0.instance.uuidString) < ($1.sequence, $1.instance.uuidString) }
    .map(\.instance)
  }
  static func scriptReceiptJoins(
    _ pack: ScriptPack, stage: ScriptReceiptStage, existing: [String: [UUID]],
    parent: ScriptInstance? = nil, receiptView: borrowing ScriptEngineState
  ) throws -> [String: [UUID]] {
    var joins = existing
    for requirement in pack.manifest.receiptRequirements ?? [] where requirement.stage == stage {
      let matches = matchingScriptReceipts(requirement, parent: parent, receiptView: receiptView)
      if let pinned = joins[requirement.id] {
        guard pinned.count == requirement.minimumCount, pinned.allSatisfy(matches.contains) else {
          throw MissionPackError("The pinned child mission receipts are unavailable.")
        }
      } else {
        guard matches.count >= requirement.minimumCount else {
          throw MissionPackError("Missing verified child mission receipts: " + requirement.id)
        }
        joins[requirement.id] = Array(matches.prefix(requirement.minimumCount))
      }
    }
    return joins
  }
}
