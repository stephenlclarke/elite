import Foundation

struct TargetPanelLayout {
  let width: Double
  let x: Double
  let y = 32.0
  let row = ceil(GameTypography.scale * 7) + 5
  let previewHeight: Double
  let headings: [String]
  let statuses: [String]
  let fields: [String]
  let fieldY: Double
  let bottom: Double
  let window: ScrollWindow

  init(game: Game, info: TargetInformation, cockpit: CockpitLayout) {
    width = min(280, cockpit.width * 0.4)
    x = cockpit.width - width - 12
    previewHeight = cockpit.width >= 1100 ? 110 : 72
    let columns = max(1, Int((width - 8) / (6 * GameTypography.scale)))
    headings = ShowroomText.wrap(info.identifier, width: columns)
    let expanded = game.targetPanelExpanded ?? (cockpit.width >= 1100)
    var wanted = ""
    if let body = game.informationTargetBody, let notice = game.wantedNotice(for: body) {
      wanted = notice + " / "
    }
    var statusText = wanted + (info.status ?? "Unknown") + "  I: " + (expanded ? "Hide" : "Detail")
    let observations: [String?] = [
      game.orbitalOutlookScanStatus, game.originalSurveyScanStatus, game.glassMeridianScanStatus,
    ]
    for observation in observations.compactMap({ $0 }) { statusText += " / " + observation }
    statuses = ShowroomText.wrap(statusText, width: columns)
    fields = info.fields.flatMap { ShowroomText.wrap($0.text, width: columns) }

    fieldY = y + row * Double(headings.count + statuses.count) + previewHeight + 8
    bottom = min(fieldY + row * Double(fields.count) + 8, cockpit.flightClip.maxY)
    let capacity = max(1, Int((bottom - fieldY - 4) / row))
    let visible = fields.count > capacity ? max(1, capacity - 1) : capacity
    window = .init(count: fields.count, visible: visible, offset: game.targetPanelScroll)
  }
}

extension Game {
  var targetDetailsWindow: ScrollWindow? {
    guard let info = targetInformation,
      commander.targetingTier.map({ $0 >= .identification }) == true,
      targetPanelExpanded ?? (viewportWidth >= 1100)
    else { return nil }
    let cockpit = CockpitLayout(game: self, width: viewportWidth, height: viewportHeight)
    let layout = TargetPanelLayout(game: self, info: info, cockpit: cockpit)
    return layout.window
  }

  mutating func pageTargetDetails(_ direction: Int) {
    guard let window = targetDetailsWindow else { return }
    targetPanelScroll = window.moved(direction * window.visible)
  }
}

extension Display {
  static func targetPanel(_ game: Game, layout: CockpitLayout, into frame: inout Frame) {
    guard let info = game.targetInformation else { return }
    let cueInk = game.informationTargetBody.flatMap { game.targetColourCue(for: $0).ink } ?? .cyan
    let font = GameTypography.scale
    let panel = TargetPanelLayout(game: game, info: info, cockpit: layout)
    let width = panel.width
    let x = panel.x
    let y = panel.y
    guard let tier = game.commander.targetingTier, tier >= .identification else {
      frame.label("LOCK: " + info.identifier, x, y, scale: font, ink: cueInk)
      var status = info.status
      if let body = game.informationTargetBody, let notice = game.wantedNotice(for: body) {
        status = notice + (status.map { " / " + $0 } ?? "")
      }
      if let outlook = game.orbitalOutlookScanStatus {
        status = (status.map { $0 + " / " } ?? "") + outlook
      }
      if let survey = game.originalSurveyScanStatus {
        status = (status.map { $0 + " / " } ?? "") + survey
      }
      if let meridian = game.glassMeridianScanStatus {
        status = (status.map { $0 + " / " } ?? "") + meridian
      }
      let observing =
        game.orbitalOutlookScanStatus != nil || game.originalSurveyScanStatus != nil
        || game.glassMeridianScanStatus != nil
      if let status {
        for (index, line) in ShowroomText.wrap(status, width: Int((width - 8) / (6 * font))).prefix(
          observing ? 8 : 3
        ).enumerated() {
          frame.label(line, x, y + panel.row * Double(index + 1), scale: font, ink: cueInk)
        }
      }
      return
    }
    let expanded = game.targetPanelExpanded ?? (layout.width >= 1100)
    let row = panel.row
    let previewHeight = panel.previewHeight
    let headingRows = Double(panel.headings.count)
    let titleRows = headingRows + Double(panel.statuses.count)
    let bottom =
      expanded ? panel.bottom : min(y + row * titleRows + 12, layout.flightClip.maxY)
    frame.graphics.append(
      .panel(
        .init(
          vertices: [
            .init(x - 8, y - 8), .init(x + width, y - 8), .init(x + width, bottom),
            .init(x - 8, bottom),
          ], colour: Ink.black.rawValue)))
    frame.stroke(x - 8, y - 8, x + width, y - 8, cueInk)
    for (index, line) in panel.headings.enumerated() {
      frame.label(line, x, y + Double(index) * row, scale: font, ink: cueInk)
    }
    for (index, line) in panel.statuses.enumerated() {
      frame.label(line, x, y + row * (headingRows + Double(index)), scale: font, ink: cueInk)
    }
    guard expanded, var body = game.informationTargetBody else { return }
    // The target camera copies its pose. It never changes the flight camera or simulation.
    body.position = .init(0, 0, 350)
    var camera = game
    camera.screen = .front
    let savedClip = frame.flightClip
    frame.flightClip = .init(
      x: x, y: y + row * titleRows + 4, width: width - 8, height: previewHeight)
    let projection = FlightProjection(
      center: .init(x + (width - 8) / 2, y + row * titleRows + 4 + previewHeight / 2),
      focal: previewHeight * 2)
    let previewMesh = body.physical?.catalogueShipID.flatMap { ShipCatalogue.ship($0)?.previewMesh }
    draw(body, game: camera, into: &frame, projection: projection, mesh: previewMesh)
    frame.flightClip = savedClip
    for (index, line) in panel.fields.dropFirst(panel.window.offset).prefix(panel.window.visible)
      .enumerated()
    {
      frame.label(line, x, panel.fieldY + Double(index) * row, scale: font, ink: .yellow)
    }
    if panel.window.last > 0 {
      let end = min(panel.fields.count, panel.window.offset + panel.window.visible)
      frame.label(
        "OPT-UP/DOWN: \(panel.window.offset + 1)-\(end)/\(panel.fields.count)", x, bottom - row,
        scale: font, ink: .cyan)
    }
  }
}
