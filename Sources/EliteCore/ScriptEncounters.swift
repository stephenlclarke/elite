import Foundation

public struct ScriptActorDefinition: Codable, Sendable {
  public let id: String
  public let hull: Hull?
  public var npc: String? = nil
  public let x: Double
  public let y: Double
  public let z: Double
  public let hostile: Bool
}
public struct ScriptEncounterDefinition: Codable, Sendable {
  public let id: String
  public let galaxy: Int
  public let system: Int
  public let profile: String
  public let actors: [ScriptActorDefinition]
}
public enum ScriptActorPresence: String, Codable, Sendable {
  case prepared, present, outside, unloaded, destroyed
}
public struct ScriptOwnedActor: Codable, Sendable, Equatable {
  public let identity: UUID
  public let alias: String
  /// Canonical pose is relative to the main station's non-spinning reference basis.
  public var body: SpaceBody
  public var presence: ScriptActorPresence
  public var destroyedByPlayer: Bool?
  var valid: Bool {
    PackValidation.localID(alias) && body.missionActorID == identity
      && body.position.finite && body.position.length <= 1e9 && body.orientation.validRotation
      && body.energy.isFinite && (0...10_000_000).contains(body.energy)
      && (body.scriptNPC?.valid ?? true)
      && (body.scriptNPC.map {
        body.energy <= $0.fit.definition.energy
          && body.missiles <= $0.fit.definition.missiles
      } ?? true)
      && body.rotation.isFinite && body.rotationRate.isFinite && (0...32).contains(body.missiles)
      && (-1..<1_000_000_000).contains(body.id)
      && (presence != .destroyed || body.energy == 0)
  }
}
public struct ScriptOwnedEncounter: Codable, Sendable, Equatable {
  public let id: String
  public let galaxy: Int
  public let system: Int
  public var admitted = false
  public var actors: [String: ScriptOwnedActor]
  public var destroyed: Bool {
    admitted && !actors.isEmpty && actors.values.allSatisfy { $0.presence == .destroyed }
  }
  var valid: Bool {
    PackValidation.localID(id) && (0..<8).contains(galaxy) && (0...256).contains(system)
      && (1...128).contains(actors.count)
      && Set(actors.values.map(\.identity)).count == actors.count
      && actors.allSatisfy { $0.key == $0.value.alias && $0.value.valid }
      && (admitted
        ? actors.values.allSatisfy { $0.presence != .prepared && $0.body.id >= 0 }
        : actors.values.allSatisfy { $0.presence == .prepared })
  }
}

extension ScriptEncounterDefinition {
  static let classicHulls: Set<Hull> = [
    .cobra, .viper, .sidewinder, .constrictor, .thargoid, .thargon,
  ]
  var valid: Bool {
    PackValidation.localID(id) && (0..<8).contains(galaxy) && (0...256).contains(system)
      && ["classic-local-freeze-v1", "profiled-local-freeze-v1"].contains(profile)
      && (1...128).contains(actors.count)
      && Set(actors.map(\.id)).count == actors.count
      && actors.allSatisfy {
        PackValidation.localID($0.id)
          && (profile == "classic-local-freeze-v1"
            ? $0.hull.map(Self.classicHulls.contains) == true && $0.npc == nil
            : $0.hull == nil && $0.npc.map(PackValidation.localID) == true)
          && [$0.x, $0.y, $0.z].allSatisfy { $0.isFinite && abs($0) <= 1_000_000 }
      }
  }
}

public struct ScriptReferenceFrame: Codable, Sendable, Equatable {
  public var galaxy: Int
  public var system: Int
  public var station: SpaceBody
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system) && station.id == 0
      && station.hull == .station
      && station.position.finite && station.orientation.validRotation && station.energy.isFinite
      && station.rotation.isFinite && station.rotationRate.isFinite
  }
}

extension Game {
  var scriptAnchor: SpaceBody? {
    if let actual = bodies.first(where: { $0.id == 0 && $0.hull == .station }) {
      return actual.energy > 0 ? actual : nil
    }
    guard let frame = scriptReferenceFrame, frame.galaxy == commander.galaxy,
      frame.system == commander.system, frame.station.energy > 0
    else { return nil }
    return frame.station
  }
  mutating func advanceScriptReferenceFrame(delta: Double) {
    guard !bodies.contains(where: { $0.id == 0 && $0.hull == .station }),
      var frame = scriptReferenceFrame, frame.galaxy == commander.galaxy,
      frame.system == commander.system
    else { return }
    frame.station.position = frame.station.position.rotated(
      pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    frame.station.orientation.rotate(pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    frame.station.position =
      frame.station.position - autoPilot.velocity * delta - Vector3(0, 0, speed * delta * 18)
    frame.station.rotation += frame.station.rotationRate * delta
    scriptReferenceFrame = frame
  }
  private func scriptRadius(_ body: SpaceBody) -> Double {
    scriptNPCRadius(body)
  }
  func scriptEncounterSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    .object(
      instance.ownedEncounters.mapValues { encounter in
        .object([
          "admitted": .bool(encounter.admitted), "destroyed": .bool(encounter.destroyed),
          "total": .integer(Int64(encounter.actors.count)),
          "destroyed_count": .integer(
            Int64(encounter.actors.values.filter { $0.presence == .destroyed }.count)),
          "actors": .object(
            encounter.actors.mapValues { actor in
              .object([
                "identity": .string(actor.identity.uuidString),
                "presence": .string(actor.presence.rawValue),
                "energy": .number(actor.body.energy),
                "position": .array([
                  .number(actor.body.position.x), .number(actor.body.position.y),
                  .number(actor.body.position.z),
                ]),
                "npc": scriptNPCSnapshot(actor.body.scriptNPC),
                "missiles": .integer(Int64(actor.body.missiles)),
              ])
            }),
        ])
      })
  }
  /// Returns a later native result. A saved plan is not an admission receipt.
  mutating func ensureScriptEncounter(
    _ id: String, pack: ScriptPack, state: inout ScriptInstance,
    worldJobAuthorized: Bool = false
  )
    throws -> (String, [String: ScriptValue])
  {
    guard state.outcome == .active || worldJobAuthorized,
      pack.manifest.capabilities.contains("classic-encounters-v2")
        || pack.manifest.capabilities.contains("profiled-encounters-v2"),
      let definition = pack.manifest.encounters?.first(where: { $0.id == id })
    else {
      throw MissionPackError(
        "Declare the classic encounter capability and an exact encounter definition.")
    }
    var plan = state.ownedEncounters[id]
    if plan == nil {
      var actors: [String: ScriptOwnedActor] = [:]
      for spec in definition.actors {
        let identity = ScriptIdentity.uuid(
          "script-actor-v2:\(state.id):\(pack.digest):\(id):\(spec.id)")
        var body = SpaceBody(
          id: -1, hull: spec.hull ?? .cobra, position: .init(spec.x, spec.y, spec.z),
          hostile: spec.hostile)
        if let npcID = spec.npc,
          let definition = pack.manifest.npcs?.first(where: { $0.id == npcID })
        {
          body.scriptNPC = try makeScriptNPC(definition, pack: pack, identity: identity)
          body.energy = definition.energy
          body.missiles = definition.missiles
          body.ecmEnabled = definition.ecm
          body.rotationRate = 0
        }
        body.missionActorID = identity
        body.missionInstanceID = state.id
        actors[spec.id] = ScriptOwnedActor(
          identity: identity, alias: spec.id, body: body, presence: .prepared)
      }
      plan = ScriptOwnedEncounter(
        id: id, galaxy: definition.galaxy, system: definition.system, actors: actors)
    }
    guard var encounter = plan else { throw MissionPackError("Encounter plan was not prepared.") }
    if encounter.admitted {
      return ("encounter.admitted", ["encounter_id": .string(id), "existing": .bool(true)])
    }
    func pending(_ reason: String) -> (String, [String: ScriptValue]) {
      ("encounter.pending", ["encounter_id": .string(id), "reason": .string(reason)])
    }
    state.ownedEncounters[id] = encounter
    guard !docked, definition.galaxy == commander.galaxy, definition.system == commander.system,
      let anchor = scriptAnchor
    else { return pending("Enter the declared system in flight with its main station available.") }
    let proposedBodies = encounter.actors.values.map(\.body)
    guard (bodies + proposedBodies).reduce(0, { $0 + $1.scriptNativeUnits }) <= 1024,
      nextBodyID <= 999_998_000 - encounter.actors.count
    else { return pending("The whole encounter needs more native actor capacity.") }
    var prepared: [SpaceBody] = []
    for alias in encounter.actors.keys.sorted() {
      var body = encounter.actors[alias]!.body
      body.position = anchor.position + anchor.orientation.apply(body.position)
      body.orientation = body.orientation.transformed(by: anchor.orientation)
      guard !body.leavesLocalBubble else {
        return pending("The complete cohort must fit the currently loaded space region.")
      }
      let radius = scriptRadius(body)
      let playerRadius = scriptPlayerMesh.vertices.map(\.length).max() ?? 100
      guard body.position.length > radius + playerRadius + 64 else {
        return pending("An encounter placement overlaps the actual commander hull.")
      }
      for other in bodies + prepared {
        guard (body.position - other.position).length > radius + scriptRadius(other) + 64 else {
          return pending("An encounter placement is obstructed; the saved plan will be retained.")
        }
      }
      body.id = nextBodyID + prepared.count
      prepared.append(body)
    }
    // All placements and capacity were checked before any body becomes visible.
    for body in prepared {
      guard
        let alias = encounter.actors.first(where: { $0.value.identity == body.missionActorID })?.key
      else {
        throw MissionPackError("Encounter identity mapping changed during admission.")
      }
      encounter.actors[alias]?.body.id = body.id
      encounter.actors[alias]?.presence = .present
    }
    encounter.admitted = true
    state.ownedEncounters[id] = encounter
    bodies.append(contentsOf: prepared)
    nextBodyID += prepared.count
    return (
      "encounter.admitted",
      [
        "encounter_id": .string(id), "count": .integer(Int64(prepared.count)),
        "existing": .bool(false),
      ]
    )
  }
  /// Native facts retain canonical location/condition and never infer death from disappearance.
  mutating func persistScriptActors(unloading: Bool = false) {
    guard !commander.scriptState.instances.isEmpty else { return }
    if let actual = bodies.first(where: { $0.id == 0 && $0.hull == .station }) {
      if actual.energy <= 0 { recordScriptWorldResourceLoss(actual) }
      if commander.scriptState.stationResources[contractStation.key] != nil {
        commander.scriptState.stationResources[contractStation.key]?.energy = max(0, actual.energy)
      }
      scriptReferenceFrame = ScriptReferenceFrame(
        galaxy: commander.galaxy, system: commander.system, station: actual)
    }
    guard let anchor = scriptAnchor else { return }
    persistScriptShots(anchor: anchor, unloading: unloading)
    if unloading {
      for body in bodies where body.missionActorID != nil && body.energy <= 0 {
        recordScriptActorRemoval(body, destroyed: true)
      }
    }
    let actual = Dictionary(
      bodies.compactMap { body in body.missionActorID.map { ($0, body) } },
      uniquingKeysWith: { first, _ in first })
    for instanceID in commander.scriptState.instances.keys {
      guard var instance = commander.scriptState.instances[instanceID] else { continue }
      for encounterID in instance.ownedEncounters.keys {
        guard var encounter = instance.ownedEncounters[encounterID], encounter.admitted,
          encounter.galaxy == commander.galaxy, encounter.system == commander.system
        else { continue }
        for alias in encounter.actors.keys {
          guard var saved = encounter.actors[alias], saved.presence != .destroyed,
            let body = actual[saved.identity], body.missionInstanceID == instanceID
          else { continue }
          saved.body = body
          saved.body.energy = max(0, body.energy)
          saved.body.position = anchor.orientation.inverse(body.position - anchor.position)
          saved.body.orientation = body.orientation.relative(to: anchor.orientation)
          saved.body.scriptNPC?.velocity = anchor.orientation.inverse(
            body.scriptNPC?.velocity ?? .init(0, 0, 0))
          if unloading && saved.presence == .present { saved.presence = .unloaded }
          encounter.actors[alias] = saved
        }
        instance.ownedEncounters[encounterID] = encounter
      }
      commander.scriptState.instances[instanceID] = instance
    }
  }
  /// Reprojects the same world actor after genuine native launch/arrival/camera travel.
  mutating func restoreScriptActors() {
    guard !commander.scriptState.instances.isEmpty, !docked, let anchor = scriptAnchor else {
      return
    }
    if !bodies.contains(where: { $0.id == 0 }), !anchor.leavesLocalBubble, bodies.count < 1024 {
      bodies.append(anchor)
    }
    var present = Set(bodies.compactMap(\.missionActorID))
    for instanceID in commander.scriptState.instances.keys.sorted(by: {
      $0.uuidString < $1.uuidString
    }) {
      guard var instance = commander.scriptState.instances[instanceID],
        scriptPack(for: instance) != nil
      else { continue }
      for encounterID in instance.ownedEncounters.keys.sorted() {
        guard var encounter = instance.ownedEncounters[encounterID], encounter.admitted,
          encounter.galaxy == commander.galaxy, encounter.system == commander.system
        else { continue }
        for alias in encounter.actors.keys.sorted() {
          guard var actor = encounter.actors[alias], actor.presence != .destroyed,
            actor.presence != .prepared, !present.contains(actor.identity),
            bodies.reduce(0, { $0 + $1.scriptNativeUnits }) + actor.body.scriptNativeUnits <= 1024,
            nextBodyID < 999_999_999
          else { continue }
          var body = actor.body
          body.position = anchor.position + anchor.orientation.apply(body.position)
          body.orientation = body.orientation.transformed(by: anchor.orientation)
          if let velocity = body.scriptNPC?.velocity {
            body.scriptNPC?.velocity = anchor.orientation.apply(velocity)
          }
          guard !body.leavesLocalBubble, body.energy > 0 else { continue }
          // Integer scene IDs may change, but world identity, condition and spent stock never do.
          body.id = nextBodyID
          nextBodyID += 1
          bodies.append(body)
          present.insert(actor.identity)
          actor.body.id = body.id
          actor.presence = .present
          encounter.actors[alias] = actor
        }
        instance.ownedEncounters[encounterID] = encounter
      }
      commander.scriptState.instances[instanceID] = instance
    }
    restoreScriptShots(anchor: anchor)
  }
  mutating func recordScriptActorRemoval(_ body: SpaceBody, destroyed: Bool) {
    if destroyed { recordScriptWorldResourceLoss(body) }
    recordScriptShotRemoval(body)
    guard let identity = body.missionActorID, let instanceID = body.missionInstanceID,
      var instance = commander.scriptState.instances[instanceID]
    else { return }
    for key in instance.ownedEncounters.keys.sorted() {
      guard var encounter = instance.ownedEncounters[key], encounter.admitted,
        let alias = encounter.actors.first(where: { $0.value.identity == identity })?.key,
        var actor = encounter.actors[alias], actor.presence == .present, actor.body.id == body.id
      else { continue }
      if destroyed {
        guard body.energy <= 0 else { return }
        actor.presence = .destroyed
        actor.body.energy = 0
        actor.destroyedByPlayer = body.destroyedByPlayer == true
      } else {
        actor.presence = .outside
      }
      encounter.actors[alias] = actor
      instance.ownedEncounters[key] = encounter
      commander.scriptState.instances[instanceID] = instance
      emitScriptEvent(
        destroyed ? "actor.destroyed" : "actor.removed",
        values: [
          "actor_id": .string(identity.uuidString), "alias": .string(alias),
          "encounter_id": .string(key),
          "destroyed_by_player": .bool(body.destroyedByPlayer == true),
        ], only: instanceID, drain: false)
      return
    }
  }
}
