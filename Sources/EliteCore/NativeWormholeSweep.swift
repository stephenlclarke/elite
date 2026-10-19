import Foundation

extension Game {
  /// Conservative whole-scene continuous clearance, using the existing native hull sweep.
  /// An unproven, moving, invalid or over-budget scene cannot produce a departure receipt.
  mutating func proveNativeTransitSweep(
    source: NativeNPCDriveSource, before: SpaceBody,
    sample: NativeWormholeMotionSample
  ) throws {
    let endPose = commander.flightSimulation.pose
    let start = sample.pose.systemPoint(before.position)
    let end = endPose.systemPoint(source.position)
    let beforeRadius = try NativeWormholeSweep.radius(
      scriptNPCMesh(before) ?? gameplayMesh(for: before))
    try proveNativeWormholeMotion(
      from: start, to: end, radius: max(source.radius, beforeRadius),
      excluding: source.actor, sample: sample, includePlayer: true)
  }

  mutating func proveNativeWormholeMotion(
    from start: Vector3, to end: Vector3, radius: Double,
    excluding actor: ActorIdentity?, sample: NativeWormholeMotionSample, includePlayer: Bool
  ) throws {
    let endPose = commander.flightSimulation.pose
    let duration = commander.flightSimulation.physicalTime - sample.physicalTime
    guard duration.isFinite, duration > 0, duration <= 0.100001 else {
      throw NativeWormholeRefusal.unsafeSweep
    }
    let observed = Set(sample.bodies.compactMap { $0.physical?.identity })
    guard
      bodies.filter({ $0.energy > 0 && $0.scriptShot == nil }).allSatisfy({
        $0.physical.map { observed.contains($0.identity) } ?? false
      })
    else { throw NativeWormholeRefusal.unsafeSweep }
    var obstacles: [HullSweepObstacle] = []
    for body in sample.bodies where body.physical?.identity != actor {
      guard body.energy > 0, body.scriptShot == nil else { continue }
      let mesh = scriptNPCMesh(body) ?? gameplayMesh(for: body)
      guard let hull = preparedWorkHull(mesh: mesh, key: "transit:\(body.id)") else {
        throw NativeWormholeRefusal.unsafeSweep
      }
      guard let identity = body.physical?.identity,
        let current = bodies.first(where: { $0.physical?.identity == identity })
      else { throw NativeWormholeRefusal.unsafeSweep }
      let from = sample.pose.systemPoint(body.position)
      let to = endPose.systemPoint(current.position)
      var basis = Basis3()
      basis.x = sample.pose.orientation.apply(body.modelVector(.init(1, 0, 0)))
      basis.y = sample.pose.orientation.apply(body.modelVector(.init(0, 1, 0)))
      basis.z = sample.pose.orientation.apply(body.modelVector(.init(0, 0, 1)))
      var finalBasis = Basis3()
      finalBasis.x = endPose.orientation.apply(current.modelVector(.init(1, 0, 0)))
      finalBasis.y = endPose.orientation.apply(current.modelVector(.init(0, 1, 0)))
      finalBasis.z = endPose.orientation.apply(current.modelVector(.init(0, 0, 1)))
      if body.rotationRate != 0 || finalBasis != basis {
        // A rotating/steering obstacle uses an enclosing actual measured radius. If that
        // conservative continuous separation fails, no frozen-orientation proof is substituted.
        let a = start - from
        let relative = (end - to) - a
        let denominator = relative.dot(relative)
        let t = denominator > 0 ? max(0, min(1, -a.dot(relative) / denominator)) : 0
        guard (a + relative * t).length > radius + hull.radius else {
          throw NativeWormholeRefusal.unsafeSweep
        }
        continue
      }
      obstacles.append(
        .init(
          identity: body.physical?.identity, hull: hull,
          pose: .init(position: from, orientation: basis), velocity: (to - from) * (1 / duration),
          angularVelocity: .init(0, 0, 0)))
    }
    // The player is a real mass/collision obstacle too, not an exception for an escort.
    if includePlayer {
      let playerRadius = try NativeWormholeSweep.radius(commander.playerMesh)
      let a = start - sample.pose.position
      let relative = (end - endPose.position) - a
      let denominator = relative.dot(relative)
      let t = denominator > 0 ? max(0, min(1, -a.dot(relative) / denominator)) : 0
      guard (a + relative * t).length > radius + playerRadius else {
        throw NativeWormholeRefusal.unsafeSweep
      }
    }
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
