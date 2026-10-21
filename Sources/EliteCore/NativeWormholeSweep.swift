import Foundation

extension Game {
  /// Conservative whole-scene continuous clearance, using the existing native hull sweep.
  /// An unproven, moving, invalid or over-budget scene cannot produce a departure receipt.
  func proveNativeTransitSweep(
    source: NativeNPCDriveSource, before: SpaceBody,
    sample: NativeWormholeMotionSample
  ) throws {
    let endPose = commander.flightSimulation.pose
    let start = sample.pose.systemPoint(before.position)
    let end = endPose.systemPoint(source.body.position)
    try proveNativeWormholeMotion(from: start, to: end, radius: source.radius,
      excluding: source.actor, sample: sample, includePlayer: true)
  }

  func proveNativeWormholeMotion(from start: Vector3, to end: Vector3, radius: Double,
    excluding actor: ActorIdentity?, sample: NativeWormholeMotionSample, includePlayer: Bool) throws
  {
    let endPose = commander.flightSimulation.pose
    let duration = commander.flightSimulation.physicalTime - sample.physicalTime
    guard duration.isFinite, duration > 0, duration <= 0.100001 else {
      throw NativeWormholeRefusal.unsafeSweep
    }
    var obstacles: [HullSweepObstacle] = []
    for body in sample.bodies where body.physical?.identity != actor {
      guard body.energy > 0, body.scriptShot == nil else { continue }
      let mesh = scriptNPCMesh(body) ?? Mesh.hull(body.hull)
      let hull = try PreparedHull(mesh: mesh)
      let current = bodies.first(where: { $0.physical?.identity == body.physical?.identity })
      let from = sample.pose.systemPoint(body.position)
      let to = current.map { endPose.systemPoint($0.position) } ?? from
      var basis = Basis3()
      basis.x = sample.pose.orientation.apply(body.modelVector(.init(1, 0, 0)))
      basis.y = sample.pose.orientation.apply(body.modelVector(.init(0, 1, 0)))
      basis.z = sample.pose.orientation.apply(body.modelVector(.init(0, 0, 1)))
      obstacles.append(
        .init(
          identity: body.physical?.identity, hull: hull,
          pose: .init(position: from, orientation: basis), velocity: (to - from) * (1 / duration),
          angularVelocity: basis.z * body.rotationRate))
    }
    // The player is a real mass/collision obstacle too, not an exception for an escort.
    if includePlayer { obstacles.append(
      .init(
        identity: commander.flightSimulation.player,
        hull: try PreparedHull(mesh: commander.playerMesh), pose: sample.pose,
        velocity: (endPose.position - sample.pose.position) * (1 / duration))) }
    let motion = HullSceneMotion(
      start: .init(position: start), end: .init(position: end),
      initialVelocity: (end - start) * (1 / duration), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: duration, playerRadius: radius)
    guard HullSweepSafety.validateSceneMotion(motion, obstacles: obstacles).safe else {
      throw NativeWormholeRefusal.unsafeSweep
    }
    let segment = end - start
    for celestial in celestials {
      let centre = endPose.systemPoint(celestial.position)
      let denominator = segment.dot(segment)
      let t = denominator > 0 ? max(0, min(1, (centre - start).dot(segment) / denominator)) : 0
      guard (start + segment * t - centre).length > celestial.radius + radius else {
        throw NativeWormholeRefusal.unsafeSweep
      }
    }
  }
}
