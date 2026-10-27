import Testing

@testable import EliteCore

struct NativeStationSurfaceTests {
  @Test func closedWaystationAndHeadquartersRockFaceTheExteriorWithoutFillingTheirHoles() {
    let way = NativeStationGeometry.waystation.mesh
    #expect(signedVolume(way, faces: 0..<240) > 153_000_000)
    #expect(way.vertices.count == 152 && way.faces.count == 272)
    for index in [112, 238] {
      let points = way.faces[index].map { way.vertices[$0] }
      #expect(abs(points[0].x) == 675)
      let camera = Vector3(points[0].x > 0 ? 1350 : -1350, 0, 0)
      #expect(visible(points, camera: camera))
    }
    // A closed toroidal surface has Euler characteristic zero; its central
    // passage is retained, with every shared edge still consistently oriented.
    var edges: [String: [(Int, Int)]] = [:]
    for face in way.faces.prefix(240) {
      for index in face.indices {
        let a = face[index]
        let b = face[(index + 1) % face.count]
        edges["\(min(a,b)):\(max(a,b))", default: []].append((a, b))
      }
    }
    #expect(120 - edges.count + 240 == 0)
    #expect(
      edges.values.allSatisfy {
        $0.count == 2 && $0[0].0 == $0[1].1 && $0[0].1 == $0[1].0
      })
    let hq = NativeStationGeometry.headquarters.mesh
    #expect(signedVolume(hq, faces: 0..<188) > 16_000_000_000)
    #expect(visible(hq.faces[126].map { hq.vertices[$0] }, camera: .init(-10000, 0, 0)))
  }

  @Test func bothOpenWaystationLinersFaceTheBoreAndHeadquartersBaysFaceTheirPilot() {
    let way = NativeStationGeometry.waystation.mesh
    for index in 240..<272 {
      let points = way.faces[index].map { way.vertices[$0] }
      #expect(visible(points, camera: .init(0, 0, 0)))
      #expect(visible(points, camera: .init(0, 0, index < 256 ? -1000 : 1000)))
    }
    let hq = NativeStationGeometry.headquarters.mesh
    for index in 188..<(188 + 66) {
      let points = hq.faces[index].map { hq.vertices[$0] }
      #expect(visible(points, camera: .init(0, 0, -10000)))
    }
    var bay = 0
    for y in [836.5, 86.5] {
      for x in [750.0, 250.0, -250.0, -750.0] {
        let inside = NativeStationGeometry.nativePoint(.init(x, y, 1685.8))
        let approach = NativeStationGeometry.nativePoint(.init(x, y, 2185.8))
        for index in (333 + bay * 10)..<(343 + bay * 10) {
          let points = hq.faces[index].map { hq.vertices[$0] }
          #expect(visible(points, camera: inside))
          #expect(visible(points, camera: approach))
        }
        bay += 1
      }
    }
    #expect(hq.vertices.count == 280 && hq.faces.count == 413)
  }

  @Test func effectivePortUsesTheNarrowMainBoreInsteadOfTheWiderLinerMouth() {
    let way = NativeStationGeometry.waystation
    #expect(way.docking.aperture.map { abs($0.x) }.max() == 106.72374)
    #expect(way.docking.aperture.map { abs($0.y) }.max() == 106.72374)
    #expect(way.launch.aperture == way.docking.aperture)
    let tooWide = probe(halfWidth: 110, halfHeight: 1)
    #expect(!way.docking.fits(tooWide) && !way.launch.fits(tooWide))
    #expect(way.exit(for: tooWide) == nil)
    let fits = probe(halfWidth: 106, halfHeight: 1)
    #expect(way.docking.fits(fits) && way.launch.fits(fits))
    // Embedded source mouth vertices stay unchanged; only the effective fit
    // envelope is constrained by the smaller original main body's bore.
    #expect(way.mesh.vertices[136] == Vector3(-112.80569, 46.72565, 210))
  }

  @Test func realStationTriangleStraddlingTheNearPlaneRetainsItsVisiblePanel() throws {
    let mesh = NativeStationGeometry.waystation.mesh
    let face = try #require(
      mesh.faces.first { face in
        let depth = face.map { mesh.vertices[$0].z }
        return (depth.max() ?? 0) - (depth.min() ?? 0) > 1
      })
    let points = face.map { mesh.vertices[$0] }
    let minimum = try #require(points.map(\.z).min())
    let maximum = try #require(points.map(\.z).max())
    let shifted = points.map { $0 + Vector3(0, 0, 1 - (minimum + maximum) * 0.5) }
    #expect(shifted.contains { $0.z < 1 } && shifted.contains { $0.z > 1 })
    let panel = ShipProjection.polygon(shifted)
    #expect(panel.count >= 3 && panel.allSatisfy { $0.x.isFinite && $0.y.isFinite })
  }

  private func visible(_ points: [Vector3], camera: Vector3) -> Bool {
    let normal = (points[1] - points[0]).cross(points[2] - points[0])
    return normal.dot(points[0] - camera) < 0
  }
  private func signedVolume(_ mesh: Mesh, faces: Range<Int>) -> Double {
    faces.reduce(0) { volume, index in
      let face = mesh.faces[index]
      return volume + mesh.vertices[face[0]].dot(
        mesh.vertices[face[1]].cross(mesh.vertices[face[2]])) / 6
    }
  }
  private func probe(halfWidth: Double, halfHeight: Double) -> Mesh {
    .init(
      vertices: [
        .init(-halfWidth, -halfHeight, -1), .init(halfWidth, -halfHeight, -1),
        .init(halfWidth, halfHeight, 1), .init(-halfWidth, halfHeight, 1),
      ], faces: [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]])
  }
}
