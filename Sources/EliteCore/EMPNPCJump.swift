import Foundation

extension Game {
  /// Ordinary NPC departure is an owned fuel transaction, not destruction or a cull.
  /// A disabled hull cannot begin it even while its occupants and weapons remain aboard.
  @discardableResult
  mutating func initiateNPCJump(bodyID: Int, destination: SystemIdentity) -> Bool {
    guard !docked, destination.galaxy == commander.galaxy,
      destination.system != commander.system,
      let index = bodies.firstIndex(where: { $0.id == bodyID && $0.energy > 0 }),
      !isEMPDisabled(bodies[index]), bodies[index].physical?.empCrewPod == nil,
      let physical = bodies[index].physical, let npc = physical.npc,
      npc.role != .mission, !bodies[index].navalTarget, bodies[index].blackjackRole == nil,
      !physical.blocksNavalEncounter, let context = gameplayContext(),
      !context.protection.protectedActors.contains(physical.identity),
      npc.destination == destination, var resources = npc.resources,
      let target = systems.first(where: { $0.id == destination.system }),
      let performance = physical.catalogueShipID.flatMap({ ShipCatalogue.ship($0)?.game })
        ?? ShipCatalogue.nativeShip(bodies[index].hull)?.game,
      currentSystem.distance(to: target) <= performance.jump
    else { return false }
    let cost = Int(ceil(currentSystem.distance(to: target) * 10))
    guard resources.spendFuel(cost) else { return false }
    var candidate = self
    candidate.bodies[index].physical?.npc?.resources = resources
    guard !candidate.persistNPCStates().contains(bodyID),
      candidate.commander.npcPersistence.terminal(actor: physical.identity, reason: .jumped)
    else { return false }
    candidate.clearRemovedTarget(candidate.bodies[index])
    candidate.bodies.remove(at: index)
    self = candidate
    return true
  }
}
