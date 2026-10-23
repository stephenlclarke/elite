import Foundation

/// Only this file's actual post-motion producer can create a pending scoop contact.
final class NativeCrewLogPickupPending: Sendable {
  let capture: NativeCrewLogCapture
  fileprivate init(_ capture: NativeCrewLogCapture) { self.capture = capture }
}

extension NativeInductionCrewLogPack {
  static func marker(_ body: borrowing SpaceBody, commander: borrowing Commander) -> Bool {
    guard let job = markerJob(body) else { return false }
    return marker(job: job, commander: commander)
  }

  static func markerJob(_ body: borrowing SpaceBody) -> UUID? {
    guard let job = body.missionInstanceID, let logical = body.missionActorID,
      logical == actor(job: job, role: .recorder)
    else { return nil }
    return job
  }

  static func marker(job: UUID, commander: borrowing Commander) -> Bool {
    guard let child = commander.scriptState.instances[job], child.definition == stateID,
      child.digest == digest, child.savedNativeCrewLog?.authorization.job == job
    else { return false }
    return true
  }
  static func consumed(_ logical: UUID, commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains {
      $0.savedNativeCrewLog?.capture != nil && logical == actor(job: $0.id, role: .recorder)
        && $0.definition == stateID && $0.digest == digest
    }
  }
}

extension Game {
  var inductionCrewLogChild: ScriptInstance? {
    guard let parent = wayfarerInductionMission?.savedWayfarerInduction,
      parent.seedReception != nil
    else { return nil }
    let manifest = NativeInductionCrewLogManifest(permission: parent.permission)
    return commander.scriptState.instances[
      NativeInductionCrewLogPack.instance(recorder: manifest.recorder)]
  }

  /// Exact current native address and owning retained alias, never a selected name or serial alone.
  @inline(never)
  func inductionCrewLogRecorder(_ body: borrowing SpaceBody) -> ScriptOwnedActor? {
    guard let job = NativeInductionCrewLogPack.markerJob(body) else { return nil }
    return inductionCrewLogRecorderAtMarkerAddress(body, job: job)
  }

  // Body-only refusal must finish before entering any Commander-reading frame.
  @inline(never)
  private func inductionCrewLogRecorderAtMarkerAddress(_ body: borrowing SpaceBody, job: UUID)
    -> ScriptOwnedActor?
  {
    guard withReadOnlyCommander({ NativeInductionCrewLogPack.marker(job: job, commander: $0) })
    else { return nil }
    return inductionCrewLogRecorderAfterMarker(body)
  }

  // Ordinary targets must reject before reserving the full present-validation frame.
  @inline(never)
  private func inductionCrewLogRecorderAfterMarker(_ body: borrowing SpaceBody) -> ScriptOwnedActor?
  {
    guard let child = inductionCrewLogChild, child.outcome == .active, child.suspension == nil,
      let state = child.savedNativeCrewLog, state.admission != nil, state.capture == nil,
      !state.losses.contains(where: { $0.role == "recorder" }),
      let group = child.ownedEncounters[NativeInductionCrewLogPack.encounter], group.admitted,
      var original = group.actors["recorder"], original.presence == .present,
      original.identity == body.missionActorID, original.body.id == body.id,
      body.missionInstanceID == child.id, body.energy > 0, !body.hostile,
      let physical = body.physical, physical.identity.system == systemIdentity,
      physical.identity.system == NativeInductionCrewLogSource.location,
      physical.identity.visit == commander.flightSimulation.visit,
      physical.identity.entity > 1, physical.identity.entity < commander.flightSimulation.nextActor,
      original.body.physical?.identity == physical.identity,
      physical.population == .mission, physical.npc?.role == .mission,
      body.scriptNPC?.fit.definition == NativeInductionCrewLogSource.recorderProfile(),
      body.scriptNPC?.fit.models == [
        NativeInductionCrewLogSource.recorderModel: NativeInductionCrewLogSource.recorderGeometry
      ]
    else { return nil }
    original.body = copy body
    return original
  }

  func inductionCrewLogCompatibleMesh(_ body: SpaceBody) -> Mesh? {
    guard inductionCrewLogRecorder(body) != nil else { return nil }
    return scriptNPCMesh(body)
  }

  fileprivate func inductionCrewLogSeal(startTime: Double) -> NativeCrewLogPickupPending? {
    guard !docked, !paused, screen.isFlight, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      let child = inductionCrewLogChild, let state = child.savedNativeCrewLog,
      let admission = state.admission, state.capture == nil,
      startTime >= admission.physicalTime,
      let context = gameplayContext(), let collector = commander.flightSimulation.player,
      collector == context.player.identity,
      let purchase = try? commander.purchaseSnapshot(),
      let scoops = commander.fittedEquipment(at: .utility(.fuelScoops)),
      let scoop = purchase.items.first(where: { $0.id == scoops.id }),
      scoop.location?.hull == purchase.activeHull,
      commander.tradeCargoCapacity - commander.cargoTonnes >= 1
    else { return nil }
    for body in bodies {
      guard let marker = inductionCrewLogRecorder(body),
        let mesh = scriptNPCMesh(body), let physical = body.physical,
        physical.velocity.finite, physical.angularVelocity.finite, flightWorldVelocity.finite,
        let radius = mesh.vertices.map(\.length).max()
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
      guard NativeCrewLogCapture.approachAllowed(point: body.position, radius: radius, speed: speed)
      else { continue }
      let capture = NativeCrewLogCapture(
        issue: state.authorization.operation, original: state.authorization.manifest.recorder,
        job: child.id,
        operation: NativeCrewLogCapture.identity(
          issue: state.authorization.operation, original: state.authorization.manifest.recorder),
        sequence: 0, actor: physical.identity, collector: collector,
        carrier: purchase.activeHull, inventoryRevision: purchase.revision,
        scoop: scoop, marker: marker, capturePoint: body.position, relativeSpeed: speed,
        radius: radius, startTime: startTime, physicalTime: context.physicalTime,
        flightSeconds: commander.scriptState.flightSeconds, epoch: nativeStationRuntimeEpoch)
      return .init(capture)
    }
    return nil
  }

  @discardableResult
  @inline(never)
  mutating func retryInductionCrewLogCapture() throws -> Bool {
    guard let pending = nativeCrewLogPickupPending else { return false }
    return try retryPresentInductionCrewLogCapture(pending)
  }

  @inline(never)
  private mutating func retryPresentInductionCrewLogCapture(
    _ pending: NativeCrewLogPickupPending
  ) throws -> Bool {
    let contact = pending.capture
    guard !docked, energy.isFinite, energy > 0, screen != .gameOver,
      var child = commander.scriptState.instances[contact.job],
      var state = child.savedNativeCrewLog, state.capture == nil,
      var parent = commander.scriptState.instances[state.authorization.manifest.mission],
      let leaf = parent.savedWayfarerInduction, leaf.crewLog == nil,
      contact.issue == state.authorization.operation,
      commander.flightSimulation.player == contact.collector,
      commander.hullInstanceID == contact.carrier,
      commander.equipmentInventory?.revision == contact.inventoryRevision,
      commander.fittedEquipment(at: .utility(.fuelScoops))?.id == contact.scoop.id,
      (try? commander.purchaseSnapshot().items.contains(contact.scoop)) == true,
      nativeStationRuntimeEpoch == contact.epoch,
      let index = bodies.firstIndex(where: { $0.physical?.identity == contact.actor }),
      inductionCrewLogRecorder(bodies[index]) != nil,
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else {
      nativeCrewLogPickupPending = nil
      return false
    }
    let sequence = commander.scriptState.nextEvent + 1
    let capture = contact.sequenced(sequence)
    let nextParent = try leaf.collectingCrewLog(
      capture, freeTonnes: commander.tradeCargoCapacity - commander.cargoTonnes)
    state.capture = capture
    guard state.shapeValid(parent: nextParent) else { throw SaveError.invalidCommander }
    parent.savedWayfarerInduction = nextParent
    parent.payloads = nextParent.payloads
    parent.milestones = nextParent.milestones
    parent.acknowledge(sequence)
    parent.revision += 1
    parent.journal.append(
      "Recovered the original Cevilis crew custody recorder. Its protected tonne identifies the two original launch occupants and Enmadan shelter; no people boarded, hull/equipment changed, rescue arrival, reward or accreditation was granted."
    )
    child.savedNativeCrewLog = state
    child.milestones = [0]
    child.acknowledge(sequence)
    child.revision += 1
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    let body = bodies[index]
    recordScriptActorRemoval(body, destroyed: false)
    workTargetCollected(body)
    bodies.remove(at: index)
    nativeCrewLogPickupPending = nil
    return true
  }
}

extension GameRuntime {
  func commitInductionCrewLogCapture(startTime: Double, startPlayer: ActorIdentity?) {
    guard startPlayer == game.commander.flightSimulation.player,
      game.inductionCrewLogChild?.savedNativeCrewLog != nil,
      game.commander.flightSimulation.physicalTime > startTime,
      game.commander.flightSimulation.physicalTime - startTime <= 0.1 + 1e-9
    else { return }
    if game.nativeCrewLogPickupPending == nil {
      game.nativeCrewLogPickupPending = game.inductionCrewLogSeal(startTime: startTime)
    }
    guard game.nativeCrewLogPickupPending != nil, let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      guard try candidate.retryInductionCrewLogCapture() else {
        game.nativeCrewLogPickupPending = nil
        return
      }
      try publish(&candidate)
      game = candidate
      game.notify("ORIGINAL CREW RECORDER ABOARD - 1T PROTECTED / ENMADAN SHELTER")
    } catch { game.notify("ORIGINAL RECORDER NOT SAVED - SAVE TO RETRY THE SAME PICKUP") }
  }
}
