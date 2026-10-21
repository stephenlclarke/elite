import Foundation

enum NativeArkServiceWait: String, Codable, Sendable {
  case facilityUnavailable, fuelUnavailable, escrowExhausted, nativeLaunchPending
}

extension Game {
  /// Candidate-only service: same captured supplier stock, real quote, escrow and hull publish together.
  mutating func serviceInductionArk(_ id: UUID) throws -> Bool {
    guard var child = commander.scriptState.instances[id],
      child.revision < UInt64(Int64.max) - 3, let previous = child.savedNativeArk,
      let contact = previous.dockedContact, previous.loss == nil,
      var group = child.ownedEncounters[NativeInductionArkPack.encounter],
      var actor = group.actors[NativeInductionArkPack.alias], actor.presence == .unloaded,
      var npc = actor.body.scriptNPC, let hop = nextInductionArkHop(previous)
    else { return false }
    guard case .living(let supplier) = nativeOriginalMainStationDestination,
      supplier.identity == contact.station, var world = commander.nativeStations,
      world.mainStations.contains(contact.station)
    else { return recordInductionArkWait(id, previous: previous, reason: .facilityUnavailable) }
    var next = previous
    if npc.fuel < previous.authorization.route.legDistancesLY[hop.hop] {
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
      if let refusal = previous.fuel.refusal,
        refusal.request.offer.contact == contact,
        refusal.request.offer.supplierRevision == supply.revision,
        refusal.request.offer.availableTenthsLY == supply.remainingTenthsLY,
        refusal.request.offer.supplierActor == supplier.observation.actor,
        refusal.request.before == npc.fuel,
        refusal.request.nextHopLY == previous.authorization.route.legDistancesLY[hop.hop]
      {
        return false
      }
      let request = NativeArkFuelRequest(
        offer: .init(
          contact: contact, supplierRevision: supply.revision,
          availableTenthsLY: supply.remainingTenthsLY, pricePerTenth: Equipment.base[0].price,
          supplierActor: supplier.observation.actor,
          quotedAtPhysicalTime: commander.flightSimulation.physicalTime),
        before: npc.fuel, nextHopLY: previous.authorization.route.legDistancesLY[hop.hop])
      do {
        let quote = try previous.fuel.quote(request)
        let bank = try previous.fuel.purchasing(quote, current: request)
        guard let receipt = bank.purchases.last else { throw SaveError.invalidCommander }
        supplies[supplyIndex] = try supply.dispensing(receipt)
        npc.fuel = quote.fuelAfter
        actor.body.scriptNPC = npc
        group.actors[NativeInductionArkPack.alias] = actor
        child.ownedEncounters[NativeInductionArkPack.encounter] = group
        next = next.replacing(fuel: bank, clearsServiceWait: true)
        child.journal.append(
          "The real main-orbital supplier dispensed \(receipt.billedTenths) fuel tenths to this original ark and debited \(quote.cost) custodian decicredits. No player funds changed."
        )
      } catch let refusal as NativeArkFuelRefusal {
        let bank = try previous.fuel.recordingRefusal(request)
        let reason: NativeArkServiceWait =
          refusal == .insufficientEscrow ? .escrowExhausted : .fuelUnavailable
        next = next.replacing(fuel: bank, serviceWait: reason)
      }
      world.arkFuel = supplies
      commander.nativeStations = world
    }
    child.savedNativeArk = next
    if next != previous { child.revision += 1 }
    commander.scriptState.instances[id] = child
    if next.fuel.refusal != nil && npc.fuel < previous.authorization.route.legDistancesLY[hop.hop] {
      return next != previous
    }
    guard !docked else { return next != previous }
    let source = try inductionArkBerthAdmissionSource(id)
    switch try prepareMissionActorAdmission(source) {
    case .pending:
      return recordInductionArkWait(id, previous: next, reason: .nativeLaunchPending)
        || next != previous
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
      staged.savedNativeArk = next.replacing(
        clearsDock: true,
        exitedContacts: next.exitedContacts + [contact.sequence], clearsServiceWait: true,
        exits: next.exits + [
          .init(
            contactSequence: contact.sequence, actor: actualActor,
            physicalTime: commander.flightSimulation.physicalTime)
        ])
      staged.revision += 1
      commander.scriptState.instances[id] = staged
      return true
    }
  }

  private mutating func recordInductionArkWait(
    _ id: UUID, previous: NativeInductionArkState, reason: NativeArkServiceWait
  ) -> Bool {
    guard previous.serviceWait != reason, var child = commander.scriptState.instances[id],
      child.revision < UInt64(Int64.max) - 1
    else { return false }
    child.savedNativeArk = previous.replacing(serviceWait: reason)
    child.revision += 1
    commander.scriptState.instances[id] = child
    return true
  }
}
