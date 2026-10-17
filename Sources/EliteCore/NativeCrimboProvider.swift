import Foundation

/// A request for G1's actual group-defence adjudication, never permission to emit a weapon.
struct NativeCrimboDefenceIntent: Equatable, Sendable {
  let provider: NativeProviderIdentity
  let member: UUID
  let actor: ActorIdentity
  let attacker: ActorIdentity
  let incident: UInt64
}

extension Game {
  /// Called by G1 with the resolution of the exact accepted native incident, before victim mutation.
  /// Selection, sensor discovery, decoded threat state and refused hits cannot start aggression.
  mutating func observeNativeCrimboCombat(incident: CombatIncident, resolution: CrimeResolution)
    throws
  {
    guard resolution.accepted, let victim = incident.victim, !incident.victimIsStation,
      [.laser, .missile, .bomb, .plasma, .emp].contains(incident.kind),
      [.targetedLaunch, .hit, .destruction, .componentDestruction].contains(incident.outcome),
      var registry = commander.savedCrimboState,
      registry.world == commander.equipmentOwnerID,
      registry.spawnSequence < commander.flightSimulation.nextSpawn,
      incident.id > registry.lastCombatIncident,
      incident.id < commander.flightSimulation.nextIncident,
      incident.origin.emissionID > 0,
      incident.origin.emissionID < commander.flightSimulation.nextEmission,
      incident.physicalTime == commander.flightSimulation.physicalTime,
      let member = registry.members.first(where: {
        registry.binding(of: $0, ledger: commander.npcPersistence) == victim
      }),
      incident.origin.owner.system == NativeCrimboRegistry.system,
      incident.origin.owner.visit == victim.visit,
      !registry.contains(actor: incident.origin.owner, ledger: commander.npcPersistence)
    else { return }
    try registry.validate()
    let attacker = incident.origin.owner
    let original =
      commander.npcPersistence.logicalIdentity(for: attacker)
      ?? commander.npcPersistence.unboundSnapshots.first(where: { $0.value.actor == attacker })?.key
    let logical = original.map {
      NPCLogicalIdentity(firstActor: $0)
    }
    guard attacker == commander.flightSimulation.player || logical != nil else { return }
    guard registry.currentOrder < UInt64(Int64.max) - 1 else { throw NativeCrimboError.unavailable }
    registry.currentOrder += 1
    registry.lastCombatIncident = incident.id
    registry.threat = .init(
      attacker: attacker, logicalNPC: logical, incident: incident.id,
      physicalTime: incident.physicalTime)
    if resolution.unlawful, attacker == commander.flightSimulation.player, registry.betrayal == nil
    {
      registry.betrayal = .init(
        provider: registry.provider, member: member.identity,
        incident: incident, personSale: nil, order: registry.currentOrder)
    }
    try registry.validate()
    commander.savedCrimboState = registry
    nativeCrimboMotionSample = nil
  }

  /// G1's native law/threat owner calls only when this exact original threat genuinely ends.
  mutating func endNativeCrimboThreat(incident: UInt64) throws {
    guard var registry = commander.savedCrimboState, registry.threat?.incident == incident else {
      return
    }
    try registry.validate()
    registry.threat = nil
    commander.savedCrimboState = registry
    nativeCrimboMotionSample = nil
  }

  func nativeCrimboDefenceIntents() -> [NativeCrimboDefenceIntent] {
    guard let registry = commander.savedCrimboState,
      registry.world == commander.equipmentOwnerID,
      registry.spawnSequence < commander.flightSimulation.nextSpawn,
      (try? registry.validate()) != nil,
      let threat = registry.threat, let context = gameplayContext(),
      context.system == NativeCrimboRegistry.system
    else { return [] }
    let attacker: ActorIdentity?
    if let logical = threat.logicalNPC {
      attacker = commander.npcPersistence.binding(for: logical)
    } else {
      attacker = threat.attacker == context.player.identity ? context.player.identity : nil
    }
    guard let attacker,
      attacker == context.player.identity
        || context.actors.contains(where: { $0.identity == attacker && $0.energy > 0 })
    else { return [] }
    return registry.members.filter { $0.slot < 6 }.compactMap { member in
      guard let actor = registry.binding(of: member, ledger: commander.npcPersistence),
        !context.protection.protectedActors.contains(actor),
        let body = bodies.first(where: { $0.physical?.identity == actor }), body.energy > 1,
        body.missionActorID == nil, body.missionInstanceID == nil, body.scriptNPC == nil,
        body.physical?.catalogueShipID == member.catalogueShipID,
        body.physical?.npc?.role == member.role,
        !isEMPDisabled(body), body.physical?.npc?.resources?.canFire == true,
        body.physical?.laserCooldown == 0
      else { return nil }
      return .init(
        provider: registry.provider, member: member.identity, actor: actor,
        attacker: attacker, incident: threat.incident)
    }
  }

  /// Authenticates the original registry/ordinary ledger/body join before the generic stamp factory.
  /// Missing native core/care/relay/service/law joins remain unavailable; no capability is advertised.
  func nativeProviderMissionFacts(instance: UUID?) throws -> NativeProviderMissionFacts? {
    guard let registry = commander.savedCrimboState else { return nil }
    try registry.validate()
    guard registry.world == commander.equipmentOwnerID,
      let destination = registry.destination,
      instance.map({
        commander.scriptState.instances[$0]?.savedProviderContract?.provider == registry.provider
      }) ?? true
    else { return nil }
    let santa = registry.members[6]
    let binding: ActorIdentity?
    let available: NativeProviderAvailability
    switch santa.ownership {
    case .live(let logical):
      guard let actor = registry.binding(of: santa, ledger: commander.npcPersistence),
        commander.npcPersistence.logicalIdentity(for: actor) == logical.firstActor,
        let body = bodies.first(where: { $0.physical?.identity == actor }),
        body.missionActorID == nil, body.missionInstanceID == nil, body.scriptNPC == nil,
        let context = gameplayContext(),
        let observed = NPCPersistenceSnapshot.capture(
          body: body, pose: commander.flightSimulation.pose,
          physicalTime: context.physicalTime, protection: context.protection),
        NativeCrimboRegistry.matches(observed, member: santa)
      else { return nil }
      binding = actor
      available = registry.threat == nil ? .tracking : .defending
    case .pending, .parked:
      binding = nil
      available = .unloaded
    case .electrical:
      // The EMP owner must resolve its actual source/body/crew state before supplying facts.
      return nil
    case .terminal(_, let reason):
      binding = nil
      available = reason == .destroyed ? .destroyed : .ended
    }
    let source = NativeProviderMissionSource(
      provider: registry.provider, subject: santa.identity, currentBinding: binding,
      manifest: registry.manifest, origin: registry.origin, destination: destination,
      available: available, operationsReady: [], routeAvailable: false,
      playerThreat: registry.threat.map { $0.attacker == commander.flightSimulation.player }
        ?? false,
      currentOrder: registry.currentOrder, interval: nil, core: nil, personOperations: [],
      betrayal: registry.betrayal, relay: nil)
    return try resolveProviderMissionFacts(source)
  }
}
