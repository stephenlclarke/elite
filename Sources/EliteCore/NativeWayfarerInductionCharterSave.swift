import Foundation

enum NativeInductionCharterSave {
  static func claimsValid(
    _ choice: NativeInductionCharterChoice,
    mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard choice.parent == mission.id, choice.owner == commander.equipmentOwnerID,
      choice.sequence <= commander.scriptState.nextEvent,
      mission.hasAcknowledged(choice.sequence),
      commander.nativeStations?.mainStations.contains(choice.dock.station) == true,
      choice.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      choice.dock.actor.visit <= commander.flightSimulation.visit,
      choice.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      choice.physicalTime <= commander.flightSimulation.physicalTime,
      choice.flightSeconds <= commander.scriptState.flightSeconds
    else { return false }
    return true
  }
}
