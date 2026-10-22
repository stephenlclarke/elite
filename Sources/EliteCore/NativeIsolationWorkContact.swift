import Foundation

/// Review and arming are deliberately transient. A save never restores either capability.
struct NativeIsolationWorkReview: Equatable, Sendable {
  let nonce: UUID
  let job: UUID
  let contact: NativeIsolationContact
  let authority: NativeIsolationMeasurementAuthority
  let epoch: UUID
}

struct NativeIsolationWorkArm: Equatable, Sendable {
  let nonce: UUID
  let job: UUID
  let authority: NativeIsolationMeasurementAuthority
  let epoch: UUID
}

struct NativeIsolationWorkRuntime: Sendable {
  var contact: ActorIdentity?
  var review: NativeIsolationWorkReview?
  var arm: NativeIsolationWorkArm?
  var dirty = false
  var publishedTime = 0.0
  var reason = "Return reviews isolation work; a fresh Return arms it."
}

/// Only this file's actual mesh query can construct a live measurement endpoint.
struct NativeIsolationWorkEndpoint: Sendable {
  let arm: NativeIsolationWorkArm
  let time: Double
  let range: Double
  let speed: Double
  let aim: Double
  fileprivate init(
    arm: NativeIsolationWorkArm, time: Double, range: Double, speed: Double, aim: Double
  ) {
    self.arm = arm
    self.time = time
    self.range = range
    self.speed = speed
    self.aim = aim
  }
}

extension Game {
  /// Resolves the original logical module to its actual current native body. No targeting grant.
  func isolationWorkRole(_ body: SpaceBody) -> NativeIsolationWorkRole? {
    guard !isMissionTrial, systemIdentity == NativeIsolationWorkSource.location,
      let child = isolationWorkChild, child.suspension == nil,
      let state = child.savedIsolationWork,
      body.missionInstanceID == child.id, body.energy > 0,
      let native = body.physical, native.identity.system == systemIdentity,
      native.identity.visit == commander.flightSimulation.visit,
      native.population == .mission, native.npc?.role == .mission,
      native.npc?.resources?.electrical?.disabledAt == nil,
      let owner = commander.equipmentOwnerID, let fit = body.scriptNPC?.fit,
      NativeIsolationWorkSource(owner: owner).matches(fit),
      let role = NativeIsolationWorkRole.allCases.first(where: {
        body.missionActorID == NativeIsolationWorkPack.actor(job: child.id, role: $0)
      }),
      let module = state.modules.first(where: { $0.role == role }),
      module.loss == nil, module.admission != nil,
      let retained = child.ownedEncounters[NativeIsolationWorkPack.encounter]?.actors[
        role.rawValue],
      retained.identity == body.missionActorID, retained.presence == .present,
      retained.body.id == body.id,
      let binding = try? currentMissionNativeBinding(bodyID: body.id),
      binding.nativeActor == native.identity, binding.instanceID == child.id,
      binding.actorID == retained.identity
    else { return nil }
    return role
  }

  var isolationWorkContactBody: SpaceBody? {
    guard !docked, !paused, screen == .front else { return nil }
    if let actor = isolationWorkRuntime.contact,
      let body = bodies.first(where: { $0.physical?.identity == actor }),
      isolationWorkRole(body) != nil
    {
      return body
    }
    if let body = autoTargetBody, isolationWorkRole(body) != nil { return body }
    return nil
  }

  mutating func cycleIsolationWorkContact() -> Bool {
    guard !docked, !paused, screen.isFlight,
      systemIdentity == NativeIsolationWorkSource.location,
      currentIsolationWorkParentAuthority != nil
    else { return false }
    let available = bodies.filter { isolationWorkRole($0) != nil }.sorted { $0.id < $1.id }
    guard !available.isEmpty else { return false }
    let previous = isolationWorkRuntime.contact
    let index =
      available.firstIndex { $0.physical?.identity == previous }
      .map { ($0 + 1) % available.count } ?? 0
    cancelAutoTarget()
    interruptFlightTool()
    isolationWorkRuntime.contact = available[index].physical?.identity
    screen = .front
    notify("RENAS FEEDER SELECTED - RETURN REVIEWS ISOLATION")
    return true
  }

  public var isolationWorkUsesReturn: Bool {
    guard !docked, !paused, screen == .front,
      systemIdentity == NativeIsolationWorkSource.location
    else { return false }
    return isolationWorkRuntime.review != nil || isolationWorkRuntime.arm != nil
      || (currentIsolationWorkParentAuthority != nil && isolationWorkContactBody != nil)
  }

  mutating func interruptIsolationWork() {
    isolationWorkRuntime.review = nil
    isolationWorkRuntime.arm = nil
    isolationWorkRuntime.reason =
      "Isolation stopped; attained energy transfer and partial work stay."
  }

  /// Apply before command rollback snapshots: a refused combat command must still stop work.
  mutating func prepareIsolationWorkSafetyKey(_ token: String) {
    guard isolationWorkRuntime.arm != nil || isolationWorkRuntime.review != nil,
      ["t", "u", "m", "e", "energy-bomb", "escape-pod"].contains(token.lowercased())
    else { return }
    interruptIsolationWork()
  }

  /// Every endpoint re-reads real parent acceptance, original loan, carrier and native actor binding.
  private func isolationMeasurementAuthority(for body: SpaceBody)
    -> NativeIsolationMeasurementAuthority?
  {
    guard let role = isolationWorkRole(body), let actor = body.physical?.identity,
      let permission = currentIsolationWorkParentAuthority,
      let programmer = try? permission.programmer(in: commander),
      let player = commander.flightSimulation.player
    else { return nil }
    let original = NativeIsolationWorkSource(owner: permission.owner)
    let value = NativeIsolationMeasurementAuthority(
      parent: permission.parentID, authorization: permission.authorization,
      owner: permission.owner, source: original.id, role: role, module: original.module(role),
      issueOperation: permission.issueOperation, programmer: programmer.serial,
      carrier: programmer.hull, inventoryRevision: programmer.inventoryRevision,
      actor: actor, player: player)
    return value.valid ? value : nil
  }

  mutating func handleIsolationWorkKey(_ key: String) -> Bool {
    let pending = isolationWorkRuntime.review != nil || isolationWorkRuntime.arm != nil
    if pending && ["escape", "k", "pause", "pause-toggle"].contains(key) {
      interruptIsolationWork()
      if key == "escape" { return true }
    }
    guard key == "return", isolationWorkUsesReturn else { return false }
    guard scriptDurabilityAvailable, !playerEMPDisabled, energy > 0,
      let body = isolationWorkContactBody, let authority = isolationMeasurementAuthority(for: body),
      let child = isolationWorkChild,
      let module = child.savedIsolationWork?.modules.first(where: { $0.role == authority.role }),
      module.verification == nil
    else {
      interruptIsolationWork()
      notify("ORIGINAL PROGRAMMER OR FEEDER UNAVAILABLE; REVIEW CURRENT CONTACT")
      return true
    }
    if let review = isolationWorkRuntime.review {
      guard review.job == child.id, review.contact == module.contact,
        review.authority == authority, review.epoch == nativeStationRuntimeEpoch
      else {
        interruptIsolationWork()
        notify("ISOLATION TERMS CHANGED - SELECT AND REVIEW AGAIN")
        return true
      }
      cancelAutoTarget()
      interruptFlightTool()
      isolationWorkRuntime.contact = authority.actor
      isolationWorkRuntime.arm = .init(
        nonce: UUID(), job: child.id, authority: authority, epoch: nativeStationRuntimeEpoch)
      isolationWorkRuntime.reason = "ARMED: 20s work, then independently observe 1s zero flow."
      return true
    }
    interruptFlightTool()
    isolationWorkRuntime.contact = authority.actor
    isolationWorkRuntime.review = .init(
      nonce: UUID(), job: child.id, contact: module.contact, authority: authority,
      epoch: nativeStationRuntimeEpoch)
    isolationWorkRuntime.reason =
      "Return confirms arming; Escape cancels. No energy or fee charged."
    return true
  }

  /// Both ends of an attained native step must hit the original outward six-metre mesh face.
  @inline(never)
  func isolationWorkEndpoint() -> NativeIsolationWorkEndpoint? {
    guard !docked, !paused, !isMissionTrial, screen == .front, energy > 0, !playerEMPDisabled,
      isolationWorkStationsAlive,
      let arm = isolationWorkRuntime.arm, arm.epoch == nativeStationRuntimeEpoch,
      let state = isolationWorkChild?.savedIsolationWork,
      let module = state.modules.first(where: { $0.role == arm.authority.role }),
      module.accounts.remainingSupply > 0, module.accounts.headroom > 0,
      let body = bodies.first(where: { $0.physical?.identity == arm.authority.actor }),
      isolationMeasurementAuthority(for: body) == arm.authority,
      let native = body.physical, native.velocity.finite, native.angularVelocity.finite,
      flightWorldVelocity.finite,
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 150.000001,
        radius: 0, includePlayer: false), contact.hit.target == .body(body.id),
      contact.hit.point.finite, body.position.z > 0
    else { return nil }
    let range = contact.hit.distance
    let speed = (flightWorldVelocity - native.velocity).length
    let aim = acos(max(-1, min(1, body.position.unit.z)))
    let pose = modelPose(of: body)
    let playerPose = commander.flightSimulation.pose
    let point = playerPose.systemPoint(contact.hit.point)
    let local = pose.orientation.inverse(point - pose.position)
    let axes = [abs(local.x), abs(local.y), abs(local.z)]
    guard let axis = axes.indices.max(by: { axes[$0] < axes[$1] }),
      abs(axes[axis] - 3) < 1e-5
    else { return nil }
    let values = [local.x, local.y, local.z]
    let sign = values[axis] >= 0 ? 1.0 : -1.0
    let normal =
      axis == 0 ? Vector3(sign, 0, 0) : axis == 1 ? Vector3(0, sign, 0) : Vector3(0, 0, sign)
    guard pose.orientation.apply(normal).dot(playerPose.position - point) > 0,
      NativeIsolationWorkEnvelope.qualifies(range: range, speed: speed, aim: aim)
    else { return nil }
    return .init(
      arm: arm, time: commander.flightSimulation.physicalTime, range: range, speed: speed, aim: aim)
  }
}
