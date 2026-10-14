import Foundation

/// Station navigation is independent of combat targeting equipment and its range.
public struct StationNavigation: Sendable, Equatable {
  public let stationID: Int
  public let distance: Double
  public let viewPosition: Vector3
  public var bearingDegrees: Double { atan2(viewPosition.x, viewPosition.z) * 180 / .pi }
  public var elevationDegrees: Double {
    atan2(viewPosition.y, hypot(viewPosition.x, viewPosition.z)) * 180 / .pi
  }
  public var behind: Bool { viewPosition.z < 0 }

  var distanceText: String {
    let range: String
    if distance >= 1_000_000_000 {
      range = String(format: "%.1e units", distance)
    } else if distance >= 1_000_000 {
      range = String(format: "%.1fM units", distance / 1_000_000)
    } else if distance >= 1000 {
      range = String(format: "%.1fk units", distance / 1000)
    } else {
      range = String(format: "%.0f units", distance)
    }
    return "STATION " + range
  }

  var elevationText: String {
    let degrees = Int(abs(elevationDegrees).rounded())
    if degrees == 0 { return "LEVEL 0 DEG" }
    return "\(elevationDegrees > 0 ? "UP" : "DOWN") \(degrees) DEG"
  }

  func bearingText(layout: CockpitLayout) -> String {
    let degrees = Int(abs(bearingDegrees).rounded())
    let turn = bearingDegrees >= 0 ? "RIGHT" : "LEFT"
    if behind { return "BEHIND \(turn) \(degrees) DEG" }
    let visible =
      viewPosition.z > 1 && layout.flightClip.contains(layout.projection.point(viewPosition))
    if degrees == 0 { return visible ? "AHEAD 0 DEG" : "OFFSCREEN AHEAD" }
    return (visible ? "" : "OFFSCREEN ") + "\(turn) \(degrees) DEG"
  }

  var arrowDirection: ScreenPoint {
    let length = hypot(viewPosition.x, viewPosition.y)
    if length > 1e-9 { return .init(viewPosition.x / length, -viewPosition.y / length) }
    // Directly astern has two equally short turns. Explicit RIGHT 180 gives one
    // consistent instruction, without projecting a behind-camera point forward.
    return behind ? .init(1, 0) : .init(0, 0)
  }
}

extension Game {
  public var stationNavigation: StationNavigation? {
    guard !docked, screen.isFlight else { return nil }
    let stations = bodies.filter {
      $0.hull == .station && $0.energy > 0
        && $0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite
        && $0.position.length.isFinite
    }
    let selected = stations.first { $0.id == autoPilot.targetID }
    let main = stations.first { $0.id == 0 }
    let nearest = stations.min {
      $0.position.length == $1.position.length
        ? $0.id < $1.id : $0.position.length < $1.position.length
    }
    guard let station = selected ?? main ?? nearest else { return nil }
    return .init(
      stationID: station.id, distance: station.position.length,
      viewPosition: viewPosition(station.position))
  }
}

extension Display {
  static func stationDirection(_ game: Game, layout: CockpitLayout, into frame: inout Frame) {
    guard let navigation = game.stationNavigation else { return }
    let lines = [
      navigation.distanceText, navigation.bearingText(layout: layout), navigation.elevationText,
    ]
    let row = ceil(layout.font * 7) + 5
    let width = Double(lines.map(\.count).max() ?? 0) * 6 * layout.font + 44
    let height = row * 3 + 8
    if let bounds = stationCueBounds(width: width, height: height, layout: layout, frame: frame) {
      frame.graphics.append(
        .panel(
          .init(
            vertices: [
              .init(bounds.x, bounds.y), .init(bounds.maxX, bounds.y),
              .init(bounds.maxX, bounds.maxY), .init(bounds.x, bounds.maxY),
            ], colour: Ink.black.rawValue)))
      stationCompass(navigation, x: bounds.x + 17, y: bounds.y + height / 2, into: &frame)
      for (index, line) in lines.enumerated() {
        frame.label(
          line, bounds.x + 34, bounds.y + 4 + Double(index) * row,
          scale: layout.font, ink: .yellow)
      }
    } else {
      // Extremely crowded flight overlays still retain a compact header cue.
      let yaw = Int(abs(navigation.bearingDegrees).rounded())
      let pitch = Int(abs(navigation.elevationDegrees).rounded())
      let line =
        navigation.distanceText + (navigation.behind ? " BEHIND" : "")
        + " \(navigation.bearingDegrees >= 0 ? "R" : "L")\(yaw)"
        + " \(navigation.elevationDegrees >= 0 ? "U" : "D")\(pitch)"
      frame.label(
        line, max(12, layout.width - 12 - Double(line.count) * 6 * layout.font), 8,
        scale: layout.font, ink: .yellow)
    }
  }

  private static func stationCueBounds(
    width: Double, height: Double, layout: CockpitLayout, frame: Frame
  ) -> CanvasRect? {
    let panels = frame.graphics.compactMap { graphic -> CanvasRect? in
      guard case .panel(let panel) = graphic, panel.colour == Ink.black.rawValue,
        let left = panel.vertices.map(\.x).min(), let right = panel.vertices.map(\.x).max(),
        let top = panel.vertices.map(\.y).min(), let bottom = panel.vertices.map(\.y).max()
      else { return nil }
      return .init(x: left, y: top, width: right - left, height: bottom - top)
    }
    let obstacles = frame.labels.map(\.bounds) + panels
    var y = layout.flightClip.y + 8
    while y + height <= layout.flightClip.maxY - 4 {
      for x in [layout.width - 12 - width, 12] where x >= 12 {
        let bounds = CanvasRect(x: x, y: y, width: width, height: height)
        if !obstacles.contains(where: { stationCueIntersects(bounds, $0, gap: 4) }) {
          return bounds
        }
      }
      y += 14
    }
    return nil
  }

  private static func stationCueIntersects(_ a: CanvasRect, _ b: CanvasRect, gap: Double) -> Bool {
    a.x < b.maxX + gap && a.maxX + gap > b.x && a.y < b.maxY + gap && a.maxY + gap > b.y
  }

  private static func stationCompass(
    _ navigation: StationNavigation, x: Double, y: Double, into frame: inout Frame
  ) {
    frame.ellipse(x, y, 11, 11, .yellow)
    let direction = navigation.arrowDirection
    guard direction.x != 0 || direction.y != 0 else {
      for (a, b) in [
        (ScreenPoint(x, y - 4), ScreenPoint(x + 4, y)),
        (ScreenPoint(x + 4, y), ScreenPoint(x, y + 4)),
        (ScreenPoint(x, y + 4), ScreenPoint(x - 4, y)),
        (ScreenPoint(x - 4, y), ScreenPoint(x, y - 4)),
      ] { frame.stroke(a.x, a.y, b.x, b.y, .yellow) }
      return
    }
    let tip = ScreenPoint(x + direction.x * 8, y + direction.y * 8)
    frame.stroke(x - direction.x * 6, y - direction.y * 6, tip.x, tip.y, .yellow)
    for side in [-1.0, 1.0] {
      frame.stroke(
        tip.x, tip.y,
        tip.x - direction.x * 5 - direction.y * side * 4,
        tip.y - direction.y * 5 + direction.x * side * 4, .yellow)
    }
  }
}
