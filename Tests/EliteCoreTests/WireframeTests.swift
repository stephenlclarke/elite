import EliteCore
import Foundation
import Testing

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
  let points = Mesh.hull(body.hull).vertices.map { vertex -> Point2 in
    let p = vertex.rotated(pitch: body.rotation * 0.4, roll: body.rotation) + body.position
    return Point2(x: 128 + p.x * 256 / p.z, y: 96 - p.y * 256 / p.z)
  }
  let boundary = outline(points)
  return boundary.indices.allSatisfy {
    covered(boundary[$0], boundary[($0 + 1) % boundary.count], by: frame.shipLines)
  }
}

@Test func rotatingHullsKeepEverySilhouetteSegment() {
  var game = Game(executive: false)
  game.screen = .front
  for hull in Hull.allCases {
    // Five rolls and two pitch turns cover the complete combined rotation.
    for step in 0..<720 {
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
  for step in 0..<720 {
    let rotation = Double(step) * .pi / 72
    game.time = rotation / 0.6
    let frame = Display.render(game, rasterizeGraphics: false)
    let joined = frame.shipLines.indices.allSatisfy { index in
      let line = frame.shipLines[index]
      return [(line.x0, line.y0), (line.x1, line.y1)].allSatisfy { x, y in
        frame.shipLines.indices.contains { other in
          guard index != other else { return false }
          let next = frame.shipLines[other]
          return hypot(x - next.x0, y - next.y0) < 1e-6
            || hypot(x - next.x1, y - next.y1) < 1e-6
        }
      }
    }
    #expect(joined, "Open title outline at rotation step \(step)")
    #expect(frame.shipLines.allSatisfy { min($0.y0, $0.y1) > 29 && max($0.y0, $0.y1) < 163 })
  }
}
