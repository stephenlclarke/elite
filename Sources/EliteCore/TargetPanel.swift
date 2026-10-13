import Foundation

extension Display {
  static func targetPanel(_ game: Game, layout: CockpitLayout, into frame: inout Frame) {
    guard let info = game.targetInformation else { return }
    let font = layout.width < 700 ? 1.0 : 1.25
    let width = min(280, layout.width * 0.4)
    let x = layout.width - width - 12
    let y = 32.0
    guard let tier = game.commander.targetingTier, tier >= .identification else {
      frame.label("LOCK: " + info.identifier, x, y, scale: font, ink: .cyan)
      return
    }
    let expanded = game.targetPanelExpanded ?? (layout.width >= 1100)
    let row = ceil(font * 7) + 5
    let previewHeight = layout.width >= 1100 ? 110.0 : 72.0
    let height = expanded ? 24 + previewHeight + row * Double(info.fields.count + 2) : row * 2 + 12
    let bottom = min(y + height, layout.flightClip.maxY)
    frame.graphics.append(
      .panel(
        .init(
          vertices: [
            .init(x - 8, y - 8), .init(x + width, y - 8), .init(x + width, bottom),
            .init(x - 8, bottom),
          ], colour: Ink.black.rawValue)))
    frame.stroke(x - 8, y - 8, x + width, y - 8, .cyan)
    frame.label(info.identifier, x, y, scale: font, ink: .cyan)
    frame.label(
      (info.status ?? "Unknown") + "  I: " + (expanded ? "Hide" : "Detail"), x, y + row, scale: font
    )
    guard expanded, var body = game.informationTargetBody else { return }
    // The target camera copies its pose. It never changes the flight camera or simulation.
    body.position = .init(0, 0, 350)
    var camera = game
    camera.screen = .front
    let savedClip = frame.flightClip
    frame.flightClip = .init(x: x, y: y + row * 2 + 4, width: width - 8, height: previewHeight)
    let projection = FlightProjection(
      center: .init(x + (width - 8) / 2, y + row * 2 + 4 + previewHeight / 2),
      focal: previewHeight * 2)
    draw(body, game: camera, into: &frame, projection: projection)
    frame.flightClip = savedClip
    let fieldY = y + row * 2 + previewHeight + 8
    for (index, field) in info.fields.enumerated() {
      let top = fieldY + Double(index) * row
      if top + 7 * font <= bottom { frame.label(field.text, x, top, scale: font, ink: .yellow) }
    }
  }
}
