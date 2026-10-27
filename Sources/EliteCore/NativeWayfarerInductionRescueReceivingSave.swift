import Foundation

extension NativeRescueFlightSave {
  static func allHopsReceived(
    _ flight: NativeRescueFlightState, engine: borrowing ScriptEngineState
  ) -> Bool {
    for hop in flight.authorization.route.distancesLY.indices {
      guard let reference = flight.legs.last(where: { $0.hop == hop }),
        let leg = engine.wormholeTransit?.legs[reference.leg], leg.valid, leg.phase == .arrived,
        leg.instance == flight.authorization.job, leg.actor == flight.authorization.actor,
        leg.encounter == NativeInductionCrewLogPack.encounter, leg.alias == "launch",
        leg.arrival != nil, leg.request == reference.request,
        leg.route?.origin.worldID == flight.authorization.route.worldKeys[hop],
        leg.route?.distanceLightYears == flight.authorization.route.distancesLY[hop],
        leg.destinationWorld == flight.authorization.route.worldKeys[hop + 1]
      else { return false }
    }
    return flight.legs.last?.hop == flight.authorization.route.distancesLY.count - 1
  }

  static func receivingClaimsValid(
    _ state: NativeInductionCrewLogState,
    parent: ScriptInstance, child: ScriptInstance, commander: borrowing Commander
  ) -> Bool {
    guard let receipt = state.rescueReception else { return true }
    guard let flight = state.flight, allHopsReceived(flight, engine: commander.scriptState),
      receipt.sequence <= commander.scriptState.nextEvent,
      parent.hasAcknowledged(receipt.sequence), child.hasAcknowledged(receipt.sequence),
      receipt.physicalTime <= commander.flightSimulation.physicalTime,
      receipt.flightSeconds <= commander.scriptState.flightSeconds,
      commander.nativeStations?.mainStations.contains(receipt.playerDock.station) == true,
      receipt.playerDock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      receipt.playerDock.actor.visit <= commander.flightSimulation.visit,
      receipt.inventoryRevision < UInt64(Int64.max)
    else { return false }
    return true
  }
}
