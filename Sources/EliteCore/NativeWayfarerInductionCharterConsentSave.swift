import Foundation

enum NativeInductionCharterConsentSave {
  static func signaturesValid(
    _ signatures: [NativeInductionCharterSignature],
    mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    for signature in signatures {
      guard let parent = mission.savedWayfarerInduction,
        let capacity = parent.charterCapacity,
        let snapshot = try? capacity.snapshot(at: signature.capacityRevision),
        snapshot.events.allSatisfy({ event in
          let clock: (UInt64, Double, Double)?
          if case .released(let release) = event {
            clock = (release.sequence, release.physicalTime, release.flightSeconds)
          } else {
            clock = parent.charterClinicSource?.windowEventClock(event)
          }
          guard let clock else { return false }
          return clock.0 < signature.sequence && clock.1 <= signature.physicalTime
            && clock.2 <= signature.flightSeconds
        })
      else { return false }

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
    var previous = (
      state.allocation.sequence, state.allocation.physicalTime, state.allocation.flightSeconds
    )
    for event in state.events {
      let clock: (UInt64, Double, Double)?
      if case .released(let release) = event {
        clock = (release.sequence, release.physicalTime, release.flightSeconds)
      } else {
        clock = mission.savedWayfarerInduction?.charterClinicSource?.windowEventClock(event)
      }
      guard let clock, clock.0 > previous.0, clock.1 >= previous.1, clock.2 >= previous.2 else {
        return false
      }
      previous = clock
      guard case .released(let release) = event else {
        guard let parent = mission.savedWayfarerInduction,
          let source = parent.charterClinicSource, source.ownsWindowEvent(event),
          let clock = source.windowEventClock(event),
          clock.0 <= commander.scriptState.nextEvent, mission.hasAcknowledged(clock.0),
          clock.1 <= commander.flightSimulation.physicalTime,
          clock.2 <= commander.scriptState.flightSeconds
        else { return false }
        continue
      }
      guard
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
