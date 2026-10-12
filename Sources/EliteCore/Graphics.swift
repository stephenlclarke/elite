/// Drawing commands retain logical coordinates until the display renders them.
public enum Graphic: Sendable, Equatable {
  case line(WireLine)
  case wire(WireLine)
  case ellipse(center: ScreenPoint, radiusX: Double, radiusY: Double, ink: Ink)
  case point(center: ScreenPoint, radius: Double, opacity: Double, ink: Ink)
  case panel(ShipPanel)
}

extension Frame {
  public var shipLines: [WireLine] {
    graphics.compactMap { if case .wire(let line) = $0 { line } else { nil } }
  }

  public var shipPanels: [ShipPanel] {
    graphics.compactMap { if case .panel(let panel) = $0 { panel } else { nil } }
  }

  public mutating func point(
    _ x: Double, _ y: Double, radius: Double = 0.3, opacity: Double = 1, ink: Ink = .white
  ) {
    guard x >= 0, x <= 255, y >= 0, y <= 255 else { return }
    graphics.append(.point(center: ScreenPoint(x, y), radius: radius, opacity: opacity, ink: ink))
    if rasterizeGraphics { pixel(Int(x.rounded()), Int(y.rounded()), ink) }
  }
}
