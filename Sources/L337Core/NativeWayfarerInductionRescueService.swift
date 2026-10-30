import Foundation

extension Game {
  /// Candidate-only service: same captured supplier stock, real quote, escrow and hull publish together.
  mutating func serviceInductionRescue(_ id: UUID) throws -> Bool {
    guard var child = commander.scriptState.instances[id],
      child.revision < UInt64(Int64.max) - 3, let previousState = child.savedNativeCrewLog,
      let previous = previousState.flight,
      let contact = previous.dockedContact, previousState.livingCrew.count == 2,
      let previousBank = previousState.rescueFuel, previousBank.closure == nil,
      var group = child.ownedEncounters[NativeInductionCrewLogPack.encounter],
      var actor = group.actors["launch"], actor.presence == .unloaded,
      var npc = actor.body.scriptNPC, let hop = nextInductionRescueHop(previous)
    else { return false }
    guard case .living(let supplier) = nativeOriginalMainStationDestination,
      supplier.identity == contact.station, var world = commander.nativeStations,
      world.mainStations.contains(contact.station)
    else { return recordInductionRescueWait(id, previous: previous, reason: .facilityUnavailable) }
    var next = previous
    var nextBank = previousBank
    if npc.fuel < previous.authorization.route.distancesLY[hop.hop] {
      var supplies = world.arkFuel ?? []
      let supplyIndex: Int
      if let existing = supplies.firstIndex(where: { $0.station == contact.station }) {
        supplyIndex = existing
      } else {
        guard supplies.count < NativeMainStationIdentity.maximumCount else { return false }
        supplies.append(try NativeArkStationFuel(contact: contact))
        supplyIndex = supplies.count - 1
      }
      let supply = supplies[supplyIndex]
      if let refusal = previousBank.refusal,
        refusal.request.offer.contact == contact,
        refusal.request.offer.supplierRevision == supply.revision,
        refusal.request.offer.availableTenthsLY == supply.remainingTenthsLY,
        refusal.request.offer.supplierActor == supplier.observation.actor,
        refusal.request.before == npc.fuel,
        refusal.request.nextHopLY == previous.authorization.route.distancesLY[hop.hop]
      {
        return false
      }
      let request = NativeArkFuelRequest(
        offer: .init(
          contact: contact, supplierRevision: supply.revision,
          availableTenthsLY: supply.remainingTenthsLY, pricePerTenth: Equipment.base[0].price,
          supplierActor: supplier.observation.actor,
          quotedAtPhysicalTime: commander.flightSimulation.physicalTime),
        before: npc.fuel, nextHopLY: previous.authorization.route.distancesLY[hop.hop])
      do {
        let quote = try previousBank.quote(request)
        let bank = try previousBank.purchasing(quote, current: request)
        guard let receipt = bank.purchases.last else { throw SaveError.invalidCommander }
        supplies[supplyIndex] = try supply.dispensing(receipt)
        npc.fuel = quote.fuelAfter
        actor.body.scriptNPC = npc
        group.actors["launch"] = actor
        child.ownedEncounters[NativeInductionCrewLogPack.encounter] = group
        nextBank = bank
        next.serviceWait = nil
        child.journal.append(
          "The real main-orbital supplier dispensed \(receipt.billedTenths) fuel tenths to this original rescue launch and debited \(quote.cost) custodian decicredits. No player funds changed."
        )
      } catch let refusal as NativeArkFuelRefusal {
        let bank = try previousBank.recordingRefusal(request)
        let reason: NativeArkServiceWait =
          refusal == .insufficientEscrow ? .escrowExhausted : .fuelUnavailable
        nextBank = bank
        next.serviceWait = reason
      }
      world.arkFuel = supplies
      commander.nativeStations = world
    }
    var nextState = previousState
    nextState.flight = next
    nextState.rescueFuel = nextBank
    child.savedNativeCrewLog = nextState
    let changed = nextState != previousState
    if changed { child.revision += 1 }
    commander.scriptState.instances[id] = child
    if nextBank.refusal != nil && npc.fuel < previous.authorization.route.distancesLY[hop.hop] {
      return changed
    }
    guard !docked else { return changed }
    let source = try inductionRescueBerthAdmissionSource(id)
    switch try prepareMissionActorAdmission(source) {
    case .pending:
      return recordInductionRescueWait(id, previous: next, reason: .nativeLaunchPending)
        || changed
    case .unchanged: throw SaveError.invalidCommander
    case .ready(let plan):
      guard let current = commander.scriptState.instances[id] else {
        throw SaveError.invalidCommander
      }
      var staged = try plan.retentionPatch.preparingInstance(current)
      let admitted = try commitMissionActorAdmission(plan)
      guard let actualActor = admitted.nativeActors[next.authorization.actor] else {
        throw SaveError.invalidCommander
      }
      next.dockedContact = nil
      next.serviceWait = nil
      next.savedExits =
        next.exits + [
          .init(
            contactSequence: contact.sequence,
            actor: actualActor, physicalTime: commander.flightSimulation.physicalTime)
        ]
      next.recordBinding(actualActor, at: commander.flightSimulation.physicalTime)
      nextState.flight = next
      staged.savedNativeCrewLog = nextState
      staged.revision += 1
      commander.scriptState.instances[id] = staged
      return true
    }
  }

  private mutating func recordInductionRescueWait(
    _ id: UUID, previous: NativeRescueFlightState, reason: NativeArkServiceWait
  ) -> Bool {
    guard previous.serviceWait != reason, var child = commander.scriptState.instances[id],
      child.revision < UInt64(Int64.max) - 1
    else { return false }
    guard var state = child.savedNativeCrewLog else { return false }
    var flight = previous
    flight.serviceWait = reason
    state.flight = flight
    child.savedNativeCrewLog = state
    child.revision += 1
    commander.scriptState.instances[id] = child
    return true
  }
}
