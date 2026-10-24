import Foundation
import Testing

@testable import EliteCore

private let sceneActor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 42)

private func sceneMesh(_ half: Double = 10) -> Mesh {
  Mesh(
    vertices: [
      .init(-half, -half, -half), .init(half, -half, -half),
      .init(half, half, -half), .init(-half, half, -half),
      .init(-half, -half, half), .init(half, -half, half),
      .init(half, half, half), .init(-half, half, half),
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
    ], preserveWinding: true)
}

private func sceneMotion(
  position: Vector3 = .init(0, 0, -150), radius: Double = 2, gap: Double = 0,
  duration: Double = 1, velocity: Vector3 = .init(0, 0, 0), end: ShipPose? = nil
) -> HullSceneMotion {
  let start = ShipPose(position: position)
  return .init(
    start: start, end: end ?? .init(position: position + velocity * duration),
    initialVelocity: velocity, acceleration: .init(0, 0, 0),
    worldAngularVelocity: .init(0, 0, 0), duration: duration,
    playerRadius: radius, requiredClearance: gap)
}

struct HullSceneMotionTests {
  @Test func actualControllerSweepCopiesEveryMotionFieldAndAnalyticalEndpoint() throws {
    let target = RelativeWorkTarget(
      identity: sceneActor, pose: .init(), velocity: .init(10, 0, 0),
      angularVelocity: .init(0, 0, 0.1), surfacePoint: .init(100, 0, 0),
      surfaceNormal: .init(0, 0, -1))
    let input = RelativeWorkInput(
      ship: .init(position: .init(100, 0, -151)), velocity: .init(10, 10, 0),
      angularVelocity: .init(0, 0, 0.1), target: target, playerRadius: 30,
      limits: .init(acceleration: 40, speed: 120, pitchRate: 0.6, yawRate: 0.6, rollRate: 0.6),
      delta: 0.02)
    var controller = RelativeWorkController(parent: sceneActor, category: .rock)
    let output = controller.step(input) { _ in .clear }
    let sweep = try #require(output.validatedSweep)
    let copied = HullSceneMotion(from: sweep)
    let explicit = HullSceneMotion(
      start: sweep.start, end: sweep.end, initialVelocity: sweep.initialVelocity,
      acceleration: sweep.acceleration, worldAngularVelocity: sweep.angularVelocity,
      duration: sweep.duration, playerRadius: sweep.playerRadius,
      requiredClearance: sweep.requiredClearance)
    #expect(copied == explicit)
    #expect(
      copied.end.position == copied.start.position + copied.initialVelocity * copied.duration
        + copied.acceleration * (0.5 * copied.duration * copied.duration))
    let omega = copied.worldAngularVelocity
    let axis = omega * (1 / omega.length)
    let angle = omega.length * copied.duration
    let vector = copied.start.orientation.x
    let rotated =
      vector * cos(angle) + axis.cross(vector) * sin(angle)
      + axis * (axis.dot(vector) * (1 - cos(angle)))
    #expect((copied.end.orientation.x - rotated).length < 1e-12)
  }

  @Test func emptySceneStillValidatesMotionPoseBoundsAndBudgetBeforeReturningZeroQueries() throws {
    let clear = HullSweepSafety.validateSceneMotion(sceneMotion())
    #expect(clear.safe && clear.distanceQueries == 0 && clear.triangleTests == 0)
    var reflected = ShipPose(position: .init(0, 0, -150))
    reflected.orientation.x = .init(-1, 0, 0)
    for invalid in [
      sceneMotion(duration: 0), sceneMotion(duration: .nan),
      sceneMotion(duration: -1), sceneMotion(duration: .infinity),
      sceneMotion(velocity: .init(.nan, 0, 0)),
      sceneMotion(position: .init(.infinity, 0, 0)), sceneMotion(radius: -1),
      sceneMotion(gap: .nan), sceneMotion(gap: -1),
      sceneMotion(end: reflected), sceneMotion(end: .init(position: .init(1, 2, 3))),
    ] {
      #expect(!HullSweepSafety.validateSceneMotion(invalid).safe)
    }
    let angularMismatch = HullSceneMotion(
      start: .init(), end: .init(), initialVelocity: .init(0, 0, 0),
      acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0.2, 0),
      duration: 1, playerRadius: 2)
    #expect(HullSweepSafety.validateSceneMotion(angularMismatch).failure == .invalidMotion)
    let player = try PreparedHull(mesh: sceneMesh())
    #expect(!HullSweepSafety.validateSceneMotion(sceneMotion(radius: 1), player: player).safe)
    let budget = HullSweepBudget(
      distanceQueries: 0, triangleTests: 1, nodeVisits: 1, subdivisionDepth: 0)
    #expect(!HullSweepSafety.validateSceneMotion(sceneMotion(), budget: budget).safe)
  }

  @Test func movingObstacleCrossingClearEndpointsReportsItsActualIdentity() throws {
    let hull = try PreparedHull(mesh: sceneMesh(1))
    let obstacle = HullSweepObstacle(
      identity: sceneActor, hull: hull, pose: .init(position: .init(-10, 0, -150)),
      velocity: .init(20, 0, 0))
    for x in [-10.0, 10] {
      let endpoint = HullSweepObstacle(
        identity: sceneActor, hull: hull, pose: .init(position: .init(x, 0, -150)))
      #expect(HullSweepSafety.validateSceneMotion(sceneMotion(), obstacles: [endpoint]).safe)
    }
    let result = HullSweepSafety.validateSceneMotion(sceneMotion(), obstacles: [obstacle])
    #expect(!result.safe && result.obstacle == sceneActor)
    let cube = sceneMesh(1)
    let arm = try PreparedHull(
      mesh: Mesh(
        vertices: cube.vertices.map { .init($0.x * 20, $0.y, $0.z) },
        faces: cube.faces, preserveWinding: true))
    let pose = ShipPose(position: .init(0, 0, -160))
    let still = HullSweepObstacle(identity: sceneActor, hull: arm, pose: pose)
    #expect(HullSweepSafety.validateSceneMotion(sceneMotion(), obstacles: [still]).safe)
    let spinning = HullSweepObstacle(
      identity: sceneActor, hull: arm, pose: pose, angularVelocity: .init(0, .pi, 0))
    let crossed = HullSweepSafety.validateSceneMotion(sceneMotion(), obstacles: [spinning])
    #expect(!crossed.safe && crossed.obstacle == sceneActor)
  }

  @Test func rotatedContainmentAndAmbiguousOpenComponentsFailClosed() throws {
    let mesh = sceneMesh()
    let hull = try PreparedHull(mesh: mesh)
    var pose = ShipPose(position: .init(0, 0, -150))
    pose.orientation.x = .init(0, 1, 0)
    pose.orientation.y = .init(-1, 0, 0)
    let contained = HullSweepSafety.validateSceneMotion(
      sceneMotion(), obstacles: [.init(identity: sceneActor, hull: hull, pose: pose)])
    #expect(contained.failure == .insideHull && contained.obstacle == sceneActor)
    let open = try PreparedHull(
      mesh: Mesh(
        vertices: mesh.vertices, faces: Array(mesh.faces.dropLast()), preserveWinding: true))
    let ambiguous = HullSweepSafety.validateSceneMotion(
      sceneMotion(), obstacles: [.init(identity: sceneActor, hull: open, pose: pose)])
    #expect(ambiguous.failure == .unproven && ambiguous.obstacle == sceneActor)
  }

  @Test func explicitPrimaryMatchesTargetedProofAndOverridesRemainLocal() throws {
    let hull = try PreparedHull(mesh: sceneMesh())
    let target = RelativeWorkTarget(
      identity: sceneActor, pose: .init(), velocity: .init(0, 0, 0),
      angularVelocity: .init(0, 0, 0), surfacePoint: .init(0, 0, -10),
      surfaceNormal: .init(0, 0, -1))
    let sweep = RelativeWorkSweep(
      purpose: .work, start: .init(position: .init(0, 0, -150)),
      end: .init(position: .init(0, 0, -150)), initialVelocity: .init(0, 0, 0),
      acceleration: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), target: target,
      targetEnd: .init(), surfacePosition: .init(0, 0, -10), workPosition: .init(0, 0, -150),
      playerRadius: 2, requiredClearance: 120, duration: 1)
    let obstacle = HullSweepObstacle(identity: sceneActor, hull: hull, pose: .init())
    let targeted = HullSweepSafety.validate(sweep, target: hull)
    let scene = HullSweepSafety.validateSceneMotion(
      HullSceneMotion(from: sweep), obstacles: [obstacle])
    #expect(scene.safe == targeted.safe && scene.failure == targeted.failure)
    #expect(scene.minimumSampledClearance == targeted.minimumSampledClearance)
    #expect(
      scene.distanceQueries == targeted.distanceQueries
        && scene.triangleTests == targeted.triangleTests)
    #expect(scene.nodeVisits == targeted.nodeVisits)
    for gap in [0.0, 139, -1, .nan, .infinity] {
      let result = HullSweepSafety.validateSceneMotion(
        HullSceneMotion(from: sweep),
        obstacles: [
          .init(identity: sceneActor, hull: hull, pose: .init(), clearanceOverride: gap)
        ])
      #expect(result.safe == (gap == 0))
      if gap < 0 || !gap.isFinite { #expect(result.failure == .invalidMotion) }
    }
    let podHull = try PreparedHull(mesh: sceneMesh(1))
    let near = HullSweepObstacle(
      identity: .init(system: sceneActor.system, visit: 1, entity: 43), hull: podHull,
      pose: .init(position: .init(0, 0, -154)), clearanceOverride: 0)
    let inherited = HullSweepObstacle(
      identity: .init(system: sceneActor.system, visit: 1, entity: 44), hull: podHull,
      pose: .init(position: .init(0, 0, -146)))
    let first = HullSweepSafety.validateSceneMotion(
      HullSceneMotion(from: sweep), obstacles: [obstacle, near])
    #expect(first.safe)
    let second = HullSweepSafety.validateSceneMotion(
      HullSceneMotion(from: sweep), obstacles: [obstacle, near, inherited])
    #expect(!second.safe && second.obstacle == inherited.identity)

  }

  @Test func exhaustedBudgetAndStrictNumericalHeadroomNeverBecomeClear() throws {
    let hull = try PreparedHull(mesh: sceneMesh())
    let obstacle = HullSweepObstacle(identity: sceneActor, hull: hull, pose: .init())
    let exhausted = HullSweepSafety.validateSceneMotion(
      sceneMotion(), obstacles: [obstacle],
      budget: .init(distanceQueries: 1, triangleTests: 1, nodeVisits: 1, subdivisionDepth: 0))
    #expect(exhausted.failure == .workBudgetExceeded && exhausted.obstacle == sceneActor)
    for z in [-12.0, -20, -20.000000001] {
      let result = HullSweepSafety.validateSceneMotion(
        sceneMotion(position: .init(0, 0, z), gap: z == -12 ? 0 : 8), obstacles: [obstacle])
      #expect(!result.safe && result.obstacle == sceneActor)
    }
  }
}
