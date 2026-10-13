import Foundation

extension Display {
  /// Original Cobra Mk III hull proportions, rendered through the flight renderer.
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
    draw(ship, game: game, into: &frame, projection: projection, mesh: cobraIconHull)
    game.commander.shipDisplayStyle = .colourWireframe
    draw(ship, game: game, into: &frame, projection: projection, mesh: cobraIconHull)
    return frame
  }

  // Hull coordinates from the 6502 Second Processor Cobra Mk III blueprint;
  // reverse Z to face our camera. Only the twelve structural vertices are needed.
  // https://elite.bbcelite.com/6502sp/main/variable/ship_cobra_mk_3.html
  private static let cobraIconHull = Mesh(
    vertices: [
      .init(32, 0, -76), .init(-32, 0, -76), .init(0, 26, -24),
      .init(-120, -3, 8), .init(120, -3, 8), .init(-88, 16, 40),
      .init(88, 16, 40), .init(128, -8, 40), .init(-128, -8, 40),
      .init(0, 26, 40), .init(-32, -24, 40), .init(32, -24, 40),
    ],
    faces: [
      [0, 1, 2], [1, 2, 5], [0, 2, 6], [1, 3, 5], [0, 4, 6],
      [2, 5, 9], [2, 6, 9], [3, 5, 8], [4, 6, 7],
      [6, 7, 11, 10, 8, 5, 9], [1, 3, 8, 10], [0, 1, 10, 11], [0, 4, 7, 11],
    ])
}
