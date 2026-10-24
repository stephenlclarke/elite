import Foundation

extension NativeInductionArkPack {
  static func facilityHolds(_ actor: UUID, commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains { child in
      guard let state = child.savedNativeArk else { return false }
      return state.authorization.actor == actor && state.dockedContact != nil && state.loss == nil
    }
  }
}

extension Game {
  /// Native contact is an attained physical fact, like hull destruction. A failed write does
  /// not undo it, recreate an outside ship, debit money or fill fuel; later publication retries.
  mutating func observeInductionArkDock(from sample: NativeWormholeMotionSample?) {
    guard let sample,
      let id = wayfarerInductionMission?.savedWayfarerInduction?.ark?.job,
      var child = commander.scriptState.instances[id], let state = child.savedNativeArk,
      child.revision < UInt64(Int64.max) - 1,
      let witness = nativeInductionArkDockWitness(state: state, sample: sample),
      var group = child.ownedEncounters[NativeInductionArkPack.encounter],
      var actor = group.actors[NativeInductionArkPack.alias],
      actor.identity == state.authorization.actor, actor.presence == .present,
      let index = bodies.firstIndex(where: { $0.physical?.identity == witness.contact.arkActor }),
      let anchor = scriptAnchor
    else { return }
    actor.body = witness.body
    actor.body.position = anchor.orientation.inverse(witness.body.position - anchor.position)
    actor.body.orientation = witness.body.orientation.relative(to: anchor.orientation)
    actor.body.scriptNPC?.velocity = .init(0, 0, 0)
    actor.body.scriptNPC?.intent = nil
    actor.presence = .unloaded
    group.actors[NativeInductionArkPack.alias] = actor
    child.ownedEncounters[NativeInductionArkPack.encounter] = group
    child.savedNativeArk = state.replacing(
      fuelContacts: state.fuelContacts + [witness.contact], dockedContact: witness.contact)
    child.revision += 1
    child.journal.append(
      "Original ark attained the real main-orbital aperture and entered its berth. No fuel, receiving credit or payment is inferred from docking."
    )
    commander.scriptState.instances[id] = child
    clearRemovedTarget(bodies[index])
    bodies.remove(at: index)
    inductionArkDockPublicationPending = true
  }
}
