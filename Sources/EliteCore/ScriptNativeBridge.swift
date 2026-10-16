import Foundation

extension Game {
  /// Resolves real retained ownership. A caller-built descriptor alone has no mission authority.
  func currentMissionActorDescriptor(bodyID: Int) -> MissionActorDescriptor? {
    guard let body = bodies.first(where: { $0.id == bodyID }),
      bodies.lazy.filter({ $0.id == bodyID }).count == 1,
      body.energy.isFinite, body.energy > 0,
      let instanceID = body.missionInstanceID, let actorID = body.missionActorID,
      let instance = commander.scriptState.instances[instanceID], instance.id == instanceID,
      let pack = scriptPack(for: instance)
    else { return nil }
    var match: (encounter: ScriptOwnedEncounter, actor: ScriptOwnedActor)?
    for (encounterID, encounter) in instance.ownedEncounters {
      for (alias, actor) in encounter.actors where actor.identity == actorID {
        guard match == nil, encounterID == encounter.id, alias == actor.alias,
          encounter.admitted, actor.presence == .present,
          encounter.galaxy == commander.galaxy, encounter.system == commander.system,
          actor.body.id == bodyID, actor.body.missionActorID == actorID,
          actor.body.missionInstanceID == instanceID, actor.body.hull == body.hull,
          let definition = pack.manifest.encounters?.first(where: { $0.id == encounterID }),
          definition.galaxy == encounter.galaxy, definition.system == encounter.system,
          let declared = definition.actors.first(where: { $0.id == alias }),
          missionActorFitMatches(body, retained: actor, declared: declared, pack: pack)
        else { return nil }
        match = (encounter, actor)
      }
    }
    guard let match else { return nil }
    // Retained poses and mutable condition can be older and in the station frame. The descriptor
    // carries the actual current body; only immutable fit and durable ownership join to the record.
    return .init(
      instanceID: instanceID, instanceRevision: instance.revision, packDigest: instance.digest,
      encounterID: match.encounter.id, encounterAdmitted: match.encounter.admitted,
      system: .init(galaxy: match.encounter.galaxy, system: match.encounter.system),
      alias: match.actor.alias, actorID: actorID, presence: match.actor.presence.rawValue,
      missionActorID: body.missionActorID, missionInstanceID: body.missionInstanceID, body: body)
  }

  private func missionActorFitMatches(
    _ body: SpaceBody, retained: ScriptOwnedActor, declared: ScriptActorDefinition, pack: ScriptPack
  ) -> Bool {
    guard let npcID = declared.npc else {
      return declared.hull == body.hull && body.scriptNPC == nil && retained.body.scriptNPC == nil
    }
    guard let npc = body.scriptNPC, npc.valid,
      npc.fit == retained.body.scriptNPC?.fit,
      let definition = pack.manifest.npcs?.first(where: { $0.id == npcID }),
      npc.fit.definition == definition
    else { return false }
    // Compare existing immutable designs directly. No geometry encoding, hash construction or
    // cache mutation belongs on this live source-resolution path.
    return npc.fit.models.allSatisfy { reference, digest in
      guard let installed = pack.models[reference],
        let retained = commander.scriptState.geometry[digest]
      else { return false }
      return installed == retained
    }
  }

  /// The simulation supplies its actual transformed aim; this joins the authored weapon and muzzle.
  func missionWeaponDescriptor(
    _ weapon: ScriptNPCWeapon, source: SpaceBody, component: UUID?, muzzle: Vector3,
    direction: Vector3
  ) -> MissionWeaponDescriptor? {
    guard currentMissionActorDescriptor(bodyID: source.id)?.body == source,
      let npc = source.scriptNPC, weapon.valid
    else { return nil }
    let expectedMuzzle: Vector3
    if let component {
      guard let entry = npc.components.first(where: { $0.value.identity == component }),
        entry.value.energy > 0,
        let specification = npc.fit.definition.components?.first(where: { $0.id == entry.key }),
        specification.weapons?.first(where: { $0.id == weapon.id }) == weapon,
        entry.value.guns[weapon.id] != nil
      else { return nil }
      let pose = specification.orientation.transformed(by: source.orientation)
      let center =
        source.position
        + source.orientation.apply(specification.position * npc.fit.definition.scale)
      expectedMuzzle =
        center
        + pose.apply(weapon.muzzle * (specification.scale * npc.fit.definition.scale))
    } else {
      guard npc.fit.definition.lasers?.first(where: { $0.id == weapon.id }) == weapon,
        npc.guns[weapon.id] != nil
      else { return nil }
      expectedMuzzle =
        source.position
        + source.orientation.apply(weapon.muzzle * npc.fit.definition.scale)
    }
    guard muzzle == expectedMuzzle else { return nil }
    let descriptor = MissionWeaponDescriptor(
      id: weapon.id, kind: weapon.kind == .laser ? .laser : .plasma,
      damage: weapon.damage, range: weapon.range, projectileSpeed: weapon.projectileSpeed,
      lifetime: weapon.lifetime, collisionRadius: weapon.collisionRadius,
      collisionDelay: weapon.collisionDelay, muzzle: muzzle, direction: direction)
    guard (try? MissionNativeBridge.validateWeapon(descriptor)) != nil else { return nil }
    return descriptor
  }
}

extension ScriptNPCShot {
  /// An absent historical owner does not invalidate physical shot motion or invent attribution.
  var missionDescriptor: MissionShotDescriptor? {
    guard valid else { return nil }
    let descriptor = MissionShotDescriptor(
      identity: identity, owner: owner, instance: instance, weapon: weapon, component: component,
      velocity: velocity, age: age, lifetime: lifetime, damage: damage, radius: radius,
      collisionDelay: collisionDelay)
    guard (try? MissionNativeBridge.validateShot(descriptor)) != nil else { return nil }
    return descriptor
  }
}

extension ScriptEngineState {
  /// Saved archive shape is untrusted until joined to the retained source version and system.
  func projectileArchiveValid(_ record: ScriptProjectileRecord) -> Bool {
    guard let shot = record.body.scriptShot, let descriptor = shot.missionDescriptor,
      let instance = instances[shot.instance], instance.id == shot.instance
    else { return false }
    if let archive = shot.nativeAttribution,
      archive.origin.owner.system != SystemIdentity(galaxy: record.galaxy, system: record.system)
    {
      return false
    }
    return
      (try? MissionNativeBridge.validateArchive(
        shot.nativeAttribution, shot: descriptor, packDigest: instance.digest)) != nil
  }
}
