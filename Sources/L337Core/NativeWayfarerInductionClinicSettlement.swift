import Foundation

extension NativeInductionClinicSave {
  static func commitEnd(
    _ end: NativeInductionClinicCustodyEnd, custody: NativeInductionClinicCustody,
    child: inout ScriptInstance, commander: inout Commander,
    committedContext: ScriptEventContext? = nil
  ) throws {
    guard let contract = child.savedNativeInductionClinic,
      let prior = contract.custody, prior.end == nil, contract.close == nil,
      prior.pickup == custody.pickup, prior.timer == custody.timer,
      prior.cancellation == custody.cancellation,
      var parent = commander.scriptState.instances[contract.booking.parent],
      let state = parent.savedWayfarerInduction, let source = state.charterClinicSource,
      let capacity = state.charterCapacity,
      parent.revision < UInt64(Int64.max) - 1, child.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      end.sequence <= commander.scriptState.nextEvent + 1
    else { throw SaveError.invalidCommander }
    let snapshot = WayfarerColdChainSnapshot(
      binding: prior.integrity.binding,
      timer: prior.timer, context: end.context)
    let expected: WayfarerColdChain
    switch end.kind {
    case .received:
      guard let payment = end.payment else { throw SaveError.invalidCommander }
      expected = try prior.integrity.receiving(snapshot, receipt: payment)
    case .spoiled:
      guard let event = end.expiry else { throw SaveError.invalidCommander }
      expected = try prior.integrity.spoiling(binding: prior.integrity.binding, event: event)
    case .returned, .carrierExit: expected = try prior.integrity.observing(snapshot)
    }
    guard expected == custody.integrity else { throw SaveError.invalidCommander }
    let next = try state.updatingClinic(
      source.applying(stockEvent(end, booking: contract.booking)),
      capacity: capacity.returning(end.window))
    guard custody.end == end, custody.valid(booking: contract.booking, parent: next) else {
      throw SaveError.invalidCommander
    }
    if let before = end.creditsBefore, commander.credits != before {
      throw SaveError.invalidCommander
    }
    parent.savedWayfarerInduction = next
    parent.revision += 1
    parent.acknowledge(end.sequence)
    child.savedNativeInductionClinic = .init(booking: contract.booking, custody: custody)
    child.payloads.removeValue(forKey: NativeInductionClinicCustody.payload)
    child.timers.removeValue(forKey: custody.timer.id)
    child.outcome = custody.outcome
    child.milestones = end.kind == .received ? [0] : []
    child.dialogue = nil
    if end.creditsBefore != nil, let after = end.creditsAfter {
      commander.credits = after
    }
    commander.scriptState.nextEvent = max(commander.scriptState.nextEvent, end.sequence)
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.pendingEvents.removeAll { $0.instance == child.id }
    child.acknowledge(end.sequence)
    if let committedContext {
      child.revision += 1
      child.acknowledge(end.sequence)
      let cause =
        end.kind == .carrierExit
        ? end.loss?.cause.completionKind ?? "actor.destroyed" : "dialogue.confirmed"
      child.completionReceipt = .init(
        instance: child.id, definition: child.definition,
        version: child.version, digest: child.digest, outcome: child.outcome,
        sequence: end.sequence, causeKind: cause, cause: end.context, committed: committedContext,
        revision: child.revision, milestones: child.milestones.sorted(), destroyedEncounters: [],
        deliveredParties: [], returnedEquipment: [], settlementAmount: nil, choices: nil)
      commander.scriptState.instances[child.id] = child
    }
  }
}

extension Game {
  mutating func finishInductionClinicCustody(
    _ id: UUID, returning: Bool = false,
    lossCause: WayfarerColdChainLossCause? = nil
  ) throws {
    var child = try inductionClinicHeldChild(id, requiresTime: lossCause == nil)
    guard let contract = child.savedNativeInductionClinic, var custody = contract.custody,
      let parent = commander.scriptState.instances[contract.booking.parent]?.savedWayfarerInduction,
      let source = parent.charterClinicSource, let capacity = parent.charterCapacity,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      child.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let context = scriptEventContext(child)
    let time = commander.flightSimulation.physicalTime
    let kind: NativeInductionClinicCustodyEnd.Kind =
      lossCause != nil ? .carrierExit : returning ? .returned : .received
    let contact: WayfarerColdChainContact?
    let loss: WayfarerColdChainPhysicalLoss?
    let payment: ScriptCourierTerminalReceipt?
    let before: Int?
    let after: Int?
    if let lossCause {
      guard !docked, energy.isFinite,
        lossCause == .shipDestroyed
          ? screen == .gameOver && energy <= 0 : screen.isFlight && energy > 0
      else { throw MissionPackError("Actual attained native carrier loss is required.") }
      contact = nil
      loss = .init(
        cause: lossCause, sequence: sequence, context: context, energy: max(0, energy),
        visit: commander.flightSimulation.visit)
      payment = nil
      before = nil
      after = nil
      custody = .init(
        pickup: custody.pickup, timer: custody.timer,
        integrity: try custody.integrity.observing(
          .init(binding: custody.integrity.binding, timer: custody.timer, context: context)),
        cancellation: custody.cancellation)
    } else {
      guard returning ? custody.cancellation != nil : custody.cancellation == nil else {
        throw SaveError.invalidCommander
      }
      let dock = try inductionClinicCurrentDock(
        returning ? contract.booking.terms.source : contract.booking.terms.receiver)
      contact = .init(sequence: sequence, dock: dock, context: context)
      loss = nil
      if returning {
        guard dock.station == contract.booking.dock.station else {
          throw SaveError.invalidCommander
        }
        before = nil
        after = nil
        payment = nil
        custody = .init(
          pickup: custody.pickup, timer: custody.timer,
          integrity: try custody.integrity.observing(
            .init(binding: custody.integrity.binding, timer: custody.timer, context: context)),
          cancellation: custody.cancellation)
      } else {
        guard (0...4_294_967_295).contains(commander.credits),
          commander.credits <= 4_294_967_295 - contract.booking.terms.rewardNative
        else { throw MissionPackError("Receiving must not overflow credits.") }
        before = commander.credits
        after = commander.credits + contract.booking.terms.rewardNative
        let receipt = ScriptCourierTerminalReceipt(
          id: ScriptCourierCustody.terminalIdentity(contract.booking.unit),
          item: contract.booking.unit, cause: .delivered,
          proof: .init(
            sequence: sequence, token: "induction-original-clinic-reception",
            revision: child.revision,
            epoch: ecmControl.epoch, clock: context.calendarSeconds, station: contractStation),
          amount: contract.booking.terms.rewardNative)
        payment = receipt
        custody = .init(
          pickup: custody.pickup, timer: custody.timer,
          integrity: try custody.integrity.receiving(
            .init(binding: custody.integrity.binding, timer: custody.timer, context: context),
            receipt: receipt))
      }
    }
    let window = try capacity.returnQuote(
      reservation: contract.booking.window.operation,
      reason: kind == .received ? .completed : .cancelled)
    let operation = try NativeInductionClinicCustodyEnd.identity(
      booking: contract.booking.operation,
      pickup: custody.pickup.operation, kind: kind, sequence: sequence,
      stockRevision: source.revision,
      window: window, time: time, context: context, closedFlightSeconds: context.flightSeconds,
      contact: contact, loss: loss, expiry: nil,
      payment: payment, before: before, after: after)
    let end = NativeInductionClinicCustodyEnd(
      operation: operation, booking: contract.booking.operation,
      pickup: custody.pickup.operation, kind: kind, sequence: sequence,
      stockRevision: source.revision,
      window: window, physicalTime: time, context: context,
      closedFlightSeconds: context.flightSeconds, contact: contact, loss: loss, expiry: nil,
      payment: payment, creditsBefore: before, creditsAfter: after)
    custody.end = end
    let committed = Self.scriptEventContext(in: self, revision: child.revision + 1)
    try NativeInductionClinicSave.commitEnd(
      end, custody: custody, child: &child,
      commander: &commander, committedContext: committed)
    if let receipt = child.completionReceipt { try enqueueScriptCompletion(receipt) }
    guard NativeInductionCrewLogSave.validateClaims(commander) else {
      throw SaveError.invalidCommander
    }
    notify(
      returning
        ? "ORIGINAL CLINIC SAMPLE RETURNED - NO PAYMENT"
        : lossCause != nil
          ? "ORIGINAL CLINIC SAMPLE LOST - NO REPLACEMENT"
          : "ORIGINAL CLINIC SAMPLE RECEIVED - FROZEN QUOTE PAID")
  }
}
