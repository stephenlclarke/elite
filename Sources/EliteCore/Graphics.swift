/// Drawing commands retain logical coordinates until the display renders them.
public enum Graphic: Sendable, Equatable {
  case line(WireLine)
  case wire(WireLine)
  case ellipse(center: ScreenPoint, radiusX: Double, radiusY: Double, ink: Ink)
  case ring(center: ScreenPoint, radiusX: Double, radiusY: Double, ink: Ink, style: StrokePattern)
  case point(center: ScreenPoint, radius: Double, opacity: Double, ink: Ink)
  case panel(ShipPanel)
}

public struct CanvasRect: Sendable, Equatable {
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double
  public var maxX: Double { x + width }
  public var maxY: Double { y + height }
  public func contains(_ point: ScreenPoint) -> Bool {
    point.x >= x && point.x < maxX && point.y >= y && point.y < maxY
  }
}

public struct BitmapLabel: Sendable, Equatable {
  public let text: String
  public let x: Double
  public let y: Double
  public let scale: Double
  public let ink: Ink
  public var bounds: CanvasRect {
    CanvasRect(x: x, y: y, width: Double(text.count) * 6 * scale, height: 7 * scale)
  }
}

public struct FlightProjection: Sendable {
  public let center: ScreenPoint
  public let focal: Double
  public static let legacy = Self(center: .init(128, 96), focal: 256)
  public func point(_ point: Vector3) -> ScreenPoint {
    .init(center.x + point.x * focal / point.z, center.y - point.y * focal / point.z)
  }
}

extension Frame {
  public var shipLines: [WireLine] {
    (worldGraphics + graphics).compactMap { if case .wire(let line) = $0 { line } else { nil } }
  }

  public var shipPanels: [ShipPanel] {
    (worldGraphics + graphics).compactMap { if case .panel(let panel) = $0 { panel } else { nil } }
  }

  public mutating func point(
    _ x: Double, _ y: Double, radius: Double = 0.3, opacity: Double = 1, ink: Ink = .white
  ) {
    guard canvas.contains(ScreenPoint(x, y)) else { return }
    graphics.append(.point(center: ScreenPoint(x, y), radius: radius, opacity: opacity, ink: ink))
    if rasterizeGraphics { pixel(Int(x.rounded()), Int(y.rounded()), ink) }
  }
}
