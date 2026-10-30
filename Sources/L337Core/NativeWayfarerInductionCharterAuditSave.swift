import Foundation

enum NativeInductionCharterAuditSave {
  static func claimsValid(
    _ audit: NativeInductionCharterAudit, mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    let dock = audit.candidate.dock
    guard audit.sequence <= commander.scriptState.nextEvent,
      mission.hasAcknowledged(audit.sequence),
      audit.physicalTime <= commander.flightSimulation.physicalTime,
      audit.flightSeconds <= commander.scriptState.flightSeconds,
      dock.commanderOwner == commander.equipmentOwnerID,
      dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      dock.actor.visit <= commander.flightSimulation.visit,
      dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      commander.nativeStations?.mainStations.contains(dock.station) == true
    else { return false }
    return true
  }
}
