import Foundation

extension Game {
  /// Capture in allocation order so retired physical identities cannot be registered anew.
  @discardableResult
  mutating func persistNPCStates() -> Set<Int> {
    guard let context = gameplayContext() else { return [] }
    var refused = Set<Int>()
    for body in bodies.sorted(by: {
      ($0.physical?.identity.entity ?? 0) < ($1.physical?.identity.entity ?? 0)
    }) where body.energy > 0 && body.physical?.npc != nil {
      guard body.physical?.npc?.role != .mission, !body.navalTarget,
        body.blackjackRole == nil, body.physical?.blocksNavalEncounter != true,
        (body.physical?.identity).map({ !context.protection.protectedActors.contains($0) }) == true
      else { continue }
      guard
        let snapshot = NPCPersistenceSnapshot.capture(
          body: body, pose: commander.flightSimulation.pose, physicalTime: context.physicalTime,
          protection: context.protection)
      else {
        refused.insert(body.id)
        continue
      }
      if case .refused = commander.npcPersistence.capture(snapshot, protection: context.protection)
      {
        refused.insert(body.id)
      }
    }
    return refused
  }

  /// Off-scene ordinary craft coast in system coordinates for actual simulation time.
  /// This does not invent AI actions, jump fuel consumption or solar collection.
  mutating func advanceUnboundNPCs() {
    let now = commander.flightSimulation.physicalTime
    for (logical, var snapshot) in commander.npcPersistence.unboundSnapshots {
      let elapsed = now - snapshot.physicalTime
      guard elapsed.isFinite, elapsed > 0 else { continue }
      snapshot.position = snapshot.position + snapshot.velocity * elapsed
      snapshot.rotation += snapshot.rotationRate * elapsed
      let spin = snapshot.angularVelocity * elapsed
      snapshot.orientation.rotate(pitch: spin.x, roll: spin.z, yaw: spin.y)
      if var resources = snapshot.npc.resources {
        resources.advance(delta: elapsed)
        if resources.profile == .nativeHull {
          snapshot.energy = min(
            resources.energyCapacity, snapshot.energy + elapsed * resources.energyRecharge)
        }
        snapshot.npc.resources = resources
      }
      snapshot.physicalTime = now
      _ = commander.npcPersistence.updateUnbound(logicalIdentity: logical, snapshot: snapshot)
    }
  }

  mutating func admitPersistentNPCs() {
    guard let context = gameplayContext() else { return }
    let prior = commander.npcPersistence.unboundSnapshots
    let requests = commander.npcPersistence.pendingSpawnRequests(context: context)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: false)], intents: []))
    let rebindings = commander.npcPersistence.acknowledge(receipts: receipts)
    var identities: [ActorIdentity: ActorIdentity] = [:]
    for rebind in rebindings {
      if let old = prior[rebind.logicalIdentity]?.actor { identities[old] = rebind.actor }
      guard let index = bodies.firstIndex(where: { $0.physical?.identity == rebind.actor }) else {
        continue
      }
      var body = bodies[index]
      if rebind.restore(body: &body, pose: commander.flightSimulation.pose) { bodies[index] = body }
    }
    guard !rebindings.isEmpty else { return }
    for index in bodies.indices where bodies[index].physical?.npc != nil {
      if let original = bodies[index].physical?.npc?.firstAggressor {
        let rebound = reboundNPCReference(original, identities: identities)
        bodies[index].physical?.npc?.firstAggressor = rebound
      }
      switch bodies[index].physical?.npc?.intention {
      case .engage(let actor):
        let target = reboundNPCReference(actor, identities: identities)
        bodies[index].physical?.npc?.intention = .engage(target)
      case .flee(let actor):
        let target = reboundNPCReference(actor, identities: identities)
        bodies[index].physical?.npc?.intention = .flee(target)
      case .dock(let actor):
        let target = reboundNPCReference(actor, identities: identities)
        bodies[index].physical?.npc?.intention = .dock(target)
      default: break
      }
    }
  }

  private func reboundNPCReference(
    _ actor: ActorIdentity, identities: [ActorIdentity: ActorIdentity]
  ) -> ActorIdentity {
    guard actor.system == systemIdentity else { return actor }
    if actor.entity == 0 { return commander.flightSimulation.player ?? actor }
    if actor.entity == 1 { return commander.flightSimulation.anchors?.station.identity ?? actor }
    return identities[actor] ?? actor
  }
}
