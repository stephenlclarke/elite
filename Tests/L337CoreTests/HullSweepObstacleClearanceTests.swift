import Testing

@testable import L337Core

private let clearancePrimary = ActorIdentity(
  system: .init(galaxy: 0, system: 7), visit: 1, entity: 1)
private let clearancePod = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 2)

private func clearanceCube(_ half: Double) throws -> PreparedHull {
  try PreparedHull(
    mesh: Mesh(
      vertices: [
        .init(-half, -half, -half), .init(half, -half, -half),
        .init(half, half, -half), .init(-half, half, -half),
        .init(-half, -half, half), .init(half, -half, half),
        .init(half, half, half), .init(-half, half, half),
      ],
      faces: [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
      ], preserveWinding: true))
}

private func clearanceSweep(z: Double = -150) -> RelativeWorkSweep {
  let pose = ShipPose(position: .init(0, 0, z))
  let target = RelativeWorkTarget(
    identity: clearancePrimary, pose: .init(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), surfacePoint: .init(0, 0, -10),
    surfaceNormal: .init(0, 0, -1))
  return .init(
    purpose: .work, start: pose, end: pose, initialVelocity: .init(0, 0, 0),
    acceleration: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), target: target,
    targetEnd: .init(), surfacePosition: .init(0, 0, -10), workPosition: pose.position,
    playerRadius: 2, requiredClearance: 120, duration: 1)
}

private func clearanceObstacle(
  _ hull: PreparedHull, z: Double = -154, override: Double? = nil,
  identity: ActorIdentity = clearancePod, x: Double = 0, velocity: Vector3 = .init(0, 0, 0)
) -> HullSweepObstacle {
  .init(
    identity: identity, hull: hull, pose: .init(position: .init(x, 0, z)),
    velocity: velocity, clearanceOverride: override)
}

struct HullSweepObstacleClearanceTests {
  @Test func defaultGapIsInheritedWhileExplicitZeroAllowsSeparatedPodForSphereAndExactPlayer()
    throws
  {
    let hull = try clearanceCube(10)
    let pod = try clearanceCube(1)
    for exact in [false, true] {
      let player: PreparedHull? = exact ? pod : nil
      let inherited = HullSweepSafety.validate(
        clearanceSweep(), target: hull, player: player, obstacles: [clearanceObstacle(pod)])
      #expect(!inherited.safe && inherited.obstacle == clearancePod)
      let zero = HullSweepSafety.validate(
        clearanceSweep(), target: hull, player: player,
        obstacles: [clearanceObstacle(pod, override: 0)])
      #expect(zero.safe)
    }
  }

  @Test func positiveOverrideRequiresStrictSeparationAndInvalidOverridesFailClosed() throws {
    let hull = try clearanceCube(10)
    let pod = try clearanceCube(1)
    for gap in [1.0, 2, 120] {
      let result = HullSweepSafety.validate(
        clearanceSweep(), target: hull, obstacles: [clearanceObstacle(pod, override: gap)])
      #expect(!result.safe && result.obstacle == clearancePod)
    }
    let smaller = HullSweepSafety.validate(
      clearanceSweep(), target: hull, obstacles: [clearanceObstacle(pod, override: 0.5)])
    #expect(smaller.safe)
    let nearContact = HullSweepSafety.validate(
      clearanceSweep(), target: hull,
      obstacles: [clearanceObstacle(pod, z: -153.00000001, override: 0)])
    #expect(!nearContact.safe && nearContact.failure == .unproven)
    let budget = HullSweepSafety.validate(
      clearanceSweep(), target: hull, obstacles: [clearanceObstacle(pod, override: 0)],
      budget: .init(
        distanceQueries: 3, triangleTests: 500_000, nodeVisits: 500_000, subdivisionDepth: 12))
    #expect(!budget.safe && budget.failure == .workBudgetExceeded)
    for gap in [-1.0, .nan, .infinity, -.infinity] {
      let result = HullSweepSafety.validate(
        clearanceSweep(), target: hull, obstacles: [clearanceObstacle(pod, override: gap)])
      #expect(result.failure == .invalidMotion && result.obstacle == clearancePod)
    }
  }

  @Test func zeroOverrideStillRejectsContactAndInteriorForSphereAndExactPlayer() throws {
    let hull = try clearanceCube(10)
    let pod = try clearanceCube(1)
    for exact in [false, true] {
      for z in [-150.0, exact ? -152 : -153] {
        let result = HullSweepSafety.validate(
          clearanceSweep(), target: hull, player: exact ? pod : nil,
          obstacles: [clearanceObstacle(pod, z: z, override: 0)])
        #expect(!result.safe && result.obstacle == clearancePod)
      }
    }
  }

  @Test func movingPodCrossingBetweenClearEndpointsCannotUseZeroGapToTunnel() throws {
    let hull = try clearanceCube(10)
    let pod = try clearanceCube(1)
    for x in [-10.0, 10.0] {
      let endpoint = HullSweepSafety.validate(
        clearanceSweep(), target: hull,
        obstacles: [clearanceObstacle(pod, z: -150, override: 0, x: x)])
      #expect(endpoint.safe)
    }
    let crossing = clearanceObstacle(
      pod, z: -150, override: 0, x: -10, velocity: .init(20, 0, 0))
    let result = HullSweepSafety.validate(clearanceSweep(), target: hull, obstacles: [crossing])
    #expect(!result.safe && result.obstacle == clearancePod)
  }

  @Test func zeroOverrideDoesNotRelaxOtherObstaclesOrThePrimaryHull() throws {
    let hull = try clearanceCube(10)
    let pod = try clearanceCube(1)
    let otherID = ActorIdentity(system: clearancePrimary.system, visit: 1, entity: 3)
    let zero = clearanceObstacle(pod, override: 0)
    let inherited = clearanceObstacle(pod, z: -160, identity: otherID)
    let mixed = HullSweepSafety.validate(
      clearanceSweep(), target: hull, obstacles: [zero, inherited])
    #expect(!mixed.safe && mixed.obstacle == otherID)
    let primary = HullSweepSafety.validate(
      clearanceSweep(z: -100), target: hull, obstacles: [zero])
    #expect(!primary.safe && primary.obstacle == clearancePrimary)
  }
}
