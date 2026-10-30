import Foundation

extension NativeInductionArkSave {
  private enum FuelEvent {
    case purchase(NativeArkFuelPurchase)
    case departure(NativeWormholeDeparture)
    var time: Double {
      switch self {
      case .purchase(let p): p.request.offer.quotedAtPhysicalTime
      case .departure(let d): d.physicalTime
      }
    }
  }

  /// A saved hull cannot acquire a refill between the original tank, paid service and real entries.
  static func fuelHistoryValid(
    _ state: NativeInductionArkState, child: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    let nativeLegs = engine.wormholeTransit?.legs ?? [:]
    var events = state.fuel.purchases.map(FuelEvent.purchase)
    for reference in state.legs {
      if let departure = nativeLegs[reference.leg]?.departure {
        events.append(.departure(departure))
      }
    }
    events.sort { $0.time < $1.time }
    var fuel = state.authorization.route.initialFuelLY
    var previousTime = state.authorization.physicalTime
    for event in events {
      guard event.time.isFinite, event.time > previousTime else { return false }
      switch event {
      case .purchase(let purchase):
        guard purchase.request.before == fuel else { return false }
        fuel = purchase.fuelAfter
      case .departure(let departure):
        guard departure.fuelBefore == fuel else { return false }
        fuel = departure.fuelAfter
      }
      previousTime = event.time
    }
    if let actor = child.ownedEncounters[NativeInductionArkPack.encounter]?.actors[
      NativeInductionArkPack.alias]
    {
      guard actor.body.scriptNPC?.fuel == fuel else { return false }
    } else if !events.isEmpty {
      return false
    }
    for contact in state.fuelContacts {
      var knownActors: [ActorIdentity] = []
      if let admission = state.admission, admission.physicalTime <= contact.physicalTime,
        admission.actor.system == contact.station.system
      {
        knownActors.append(admission.actor)
      }
      knownActors += state.exits.filter {
        $0.actor.system == contact.station.system && $0.physicalTime <= contact.physicalTime
      }.map(\.actor)
      for reference in state.legs {
        if let leg = nativeLegs[reference.leg],
          let departure = leg.departure, departure.physicalTime < contact.physicalTime,
          let arrival = leg.arrival, arrival.nativeActor.system == contact.station.system,
          arrival.nativeActor.visit <= contact.arkActor.visit
        {
          knownActors.append(arrival.nativeActor)
        }
      }
      let latest = knownActors.max {
        $0.visit == $1.visit ? $0.entity < $1.entity : $0.visit < $1.visit
      }
      guard latest == contact.arkActor else { return false }
    }
    for exit in state.exits {
      guard
        state.fuel.purchases.filter({ $0.request.offer.contact.sequence == exit.contactSequence })
          .allSatisfy({ $0.request.offer.quotedAtPhysicalTime <= exit.physicalTime })
      else { return false }
    }
    return true
  }
}
