import Foundation

extension Display {
  /// Export-only design presentation; creates no ownership, discovery or flight evidence.
  public static func originalDesignPresentation(
    _ game: Game, shipID: String, time: Double, width: Double, height: Double
  ) throws -> Frame {
    guard let ship = ShipCatalogue.ship(shipID), let definition = ship.originalDefinition else {
      throw OriginalFleetShowroomModels.Failure.unknownID
    }
    let model = try OriginalFleetShowroomModels.model(for: shipID)
    guard model.id == definition.id else {
      throw OriginalFleetShowroomModels.Failure.invalidAsset
    }
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    frame.flightClip = .init(x: 16, y: 84, width: width - 32, height: height - 204)
    centeredLabel("ORIGINAL SHIP DESIGN", y: 18, into: &frame)
    centeredLabel(shipID + " - " + definition.name, y: 52, into: &frame)
    centeredLabel("DESIGN PRESENTATION", y: height - 58, into: &frame)
    var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 400))
    body.orientation.rotate(pitch: 0.35, roll: time * 0.12, yaw: time * 0.7)
    let projection = FlightProjection(
      center: .init(width / 2, height * 0.47), focal: min(width, height) * 1.15)
    draw(
      body, game: game, into: &frame, projection: projection,
      mesh: model.displayMesh.showroomNormalised, screen: .title)
    return frame
  }

  static func startupScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let scale = min(width / 256, height / 256)
    // Preserve the rotating ships' geometry; only text leaves the legacy transform.
    frame.flightClip = .init(x: 0, y: 12 * scale, width: width, height: 164 * scale)
    let projection = FlightProjection(center: .init(width / 2, 96 * scale), focal: 256 * scale)
    if game.screen == .title {
      var ship = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 280))
      ship.rotation = game.time * 0.6
      draw(ship, game: game, into: &frame, projection: projection, mesh: L337Branding.titleMesh)
      centeredLabel(NewCommanderDefaults.title, y: 18, into: &frame)
      for (index, text) in [
        "SPACE TRADING, EXPLORATION AND DISCOVERY", "PRESS SPACE COMMANDER",
        BuildIdentity.current.versionLine, BuildIdentity.repository,
        BuildIdentity.current.revisionLine,
      ].enumerated() {
        centeredLabel(text, y: height - 120 + Double(index) * GameTypography.row, into: &frame)
      }
    } else {
      var ship = SpaceBody(id: 0, hull: .thargoid, position: .init(0, 0, 280))
      ship.rotation = game.time * 0.7
      draw(ship, game: game, into: &frame, projection: projection, mesh: L337Branding.titleMesh)
      let lines = [
        "XYZZY PRESENTS", NewCommanderDefaults.title,
        "WELCOME COMMANDER " + game.commander.name, "THE GALAXY AWAITS",
        "FLY. TRADE. SURVIVE.", BuildIdentity.current.versionLine,
        BuildIdentity.repository, BuildIdentity.current.revisionLine,
      ]
      let speed = (height + Double(lines.count) * GameTypography.row) / 11
      for (index, text) in lines.enumerated() {
        let y = height + Double(index) * GameTypography.row - game.time * speed
        if y >= 0 && y + 7 * GameTypography.scale < height {
          centeredLabel(text, y: y, into: &frame)
        }
      }
    }
    if game.paused { centeredLabel("PAUSED - COMMAND-P TO RESUME", y: height - 24, into: &frame) }
    return frame
  }
  private static func centeredLabel(_ text: String, y: Double, into frame: inout Frame) {
    frame.label(
      text, (frame.canvas.width - Double(text.count) * 6 * GameTypography.scale) / 2,
      y, scale: GameTypography.scale)
  }
}
