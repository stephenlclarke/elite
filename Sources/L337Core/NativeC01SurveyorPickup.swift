import Foundation

/// Only the post-motion producer in this file can seal a current original-recorder contact.
final class NativeC01SurveyorPending: Sendable {
  let capture: NativeC01SurveyorCapture
  fileprivate init(_ capture: NativeC01SurveyorCapture) { self.capture = capture }
}

extension Game {
  fileprivate func sealC01SurveyorCapture(startTime: Double) -> NativeC01SurveyorPending? {
    guard !docked, !paused, screen.isFlight, !playerEMPDisabled, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian,
      let surveyor = state.surveyor, surveyor.capture == nil, surveyor.loss == nil,
      let player = commander.flightSimulation.player,
      let purchase = try? commander.purchaseSnapshot(),
      let fitted = commander.fittedEquipment(at: .utility(.fuelScoops)),
      let scoop = purchase.items.first(where: { $0.id == fitted.id }),
      scoop.location?.hull == purchase.activeHull,
      startTime >= surveyor.source.physicalTime,
      commander.flightSimulation.physicalTime > startTime,
      commander.flightSimulation.physicalTime - startTime <= 0.1 + 1e-9
    else { return nil }
    let radius = NativeC01SurveyorGeometry.recorder.rawMesh.vertices.map(\.length).max()!
    for body in bodies {
      guard let marker = c01SurveyorActor(body), marker.alias == NativeC01Surveyor.aliases[1],
        body.energy > 0, let physical = body.physical,
        physical.velocity.finite, physical.angularVelocity.finite, flightWorldVelocity.finite
      else { continue }
      if let work = workGuidance {
        guard work.parent == physical.identity, work.mode == .autoScoop(.salvage),
          lastAppliedWorkMotion?.end == commander.flightSimulation.pose
        else { continue }
      }
      let omega =
        workGuidance != nil || workBraking != nil
        ? lastAppliedWorkMotion?.worldAngularVelocity.length ?? 0
        : abs(pitch) + abs(yaw) + abs(roll)
      let speed =
        (physical.velocity - flightWorldVelocity).length
        + omega * Vector3(0, -45, 55).length + physical.angularVelocity.length * radius
      guard NativeC01Surveyor.approachAllowed(point: body.position, radius: radius, speed: speed)
      else { continue }
      let capture = NativeC01SurveyorCapture(
        operation: NativeC01Surveyor.captureOperation(permission: state.permission.operation),
        marker: marker, collector: player, carrier: purchase.activeHull,
        inventoryRevision: purchase.revision, scoop: scoop,
        capturePoint: body.position, relativeSpeed: speed, startTime: startTime,
        physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
      var projected = state
      projected.surveyor?.capture = capture
      guard NativeC01Surveyor.shapeValid(projected) else { continue }
      return .init(capture)
    }
    return nil
  }

  fileprivate mutating func applyC01SurveyorCapture() throws -> Bool {
    guard let pending = nativeC01SurveyorPending else { return false }
    let capture = pending.capture
    guard var mission = glassMeridianMission, mission.outcome == .active, mission.suspension == nil,
      var state = mission.savedGlassMeridian, state.surveyor?.capture == nil,
      state.surveyor?.loss == nil, !docked, energy > 0, screen.isFlight,
      capture.epoch == nativeStationRuntimeEpoch,
      commander.flightSimulation.player == capture.collector,
      commander.hullInstanceID == capture.carrier,
      commander.equipmentInventory?.revision == capture.inventoryRevision,
      commander.fittedEquipment(at: .utility(.fuelScoops))?.id == capture.scoop.id,
      (try? commander.purchaseSnapshot().items.contains(capture.scoop)) == true,
      let index = bodies.firstIndex(where: {
        $0.physical?.identity == capture.marker.body.physical?.identity
      }),
      let current = c01SurveyorActor(bodies[index]), current.identity == capture.marker.identity,
      current.body.energy > 0, mission.revision < UInt64(Int64.max) - 1
    else {
      nativeC01SurveyorPending = nil
      return false
    }
    state.surveyor?.capture = capture
    guard NativeC01Surveyor.shapeValid(state) else { throw SaveError.invalidCommander }
    mission.savedGlassMeridian = state
    mission.milestones.insert(2)
    mission.revision += 1
    mission.journal.append(
      state.reservationCase == nil
        ? "Recovered the original Glass Meridian flight recorder: 8kg protected custody. Navidor Harrier source retained. Stage four audit, payment and final clue remain unavailable."
        : "Recovered the original Glass Meridian flight recorder: 8kg protected custody. Visit Captain Orin Sorel at Enmadan's main orbital to compare the original bookings. No payment or final clue."
    )
    commander.scriptState.instances[mission.id] = mission
    guard let tonnes = commander.checkedCargoTonnes, tonnes <= commander.tradeCargoCapacity else {
      throw MissionPackError("The original 8kg recorder does not fit the actual hold.")
    }
    let body = bodies[index]
    recordScriptActorRemoval(body, destroyed: false)
    workTargetCollected(body)
    bodies.remove(at: index)
    nativeC01SurveyorPending = nil
    return true
  }

  mutating func loseC01SurveyorOnEscape(_ pod: EquipmentPurchaseItem?) throws {
    guard glassMeridianMission?.savedGlassMeridian?.surveyor?.held == true else { return }
    guard let pod else { throw SaveError.invalidCommander }
    guard try recordC01SurveyorLoss(escapePod: pod) else { throw SaveError.invalidCommander }
  }

  @discardableResult
  mutating func recordC01SurveyorLoss(escapePod: EquipmentPurchaseItem? = nil) throws -> Bool {
    guard var mission = glassMeridianMission, var state = mission.savedGlassMeridian,
      let surveyor = state.surveyor, surveyor.loss == nil,
      let collector = commander.flightSimulation.player, let carrier = commander.hullInstanceID
    else { return false }
    let loss: NativeC01SurveyorLoss
    if surveyor.held, let pod = escapePod {
      guard energy > 0, !docked, pod.node.key == "Escape Pod",
        pod.location?.hull == carrier,
        commander.equipmentInventory?.items.contains(where: { $0.id == pod.id }) == false
      else { throw SaveError.invalidCommander }
      loss = .init(
        kind: .escape, marker: nil, collector: collector, carrier: carrier,
        energy: energy, escapePod: pod, physicalTime: commander.flightSimulation.physicalTime)
    } else if surveyor.held, screen == .gameOver, energy.isFinite, energy <= 0 {
      loss = .init(
        kind: .carrierDestroyed, marker: nil, collector: collector, carrier: carrier,
        energy: energy, escapePod: nil, physicalTime: commander.flightSimulation.physicalTime)
    } else if surveyor.capture == nil,
      let marker = mission.ownedEncounters[NativeC01Surveyor.encounter]?.actors[
        NativeC01Surveyor.aliases[1]],
      marker.presence == .destroyed, marker.body.energy == 0
    {
      loss = .init(
        kind: .recorderDestroyed, marker: marker, collector: collector, carrier: carrier,
        energy: energy, escapePod: nil, physicalTime: commander.flightSimulation.physicalTime)
    } else {
      return false
    }
    guard NativeC01ReservationAuditSave.shapeValid(state) else { throw SaveError.invalidCommander }
    state.surveyor?.loss = loss
    guard NativeC01Surveyor.shapeValid(state) else { throw SaveError.invalidCommander }
    let lossSequence = try observeC01ReservationLoss(state: &state, mission: &mission)
    guard NativeC01ReservationAuditSave.shapeValid(state) else { throw SaveError.invalidCommander }
    mission.savedGlassMeridian = state
    mission.journal.append(
      state.reservationCase?.audit == nil
        ? "Original Glass Meridian recorder lost. This attempt cannot reissue the original."
        : "Original Glass Meridian recorder lost after Sorel's recorded audit. The historical findings remain valid; the original cannot be reissued."
    )
    if let lossSequence { commander.scriptState.nextEvent = lossSequence }
    commander.scriptState.instances[mission.id] = mission
    nativeC01SurveyorPending = nil
    return true
  }
}

extension GameRuntime {
  func commitC01Surveyor(startTime: Double, startPlayer: ActorIdentity?) {
    guard game.glassMeridianMission?.savedGlassMeridian?.readings.count == 2,
      let publish = scriptPublisher()
    else { return }
    if startPlayer == game.commander.flightSimulation.player, game.nativeC01SurveyorPending == nil {
      game.nativeC01SurveyorPending = game.sealC01SurveyorCapture(startTime: startTime)
    }
    var candidate = game
    do {
      let loss = try candidate.recordC01SurveyorLoss()
      let capture = try candidate.applyC01SurveyorCapture()
      let source = try candidate.prepareC01Surveyor()
      guard loss || capture || source else {
        // Revoking a stale transient contact needs no save. A later real ingress can seal anew.
        if candidate.nativeC01SurveyorPending == nil { game.nativeC01SurveyorPending = nil }
        return
      }
      try publish(&candidate)
      game = candidate
      if capture { game.notify("ORIGINAL RECORDER ABOARD - 8KG PROTECTED") }
    } catch { game.notify("GLASS MERIDIAN UPDATE NOT SAVED - ORIGINAL EVIDENCE RETAINED") }
  }
}
