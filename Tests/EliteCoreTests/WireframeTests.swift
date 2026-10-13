import Foundation
import Testing

@testable import EliteCore

private struct Point2 {
  let x: Double
  let y: Double

  func turn(_ b: Self, _ c: Self) -> Double {
    (b.x - x) * (c.y - y) - (b.y - y) * (c.x - x)
  }
}

// The projected convex outline is an independent oracle: every outer segment
// must be drawn regardless of how the mesh partitions its visible faces.
private func outline(_ points: [Point2]) -> [Point2] {
  let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
  func half(_ points: [Point2]) -> [Point2] {
    var result: [Point2] = []
    for point in points {
      while result.count >= 2
        && result[result.count - 2].turn(result[result.count - 1], point) <= 1e-8
      {
        result.removeLast()
      }
      result.append(point)
    }
    return result
  }
  return Array(half(sorted).dropLast()) + Array(half(sorted.reversed()).dropLast())
}

private func covered(_ a: Point2, _ b: Point2, by lines: [WireLine]) -> Bool {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let lengthSquared = dx * dx + dy * dy
  let intervals = lines.compactMap { line -> (Double, Double)? in
    let p = Point2(x: line.x0, y: line.y0)
    let q = Point2(x: line.x1, y: line.y1)
    guard abs(a.turn(b, p)) < 1e-6, abs(a.turn(b, q)) < 1e-6 else { return nil }
    let t0 = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared
    let t1 = ((q.x - a.x) * dx + (q.y - a.y) * dy) / lengthSquared
    return (min(t0, t1), max(t0, t1))
  }.sorted { $0.0 < $1.0 }
  var end = 0.0
  for interval in intervals {
    if interval.0 > end + 1e-6 { return false }
    end = max(end, interval.1)
    if end >= 1 - 1e-6 { return true }
  }
  return false
}

private func hasCompleteOutline(_ body: SpaceBody, in frame: Frame) -> Bool {
  if body.hull == .cobra { return hasCompleteSourceBoundary(body, in: frame) }
  let points = Mesh.hull(body.hull).vertices.map { vertex -> Point2 in
    let p =
      body.orientation.apply(
        vertex.rotated(pitch: body.hull == .station ? 0 : body.rotation * 0.4, roll: body.rotation))
      + body.position
    return Point2(x: 128 + p.x * 256 / p.z, y: 96 - p.y * 256 / p.z)
  }
  let boundary = outline(points)
  return boundary.indices.allSatisfy {
    covered(boundary[$0], boundary[($0 + 1) % boundary.count], by: frame.shipLines)
  }
}

// Source craft are not convex. Weld source vertices once and independently
// identify front/back face boundaries at every tested camera orientation.
private struct SourceBoundaryOracle: Sendable {
  let mesh: Mesh
  let faces: [(normal: Vector3, center: Vector3)]
  let edges: [(a: Int, b: Int, adjacent: [Int])]
  init() {
    mesh = Mesh.hull(.cobra)
    let tokens = mesh.vertices.map { p in
      "\(Int((p.x * 1e6).rounded()))/\(Int((p.y * 1e6).rounded()))/\(Int((p.z * 1e6).rounded()))"
    }
    var faceData: [(normal: Vector3, center: Vector3)] = []
    var edgeData: [String: (a: Int, b: Int, adjacent: [Int])] = [:]
    for (faceIndex, face) in mesh.faces.enumerated() {
      var normal = Vector3(0, 0, 0)
      var center = Vector3(0, 0, 0)
      for index in face.indices {
        let a = mesh.vertices[face[index]]
        let b = mesh.vertices[face[(index + 1) % face.count]]
        normal =
          normal
          + Vector3(
            (a.y - b.y) * (a.z + b.z),
            (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
        center = center + a
        let key = [tokens[face[index]], tokens[face[(index + 1) % face.count]]].sorted().joined(
          separator: ":")
        var edge = edgeData[key] ?? (face[index], face[(index + 1) % face.count], [])
        edge.adjacent.append(faceIndex)
        edgeData[key] = edge
      }
      faceData.append((normal, center * (1 / Double(face.count))))
    }
    faces = faceData
    edges = Array(edgeData.values)
  }
}
private let cobraBoundaryOracle = SourceBoundaryOracle()

private func hasCompleteSourceBoundary(_ body: SpaceBody, in frame: Frame) -> Bool {
  let oracle = cobraBoundaryOracle
  let vertices = oracle.mesh.vertices.map { body.modelVector($0) + body.position }
  let facing = oracle.faces.map {
    body.modelVector($0.normal).dot(body.modelVector($0.center) + body.position) < 0
  }
  let boundary = oracle.edges.filter { edge in
    let visible = edge.adjacent.map { facing[$0] }
    return visible.contains(true) && (visible.count == 1 || visible.contains(false))
  }
  let lines = frame.shipLines
  return !boundary.isEmpty
    && boundary.allSatisfy { edge in
      let p = vertices[edge.a]
      let q = vertices[edge.b]
      return covered(
        .init(x: 128 + p.x * 256 / p.z, y: 96 - p.y * 256 / p.z),
        .init(x: 128 + q.x * 256 / q.z, y: 96 - q.y * 256 / q.z), by: lines)
    }
}

@Test func rotatingHullsKeepEverySilhouetteSegment() {
  var game = Game(executive: false)
  game.screen = .front
  for hull in Hull.allCases {
    // Five rolls and two pitch turns cover the complete combined rotation.
    for step in stride(from: 0, to: 720, by: hull == .cobra ? 5 : 1) {
      let rotation = Double(step) * .pi / 72
      var body = SpaceBody(id: 0, hull: hull, position: .init(0, 0, 800))
      body.rotation = rotation
      game.bodies = [body]
      let frame = Display.render(game, rasterizeGraphics: false)
      #expect(
        hasCompleteOutline(body, in: frame),
        "Missing silhouette for \(hull) at rotation step \(step)")
    }
  }
}

@Test func titleShipStaysCompleteBetweenTextRows() {
  var game = Game(executive: false)
  game.screen = .title
  for step in stride(from: 0, to: 720, by: 5) {
    let rotation = Double(step) * .pi / 72
    game.time = rotation / 0.6
    let frame = Display.render(game, rasterizeGraphics: false)
    #expect(!frame.shipPanels.isEmpty && frame.shipLines.isEmpty)
    #expect(
      frame.shipPanels.allSatisfy { panel in panel.vertices.allSatisfy { $0.y > 29 && $0.y < 163 }
      }, "Title bounds at \(step)")
    var edges = frame
    for panel in frame.shipPanels {
      for index in panel.vertices.indices {
        let a = panel.vertices[index]
        let b = panel.vertices[(index + 1) % panel.vertices.count]
        edges.graphics.append(.wire(WireLine(x0: a.x, y0: a.y, x1: b.x, y1: b.y, ink: .white)))
      }
    }
    var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 280))
    body.rotation = rotation
    #expect(hasCompleteOutline(body, in: edges), "Missing shaded title outline at \(step)")
  }
}
