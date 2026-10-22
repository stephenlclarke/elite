import Foundation
import OSLog

private let gameplayCombatLogger = Logger(subsystem: "io.xyzzy.elite", category: "GameplayCombat")

extension Game {
  /// Capture the emitter once. Projectiles retain this origin even if it disappears.
  mutating func makeAttackOrigin(
    owner: ActorIdentity, ordnance: ActorIdentity? = nil, sourcePart: String? = nil,
    playerAmmunition: PlayerAmmunitionSource? = nil
  ) -> AttackOrigin? {
    ensurePhysicalActors()
    guard let context = gameplayContext(),
      let actor = combatActor(owner, context: context), actor.energy > 0,
      let emission = commander.flightSimulation.allocateEmission()
    else { return nil }
    return .init(
      emissionID: emission, owner: owner, ordnance: ordnance,
      emittedAt: context.physicalTime, ownerLegalAtEmission: actor.legal, sourcePart: sourcePart,
      playerAmmunition: playerAmmunition)
  }

  /// Record before changing health or hostility so legal/bounty evidence stays original.
  @discardableResult
  mutating func recordCombat(
    origin: AttackOrigin, kind: AttackKind, outcome: AttackOutcome,
    target: GameplayHitTarget?, worldPosition: Vector3, emissionPosition: Vector3? = nil,
    laser: LaserKind? = nil, mount: LaserMount? = nil, victimPart: String? = nil
  ) -> CombatIncident? {
    if case .body(let id) = target,
      let body = bodies.first(where: { $0.id == id }), nativePracticeReservation(body) != nil
    {
      return nil
    }
    ensurePhysicalActors()
    guard let context = gameplayContext() else { return nil }
    return recordCombatWithEntitlement(
      origin: origin, kind: kind, outcome: outcome, target: target,
      worldPosition: worldPosition, emissionPosition: emissionPosition, laser: laser, mount: mount,
      victimPart: victimPart, context: context,
      entitlement: combatMissionEntitlement(target, owner: origin.owner, context: context))
  }

  /// The only caller carrying an entitlement across mutation is this file's uninterrupted
  /// native body-hit/death path. The live-only retained factory remains unchanged.
  private mutating func recordCombatWithEntitlement(
    origin: AttackOrigin, kind: AttackKind, outcome: AttackOutcome,
    target: GameplayHitTarget?, worldPosition: Vector3, emissionPosition: Vector3?,
    laser: LaserKind?, mount: LaserMount?, victimPart: String?, context: EncounterContext,
    entitlement: MissionBountyEntitlement?
  ) -> CombatIncident? {
    guard worldPosition.finite, emissionPosition?.finite ?? true,
      origin.owner.system == context.system,
      origin.owner.visit == context.visit, origin.emittedAt.isFinite,
      origin.emittedAt >= 0, origin.emittedAt <= context.physicalTime
    else { return nil }
    let victim = combatVictim(target, context: context)
    if case .body = target, victim == nil { return nil }
    guard let id = commander.flightSimulation.allocateIncident() else { return nil }
    let incident = CombatIncident(
      id: id, physicalTime: context.physicalTime, origin: origin, victim: victim?.identity,
      kind: kind, outcome: outcome, position: worldPosition,
      victimLegalBeforeAttack: victim?.legal, firstAggressor: victim?.npc?.firstAggressor,
      victimRole: victim?.npc?.role, victimIsStation: victim?.hull == .station,
      laser: laser, mount: mount, victimPart: victimPart)
    let resolution = commander.crimeLedger.record(
      incident, context: context, emissionPosition: emissionPosition,
      missionEntitlement: entitlement.flatMap {
        $0.owner == origin.owner && $0.victim == victim?.identity ? $0 : nil
      })
    guard resolution.accepted else { return nil }
    gameplayCombatTrace?.append(incident)
    applyCrimeResolution(resolution, target: target, origin: origin, context: context)
    return incident
  }

  /// The caller supplies the nearest verified hit; this adapter never spawns or removes bodies.
  @discardableResult
  mutating func applyCombatHit(
    _ hit: GameplayHit, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind? = nil, mount: LaserMount? = nil, emissionPosition: Vector3? = nil,
    energyMultiplier: Double = 1
  ) -> CombatIncident? {
    guard damage.isFinite, damage >= 0, hit.distance.isFinite, hit.distance >= 0,
      hit.point.finite, energyMultiplier.isFinite, energyMultiplier >= 0
    else { return nil }
    // Practice attribution belongs to the sealed native contact route, never raw damage.
    if nativePracticeReservedTarget(hit) { return nil }
    ensurePhysicalActors()
    switch hit.target {
    case .body:
      return applyBodyHit(
        hit, origin: origin, kind: kind, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition)
    case .player:
      return applyPlayerHit(
        hit, origin: origin, kind: kind, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition, energyMultiplier: energyMultiplier)
    case .celestial:
      return recordCombat(
        origin: origin, kind: kind, outcome: .hit, target: hit.target,
        worldPosition: commander.flightSimulation.pose.systemPoint(hit.point),
        emissionPosition: emissionPosition, laser: laser, mount: mount)
    }
  }

  private mutating func applyBodyHit(
    _ hit: GameplayHit, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind?, mount: LaserMount?, emissionPosition: Vector3?
  ) -> CombatIncident? {
    guard case .body(let id) = hit.target,
      let index = bodies.firstIndex(where: { $0.id == id }), bodies[index].energy > 0,
      let context = gameplayContext()
    else { return nil }
    let entitlement = combatMissionEntitlement(hit.target, owner: origin.owner, context: context)
    let interception = bodies[index].hull == .missile
    let world = commander.flightSimulation.pose.systemPoint(hit.point)
    guard
      let incident = recordCombatWithEntitlement(
        origin: origin, kind: kind, outcome: interception ? .ordnanceInterception : .hit,
        target: hit.target, worldPosition: world, emissionPosition: emissionPosition,
        laser: laser, mount: mount, victimPart: nil, context: context, entitlement: entitlement)
    else { return nil }
    if interception {
      if let emission = currentNativeOrdnanceEmission(bodies[index], context: context) {
        commander.crimeLedger.finishEmission(emission)
      }
      bodies[index].energy = 0
    } else {
      damageBody(index: index, incident: incident, damage: damage, point: hit.point)
    }
    if bodies[index].energy <= 0 {
      bodies[index].physical?.deathOrigin = origin
      bodies[index].destroyedByPlayer = origin.owner == commander.flightSimulation.player
      if !interception, let deathContext = gameplayContext() {
        let destruction = recordCombatWithEntitlement(
          origin: origin, kind: kind, outcome: .destruction, target: hit.target,
          worldPosition: world, emissionPosition: emissionPosition, laser: laser, mount: mount,
          victimPart: nil, context: deathContext, entitlement: entitlement)
        bodies[index].physical?.deathIncidentID = destruction?.id
      }
    }
    return incident
  }

  private mutating func applyPlayerHit(
    _ hit: GameplayHit, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind?, mount: LaserMount?, emissionPosition: Vector3?, energyMultiplier: Double
  ) -> CombatIncident? {
    let world = commander.flightSimulation.pose.systemPoint(hit.point)
    guard energy > 0,
      let incident = recordCombat(
        origin: origin, kind: kind, outcome: .hit, target: .player,
        worldPosition: world, emissionPosition: emissionPosition, laser: laser, mount: mount)
    else { return nil }
    applyDamage(damage, front: hit.point.z >= 0, energyMultiplier: energyMultiplier)
    if energy <= 0 {
      recordFatalPlayerHit(
        incident, origin: origin, kind: kind, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition, energyMultiplier: energyMultiplier, world: world)
    }
    return incident
  }

  /// Fatal-only queries and logging do not reserve temporaries in the ordinary hit frame.
  @inline(never)
  private mutating func recordFatalPlayerHit(
    _ incident: CombatIncident, origin: AttackOrigin, kind: AttackKind, damage: Double,
    laser: LaserKind?, mount: LaserMount?, emissionPosition: Vector3?, energyMultiplier: Double,
    world: Vector3
  ) {
    let revision = gameplayRevision
    let owner = incident.origin.owner
    let loggedLaser: String = incident.laser?.rawValue ?? "none"
    let loggedMount: String = incident.mount?.rawValue ?? "none"
    let ownerLegal = incident.origin.ownerLegalAtEmission.value
    let playerLegal = commander.legal
    var ownerMatches = 0
    var role = "unknown"
    var producer = "unknown"
    var engagesPlayer = "u"
    if let player = commander.flightSimulation.player,
      player.system == owner.system, player.visit == owner.visit
    {
      for body in bodies where body.physical?.identity == owner {
        ownerMatches += 1
        guard ownerMatches == 1 else {
          role = "unknown"
          producer = "unknown"
          engagesPlayer = "u"
          break
        }
        role = body.physical?.npc?.role.rawValue ?? "none"
        producer = body.physical?.spawnIdentity?.producer.rawValue ?? "none"
        engagesPlayer = body.physical?.npc?.intention == .engage(player) ? "1" : "0"
      }
    }
    let ownerContext = (role: role, producer: producer, engagesPlayer: engagesPlayer)
    gameplayCombatLogger.notice(
      "PLAYER_COMBAT_FATAL revision=\(revision, privacy: .public) incident=\(incident.id, privacy: .public) time=\(String(incident.physicalTime), privacy: .public) kind=\(incident.kind.rawValue, privacy: .public) ownerGalaxy=\(owner.system.galaxy, privacy: .public) ownerSystem=\(owner.system.system, privacy: .public) ownerVisit=\(owner.visit, privacy: .public) ownerEntity=\(owner.entity, privacy: .public) ordnance=\(incident.origin.ordnance == nil ? 0 : 1, privacy: .public) damage=\(String(damage), privacy: .public) energyMultiplier=\(String(energyMultiplier), privacy: .public) laser=\(loggedLaser, privacy: .public) mount=\(loggedMount, privacy: .public) role=\(ownerContext.role, privacy: .public) oLegal=\(ownerLegal, privacy: .public) pLegal=\(playerLegal, privacy: .public) producer=\(ownerContext.producer, privacy: .public) engagePlayer=\(ownerContext.engagesPlayer, privacy: .public)"
    )
    recordCombat(
      origin: origin, kind: kind, outcome: .destruction, target: .player,
      worldPosition: world, emissionPosition: emissionPosition, laser: laser, mount: mount)
  }

  private mutating func damageBody(
    index: Int, incident: CombatIncident, damage: Double, point: Vector3
  ) {
    guard damage > 0, bodies[index].physical?.empCrewPod == nil,
      bodies[index].hull != .station || nativeStationBodyIsCurrent(bodies[index]),
      incident.kind != .bomb || !bodies[index].hull.bombImmune
    else { return }
    if bodies[index].hull == .constrictor,
      incident.kind == .plasma
        || (incident.kind == .laser && incident.laser != .military && incident.laser != .naval)
    {
      return
    }
    if damagePhysicalAsteroid(index: index, incident: incident, damage: damage) { return }
    if let rockID = bodies[index].physical?.rock,
      let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == rockID })
    {
      switch commander.miningLedger.hit(rock: rock, incident: incident, damage: damage) {
      case .damaged(let remaining): bodies[index].energy = remaining
      case .extracted, .destroyed: bodies[index].energy = 0
      case .ignored, .capacityRefused: break
      }
    } else {
      var remaining = damage
      if incident.kind != .bomb, var resources = bodies[index].physical?.npc?.resources {
        let forward = bodies[index].modelVector(.init(0, 0, 1))
        remaining = resources.absorb(
          damage, front: (point - bodies[index].position).dot(forward) >= 0)
        bodies[index].physical?.npc?.resources = resources
      }
      bodies[index].energy = max(0, bodies[index].energy - remaining)
    }
  }

  private mutating func applyCrimeResolution(
    _ resolution: CrimeResolution, target: GameplayHitTarget?, origin: AttackOrigin,
    context: EncounterContext
  ) {
    applyNativeCrimeResolution(
      resolution, target: target, attacker: origin.owner, context: context)
  }

  /// Apply a verified ledger result without manufacturing a current origin for old ordnance.
  mutating func applyNativeCrimeResolution(
    _ resolution: CrimeResolution, target: GameplayHitTarget?, attacker: ActorIdentity?,
    context: EncounterContext
  ) {
    if resolution.offender == context.player.identity {
      let baseline = max(0, min(255, commander.legal))
      let penalty = max(0, min(255, resolution.legalPenalty))
      commander.legal = max(commander.legal, min(255, baseline + penalty))
    } else if let index = bodies.firstIndex(where: { $0.physical?.identity == resolution.offender }
    ),
      let legal = bodies[index].physical?.npc?.legal.value
    {
      let baseline = max(0, min(255, legal))
      let penalty = max(0, min(255, resolution.legalPenalty))
      bodies[index].physical?.npc?.legal.value = max(legal, min(255, baseline + penalty))
      if penalty > 0 { bodies[index].physical?.npc?.legalProvenance = .recorded }
    }
    if resolution.unlawful, case .body(let id) = target,
      let index = bodies.firstIndex(where: { $0.id == id }), bodies[index].hull.isTargetShip
    {
      bodies[index].physical?.npc?.firstAggressor = resolution.firstAggressor
      if let attacker = resolution.offender ?? attacker {
        bodies[index].physical?.npc?.intention = .engage(attacker)
        if bodies[index].blackjackRole == nil, bodies[index].missionInstanceID == nil,
          bodies[index].scriptNPC == nil
        {
          bodies[index].hostile = attacker == context.player.identity
        } else if attacker == context.player.identity {
          // Authored mission and Blackjack drivers retain their existing dispatch projection.
          bodies[index].hostile = true
        }
      }
    }
    if let death = resolution.death {
      var careers = commander.wantedCareers
      if let ownerBody = bodies.first(where: { $0.physical?.identity == death.owner }),
        wantedCareerIsOrdinary(ownerBody),
        let logical = commander.npcPersistence.logicalIdentity(for: death.owner),
        let observed = NPCPersistenceSnapshot.capture(
          body: ownerBody, pose: commander.flightSimulation.pose,
          physicalTime: context.physicalTime, protection: context.protection)
      {
        careers.observe(
          observed, logical: logical, visible: ownerBody.position.length <= context.perceptionRadius
        )
      }
      let shipDeath =
        death.victim == context.player.identity
        || context.actors.contains { $0.identity == death.victim && $0.hull.isTargetShip }
      let victimCareer = careers.careers.values.first { $0.binding == death.victim }
      var listed = false
      if let career = victimCareer {
        listed = wantedBoard.contains { $0.identity == career.identity }
      }
      let recorded = careers.record(
        death, player: context.player.identity, shipDeath: shipDeath)
      if careers != commander.wantedCareers { commander.wantedCareers = careers }
      if recorded, listed, let name = victimCareer?.callsign {
        notify("WANTED CAREER CLOSED: " + name)
      }
    }
    if let report = resolution.report { commander.stationSecurity.receive(report) }
    for notice in resolution.notices where message != notice.text || messageTime <= 0 {
      notify(notice.text)
    }
    observeFleetDestruction(resolution.death, target: target, context: context)
    creditCombatDeath(resolution.death, target: target, context: context)
  }

  private mutating func creditCombatDeath(
    _ death: DeathSettlement?, target: GameplayHitTarget?, context: EncounterContext
  ) {
    guard let death, death.owner == context.player.identity, case .body(let id) = target,
      let body = bodies.first(where: { $0.id == id }), body.hull.isTargetShip,
      !isGlassMeridianClock(body)
    else { return }
    let previousRank = commander.rank
    commander.kills = (commander.kills &+ 1) & 0xffff
    commander.credits = (commander.credits &+ death.bountyTenths) & 0xffff_ffff
    if commander.rank != previousRank { notify("RIGHT ON, COMMANDER") }
  }

  private func combatVictim(_ target: GameplayHitTarget?, context: EncounterContext)
    -> ActorSnapshot?
  {
    switch target {
    case .player: return context.player
    case .body(let id):
      guard let identity = bodies.first(where: { $0.id == id })?.physical?.identity else {
        return nil
      }
      return combatActor(identity, context: context)
    case .celestial, nil: return nil
    }
  }

  private func combatActor(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot? {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  func combatMissionEntitlement(
    _ target: GameplayHitTarget?, owner: ActorIdentity, context: EncounterContext
  ) -> MissionBountyEntitlement? {
    guard owner == context.player.identity, case .body(let id) = target,
      let body = bodies.first(where: { $0.id == id }), let victim = body.physical?.identity
    else { return nil }
    if let descriptor = currentMissionActorDescriptor(bodyID: id),
      let binding = try? MissionNativeBridge.bindActor(
        descriptor: descriptor, body: body, context: context), binding.nativeActor == victim,
      let instance = commander.scriptState.instances[descriptor.instanceID],
      let pack = scriptPack(for: instance),
      let encounter = pack.manifest.encounters?.first(where: { $0.id == descriptor.encounterID }),
      let declared = encounter.actors.first(where: { $0.id == descriptor.alias })
    {
      let amount =
        body.scriptNPC?.fit.definition.bounty ?? body.hull.navalBounty
        ?? (declared.hostile ? 50 : 0)
      return .init(
        owner: owner, victim: victim, amountTenths: amount,
        authorizesAttack: declared.hostile)
    }
    if let role = body.blackjackRole, commander.galaxy == 1,
      commander.system == role.system, commander.blackjack.stage == role.requiredStage
    {
      let saved = role == .bolts ? commander.blackjack.bolts : commander.blackjack.witness
      if saved?.identity == body.blackjackIdentity {
        return .init(
          owner: owner, victim: victim, amountTenths: role.bountyCredits * 10,
          authorizesAttack: role == .bolts)
      }
    }
    if body.navalTarget, body.hull == .constrictor,
      commander.missionStage == .huntingConstrictor
    {
      return .init(
        owner: owner, victim: victim, amountTenths: body.hull.navalBounty ?? 0,
        authorizesAttack: true)
    }
    return nil
  }
}
