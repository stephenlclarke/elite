import Foundation

extension Game {
  func applyInductionSeedExpiry(
    event: ScriptEvent, state: inout ScriptInstance,
    candidate: inout Commander
  ) throws {
    guard NativeInductionSeedPack.marked(state), state.outcome == .active,
      let contract = state.savedNativeInductionSeed, var custody = contract.custody,
      custody.end == nil, contract.close == nil,
      NativeInductionSeedSave.pendingExpiry(state, engine: candidate.scriptState) == event,
      let context = event.context,
      candidate.freightHistoricalContextValid(context, requiresDock: context.docked),
      let parent = candidate.scriptState.instances[contract.booking.parent]?.savedWayfarerInduction,
      let source = parent.charterSeedSource, let capacity = parent.charterCapacity,
      candidate.scriptState.nextEvent < UInt64(Int64.max) - 1
    else {
      throw MissionPackError(
        "Expiry requires this original seed lot's actual queued one-shot timer event.")
    }
    let integrity = try custody.integrity.spoiling(binding: custody.integrity.binding, event: event)
    custody = .init(
      pickup: custody.pickup, timer: custody.timer, integrity: integrity,
      cancellation: custody.cancellation)
    // The original timer event remains the quality proof. A later retry returns the current
    // window with a fresh publication sequence/clock, after any unrelated ledger activity.
    let sequence = candidate.scriptState.nextEvent + 1
    let time = candidate.flightSimulation.physicalTime
    let clock = candidate.scriptState.flightSeconds
    let window = try capacity.returnQuote(
      reservation: contract.booking.window.operation, reason: .cancelled)
    let operation = try NativeInductionSeedCustodyEnd.identity(
      booking: contract.booking.operation,
      pickup: custody.pickup.operation, kind: .spoiled, sequence: sequence,
      stockRevision: source.revision, window: window, time: time, context: context,
      closedFlightSeconds: clock, contact: nil, loss: nil, expiry: event, payment: nil,
      before: nil, after: nil)
    let end = NativeInductionSeedCustodyEnd(
      operation: operation, booking: contract.booking.operation,
      pickup: custody.pickup.operation, kind: .spoiled, sequence: sequence,
      stockRevision: source.revision, window: window, physicalTime: time, context: context,
      closedFlightSeconds: clock, contact: nil, loss: nil, expiry: event, payment: nil,
      creditsBefore: nil, creditsAfter: nil)
    custody.end = end
    try NativeInductionSeedSave.commitEnd(
      end, custody: custody, child: &state, commander: &candidate)
    state.journal.append(
      "The original seed lot spoiled at its native flight deadline. Recorded terminal failure releases its original window and cargo reservation; no restock, payment or success."
    )
  }
  mutating func retryInductionSeedExpiry(_ id: UUID) throws {
    guard let child = commander.scriptState.instances[id], child.suspension != nil,
      let event = NativeInductionSeedSave.pendingExpiry(child, engine: commander.scriptState),
      nativeInductionSeedPack != nil, !scriptDispatching, !scriptEventsDeferred
    else {
      throw MissionPackError("Restore the exact seed content for its original pending expiry.")
    }
    commander.scriptState.instances[id]?.suspension = nil
    drainScriptEvents()
    guard let next = commander.scriptState.instances[id], next.outcome == .failed,
      next.savedNativeInductionSeed?.custody?.end?.expiry == event,
      next.completionReceipt?.sequence == event.sequence,
      NativeInductionCrewLogSave.validateClaims(commander)
    else { throw MissionPackError("The original seed lot expiry could not be committed.") }
  }
}

extension Game {
  var heldInductionSeedJobs: [UUID] {
    commander.scriptState.instances.values.filter {
      $0.savedNativeInductionSeed?.custody != nil
        && $0.savedNativeInductionSeed?.custody?.end == nil && $0.outcome == .active
    }.map(\.id).sorted { $0.uuidString < $1.uuidString }
  }
  mutating func loseHeldInductionSeedOnExit(_ cause: WayfarerColdChainLossCause) throws {
    for id in heldInductionSeedJobs {
      try finishInductionSeedCustody(id, lossCause: cause)
    }
  }
}
extension GameRuntime {
  func commitInductionSeedHeldFatalLoss() {
    guard game.screen == .gameOver, !game.docked, game.energy.isFinite, game.energy <= 0,
      !game.heldInductionSeedJobs.isEmpty
    else { return }
    do { try scriptCommand { try $0.loseHeldInductionSeedOnExit(.shipDestroyed) } } catch {
      game.notify("ORIGINAL SEED SAMPLE LOSS NOT SAVED - NATIVE LOSS RETAINED FOR RETRY")
    }
  }
}
