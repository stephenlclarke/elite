import Foundation

enum NativeInductionCharterConsentSave {
  static func signaturesValid(
    _ signatures: [NativeInductionCharterSignature],
    mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    for signature in signatures {
      guard signature.sequence <= commander.scriptState.nextEvent,
        mission.hasAcknowledged(signature.sequence),
        signature.physicalTime <= commander.flightSimulation.physicalTime,
        signature.flightSeconds <= commander.scriptState.flightSeconds,
        signature.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
        signature.dock.actor.visit <= commander.flightSimulation.visit,
        signature.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
        commander.nativeStations?.mainStations.contains(signature.dock.station) == true
      else { return false }
    }
    return true
  }
  static func capacityEventsValid(
    _ state: NativeInductionCapacityState,
    mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    for event in state.events {
      // Accepted consignment/custody joins remain the separate quote-source adapter.
      guard case .released(let release) = event,
        let signature = mission.savedWayfarerInduction?.charterSignatures?.first(where: {
          $0.operatorID == release.operatorID
        }), release.consent == signature.operation, release.sequence > signature.sequence,
        release.revision >= signature.capacityRevision,
        release.physicalTime >= signature.physicalTime,
        release.flightSeconds >= signature.flightSeconds,
        release.dock.sequence >= signature.dock.sequence,
        release.sequence <= commander.scriptState.nextEvent,
        mission.hasAcknowledged(release.sequence),
        release.physicalTime <= commander.flightSimulation.physicalTime,
        release.flightSeconds <= commander.scriptState.flightSeconds,
        release.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
        release.dock.actor.visit <= commander.flightSimulation.visit,
        release.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
        commander.nativeStations?.mainStations.contains(release.dock.station) == true
      else { return false }
    }
    return true
  }
}
