import Foundation

extension NativeWayfarerInductionState {
  func allocatingCharterCapacity(_ capacity: NativeInductionCapacityState) throws -> Self {
    guard valid, let charterChoice, charterCapacity == nil, capacity.events.isEmpty,
      capacity.valid(choice: charterChoice)
    else { throw SaveError.invalidCommander }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception,
      charterChoice: charterChoice, charterCapacity: capacity)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}

enum NativeInductionCapacitySave {
  static func claimsValid(
    _ state: NativeInductionCapacityState,
    mission: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    let source = state.allocation
    // Only actual owner-consent joins admit releases. Policy-only consignment events remain refused.
    guard
      NativeInductionCharterConsentSave.capacityEventsValid(
        state, mission: mission, commander: commander),
      source.parent == mission.id,
      source.commanderOwner == commander.equipmentOwnerID,
      source.sequence <= commander.scriptState.nextEvent, mission.hasAcknowledged(source.sequence),
      source.physicalTime <= commander.flightSimulation.physicalTime,
      source.flightSeconds <= commander.scriptState.flightSeconds,
      source.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      source.dock.actor.visit <= commander.flightSimulation.visit,
      source.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      commander.nativeStations?.mainStations.contains(source.dock.station) == true
    else { return false }
    return true
  }
}
