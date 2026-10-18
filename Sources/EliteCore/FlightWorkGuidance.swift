import Foundation

struct FlightWorkSurface: Sendable {
  let point: Vector3
  let normal: Vector3
  let radius: Double?
  let section: WreckSectionIdentity?
}

/// Transient controller state. Persisted target custody remains in the existing ledgers.
struct FlightWorkGuidance: Sendable {
  let parent: ActorIdentity
  let mode: WorkTargetMode
  let surface: FlightWorkSurface
  let collectionOffset: Double
  var controller: RelativeWorkController
  var scoop: ScoopApproachController
  var velocity: Vector3
  var angularVelocity: Vector3
  var status = "APPROACHING"
  var holding = false
  var manualToolOverride = false
}

struct FlightWorkBraking: Sendable {
  var velocity: Vector3
  var angularVelocity: Vector3
}

extension Game {
  var flightWorldVelocity: Vector3 {
    workGuidance?.velocity ?? workBraking?.velocity
      ?? commander.flightSimulation.pose.orientation.apply(
        autoPilot.velocity + .init(0, 0, speed * 18))
  }

  var workLimits: RelativeWorkLimits {
    let craft = commander.performance
    return .init(
      acceleration: craft.acceleration * 18, speed: craft.speed * 18,
      pitchRate: craft.pitch, yawRate: craft.yaw, rollRate: craft.roll)
  }

  /// Convert the displayed transform to a constant world-axis spin without moving its mesh.
  mutating func canonicalizeWorkTarget(_ identity: ActorIdentity) {
    guard let index = bodies.firstIndex(where: { $0.physical?.identity == identity }),
      bodies[index].physical?.canonicalSpin != true
    else { return }
    let body = bodies[index]
    let pose = modelPose(of: body)
    let localOmega = Vector3(
      body.hull == .station ? 0 : 0.4 * body.rotationRate * cos(body.rotation),
      body.hull == .station ? 0 : 0.4 * body.rotationRate * sin(body.rotation), body.rotationRate)
    let player = commander.flightSimulation.pose
    bodies[index].physical?.angularVelocity = player.orientation.apply(
      body.orientation.apply(localOmega))
    bodies[index].orientation = player.orientation.transposed.composed(with: pose.orientation)
    bodies[index].rotation = 0
    bodies[index].rotationRate = 0
    bodies[index].physical?.canonicalSpin = true
  }

  mutating func beginWorkGuidance(body: SpaceBody, mode: WorkTargetMode, velocity: Vector3) {
    guard !playerEMPDisabled else { return }
    guard let context = gameplayContext(), let actor = body.physical?.identity,
      let metadata = recoverableMetadata(for: body, context: context),
      let surface = workSurface(for: body, metadata: metadata)
    else {
      cancelAutoTarget()
      notify("NO ACCESSIBLE WORK SURFACE")
      return
    }
    canonicalizeWorkTarget(actor)
    guard let canonical = bodies.first(where: { $0.physical?.identity == actor }) else { return }
    let offset: Double
    if case .hold = mode, commander.equipment.contains("Fuel Scoops"),
      workRayReachesSurface(body: canonical, surface: surface, lateralOffset: 40)
    {
      offset = 40
    } else {
      offset = 0
    }
    workGuidance = .init(
      parent: actor, mode: mode, surface: surface, collectionOffset: offset,
      controller: .init(parent: actor, wreck: metadata.wreck, category: metadata.category),
      scoop: .init(parent: actor), velocity: velocity, angularVelocity: .init(0, 0, 0))
    selectAcquiredWorkTool(mode)
    workBraking = nil
    manualResidualFlight = false
    approvedWorkMotion = nil
    spin.stop(immediate: true)
    speed = 0
    autoPilot.setApproachVelocity(.init(0, 0, 0))
    notify("WORK GUIDANCE ENGAGED - Q RELEASE HOLD")
  }

  /// Manual release retains actual world momentum; it never snaps velocity to zero.
  mutating func releaseWorkGuidance() {
    guard workGuidance != nil || workBraking != nil else { return }
    interruptFlightTool()
    let local = commander.flightSimulation.pose.shipVector(flightWorldVelocity)
    speed = 0
    manualResidualFlight = true
    autoPilot.setApproachVelocity(local)
    workGuidance = nil
    workBraking = nil
    workRecoveryRock = nil
    approvedWorkMotion = nil
  }

  func workSurface(for body: SpaceBody, metadata: SalvageTargetMetadata) -> FlightWorkSurface? {
    let pose = modelPose(of: body)
    let player = commander.flightSimulation.pose.position
    let surfaces: [FlightWorkSurface]
    if !metadata.workSurfaces.isEmpty {
      surfaces = metadata.workSurfaces.filter {
        metadata.section == nil || metadata.section == $0.section
      }.map {
        .init(point: $0.position, normal: $0.normal, radius: $0.radius, section: $0.section)
      }
    } else {
      let mesh = gameplayMesh(for: body)
      surfaces = mesh.faces.compactMap { face in
        guard face.count >= 3, face.allSatisfy(mesh.vertices.indices.contains) else { return nil }
        let a = mesh.vertices[face[0]]
        let b = mesh.vertices[face[1]]
        let c = mesh.vertices[face[2]]
        let normal = (b - a).cross(c - a).unit
        guard normal.length > 0 else { return nil }
        return .init(
          point: face.reduce(Vector3(0, 0, 0)) { $0 + mesh.vertices[$1] }
            * (1 / Double(face.count)),
          normal: normal, radius: nil, section: nil)
      }
    }
    return surfaces.filter {
      pose.orientation.apply($0.normal).dot(player - pose.systemPoint($0.point)) > 0
        && workRayReachesSurface(body: body, surface: $0, lateralOffset: 0)
    }.sorted { a, b in
      let leftDepleted = a.section.map(salvageSectionIsDepleted) ?? false
      let rightDepleted = b.section.map(salvageSectionIsDepleted) ?? false
      if leftDepleted != rightDepleted { return !leftDepleted }
      return (pose.systemPoint(a.point) - player).length
        < (pose.systemPoint(b.point) - player).length
    }.first
  }

  /// The proposed hold must look onto a real mesh face with no intervening actor.
  func workRayReachesSurface(body: SpaceBody, surface: FlightWorkSurface, lateralOffset: Double)
    -> Bool
  {
    let pose = modelPose(of: body)
    let normal = pose.orientation.apply(surface.normal).unit
    let playerRadius = commander.playerMesh.vertices.map(\.length).max() ?? 0
    var desired = Basis3()
    desired.z = normal * -1
    var up = pose.orientation.y - desired.z * pose.orientation.y.dot(desired.z)
    if up.length < 1e-6 { up = pose.orientation.x - desired.z * pose.orientation.x.dot(desired.z) }
    desired.y = up.unit
    desired.x = desired.y.cross(desired.z).unit
    let origin =
      pose.systemPoint(surface.point) + normal * (max(120, 2 * playerRadius) + playerRadius + 1)
      + desired.y * lateralOffset
    let hypothetical = ShipPose(position: origin, orientation: desired)
    let old = commander.flightSimulation.pose
    var scene = bodies
    for index in scene.indices {
      scene[index].position = hypothetical.shipPoint(old.systemPoint(scene[index].position))
      scene[index].orientation = hypothetical.orientation.transposed.composed(
        with: old.orientation.composed(with: scene[index].orientation))
    }
    let stars = celestials.map {
      CelestialBody(
        kind: $0.kind, position: hypothetical.shipPoint(old.systemPoint($0.position)),
        radius: $0.radius)
    }
    guard
      let hit = GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 1),
        maxDistance: 6000, bodies: scene.filter { $0.energy > 0 }, celestials: stars,
        meshOverrides: gameplayMeshOverrides), case .body(let id) = hit.target, id == body.id
    else { return false }
    if surface.section != nil {
      let point = pose.systemPoint(surface.point)
      let impact = hypothetical.systemPoint(hit.point)
      guard let radius = surface.radius, radius.isFinite, radius > 0,
        (point - impact).length <= max(1, radius),
        pose.orientation.apply(surface.normal).dot(hypothetical.position - point) > 0
      else { return false }
    }
    return true
  }

  mutating func advanceWorkGuidance(delta: Double) {
    approvedWorkMotion = nil
    guard !playerEMPDisabled else {
      releaseWorkGuidance()
      return
    }
    if let body = bodies.first(where: {
      $0.physical?.identity == workGuidance?.parent && $0.energy <= 0
    }),
      continueMinedRockRecovery(body)
    {
      return
    }
    guard var state = workGuidance else {
      if workBraking != nil {
        advanceWorkBraking(delta: delta)
      } else if workRecoveryRock != nil {
        selectNextMinedOre()
      }
      return
    }
    guard let context = gameplayContext(), let body = autoTargetBody,
      body.physical?.identity == state.parent,
      let candidate = workTargetCandidate(for: body, context: context, frontVisible: true),
      WorkTargetSelection.evaluate(
        candidate, system: context.system, visit: context.visit,
        capabilities: workTargetCapabilities
      ).mode == state.mode,
      let physical = body.physical,
      workSurfaceStillAuthorized(state, body: body, context: context),
      let targetHull = preparedWorkHull(mesh: gameplayMesh(for: body), key: "target:\(body.id)"),
      let playerHull = preparedWorkHull(mesh: commander.playerMesh, key: "player"),
      let obstacles = workObstacles(excluding: state.parent, delta: delta)
    else {
      cancelAutoTarget()
      weaponsTargetID = nil
      notify("WORK TARGET UNAVAILABLE")
      return
    }
    let pose = commander.flightSimulation.pose
    let targetPose = modelPose(of: body)
    let validate: (RelativeWorkSweep) -> RelativeWorkClearance = {
      HullSweepSafety.validate($0, target: targetHull, player: playerHull, obstacles: obstacles)
        .clearance
    }
    let previousStatus = state.status
    switch state.mode {
    case .hold:
      let target = RelativeWorkTarget(
        identity: state.parent, wreck: physical.salvage?.wreck,
        pose: targetPose, velocity: physical.velocity, angularVelocity: physical.angularVelocity,
        surfacePoint: state.surface.point, surfaceNormal: state.surface.normal,
        depleted: state.surface.section.map(salvageSectionIsDepleted) ?? false)
      let output = state.controller.step(
        .init(
          ship: pose, velocity: state.velocity,
          angularVelocity: state.angularVelocity, target: target, playerRadius: playerHull.radius,
          limits: workLimits, cutterRange: state.surface.section == nil ? 6000 : 300,
          delta: delta, collectionOffset: state.collectionOffset), validate: validate)
      let wasHolding = state.holding
      state.holding = output.status == .holding
      if state.holding && !wasHolding { interruptFlightTool() }
      state.status = workStatus(output.status)
      if let sweep = output.validatedSweep { approvedWorkMotion = .init(from: sweep) }
      for transition in output.transitions {
        switch transition {
        case .selectTool: break
        case .workComplete: notify("SECTION EXHAUSTED - HOLDING POSITION")
        case .status: break
        }
      }
    case .autoScoop:
      let target = ScoopApproachTarget(
        identity: state.parent, hull: targetHull,
        pose: targetPose, velocity: physical.velocity, angularVelocity: physical.angularVelocity,
        surfacePoint: state.surface.point, surfaceNormal: state.surface.normal)
      let output = state.scoop.step(
        .init(
          ship: pose, velocity: state.velocity,
          angularVelocity: state.angularVelocity, target: target, playerRadius: playerHull.radius,
          limits: workLimits, captureOffsetInShip: .init(0, -45, 55), captureTolerance: 2,
          delta: delta), validate: validate)
      state.status = scoopStatus(output.status)
      if let sweep = output.validatedSweep { approvedWorkMotion = .init(from: sweep) }
    case .ship, .docking:
      cancelAutoTarget()
      return
    }
    workGuidance = state
    authorizeWorkThrust(delta: delta)
    if previousStatus != state.status { notify("WORK: " + state.status) }
  }

  func workSurfaceStillAuthorized(
    _ state: FlightWorkGuidance, body: SpaceBody, context: EncounterContext
  ) -> Bool {
    if body.physical?.empCrewPod != nil {
      return state.mode == .autoScoop(.salvage) && hasNativeRescueTools
        && nativePodFacts(body, context: context)?.fits == true
        && automaticScoopShapeCompatible(body, context: context)
    }
    if let source = body.physical?.empSource,
      let record = commander.savedEMPState?.records[source], record.crewAboard > 0
    {
      return nativeCrewCaptureAvailable(body, context: context) && hasNativeRescueTools
        && freeNativePeopleTonnes > 0
    }
    guard let section = state.surface.section else { return true }
    guard let metadata = recoverableMetadata(for: body, context: context),
      metadata.wreck == section.wreck,
      metadata.section == nil || metadata.section == section
    else { return false }
    return metadata.workSurfaces.contains {
      $0.section == section && $0.position == state.surface.point
        && $0.normal == state.surface.normal && $0.radius == state.surface.radius
    }
  }

  mutating func authorizeWorkThrust(delta: Double) {
    guard !playerEMPDisabled else {
      approvedWorkMotion = nil
      return
    }
    guard let motion = approvedWorkMotion else { return }
    let cost = delta * 2 * min(1, motion.acceleration.length / workLimits.acceleration)
    guard energy.isFinite, energy > cost else {
      approvedWorkMotion = nil
      if workGuidance != nil { workGuidance?.status = "INSUFFICIENT THRUST ENERGY" }
      notify("WORK: INSUFFICIENT THRUST ENERGY")
      return
    }
    energy -= cost
  }

  mutating func workTargetCollected(_ body: SpaceBody) {
    guard let work = workGuidance, let identity = body.physical?.identity,
      work.parent == identity
    else { return }
    let velocity = flightWorldVelocity
    let omega = work.angularVelocity
    workGuidance = nil
    approvedWorkMotion = nil
    autoPilot.disengage()
    weaponsTargetID = nil
    dockingComputer = false
    workBraking = .init(velocity: velocity, angularVelocity: omega)
  }

  mutating func advanceWorkBraking(delta: Double) {
    guard !playerEMPDisabled else { return }
    guard let state = workBraking,
      let player = preparedWorkHull(mesh: commander.playerMesh, key: "player"),
      let obstacles = workObstacles(excluding: nil, delta: delta)
    else { return }
    let acceleration =
      state.velocity.unit * -min(workLimits.acceleration, state.velocity.length / delta)
    let start = commander.flightSimulation.pose
    var end = start
    end.position = start.position + state.velocity * delta + acceleration * (0.5 * delta * delta)
    // Angular control may change within its legal rate limit; there is no orientation snap.
    let motion = HullSceneMotion(
      start: start, end: end, initialVelocity: state.velocity,
      acceleration: acceleration, worldAngularVelocity: .init(0, 0, 0), duration: delta,
      playerRadius: player.radius)
    if HullSweepSafety.validateSceneMotion(motion, player: player, obstacles: obstacles).safe {
      approvedWorkMotion = motion
      authorizeWorkThrust(delta: delta)
    } else if message != "BRAKING BLOCKED - COASTING" || messageTime <= 0 {
      notify("BRAKING BLOCKED - COASTING")
    }
  }

  @discardableResult
  mutating func continueMinedRockRecovery(_ body: SpaceBody) -> Bool {
    guard workGuidance?.parent == body.physical?.identity,
      workGuidance?.mode == .hold(.mining), let rock = body.physical?.rock,
      commander.miningLedger.isDepleted(rock)
    else { return false }
    let velocity = flightWorldVelocity
    let omega = workGuidance?.angularVelocity ?? .init(0, 0, 0)
    workGuidance = nil
    autoPilot.disengage()
    weaponsTargetID = nil
    approvedWorkMotion = nil
    workRecoveryRock = rock
    workBraking = .init(velocity: velocity, angularVelocity: omega)
    if velocity.length < 1e-9 {
      workBraking = nil
      selectNextMinedOre()
    }
    notify("MINING COMPLETE - RECOVERING ORE")
    return true
  }

  mutating func selectNextMinedOre() {
    guard !playerEMPDisabled else { return }
    guard let rock = workRecoveryRock, let context = gameplayContext() else { return }
    let eligible = bodies.filter { body in
      guard body.energy > 0, let payload = body.physical?.payload,
        case .ore(let source, _) = payload, source == rock,
        let candidate = workTargetCandidate(for: body, context: context, frontVisible: true)
      else { return false }
      return WorkTargetSelection.evaluate(
        candidate, system: context.system, visit: context.visit,
        capabilities: workTargetCapabilities
      ).mode == .autoScoop(.mining)
    }
    guard !eligible.isEmpty else {
      workRecoveryRock = nil
      notify("ORE RECOVERY FINISHED")
      return
    }
    let velocity = flightWorldVelocity
    autoPilot.cycle(
      eligible, frontIDs: Set(eligible.map(\.id)), signature: "ore-recovery",
      manualEngagement: !targetingEnabled)
    weaponsTargetID = autoPilot.targetID
    if let target = autoTargetBody {
      beginWorkGuidance(body: target, mode: .autoScoop(.mining), velocity: velocity)
    }
  }

  private func workBlockMessage(_ reason: RelativeWorkBlock) -> String {
    switch reason {
    case .invalidInput: "TARGET MOTION UNAVAILABLE"
    case .unsupportedTarget: "TARGET NOT SUITABLE"
    case .identityMismatch: "TARGET CHANGED"
    case .toolRange: "OUTSIDE TOOL RANGE"
    case .speedLimit: "TARGET TOO FAST"
    case .accelerationLimit: "THRUST LIMIT"
    case .turnLimit: "TARGET SPIN TOO FAST"
    case .clearance: "PATH NOT CLEAR"
    }
  }

  func workStatus(_ status: RelativeWorkStatus) -> String {
    switch status {
    case .idle, .approaching: "APPROACHING WORK SURFACE"
    case .matching: "MATCHING TARGET MOTION"
    case .holding: "HOLDING - RETURN FIRES SELECTED WEAPON"
    case .blocked(let reason): "HOLD BLOCKED: " + workBlockMessage(reason)
    case .cancelled: "CANCELLED"
    case .targetLost, .changedPrimary: "TARGET LOST"
    }
  }

  func scoopStatus(_ status: ScoopApproachStatus) -> String {
    switch status {
    case .approaching: "APPROACHING SCOOP TARGET"
    case .matching: "MATCHING SCOOP TARGET MOTION"
    case .ready: "SCOOP ALIGNED"
    case .blocked(let reason): "SCOOP BLOCKED: " + workBlockMessage(reason)
    case .cancelled: "CANCELLED"
    case .targetLost, .changedPrimary: "TARGET LOST"
    }
  }
}

extension Basis3 {
  func composed(with other: Basis3) -> Basis3 {
    var result = Basis3()
    result.x = apply(other.x)
    result.y = apply(other.y)
    result.z = apply(other.z)
    return result
  }
}
