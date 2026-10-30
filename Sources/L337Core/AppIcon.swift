import Foundation

extension Display {
  /// The approved Larvaal Sovereign and its authored jade palette, framed by the game renderer.
  public static func appIcon() -> Frame {
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.flightClip = frame.canvas
    frame.ellipse(128, 128, 98, 98, .gold)
    for point in [ScreenPoint(51, 60), .init(197, 73), .init(62, 190), .init(183, 198)] {
      frame.point(point.x, point.y, radius: 0.7, ink: .white)
    }
    var game = Game()
    game.screen = .front
    var ship = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 450))
    ship.orientation.rotate(pitch: -0.65, roll: -0.2, yaw: 0.25)
    let projection = FlightProjection(center: .init(128, 128), focal: 300)
    game.commander.shipDisplayStyle = .shadedPanels
    draw(ship, game: game, into: &frame, projection: projection, mesh: L337Branding.iconMesh)
    return frame
  }

}
