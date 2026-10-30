import Foundation

private final class PreparedGameplayMissile {
  let index: Int
  let owner: ActorIdentity
  let emissionPosition: Vector3
  let origin: AttackOrigin
  let state: OrdnanceState

  init(
    index: Int, owner: ActorIdentity, emissionPosition: Vector3,
    origin: AttackOrigin, state: OrdnanceState
  ) {
    self.index = index
    self.owner = owner
    self.emissionPosition = emissionPosition
    self.origin = origin
    self.state = state
  }
}

extension Game {
  /// Admission, ownership and launch evidence are one transaction. A refused launch leaves
  /// ammunition, identities, cash and target state unchanged.
  @inline(never)
  mutating func launchGameplayMissile(targetBodyID: Int) -> Bool {
    guard !playerEMPDisabled else { return false }
    var candidate = self
    do {
      let ammunition = try candidate.prepareGameplayMissileConsumption()
      guard candidate.commander.valid,
        candidate.admitGameplayMissile(
          ownerBodyID: nil, targetBodyID: targetBodyID,
          profile: ammunition.node.flatMap { AlienMissileDefinition.profile(for: $0) }
            ?? .standardMissile,
          playerAmmunition: ammunition.source), candidate.commander.valid
      else { return false }
    } catch {
      return false
    }
    self = candidate
    return true
  }

  @inline(never)
  private mutating func prepareGameplayMissileConsumption() throws -> (
    node: EquipmentNodeID?, source: PlayerAmmunitionSource
  ) {
    try commander.prepareEquipment()
    guard let inventory = commander.equipmentInventory else {
      throw CommanderEquipmentError.incompleteState
    }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.nativePerformance)
    let obligations = try commander.equipmentIssueObligations()
    let quote = try StandardAmmunitionTransactions.quoteConsumption(
      unlimited: commander.unlimitedMissiles, inventory: inventory,
      context: context, obligations: obligations)
    let application = try StandardAmmunitionTransactions.applyConsumption(
      quote: quote, inventory: inventory, context: context, obligations: obligations)
    commander.savedEquipmentInventory = application.inventory
    commander.mirrorFittedEquipment()
    if let removed = application.removedItem { try stageGearConsumption(removed) }
    return (application.removedItem?.node, application.source)
  }

  mutating func launchGameplayNPCMissile(bodyID: Int) -> Bool {
    var candidate = self
    guard let ownerIndex = candidate.bodies.firstIndex(where: { $0.id == bodyID }),
      !candidate.isEMPDisabled(candidate.bodies[ownerIndex]),
      candidate.bodies[ownerIndex].missiles > 0,
      candidate.admitGameplayMissile(ownerBodyID: bodyID, targetBodyID: nil)
    else {
      return false
    }
    candidate.bodies[ownerIndex].missiles -= 1
    self = candidate
    return true
  }

  @inline(never)
  private mutating func admitGameplayMissile(
    ownerBodyID: Int?, targetBodyID: Int?, profile: OrdnanceProfile = .standardMissile,
    playerAmmunition: PlayerAmmunitionSource? = nil
  ) -> Bool {
    guard
      let prepared = prepareAdmittedGameplayMissile(
        ownerBodyID: ownerBodyID, targetBodyID: targetBodyID, profile: profile,
        playerAmmunition: playerAmmunition)
    else { return false }
    guard
      nativePracticeMissileLaunchAllowed(targetBodyID: targetBodyID, owner: prepared.owner)
        || recordCombat(
          origin: prepared.origin, kind: .missile, outcome: .targetedLaunch,
          target: targetBodyID.map(GameplayHitTarget.body) ?? .player,
          worldPosition: prepared.emissionPosition,
          emissionPosition: prepared.emissionPosition) != nil
    else { return false }

    bodies[prepared.index].physical?.attackOrigin = prepared.origin
    bodies[prepared.index].physical?.emissionPosition = prepared.emissionPosition
    bodies[prepared.index].physical?.ordnance = prepared.state
    bodies[prepared.index].physical?.velocity = prepared.state.velocity
    bodies[prepared.index].rotationRate = 0
    bodies[prepared.index].playerMissileTarget = targetBodyID
    bodies[prepared.index].enemyMissile = ownerBodyID != nil
    bodies[prepared.index].hostile = ownerBodyID != nil
    bodies[prepared.index].missileSourceID = ownerBodyID
    observeSafeGunneryMissileLaunch(prepared.origin)
    if prepared.origin.owner == commander.flightSimulation.player {
      observeDefensiveFlightDischarge(emission: prepared.origin.emissionID)
    }
    return true
  }

  @inline(never)
  private mutating func prepareAdmittedGameplayMissile(
    ownerBodyID: Int?, targetBodyID: Int?, profile: OrdnanceProfile,
    playerAmmunition: PlayerAmmunitionSource?
  ) -> PreparedGameplayMissile? {
    if let ownerBodyID {
      guard let body = bodies.first(where: { $0.id == ownerBodyID }), !isEMPDisabled(body)
      else { return nil }
    }
    ensurePhysicalActors()
    guard let context = gameplayContext(), energy > 0,
      let owner = missileActor(bodyID: ownerBodyID, context: context), owner.energy > 0,
      let target = missileActor(bodyID: targetBodyID, context: context), target.energy > 0,
      target.identity != owner.identity,
      let sequence = commander.flightSimulation.allocateSpawn()
    else { return nil }
    let direction =
      ownerBodyID == nil ? owner.orientation.z : (target.position - owner.position).unit
    guard direction.length > 0 else { return nil }
    let position = owner.position + direction * 24
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .ordnance),
      population: .projectile, hull: .missile, position: position,
      orientation: owner.orientation, velocity: .init(0, 0, 0), npc: nil,
      rock: nil, payload: nil,
      priority: context.protection.protectedActors.contains(owner.identity) ? .mission : .ordinary)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: true)], intents: []))
    guard let actor = receipts.first?.actor,
      let index = bodies.firstIndex(where: { $0.physical?.identity == actor }),
      let origin = makeAttackOrigin(
        owner: owner.identity, ordnance: actor,
        playerAmmunition: playerAmmunition),
      let state = OrdnanceState(
        profile: profile, origin: origin,
        target: target.identity, position: position, direction: direction,
        emissionPosition: owner.position)
    else { return nil }
    return PreparedGameplayMissile(
      index: index, owner: owner.identity, emissionPosition: owner.position, origin: origin,
      state: state)
  }

  private func missileActor(bodyID: Int?, context: EncounterContext) -> ActorSnapshot? {
    guard let bodyID else { return context.player }
    guard let identity = bodies.first(where: { $0.id == bodyID })?.physical?.identity else {
      return nil
    }
    return context.actors.first { $0.identity == identity }
  }

  /// An activation is identified by its actual emitter and one monotonic allocator sequence.
  /// Keeping the same identity for every field update prevents repeatedly stripping resistance.
  @discardableResult
  mutating func activateOrdnanceECM(emitter: ActorIdentity) -> Bool {
    guard let context = gameplayContext(),
      emitter == context.player.identity
        || context.actors.contains(where: { $0.identity == emitter && $0.energy > 0 }),
      let sequence = commander.flightSimulation.allocateSpawn()
    else { return false }
    let activation = ECMActivationIdentity(emitter: emitter, sequence: sequence)
    activeECMActivation = activation
    cancelEMPCharge(for: activation)
    return true
  }

  mutating func advanceGameplayOrdnance(allowEnemyECM: Bool = true) {
    let ids = bodies.filter { $0.physical?.ordnance != nil }.map(\.id)
    for id in ids {
      guard let index = bodies.firstIndex(where: { $0.id == id }),
        var state = bodies[index].physical?.ordnance, let context = gameplayContext()
      else { continue }
      let missile = bodies[index]
      let pulses = ecmFrames > 0 ? activeECMActivation.map { [$0] } ?? [] : []
      var result = advanceOrdnance(bodyID: id, state: &state, context: context, activeECM: pulses)
      // Original missile tactics test impact before the target's 16/256 ECM chance.
      if allowEnemyECM, state.termination == nil, state.profile == .standardMissile,
        ecmFrames == 0,
        let target = bodies.first(where: {
          $0.physical?.identity == state.target && $0.energy > 0 && $0.ecmEnabled
        }), randomByte() < 16,
        let emitter = target.physical?.identity, activateOrdnanceECM(emitter: emitter),
        let pulse = activeECMActivation
      {
        ecmFrames = 32
        enemyECMSource = target.id
        notify("ENEMY ECM")
        result = advanceOrdnance(bodyID: id, state: &state, context: context, activeECM: [pulse])
      }
      bodies[index].physical?.ordnance = state
      if result.endedNow, result.termination == .ecm,
        activeECMActivation?.emitter == commander.flightSimulation.player,
        ecmControl.ownFieldActive
      {
        ecmControl.recordDestruction()
        confirmRetaliation(missile)
      }
    }
  }
}
