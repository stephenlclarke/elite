import Foundation

extension NativeGlassMeridian {
  static func lossesValid(_ state: NativeGlassMeridianState) -> Bool {
    guard state.losses.count <= 128 else { return false }
    var counts = [0, 0]
    var lastTime = state.permission.physicalTime
    var physical: Set<ActorIdentity> = []
    for loss in state.losses {
      guard (0..<2).contains(loss.ordinal), loss.generation == counts[loss.ordinal],
        loss.physicalTime.isFinite, loss.physicalTime >= lastTime,
        loss.marker.valid, loss.marker.presence == .destroyed, loss.marker.body.energy == 0,
        loss.marker.alias == targets[loss.ordinal],
        loss.marker.identity
          == actor(
            mission: state.permission.mission,
            ordinal: loss.ordinal, generation: loss.generation),
        loss.marker.body.missionInstanceID == state.permission.mission,
        loss.marker.body.scriptNPC.map({ clockDefinitionValid($0.fit.definition) }) == true,
        let binding = loss.marker.body.physical?.identity, binding.system == objective,
        binding.entity > 1, binding.visit > state.permission.dock.actor.visit,
        physical.insert(binding).inserted
      else { return false }
      counts[loss.ordinal] += 1
      lastTime = loss.physicalTime
    }
    return true
  }

  /// The ordinary source validator accepts only this closed native replacement history.
  static func authorizesReplacement(
    _ state: NativeGlassMeridianState?, actor value: ScriptOwnedActor,
    encounter: String, instance: UUID, packDigest: String
  ) -> Bool {
    guard packDigest == digest, let state, state.permission.mission == instance,
      lossesValid(state), let ordinal = encounters.firstIndex(of: encounter),
      value.alias == targets[ordinal]
    else { return false }
    let generation = state.losses.filter { $0.ordinal == ordinal }.count
    return generation > 0
      && value.identity == actor(mission: instance, ordinal: ordinal, generation: generation)
  }
}

extension Game {
  /// A destroyed unread device is replaced by fresh source stock, never resurrected in place.
  /// The old canonical body and native identity remain in the campaign's loss history.
  mutating func prepareGlassMeridianBeacons() throws -> Bool {
    guard var mission = glassMeridianMission, var state = mission.savedGlassMeridian,
      mission.outcome == .active, mission.suspension == nil, state.readings.count < 2,
      let pack = glassMeridianPack, systemIdentity == NativeGlassMeridian.objective,
      !docked, !paused, screen.isFlight
    else { return false }
    var changed = false
    for ordinal in 0..<2 where !state.readings.contains(where: { $0.reading.ordinal == ordinal }) {
      let key = NativeGlassMeridian.encounters[ordinal]
      let alias = NativeGlassMeridian.targets[ordinal]
      if let old = mission.ownedEncounters[key]?.actors[alias], old.presence == .destroyed {
        guard state.losses.count < 128 else {
          throw MissionPackError(
            "Clock replacement history is full; completed evidence is retained.")
        }
        let generation = state.losses.filter { $0.ordinal == ordinal }.count
        state.losses.append(
          .init(
            ordinal: ordinal, generation: generation, marker: old,
            physicalTime: commander.flightSimulation.physicalTime))
        guard NativeGlassMeridian.lossesValid(state),
          let definition = pack.manifest.encounters?.first(where: { $0.id == key }),
          let spec = definition.actors.first,
          let npc = pack.manifest.npcs?.first(where: { $0.id == NativeGlassMeridian.markerID })
        else { throw SaveError.invalidCommander }
        let identity = NativeGlassMeridian.actor(
          mission: mission.id, ordinal: ordinal, generation: generation + 1)
        var body = SpaceBody(
          id: -1, hull: spec.hull ?? .cobra,
          position: .init(spec.x, spec.y, spec.z), hostile: false)
        body.scriptNPC = try makeScriptNPC(npc, pack: pack, identity: identity)
        body.energy = npc.energy
        body.missiles = npc.missiles
        body.ecmEnabled = npc.ecm
        body.rotationRate = 0
        body.missionActorID = identity
        body.missionInstanceID = mission.id
        mission.savedGlassMeridian = state
        mission.ownedEncounters[key] = .init(
          id: key, galaxy: 0, system: 185,
          actors: [alias: .init(identity: identity, alias: alias, body: body, presence: .prepared)])
        changed = true
      }
      if mission.ownedEncounters[key]?.admitted != true {
        let before = mission.ownedEncounters[key]
        _ = try ensureScriptEncounter(key, pack: pack, state: &mission)
        if mission.ownedEncounters[key] != before { changed = true }
      }
    }
    if changed {
      mission.savedGlassMeridian = state
      commander.scriptState.instances[mission.id] = mission
    }
    return changed
  }
}

extension GameRuntime {
  func commitGlassMeridianBeacons() {
    guard game.glassMeridianMission != nil, let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      let reading = try candidate.applyGlassMeridianPending()
      let source = try candidate.prepareGlassMeridianBeacons()
      guard reading || source else { return }
      try publish(&candidate)
      game = candidate
    } catch {
      let reason = "Clock source refused: " + error.localizedDescription
      game.nativeGlassMeridianRuntime?.reason = reason
      game.notify(reason)
    }
  }
}
