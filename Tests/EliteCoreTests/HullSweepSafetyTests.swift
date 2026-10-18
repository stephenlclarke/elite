import Foundation
import Testing

@testable import EliteCore

private let hsIdentity = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 3, entity: 41)

private func hsBox(_ half: Vector3 = .init(10, 10, 10), reversed: Bool = false) -> Mesh {
  let faces = [
    [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
  ]
  return Mesh(
    vertices: [
      .init(-half.x, -half.y, -half.z), .init(half.x, -half.y, -half.z),
      .init(half.x, half.y, -half.z), .init(-half.x, half.y, -half.z),
      .init(-half.x, -half.y, half.z), .init(half.x, -half.y, half.z),
      .init(half.x, half.y, half.z), .init(-half.x, half.y, half.z),
    ], faces: reversed ? faces.map { Array($0.reversed()) } : faces, preserveWinding: true)
}

private func hsConcaveHull() -> Mesh {
  let outline: [(Double, Double)] = [(0, 0), (100, 0), (100, 20), (20, 20), (20, 100), (0, 100)]
  let vertices = [-10.0, 10.0].flatMap { y in outline.map { Vector3($0.0, y, $0.1) } }
  var faces = [Array(0..<6), Array((6..<12).reversed())]
  for index in 0..<6 {
    let next = (index + 1) % 6
    faces.append([index, next, next + 6, index + 6])
  }
  return Mesh(vertices: vertices, faces: faces, preserveWinding: true)
}

private func hsPose(_ initial: ShipPose, velocity: Vector3, omega: Vector3, time: Double)
  -> ShipPose
{
  var pose = initial
  pose.position = initial.position + velocity * time
  if omega.length > 0 {
    let axis = omega * (1 / omega.length)
    let angle = omega.length * time
    func rotate(_ point: Vector3) -> Vector3 {
      point * cos(angle) + axis.cross(point) * sin(angle) + axis
        * (axis.dot(point) * (1 - cos(angle)))
    }
    pose.orientation.x = rotate(initial.orientation.x)
    pose.orientation.y = rotate(initial.orientation.y)
    pose.orientation.z = rotate(initial.orientation.z)
  }
  return pose
}

private func hsSweep(
  position: Vector3 = .init(0, 0, -50), velocity: Vector3 = .init(0, 0, 0),
  acceleration: Vector3 = .init(0, 0, 0), omega: Vector3 = .init(0, 0, 0),
  radius: Double = 2, gap: Double = 3, duration: Double = 0.1,
  targetPosition: Vector3 = .init(0, 0, 0), targetVelocity: Vector3 = .init(0, 0, 0),
  targetOmega: Vector3 = .init(0, 0, 0), mismatchedEnd: Bool = false
) -> RelativeWorkSweep {
  var initial = ShipPose()
  initial.position = position
  var end = hsPose(initial, velocity: velocity, omega: omega, time: duration)
  end.position = end.position + acceleration * (0.5 * duration * duration)
  if mismatchedEnd { end.position.x += 1 }
  var targetPose = ShipPose()
  targetPose.position = targetPosition
  let target = RelativeWorkTarget(
    identity: hsIdentity, pose: targetPose, velocity: targetVelocity,
    angularVelocity: targetOmega, surfacePoint: .init(0, 0, -10), surfaceNormal: .init(0, 0, -1))
  return .init(
    purpose: .work, start: initial, end: end, initialVelocity: velocity, acceleration: acceleration,
    angularVelocity: omega, target: target,
    targetEnd: hsPose(targetPose, velocity: targetVelocity, omega: targetOmega, time: duration),
    surfacePosition: .init(0, 0, -10), workPosition: position,
    playerRadius: radius, requiredClearance: gap, duration: duration)
}

@Test func hullSweepUsesTwoSidedTrueSurfaceDistanceAndDetectsClosedInterior() throws {
  for reversed in [false, true] {
    let hull = try PreparedHull(mesh: hsBox(reversed: reversed))
    #expect(hull.isClosed && hull.triangleCount == 12)
    for x in [-30.0, 30.0] {
      let result = HullSweepSafety.validate(hsSweep(position: .init(x, 0, 0)), target: hull)
      #expect(result.safe && result.minimumSampledClearance == 18)
      #expect(result.clearance == .clear && result.distanceQueries == 3)
    }
    let inside = HullSweepSafety.validate(hsSweep(position: .init(0, 0, 0)), target: hull)
    #expect(!inside.safe && inside.failure == .insideHull)
  }
}

@Test func hullSweepRetainsAnalyticFaceEdgeAndCornerDistancesForBothWindingDirections() throws {
  for reversed in [false, true] {
    let obstacle = try PreparedHull(mesh: hsBox(reversed: reversed))
    let player = try PreparedHull(mesh: hsBox(.init(1, 1, 1), reversed: reversed))
    let cases: [(Vector3, Double, Double)] = [
      (.init(30, 0, 0), 20, 19),
      (.init(30, 30, 0), sqrt(800), sqrt(722)),
      (.init(30, 30, 30), sqrt(1200), sqrt(1083)),
      (.init(-30, -30, -30), sqrt(1200), sqrt(1083)),
    ]
    for (position, pointDistance, meshDistance) in cases {
      let sphere = HullSweepSafety.validate(hsSweep(position: position), target: obstacle)
      #expect(sphere.safe && sphere.distanceQueries == 3)
      #expect(abs((sphere.minimumSampledClearance ?? 0) - (pointDistance - 2)) < 1e-10)
      let exact = HullSweepSafety.validate(
        hsSweep(position: position, radius: player.radius), target: obstacle, player: player)
      #expect(exact.safe && exact.distanceQueries == 3)
      #expect(abs((exact.minimumSampledClearance ?? 0) - meshDistance) < 1e-10)
    }
  }
}

@Test func hullSweepConcaveClosedNotchIsEmptyButTheArmHasSolidInterior() throws {
  let hull = try PreparedHull(mesh: hsConcaveHull())
  #expect(hull.isClosed)
  let notch = HullSweepSafety.validate(hsSweep(position: .init(60, 0, 60), gap: 10), target: hull)
  #expect(notch.safe && abs((notch.minimumSampledClearance ?? 0) - 38) < 1e-8)
  let arm = HullSweepSafety.validate(hsSweep(position: .init(10, 0, 60), gap: 1), target: hull)
  #expect(arm.failure == .insideHull)
}

@Test func hullSweepSubdividesSafeLateralMotionAndRejectsCrossingBetweenClearEndpoints() throws {
  let hull = try PreparedHull(mesh: hsBox())
  let lateral = hsSweep(position: .init(-10, 0, -20), velocity: .init(200, 0, 0), gap: 5)
  let safe = HullSweepSafety.validate(lateral, target: hull)
  #expect(safe.safe && safe.distanceQueries > 3)
  #expect(abs((safe.minimumSampledClearance ?? 0) - 8) < 1e-8)

  let small = try PreparedHull(mesh: hsBox(.init(1, 1, 1)))
  let crossing = hsSweep(
    position: .init(-10, 0, 0), velocity: .init(200, 0, 0), radius: 0.1, gap: 0.5,
    targetPosition: .init(3, 0, 0))
  let blocked = HullSweepSafety.validate(crossing, target: small)
  #expect(!blocked.safe && blocked.distanceQueries > 3)
  #expect(blocked.failure == .insideHull || blocked.failure == .clearanceViolation)
  let grazing = hsSweep(
    position: .init(-10, 2, 0), velocity: .init(200, 0, 0), radius: 1, gap: 0)
  #expect(HullSweepSafety.validate(grazing, target: small).failure == .clearanceViolation)
}

@Test func hullSweepTracksTargetTranslationAndRotatingProtrusionsAcrossTheWholeStep() throws {
  let bar = try PreparedHull(mesh: hsBox(.init(40, 1, 1)))
  let swing = hsSweep(position: .init(0, 30, 0), gap: 2, targetOmega: .init(0, 0, .pi / 0.1))
  let result = HullSweepSafety.validate(swing, target: bar)
  #expect(!result.safe && result.failure == .insideHull)

  let cube = try PreparedHull(mesh: hsBox())
  let translating = hsSweep(velocity: .init(15, 0, 0), targetVelocity: .init(15, 0, 0))
  let together = HullSweepSafety.validate(translating, target: cube)
  #expect(together.safe && together.distanceQueries == 3)
  #expect(together.minimumSampledClearance == 38)

  var obstaclePose = ShipPose()
  obstaclePose.position = .init(-10, 0, -50)
  let movingID = ActorIdentity(system: hsIdentity.system, visit: 3, entity: 99)
  let moving = HullSweepObstacle(
    identity: movingID, hull: try PreparedHull(mesh: hsBox(.init(1, 1, 1))), pose: obstaclePose,
    velocity: .init(200, 0, 0))
  let obstructed = HullSweepSafety.validate(hsSweep(), target: cube, obstacles: [moving])
  #expect(!obstructed.safe && obstructed.obstacle == movingID && obstructed.failure == .insideHull)
}

@Test func hullSweepExactPlayerMeshUsesPrunedTrianglePairsAndTestsContainmentBothWays() throws {
  let cube = try PreparedHull(mesh: hsBox())
  let thin = try PreparedHull(mesh: hsBox(.init(20, 1, 1)))
  let motion = hsSweep(position: .init(0, 0, -15), radius: thin.radius, gap: 3)
  #expect(!HullSweepSafety.validate(motion, target: cube).safe)
  let exact = HullSweepSafety.validate(motion, target: cube, player: thin)
  #expect(exact.safe && abs((exact.minimumSampledClearance ?? 0) - 4) < 1e-8)
  #expect(exact.triangleTests <= HullSweepBudget.standard.triangleTests)
  #expect(exact.nodeVisits <= HullSweepBudget.standard.nodeVisits)
  let inner = try PreparedHull(mesh: hsBox(.init(1, 1, 1)))
  #expect(
    HullSweepSafety.validate(
      hsSweep(position: .init(0, 0, 0), radius: inner.radius), target: cube, player: inner
    ).failure == .insideHull)
  #expect(
    HullSweepSafety.validate(
      hsSweep(position: .init(0, 0, 0), radius: cube.radius), target: inner, player: cube
    ).failure == .insideHull)
  let rotating = hsSweep(
    position: .init(0, 0, -25), omega: .init(0, .pi / 0.1, 0), radius: thin.radius, gap: 1)
  #expect(!HullSweepSafety.validate(rotating, target: cube, player: thin).safe)
}

@Test func hullSweepRefusesUnprovenIntervalsAndExhaustedBudgetsWithoutEndpointApproval() throws {
  let hull = try PreparedHull(mesh: hsBox())
  let motion = hsSweep(position: .init(-10, 0, -20), velocity: .init(200, 0, 0), gap: 5)
  var depth = HullSweepBudget.standard
  depth.subdivisionDepth = 0
  let unproven = HullSweepSafety.validate(motion, target: hull, budget: depth)
  #expect(unproven.failure == .unproven && !unproven.safe)
  var queries = HullSweepBudget.standard
  queries.distanceQueries = 2
  let exhausted = HullSweepSafety.validate(motion, target: hull, budget: queries)
  #expect(exhausted.failure == .workBudgetExceeded && exhausted.distanceQueries == 2)
  var triangles = HullSweepBudget.standard
  triangles.triangleTests = 1
  #expect(
    HullSweepSafety.validate(hsSweep(), target: hull, budget: triangles).failure
      == .workBudgetExceeded)
  var nodes = HullSweepBudget.standard
  nodes.nodeVisits = 1
  #expect(
    HullSweepSafety.validate(hsSweep(), target: hull, budget: nodes).failure == .workBudgetExceeded)
}

@Test func hullSweepRejectsInvalidMeshesFramesAndNonEnclosingPlayerRadii() throws {
  #expect(throws: HullSweepFailure.geometryTooComplex) {
    try PreparedHull(mesh: hsBox(), maximumTriangles: 1)
  }
  let invalid = Mesh(
    vertices: [.init(0, 0, 0), .init(1, 0, 0), .init(0, 1, 0)], faces: [[0, 1, 9]],
    preserveWinding: true)
  #expect(throws: HullSweepFailure.invalidGeometry) { try PreparedHull(mesh: invalid) }
  let hull = try PreparedHull(mesh: hsBox())
  #expect(
    HullSweepSafety.validate(hsSweep(mismatchedEnd: true), target: hull).failure == .invalidMotion)
  #expect(HullSweepSafety.validate(hsSweep(duration: 0), target: hull).failure == .invalidMotion)
  #expect(
    HullSweepSafety.validate(hsSweep(velocity: .init(.nan, 0, 0)), target: hull).failure
      == .invalidMotion)
  #expect(
    HullSweepSafety.validate(hsSweep(radius: 1), target: hull, player: hull).failure
      == .invalidMotion)
}

@Test func hullSweepRefusesAmbiguousOpenInteriorInsteadOfTreatingItAsEmptySpace() throws {
  let box = hsBox()
  let open = try PreparedHull(
    mesh: Mesh(vertices: box.vertices, faces: Array(box.faces.dropLast()), preserveWinding: true))
  #expect(!open.isClosed)
  #expect(
    HullSweepSafety.validate(hsSweep(position: .init(0, 0, 0)), target: open).failure == .unproven)
  #expect(HullSweepSafety.validate(hsSweep(), target: open).safe)
}

@Test func hullSweepActualGeometryKeepsDriftingSpinningDepletedParentInStableHold() throws {
  let hull = try PreparedHull(mesh: hsBox())
  var target = hsSweep().target
  target.velocity = .init(5, 0, 0)
  target.angularVelocity = .init(0, 0.05, 0)
  var ship = ShipPose()
  ship.position = .init(0, 0, -161)
  var input = RelativeWorkInput(
    ship: ship, velocity: .init(-3.05, 0, 0), angularVelocity: target.angularVelocity,
    target: target, playerRadius: 30,
    limits: .init(acceleration: 40, speed: 120, pitchRate: 0.6, yawRate: 0.6, rollRate: 0.6),
    delta: 0.02)
  var controller = RelativeWorkController(parent: hsIdentity, category: .wreck)
  var selections = 0
  var completions = 0
  for frame in 0..<300 {
    if frame == 100 { input.target?.depleted = true }
    let output = controller.step(input) { sweep in
      let result = HullSweepSafety.validate(sweep, target: hull)
      #expect(result.safe)
      #expect((result.minimumSampledClearance ?? 0) > 120)
      return result.clearance
    }
    selections += output.transitions.filter { $0 == .selectTool(.salvageCutter) }.count
    completions += output.transitions.filter { $0 == .workComplete }.count
    #expect(output.motionValidated && controller.parent == hsIdentity)
    let omega = input.ship.orientation.apply(
      .init(output.pitchRate, -output.yawRate, output.rollRate))
    input.ship = hsPose(input.ship, velocity: input.velocity, omega: omega, time: input.delta)
    input.ship.position =
      input.ship.position + output.acceleration * (0.5 * input.delta * input.delta)
    input.velocity = output.velocity
    input.angularVelocity = omega
    var next = try #require(input.target)
    next.pose = hsPose(
      next.pose, velocity: next.velocity, omega: next.angularVelocity, time: input.delta)
    input.target = next
  }
  #expect(controller.status == .holding && selections == 1 && completions == 1)
}

@Test func hullSweepControllerRetainsItsParentAndAppliesOnlyPhysicallyValidatedBraking() throws {
  let hull = try PreparedHull(mesh: hsBox())
  var pose = ShipPose()
  pose.position = .init(0, 0, 500)
  let target = RelativeWorkTarget(
    identity: hsIdentity, pose: pose, velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0),
    surfacePoint: .init(0, 0, -10), surfaceNormal: .init(0, 0, -1))
  var obstaclePose = ShipPose()
  obstaclePose.position = .init(0, 0, 153.1)
  let obstacle = HullSweepObstacle(
    hull: try PreparedHull(mesh: hsBox(.init(1, 1, 1))), pose: obstaclePose)
  let input = RelativeWorkInput(
    ship: .init(), velocity: .init(0, 0, 20), angularVelocity: .init(0, 0, 0),
    target: target, playerRadius: 30,
    limits: .init(acceleration: 40, speed: 120, pitchRate: 0.6, yawRate: 0.6, rollRate: 0.6),
    delta: 0.1)
  var controller = RelativeWorkController(parent: hsIdentity, category: .wreck)
  var checks: [(RelativeWorkSweep.Purpose, HullSweepResult)] = []
  let output = controller.step(input) { sweep in
    let result = HullSweepSafety.validate(sweep, target: hull, obstacles: [obstacle])
    checks.append((sweep.purpose, result))
    return result.clearance
  }
  #expect(checks.count == 2 && checks[0].0 == .work && checks[1].0 == .braking)
  #expect(!checks[0].1.safe && checks[1].1.safe)
  #expect(output.motionValidated && output.acceleration == Vector3(0, 0, -40))
  #expect(output.velocity == Vector3(0, 0, 16) && controller.parent == hsIdentity)
  #expect(output.status == .blocked(.clearance(HullSweepFailure.clearanceViolation.message)))
}

@Test func hullSweepPreparedRawCapitalGeometryHasBoundedNativeStepWork() throws {
  for id in ["SH005", "SH045", "SH129", "SH171"] {
    let record = try #require(ShipCatalogue.ship(id))
    let raw = record.design.rawMesh
    let hull = try PreparedHull(mesh: raw)
    let top = try #require(raw.vertices.map(\.y).max())
    let motion = hsSweep(
      position: .init(0, top + 127, 0), velocity: .init(1, 0, 0), gap: 120,
      targetOmega: .init(0, 0.02, 0))
    let start = ContinuousClock.now
    var final = HullSweepSafety.validate(motion, target: hull)
    for _ in 0..<20 { final = HullSweepSafety.validate(motion, target: hull) }
    let elapsed = start.duration(to: .now)
    #expect(final.safe)
    #expect(final.distanceQueries <= HullSweepBudget.standard.distanceQueries)
    #expect(final.triangleTests <= HullSweepBudget.standard.triangleTests)
    #expect(final.nodeVisits <= HullSweepBudget.standard.nodeVisits)
    print(
      "HULL_SWEEP_BENCH \(id) triangles=\(hull.triangleCount) steps=21 elapsed=\(elapsed) queries=\(final.distanceQueries) triangleTests=\(final.triangleTests) nodes=\(final.nodeVisits) safe=\(final.safe)"
    )
  }
}

private func hsThinBox(reversed: Bool = false, open: Bool = false) -> Mesh {
  let box = hsBox(.init(10, 0.000001, 10), reversed: reversed)
  return Mesh(
    vertices: box.vertices, faces: open ? Array(box.faces.dropLast()) : box.faces,
    preserveWinding: true)
}

@Test func hullSweepPreparesOriginalTigerTraderWithoutRemovingItsThinSurface() throws {
  let ship = try #require(ShipCatalogue.ship("SH127"))
  let mesh = ship.design.rawMesh
  #expect(mesh.vertices.count == 3806 && mesh.faces.count == 7016)
  #expect(mesh.faces[747] == [227, 228, 328])
  #expect(mesh.vertices[227] == Vector3(-4.77449, 8.10366, -36.96109))
  #expect(mesh.vertices[228] == Vector3(-4.67319, 4.49747, -48.0395))
  #expect(mesh.vertices[328] == Vector3(-4.71821, 6.10022, -43.11576))
  let hull = try PreparedHull(mesh: mesh)
  #expect(hull.triangleCount == 7016)
  // The source assembly has open/nonmanifold components. Thin-face support must not
  // turn their ambiguous interior into a fictitious watertight solid.
  #expect(!hull.isClosed)
  let far = HullSweepSafety.validatePlacement(
    center: .init(0, -300, 0), radius: 69, hull: hull, pose: .init())
  #expect(far.safe)
}

@Test(arguments: [false, true])
func hullSweepResolvedThinClosedHullPreservesWindingAndInteriorRefusal(reversed: Bool) throws {
  let hull = try PreparedHull(mesh: hsThinBox(reversed: reversed))
  #expect(hull.isClosed && hull.triangleCount == 12)
  let inside = HullSweepSafety.validatePlacement(
    center: .init(0, 0, 0), radius: 0.0000001, hull: hull, pose: .init())
  #expect(!inside.safe && inside.failure == .insideHull)
  for exact in [false, true] {
    let player = exact ? try PreparedHull(mesh: hsBox(.init(1, 1, 1))) : nil
    let outside = HullSweepSafety.validate(hsSweep(), target: hull, player: player)
    #expect(outside.safe)
    let crossing = HullSweepSafety.validate(
      hsSweep(position: .init(0, -5, 0), velocity: .init(0, 100, 0), gap: 0),
      target: hull, player: player)
    #expect(!crossing.safe)
  }
}

@Test func hullSweepThinOpenInteriorAndRayBoundaryStayConservative() throws {
  let open = try PreparedHull(mesh: hsThinBox(open: true))
  #expect(!open.isClosed)
  let interior = HullSweepSafety.validatePlacement(
    center: .init(0, 0, 0), radius: 0.0000001, hull: open, pose: .init())
  #expect(interior.failure == .unproven)
  for point in [Vector3(10, 0, 0), .init(10, 0.000001, 10)] {
    let boundary = HullSweepSafety.validatePlacement(
      center: point, radius: 0.0000001, hull: open, pose: .init())
    #expect(!boundary.safe)
  }
}

@Test func hullSweepUnresolvedOrMalformedThinGeometryCannotBecomeAPreparedSurface() {
  let uncertain = 200_000_000.0.nextUp
  let vertices: [[Vector3]] = [
    [.init(0, 0, 0), .init(1, 1, 0), .init(2, 2, 0)],
    [.init(0, 0, 0), .init(100_000_000, 100_000_000, 0), .init(200_000_000, uncertain, 0)],
    [.init(0, 0, 0), .init(1, 0, 0), .init(.nan, 0.000001, 0)],
    [.init(0, 0, 0), .init(1, 0, 0), .init(.infinity, 0.000001, 0)],
  ]
  for points in vertices {
    #expect(throws: HullSweepFailure.invalidGeometry) {
      try PreparedHull(mesh: Mesh(vertices: points, faces: [[0, 1, 2]], preserveWinding: true))
    }
  }
  for faces in [[[0, 1, 9]], [[0, 1, 1]]] {
    #expect(throws: HullSweepFailure.invalidGeometry) {
      try PreparedHull(
        mesh: Mesh(
          vertices: [.init(0, 0, 0), .init(10, 0, 0), .init(10, 0.000001, 0)],
          faces: faces, preserveWinding: true))
    }
  }
  #expect(throws: HullSweepFailure.invalidGeometry) {
    try PreparedHull(
      mesh: Mesh(
        vertices: [.init(0, 0, 0), .init(2, 2, 0), .init(0, 2, 0), .init(2, 0, 0)],
        faces: [[0, 1, 2, 3]], preserveWinding: true))
  }
}

private func hsConcaveThinBridge(scale: Double, translation: Vector3, reversed: Bool) -> Mesh {
  let delta = 0.000000001
  let outline: [(Double, Double)] = [
    (-1, -1), (1, -1), (1, 0.5), (3, 0.5), (3, -1), (3 + delta, -1),
    (3 + delta, 1), (-1, 1),
  ]
  let caps = [[0, 1, 2], [0, 2, 7], [3, 4, 5], [3, 5, 6], [2, 3, 6], [2, 6, 7]]
  let vertices = [-1.0, 1.0].flatMap { v in
    outline.map { point in
      let (s, u) = point
      return Vector3(s, 0.371 * s + u, 0.529 * s + v) * scale + translation
    }
  }
  var faces = caps.map { Array($0.reversed()) } + caps.map { $0.map { $0 + 8 } }
  for i in outline.indices {
    let j = (i + 1) % outline.count
    faces += [[i, j, j + 8], [i, j + 8, i + 8]]
  }
  return Mesh(
    vertices: vertices, faces: reversed ? faces.map { Array($0.reversed()) } : faces,
    preserveWinding: true)
}

@Test(arguments: [0.25, 1.0, 4.0])
func hullSweepConcaveThinBridgeCannotHideInsideBroadArmBehindMergedCrossings(scale: Double)
  throws
{
  // The first fixed containment ray hits three broad plates at t=1,3,3+1e-9.
  // Thin connecting triangles are elsewhere in the same connected component. Conditioning
  // only the triangles hit by the ray merges its last two real crossings into false parity.
  for translation in [Vector3(0, 0, 0), .init(128, -64, 32)] {
    for reversed in [false, true] {
      let mesh = hsConcaveThinBridge(scale: scale, translation: translation, reversed: reversed)
      #expect(mesh.vertices.count == 16 && mesh.faces.count == 28)
      var edges: [[Int]: Int] = [:]
      for face in mesh.faces {
        for index in face.indices {
          let edge = [face[index], face[(index + 1) % face.count]].sorted()
          edges[edge, default: 0] += 1
        }
      }
      #expect(edges.count == 42 && edges.values.allSatisfy { $0 == 2 })
      let hull = try PreparedHull(mesh: mesh)
      #expect(hull.triangleCount == 28 && hull.isClosed)
      let point = Vector3(0, 0.1, 0.2) * scale + translation
      let inside = HullSweepSafety.validatePlacement(
        center: point, radius: 0.01 * scale, hull: hull, pose: .init())
      #expect(!inside.safe)
      #expect(inside.failure == .insideHull || inside.failure == .unproven)
      let player = try PreparedHull(mesh: hsBox(Vector3(0.01, 0.01, 0.01) * scale))
      for exact in [false, true] {
        let pose = ShipPose(position: point)
        let stationary = HullSceneMotion(
          start: pose, end: pose, initialVelocity: .init(0, 0, 0),
          acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
          duration: 0.1, playerRadius: player.radius)
        let result = HullSweepSafety.validateSceneMotion(
          stationary, player: exact ? player : nil,
          obstacles: [.init(hull: hull, pose: .init())])
        #expect(!result.safe)
        #expect(result.failure == .insideHull || result.failure == .unproven)
      }
    }
  }
}
