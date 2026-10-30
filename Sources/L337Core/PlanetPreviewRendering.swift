import Foundation

extension Display {
  /// Data/chart previews use the selected scene style without changing map inks.
  static func planetPreview(
    _ preview: PlanetPreview, style: ShipDisplayStyle, into frame: inout Frame
  ) {
    guard style != .shadedPanels else {
      frame.graphics.append(.planet(preview))
      return
    }
    let bounds = preview.bounds
    guard bounds.width.isFinite, bounds.height.isFinite, bounds.x.isFinite, bounds.y.isFinite,
      bounds.width > 0, bounds.height > 0
    else { return }
    let radius = min(bounds.width, bounds.height) / 2
    let center = ScreenPoint(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
    let segments = min(512, max(32, Int(ceil(sqrt(radius) * 8))))
    let ink: Ink = style == .whiteWireframe ? .white : .blue
    var previous = ScreenPoint(center.x + radius, center.y)
    for index in 1...segments {
      let angle = Double(index) * 2 * .pi / Double(segments)
      let next = ScreenPoint(center.x + radius * cos(angle), center.y + radius * sin(angle))
      frame.stroke(previous.x, previous.y, next.x, next.y, ink)
      previous = next
    }
  }
}
