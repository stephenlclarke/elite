import Foundation

public struct CockpitLayout: Sendable {
  public let width: Double
  public let height: Double
  public let font: Double
  public let instrumentScale: Double
  public let row: Double
  public let dashboardTop: Double
  public let instrumentsTop: Double
  public let radarWidth: Double
  public let sideWidth: Double
  public let leftColumns: Int
  public let extraLines: [String]
  public var flightClip: CanvasRect {
    .init(x: 0, y: 24, width: width, height: max(40, dashboardTop - 52))
  }
  public var projection: FlightProjection {
    .init(
      center: .init(width / 2, flightClip.y + flightClip.height / 2),
      focal: flightClip.height * 256 / 164)
  }
  public init(game: Game, width: Double, height: Double) {
    self.width = max(320, width)
    self.height = max(320, height)
    font = GameTypography.scale
    if width < 640 { instrumentScale = 1.25 } else { instrumentScale = width < 1100 ? 1.5 : 2 }
    // Instrument geometry keeps its existing proportions independently of text size.
    row = ceil(instrumentScale * 7) + 6
    radarWidth = min(560, max(104, width * 0.30))
    sideWidth = (width - radarWidth - 48) / 2
    leftColumns = sideWidth >= 400 ? 2 : 1
    let textColumns = max(20, Int((width - 24) / (6 * instrumentScale)))
    let weaponLines = game.retaliation.status.isEmpty ? [] : ["WEAPONS: " + game.retaliation.status]
    let toolLines = ["TOOL: " + game.selectedFlightTool.label.uppercased() + " / W CHANGE"]
    extraLines =
      (game.autoHUDLines + toolLines + game.salvageHUDLines + game.solarHUDLines + weaponLines
      + game.spin.hudLines)
      .flatMap {
        MissionNotice.wrap($0, width: textColumns)
      }
    let rows = max(4, Int(ceil(6 / Double(leftColumns))))
    let scannerHeight = width < 900 ? 80.0 : 108.0
    let panelHeight =
      16 + row * Double(1 + extraLines.count) + max(row * Double(rows), scannerHeight)
    dashboardTop = max(120, self.height - panelHeight)
    instrumentsTop = dashboardTop + 8 + row * Double(1 + extraLines.count)
  }
}

extension Frame {
  public mutating func label(
    _ text: String, _ x: Double, _ y: Double, scale: Double, ink: Ink = .white
  ) {
    labels.append(BitmapLabel(text: text, x: x, y: y, scale: scale, ink: ink))
  }
  mutating func stroke(_ x: Double, _ y: Double, _ xx: Double, _ yy: Double, _ ink: Ink) {
    graphics.append(.line(.init(x0: x, y0: y, x1: xx, y1: yy, ink: ink)))
  }
}

extension Game {
  public var flightStatus: String {
    if docked { return "Docked" }
    if energy <= 0 { return "Destroyed" }
    return bodies.contains(where: \.hostile) ? "Hostile" : "Safe"
  }
  public var missileIconCount: Int { commander.unlimitedMissiles ? 1 : commander.missiles }
}

extension Display {
  public static func cockpit(_ game: Game, width: Double, height: Double) -> Frame {
    let layout = CockpitLayout(game: game, width: width, height: height)
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: layout.width, height: layout.height)
    frame.flightClip = layout.flightClip
    if game.screen.isFlight {
      spaceScene(game, projection: layout.projection, into: &frame)
      frame.worldGraphics = frame.graphics
      frame.graphics = []
      frame.label(game.screen.rawValue + " view", 12, 8, scale: layout.font)
      targetMarker(game, layout: layout, into: &frame)
      targetPanel(game, layout: layout, into: &frame)
      if game.messageTime > 0 {
        let x = max(12, (layout.width - Double(game.message.count) * 6 * layout.font) / 2)
        frame.label(
          game.message, x, layout.dashboardTop - layout.row, scale: layout.font, ink: .yellow)
      }
      if game.paused {
        frame.label("PAUSED - COMMAND-P TO RESUME", 12, 32, scale: layout.font, ink: .yellow)
      }
      if let countdown = game.jumpCountdown {
        frame.label("Hyperspace: \(Int(ceil(countdown)))", 12, 52, scale: layout.font, ink: .cyan)
      }
      if game.dockingComputer {
        frame.label("Docking computer engaged", 12, 72, scale: layout.font, ink: .cyan)
      }
      stationDirection(game, layout: layout, into: &frame)
    }
    cockpitHeader(game, layout: layout, into: &frame)
    for (index, line) in layout.extraLines.enumerated() {
      frame.label(
        line, 12, layout.dashboardTop + 8 + layout.row * Double(index + 1), scale: layout.font,
        ink: .cyan)
    }
    cockpitInstruments(game, layout: layout, into: &frame)
    return frame
  }

  private static func targetMarker(_ game: Game, layout: CockpitLayout, into frame: inout Frame) {
    guard let target = game.informationTargetBody else { return }
    let position = game.viewPosition(target.position)
    let point = layout.projection.point(.init(position.x, position.y, max(1, abs(position.z))))
    let visible = position.z > 1 && layout.flightClip.contains(point)
    let x = max(16, min(layout.width - 16, point.x))
    let y = max(layout.flightClip.y + 12, min(layout.flightClip.maxY - 12, point.y))
    for sign in [-1.0, 1.0] {
      frame.stroke(x + sign * 10, y - 8, x + sign * 10, y + 8, .cyan)
      frame.stroke(x + sign * 10, y - 8, x + sign * 5, y - 8, .cyan)
      frame.stroke(x + sign * 10, y + 8, x + sign * 5, y + 8, .cyan)
    }
    if !visible {
      frame.label(
        "AUTO TARGET OFFSCREEN", 12, layout.flightClip.maxY - layout.row, scale: layout.font,
        ink: .cyan)
    }
  }

  private static func cockpitHeader(_ game: Game, layout: CockpitLayout, into frame: inout Frame) {
    frame.stroke(0, layout.dashboardTop, layout.width, layout.dashboardTop, .yellow)
    let y = layout.dashboardTop + 8
    frame.label(
      "Status: " + game.flightStatus, 12, y, scale: layout.font,
      ink: game.flightStatus == "Hostile" ? .red : .green)
    let x = floor(layout.width * 0.38)
    frame.label("Missiles", x, y, scale: layout.font, ink: .yellow)
    var next = x + 8 * 6 * layout.font + 8
    if game.missileIconCount == 0 {
      frame.label("None", next, y, scale: layout.font)
      next += 4 * 6 * layout.font
    } else {
      for _ in 0..<game.missileIconCount {
        missileIcon(
          x: next, y: y, scale: layout.instrumentScale / 1.5, armed: game.missileArmed, into: &frame
        )
        next += 14 * layout.instrumentScale / 1.5
      }
    }
    if game.commander.unlimitedMissiles {
      frame.label("~", next, y, scale: layout.font, ink: .green)
      next += 6 * layout.font
    }
    frame.label(
      game.missileArmed ? "Armed" : "Unarmed", next + 8, y, scale: layout.font,
      ink: game.missileArmed ? .red : .white)
    frame.label(
      "K: Help", layout.width - 12 - 7 * 6 * layout.font, y, scale: layout.font, ink: .cyan)
  }

  private static func missileIcon(
    x: Double, y: Double, scale: Double, armed: Bool, into frame: inout Frame
  ) {
    let points: [ScreenPoint] = [
      .init(5, 0), .init(2, 4), .init(2, 9), .init(0, 12), .init(5, 10),
      .init(10, 12), .init(8, 9), .init(8, 4), .init(5, 0),
    ]
    for pair in zip(points, points.dropFirst()) {
      frame.stroke(
        x + pair.0.x * scale, y + pair.0.y * scale, x + pair.1.x * scale, y + pair.1.y * scale,
        armed ? .red : .green)
    }
  }

  private static func cockpitInstruments(
    _ game: Game, layout: CockpitLayout, into frame: inout Frame
  ) {
    let gauges: [(String, Double, Ink)] = [
      ("Front shield", game.frontShield / game.commander.shieldCapacity, .green),
      ("Rear shield", game.rearShield / game.commander.rearShieldCapacity, .green),
      ("Fuel", Double(game.commander.fuel) / Double(game.commander.fuelCapacity), .green),
      ("Cabin temp", game.cabinTemperature, .red), ("Laser heat", game.laserHeat / 255, .red),
      ("Altitude", game.altitude, .yellow),
    ]
    let columnWidth =
      (layout.sideWidth - Double(layout.leftColumns - 1) * 12) / Double(layout.leftColumns)
    let rows = Int(ceil(6 / Double(layout.leftColumns)))
    for (index, gauge) in gauges.enumerated() {
      let x = 12 + Double(index / rows) * (columnWidth + 12)
      let y = layout.instrumentsTop + Double(index % rows) * layout.row
      cockpitGauge(
        gauge.0, value: gauge.1, bounds: .init(x: x, y: y, width: columnWidth, height: layout.row),
        layout: layout,
        ink: gauge.2,
        into: &frame)
    }
    let instrumentWidth = min(layout.sideWidth, 13 * 6 * layout.instrumentScale + 160)
    let x = layout.width - 12 - instrumentWidth
    for (index, gauge) in [
      (
        "Speed",
        game.cockpitSpeed
          / game.commander.performance.speed
      ), ("Roll", game.roll), ("Pitch", game.pitch),
    ]
    .enumerated() {
      cockpitGauge(
        gauge.0, value: gauge.1,
        bounds: .init(
          x: x, y: layout.instrumentsTop + Double(index) * layout.row, width: instrumentWidth,
          height: layout.row),
        layout: layout, ink: .green, signed: index > 0, into: &frame)
    }
    let y = layout.instrumentsTop + 3 * layout.row
    frame.label("Energy", x, y, scale: layout.font, ink: .yellow)
    let barX = x + min(instrumentWidth * 0.75, 13 * 6 * layout.instrumentScale)
    let barEnd = min(x + instrumentWidth, barX + 160)
    for bank in 0..<4 {
      let length =
        (barEnd - barX)
        * max(
          0,
          min(
            1,
            (game.energy - Double(bank) * game.commander.performance.energy / 4)
              / (game.commander.performance.energy / 4)))
      let by = y + Double(bank) * 3
      frame.stroke(barX, by, barEnd, by, .blue)
      if length > 0 { frame.stroke(barX, by, barX + length, by, .yellow) }
    }
    cockpitScanner(game, layout: layout, into: &frame)
  }

  private static func cockpitGauge(
    _ name: String, value: Double, bounds: CanvasRect,
    layout: CockpitLayout, ink: Ink, signed: Bool = false, into frame: inout Frame
  ) {
    let x = bounds.x
    let y = bounds.y
    let width = bounds.width
    let label = signed && abs(value) < 0.02 ? name + " neutral" : name
    frame.label(label, x, y, scale: layout.font, ink: .yellow)
    let barX = x + min(width * 0.75, 13 * 6 * layout.instrumentScale)
    let barWidth = min(160, width - (barX - x))
    let by = y + 5
    frame.stroke(barX, by, barX + barWidth, by, .blue)
    let start = signed ? barX + barWidth / 2 : barX
    let end =
      signed
      ? start + barWidth / 2 * max(-1, min(1, value)) : barX + barWidth * max(0, min(1, value))
    if start != end {
      for offset in -1...1 {
        frame.stroke(start, by + Double(offset), end, by + Double(offset), ink)
      }
    }
    if signed { frame.stroke(start, by - 4, start, by + 4, .yellow) }
  }

  private static func cockpitScanner(_ game: Game, layout: CockpitLayout, into frame: inout Frame) {
    let cx = layout.width / 2
    let rx = (layout.radarWidth - 12) / 2
    let ry = layout.width < 900 ? 32.0 : 46.0
    let cy = layout.instrumentsTop + 16 + ry
    frame.label(
      "Scanner", cx - 21 * layout.font, layout.instrumentsTop, scale: layout.font, ink: .yellow)
    frame.ellipse(cx, cy, rx, ry, .green)
    frame.stroke(cx - rx, cy, cx + rx, cy, .green)
    frame.stroke(cx, cy - ry, cx, cy + ry, .green)
    for body in game.bodies {
      let sx = cx + max(-rx + 2, min(rx - 2, body.position.x / 4400 * rx))
      let sy = cy + max(-ry + 2, min(ry - 2, -body.position.z / 8500 * ry))
      let lift = max(-ry / 2, min(ry / 2, body.position.y / 3000 * ry))
      let ink: Ink = body.hostile ? .red : .green
      frame.stroke(sx, sy, sx, sy - lift, ink)
      frame.stroke(sx - 2, sy - lift, sx + 2, sy - lift, ink)
    }
  }
}
