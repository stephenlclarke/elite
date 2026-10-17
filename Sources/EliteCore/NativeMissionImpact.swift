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
  let damageAdmitted: Bool
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
    damage: Double, damageAdmitted: Bool, hullDestroyed: Bool, componentDestroyed: Bool,
    eventID: UInt64?,
    sourceInstanceID: UUID?, sourceActorID: UUID?, player: Bool, sourceComponentID: UUID?,
    targetMissionInstanceID: UUID?, targetMissionActorID: UUID?, originalOrigin: AttackOrigin?,
    adjudication: NativeMissionAdjudication, terminalShotID: UUID?
  ) {
    self.kind = kind
    self.target = target
    self.victimPart = victimPart
    self.victimComponentID = victimComponentID
    self.damage = damage
    self.damageAdmitted = damageAdmitted
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
  var damageAdmitted = false
}

extension Game {
  /// Plan the exact target and firing events before the gun's real emission allocator runs.
  /// The same private damage policy stages the preview and the later physical commit.
  func preflightMissionNativeLaser(_ query: MissionNativeLaserQuery) throws
    -> ScriptMissionEventCapacityPlan
  {
    guard let context = gameplayContext(), context == query.context,
      let descriptor = currentMissionActorDescriptor(bodyID: query.source.bodyID),
      let source = bodies.first(where: { $0.id == query.source.bodyID })
    else { throw NativeMissionImpactError.staleProof }
    try MissionNativeBridge.validateBinding(
      query.source, descriptor: descriptor, body: source, context: context)
    let current = try nearestMissionCollision(
      from: query.weapon.muzzle, direction: query.weapon.direction,
      range: query.weapon.range, radius: 0, excludingBodyIDs: [query.source.bodyID],
      includePlayer: true)
    guard current == query.contact else { throw NativeMissionImpactError.staleProof }
    return try preflightCurrentMissionContact(
      query.contact, owner: query.source.nativeActor, sourcePart: query.sourceComponentID,
      damage: query.weapon.damage, laser: nil, mount: nil, context: context,
      sourceWeaponInstanceID: query.source.instanceID)
  }

  /// Native player/NPC callers use their real current emitter and weapon statistics. This is
  /// readonly planning, never a damage capability or a replacement persisted attack origin.
  func preflightNativeMissionContact(
    _ contact: MissionCollisionContact, owner: ActorIdentity, damage: Double,
    laser: LaserKind?, mount: LaserMount?
  ) throws -> ScriptMissionEventCapacityPlan {
    guard let context = gameplayContext(),
      contact.selectedTargetBody.map({ selected in
        bodies.filter({ $0.id == selected.id }) == [selected]
      }) == true
    else { throw NativeMissionImpactError.staleProof }
    return try preflightCurrentMissionContact(
      contact, owner: owner, sourcePart: nil, damage: damage, laser: laser, mount: mount,
      context: context, sourceWeaponInstanceID: nil)
  }

  private func preflightCurrentMissionContact(
    _ contact: MissionCollisionContact?, owner: ActorIdentity, sourcePart: UUID?,
    damage: Double, laser: LaserKind?, mount: LaserMount?, context: EncounterContext,
    sourceWeaponInstanceID: UUID?
  ) throws -> ScriptMissionEventCapacityPlan {
    let emitter =
      owner == context.player.identity
      ? context.player : context.actors.first(where: { $0.identity == owner })
    guard let emitter, emitter.energy > 0,
      owner.system == context.system, owner.visit == context.visit
    else { throw NativeMissionImpactError.staleProof }
    // These are the actual next native allocator values staged in a small value copy. No
    // emission, incident, body, law or event is published during this capacity preview.
    var flight = commander.flightSimulation
    guard let emission = flight.allocateEmission(), let eventID = flight.allocateIncident(),
      flight.valid
    else { throw NativeMissionImpactError.unavailableAllocator }
    let origin = AttackOrigin(
      emissionID: emission, owner: owner, emittedAt: context.physicalTime,
      ownerLegalAtEmission: emitter.legal, sourcePart: sourcePart?.uuidString)
    var plan = MissionDamagePlan()
    if let contact {
      var mining = commander.miningLedger
      let incident = missionCombatIncident(
        eventID: eventID, origin: origin, kind: .laser, hit: contact.hit, outcome: .hit,
        part: contact.victimPart, context: context, laser: laser, mount: mount)
      plan = try missionDamagePlan(
        hit: contact.hit, victimPart: contact.victimPart, component: contact.componentUUID,
        damage: damage, kind: .laser, laser: laser, eventID: eventID, mining: &mining,
        projectile: nil, incident: incident, context: context)
    }
    return try missionEventCapacity(
      plan, damage: damage, part: contact?.victimPart, component: contact?.componentUUID,
      sourceWeaponInstanceID: sourceWeaponInstanceID)
  }

  /// Consume a live retained projectile capability. Every fallible check and ledger operation
  /// runs against pre-damage facts; the final commit also makes the projectile terminal.
  mutating func applyMissionImpact(_ proof: MissionNativeImpactProof) throws
    -> NativeMissionImpactReceipt
  {
    try validateMissionNativeImpactProof(proof)
    return try applyValidatedMissionProjectileImpact(proof)
  }

  /// Enter staging only after the full current-scene proof validation has returned.
  private mutating func applyValidatedMissionProjectileImpact(_ proof: MissionNativeImpactProof)
    throws -> NativeMissionImpactReceipt
  {
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
    _ = try missionEventCapacity(
      plan, damage: proof.damage, part: proof.victimPart, component: proof.victimComponentID)
    var law = commander.crimeLedger
    let resolution = law.recordMissionReentryImpact(
      proof, eventID: eventID, outcome: plan.outcome, context: context)
    guard resolution.accepted else { throw NativeMissionImpactError.refusedLedger }
    if let intercepted = interceptedNativeEmission(plan, context: context) {
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
    _ = try missionEventCapacity(
      plan, damage: proof.damage, part: proof.victimPart, component: proof.victimComponentID)
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
    if let intercepted = interceptedNativeEmission(plan, context: context) {
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

  /// Actual native weapon callers retain their ordinary origin and weapon statistics. A sealed
  /// custom-geometry contact uses this same damage plan for authored hulls and components.
  mutating func applyNativeMissionContact(
    _ contact: MissionCollisionContact, origin: AttackOrigin, damage: Double,
    laser: LaserKind?, mount: LaserMount?, emissionPosition: Vector3
  ) throws -> NativeMissionImpactReceipt {
    guard let target = contact.selectedTargetBody, target.scriptNPC != nil,
      bodies.filter({ $0.id == target.id }) == [target],
      let context = gameplayContext(),
      origin.owner.system == context.system, origin.owner.visit == context.visit,
      origin.emittedAt == context.physicalTime, emissionPosition.finite,
      origin.emissionID > consumedMissionLaserEmission,
      origin.emissionID < commander.flightSimulation.nextEmission,
      origin.owner == context.player.identity
        || context.actors.contains(where: { $0.identity == origin.owner && $0.energy > 0 })
    else { throw NativeMissionImpactError.staleProof }
    var flight = commander.flightSimulation
    guard let eventID = flight.allocateIncident() else {
      throw NativeMissionImpactError.unavailableAllocator
    }
    var mining = commander.miningLedger
    let preliminary = missionCombatIncident(
      eventID: eventID, origin: origin, kind: .laser, hit: contact.hit, outcome: .hit,
      part: contact.victimPart, context: context, laser: laser, mount: mount)
    let plan = try missionDamagePlan(
      hit: contact.hit, victimPart: contact.victimPart, component: contact.componentUUID,
      damage: damage, kind: .laser, laser: laser, eventID: eventID, mining: &mining,
      projectile: nil, incident: preliminary, context: context)
    _ = try missionEventCapacity(
      plan, damage: damage, part: contact.victimPart, component: contact.componentUUID)
    let incident = missionCombatIncident(
      eventID: eventID, origin: origin, kind: .laser, hit: contact.hit, outcome: plan.outcome,
      part: contact.victimPart, context: context, laser: laser, mount: mount)
    var law = commander.crimeLedger
    let resolution = law.record(
      incident, context: context, emissionPosition: emissionPosition,
      missionEntitlement: combatMissionEntitlement(
        contact.hit.target, owner: origin.owner, context: context))
    guard resolution.accepted else { throw NativeMissionImpactError.refusedLedger }
    commander.flightSimulation = flight
    commander.miningLedger = mining
    commander.crimeLedger = law
    consumedMissionLaserEmission = origin.emissionID
    commitMissionDamage(plan, damage: damage, origin: origin, eventID: eventID)
    applyNativeCrimeResolution(
      resolution, target: contact.hit.target, attacker: origin.owner, context: context)
    let source = bodies.first(where: { $0.physical?.identity == origin.owner })
    return missionImpactReceipt(
      kind: .laser, hit: contact.hit, part: contact.victimPart,
      component: contact.componentUUID, damage: damage, plan: plan, eventID: eventID,
      sourceInstance: source?.missionInstanceID, sourceActor: source?.missionActorID,
      sourceComponent: nil, origin: origin, adjudication: .currentVisit, terminalShot: nil,
      player: origin.owner == context.player.identity)
  }

  /// Native missiles retain their genuine original emission; no laser watermark is consulted.
  mutating func applyMissionImpact(_ proof: NativeMissionOrdnanceImpactProof) throws -> (
    receipt: NativeMissionImpactReceipt, incident: CombatIncident
  ) {
    try validateNativeMissionOrdnanceImpactProof(proof)
    guard let target = proof.contact.selectedTargetBody, target.scriptNPC != nil,
      let context = gameplayContext()
    else { throw NativeMissionImpactError.staleProof }
    let contact = proof.contact
    let origin = proof.ordnance.origin
    let kind = proof.ordnance.profile.attackKind
    var flight = commander.flightSimulation
    guard let eventID = flight.allocateIncident() else {
      throw NativeMissionImpactError.unavailableAllocator
    }
    var mining = commander.miningLedger
    let preliminary = missionCombatIncident(
      eventID: eventID, origin: origin, kind: kind, hit: contact.hit, outcome: .hit,
      part: contact.victimPart, context: context)
    let plan = try missionDamagePlan(
      hit: contact.hit, victimPart: contact.victimPart, component: contact.componentUUID,
      damage: proof.damage, kind: kind, laser: nil, eventID: eventID, mining: &mining,
      projectile: nil, incident: preliminary, context: context)
    _ = try missionEventCapacity(
      plan, damage: proof.damage, part: contact.victimPart, component: contact.componentUUID)
    let incident = missionCombatIncident(
      eventID: eventID, origin: origin, kind: kind, hit: contact.hit, outcome: plan.outcome,
      part: contact.victimPart, context: context)
    var law = commander.crimeLedger
    let resolution = law.record(
      incident, context: context, emissionPosition: proof.ordnance.emissionPosition,
      missionEntitlement: combatMissionEntitlement(
        contact.hit.target, owner: origin.owner, context: context))
    guard resolution.accepted else { throw NativeMissionImpactError.refusedLedger }
    commander.flightSimulation = flight
    commander.miningLedger = mining
    commander.crimeLedger = law
    commitMissionDamage(plan, damage: proof.damage, origin: origin, eventID: eventID)
    applyNativeCrimeResolution(
      resolution, target: contact.hit.target, attacker: origin.owner, context: context)
    let source = bodies.first(where: { $0.physical?.identity == origin.owner })
    return (
      missionImpactReceipt(
        kind: kind, hit: contact.hit, part: contact.victimPart,
        component: contact.componentUUID, damage: proof.damage, plan: plan, eventID: eventID,
        sourceInstance: source?.missionInstanceID, sourceActor: source?.missionActorID,
        sourceComponent: nil, origin: origin, adjudication: .currentVisit, terminalShot: nil,
        player: origin.owner == context.player.identity), incident
    )
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
      plan.damageAdmitted = true
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
        try validateMissionDamageTarget(body, context: context)
        guard var state = body.scriptNPC?.components[part], state.identity == component,
          state.energy.isFinite, state.energy > 0
        else { throw NativeMissionImpactError.invalidTarget }
        state.energy = max(0, state.energy - damage)
        plan.componentDestroyed = state.energy == 0
        body.scriptNPC?.components[part] = state
        plan.damageAdmitted = true
      } else if body.hull == .missile {
        body.energy = 0
        plan.outcome = .ordnanceInterception
        plan.damageAdmitted = true
      } else if body.scriptNPC != nil {
        // Authored condition applies only to an actual retained, installed and currently bound
        // profiled actor. Native hull immunity remains intact for every other body.
        try validateMissionDamageTarget(body, context: context)
        body.energy = max(0, body.energy - damage)
        plan.damageAdmitted = true
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
          case .damaged(let remaining):
            body.energy = remaining
            plan.damageAdmitted = true
          case .extracted, .destroyed:
            body.energy = 0
            plan.damageAdmitted = true
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
          plan.damageAdmitted = true
        }
      }
      plan.bodyIndex = index
      plan.body = body
      plan.hullDestroyed = body.energy == 0
    }
    if plan.outcome != .ordnanceInterception {
      if plan.hullDestroyed {
        plan.outcome = .destruction
      } else if plan.componentDestroyed {
        plan.outcome = .componentDestruction
      }
    }
    return plan
  }

  private func validateMissionDamageTarget(_ body: SpaceBody, context: EncounterContext) throws {
    guard let descriptor = currentMissionActorDescriptor(bodyID: body.id) else {
      throw NativeMissionImpactError.invalidTarget
    }
    _ = try MissionNativeBridge.bindActor(descriptor: descriptor, body: body, context: context)
  }

  private func missionEventCapacity(
    _ plan: MissionDamagePlan, damage: Double, part: String?, component: UUID?,
    sourceWeaponInstanceID: UUID? = nil
  ) throws -> ScriptMissionEventCapacityPlan {
    try planScriptMissionImpactEvents(
      target: plan.body, damage: damage, damageAdmitted: plan.damageAdmitted,
      victimPart: part, victimComponentID: component,
      componentDestroyed: plan.componentDestroyed, hullDestroyed: plan.hullDestroyed,
      sourceWeaponInstanceID: sourceWeaponInstanceID)
  }

  private func interceptedNativeEmission(_ plan: MissionDamagePlan, context: EncounterContext)
    -> UInt64?
  {
    guard plan.outcome == .ordnanceInterception, let body = plan.body else { return nil }
    return currentNativeOrdnanceEmission(body, context: context)
  }

  /// Historical Script shot archives never retire an unrelated live native missile threat.
  /// Both the ordinary hit path and mission kernel use the actual current ordnance binding.
  func currentNativeOrdnanceEmission(_ body: SpaceBody, context: EncounterContext) -> UInt64? {
    guard body.scriptShot == nil, let physical = body.physical,
      let ordnance = physical.ordnance, ordnance.valid, ordnance.termination == nil,
      physical.identity == ordnance.origin.ordnance,
      physical.attackOrigin == ordnance.origin,
      ordnance.origin.owner.system == context.system,
      ordnance.origin.owner.visit == context.visit,
      ordnance.origin.emittedAt <= context.physicalTime
    else { return nil }
    return ordnance.origin.emissionID
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
    outcome: AttackOutcome, part: String?, context: EncounterContext,
    laser: LaserKind? = nil, mount: LaserMount? = nil
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
      laser: laser, mount: mount, victimPart: part)
  }

  private func missionImpactReceipt(
    kind: AttackKind, hit: GameplayHit?, part: String?, component: UUID?, damage: Double,
    plan: MissionDamagePlan, eventID: UInt64, sourceInstance: UUID?, sourceActor: UUID?,
    sourceComponent: UUID?, origin: AttackOrigin?, adjudication: NativeMissionAdjudication,
    terminalShot: UUID?, player: Bool
  ) -> NativeMissionImpactReceipt {
    .init(
      kind: kind, target: hit?.target, victimPart: part, victimComponentID: component,
      damage: damage, damageAdmitted: plan.damageAdmitted, hullDestroyed: plan.hullDestroyed,
      componentDestroyed: plan.componentDestroyed, eventID: eventID,
      sourceInstanceID: sourceInstance, sourceActorID: sourceActor, player: player,
      sourceComponentID: sourceComponent, targetMissionInstanceID: plan.body?.missionInstanceID,
      targetMissionActorID: plan.body?.missionActorID, originalOrigin: origin,
      adjudication: adjudication, terminalShotID: terminalShot)
  }
}
