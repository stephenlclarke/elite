import Foundation

extension Game {
  mutating func preparedWorkHull(mesh: Mesh, key: String) -> PreparedHull? {
    let cacheKey = "work:" + key
    if let cached = salvageAdmissionGeometry[cacheKey],
      cached.mesh.vertices == mesh.vertices, cached.mesh.faces == mesh.faces
    {
      return cached.hull
    }
    guard let hull = try? PreparedHull(mesh: mesh) else { return nil }
    if salvageAdmissionGeometry.count >= 128 {
      salvageAdmissionGeometry.removeAll(keepingCapacity: true)
    }
    salvageAdmissionGeometry[cacheKey] = .init(mesh: mesh, hull: hull)
    return hull
  }

  /// Legacy AI runs before the proof. Its whole ensuing linear displacement is an obstacle,
  /// and it is not run again after the approved player motion.
  mutating func planWorkScene(delta: Double) {
    guard !playerEMPDisabled, workGuidance != nil || workBraking != nil else { return }
    workScenePlanned = true
    if missionLoopCounter & 7 == 0 { navalTactics() }
    let actors = bodies.filter {
      $0.hostile && $0.energy > 0 && $0.physical?.spawnIdentity == nil
    }.map(\.id)
    for id in actors {
      guard let index = bodies.firstIndex(where: { $0.id == id }) else { continue }
      let before = bodies[index]
      let start = modelPose(of: before)
      let radius = gameplayMesh(for: before).vertices.map(\.length).max() ?? 0
      enemyAction(index: index, dt: delta)
      guard let after = bodies.first(where: { $0.id == id }),
        let hull = preparedWorkHull(mesh: workObstacleBox(radius), key: "legacy:\(id)")
      else { continue }
      let velocity = (modelPose(of: after).position - start.position) * (1 / delta)
      plannedLegacyWorkMotion[id] = .init(
        identity: before.physical?.identity, hull: hull,
        pose: .init(position: start.position), velocity: velocity, clearanceOverride: 0)
    }
  }

  /// Include every current actor. Other loose pods remain obstacles after one is collected.
  mutating func workObstacles(excluding primary: ActorIdentity?, delta: Double)
    -> [HullSweepObstacle]?
  {
    var result: [HullSweepObstacle] = []
    for body in bodies
    where body.energy > 0 && (primary == nil || body.physical?.identity != primary) {
      guard let physical = body.physical else { return nil }
      if let planned = plannedLegacyWorkMotion[body.id] {
        result.append(planned)
        continue
      }
      let mesh = gameplayMesh(for: body)
      if physical.canonicalSpin == true {
        guard let hull = preparedWorkHull(mesh: mesh, key: "actor:\(body.id)") else { return nil }
        result.append(
          .init(
            identity: physical.identity, hull: hull, pose: modelPose(of: body),
            velocity: physical.spawnIdentity == nil ? .init(0, 0, 0) : physical.velocity,
            angularVelocity: physical.angularVelocity, clearanceOverride: 0))
      } else {
        // The enclosing box covers the complete legacy model spin. Turning projectiles get
        // a full one-step travel envelope rather than an assumed straight trajectory.
        var radius = mesh.vertices.map(\.length).max() ?? 0
        if let projectile = physical.ordnance { radius += projectile.velocity.length * delta }
        guard let hull = preparedWorkHull(mesh: workObstacleBox(radius), key: "envelope:\(body.id)")
        else { return nil }
        let velocity =
          physical.spawnIdentity != nil && physical.ordnance == nil
          ? physical.velocity : Vector3(0, 0, 0)
        result.append(
          .init(
            identity: physical.identity, hull: hull,
            pose: .init(position: modelPose(of: body).position), velocity: velocity,
            clearanceOverride: 0))
      }
    }
    let pose = commander.flightSimulation.pose
    for (index, celestial) in celestials.enumerated() {
      guard
        let hull = preparedWorkHull(
          mesh: workObstacleBox(celestial.radius), key: "celestial:\(index)")
      else { return nil }
      result.append(
        .init(
          hull: hull, pose: .init(position: pose.systemPoint(celestial.position)),
          clearanceOverride: 0))
    }
    return result
  }

  /// Consume one accepted endpoint. No Euler integration of its end velocity follows it.
  @discardableResult
  mutating func moveWorkFrame(delta: Double) -> Bool {
    guard workGuidance != nil || workBraking != nil else { return false }
    let start = commander.flightSimulation.pose
    let motion = approvedWorkMotion
    let accepted = motion.map { $0.start == start && $0.duration == delta } ?? false
    let initialVelocity = flightWorldVelocity
    let end: ShipPose
    let velocity: Vector3
    let omega: Vector3
    if accepted, let motion {
      end = motion.end
      velocity = motion.initialVelocity + motion.acceleration * delta
      omega = motion.worldAngularVelocity
      lastAppliedWorkMotion = motion
    } else {
      // A failed clearance proof cannot authorize thrust or a new rotation. Physical inertia
      // continues; this is an unpowered coast, not a claim of collision-free motion.
      end = .init(
        position: start.position + initialVelocity * delta, orientation: start.orientation)
      velocity = initialVelocity
      omega = .init(0, 0, 0)
      lastAppliedWorkMotion = nil
    }
    approvedWorkMotion = nil
    commander.flightSimulation.pose = end
    rotateScriptNPCVelocities(from: start, to: end)
    let change = start.orientation.workFrameRelative(to: end.orientation)
    for index in bodies.indices {
      bodies[index].position = end.shipPoint(start.systemPoint(bodies[index].position))
      bodies[index].orientation = change.composed(with: bodies[index].orientation)
      advanceBodyModelRotation(at: index, delta: delta)
      advanceCanonicalModelSpin(at: index, delta: delta)
      if let physical = bodies[index].physical, physical.spawnIdentity != nil,
        physical.ordnance == nil, bodies[index].scriptShot == nil,
        bodies[index].scriptNPC == nil || c01SurveyorActor(bodies[index]) != nil
      {
        bodies[index].position = bodies[index].position + end.shipVector(physical.velocity) * delta
      }
    }
    for index in celestials.indices {
      celestials[index].position = end.shipPoint(start.systemPoint(celestials[index].position))
    }
    workGuidance?.velocity = velocity
    workGuidance?.angularVelocity = omega
    workBraking?.velocity = velocity
    workBraking?.angularVelocity = omega
    autoPilot.setApproachVelocity(.init(0, 0, 0))
    speed = 0
    if workGuidance == nil, velocity.length < 1e-9 {
      workBraking = nil
    }
    return true
  }

  func workObstacleBox(_ radius: Double) -> Mesh {
    let r = radius
    return .init(
      vertices: [
        .init(-r, -r, -r), .init(r, -r, -r), .init(r, r, -r), .init(-r, r, -r),
        .init(-r, -r, r), .init(r, -r, r), .init(r, r, r), .init(-r, r, r),
      ],
      faces: [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
      ])
  }
}

extension Basis3 {
  /// Re-express an orientation in an admitted work frame without normalizing either basis.
  /// A represented rotation is only approximately orthogonal: its transpose is not its inverse.
  func workFrameRelative(to frame: Basis3) -> Basis3 {
    let first = frame.y.cross(frame.z)
    let second = frame.z.cross(frame.x)
    let third = frame.x.cross(frame.y)
    let inverseDeterminant = 1 / frame.x.dot(first)
    func coordinates(_ vector: Vector3) -> Vector3 {
      .init(
        vector.dot(first) * inverseDeterminant, vector.dot(second) * inverseDeterminant,
        vector.dot(third) * inverseDeterminant)
    }
    var result = Basis3()
    result.x = coordinates(x)
    result.y = coordinates(y)
    result.z = coordinates(z)
    return result
  }
}
