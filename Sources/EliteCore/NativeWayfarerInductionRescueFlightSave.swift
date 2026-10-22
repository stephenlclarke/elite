import Foundation

enum NativeRescueFlightSave {
  static func valid(
    _ state: NativeInductionCrewLogState, parent: ScriptInstance,
    child: ScriptInstance, source: NativeInductionCrewLogSource,
    commander: borrowing Commander
  ) -> Bool {
    guard let flight = state.flight else { return true }
    let a = flight.authorization
    guard let leaf = parent.savedWayfarerInduction, let bank = state.rescueFuel,
      flight.shapeValid(
        root: state.authorization, funding: bank.funding, parent: leaf, source: source),
      a.sequence <= commander.scriptState.nextEvent,
      parent.hasAcknowledged(a.sequence), child.hasAcknowledged(a.sequence),
      a.physicalTime <= commander.flightSimulation.physicalTime,
      a.flightSeconds <= commander.scriptState.flightSeconds,
      a.calendarSeconds <= commander.scriptState.calendarSeconds,
      commander.nativeStations?.mainStations.contains(a.dock.station) == true,
      a.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      a.dock.actor.visit <= commander.flightSimulation.visit,
      receivingClaimsValid(state, parent: parent, child: child, commander: commander),
      let actor = child.ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["launch"]
    else { return false }
    guard serviceBoundsValid(flight, bank: bank, commander: commander) else { return false }
    return legsValid(
      flight, source: source, actor: actor, engine: commander.scriptState, bank: bank)
  }

  static func legsValid(
    _ flight: NativeRescueFlightState, source: NativeInductionCrewLogSource,
    actor: ScriptOwnedActor, engine: borrowing ScriptEngineState,
    bank: NativeRescueFuelEscrow? = nil
  ) -> Bool {
    let a = flight.authorization
    var previous: NativeRescueHopReference?
    var previousLeg: NativeWormholeLeg?
    for reference in flight.legs {
      guard reference.valid(authorization: a),
        let leg = engine.wormholeTransit?.legs[reference.leg], leg.valid,
        leg.instance == a.job, leg.actor == a.actor,
        leg.encounter == NativeInductionCrewLogPack.encounter, leg.alias == "launch",
        leg.request == reference.request, leg.requestedAt >= a.calendarSeconds,
        leg.destinationWorld == a.route.worldKeys[reference.hop + 1]
      else { return false }
      if let previous, let previousLeg {
        if reference.hop == previous.hop {
          guard previousLeg.phase == .cancelled, reference.attempt == previous.attempt + 1 else {
            return false
          }
        } else {
          guard previousLeg.phase == .arrived, reference.hop == previous.hop + 1,
            reference.attempt == 0
          else { return false }
        }
      } else if reference.hop != 0 || reference.attempt != 0 {
        return false
      }
      if let route = leg.route {
        guard route.origin.worldID == a.route.worldKeys[reference.hop],
          route.destination.worldID == a.route.worldKeys[reference.hop + 1],
          route.distanceLightYears == a.route.distancesLY[reference.hop]
        else { return false }
      }
      if let departure = leg.departure {
        guard let fit = departure.body.scriptNPC?.fit, source.matchesFit(fit, recorder: false),
          departure.body.physical?.population == .mission,
          departure.body.physical?.npc?.role == .mission,
          leg.driveTerms == source.ship.drive, departure.physicalTime >= a.physicalTime,
          departure.fuelAfter == departure.fuelBefore - a.route.distancesLY[reference.hop]
        else { return false }
      }
      previous = reference
      previousLeg = leg
    }
    let all = engine.wormholeTransit?.legs.values.filter { $0.instance == a.job } ?? []
    guard all.count == flight.legs.count else { return false }
    return fuelHistoryValid(flight, bank: bank, actor: actor, engine: engine)
  }

  static func actorValid(
    _ actor: ScriptOwnedActor, flight: NativeRescueFlightState,
    root: NativeCrewLogAuthorization, commander: borrowing Commander
  ) -> Bool {
    let ledger = commander.scriptState.wormholeTransit?.legs ?? [:]
    let arrivals = flight.legs.compactMap { ledger[$0.leg] }.filter { $0.arrival != nil }
    let latest = arrivals.max {
      ($0.arrival?.calendarSeconds ?? 0) < ($1.arrival?.calendarSeconds ?? 0)
    }
    let expected = latest?.route?.destination.location ?? NativeInductionCrewLogSource.location
    guard (actor.transitLocation ?? NativeInductionCrewLogSource.location) == expected,
      let npc = actor.body.scriptNPC, npc.velocity.finite,
      let native = actor.body.physical,
      native.population == .mission, native.npc?.role == .mission,
      native.identity.system == expected, native.identity.visit >= root.stationActor.visit,
      native.identity.visit <= commander.flightSimulation.visit,
      native.identity.entity > 1, native.identity.entity < commander.flightSimulation.nextActor,
      native.ordnance == nil, native.rock == nil, native.salvage == nil,
      native.empSource == nil, native.empCrewPod == nil
    else { return false }
    if let contact = flight.dockedContact {
      guard actor.presence == .unloaded, actor.body.energy > 0,
        native.identity == contact.arkActor, expected == contact.station.system,
        npc.velocity == .init(0, 0, 0), npc.intent == nil
      else { return false }
    }
    if let intent = npc.intent {
      if intent.request == "native-rescue-workarea-exit" {
        guard latest == nil, intent.mode == .approach, intent.target == nil, !intent.player,
          intent.offset == NativeInductionCrewLogRole.launch.offset + Vector3(0, 0, 1200),
          intent.speed == min(1, 144 / npc.fit.definition.speed), intent.tolerance == 50
        else { return false }
      } else if intent.request == "native-rescue-berth-exit" {
        guard flight.dockedContact == nil, let exit = flight.exits.last,
          exit.actor == native.identity, intent.mode == .approach,
          intent.target == nil, !intent.player, intent.offset.finite,
          intent.speed == min(1, 144 / npc.fit.definition.speed), intent.tolerance == 50
        else { return false }
      } else if !flight.legs.contains(where: { $0.request == intent.request }) {
        return false
      }
    }
    if [.inTransit, .arrivalPending].contains(actor.presence) {
      guard let last = flight.legs.last, let leg = ledger[last.leg],
        let departure = leg.departure, leg.arrival == nil,
        [.inTransit, .arrivalPending].contains(leg.phase), actor.body == departure.body
      else { return false }
      return true
    }
    return true
  }
}
