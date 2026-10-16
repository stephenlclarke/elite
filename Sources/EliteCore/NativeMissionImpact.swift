import Foundation

enum NativeMissionAdjudication: Sendable, Equatable {
  case unknown, currentVisit, frozenLaunch
}

/// Actual effect facts for MC1's once-only event projection. This is not an authority input.
/// Only the native damage kernel in this file constructs receipts after applying an effect.
struct NativeMissionImpactReceipt: Sendable {
  let kind: AttackKind
  let target: GameplayHitTarget?
  let victimPart: String?
  let victimComponentID: UUID?
  let damage: Double
  let hullDestroyed: Bool
  let componentDestroyed: Bool
  let eventID: UInt64?
  let sourceInstanceID: UUID?
  let sourceActorID: UUID?
  let player: Bool
  let sourceComponentID: UUID?
  let targetMissionInstanceID: UUID?
  let targetMissionActorID: UUID?
  let originalOrigin: AttackOrigin?
  let adjudication: NativeMissionAdjudication
  let terminalShotID: UUID?
  var targetBodyID: Int? {
    if case .body(let id) = target { return id }
    return nil
  }

  fileprivate init(
    kind: AttackKind, target: GameplayHitTarget?, victimPart: String?, victimComponentID: UUID?,
    damage: Double, hullDestroyed: Bool, componentDestroyed: Bool, eventID: UInt64?,
    sourceInstanceID: UUID?, sourceActorID: UUID?, player: Bool, sourceComponentID: UUID?,
    targetMissionInstanceID: UUID?, targetMissionActorID: UUID?, originalOrigin: AttackOrigin?,
    adjudication: NativeMissionAdjudication, terminalShotID: UUID?
  ) {
    self.kind = kind
    self.target = target
    self.victimPart = victimPart
    self.victimComponentID = victimComponentID
    self.damage = damage
    self.hullDestroyed = hullDestroyed
    self.componentDestroyed = componentDestroyed
    self.eventID = eventID
    self.sourceInstanceID = sourceInstanceID
    self.sourceActorID = sourceActorID
    self.player = player
    self.sourceComponentID = sourceComponentID
    self.targetMissionInstanceID = targetMissionInstanceID
    self.targetMissionActorID = targetMissionActorID
    self.originalOrigin = originalOrigin
    self.adjudication = adjudication
    self.terminalShotID = terminalShotID
  }
}

enum NativeMissionImpactError: Error, Equatable, Sendable {
  case staleProof, unavailableAllocator, refusedLedger, refusedMining, invalidTarget
}

private struct MissionDamagePlan {
  var bodyIndex: Int?
  var body: SpaceBody?
  var outcome: AttackOutcome = .hit
  var hullDestroyed = false
  var componentDestroyed = false
  var playerHit: GameplayHit?
}

extension Game {
  /// Consume a live retained projectile capability. Every fallible check and ledger operation
  /// runs against pre-damage facts; the final commit also makes the projectile terminal.
  mutating func applyMissionImpact(_ proof: MissionNativeImpactProof) throws
    -> NativeMissionImpactReceipt
  {
    try validateMissionNativeImpactProof(proof)
    guard let context = gameplayContext(),
      let shotIndex = bodies.firstIndex(where: { $0 == proof.projectileBody }),
      let instance = commander.scriptState.instances[proof.sourceInstanceID],
      instance.revision == proof.instanceRevision
    else { throw NativeMissionImpactError.staleProof }
    var flight = commander.flightSimulation
    guard let eventID = flight.allocateIncident() else {
      throw NativeMissionImpactError.unavailableAllocator
    }
    var mining = commander.miningLedger
    let plan = try missionDamagePlan(
      hit: proof.hit, victimPart: proof.victimPart, component: proof.victimComponentID,
      damage: proof.damage, kind: proof.kind, laser: nil, eventID: eventID,
      mining: &mining, projectile: proof, incident: nil, context: context)
    var law = commander.crimeLedger
    let resolution = law.recordMissionReentryImpact(
      proof, eventID: eventID, outcome: plan.outcome, context: context)
    guard resolution.accepted else { throw NativeMissionImpactError.refusedLedger }
    if let intercepted = plan.body?.physical?.attackOrigin?.emissionID,
      plan.outcome == .ordnanceInterception
    {
      law.finishEmission(intercepted)
    }
    // No failure or suspension is permitted after this point. Keep the original historical
    // origin unchanged; unknown attribution still produces the actual physical effect.
    commander.flightSimulation = flight
    commander.miningLedger = mining
    commander.crimeLedger = law
    commitMissionDamage(plan, damage: proof.damage, origin: proof.originalOrigin, eventID: eventID)
    bodies[shotIndex].energy = 0
    applyNativeCrimeResolution(
      resolution, target: proof.hit.target, attacker: proof.currentSource, context: context)
    return missionImpactReceipt(
      kind: proof.kind, hit: proof.hit, part: proof.victimPart,
      component: proof.victimComponentID, damage: proof.damage, plan: plan, eventID: eventID,
      sourceInstance: proof.sourceInstanceID, sourceActor: proof.sourceActorID,
      sourceComponent: proof.sourceComponentID, origin: proof.originalOrigin,
      adjudication: proof.attribution == .frozenLaunch ? .frozenLaunch : .unknown,
      terminalShot: proof.shotID, player: false)
  }

  /// Instant mission lasers use a real current-visit emission and the ordinary crime ledger.
  /// The watermark is published with the damage, so replay cannot allocate a second event.
  mutating func applyMissionImpact(_ proof: MissionNativeLaserProof) throws
    -> NativeMissionImpactReceipt
  {
    try validateMissionNativeLaserProof(proof)
    guard let context = gameplayContext(),
      proof.origin.emissionID > consumedMissionLaserEmission,
      proof.origin.emissionID < commander.flightSimulation.nextEmission,
      proof.origin.owner.system == context.system, proof.origin.owner.visit == context.visit,
      proof.origin.emittedAt == context.physicalTime
    else { throw NativeMissionImpactError.staleProof }
    var flight = commander.flightSimulation
    guard let eventID = flight.allocateIncident() else {
      throw NativeMissionImpactError.unavailableAllocator
    }
    var mining = commander.miningLedger
    let preliminary = missionCombatIncident(
      eventID: eventID, origin: proof.origin, kind: .laser, hit: proof.hit,
      outcome: .hit, part: proof.victimPart, context: context)
    var plan = MissionDamagePlan()
    if let hit = proof.hit {
      plan = try missionDamagePlan(
        hit: hit, victimPart: proof.victimPart, component: proof.victimComponentID,
        damage: proof.damage, kind: .laser, laser: nil, eventID: eventID,
        mining: &mining, projectile: nil, incident: preliminary, context: context)
    } else {
      plan.outcome = .discharge
    }
    let incident = missionCombatIncident(
      eventID: eventID, origin: proof.origin, kind: .laser, hit: proof.hit,
      outcome: plan.outcome, part: proof.victimPart, context: context)
    var law = commander.crimeLedger
    let emissionPosition = flight.pose.systemPoint(proof.weapon.muzzle)
    let resolution = law.record(
      incident, context: context, emissionPosition: emissionPosition,
      missionEntitlement: combatMissionEntitlement(
        proof.hit?.target, owner: proof.origin.owner, context: context))
    guard resolution.accepted else { throw NativeMissionImpactError.refusedLedger }
    if let intercepted = plan.body?.physical?.attackOrigin?.emissionID,
      plan.outcome == .ordnanceInterception
    {
      law.finishEmission(intercepted)
    }
    commander.flightSimulation = flight
    commander.miningLedger = mining
    commander.crimeLedger = law
    consumedMissionLaserEmission = proof.origin.emissionID
    commitMissionDamage(plan, damage: proof.damage, origin: proof.origin, eventID: eventID)
    applyNativeCrimeResolution(
      resolution, target: proof.hit?.target, attacker: proof.origin.owner, context: context)
    return missionImpactReceipt(
      kind: .laser, hit: proof.hit, part: proof.victimPart, component: proof.victimComponentID,
      damage: proof.hit == nil ? 0 : proof.damage, plan: plan, eventID: eventID,
      sourceInstance: proof.sourceInstanceID, sourceActor: proof.sourceActorID,
      sourceComponent: proof.sourceComponentID, origin: proof.origin,
      adjudication: .currentVisit, terminalShot: nil, player: false)
  }

  private func missionDamagePlan(
    hit: GameplayHit, victimPart: String?, component: UUID?, damage: Double,
    kind: AttackKind, laser: LaserKind?, eventID: UInt64, mining: inout MiningLedger,
    projectile: MissionNativeImpactProof?, incident: CombatIncident?, context: EncounterContext
  ) throws -> MissionDamagePlan {
    guard damage.isFinite, damage > 0, hit.point.finite, hit.distance.isFinite,
      hit.distance >= 0, (victimPart == nil) == (component == nil)
    else { throw NativeMissionImpactError.invalidTarget }
    var plan = MissionDamagePlan()
    switch hit.target {
    case .player:
      guard energy.isFinite, energy > 0, victimPart == nil else {
        throw NativeMissionImpactError.invalidTarget
      }
      plan.playerHit = hit
      let shield = hit.point.z >= 0 ? frontShield : rearShield
      plan.hullDestroyed = energy - max(0, damage - shield) <= 0
    case .celestial:
      guard victimPart == nil else { throw NativeMissionImpactError.invalidTarget }
    case .body(let id):
      guard let index = bodies.firstIndex(where: { $0.id == id }),
        bodies.lazy.filter({ $0.id == id }).count == 1,
        bodies[index].energy.isFinite, bodies[index].energy > 0
      else { throw NativeMissionImpactError.invalidTarget }
      var body = bodies[index]
      if let part = victimPart, let component {
        _ = try currentMissionNativeBinding(bodyID: id)
        guard var state = body.scriptNPC?.components[part], state.identity == component,
          state.energy.isFinite, state.energy > 0
        else { throw NativeMissionImpactError.invalidTarget }
        state.energy = max(0, state.energy - damage)
        plan.componentDestroyed = state.energy == 0
        body.scriptNPC?.components[part] = state
      } else if body.hull == .missile {
        body.energy = 0
        plan.outcome = .ordnanceInterception
      } else if body.scriptNPC != nil {
        // Authored condition applies only to an actual retained, installed and currently bound
        // profiled actor. Native hull immunity remains intact for every other body.
        _ = try currentMissionNativeBinding(bodyID: id)
        body.energy = max(0, body.energy - damage)
      } else if body.hull != .station,
        !(body.hull == .constrictor
          && (kind == .plasma || (kind == .laser && laser != .military && laser != .naval)))
      {
        if let identity = body.physical?.rock,
          let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == identity })
        {
          let result: MiningHitResult
          if let projectile {
            result = mining.hit(rock: rock, proof: projectile, eventID: eventID, context: context)
          } else if let incident {
            result = mining.hit(rock: rock, incident: incident, damage: damage)
          } else {
            throw NativeMissionImpactError.invalidTarget
          }
          switch result {
          case .damaged(let remaining): body.energy = remaining
          case .extracted, .destroyed: body.energy = 0
          case .ignored: break
          case .capacityRefused: throw NativeMissionImpactError.refusedMining
          }
        } else {
          var remaining = damage
          if kind != .bomb, var resources = body.physical?.npc?.resources {
            let forward = body.modelVector(.init(0, 0, 1))
            remaining = resources.absorb(
              damage, front: (hit.point - body.position).dot(forward) >= 0)
            body.physical?.npc?.resources = resources
          }
          body.energy = max(0, body.energy - remaining)
        }
      }
      plan.bodyIndex = index
      plan.body = body
      plan.hullDestroyed = body.energy == 0
    }
    if plan.outcome != .ordnanceInterception {
      if plan.hullDestroyed { plan.outcome = .destruction }
      else if plan.componentDestroyed { plan.outcome = .componentDestruction }
    }
    return plan
  }

  private mutating func commitMissionDamage(
    _ plan: MissionDamagePlan, damage: Double, origin: AttackOrigin?, eventID: UInt64
  ) {
    if let hit = plan.playerHit { applyDamage(damage, front: hit.point.z >= 0) }
    if let index = plan.bodyIndex, var body = plan.body {
      if plan.hullDestroyed {
        body.physical?.deathOrigin = origin
        body.physical?.deathIncidentID = eventID
        body.destroyedByPlayer = origin?.owner == commander.flightSimulation.player
      }
      bodies[index] = body
    }
  }

  private func missionCombatIncident(
    eventID: UInt64, origin: AttackOrigin, kind: AttackKind, hit: GameplayHit?,
    outcome: AttackOutcome, part: String?, context: EncounterContext
  ) -> CombatIncident {
    let victim: ActorSnapshot?
    switch hit?.target {
    case .player: victim = context.player
    case .body(let id):
      let identity = bodies.first(where: { $0.id == id })?.physical?.identity
      victim = context.actors.first(where: { $0.identity == identity })
    case .celestial, nil: victim = nil
    }
    return .init(
      id: eventID, physicalTime: context.physicalTime, origin: origin, victim: victim?.identity,
      kind: kind, outcome: outcome,
      position: commander.flightSimulation.pose.systemPoint(hit?.point ?? .init(0, 0, 0)),
      victimLegalBeforeAttack: victim?.legal, firstAggressor: victim?.npc?.firstAggressor,
      victimRole: victim?.npc?.role, victimIsStation: victim?.hull == .station,
      laser: nil, mount: nil, victimPart: part)
  }

  private func missionImpactReceipt(
    kind: AttackKind, hit: GameplayHit?, part: String?, component: UUID?, damage: Double,
    plan: MissionDamagePlan, eventID: UInt64, sourceInstance: UUID?, sourceActor: UUID?,
    sourceComponent: UUID?, origin: AttackOrigin?, adjudication: NativeMissionAdjudication,
    terminalShot: UUID?, player: Bool
  ) -> NativeMissionImpactReceipt {
    .init(
      kind: kind, target: hit?.target, victimPart: part, victimComponentID: component,
      damage: damage, hullDestroyed: plan.hullDestroyed,
      componentDestroyed: plan.componentDestroyed, eventID: eventID,
      sourceInstanceID: sourceInstance, sourceActorID: sourceActor, player: player,
      sourceComponentID: sourceComponent, targetMissionInstanceID: plan.body?.missionInstanceID,
      targetMissionActorID: plan.body?.missionActorID, originalOrigin: origin,
      adjudication: adjudication, terminalShotID: terminalShot)
  }
}
