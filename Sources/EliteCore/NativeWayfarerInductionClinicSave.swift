import Foundation

enum NativeInductionClinicSave {
  static func shapeValid(_ child: borrowing ScriptInstance) -> Bool {
    guard let state = child.savedNativeInductionClinic else { return false }
    return child.definition == NativeInductionClinicPack.stateID
      && child.version == NativeInductionClinicPack.version
      && child.digest == NativeInductionClinicPack.digest
      && child.id == state.booking.instance && child.outcome == state.outcome
      && child.contract == nil && child.completionReceipt == nil && child.dialogue == nil
      && child.payloads.isEmpty && child.gearIssues.isEmpty && child.milestones.isEmpty
      && child.timers.isEmpty && child.ownedEncounters.isEmpty && child.data == .object([:])
      && child.campaignParent == nil && child.campaignChildren.isEmpty
  }
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    for child in engine.instances.values
    where NativeInductionClinicPack.marked(child)
      || child.savedNativeInductionClinic != nil
    {
      guard shapeValid(child), let contract = child.savedNativeInductionClinic,
        let parent = engine.instances[contract.booking.parent],
        let state = parent.savedWayfarerInduction,
        parent.definition == NativeWayfarerInduction.stateID,
        parent.digest == NativeWayfarerInduction.digest,
        contract.valid(parent: state), let source = state.charterClinicSource,
        let capacity = state.charterCapacity,
        source.history?.contains(stockEvent(contract.booking)) == true,
        capacity.events.contains(.reserved(contract.booking.window)),
        historicalDockValid(contract.booking.dock, commander: commander),
        historicalEventValid(
          contract.booking.sequence, time: contract.booking.physicalTime,
          clock: contract.booking.flightSeconds, parent: parent, child: child, commander: commander)
      else { return false }
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
      } else {
        guard commander.hullInstanceID == contract.booking.carrier,
          (commander.equipmentInventory?.revision ?? 0) >= contract.booking.inventoryRevision
        else { return false }
      }
    }
    for parent in engine.instances.values {
      guard let state = parent.savedWayfarerInduction, let source = state.charterClinicSource else {
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
          let contract = child.savedNativeInductionClinic,
          contract.booking.parent == parent.id
        else { return false }
        if event.kind == .reserved {
          guard event == stockEvent(contract.booking) else { return false }
        } else {
          guard let close = contract.close,
            event == stockEvent(close, booking: contract.booking)
          else { return false }
        }
      }
    }
    return true
  }
  static func stockEvent(_ booking: NativeInductionClinicBooking)
    -> NativeInductionClinicStockMutation
  {
    .init(
      kind: .reserved, operation: booking.operation, instance: booking.instance, unit: booking.unit,
      window: booking.window.operation, revision: booking.stockRevision, sequence: booking.sequence,
      physicalTime: booking.physicalTime, flightSeconds: booking.flightSeconds)
  }
  static func stockEvent(
    _ close: NativeInductionClinicUncollectedClose,
    booking: NativeInductionClinicBooking
  ) -> NativeInductionClinicStockMutation {
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
    guard dock.commanderOwner == commander.equipmentOwnerID,
      dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      dock.actor.visit <= commander.flightSimulation.visit,
      dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      commander.nativeStations?.mainStations.contains(dock.station) == true
    else { return false }
    return true
  }
  static func historicalEventValid(
    _ sequence: UInt64, time: Double, clock: Double,
    parent: ScriptInstance, child: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard sequence <= commander.scriptState.nextEvent,
      parent.hasAcknowledged(sequence), child.hasAcknowledged(sequence),
      time <= commander.flightSimulation.physicalTime,
      clock <= commander.scriptState.flightSeconds
    else { return false }
    return true
  }
}
