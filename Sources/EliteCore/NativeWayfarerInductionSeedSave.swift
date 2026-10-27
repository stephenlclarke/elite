import Foundation

enum NativeInductionSeedSave {
  static func shapeValid(_ child: borrowing ScriptInstance) -> Bool {
    guard let state = child.savedNativeInductionSeed else { return false }
    guard child.definition == NativeInductionSeedPack.stateID,
      child.version == NativeInductionSeedPack.version,
      child.digest == NativeInductionSeedPack.digest,
      child.id == state.booking.instance, child.outcome == state.outcome,
      child.contract == nil, child.dialogue == nil, child.gearIssues.isEmpty,
      child.ownedEncounters.isEmpty, child.data == .object([:]),
      child.campaignParent == nil, child.campaignChildren.isEmpty
    else { return false }
    guard let custody = state.custody else {
      return child.completionReceipt == nil && child.payloads.isEmpty && child.milestones.isEmpty
        && child.timers.isEmpty
    }
    let active = custody.end == nil
    return child.payloads == (active ? [NativeInductionSeedCustody.payload: 3] : [:])
      && child.milestones == (custody.end?.kind == .received ? [0] : [])
      && (active ? child.completionReceipt == nil : true)
      && (active
        ? child.timers.isEmpty || child.timers == [custody.timer.id: custody.timer]
        : child.timers.isEmpty)
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    for child in engine.instances.values
    where NativeInductionSeedPack.marked(child)
      || child.savedNativeInductionSeed != nil
    {
      guard shapeValid(child), let contract = child.savedNativeInductionSeed,
        let parent = engine.instances[contract.booking.parent],
        let state = parent.savedWayfarerInduction,
        parent.definition == NativeWayfarerInduction.stateID,
        parent.digest == NativeWayfarerInduction.digest,
        contract.valid(parent: state), let source = state.charterSeedSource,
        let capacity = state.charterCapacity,
        source.history?.contains(stockEvent(contract.booking)) == true,
        capacity.events.contains(.reserved(contract.booking.window)),
        historicalDockValid(contract.booking.dock, commander: commander),
        historicalEventValid(
          contract.booking.sequence, time: contract.booking.physicalTime,
          clock: contract.booking.flightSeconds, parent: parent, child: child, commander: commander)
      else { return false }
      if contract.outcome == .active {
        guard let occupied = commander.checkedCargoTonnes,
          occupied <= commander.standardCargoCapacity,
          commander.passengerFit?.allowed == true
        else { return false }
      }
      if let custody = contract.custody {
        guard
          custodyClaimsValid(
            custody, contract: contract, parent: parent, child: child, commander: commander)
        else { return false }
      }
      if let close = contract.close {
        guard source.history?.contains(stockEvent(close, booking: contract.booking)) == true,
          capacity.events.contains(.returned(close.window)),
          close.player.visit <= commander.flightSimulation.visit,
          historicalEventValid(
            close.sequence, time: close.physicalTime, clock: close.flightSeconds,
            parent: parent, child: child, commander: commander)
        else { return false }
        if let dock = close.dock, !historicalDockValid(dock, commander: commander) { return false }
        if let loss = close.sourceLoss,
          engine.stationResources[loss.key] != loss
        {
          return false
        }
      } else if contract.outcome == .active {
        guard commander.hullInstanceID == contract.booking.carrier,
          (commander.equipmentInventory?.revision ?? 0) >= contract.booking.inventoryRevision
        else { return false }
      }
    }
    for parent in engine.instances.values {
      guard let state = parent.savedWayfarerInduction, let source = state.charterSeedSource else {
        continue
      }
      let issue = source.issue
      guard source.valid(parent: state), issue.parent == parent.id,
        issue.commanderOwner == commander.equipmentOwnerID,
        issue.sequence <= engine.nextEvent, parent.hasAcknowledged(issue.sequence),
        issue.physicalTime <= commander.flightSimulation.physicalTime,
        issue.flightSeconds <= engine.flightSeconds,
        historicalDockValid(issue.dock, commander: commander),
        commander.nativeStations?.mainStations.contains(source.delegation.auditor) == true
      else { return false }
      for event in source.history ?? [] {
        guard let child = engine.instances[event.instance],
          let contract = child.savedNativeInductionSeed,
          contract.booking.parent == parent.id
        else { return false }
        if event.kind == .reserved {
          guard event == stockEvent(contract.booking) else { return false }
        } else if let close = contract.close {
          guard event == stockEvent(close, booking: contract.booking) else { return false }
        } else {
          guard let end = contract.custody?.end,
            event == stockEvent(end, booking: contract.booking)
          else { return false }
        }
      }
    }
    return true
  }
  static func stockEvent(_ booking: NativeInductionSeedBooking)
    -> NativeInductionSeedStockMutation
  {
    .init(
      kind: .reserved, operation: booking.operation, instance: booking.instance, unit: booking.unit,
      window: booking.window.operation, revision: booking.stockRevision, sequence: booking.sequence,
      physicalTime: booking.physicalTime, flightSeconds: booking.flightSeconds)
  }
  static func stockEvent(
    _ close: NativeInductionSeedUncollectedClose,
    booking: NativeInductionSeedBooking
  ) -> NativeInductionSeedStockMutation {
    .init(
      kind: close.kind == .sourceLost ? .failedBeforePickup : .cancelled,
      operation: close.operation, instance: close.instance, unit: booking.unit,
      window: close.window.operation, revision: close.stockRevision, sequence: close.sequence,
      physicalTime: close.physicalTime, flightSeconds: close.flightSeconds)
  }
  static func historicalDockValid(
    _ dock: NativeMainStationDockReceipt,
    commander: borrowing Commander
  ) -> Bool {
    NativeInductionClinicSave.historicalDockValid(dock, commander: commander)
  }

  static func historicalEventValid(
    _ sequence: UInt64, time: Double, clock: Double,
    parent: ScriptInstance, child: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    NativeInductionClinicSave.historicalEventValid(
      sequence, time: time, clock: clock,
      parent: parent, child: child, commander: commander)
  }
}

extension NativeInductionSeedSave {
  static func stockEvent(
    _ end: NativeInductionSeedCustodyEnd, booking: NativeInductionSeedBooking
  ) -> NativeInductionSeedStockMutation {
    let kind: NativeInductionSeedStockMutation.Kind
    switch end.kind {
    case .received: kind = .received
    case .returned: kind = .returnedToOwner
    case .spoiled: kind = .spoiled
    case .carrierExit: kind = .carrierLost
    }
    return .init(
      kind: kind, operation: end.operation, instance: booking.instance, unit: booking.unit,
      window: end.window.operation, revision: end.stockRevision, sequence: end.sequence,
      physicalTime: end.physicalTime, flightSeconds: end.closedFlightSeconds)
  }
  static func custodyClaimsValid(
    _ custody: NativeInductionSeedCustody,
    contract: NativeInductionSeedContract, parent: ScriptInstance, child: ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard historicalDockValid(custody.pickup.contact.dock, commander: commander),
      commander.freightHistoricalContextValid(custody.pickup.contact.context, requiresDock: true),
      historicalEventValid(
        custody.pickup.contact.sequence, time: custody.pickup.physicalTime,
        clock: custody.pickup.contact.context.flightSeconds, parent: parent, child: child,
        commander: commander)
    else { return false }
    if let cancel = custody.cancellation {
      guard historicalDockValid(cancel.contact.dock, commander: commander),
        commander.freightHistoricalContextValid(cancel.contact.context, requiresDock: true),
        historicalEventValid(
          cancel.contact.sequence, time: cancel.physicalTime,
          clock: cancel.contact.context.flightSeconds, parent: parent, child: child,
          commander: commander)
      else { return false }
    }
    if let end = custody.end {
      guard let source = parent.savedWayfarerInduction?.charterSeedSource,
        source.history?.contains(stockEvent(end, booking: contract.booking)) == true,
        parent.savedWayfarerInduction?.charterCapacity?.events.contains(.returned(end.window))
          == true,
        commander.freightHistoricalContextValid(end.context, requiresDock: end.context.docked),
        historicalEventValid(
          end.sequence, time: end.physicalTime, clock: end.closedFlightSeconds,
          parent: parent, child: child, commander: commander),
        let receipt = child.completionReceipt,
        receipt.sequence == (end.expiry?.sequence ?? end.sequence),
        receipt.cause == end.context, receipt.outcome == custody.outcome,
        receipt.valid(for: child, engine: commander.scriptState)
      else { return false }
      if let contact = end.contact, !historicalDockValid(contact.dock, commander: commander) {
        return false
      }
      if let loss = end.loss, loss.visit > commander.flightSimulation.visit { return false }
      return true
    }
    guard contract.booking.carrier == commander.hullInstanceID,
      (commander.equipmentInventory?.revision ?? 0) >= custody.pickup.inventoryRevision
    else { return false }
    if child.timers == [custody.timer.id: custody.timer] {
      return !commander.scriptState.pendingEvents.contains {
        $0.instance == child.id && $0.kind == "timer.fired"
      }
    }
    return pendingExpiry(child, engine: commander.scriptState) != nil
  }
  static func pendingExpiry(_ child: ScriptInstance, engine: ScriptEngineState) -> ScriptEvent? {
    guard let custody = child.savedNativeInductionSeed?.custody, custody.end == nil,
      child.outcome == .active, child.timers.isEmpty, child.completionReceipt == nil
    else { return nil }
    let events = engine.pendingEvents.filter { $0.instance == child.id && $0.kind == "timer.fired" }
    guard events.count == 1, let event = events.first,
      event.sequence > custody.pickup.contact.sequence, event.sequence <= engine.nextEvent,
      !child.hasAcknowledged(event.sequence), let context = event.context,
      context.valid, context.revision == child.revision,
      context.flightSeconds <= engine.flightSeconds, context.localSeconds <= engine.localSeconds,
      context.calendarSeconds <= engine.calendarSeconds,
      context.transitSeconds <= engine.transitSeconds,
      Set(event.values.keys) == [
        "timer_id", "pulse", "due", "fired_at", "has_been_run", "clock_exhausted", "counters",
        "reset_counters",
      ],
      event.values["clock_exhausted"] == .bool(false), event.values["counters"] == .object([:]),
      event.values["reset_counters"] == .array([]),
      (try? custody.integrity.spoiling(binding: custody.integrity.binding, event: event)) != nil
    else { return nil }
    return event
  }
}
