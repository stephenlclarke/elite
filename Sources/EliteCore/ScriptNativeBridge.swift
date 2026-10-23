import Foundation

extension Game {
  /// Resolves real retained ownership. A caller-built descriptor alone has no mission authority.
  func currentMissionActorDescriptor(bodyID: Int) -> MissionActorDescriptor? {
    // Ordinary craft cannot pass the retained factory's existing ownership guard.
    // Keep that rejection outside its Commander and actor-validation stack frames.
    guard Self.firstMissionBodyHasOwnershipTags(bodyID: bodyID, bodies: bodies) else { return nil }
    return retainedCurrentMissionActorDescriptor(bodyID: bodyID)
  }

  @inline(never)
  private static func firstMissionBodyHasOwnershipTags(
    bodyID: Int, bodies: borrowing [SpaceBody]
  ) -> Bool {
    for index in bodies.indices where bodies[index].id == bodyID {
      return bodies[index].missionInstanceID != nil && bodies[index].missionActorID != nil
    }
    return false
  }

  /// Only actual mission-tagged bodies enter the unchanged full retained-owner census.
  private func retainedCurrentMissionActorDescriptor(bodyID: Int) -> MissionActorDescriptor? {
    let source = commander.missionActorSourceValues()
    return Self.retainedMissionActorDescriptor(
      bodyID: bodyID, bodies: bodies, instances: source.instances,
      packs: scriptPacks, galaxy: source.galaxy, system: source.system,
      geometry: source.geometry)
  }

  /// Resolve the same immutable authority facts without retaining another complete Game frame.
  private static func retainedMissionActorDescriptor(
    bodyID: Int, bodies: [SpaceBody], instances: [UUID: ScriptInstance], packs: [ScriptPack],
    galaxy: Int, system: Int, geometry: [String: ShipDesign]
  ) -> MissionActorDescriptor? {
    guard let body = bodies.first(where: { $0.id == bodyID }),
      bodies.lazy.filter({ $0.id == bodyID }).count == 1,
      body.energy.isFinite, body.energy > 0,
      let instanceID = body.missionInstanceID, let actorID = body.missionActorID,
      let instance = instances[instanceID], instance.id == instanceID,
      let pack = packs.first(where: {
        $0.manifest.stateID == instance.definition && $0.manifest.version == instance.version
          && $0.digest == instance.digest
      })
    else { return nil }
    var match: (encounter: ScriptOwnedEncounter, actor: ScriptOwnedActor)?
    for (encounterID, encounter) in instance.ownedEncounters {
      for (alias, actor) in encounter.actors where actor.identity == actorID {
        guard match == nil, encounterID == encounter.id, alias == actor.alias,
          encounter.admitted, actor.presence == .present,
          actor.location(in: encounter) == .init(galaxy: galaxy, system: system),
          actor.body.id == bodyID, actor.body.missionActorID == actorID,
          actor.body.missionInstanceID == instanceID, actor.body.hull == body.hull,
          let definition = NativeC01Surveyor.encounterDefinition(
            pack: pack, state: instance, id: encounterID),
          definition.galaxy == encounter.galaxy, definition.system == encounter.system,
          let declared = definition.actors.first(where: { $0.id == alias }),
          missionActorFitMatches(
            body, retained: actor, declared: declared, pack: pack, instance: instance,
            geometry: geometry)
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
      system: match.actor.location(in: match.encounter),
      alias: match.actor.alias, actorID: actorID, presence: match.actor.presence.rawValue,
      missionActorID: body.missionActorID, missionInstanceID: body.missionInstanceID, body: body)
  }

  @inline(never)
  private static func missionActorFitMatches(
    _ body: borrowing SpaceBody, retained: borrowing ScriptOwnedActor,
    declared: borrowing ScriptActorDefinition, pack: borrowing ScriptPack,
    instance: borrowing ScriptInstance, geometry: borrowing [String: ShipDesign]
  ) -> Bool {
    guard let npcID = declared.npc else {
      guard declared.hull == body.hull, body.scriptNPC == nil, retained.body.scriptNPC == nil else {
        return false
      }
      return true
    }
    guard let npc = body.scriptNPC, npc.valid,
      npc.fit == retained.body.scriptNPC?.fit,
      missionActorComponentsMatch(npc.components, retained: retained),
      let definition = NativeC01Surveyor.profiles(pack: copy pack, state: copy instance).first(
        where: {
          $0.id == npcID
        }),
      npc.fit.definition == definition
    else { return false }
    // Compare existing immutable designs directly. No geometry encoding, hash construction or
    // cache mutation belongs on this live source-resolution path.
    return missionActorModelsMatch(
      npc.fit.models, pack: pack, instance: instance, geometry: geometry)
  }

  @inline(never)
  private static func missionActorComponentsMatch(
    _ components: borrowing [String: ScriptNPCComponentState], retained: borrowing ScriptOwnedActor
  ) -> Bool {
    for (alias, component) in copy components {
      guard retained.body.scriptNPC?.components[alias]?.identity == component.identity else {
        return false
      }
    }
    return true
  }

  @inline(never)
  private static func missionActorModelsMatch(
    _ models: borrowing [String: String], pack: borrowing ScriptPack,
    instance: borrowing ScriptInstance, geometry: borrowing [String: ShipDesign]
  ) -> Bool {
    for (reference, digest) in copy models {
      guard
        let installed = NativeC01Surveyor.designs(pack: copy pack, state: copy instance)[reference],
        let retained = geometry[digest]
      else { return false }
      guard installed == retained else { return false }
    }
    return true
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
      let instance = instances[shot.instance], instance.id == shot.instance,
      instance.ownedEncounters.values.contains(where: { encounter in
        encounter.actors.values.contains { actor in
          actor.identity == shot.owner
            && (shot.component.map { component in
              actor.body.scriptNPC?.components.values.contains { $0.identity == component } == true
            } ?? true)
        }
      })
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

extension Commander {
  /// Read the same immutable fields through borrowed self before the factory starts.
  /// This tuple is transient data, with no body, authority, cache or state owner.
  fileprivate func missionActorSourceValues() -> (
    instances: [UUID: ScriptInstance], galaxy: Int, system: Int, geometry: [String: ShipDesign]
  ) {
    let state = scriptState
    return (state.instances, galaxy, system, state.geometry)
  }
}
