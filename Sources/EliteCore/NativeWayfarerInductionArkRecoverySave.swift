import Foundation

extension NativeInductionArkSave {
  static func recoveryParentValid(
    _ parent: borrowing ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard parent.definition == NativeWayfarerInduction.stateID,
      parent.version == NativeWayfarerInduction.version,
      parent.digest == NativeWayfarerInduction.digest,
      let leaf = parent.savedWayfarerInduction, leaf.valid,
      leaf.permission.owner == commander.equipmentOwnerID
    else { return false }
    if let reserve = parent.savedArkReserve {
      guard reserve.valid(permission: leaf.permission) else { return false }
      if let dock = reserve.legacyRebriefDock {
        guard dock == parent.savedArkRecovery?.dock,
          dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
          dock.actor.visit <= commander.flightSimulation.visit
        else { return false }
      }
    }
    guard let recovery = parent.savedArkRecovery else { return true }
    guard recoveryFactsValid(parent, engine: commander.scriptState),
      recovery.physicalTime <= commander.flightSimulation.physicalTime,
      recovery.flightSeconds <= commander.scriptState.flightSeconds,
      recovery.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      recovery.dock.actor.visit <= commander.flightSimulation.visit
    else { return false }
    return true
  }

  /// Pure cross-record accounting/ownership joins; physical actor proof is checked separately.
  static func recoveryFactsValid(
    _ parent: borrowing ScriptInstance, engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let recovery = parent.savedArkRecovery else { return true }
    guard let leaf = parent.savedWayfarerInduction else { return false }
    guard let reserve = parent.savedArkReserve, let key = leaf.seedKey,
      leaf.ark == recovery.replacement,
      recovery.valid(reserve: reserve, key: key, permission: leaf.permission),
      let retired = engine.instances[recovery.retired.job],
      let old = retired.savedNativeArk, old.authorization.reserve == nil,
      old.authorization.parent == parent.id, old.authorization.job == recovery.retired.job,
      old.authorization.registeredArk == recovery.retired.registeredArk,
      old.authorization.operation == recovery.retired.operation,
      old.loss == recovery.priorLoss, old.reception == nil,
      old.fuel.closure?.recoveryOperation == recovery.operation,
      recovery.sequence <= engine.nextEvent,
      parent.hasAcknowledged(recovery.sequence), retired.hasAcknowledged(recovery.sequence),
      let replacement = engine.instances[recovery.replacement.job],
      let new = replacement.savedNativeArk, replacement.hasAcknowledged(recovery.sequence),
      new.authorization.sequence == recovery.sequence, new.authorization.reserve == reserve,
      new.authorization.operation == recovery.replacement.operation,
      new.authorization.dock == recovery.dock,
      new.authorization.physicalTime == recovery.physicalTime,
      recovery.sequence > old.authorization.sequence,
      recovery.dock.sequence > old.authorization.dock.sequence,
      new.authorization.flightSeconds == recovery.flightSeconds,
      new.authorization.carrier == recovery.carrier,
      new.authorization.inventoryRevision == recovery.inventoryRevision
    else { return false }
    return true
  }

}
