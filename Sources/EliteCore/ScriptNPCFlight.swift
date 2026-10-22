import Foundation

extension Game {
  mutating func applyScriptNPCIntent(
    _ command: ScriptValue, pack: ScriptPack, state: inout ScriptInstance
  ) throws -> (String, [String: ScriptValue])? {
    guard pack.manifest.capabilities.contains("profiled-encounters-v2"), state.outcome == .active,
      let fields = command.object,
      Set(fields.keys).isSubset(of: [
        "op", "id", "encounter", "actor", "mode", "target", "offset", "speed", "tolerance",
      ]),
      let request = fields["id"]?.string, PackValidation.localID(request),
      let encounterID = fields["encounter"]?.string, let alias = fields["actor"]?.string,
      let modeName = fields["mode"]?.string, let mode = ScriptNPCIntentMode(rawValue: modeName),
      let speed = fields["speed"]?.double, let tolerance = fields["tolerance"]?.double,
      let coordinates = fields["offset"]?.array, coordinates.count == 3,
      let x = coordinates[0].double, let y = coordinates[1].double, let z = coordinates[2].double,
      var encounter = state.ownedEncounters[encounterID], var actor = encounter.actors[alias],
      ![.destroyed, .inTransit, .arrivalPending].contains(actor.presence),
      var npc = actor.body.scriptNPC
    else { throw MissionPackError("A flight request requires a declared owned profiled NPC.") }
    let receipt = "intent-" + request
    if state.receipts.contains(receipt) { return nil }
    let targetName = fields["target"]?.string
    let player = targetName == "player"
    var target: UUID?
    if let targetName, !player {
      let candidates = state.ownedEncounters.values.flatMap { $0.actors.values }.filter {
        $0.alias == targetName && $0.identity != actor.identity && $0.presence != .destroyed
      }
      guard candidates.count == 1 else {
        throw MissionPackError("Flight targets must identify one distinct owned actor or player.")
      }
      target = candidates[0].identity
    }
    let intent = ScriptNPCIntent(
      request: request, mode: mode, target: target, player: player,
      offset: .init(x, y, z), speed: speed, tolerance: tolerance)
    guard intent.valid else { throw MissionPackError("Invalid flight intent or target.") }
    npc.intent = intent
    actor.body.scriptNPC = npc
    encounter.actors[alias] = actor
    state.ownedEncounters[encounterID] = encounter
    if let index = bodies.firstIndex(where: { $0.missionActorID == actor.identity }) {
      bodies[index].scriptNPC?.intent = intent
    }
    state.receipts.insert(receipt)
    return (
      "actor.intent.accepted",
      [
        "actor_id": .string(actor.identity.uuidString),
        "request": .string(request), "mode": .string(mode.rawValue),
      ]
    )
  }

  /// All actors observe the same post-camera snapshot; array order cannot change steering.
  mutating func advanceScriptNPCFlight(delta: Double) {
    let snapshot = bodies
    let owned = Dictionary(
      snapshot.compactMap { body in
        body.missionActorID.map { ($0, body) }
      }, uniquingKeysWith: { first, _ in first })
    let station = snapshot.first { $0.id == 0 && $0.hull == .station }
    for index in bodies.indices {
      observeNativeTransitSpool(bodies[index])
      guard bodies[index].energy > 0, var npc = bodies[index].scriptNPC else { continue }
      let definition = npc.fit.definition
      // C01 propulsion stays disabled; physical contact momentum still moves the original hull.
      if c01SurveyorActor(bodies[index]) != nil, let physical = bodies[index].physical {
        bodies[index].position =
          bodies[index].position
          + commander.flightSimulation.pose.shipVector(physical.velocity) * delta
        continue
      }
      if bodies[index].physical?.npc?.resources?.profile != .nativeHull {
        bodies[index].energy = min(
          definition.energy, bodies[index].energy + definition.recharge * delta)
      }
      var desired = Vector3(0, 0, 0)
      if let guidance = inductionArkDockGuidance(bodies[index], profile: definition, delta: delta)
        ?? inductionRescueDockGuidance(bodies[index], profile: definition, delta: delta)
      {
        bodies[index].orientation = guidance.orientation
        desired = guidance.desired
      } else {
        if npc.intent == nil, let goal = nativeTransitExitClearanceGoal(bodies[index]) {
          let offset = goal - bodies[index].position
          if offset.length > 1e-6 {
            bodies[index].orientation = Self.steerScriptNPC(
              bodies[index].orientation, toward: offset, profile: definition, delta: delta)
            desired =
              bodies[index].orientation.z
              * min(
                definition.speed,
                sqrt(2 * definition.acceleration * offset.length))
          }
        }
        if var intent = npc.intent {
          intent = nativeTransitSteeringIntent(bodies[index], intent: intent)
          let transitGoal = nativeTransitSteeringGoal(bodies[index], intent: intent)
          var goal: Vector3?
          var targetVelocity = Vector3(0, 0, 0)
          if intent.mode == .hold {
            goal = bodies[index].position
          } else if intent.mode == .approach, let station {
            goal =
              transitGoal
              ?? (station.position + station.orientation.apply(intent.offset))
          } else if intent.player {
            goal = intent.offset
          } else if let identity = intent.target, let target = owned[identity], target.energy > 0 {
            goal = target.position + target.modelVector(intent.offset)
            targetVelocity = target.scriptNPC?.velocity ?? .init(0, 0, 0)
          }
          if let goal {
            let offset = goal - bodies[index].position
            let aim = intent.mode == .flee ? offset * -1 : offset
            if intent.mode != .hold && aim.length > 1e-6 {
              bodies[index].orientation = Self.steerScriptNPC(
                bodies[index].orientation, toward: aim, profile: definition, delta: delta)
            }
            var speed = definition.speed * intent.speed
            if transitGoal != nil && aim.length > 1e-6
              && bodies[index].orientation.z.dot(aim.unit) < 0.98
            {
              speed = 0
            }
            if [.hold, .approach, .follow].contains(intent.mode) {
              speed = min(
                speed, sqrt(2 * definition.acceleration * max(0, offset.length - intent.tolerance)))
            }
            desired = bodies[index].orientation.z * speed
            if intent.mode == .follow { desired = desired + targetVelocity }
            desired = desired.limited(to: definition.speed)
            if intent.status == .requested && [.hold, .approach, .follow].contains(intent.mode)
              && transitGoal == nil
              && offset.length <= intent.tolerance && (npc.velocity - targetVelocity).length < 1
            {
              intent.status = .reached
              emitScriptNPCFlightResult(bodies[index], intent: intent, kind: "actor.arrived")
            }
          } else if intent.status != .lost {
            intent.status = .lost
            emitScriptNPCFlightResult(bodies[index], intent: intent, kind: "actor.target.lost")
          }
          npc.intent = intent
        }
      }
      npc.velocity =
        npc.velocity + (desired - npc.velocity).limited(to: definition.acceleration * delta)
      bodies[index].position = bodies[index].position + npc.velocity * delta
      bodies[index].scriptNPC = npc
    }
    resolveInductionArkDockMotion(before: snapshot, delta: delta)
    resolveNativeTransitMotion(before: snapshot, delta: delta)
  }
  private static func steerScriptNPC(
    _ basis: Basis3, toward vector: Vector3, profile: ScriptNPCDefinition, delta: Double
  ) -> Basis3 {
    let local = basis.inverse(vector)
    let pitch = max(
      -profile.pitch * delta,
      min(
        profile.pitch * delta,
        -atan2(local.y, hypot(local.x, local.z))))
    let yaw = max(-profile.yaw * delta, min(profile.yaw * delta, -atan2(local.x, local.z)))
    var step = Basis3()
    step.rotate(pitch: pitch, roll: 0, yaw: yaw)
    return step.transformed(by: basis)
  }
  private mutating func emitScriptNPCFlightResult(
    _ body: SpaceBody, intent: ScriptNPCIntent, kind: String
  ) {
    guard let actor = body.missionActorID, let instance = body.missionInstanceID else { return }
    emitScriptEvent(
      kind,
      values: [
        "actor_id": .string(actor.uuidString),
        "request": .string(intent.request), "mode": .string(intent.mode.rawValue),
      ],
      only: instance, drain: false)
  }
}
