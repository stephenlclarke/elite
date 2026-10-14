import Foundation

extension Display {
  private enum FlightObject {
    case ship(SpaceBody)
    case celestial(CelestialBody)

    var position: Vector3 {
      switch self {
      case .ship(let body): body.position
      case .celestial(let body): body.position
      }
    }
  }

  /// A common painter order lets nearer planets occlude more distant ships.
  static func flightObjects(_ game: Game, projection: FlightProjection, into frame: inout Frame) {
    let objects = game.bodies.map(FlightObject.ship) + game.celestials.map(FlightObject.celestial)
    let visible = objects.compactMap { object -> (FlightObject, Double)? in
      let depth = game.viewPosition(object.position).z
      return depth.isFinite ? (object, depth) : nil
    }
    for (object, _) in visible.sorted(by: { $0.1 > $1.1 }) {
      switch object {
      case .ship(let body): draw(body, game: game, into: &frame, projection: projection)
      case .celestial(let body): celestial(body, game: game, projection: projection, into: &frame)
      }
    }
  }

  /// Celestials share the moving camera coordinates used by ships and stars.
  static func celestialScene(_ game: Game, projection: FlightProjection, into frame: inout Frame) {
    for body in game.celestials.sorted(by: {
      game.viewPosition($0.position).z > game.viewPosition($1.position).z
    }) {
      celestial(body, game: game, projection: projection, into: &frame)
    }
  }

  private static func celestial(
    _ body: CelestialBody, game: Game, projection: FlightProjection, into frame: inout Frame
  ) {
    guard projection.focal.isFinite, projection.focal > 0,
      projection.center.x.isFinite, projection.center.y.isFinite
    else { return }
    let clip = frame.flightClip
    guard clip.width.isFinite, clip.height.isFinite, clip.width > 0, clip.height > 0 else { return }
    let position = game.viewPosition(body.position)
    let distance = position.length
    guard position.x.isFinite, position.y.isFinite, position.z.isFinite,
      distance.isFinite, body.radius.isFinite, body.radius > 0
    else { return }
    let center: ScreenPoint
    let radius: Double
    if distance <= body.radius {
      // Collision/heat handles the interior in simulation. Cover the viewport
      // without projecting through zero depth or allocating an enormous image.
      center = .init(clip.x + clip.width / 2, clip.y + clip.height / 2)
      radius = hypot(clip.width, clip.height)
    } else {
      guard position.z > 0 else { return }
      // Keep near-plane crossings bounded; normal approach remains perspective.
      let depth = max(position.z, body.radius * 0.05, 1)
      let projectedRadius = projection.focal * (body.radius / depth)
      radius = min(projectedRadius, 4 * max(clip.width, clip.height))
      // Bound the whole projected disk together. Clamping only its radius
      // would incorrectly discard a nearby sphere whose limb crosses the view.
      center = .init(
        projection.center.x + (position.x / body.radius) * radius,
        projection.center.y - (position.y / body.radius) * radius)
    }
    guard center.x.isFinite, center.y.isFinite, radius.isFinite, radius > 0 else { return }
    let visibleRadius = body.kind == .sun ? radius * 1.15 : radius
    let nearestX = min(max(center.x, clip.x), clip.maxX)
    let nearestY = min(max(center.y, clip.y), clip.maxY)
    guard hypot(center.x - nearestX, center.y - nearestY) <= visibleRadius else { return }
    switch body.kind {
    case .planet:
      frame.graphics.append(
        .planet(
          .init(
            galaxy: game.commander.galaxy, system: game.currentSystem,
            bounds: .init(
              x: center.x - radius, y: center.y - radius,
              width: radius * 2, height: radius * 2),
            time: game.time.isFinite ? game.time : 0)))
    case .sun:
      // Filled points intentionally bypass Frame.point's center-only culling:
      // a large sun remains visible when its limb crosses the viewport edge.
      frame.graphics.append(
        .point(center: center, radius: radius * 1.15, opacity: 0.15, ink: .orange))
      frame.graphics.append(.point(center: center, radius: radius * 1.06, opacity: 0.3, ink: .gold))
      frame.graphics.append(.point(center: center, radius: radius, opacity: 1, ink: .gold))
      frame.graphics.append(.point(center: center, radius: radius * 0.86, opacity: 1, ink: .yellow))
    }
  }
}
