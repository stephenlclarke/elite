import Foundation

extension NativeRescueFlightSave {
  private enum FuelEvent {
    case purchase(NativeArkFuelPurchase)
    case departure(NativeWormholeDeparture)
    var time: Double {
      switch self {
      case .purchase(let purchase): purchase.request.offer.quotedAtPhysicalTime
      case .departure(let departure): departure.physicalTime
      }
    }
  }

  static func fuelHistoryValid(
    _ flight: NativeRescueFlightState, bank: NativeRescueFuelEscrow?,
    actor: ScriptOwnedActor, engine: borrowing ScriptEngineState
  ) -> Bool {
    let ledger = engine.wormholeTransit?.legs ?? [:]
    var events = (bank?.purchases ?? []).map(FuelEvent.purchase)
    for reference in flight.legs {
      if let departure = ledger[reference.leg]?.departure { events.append(.departure(departure)) }
    }
    events.sort { $0.time < $1.time }
    var fuel = flight.authorization.initialFuelLY
    var time = flight.authorization.physicalTime
    for event in events {
      guard event.time.isFinite, event.time > time else { return false }
      switch event {
      case .purchase(let purchase):
        guard flight.fuelContacts.contains(purchase.request.offer.contact),
          purchase.request.before == fuel
        else { return false }
        fuel = purchase.fuelAfter
      case .departure(let departure):
        guard departure.fuelBefore == fuel else { return false }
        fuel = departure.fuelAfter
      }
      time = event.time
    }
    guard actor.body.scriptNPC?.fuel == fuel else { return false }
    for contact in flight.fuelContacts {
      // Contact, purchase and exit may attain the same frame clock, in that causal order.
      let known = flight.bindings.filter { binding in
        binding.physicalTime <= contact.physicalTime
          && !flight.exits.contains(where: { exit in
            exit.actor == binding.actor && exit.contactSequence >= contact.sequence
          })
      }
      guard known.last?.actor == contact.arkActor
      else { return false }
    }
    for exit in flight.exits {
      guard
        (bank?.purchases ?? []).filter({
          $0.request.offer.contact.sequence == exit.contactSequence
        }).allSatisfy({ $0.request.offer.quotedAtPhysicalTime <= exit.physicalTime })
      else { return false }
    }
    return true
  }

  static func serviceBoundsValid(
    _ flight: NativeRescueFlightState, bank: NativeRescueFuelEscrow,
    commander: borrowing Commander
  ) -> Bool {
    let stations = commander.nativeStations?.mainStations ?? []
    let ledger = commander.scriptState.wormholeTransit?.legs ?? [:]
    let now = commander.flightSimulation.physicalTime
    let visit = commander.flightSimulation.visit
    let next = commander.flightSimulation.nextActor
    guard
      flight.fuelContacts.allSatisfy({
        stations.contains($0.station)
          && $0.arkActor.visit <= visit && $0.arkActor.entity < next && $0.physicalTime <= now
      }),
      flight.bindings.allSatisfy({
        $0.actor.visit <= visit && $0.actor.entity < next && $0.physicalTime <= now
      }), flight.exits.allSatisfy({ $0.physicalTime <= now }),
      bank.purchases.allSatisfy({
        $0.request.offer.supplierActor.visit <= visit
          && $0.request.offer.quotedAtPhysicalTime <= now
      })
    else { return false }
    if let refusal = bank.refusal {
      guard refusal.request.offer.supplierActor.visit <= visit,
        refusal.request.offer.quotedAtPhysicalTime <= now
      else { return false }
    }
    // Every off-source observed physical binding needs a real preceding owned arrival.
    for binding in flight.bindings
    where binding.actor.system != NativeInductionCrewLogSource.location {
      guard
        flight.legs.contains(where: { reference in
          guard let leg = ledger[reference.leg],
            let arrival = leg.arrival, let departure = leg.departure
          else { return false }
          return arrival.nativeActor.system == binding.actor.system
            && arrival.nativeActor.visit <= binding.actor.visit
            && departure.physicalTime < binding.physicalTime
        })
      else { return false }
    }
    return true
  }
}
