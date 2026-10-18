import Foundation
import Testing

@testable import EliteCore

private func placementBox() -> Mesh {
  Mesh(
    vertices: [
      .init(-10, -10, -10), .init(10, -10, -10), .init(10, 10, -10), .init(-10, 10, -10),
      .init(-10, -10, 10), .init(10, -10, 10), .init(10, 10, 10), .init(-10, 10, 10),
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
    ], preserveWinding: true)
}

private func mixedSourceSupport(_ support: [Vector3]) -> Mesh {
  Mesh(
    vertices: support + [.init(100, 100, 100), .init(101, 100, 100), .init(100, 101, 100)],
    faces: [[0, 1, 2], [3, 4, 5]], preserveWinding: true)
}

private func dualClusterMesh(
  near: Double = 0, far: Double, z: Double = 0, reversed: Bool = false,
  conditioned: Bool = false
) -> Mesh {
  var vertices: [Vector3] = []
  var faces: [[Int]] = []
  // Deliberately retain far-first source order; the immutable BVH groups spatially.
  for x in [far, near] {
    for row in 0..<8 {
      let y = Double(row * 2)
      let index = vertices.count
      let zero = conditioned && x == far && row == 7
      let sliver = conditioned && x == near && row == 7
      vertices += [
        .init(x, y, z), .init(x + 1, y, z),
        .init(x + (zero ? 0.5 : 0), y + (zero ? 0 : sliver ? 1e-9 : 1), z),
      ]
      faces.append([index, index + 1, index + 2])
    }
  }
  return Mesh(
    vertices: vertices, faces: reversed ? Array(faces.reversed()) : faces, preserveWinding: true)
}

private func dualStationaryMotion(_ player: PreparedHull, pose: ShipPose = .init())
  -> HullSceneMotion
{
  .init(
    start: pose, end: pose, initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
    worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: player.radius)
}

struct HullSweepPlacementTests {
  @Test func separationRequiresStrictGapAndNumericalHeadroomAndRejectsInterior() throws {
    let hull = try PreparedHull(mesh: placementBox())
    for x in [0.0, 10, 11.9, 12, 20, 20.000000001] {
      let result = HullSweepSafety.validatePlacement(
        center: .init(x, 0, 0), radius: 2, hull: hull, pose: .init(), requiredClearance: 8)
      #expect(!result.safe)
    }
    let clear = HullSweepSafety.validatePlacement(
      center: .init(20.001, 0, 0), radius: 2, hull: hull, pose: .init(), requiredClearance: 8)
    #expect(clear.safe)
    #expect(abs((clear.minimumSampledClearance ?? 0) - 8.001) < 1e-10)
    let inside = HullSweepSafety.validatePlacement(
      center: .init(0, 0, 0), radius: 1, hull: hull, pose: .init())
    #expect(inside.failure == .insideHull)
  }

  @Test func translatedRotatedPoseUsesNativeSurfaceAndRejectsReflectedOrMalformedBasis() throws {
    let hull = try PreparedHull(mesh: placementBox())
    var pose = ShipPose(position: .init(100, 200, 300))
    pose.orientation.x = .init(0, 1, 0)
    pose.orientation.y = .init(-1, 0, 0)
    pose.orientation.z = .init(0, 0, 1)
    let result = HullSweepSafety.validatePlacement(
      center: .init(100, 230, 300), radius: 2, hull: hull, pose: pose, requiredClearance: 8)
    #expect(result.safe && result.minimumSampledClearance == 18)
    for axis in [Vector3(0, -1, 0), Vector3(0, 2, 0), Vector3(.nan, 0, 0)] {
      pose.orientation.x = axis
      let invalid = HullSweepSafety.validatePlacement(
        center: .init(100, 230, 300), radius: 2, hull: hull, pose: pose)
      #expect(!invalid.safe && invalid.failure == .invalidMotion)
    }
  }

  @Test func invalidInputsAndExhaustedGeometryBudgetFailClosed() throws {
    let hull = try PreparedHull(mesh: placementBox())
    for radius in [0.0, -1, .nan, .infinity] {
      #expect(
        !HullSweepSafety.validatePlacement(
          center: .init(30, 0, 0), radius: radius, hull: hull, pose: .init()
        ).safe)
    }
    for gap in [-1.0, .nan, .infinity] {
      #expect(
        !HullSweepSafety.validatePlacement(
          center: .init(30, 0, 0), radius: 2, hull: hull, pose: .init(), requiredClearance: gap
        ).safe)
    }
    for x in [Double.nan, .infinity, -.infinity] {
      #expect(
        !HullSweepSafety.validatePlacement(
          center: .init(x, 0, 0), radius: 2, hull: hull, pose: .init()
        ).safe)
    }
    let exhausted = HullSweepSafety.validatePlacement(
      center: .init(30, 0, 0), radius: 2, hull: hull, pose: .init(),
      budget: .init(distanceQueries: 1, triangleTests: 1, nodeVisits: 1, subdivisionDepth: 0))
    #expect(!exhausted.safe && exhausted.failure == .workBudgetExceeded)
  }

  @Test func otherClosedComponentAndAmbiguousOpenInteriorCannotBeIgnored() throws {
    let box = placementBox()
    let joined = Mesh(
      vertices: box.vertices + box.vertices.map { $0 + Vector3(40, 0, 0) },
      faces: box.faces + box.faces.map { $0.map { $0 + box.vertices.count } },
      preserveWinding: true)
    let components = try PreparedHull(mesh: joined)
    let wing = HullSweepSafety.validatePlacement(
      center: .init(40, 0, 0), radius: 2, hull: components, pose: .init())
    #expect(!wing.safe && wing.failure == .insideHull)
    let open = try PreparedHull(
      mesh: Mesh(
        vertices: box.vertices, faces: Array(box.faces.dropLast()), preserveWinding: true))
    let ambiguous = HullSweepSafety.validatePlacement(
      center: .init(0, 0, 0), radius: 1, hull: open, pose: .init())
    #expect(!ambiguous.safe && ambiguous.failure == .unproven)
  }

  @Test func actualSH005ReleasedLotMustProveGlobalMeshClearanceRatherThanRayDistance() throws {
    // Source /tmp/elite-composed-admission-geometry.json SHA-256:
    // bfe02fc7df3ed66d8b3971cf25bf38f32d997774a4f3abb6dc36cd7a3a5d527e
    // Its 28.80603689960958 distance is along the work ray, not global surface distance.
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: "SH005"))
    let mesh = profile.mesh
    #expect(mesh.vertices.count == 3101 && mesh.faces.count == 1413)
    #expect(profile.sections.first?.index == 0 && profile.sections.first?.sourceFaceIndex == 508)
    let hull = try PreparedHull(mesh: mesh)
    var pose = ShipPose(position: .init(56.917199999999994, 0.4053399999999999, 731.2808))
    pose.orientation.x = .init(0, 1, 0)
    pose.orientation.y = .init(0, 0, -1)
    pose.orientation.z = .init(-1, 0, 0)
    let result = HullSweepSafety.validatePlacement(
      center: .init(0, 0, 671.1939631003904),
      radius: Vector3(10.857670466379625, 10.857670466379625, 10.857670466379625).length,
      hull: hull, pose: pose, requiredClearance: 8)
    #expect(
      result.safe,
      "Actual released lot must be globally separated; failure: \(String(describing: result.failure))"
    )
    #expect((result.minimumSampledClearance ?? -.infinity) > 8)
  }

  @Test(arguments: [0.000001, 0.25, 1.0, 4.0, 1_000_000.0])
  func resolvedThinSurfacePlacementPreservesScaleTranslationAndStrictGap(scale: Double) throws {
    for translation in [Vector3(0, 0, 0), .init(10000, -30000, 20000)] {
      for reversed in [false, true] {
        let local = [Vector3(0, 0, 0), .init(10, 0, 0), .init(10, 0.000001, 0)]
        let mesh = Mesh(
          vertices: local.map { $0 * scale + translation },
          faces: [reversed ? [2, 1, 0] : [0, 1, 2]], preserveWinding: true)
        if scale == 0.000001 && translation != Vector3(0, 0, 0) {
          // This translation loses the entire thin dimension in the stored Doubles.
          // Refusing it is required; silently perturbing/welding a surface is not repair.
          #expect(mesh.vertices[1] == mesh.vertices[2])
          #expect(throws: HullSweepFailure.invalidGeometry) { try PreparedHull(mesh: mesh) }
          continue
        }
        let hull = try PreparedHull(mesh: mesh)
        #expect(hull.triangleCount == 1 && !hull.isClosed)
        let radius = scale
        let gap = 2 * scale
        let boundary = translation + Vector3(5 * scale, 0, radius + gap)
        let refused = HullSweepSafety.validatePlacement(
          center: boundary, radius: radius, hull: hull, pose: .init(), requiredClearance: gap)
        #expect(!refused.safe)
        let additionalGap = max(0.1, 0.01 * scale)
        let clear = HullSweepSafety.validatePlacement(
          center: boundary + Vector3(0, 0, additionalGap), radius: radius,
          hull: hull, pose: .init(), requiredClearance: gap)
        #expect(clear.safe)
        // A conservative lower bound cannot exceed this independently known plane gap.
        #expect((clear.minimumSampledClearance ?? .infinity) <= gap + additionalGap + 1e-9)
      }
    }
  }

  @Test func thinSurfaceCrossingAndNearParallelPlayerEdgesNeverGrantFalseClearance() throws {
    let target = try PreparedHull(
      mesh: Mesh(
        vertices: [.init(0, 0, 0), .init(10, 0, 0), .init(10, 0.000001, 0)],
        faces: [[0, 1, 2]], preserveWinding: true))
    let player = try PreparedHull(mesh: placementBox())
    for exact in [false, true] {
      let start = ShipPose(position: .init(5, 0, -20))
      let end = ShipPose(position: .init(5, 0, 20))
      let motion = HullSceneMotion(
        start: start, end: end, initialVelocity: .init(0, 0, 400),
        acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
        duration: 0.1, playerRadius: player.radius)
      let result = HullSweepSafety.validateSceneMotion(
        motion, player: exact ? player : nil,
        obstacles: [.init(hull: target, pose: .init())])
      #expect(!result.safe)
    }
    let invalidBudget = HullSweepSafety.validatePlacement(
      center: .init(5, 0, 20), radius: 1, hull: target, pose: .init(),
      budget: .init(distanceQueries: 1, triangleTests: 0, nodeVisits: 1, subdivisionDepth: 0))
    #expect(!invalidBudget.safe && invalidBudget.failure == .invalidMotion)
    #expect(invalidBudget.distanceQueries == 0 && invalidBudget.triangleTests == 0)
    let clearMotion = HullSceneMotion(
      start: .init(position: .init(5, 0, 20)), end: .init(position: .init(5.1, 0, 20)),
      initialVelocity: .init(1, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: 1)
    let exhausted = HullSweepSafety.validateSceneMotion(
      clearMotion, obstacles: [.init(hull: target, pose: .init())],
      budget: .init(distanceQueries: 1, triangleTests: 100, nodeVisits: 100, subdivisionDepth: 0))
    #expect(!exhausted.safe)
    #expect(exhausted.failure == .workBudgetExceeded)
    #expect(exhausted.distanceQueries == 1 && exhausted.triangleTests > 0)
    #expect((exhausted.minimumSampledClearance ?? 0) > 0)
  }

  @Test func sourceSegmentSupportKeepsCollisionAndProvesUsefulExteriorSeparation() throws {
    let hull = try PreparedHull(
      mesh: mixedSourceSupport([.init(0, 0, 0), .init(10, 0, 0), .init(5, 0, 0)]))
    #expect(hull.triangleCount == 2 && !hull.isClosed)
    for pose in [ShipPose(), .init(position: .init(1000, -2000, 3000))] {
      let clear = HullSweepSafety.validatePlacement(
        center: pose.systemPoint(.init(5, 3, 4)), radius: 1, hull: hull, pose: pose)
      #expect(clear.safe)
      // The original segment's exact distance is 5; radius 1 leaves separation 4.
      #expect((clear.minimumSampledClearance ?? 0) > 3.999999)
      #expect((clear.minimumSampledClearance ?? .infinity) <= 4)
      let blocked = HullSweepSafety.validatePlacement(
        center: pose.systemPoint(.init(5, 0, 0.5)), radius: 1, hull: hull, pose: pose)
      #expect(!blocked.safe)
    }
  }

  @Test func unresolvedNonzeroSourceTriangleKeepsItsFilledInterior() throws {
    let epsilon = Double.ulpOfOne / 8
    let hull = try PreparedHull(
      mesh: mixedSourceSupport([.init(-1, -1, 0), .init(1, 1, 0), .init(0, epsilon, 0)]))
    // This exactly representable point is .25*A + .25*B + .5*C. All three edges
    // are a positive distance away; an edge-only replacement would miss the filled interior.
    let interior = HullSweepSafety.validatePlacement(
      center: .init(0, epsilon / 2, 0), radius: Double.leastNormalMagnitude,
      hull: hull, pose: .init())
    #expect(!interior.safe)
    #expect((interior.minimumSampledClearance ?? .infinity) <= 0)
    let exterior = HullSweepSafety.validatePlacement(
      center: .init(0, epsilon / 2, 10), radius: 1, hull: hull, pose: .init())
    #expect(exterior.safe)
    #expect((exterior.minimumSampledClearance ?? 0) > 8.999999)
  }

  @Test func originalSupportRejectsCrossingsAndAllowsSeparatedExactPlayerMotion() throws {
    let hull = try PreparedHull(
      mesh: mixedSourceSupport([.init(0, 0, 0), .init(10, 0, 0), .init(5, 0, 0)]))
    let player = try PreparedHull(mesh: placementBox())
    for exact in [false, true] {
      let clearMotion = HullSceneMotion(
        start: .init(position: .init(5, 0, 40)), end: .init(position: .init(5.1, 0, 40)),
        initialVelocity: .init(1, 0, 0), acceleration: .init(0, 0, 0),
        worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: player.radius)
      let clear = HullSweepSafety.validateSceneMotion(
        clearMotion, player: exact ? player : nil, obstacles: [.init(hull: hull, pose: .init())])
      #expect(clear.safe)
      let crossing = HullSceneMotion(
        start: .init(position: .init(5, 0, -20)), end: .init(position: .init(5, 0, 20)),
        initialVelocity: .init(0, 0, 400), acceleration: .init(0, 0, 0),
        worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: player.radius)
      let blocked = HullSweepSafety.validateSceneMotion(
        crossing, player: exact ? player : nil, obstacles: [.init(hull: hull, pose: .init())])
      #expect(!blocked.safe)
    }
  }

  @Test func zeroOnlyComponentCannotAcquireClosedVolumeFromEdgeIncidence() throws {
    let box = placementBox()
    let mesh = Mesh(
      vertices: [Vector3(0, 0, 0), .init(10, 0, 0), .init(5, 0, 0)]
        + box.vertices.map { $0 + Vector3(100, 100, 100) },
      faces: [[0, 1, 2], [2, 1, 0]] + box.faces.map { $0.map { $0 + 3 } },
      preserveWinding: true)
    let hull = try PreparedHull(mesh: mesh)
    #expect(!hull.isClosed)
    let unresolved = HullSweepSafety.validatePlacement(
      center: .init(5, 0, 0), radius: 0.1, hull: hull, pose: .init())
    #expect(unresolved.failure == .unproven)
    let genuineInterior = HullSweepSafety.validatePlacement(
      center: .init(100, 100, 100), radius: 1, hull: hull, pose: .init())
    #expect(genuineInterior.failure == .insideHull)
  }

  @Test func supportBVHRetainsNearestPrimitiveAcrossDifferentSourceOrders() throws {
    for reversed in [false, true] {
      var vertices: [Vector3] = []
      var faces: [[Int]] = []
      for z in [40.0, 30, 20, 10, 0, 50, 60, 70, 80, 90] {
        let index = vertices.count
        vertices += [.init(0, 0, z), .init(10, 0, z), .init(5, 0, z)]
        faces.append([index, index + 1, index + 2])
      }
      let index = vertices.count
      vertices += [.init(100, 100, 100), .init(101, 100, 100), .init(100, 101, 100)]
      faces.append([index, index + 1, index + 2])
      let hull = try PreparedHull(
        mesh: Mesh(
          vertices: vertices, faces: reversed ? Array(faces.reversed()) : faces,
          preserveWinding: true))
      let result = HullSweepSafety.validatePlacement(
        center: .init(5, 0, 1), radius: 0.5, hull: hull, pose: .init())
      #expect(result.safe && result.nodeVisits > 1)
      #expect((result.minimumSampledClearance ?? 0) > 0.499999)
      #expect((result.minimumSampledClearance ?? .infinity) <= 0.5)
    }
  }

  @Test func coveredZeroSupportDoesNotPreventCertifiedClosedInteriorRefusal() throws {
    let box = placementBox()
    var faces = box.faces.filter { $0 != [0, 1, 5, 4] }
    // The zero face bridges the full 0->1 edge to the two halves on the adjacent
    // unchanged cube surface. Every edge still has two incidences; no closure is forced.
    faces += [[0, 8, 4], [8, 1, 4], [1, 5, 4], [0, 1, 8]]
    let hull = try PreparedHull(
      mesh: Mesh(
        vertices: box.vertices + [.init(0, -10, -10)], faces: faces,
        preserveWinding: true))
    #expect(hull.triangleCount == 14 && hull.isClosed)
    let inside = HullSweepSafety.validatePlacement(
      center: .init(0, 0, 0), radius: 1, hull: hull, pose: .init())
    #expect(inside.failure == .insideHull)
    let outside = HullSweepSafety.validatePlacement(
      center: .init(0, -30, -30), radius: 1, hull: hull, pose: .init())
    #expect(outside.safe)
  }

  @Test func exactTriangleBVHVisitsNearerSupportBeforeFarLeafWithinOriginalBudget() throws {
    let player = try PreparedHull(
      mesh: Mesh(
        vertices: [.init(0, 0, 0), .init(1, 0, 0), .init(0, 1, 0)],
        faces: [[0, 1, 2]], preserveWinding: true))
    var vertices: [Vector3] = []
    var faces: [[Int]] = []
    for z in [0.0, 1, 2, 3, 4, 5, 6, 7, 80, 81, 82, 83, 84, 85, 86, 87] {
      let index = vertices.count
      vertices += [
        .init(0, 0, z), .init(1, 0, z), .init(z == 87 ? 0.5 : 0, z == 87 ? 0 : 1, z),
      ]
      faces.append([index, index + 1, index + 2])
    }
    // Two eight-primitive leaves: at z=100 the right leaf must be visited first.
    // Each of three stationary samples can test eight primitives and prune the far leaf.
    // Fixed left-first traversal instead spends sixteen tests in its first sample.
    let budget = HullSweepBudget(
      distanceQueries: 3, triangleTests: 24, nodeVisits: 9, subdivisionDepth: 0)
    for reversed in [false, true] {
      let hull = try PreparedHull(
        mesh: Mesh(
          vertices: vertices, faces: reversed ? Array(faces.reversed()) : faces,
          preserveWinding: true))
      #expect(hull.triangleCount == 16)
      for z in [100.0, 87] {
        let pose = ShipPose(position: .init(0, 0, z))
        let motion = HullSceneMotion(
          start: pose, end: pose, initialVelocity: .init(0, 0, 0),
          acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
          duration: 0.1, playerRadius: player.radius)
        let result = HullSweepSafety.validateSceneMotion(
          motion, player: player, obstacles: [.init(hull: hull, pose: .init())], budget: budget)
        if z == 100 {
          #expect(result.safe)
          #expect(
            result.distanceQueries == 3 && result.triangleTests == 24 && result.nodeVisits == 9)
          #expect((result.minimumSampledClearance ?? 0) > 12.999999)
          #expect((result.minimumSampledClearance ?? .infinity) <= 13)
        } else {
          #expect(!result.safe)
        }
      }
    }
  }

  @Test func ordinaryExactPlayerRigidTransformsRetainUsefulSurfaceClearance() throws {
    let player = try PreparedHull(
      mesh: Mesh(
        vertices: [.init(0, 0, 0), .init(10, 0, 0), .init(0, 10, 0)],
        faces: [[0, 1, 2]], preserveWinding: true))
    let obstacle = try PreparedHull(
      mesh: Mesh(
        vertices: [.init(-100, -100, 0), .init(100, -100, 0), .init(0, 100, 0)],
        faces: [[0, 1, 2]], preserveWinding: true))
    for offset in [Vector3(0, 0, 0), .init(1000, -2000, 3000)] {
      var pose = ShipPose(position: offset + Vector3(0, 0, 30))
      pose.orientation.x = .init(0, 1, 0)
      pose.orientation.y = .init(-1, 0, 0)
      let motion = HullSceneMotion(
        start: pose, end: pose, initialVelocity: .init(0, 0, 0),
        acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
        duration: 0.1, playerRadius: player.radius)
      let result = HullSweepSafety.validateSceneMotion(
        motion, player: player, obstacles: [.init(hull: obstacle, pose: .init(position: offset))])
      #expect(result.safe && result.distanceQueries == 3)
      #expect(abs((result.minimumSampledClearance ?? 0) - 30) < 1e-8)
    }
  }

  @Test func nearCollinearExactPlayerTransformRetainsConservativeContactAndExterior() throws {
    let player = try PreparedHull(
      mesh: Mesh(
        vertices: [.init(0, 0, 0), .init(10, 0, 0), .init(10, 0.000001, 0)],
        faces: [[0, 1, 2]], preserveWinding: true))
    let obstacle = try PreparedHull(mesh: placementBox())
    for z in [30.0, 10] {
      let pose = ShipPose(position: .init(0, 0, z))
      let motion = HullSceneMotion(
        start: pose, end: pose, initialVelocity: .init(0, 0, 0),
        acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
        duration: 0.1, playerRadius: player.radius)
      let result = HullSweepSafety.validateSceneMotion(
        motion, player: player, obstacles: [.init(hull: obstacle, pose: .init())])
      if z == 30 {
        #expect(result.safe && (result.minimumSampledClearance ?? 0) > 19.999999)
      } else {
        #expect(!result.safe)
      }
    }
  }

  @Test func representedRigidTransformCollapseKeepsActualNumericalUnknownRefusal() throws {
    let vertices = [Vector3(0, 0, 0), .init(1, 0, 0), .init(0, 1, 0)]
    let player = try PreparedHull(
      mesh: Mesh(vertices: vertices, faces: [[0, 1, 2]], preserveWinding: true))
    let obstacle = try PreparedHull(
      mesh: Mesh(
        vertices: [.init(-100, -100, 100000), .init(100, -100, 100000), .init(0, 100, 100000)],
        faces: [[0, 1, 2]], preserveWinding: true))
    let pose = ShipPose(position: .init(1e20, 1e20, 1e20))
    let represented = vertices.map { pose.shipPoint(pose.systemPoint($0)) }
    try #require(represented.allSatisfy { $0 == .init(0, 0, 0) })
    let motion = HullSceneMotion(
      start: pose, end: pose, initialVelocity: .init(0, 0, 0),
      acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
      duration: 0.1, playerRadius: player.radius)
    let result = HullSweepSafety.validateSceneMotion(
      motion, player: player, obstacles: [.init(hull: obstacle, pose: pose)])
    #expect(!result.safe && result.failure == .unproven)
    // The standard subdivision budget is retained: large numerical headroom stays
    // unresolved after the endpoint/midpoint checks and attempts further subdivision.
    #expect(result.distanceQueries > 3 && result.triangleTests > 0)
    #expect((result.minimumSampledClearance ?? 0) > 99999)
  }

  @Test func dualBVHProvesNearFarClustersWithinSamePrimitiveBudgetRegardlessOfSourceOrder() throws {
    let budget = HullSweepBudget(
      distanceQueries: 3, triangleTests: 192, nodeVisits: 96, subdivisionDepth: 0)
    for reversed in [false, true] {
      for conditioned in [false, true] {
        let player = try PreparedHull(
          mesh: dualClusterMesh(far: 500, reversed: reversed, conditioned: conditioned))
        let obstacle = try PreparedHull(mesh: dualClusterMesh(far: 2000, z: 10))
        #expect(player.triangleCount == 16 && obstacle.triangleCount == 16)
        let result = HullSweepSafety.validateSceneMotion(
          dualStationaryMotion(player), player: player,
          obstacles: [.init(hull: obstacle, pose: .init())], budget: budget)
        // Near leaves require at most 8*8 paid pairs per sample; certified row pruning
        // may reduce that work, including when a conditioned lower bound is below exact10.
        // Far leaves retain certified gaps >499. The original192-pair budget is unchanged.
        #expect(result.safe && result.distanceQueries == 3)
        #expect(result.triangleTests > 0 && result.triangleTests <= budget.triangleTests)
        #expect(result.nodeVisits > 0 && result.nodeVisits <= budget.nodeVisits)
        #expect((result.minimumSampledClearance ?? 0) > 9.999999)
        #expect((result.minimumSampledClearance ?? .infinity) <= 10.000001)
      }
    }
  }

  @Test func dualBVHReportsActualPrimitiveAndTwoNodeChargeExhaustion() throws {
    let player = try PreparedHull(mesh: dualClusterMesh(far: 500))
    let obstacle = try PreparedHull(mesh: dualClusterMesh(far: 2000, z: 10))
    for budget in [
      HullSweepBudget(distanceQueries: 3, triangleTests: 191, nodeVisits: 96, subdivisionDepth: 0),
      .init(distanceQueries: 3, triangleTests: 192, nodeVisits: 1, subdivisionDepth: 0),
    ] {
      let result = HullSweepSafety.validateSceneMotion(
        dualStationaryMotion(player), player: player,
        obstacles: [.init(hull: obstacle, pose: .init())], budget: budget)
      #expect(!result.safe && result.failure == .workBudgetExceeded)
      if budget.nodeVisits == 1 {
        #expect(result.nodeVisits == 1 && result.triangleTests == 0)
      } else {
        #expect(result.distanceQueries == 3 && result.triangleTests == 191)
      }
    }
  }

  @Test func dualBVHRetainsOverlapAndContinuousCrossingRefusal() throws {
    let player = try PreparedHull(mesh: dualClusterMesh(far: 500, conditioned: true))
    let obstacle = try PreparedHull(mesh: dualClusterMesh(far: 2000, z: 10))
    let overlap = HullSweepSafety.validateSceneMotion(
      dualStationaryMotion(player, pose: .init(position: .init(0, 0, 10))), player: player,
      obstacles: [.init(hull: obstacle, pose: .init())])
    #expect(!overlap.safe)
    let crossing = HullSceneMotion(
      start: .init(), end: .init(position: .init(0, 0, 20)),
      initialVelocity: .init(0, 0, 200), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: player.radius)
    let result = HullSweepSafety.validateSceneMotion(
      crossing, player: player, obstacles: [.init(hull: obstacle, pose: .init())])
    #expect(!result.safe && result.distanceQueries >= 3)
  }

  @Test func dualBVHOutwardBoundsRetainRotatedTranslatedUsefulClearance() throws {
    let player = try PreparedHull(mesh: dualClusterMesh(far: 500, conditioned: true))
    let obstacle = try PreparedHull(mesh: dualClusterMesh(far: 2000, z: 10))
    for sharedRotation in [false, true] {
      var ship = ShipPose(position: .init(1000, -2000, 3000))
      ship.orientation.x = .init(0, 1, 0)
      ship.orientation.y = .init(-1, 0, 0)
      let target = sharedRotation ? ship : ShipPose(position: ship.position)
      let result = HullSweepSafety.validateSceneMotion(
        dualStationaryMotion(player, pose: ship), player: player,
        obstacles: [.init(hull: obstacle, pose: target)])
      #expect(result.safe && result.distanceQueries == 3 && result.triangleTests > 0)
      #expect((result.minimumSampledClearance ?? 0) > 9.999999)
      #expect((result.minimumSampledClearance ?? .infinity) <= 10.000001)
    }
  }

  @Test func dualBVHCollapsedBoundsCannotOverrideActualNumericalUnknown() throws {
    let mesh = dualClusterMesh(far: 500, conditioned: true)
    let player = try PreparedHull(mesh: mesh)
    let obstacle = try PreparedHull(mesh: dualClusterMesh(far: 2000, z: 100000))
    let pose = ShipPose(position: .init(1e20, 1e20, 1e20))
    let represented = mesh.vertices.map { pose.shipPoint(pose.systemPoint($0)) }
    try #require(represented.allSatisfy { $0 == .init(0, 0, 0) })
    let result = HullSweepSafety.validateSceneMotion(
      dualStationaryMotion(player, pose: pose), player: player,
      obstacles: [.init(hull: obstacle, pose: pose)])
    #expect(!result.safe && result.failure == .unproven)
    #expect(result.distanceQueries > 3 && result.triangleTests > 0 && result.nodeVisits > 0)
    #expect((result.minimumSampledClearance ?? 0) > 99999)
  }

  @Test func dualBVHOverflowEnclosureCannotPruneAnInfiniteBestIntoClearance() throws {
    let player = try PreparedHull(mesh: dualClusterMesh(far: 500))
    let obstacle = try PreparedHull(mesh: dualClusterMesh(far: 2000, z: 10))
    let huge = 1e154
    let pose = ShipPose(position: .init(huge, 0, 0))
    let target = ShipPose(position: .init(-huge, 0, 0))
    let represented = target.shipPoint(pose.systemPoint(.init(0, 0, 0)))
    try #require(pose.position.length.isFinite && target.position.length.isFinite)
    try #require(represented.x.isFinite && !represented.length.isFinite)
    let result = HullSweepSafety.validateSceneMotion(
      dualStationaryMotion(player, pose: pose), player: player,
      obstacles: [.init(hull: obstacle, pose: target)])
    #expect(!result.safe && result.failure == .unproven)
    #expect(result.distanceQueries == 1 && result.triangleTests == 1 && result.nodeVisits >= 2)
    #expect(result.minimumSampledClearance == nil)
  }

  @Test func dualBVHLargePlayerSmallTargetFilledCrossingReachesChargedLeafRefusal() throws {
    for reversed in [false, true] {
      var vertices = [Vector3(0, -20, -5), .init(0, 20, -5), .init(0, 0, 5)]
      var faces = [[0, 1, 2]]
      for index in 1...8 {
        let x = Double(index * 100)
        let first = vertices.count
        vertices += [.init(x, 0, 100), .init(x + 1, 0, 100), .init(x, 1, 100)]
        faces.append([first, first + 1, first + 2])
      }
      // Reverse winding while preserving each component's first representative vertex.
      let playerMesh = Mesh(
        vertices: vertices, faces: reversed ? faces.map { [$0[0], $0[2], $0[1]] } : faces,
        preserveWinding: true)
      let targetVertices = [Vector3(-10, -10, 0), .init(10, -10, 0), .init(0, 10, 0)]
      let targetMesh = Mesh(
        vertices: targetVertices, faces: [reversed ? [0, 2, 1] : [0, 1, 2]],
        preserveWinding: true)
      // Target bounds have z=0, while every player component representative has z!=0.
      // The target representative has x=-10, outside every player's x>=0 component box.
      try #require(playerMesh.faces.allSatisfy { playerMesh.vertices[$0[0]].z != 0 })
      try #require(playerMesh.vertices.allSatisfy { $0.x >= 0 } && targetVertices[0].x == -10)
      let player = try PreparedHull(mesh: playerMesh)
      let target = try PreparedHull(mesh: targetMesh)
      #expect(player.triangleCount == 9 && target.triangleCount == 1)
      // At z=0 the vertical filled triangle contains x=0,y in [-10,10]; so does
      // the horizontal target. Their genuine intersection cannot be a containment refusal.
      let result = HullSweepSafety.validateSceneMotion(
        dualStationaryMotion(player), player: player,
        obstacles: [.init(hull: target, pose: .init())])
      #expect(!result.safe && result.failure == .clearanceViolation)
      #expect(result.triangleTests > 0 && result.nodeVisits >= 4 && result.distanceQueries == 1)
      #expect(result.minimumSampledClearance == 0)
    }
  }

  @Test func dualBVHRowCertificateReducesPaidPairsWhenBothPlayerLeafBoxesOverlapTarget() throws {
    var vertices: [Vector3] = []
    var faces: [[Int]] = []
    var targetVertices: [Vector3] = []
    var targetFaces: [[Int]] = []
    for x in [0.0, 1000] {
      let near = vertices.count
      vertices += [.init(x, 0, 0), .init(x + 1, 0, 0), .init(x, 1, 0)]
      faces.append([near, near + 1, near + 2])
      for row in 0..<7 {
        let y = Double(row * 2)
        let far = vertices.count
        vertices += [.init(x + 2, y, 100), .init(x + 3, y, 100), .init(x + 2, y + 1, 100)]
        faces.append([far, far + 1, far + 2])
      }
      for row in 0..<4 {
        let y = Double(row * 2)
        let first = targetVertices.count
        targetVertices += [.init(x, y, 10), .init(x + 1, y, 10), .init(x, y + 1, 10)]
        targetFaces.append([first, first + 1, first + 2])
      }
    }
    let target = try PreparedHull(
      mesh: Mesh(vertices: targetVertices, faces: targetFaces, preserveWinding: true))
    for reversed in [false, true] {
      let player = try PreparedHull(
        mesh: Mesh(
          vertices: vertices, faces: reversed ? Array(faces.reversed()) : faces,
          preserveWinding: true))
      #expect(player.triangleCount == 16 && target.triangleCount == 8)
      // BVH splits on x into two eight-primitive player leaves. Each leaf spans z=0...100
      // and intersects the target leaf box x=0...1001,y=0...7,z=10: no node can prune.
      // In each player leaf, the smaller-x near row is visited first in either source order.
      // Its eight comparisons establish exact distance10. Each of seven z=100 rows then
      // pays once for a certified distance>=90 to the whole target leaf, skipping seven pairs.
      // Three samples therefore cost 3*2*(8+7)=90 paid pairs versus 3*16*8=384 without row proof.
      let budget = HullSweepBudget(
        distanceQueries: 3, triangleTests: 90, nodeVisits: 18, subdivisionDepth: 0)
      let result = HullSweepSafety.validateSceneMotion(
        dualStationaryMotion(player), player: player,
        obstacles: [.init(hull: target, pose: .init())], budget: budget)
      #expect(result.safe && result.distanceQueries == 3)
      #expect(result.triangleTests == 90 && result.nodeVisits == 18)
      #expect(abs((result.minimumSampledClearance ?? 0) - 10) < 1e-8)
      let exhausted = HullSweepSafety.validateSceneMotion(
        dualStationaryMotion(player), player: player,
        obstacles: [.init(hull: target, pose: .init())],
        budget: .init(distanceQueries: 3, triangleTests: 89, nodeVisits: 18, subdivisionDepth: 0))
      #expect(!exhausted.safe && exhausted.failure == .workBudgetExceeded)
      #expect(exhausted.triangleTests == 89 && exhausted.distanceQueries == 3)
    }
  }
}
