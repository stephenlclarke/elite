import Foundation

extension NativeInductionWorkshopSave {
  static func commitEnd(
    _ end: NativeInductionWorkshopEnd, child: inout ScriptInstance,
    commander: inout Commander, committedContext: ScriptEventContext
  ) throws {
    guard let contract = child.savedNativeInductionWorkshop, contract.end == nil,
      var parent = commander.scriptState.instances[contract.booking.parent],
      let state = parent.savedWayfarerInduction, let source = state.charterWorkshopSource,
      let capacity = state.charterCapacity,
      parent.revision < UInt64(Int64.max) - 1, child.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      end.facts.sequence == commander.scriptState.nextEvent + 1
    else { throw SaveError.invalidCommander }
    let closed = NativeInductionWorkshopContract(
      booking: contract.booking, pickup: contract.pickup,
      service: contract.service, cancellation: contract.cancellation, end: end)
    let next = try state.updatingWorkshop(
      source.applying(stockEvent(end, contract: contract)),
      capacity: capacity.returning(end.facts.window))
    guard closed.valid(parent: next) else { throw SaveError.invalidCommander }
    if let before = end.facts.creditsBefore, commander.credits != before {
      throw SaveError.invalidCommander
    }
    parent.savedWayfarerInduction = next
    parent.revision += 1
    parent.acknowledge(end.facts.sequence)
    child.savedNativeInductionWorkshop = closed
    child.payloads = [:]
    child.outcome = closed.outcome
    child.milestones = end.facts.kind == .returned ? [0] : []
    child.dialogue = nil
    child.revision += 1
    child.acknowledge(end.facts.sequence)
    if let after = end.facts.creditsAfter { commander.credits = after }
    commander.scriptState.nextEvent = end.facts.sequence
    let kind =
      end.facts.kind == .carrierExit
      ? end.facts.loss?.cause.completionKind ?? "actor.destroyed"
      : end.facts.kind == .sourceLost ? "actor.destroyed" : "dialogue.confirmed"
    child.completionReceipt = .init(
      instance: child.id, definition: child.definition,
      version: child.version, digest: child.digest, outcome: child.outcome,
      sequence: end.facts.sequence, causeKind: kind, cause: end.facts.context,
      committed: committedContext, revision: child.revision, milestones: child.milestones.sorted(),
      destroyedEncounters: [], deliveredParties: [], returnedEquipment: [], settlementAmount: nil,
      choices: nil)
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    commander.scriptState.pendingEvents.removeAll { $0.instance == child.id }
  }
}

extension Game {
  mutating func finishInductionWorkshop(
    _ id: UUID, kind requested: NativeInductionWorkshopEndFacts.Kind,
    cause: WayfarerColdChainLossCause? = nil
  ) throws {
    var child = try inductionWorkshopChild(id, forLoss: cause != nil || requested == .sourceLost)
    guard let contract = child.savedNativeInductionWorkshop,
      let state = commander.scriptState.instances[contract.booking.parent]?.savedWayfarerInduction,
      let source = state.charterWorkshopSource, let capacity = state.charterCapacity,
      let fit = commander.equipmentInventory?.revision,
      child.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sourceResource = commander.scriptState.stationResources[
      source.issue.profile.source.resourceKey]
    let sourceGone = contract.pickup == nil && sourceResource?.destroyed == true
    let kind: NativeInductionWorkshopEndFacts.Kind = sourceGone ? .sourceLost : requested
    let sequence = commander.scriptState.nextEvent + 1
    let context = scriptEventContext(child)
    let contact: WayfarerColdChainContact?
    let loss: WayfarerColdChainPhysicalLoss?
    if kind == .carrierExit {
      guard let cause, !docked, energy.isFinite,
        cause == .shipDestroyed ? screen == .gameOver && energy <= 0 : screen.isFlight && energy > 0
      else { throw MissionPackError("Actual attained native carrier exit is required.") }
      loss = .init(
        cause: cause, sequence: sequence, context: context, energy: max(0, energy),
        visit: commander.flightSimulation.visit)
      contact = nil
    } else if kind == .sourceLost {
      guard sourceGone else {
        throw MissionPackError("Known destruction of the original uncollected source is required.")
      }
      loss = nil
      contact = nil
    } else {
      let dock = try inductionClinicCurrentDock(
        kind == .cancelledBeforePickup ? nil : source.issue.profile.receiver)
      contact = .init(sequence: sequence, dock: dock, context: context)
      loss = nil
    }
    let before: Int?
    let after: Int?
    if kind == .returned {
      guard (0...4_294_967_295).contains(commander.credits),
        commander.credits <= 4_294_967_295 - contract.booking.rewardNative
      else { throw MissionPackError("Original workshop return would overflow credits.") }
      before = commander.credits
      after = commander.credits + contract.booking.rewardNative
    } else {
      before = nil
      after = nil
    }
    let window = try capacity.returnQuote(
      reservation: contract.booking.window.operation,
      reason: kind == .returned ? .completed : .cancelled)
    let facts = NativeInductionWorkshopEndFacts(
      booking: contract.booking.operation, kind: kind,
      sequence: sequence, stockRevision: source.revision, window: window,
      carrier: contract.booking.carrier, inventoryRevision: fit,
      physicalTime: commander.flightSimulation.physicalTime, context: context,
      contact: contact, loss: loss, sourceLoss: kind == .sourceLost ? sourceResource : nil,
      creditsBefore: before, creditsAfter: after)
    let end = NativeInductionWorkshopEnd(
      operation: try NativeInductionWorkshopEnd.identity(facts), facts: facts)
    let committed = Self.scriptEventContext(in: self, revision: child.revision + 1)
    try NativeInductionWorkshopSave.commitEnd(
      end, child: &child, commander: &commander, committedContext: committed)
    if let receipt = child.completionReceipt { try enqueueScriptCompletion(receipt) }
    guard NativeInductionCrewLogSave.validateClaims(commander) else {
      throw SaveError.invalidCommander
    }
    notify(
      kind == .returned
        ? "ORIGINAL SERVICED SERIAL RECEIVED - FROZEN WORKSHOP QUOTE PAID"
        : "ORIGINAL WORKSHOP OBLIGATION CLOSED - NO PAYMENT OR FRESH STOCK")
  }
}
