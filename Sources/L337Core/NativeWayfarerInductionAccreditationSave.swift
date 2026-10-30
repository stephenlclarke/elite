import Foundation

enum NativeInductionAccreditationSave {
  /// Only this pinned terminal permits subsequent, individually acknowledged service mutations.
  static func validCompletion(
    _ receipt: ScriptCompletionReceipt, state mission: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard receipt.instance == mission.id, receipt.definition == mission.definition,
      receipt.version == mission.version, receipt.digest == mission.digest,
      receipt.outcome == .complete,
      mission.definition == NativeWayfarerInduction.stateID,
      mission.version == NativeWayfarerInduction.version,
      mission.digest == NativeWayfarerInduction.digest,
      mission.outcome == .complete, let parent = mission.savedWayfarerInduction, parent.valid,
      let terminal = parent.accreditation, terminal.valid(parent: parent),
      receipt.sequence == terminal.sequence, receipt.revision == terminal.publicationRevision,
      receipt.causeKind == "mission.receipted", receipt.cause?.nativeMainDock == terminal.dock,
      receipt.committed.nativeMainDock == terminal.dock,
      receipt.milestones == Array(0...13), mission.milestones == Set(0...13),
      mission.payloads.isEmpty, mission.contract == nil,
      terminal.sequence <= engine.nextEvent, mission.hasAcknowledged(terminal.sequence),
      terminal.flightSeconds <= engine.flightSeconds,
      terminal.dock.calendarSeconds <= engine.calendarSeconds,
      let later = postTerminalMutations(
        mission: mission, parent: parent, engine: engine, after: terminal.sequence),
      mission.revision >= terminal.publicationRevision,
      mission.revision - terminal.publicationRevision == UInt64(later)
    else { return false }
    return true
  }

  private static func postTerminalMutations(
    mission: borrowing ScriptInstance, parent: NativeWayfarerInductionState,
    engine: borrowing ScriptEngineState, after: UInt64
  ) -> Int? {
    var sequences: Set<UInt64> = []
    let nextEvent = engine.nextEvent
    let through = mission.acknowledgedThrough ?? 0
    let acknowledged = mission.acknowledgedEvents
    func record(_ sequence: UInt64, child: ScriptInstance? = nil) -> Bool {
      guard sequence <= nextEvent, sequence <= through || acknowledged.contains(sequence),
        child.map({ $0.hasAcknowledged(sequence) }) ?? true
      else { return false }
      if sequence > after { sequences.insert(sequence) }
      return true
    }
    for event in parent.charterCapacity?.events ?? [] {
      if case .released(let release) = event, !record(release.sequence) { return nil }
    }
    if let source = parent.charterClinicSource {
      guard record(source.issue.sequence) else { return nil }
      for event in source.history ?? [] {
        guard let child = engine.instances[event.instance],
          let contract = child.savedNativeInductionClinic, contract.booking.parent == mission.id,
          NativeInductionClinicSave.shapeValid(child), contract.valid(parent: parent),
          record(event.sequence, child: child)
        else { return nil }
        if event.kind == .reserved {
          guard event == NativeInductionClinicSave.stockEvent(contract.booking) else { return nil }
        } else if let close = contract.close {
          guard event == NativeInductionClinicSave.stockEvent(close, booking: contract.booking)
          else { return nil }
        } else {
          guard let end = contract.custody?.end,
            event == NativeInductionClinicSave.stockEvent(end, booking: contract.booking)
          else { return nil }
        }
        if let custody = contract.custody {
          if custody.end != nil {
            guard let completion = child.completionReceipt,
              completion.valid(for: child, engine: engine)
            else { return nil }
          }
          guard record(custody.pickup.contact.sequence, child: child) else { return nil }
          if let cancel = custody.cancellation, !record(cancel.contact.sequence, child: child) {
            return nil
          }
        }
      }
    }
    if let source = parent.charterSeedSource {
      guard record(source.issue.sequence) else { return nil }
      for event in source.history ?? [] {
        guard let child = engine.instances[event.instance],
          let contract = child.savedNativeInductionSeed, contract.booking.parent == mission.id,
          NativeInductionSeedSave.shapeValid(child), contract.valid(parent: parent),
          record(event.sequence, child: child)
        else { return nil }
        if event.kind == .reserved {
          guard event == NativeInductionSeedSave.stockEvent(contract.booking) else { return nil }
        } else if let close = contract.close {
          guard event == NativeInductionSeedSave.stockEvent(close, booking: contract.booking) else {
            return nil
          }
        } else {
          guard let end = contract.custody?.end,
            event == NativeInductionSeedSave.stockEvent(end, booking: contract.booking)
          else { return nil }
        }
        if let custody = contract.custody {
          if custody.end != nil {
            guard let completion = child.completionReceipt,
              completion.valid(for: child, engine: engine)
            else { return nil }
          }
          guard record(custody.pickup.contact.sequence, child: child) else { return nil }
          if let cancel = custody.cancellation, !record(cancel.contact.sequence, child: child) {
            return nil
          }
        }
      }
    }
    if let source = parent.charterWorkshopSource {
      guard record(source.issue.sequence) else { return nil }
      for event in source.history ?? [] {
        guard let child = engine.instances[event.instance],
          let contract = child.savedNativeInductionWorkshop, contract.booking.parent == mission.id,
          NativeInductionWorkshopSave.shapeValid(child), contract.valid(parent: parent),
          record(event.sequence, child: child)
        else { return nil }
        if event.kind == .reserved {
          guard event == NativeInductionWorkshopSave.stockEvent(contract.booking) else {
            return nil
          }
        } else {
          guard let end = contract.end,
            event == NativeInductionWorkshopSave.stockEvent(end, contract: contract)
          else { return nil }
        }
        if contract.end != nil {
          guard let completion = child.completionReceipt,
            completion.valid(for: child, engine: engine)
          else { return nil }
        }
        if let pickup = contract.pickup, !record(pickup.contact.sequence, child: child) {
          return nil
        }
        if let service = contract.service, !record(service.contact.sequence, child: child) {
          return nil
        }
        if let cancel = contract.cancellation, !record(cancel.contact.sequence, child: child) {
          return nil
        }
      }
    }
    return sequences.count
  }

  static func claimsValid(
    _ terminal: NativeInductionAccreditation, mission: ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard let receipt = mission.completionReceipt,
      validCompletion(receipt, state: mission, engine: commander.scriptState),
      receipt.valid(for: mission, engine: commander.scriptState),
      commander.scriptState.savedClueJournal?.awards["l337.wayfarer-exchange"]?.completion
        == receipt,
      commander.scriptState.savedClueJournal?.owner == commander.equipmentOwnerID,
      terminal.physicalTime <= commander.flightSimulation.physicalTime,
      terminal.flightSeconds <= commander.scriptState.flightSeconds,
      terminal.dock.actor.visit <= commander.flightSimulation.visit,
      terminal.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      commander.nativeStations?.mainStations.contains(terminal.dock.station) == true
    else { return false }
    return true
  }
}
