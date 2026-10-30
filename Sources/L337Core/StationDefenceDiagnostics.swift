import Foundation

/// Opt-in observations of this common accepted-combat path only, never gameplay authority.
struct GameplayCombatTrace: Sendable {
  let epoch = UUID()
  private(set) var incidents: [CombatIncident] = []
  private(set) var dropped = 0

  mutating func append(_ incident: CombatIncident) {
    incidents.append(incident)
    if incidents.count > 128 {
      dropped += incidents.count - 128
      incidents.removeFirst(incidents.count - 128)
    }
  }
}

/// Immutable bounded observations. No Game or Commander is retained by a diagnostic consumer.
struct StationDefenceDiagnosticSnapshot: Sendable {
  let physicalTime: Double
  let scalars: [String: String]
  let combat: GameplayCombatTrace
  let audioEpoch: UUID
  let audio: [DischargeAudioEvent]
  let firstEntryCourse: [String: String]?
  let firstEntryCourseRefusal: [String: String]?
}

extension GameRuntime {
  /// Private test diagnostics opt in explicitly; ordinary runtimes keep the recorder absent.
  func enableStationDefenceDiagnostics() {
    if game.gameplayCombatTrace == nil { game.gameplayCombatTrace = .init() }
  }
}

extension Game {
  func stationDefenceDiagnosticSnapshot() -> StationDefenceDiagnosticSnapshot? {
    guard let trace = gameplayCombatTrace else { return nil }
    func vector(_ value: Vector3) -> String { "\(value.x),\(value.y),\(value.z)" }
    func actor(_ value: ActorIdentity?) -> String {
      guard let value else { return "nil" }
      return "\(value.system.galaxy)/\(value.system.system)/\(value.visit)/\(value.entity)"
    }
    let flight = commander.flightSimulation
    let station = autoTargetBody
    let combatActor = stationAutoDefence?.combatActor
    let combat = bodies.first { $0.physical?.identity == combatActor && combatActor != nil }
    let stationMesh = station.map { gameplayMeshOverrides[$0.id] ?? Mesh.hull($0.hull) }
    let radius = stationMesh?.vertices.map(\.length).max() ?? .infinity
    let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? .infinity
    let clearance = max(station?.stationClearanceRadius ?? .infinity, radius + playerRadius)
    let inward = station.map { max(0, autoPilot.velocity.dot($0.position.unit)) } ?? .nan
    let stopping = inward * inward / (2 * workLimits.acceleration) + inward * 0.1
    let context = gameplayContext()
    let attack = combatActor.flatMap { source in
      context.map {
        commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: source, against: $0.player.identity, context: $0)
      }
    }
    var values: [String: String] = [
      "revision": String(gameplayRevision), "time": String(flight.physicalTime),
      "player": actor(flight.player), "destination": actor(autoPilot.targetActor),
      "positionWorld": vector(flight.pose.position), "velocityWorld": vector(flightWorldVelocity),
      "velocityLocal": vector(autoPilot.velocity), "scalarSpeed": String(speed),
      "phase": String(describing: autoPilot.stationDefencePhase), "status": autoPilot.status,
      "ready": String(autoPilot.ready), "final": String(autoPilot.finalApproach),
      "goalError": String(autoPilot.positionError), "facingError": String(autoPilot.facingError),
      "spinPhaseError": String(autoPilot.phaseError), "spinRateError": String(autoPilot.rateError),
      "pitchYawRoll": vector(.init(pitch, yaw, roll)), "combatActor": actor(combatActor),
      "combatPositionLocal": combat.map { vector($0.position) } ?? "nil",
      "combatEnergy": combat.map { String($0.energy) } ?? "nil",
      "combatIntention": combat?.physical?.npc.map { String(describing: $0.intention) } ?? "nil",
      "combatCurrentUnlawfulAttack": attack.map { String($0) } ?? "unavailable",
      "combatActorBodyCount": String(
        bodies.filter { $0.physical?.identity == combatActor && combatActor != nil }.count),
      "combatResourcesEMPMarkerSalvageScript":
        "\(combat?.physical?.npc?.resources?.valid ?? false),\(combat.map { isEMPDisabled($0) } ?? false),\(combat?.physical?.empSource != nil),\(combat?.physical?.salvage != nil),\(combat?.scriptNPC != nil)",
      "combatBearingObserved": combat.map {
        "\(atan2($0.position.y, hypot($0.position.x, $0.position.z))),\(atan2($0.position.x, $0.position.z))"
      } ?? "nil",
      "energyShields": vector(.init(energy, frontShield, rearShield)),
      "heatCooldown": "\(laserHeat),\(fireCooldown)",
      "EMPWorkSuspended": "\(playerEMPDisabled),\(workFireSuspended)",
      "ECMFittedField":
        "\(commander.fittedEquipment(at: .utility(.ecm)) != nil),\(ecmControl.fieldActive)",
      "missilesStockCooldown": "\(commander.missiles),\(missileCooldown)",
      "missilePublicationRefused": String(stationAutoDefence?.missilePublicationRefused ?? false),
      "pendingEntry": String(pendingNativeStationDock != nil),
      "stationContainsPlayer": station.map { String($0.containsPlayer) } ?? "nil",
      "stationRangeClearanceStopping":
        "\(station?.position.length ?? .nan),\(clearance),\(stopping)",
      "evasionWorld": stationAutoDefence?.evasionWorld.map { vector($0) } ?? "nil",
    ]
    for mount in LaserMount.allCases {
      let direction: Vector3
      switch mount {
      case .front: direction = .init(0, 0, 1)
      case .rear: direction = .init(0, 0, -1)
      case .left: direction = .init(-1, 0, 0)
      case .right: direction = .init(1, 0, 0)
      }
      let key = "prospectiveMount_" + mount.rawValue
      let laser = commander.laser(on: mount).map { String(describing: $0) } ?? "none"
      do {
        guard
          let contact = try nearestMissionCollision(
            from: .init(0, 0, 0), direction: direction, range: 6000, radius: 0,
            excludingBodyIDs: [], includePlayer: false)
        else {
          values[key] = laser + "/no-contact"
          continue
        }
        let target = contact.selectedTargetBody
        let identity = target?.physical?.identity
        let law = identity.flatMap { victim in
          context.map {
            commander.crimeLedger.permitsAutonomousDefence(
              owner: $0.player.identity, victim: victim, context: $0)
          }
        }
        values[key] =
          "\(laser)/\(actor(identity))/\(contact.hit.distance)/law:\(law.map { String($0) } ?? "unknown")/emp:\(target.map { isEMPDisabled($0) } ?? false)/resources:\(target?.physical?.npc?.resources?.valid ?? false)"
      } catch { values[key] = laser + "/query-error" }
    }
    return .init(
      physicalTime: flight.physicalTime, scalars: values, combat: trace,
      audioEpoch: dischargeAudio.epoch, audio: dischargeAudio.events,
      firstEntryCourse: stationAutoDefence?.firstEntryCourseObservation,
      firstEntryCourseRefusal: stationAutoDefence?.firstEntryCourseRefusalObservation)
  }
}
