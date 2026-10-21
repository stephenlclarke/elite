import Foundation

extension Frame {
  mutating func worldGlow(_ line: WireLine) {
    graphics.append(.glow(line))
    if rasterizeGraphics {
      // The classic bitmap keeps the same separate cue; hull wires still render in their own ink.
      self.line(
        Int(line.x0.rounded()), Int(line.y0.rounded()), Int(line.x1.rounded()),
        Int(line.y1.rounded()), line.ink, clipTop: Int(flightClip.y),
        clipBottom: Int(flightClip.maxY - 1))
    }
  }
}

extension Display {
  /// Twelve clipped halo segments, with a shared prepared scene and real mesh/sphere occlusion.
  static func targetWorldGlow(
    _ body: SpaceBody, game: Game, projection: FlightProjection,
    scene: GameplayRaycast.OcclusionScene, context: EncounterContext?, into frame: inout Frame
  ) {
    guard projection.focal.isFinite, projection.focal > 0,
      projection.center.x.isFinite, projection.center.y.isFinite,
      let ink = game.targetColourCue(for: body, context: context).ink
    else { return }
    let center = game.viewPosition(body.position)
    guard center.z > 1, frame.flightClip.contains(projection.point(center)) else { return }
    let mesh = game.gameplayMesh(for: body)
    let vertices = mesh.vertices.map {
      game.viewPosition(body.modelVector($0) + body.position)
    }
    guard !vertices.isEmpty, vertices.allSatisfy({ $0.finite && $0.z > 1 }) else { return }
    func visibleHit(toward point: Vector3) -> GameplayHit? {
      guard point.finite,
        let hit = GameplayRaycast.nearest(
          origin: .init(0, 0, 0), direction: point,
          maxDistance: point.length + 1, scene: scene), hit.target == .body(body.id)
      else { return nil }
      return hit
    }
    var visible = visibleHit(toward: body.position)
    if visible == nil {
      // Hollow/asymmetric meshes need not contain their body origin. Sample actual face surfaces,
      // keeping the same nearest real mesh/celestial hit proof and a fixed per-object ray budget.
      let samples = min(32, mesh.faces.count)
      for sample in 0..<samples {
        let face = mesh.faces[sample * mesh.faces.count / samples]
        guard face.count >= 3, face.allSatisfy(mesh.vertices.indices.contains) else { continue }
        let local =
          face.reduce(Vector3(0, 0, 0)) { $0 + mesh.vertices[$1] }
          * (1 / Double(face.count))
        if let hit = visibleHit(toward: body.modelVector(local) + body.position) {
          visible = hit
          break
        }
      }
    }
    guard let hit = visible else { return }
    let points = vertices.map(projection.point)
    let minX = points.map(\.x).min()!
    let maxX = points.map(\.x).max()!
    let minY = points.map(\.y).min()!
    let maxY = points.map(\.y).max()!
    let midpoint = ScreenPoint((minX + maxX) / 2, (minY + maxY) / 2)
    let rx = max(4, (maxX - minX) / 2 + 3)
    let ry = max(4, (maxY - minY) / 2 + 3)
    let depth = max(1, game.viewPosition(hit.point).z)
    func shipDirection(_ point: ScreenPoint) -> Vector3 {
      let view = Vector3(
        (point.x - projection.center.x) / projection.focal,
        -(point.y - projection.center.y) / projection.focal, 1)
      switch game.screen {
      case .rear: return .init(-view.x, view.y, -view.z)
      case .left: return .init(-view.z, view.y, view.x)
      case .right: return .init(view.z, view.y, -view.x)
      default: return view
      }
    }
    func clear(_ point: ScreenPoint) -> Bool {
      guard frame.flightClip.contains(point) else { return false }
      let ray = shipDirection(point)
      // Ignore only this source. A closer physical hull or celestial clips its cue in every style.
      return GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: ray,
        maxDistance: depth * ray.length, scene: scene, ignoring: [body.id]) == nil
    }
    func segmentClear(_ p: ScreenPoint, _ q: ScreenPoint) -> Bool {
      // Whole-segment envelopes cover thin occluders between ray samples and the finite halo width.
      // This can hide a little extra glow around a foreground mesh, but never reveals it through one.
      let padding = 8.0
      let x = min(p.x, q.x) - padding
      let y = min(p.y, q.y) - padding
      let right = max(p.x, q.x) + padding
      let bottom = max(p.y, q.y) + padding
      guard x >= frame.flightClip.x, y >= frame.flightClip.y,
        right < frame.flightClip.maxX, bottom < frame.flightClip.maxY
      else { return false }
      return !scene.glowOccluders.contains { occluder in
        guard occluder.bodyID != body.id, occluder.nearDepth < depth else { return false }
        guard let bounds = occluder.bounds else { return true }
        return x <= bounds.maxX && right >= bounds.x && y <= bounds.maxY && bottom >= bounds.y
      }
    }
    for i in 0..<12 {
      let a = Double(i) * 2 * .pi / 12
      let b = Double(i + 1) * 2 * .pi / 12
      let p = ScreenPoint(midpoint.x + cos(a) * rx, midpoint.y + sin(a) * ry)
      let q = ScreenPoint(midpoint.x + cos(b) * rx, midpoint.y + sin(b) * ry)
      let middle = ScreenPoint((p.x + q.x) / 2, (p.y + q.y) / 2)
      guard segmentClear(p, q), clear(p), clear(middle), clear(q) else { continue }
      frame.worldGlow(.init(x0: p.x, y0: p.y, x1: q.x, y1: q.y, ink: ink))
    }
  }
}
