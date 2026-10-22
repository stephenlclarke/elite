import Foundation

enum NativeInductionWorkshopSave {
  static func shapeValid(_ child: borrowing ScriptInstance) -> Bool {
    guard let contract = child.savedNativeInductionWorkshop else { return false }
    return child.definition == NativeInductionWorkshopPack.stateID
      && child.version == NativeInductionWorkshopPack.version
      && child.digest == NativeInductionWorkshopPack.digest && child.id == contract.booking.instance
      && child.outcome == contract.outcome && child.contract == nil && child.dialogue == nil
      && child.gearIssues.isEmpty && child.timers.isEmpty && child.ownedEncounters.isEmpty
      && child.data == .object([:]) && child.campaignParent == nil && child.campaignChildren.isEmpty
      && child.payloads == contract.payloads
      && child.milestones == (contract.end?.facts.kind == .returned ? [0] : [])
      && (contract.end == nil ? child.completionReceipt == nil : true)
  }
  static func stockEvent(_ booking: NativeInductionWorkshopBooking)
    -> NativeInductionWorkshopStockMutation
  {
    .init(
      kind: .reserved, operation: booking.operation, instance: booking.instance, unit: booking.unit,
      window: booking.window.operation, revision: booking.stockRevision, sequence: booking.sequence,
      physicalTime: booking.physicalTime, flightSeconds: booking.flightSeconds, condition: nil)
  }
  static func stockEvent(
    _ end: NativeInductionWorkshopEnd, contract: NativeInductionWorkshopContract
  ) -> NativeInductionWorkshopStockMutation {
    let kind: NativeInductionWorkshopStockMutation.Kind
    switch end.facts.kind {
    case .cancelledBeforePickup: kind = .cancelledBeforePickup
    case .returned: kind = .returned
    case .cancelledHeld: kind = .cancelledHeld
    case .sourceLost: kind = .sourceLost
    case .carrierExit: kind = contract.pickup == nil ? .cancelledBeforePickup : .lost
    }
    return .init(
      kind: kind, operation: end.operation, instance: contract.booking.instance,
      unit: contract.booking.unit, window: end.facts.window.operation,
      revision: end.facts.stockRevision,
      sequence: end.facts.sequence, physicalTime: end.facts.physicalTime,
      flightSeconds: end.facts.context.flightSeconds,
      condition: kind == .cancelledBeforePickup ? nil : contract.condition)
  }
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    for child in engine.instances.values
    where NativeInductionWorkshopPack.marked(child) || child.savedNativeInductionWorkshop != nil {
      guard shapeValid(child), let contract = child.savedNativeInductionWorkshop,
        let parent = engine.instances[contract.booking.parent],
        let state = parent.savedWayfarerInduction,
        parent.definition == NativeWayfarerInduction.stateID,
        parent.version == NativeWayfarerInduction.version,
        parent.digest == NativeWayfarerInduction.digest,
        contract.valid(parent: state), let source = state.charterWorkshopSource,
        let capacity = state.charterCapacity,
        source.history?.contains(stockEvent(contract.booking)) == true,
        capacity.events.contains(.reserved(contract.booking.window)),
        NativeInductionClinicSave.historicalDockValid(contract.booking.dock, commander: commander),
        NativeInductionClinicSave.historicalEventValid(
          contract.booking.sequence, time: contract.booking.physicalTime,
          clock: contract.booking.flightSeconds, parent: parent, child: child, commander: commander)
      else { return false }
      if let pickup = contract.pickup {
        guard
          contactValid(
            pickup.contact, time: pickup.physicalTime, parent: parent, child: child,
            commander: commander)
        else { return false }
      }
      if let service = contract.service {
        guard
          contactValid(
            service.contact, time: service.physicalTime, parent: parent, child: child,
            commander: commander)
        else { return false }
      }
      if let cancel = contract.cancellation {
        guard
          contactValid(
            cancel.contact, time: cancel.physicalTime, parent: parent, child: child,
            commander: commander)
        else { return false }
      }
      if let end = contract.end {
        let f = end.facts
        guard source.history?.contains(stockEvent(end, contract: contract)) == true,
          capacity.events.contains(.returned(f.window)),
          NativeInductionClinicSave.historicalEventValid(
            f.sequence, time: f.physicalTime, clock: f.context.flightSeconds,
            parent: parent, child: child, commander: commander),
          commander.freightHistoricalContextValid(f.context, requiresDock: f.context.docked),
          let receipt = child.completionReceipt, receipt.sequence == f.sequence,
          receipt.cause == f.context,
          receipt.outcome == contract.outcome, receipt.valid(for: child, engine: engine)
        else { return false }
        if let contact = f.contact,
          !NativeInductionClinicSave.historicalDockValid(contact.dock, commander: commander)
        {
          return false
        }
        if let loss = f.loss, loss.visit > commander.flightSimulation.visit { return false }
        if let loss = f.sourceLoss, engine.stationResources[loss.key] != loss { return false }
      } else {
        guard commander.hullInstanceID == contract.booking.carrier,
          (commander.equipmentInventory?.revision ?? 0)
            >= (contract.service?.inventoryRevision ?? contract.pickup?.inventoryRevision
              ?? contract.booking.inventoryRevision),
          let occupied = commander.checkedCargoTonnes, occupied <= commander.standardCargoCapacity,
          commander.passengerFit?.allowed == true
        else { return false }
      }
    }
    for parent in engine.instances.values {
      guard let state = parent.savedWayfarerInduction, let source = state.charterWorkshopSource
      else { continue }
      guard source.valid(parent: state), source.issue.parent == parent.id,
        source.issue.commanderOwner == commander.equipmentOwnerID,
        source.issue.sequence <= engine.nextEvent, parent.hasAcknowledged(source.issue.sequence),
        source.issue.physicalTime <= commander.flightSimulation.physicalTime,
        source.issue.flightSeconds <= engine.flightSeconds,
        NativeInductionClinicSave.historicalDockValid(source.issue.dock, commander: commander),
        commander.nativeStations?.mainStations.contains(source.delegation.auditor) == true
      else { return false }
      for event in source.history ?? [] {
        guard let child = engine.instances[event.instance],
          let contract = child.savedNativeInductionWorkshop,
          contract.booking.parent == parent.id
        else { return false }
        if event.kind == .reserved {
          guard event == stockEvent(contract.booking) else { return false }
        } else {
          guard let end = contract.end, event == stockEvent(end, contract: contract) else {
            return false
          }
        }
      }
    }
    return true
  }
  private static func contactValid(
    _ contact: WayfarerColdChainContact, time: Double,
    parent: ScriptInstance, child: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard NativeInductionClinicSave.historicalDockValid(contact.dock, commander: commander),
      commander.freightHistoricalContextValid(contact.context, requiresDock: true),
      NativeInductionClinicSave.historicalEventValid(
        contact.sequence, time: time, clock: contact.context.flightSeconds,
        parent: parent, child: child, commander: commander)
    else { return false }
    return true
  }
}
