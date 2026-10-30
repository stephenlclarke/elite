import Foundation

struct NativeInductionUtilityWorkReview: Sendable, Equatable {
  let nonce: UUID
  let job: UUID
  let revision: UInt64
  let role: NativeInductionUtilityRole
  let actor: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
}

struct NativeInductionUtilityWorkRuntime: Sendable {
  var contact: ActorIdentity?
  var review: NativeInductionUtilityWorkReview?
  var arm: NativeInductionUtilityArm?
  var reason = "Select a handoff; Return reviews maintenance, Return confirms arming."
  var dirty = false
  var publishedSeconds = 0.0
}

/// Constructed only by the actual native surface query below, never by saved/model measurements.
struct NativeInductionUtilityEndpoint: Sendable {
  let arm: UUID
  let actor: ActorIdentity
  let player: ActorIdentity
  let carrier: UUID
  let revision: UInt64
  let epoch: UUID
  let time: Double
  let range: Double
  let speed: Double
  let aim: Double
  fileprivate init(
    arm: UUID, actor: ActorIdentity, player: ActorIdentity, carrier: UUID,
    revision: UInt64, epoch: UUID, time: Double, range: Double, speed: Double, aim: Double
  ) {
    self.arm = arm
    self.actor = actor
    self.player = player
    self.carrier = carrier
    self.revision = revision
    self.epoch = epoch
    self.time = time
    self.range = range
    self.speed = speed
    self.aim = aim
  }
  func sameAuthority(_ other: Self) -> Bool {
    arm == other.arm && actor == other.actor && player == other.player && carrier == other.carrier
      && revision == other.revision && epoch == other.epoch
  }
}

extension Game {
  func inductionUtilityRole(_ body: SpaceBody) -> NativeInductionUtilityRole? {
    guard !isMissionTrial, systemIdentity == NativeInductionUtilitySource.location,
      let child = inductionUtilityChild, child.suspension == nil,
      let state = child.savedNativeInductionUtility, state.admission != nil, state.receiving == nil,
      body.missionInstanceID == child.id, body.energy > 0,
      let native = body.physical, native.identity.system == systemIdentity,
      native.identity.visit == commander.flightSimulation.visit,
      native.population == .mission, native.npc?.role == .mission,
      let parentMission = wayfarerInductionMission, parentMission.outcome == .active,
      parentMission.suspension == nil, let parent = parentMission.savedWayfarerInduction,
      let source = try? NativeInductionUtilitySource(parent: parent),
      let fit = body.scriptNPC?.fit, source.matchesFit(fit)
    else { return nil }
    return NativeInductionUtilityRole.allCases.first {
      body.missionActorID == NativeInductionUtilityPack.actor(job: child.id, role: $0)
    }
  }

  var inductionUtilityContactBody: SpaceBody? {
    guard !docked, screen == .front, !paused else { return nil }
    if let id = inductionUtilityWorkRuntime.contact,
      let body = bodies.first(where: { $0.physical?.identity == id }),
      inductionUtilityRole(body) != nil
    {
      return body
    }
    if let body = autoTargetBody, inductionUtilityRole(body) != nil { return body }
    return nil
  }

  /// Mission contact selection grants neither fitted targeting equipment nor automatic flight.
  mutating func cycleInductionUtilityContact() -> Bool {
    guard !docked, screen.isFlight, !paused,
      systemIdentity == NativeInductionUtilitySource.location,
      let state = inductionUtilityChild?.savedNativeInductionUtility, state.receiving == nil
    else { return false }
    let available = bodies.filter { inductionUtilityRole($0) != nil }.sorted { $0.id < $1.id }
    guard !available.isEmpty else {
      notify("ENRON HANDOFF ADMISSION PENDING - APPROACH THE CREW'S REFERENCE POSITIONS")
      return true
    }
    let old = inductionUtilityWorkRuntime.contact
    let index =
      available.firstIndex { $0.physical?.identity == old }.map { ($0 + 1) % available.count } ?? 0
    interruptFlightTool()
    inductionUtilityWorkRuntime.contact = available[index].physical?.identity
    screen = .front
    notify(
      "ENRON " + (inductionUtilityRole(available[index])?.rawValue.uppercased() ?? "HANDOFF")
        + " - RETURN REVIEWS MAINTENANCE")
    return true
  }

  public var inductionUtilityUsesReturn: Bool {
    guard !docked, screen == .front, !paused,
      systemIdentity == NativeInductionUtilitySource.location
    else { return false }
    return inductionUtilityWorkRuntime.review != nil || inductionUtilityWorkRuntime.arm != nil
      || inductionUtilityContactBody != nil
  }

  mutating func interruptInductionUtilityWork() {
    inductionUtilityWorkRuntime.review = nil
    inductionUtilityWorkRuntime.arm = nil
    inductionUtilityWorkRuntime.reason = "Maintenance stopped; measured partial work is retained."
  }

  /// Query both ends of a real simulation step. A dialog, scan, cull or model cannot call this work.
  @inline(never)
  func inductionUtilityEndpoint() -> NativeInductionUtilityEndpoint? {
    guard !docked, !paused, screen == .front, !isMissionTrial, energy > 0, !playerEMPDisabled,
      case .living = nativeOriginalMainStationDestination,
      let arm = inductionUtilityWorkRuntime.arm, arm.epoch == nativeStationRuntimeEpoch,
      arm.carrier == commander.hullInstanceID,
      arm.inventoryRevision == commander.equipmentInventory?.revision,
      commander.equipmentOwnerID == arm.owner, let player = commander.flightSimulation.player,
      player == arm.player, let child = inductionUtilityChild,
      let state = child.savedNativeInductionUtility,
      let module = state.modules.first(where: { $0.role == arm.role }), module.work?.repair == nil,
      module.work?.segments.last?.arm == arm,
      let body = bodies.first(where: { $0.physical?.identity == arm.actor }),
      inductionUtilityRole(body) == arm.role, let native = body.physical,
      native.velocity.finite, native.angularVelocity.finite, flightWorldVelocity.finite,
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 150.000001, radius: 0, includePlayer: false), contact.hit.target == .body(body.id),
      contact.hit.point.finite, body.position.z > 0
    else { return nil }
    let range = contact.hit.distance
    let speed = (flightWorldVelocity - native.velocity).length
    let aim = acos(max(-1, min(1, body.position.unit.z)))
    // Outward cube face at the actual first mesh hit must face the player; never work from inside.
    let pose = modelPose(of: body)
    let local = pose.orientation.inverse(
      commander.flightSimulation.pose.systemPoint(contact.hit.point) - pose.position)
    let axes = [abs(local.x), abs(local.y), abs(local.z)]
    guard let axis = axes.indices.max(by: { axes[$0] < axes[$1] }), abs(axes[axis] - 3) < 1e-5
    else { return nil }
    let values = [local.x, local.y, local.z]
    let sign = values[axis] >= 0 ? 1.0 : -1.0
    let normal =
      axis == 0 ? Vector3(sign, 0, 0) : axis == 1 ? Vector3(0, sign, 0) : Vector3(0, 0, sign)
    let outward = pose.orientation.apply(normal)
    let hit = commander.flightSimulation.pose.systemPoint(contact.hit.point)
    guard outward.dot(commander.flightSimulation.pose.position - hit) > 0,
      NativeInductionUtilityEnvelope.qualifies(
        range: range, speed: speed, aim: aim,
        front: true, unobstructed: true)
    else { return nil }
    return .init(
      arm: arm.operation, actor: arm.actor, player: player,
      carrier: arm.carrier, revision: arm.inventoryRevision, epoch: arm.epoch,
      time: commander.flightSimulation.physicalTime, range: range, speed: speed, aim: aim)
  }
}
