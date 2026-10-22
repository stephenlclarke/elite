import Foundation

enum NativeInductionClinicSave {
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    // This source envelope has no accepted consignment instances yet.
    guard !engine.instances.values.contains(where: { NativeInductionClinicPack.marked($0) }) else {
      return false
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
        issue.dock.calendarSeconds <= engine.calendarSeconds,
        issue.dock.actor.visit <= commander.flightSimulation.visit,
        issue.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
        commander.nativeStations?.mainStations.contains(issue.dock.station) == true,
        commander.nativeStations?.mainStations.contains(source.delegation.auditor) == true
      else { return false }
    }
    return true
  }
}
