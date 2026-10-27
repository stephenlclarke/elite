import Foundation

extension Display {
  static func drawNativeWormholes(
    _ game: Game, into frame: inout Frame,
    projection: FlightProjection
  ) {
    for leg in (game.commander.scriptState.wormholeTransit?.legs ?? [:]).values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) {
      guard let hole = leg.opening, hole.valid,
        OriginalWorldJourneyContext.production(for: hole.route, in: game) != nil,
        hole.route.origin.location == game.systemIdentity,
        game.commander.scriptState.calendarSeconds >= hole.openedAt,
        game.commander.scriptState.calendarSeconds <= hole.expiresAt
      else { continue }
      var previous: Vector3?
      for index in 0...32 {
        let angle = Double(index) * 2 * Double.pi / 32
        let world =
          hole.entrance.position
          + hole.entrance.orientation.apply(
            .init(cos(angle) * hole.radius, sin(angle) * hole.radius, 0))
        let point = game.viewPosition(game.commander.flightSimulation.pose.shipPoint(world))
        if let previous, let line = project(previous, point, projection: projection) {
          frame.wire(line.0, line.1, line.2, line.3, .cyan)
        }
        previous = point
      }
    }
  }
}
