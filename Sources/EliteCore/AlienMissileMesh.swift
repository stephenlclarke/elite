import Foundation

/// A swept three-prong body shared by drawing, occlusion and physical raycasts.
/// The stock envelope is retained; the two notches are real empty space.
enum AlienMissileMesh {
  static let mesh: Mesh = {
    let stock = Mesh.hull(.missile)
    let width = stock.vertices.map { abs($0.x) }.max() ?? 30
    let height = stock.vertices.map { abs($0.y) }.max() ?? 18
    let length = stock.vertices.map { abs($0.z) }.max() ?? 30
    let outline: [(Double, Double)] = [
      (-8, -30), (8, -30), (30, 20), (18, 30), (10, 0),
      (0, 18), (-10, 0), (-18, 30), (-30, 20),
    ]
    let vertices = [-1.0, 1.0].flatMap { layer in
      outline.map { x, z in Vector3(x * width / 30, layer * height, z * length / 30) }
    }
    // Triangulate the concave caps explicitly, leaving both fork gaps open.
    let cap = [[1, 2, 3], [1, 3, 4], [1, 4, 5], [1, 5, 6], [7, 8, 0], [6, 7, 0], [0, 1, 6]]
    let count = outline.count
    var faces = cap
    faces += cap.map { $0.reversed().map { $0 + count } }
    for index in outline.indices {
      let next = (index + 1) % count
      faces.append([index, index + count, next + count, next])
    }
    return Mesh(vertices: vertices, faces: faces, preserveWinding: true)
  }()
}
