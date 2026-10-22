import Foundation

extension Game {
  /// Future T02/T03 lesson adapters call this after the genuine station choice and launch.
  /// The native begin freezes the actual flight pose; it never accepts a caller-selected frame.
  mutating func beginNativePractice(instance id: UUID) throws {
    guard !docked, !paused, !isMissionTrial, screen.isFlight, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      var instance = commander.scriptState.instances[id], instance.outcome == .active,
      instance.suspension == nil, instance.savedNativePractice == nil,
      let lesson = NativePracticeLesson(rawValue: instance.definition),
      let pack = scriptPack(for: instance), pack.digest == instance.digest,
      let consent = instance.choiceReceipts[NativePracticeSource.consentGroup],
      consent.valid(for: instance, engine: commander.scriptState),
      consent.choice == NativePracticeSource.consentChoice,
      let carrier = commander.hullInstanceID,
      let player = commander.flightSimulation.player,
      commander.scriptState.instances.values.allSatisfy({
        $0.savedNativePractice.map { $0.endedAt != nil } ?? true
      })
    else { throw NativePracticeError.invalidSource }
    ensurePhysicalActors()
    guard let context = gameplayContext(), context.player.identity == player,
      context.system == systemIdentity, context.visit == commander.flightSimulation.visit
    else { throw NativePracticeError.staleContext }
    var flight = commander.flightSimulation
    let permission = NativePracticePermission(
      mission: id, owner: commander.equipmentOwnerID, carrier: carrier, lesson: lesson,
      digest: instance.digest, consent: consent, player: player,
      frame: flight.pose, begunAt: flight.physicalTime)
    let practice = try NativePracticeState.prepare(permission: permission, flight: &flight)
    let prepared = try prepareNativePracticeBodies(practice, context: context)
    instance.savedNativePractice = practice
    commander.flightSimulation = flight
    commander.scriptState.instances[id] = instance
    bodies.append(contentsOf: prepared)
    nextBodyID += prepared.count
    gameplayRevision &+= 1
  }

  /// Same-visit restoration keeps the original allocations, frame and first-hit history.
  /// Returning in a later visit is an interruption, not permission to mint another range.
  mutating func restoreNativePractice(instance id: UUID) throws {
    guard !docked, !paused, !isMissionTrial,
      let instance = commander.scriptState.instances[id],
      let practice = instance.savedNativePractice,
      nativePracticeCurrent(practice, instance: instance),
      let context = gameplayContext()
    else { throw NativePracticeError.staleContext }
    let prepared = try prepareNativePracticeBodies(practice, context: context)
    bodies.append(contentsOf: prepared)
    nextBodyID += prepared.count
    if !prepared.isEmpty { gameplayRevision &+= 1 }
  }

  /// Provider lifetime only: removing originals is never a hit, death or lesson completion.
  mutating func endNativePractice(instance id: UUID) throws {
    guard var instance = commander.scriptState.instances[id],
      var practice = instance.savedNativePractice, practice.valid,
      practice.endedAt == nil, practice.permission.owner == commander.equipmentOwnerID
    else { throw NativePracticeError.invalidSource }
    practice.endedAt = commander.flightSimulation.physicalTime
    guard practice.valid else { throw NativePracticeError.staleContext }
    bodies.removeAll { practice.reserves($0) }
    instance.savedNativePractice = practice
    commander.scriptState.instances[id] = instance
    gameplayRevision &+= 1
  }

  private func prepareNativePracticeBodies(
    _ practice: NativePracticeState, context: EncounterContext
  ) throws -> [SpaceBody] {
    guard practice.valid, practice.endedAt == nil,
      context.player.identity == practice.permission.player,
      Set(bodies.map(\.id)).count == bodies.count,
      nextBodyID >= 0, nextBodyID <= 999_999_996
    else { throw NativePracticeError.staleContext }
    var prepared: [SpaceBody] = []
    for beacon in practice.beacons {
      let matching = bodies.filter {
        $0.physical?.identity == beacon.actor || $0.physical?.spawnIdentity == beacon.spawn
      }
      if let existing = matching.first {
        guard matching.count == 1,
          practice.beacon(for: existing, pose: commander.flightSimulation.pose) == beacon
        else { throw NativePracticeError.invalidTarget }
        continue
      }
      let body = practice.body(
        for: beacon, id: nextBodyID + prepared.count, pose: commander.flightSimulation.pose)
      guard !bodies.contains(where: { $0.id == body.id }) else {
        throw NativePracticeError.invalidTarget
      }
      prepared.append(body)
    }
    if let refusal = gameplayPracticeAdmissionRefusal(
      practice, prepared: prepared, context: context)
    {
      throw refusal == .unsafePosition
        ? NativePracticeError.unsafePosition : NativePracticeError.capacity
    }
    return prepared
  }

  func nativePracticeCurrent(_ practice: NativePracticeState, instance: ScriptInstance) -> Bool {
    NativePracticeSave.valid(
      practice, instance: instance, engine: commander.scriptState,
      owner: commander.equipmentOwnerID, flight: commander.flightSimulation)
      && practice.endedAt == nil && instance.outcome == .active
      && instance.suspension == nil && instance.id == practice.permission.mission
      && instance.definition == practice.permission.lesson.rawValue
      && instance.digest == practice.permission.digest && scriptPack(for: instance) != nil
      && practice.permission.owner == commander.equipmentOwnerID
      && practice.permission.carrier == commander.hullInstanceID
      && practice.permission.player == commander.flightSimulation.player
      && instance.choiceReceipts[NativePracticeSource.consentGroup] == practice.permission.consent
      && practice.permission.consent.valid(for: instance, engine: commander.scriptState)
  }

  /// This lookup cannot grant immunity through a mission label or through an ordinary actor.
  func nativePracticeReservation(_ body: SpaceBody) -> NativePracticeState? {
    guard body.hull == .cargo, let physical = body.physical,
      physical.population == .mission, physical.spawnIdentity?.producer == .provider
    else { return nil }
    for instance in commander.scriptState.instances.values {
      if let practice = instance.savedNativePractice, practice.reserves(body),
        NativePracticeSave.valid(
          practice, instance: instance, engine: commander.scriptState,
          owner: commander.equipmentOwnerID, flight: commander.flightSimulation)
      {
        return practice
      }
    }
    return nil
  }

  func nativePracticeReservedTarget(_ hit: GameplayHit) -> Bool {
    guard case .body(let id) = hit.target,
      let body = bodies.first(where: { $0.id == id })
    else { return false }
    return nativePracticeReservation(body) != nil
  }

  /// True consumes only the native practice route, including duplicate/stale refusal.
  /// No CombatIncident, health, crew, crime, bounty, hostility or cargo state is produced.
  @discardableResult
  mutating func handleNativePracticeContact(
    _ contact: MissionCollisionContact, origin: AttackOrigin, kind: AttackKind,
    projectile: OrdnanceState? = nil
  ) -> Bool {
    guard let body = contact.selectedTargetBody,
      var practice = nativePracticeReservation(body)
    else { return false }
    guard !paused, !docked, !isMissionTrial,
      var instance = commander.scriptState.instances[practice.permission.mission],
      nativePracticeCurrent(practice, instance: instance),
      bodies.filter({ $0.id == body.id }) == [body],
      projectile.map({ nativePracticeProjectileCurrent($0) }) ?? true,
      let receipt = try? NativePracticeHitPolicy.nativeContact(
        contact, state: practice, pose: commander.flightSimulation.pose, origin: origin,
        kind: kind, time: projectile?.lastUpdatedAt ?? commander.flightSimulation.physicalTime,
        nextEmission: commander.flightSimulation.nextEmission, projectile: projectile)
    else { return true }
    do { try practice.record(receipt) } catch { return true }
    instance.savedNativePractice = practice
    commander.scriptState.instances[instance.id] = instance
    return true
  }

  private func nativePracticeProjectileCurrent(_ shot: OrdnanceState) -> Bool {
    let matches = bodies.filter { $0.physical?.identity == shot.origin.ordnance }
    guard matches.count == 1, let body = matches.first, body.energy > 0,
      body.hull == .missile, body.scriptShot == nil,
      let physical = body.physical, physical.population == .projectile,
      physical.spawnIdentity?.producer == .ordnance,
      physical.attackOrigin == shot.origin,
      let retained = physical.ordnance, retained.valid, retained.termination == nil,
      retained.origin == shot.origin, retained.profile == shot.profile,
      retained.target == shot.target, retained.emissionPosition == shot.emissionPosition,
      retained.lastUpdatedAt <= shot.lastUpdatedAt,
      shot.lastUpdatedAt <= commander.flightSimulation.physicalTime,
      retained.propulsionTravel <= shot.propulsionTravel
    else { return false }
    return true
  }

  func nativePracticeMissileLaunchAllowed(targetBodyID: Int?, owner: ActorIdentity) -> Bool {
    guard !paused, !docked, !isMissionTrial, let targetBodyID,
      owner == commander.flightSimulation.player,
      let body = bodies.first(where: { $0.id == targetBodyID }),
      bodies.filter({ $0.id == targetBodyID }).count == 1,
      let practice = nativePracticeReservation(body),
      let instance = commander.scriptState.instances[practice.permission.mission],
      nativePracticeCurrent(practice, instance: instance),
      practice.beacon(for: body, pose: commander.flightSimulation.pose) != nil
    else { return false }
    return true
  }

  func nativePracticeMesh(_ body: SpaceBody) -> Mesh? {
    guard let practice = nativePracticeReservation(body) else { return nil }
    let time = commander.flightSimulation.physicalTime
    let flashing = practice.hits.contains {
      $0.actor == body.physical?.identity && time >= $0.time && time - $0.time <= 0.15
    }
    return NativePracticeSource.mesh(flashing: flashing)
  }
}
