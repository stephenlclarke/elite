import Foundation

extension Display {
  /// Catalogue GIFs and overview sheets use the same projection, winding and shading as the app.
  public static func shipPortrait(_ ship: CatalogueShip, angle: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: 256, height: 256)
    frame.flightClip = .init(x: 8, y: 30, width: 240, height: 202)
    var game = Game(executive: false)
    game.screen = .front
    game.commander.shipDisplayStyle = .shadedPanels
    var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 400))
    body.orientation.rotate(pitch: 0.3, roll: 0.15, yaw: angle)
    draw(
      body, game: game, into: &frame, projection: .init(center: .init(128, 134), focal: 340),
      mesh: ship.previewMesh)
    frame.label(ship.id, 10, 10, scale: 1, ink: .yellow)
    frame.label(ship.name, 10, 242, scale: min(1, 236 / Double(ship.name.count * 6)), ink: .cyan)
    return frame
  }
}
