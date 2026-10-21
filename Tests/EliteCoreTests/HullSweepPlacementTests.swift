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
}
