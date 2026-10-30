import Foundation

extension NativeInductionCrewLogPack {
  static func facilityHolds(_ actor: UUID, commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains { child in
      guard let state = child.savedNativeCrewLog, let flight = state.flight else { return false }
      return flight.authorization.actor == actor && flight.dockedContact != nil
        && (state.livingCrew.count == 2 || state.rescueReception != nil)
    }
  }
}

extension Game {
  /// Attained native docking survives writer refusal. It neither dispenses fuel nor receives people.
  mutating func observeInductionRescueDock(from sample: NativeWormholeMotionSample?) {
    guard let sample, var child = inductionCrewLogChild, var state = child.savedNativeCrewLog,
      var flight = state.flight, child.revision < UInt64(Int64.max) - 1,
      let witness = nativeInductionRescueDockWitness(state: state, sample: sample),
      var group = child.ownedEncounters[NativeInductionCrewLogPack.encounter],
      var actor = group.actors["launch"], actor.identity == flight.authorization.actor,
      actor.presence == .present,
      let index = bodies.firstIndex(where: { $0.physical?.identity == witness.contact.arkActor }),
      let anchor = scriptAnchor, flight.bindings.count < 256
    else { return }
    // The physical address is observed from the same native frame, never recreated from a receipt.
    flight.recordBinding(witness.contact.arkActor, at: sample.physicalTime)
    flight.savedFuelContacts = flight.fuelContacts + [witness.contact]
    flight.dockedContact = witness.contact
    actor.body = witness.body
    actor.body.position = anchor.orientation.inverse(witness.body.position - anchor.position)
    actor.body.orientation = witness.body.orientation.relative(to: anchor.orientation)
    actor.body.scriptNPC?.velocity = .init(0, 0, 0)
    actor.body.scriptNPC?.intent = nil
    actor.presence = .unloaded
    group.actors["launch"] = actor
    child.ownedEncounters[NativeInductionCrewLogPack.encounter] = group
    state.flight = flight
    child.savedNativeCrewLog = state
    child.revision += 1
    child.journal.append(
      "The same original rescue launch entered the actual main-orbital berth. Its two original people remain aboard; no fuel or survivor receiving is inferred."
    )
    commander.scriptState.instances[child.id] = child
    clearRemovedTarget(bodies[index])
    bodies.remove(at: index)
    inductionRescueDockPublicationPending = true
  }

  var hasInductionRescueMotionObserver: Bool {
    guard let state = inductionCrewLogChild?.savedNativeCrewLog, let flight = state.flight,
      state.livingCrew.count == 2, flight.dockedContact == nil
    else { return false }
    return bodies.contains { $0.missionActorID == flight.authorization.actor }
  }
}
