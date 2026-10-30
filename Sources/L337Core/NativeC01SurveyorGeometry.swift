import Foundation

/// C01-only authoring: the full ROC Harrier remains visual; its convex envelope is collision.
/// Concave recesses are deliberately filled. This never activates original SH026 fleet physics.
enum NativeC01SurveyorGeometry {
  struct Geometry: Sendable {
    let design: ShipDesign
    let collision: Mesh
  }
  static let harrier: Result<Geometry, any Error> = Result {
    guard let record = ShipCatalogue.ship("SH056"), record.name == "Harrier",
      record.model == "ROC-SH056", record.design.valid
    else { throw SaveError.invalidCommander }
    let original = record.design
    let envelope = try OriginalHullEnvelope(vertices: original.rawMesh.vertices)
    let scale = 65 / envelope.dimensions.z
    guard scale.isFinite, scale > 0 else { throw SaveError.invalidCommander }
    let points = original.rawMesh.vertices.map { $0 * scale }
    let design = ShipDesign(
      vertices: points.map { [$0.x, $0.y, $0.z] }, faces: original.faces,
      license: original.license,
      source: original.source + "; C01 mission-only 65m fore-aft uniform calibration",
      details: original.details, materials: original.materials,
      faceMaterials: original.faceMaterials, paletteName: original.paletteName,
      appearanceSource: original.appearanceSource, appearanceLicense: original.appearanceLicense,
      appearanceBasis: original.appearanceBasis, sourceFaceColours: original.sourceFaceColours,
      sourceTextures: original.sourceTextures, sourceFaceTextures: original.sourceFaceTextures,
      resolvedTextures: original.resolvedTextures, textures: original.textures,
      faceTextures: original.faceTextures)
    return .init(design: design, collision: try convexEnvelope(points))
  }

  static let recorder: ShipDesign = .init(
    vertices: [
      [-0.4, -0.25, -0.15], [0.4, -0.25, -0.15], [0.4, 0.25, -0.15], [-0.4, 0.25, -0.15],
      [-0.4, -0.25, 0.15], [0.4, -0.25, 0.15], [0.4, 0.25, 0.15], [-0.4, 0.25, 0.15],
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ],
    license: "MIT", source: "L337 C01 original recorder; authored closed 0.8 x 0.5 x 0.3 metre box")

  private struct Edge: Hashable, Comparable {
    let a: Int
    let b: Int
    init(_ a: Int, _ b: Int) {
      self.a = min(a, b)
      self.b = max(a, b)
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.a == rhs.a ? lhs.b < rhs.b : lhs.a < rhs.a
    }
  }

  /// Deterministic incremental hull. Every input point must lie in the final closed half-spaces.
  static func convexEnvelope(_ input: [Vector3]) throws -> Mesh {
    guard (4...4096).contains(input.count), input.allSatisfy(\.finite) else {
      throw HullSweepFailure.invalidGeometry
    }
    let epsilon = 1e-8
    var points: [Vector3] = []
    for p in input where !points.contains(where: { ($0 - p).length < epsilon }) { points.append(p) }
    guard points.count >= 4 else { throw HullSweepFailure.invalidGeometry }
    let a = 0
    let b = points.indices.max {
      (points[$0] - points[a]).length < (points[$1] - points[a]).length
    }!
    let c = points.indices.max {
      (points[b] - points[a]).cross(points[$0] - points[a]).length
        < (points[b] - points[a]).cross(points[$1] - points[a]).length
    }!
    let normal = (points[b] - points[a]).cross(points[c] - points[a])
    guard normal.length > epsilon else { throw HullSweepFailure.invalidGeometry }
    let d = points.indices.max {
      abs(normal.dot(points[$0] - points[a])) < abs(normal.dot(points[$1] - points[a]))
    }!
    guard abs(normal.dot(points[d] - points[a])) > epsilon else {
      throw HullSweepFailure.invalidGeometry
    }
    let interior = (points[a] + points[b] + points[c] + points[d]) * 0.25
    func outward(_ face: [Int]) -> [Int] {
      let x = points[face[0]]
      let y = points[face[1]]
      let z = points[face[2]]
      return (y - x).cross(z - x).dot(interior - x) > 0 ? Array(face.reversed()) : face
    }
    var faces = [[a, b, c], [a, d, b], [a, c, d], [b, d, c]].map(outward)
    for index in points.indices where ![a, b, c, d].contains(index) {
      let visible = faces.indices.filter { face in
        let f = faces[face]
        let x = points[f[0]]
        let n = (points[f[1]] - x).cross(points[f[2]] - x)
        return n.dot(points[index] - x) > epsilon * n.length
      }
      if visible.isEmpty { continue }
      var edges: [Edge: Int] = [:]
      for face in visible {
        let f = faces[face]
        for edge in [Edge(f[0], f[1]), Edge(f[1], f[2]), Edge(f[2], f[0])] {
          edges[edge, default: 0] += 1
        }
      }
      let removed = Set(visible)
      faces = faces.enumerated().filter { !removed.contains($0.offset) }.map(\.element)
      for edge in edges.keys.sorted() where edges[edge] == 1 {
        let face = outward([edge.a, edge.b, index])
        guard
          (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).length
            > epsilon
        else { throw HullSweepFailure.invalidGeometry }
        faces.append(face)
      }
      guard faces.count <= 8192 else { throw HullSweepFailure.geometryTooComplex }
    }
    let used = Set(faces.flatMap { $0 }).sorted()
    let remap = Dictionary(uniqueKeysWithValues: used.enumerated().map { ($0.element, $0.offset) })
    let mesh = Mesh(
      vertices: used.map { points[$0] }, faces: faces.map { $0.map { remap[$0]! } },
      preserveWinding: true)
    let prepared = try PreparedHull(mesh: mesh)
    guard prepared.isClosed else { throw HullSweepFailure.invalidGeometry }
    for face in mesh.faces {
      let x = mesh.vertices[face[0]]
      let n = (mesh.vertices[face[1]] - x).cross(mesh.vertices[face[2]] - x)
      guard input.allSatisfy({ n.dot($0 - x) <= epsilon * n.length * 4 }) else {
        throw HullSweepFailure.invalidGeometry
      }
    }
    return mesh
  }
}
