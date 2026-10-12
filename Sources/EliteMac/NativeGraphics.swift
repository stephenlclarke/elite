import AppKit
import EliteCore

/// The window and exported media share the same drawing path at any pixel size.
@MainActor
func drawFrame(_ frame: Frame, context: CGContext, rect: CGRect) {
  guard let bitmap = bitmapFor(frame) else { return }
  context.saveGState()
  context.translateBy(x: rect.minX, y: rect.minY)
  context.scaleBy(x: rect.width / 256, y: rect.height / 256)
  context.clip(to: CGRect(x: 0, y: 0, width: 256, height: 256))
  context.setShouldAntialias(true)
  context.setAllowsAntialiasing(true)
  context.setLineJoin(.round)
  context.setLineCap(.round)
  if !frame.rasterizeGraphics {
    for graphic in frame.graphics { drawGraphic(graphic, context: context) }
  }
  // Preserve the original bitmap font above the smooth geometry.
  context.interpolationQuality = .none
  context.translateBy(x: 0, y: 256)
  context.scaleBy(x: 1, y: -1)
  context.draw(bitmap, in: CGRect(x: 0, y: 0, width: 256, height: 256))
  context.restoreGState()
}

@MainActor
func imageFor(_ frame: Frame, pixelSize: Int = 256) -> CGImage? {
  if frame.rasterizeGraphics { return bitmapFor(frame) }
  guard pixelSize > 0, pixelSize <= 8192,
    let context = CGContext(
      data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8,
      bytesPerRow: pixelSize * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { return nil }
  let rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
  context.setFillColor(colour(Ink.black.rawValue))
  context.fill(rect)
  context.translateBy(x: 0, y: Double(pixelSize))
  context.scaleBy(x: 1, y: -1)
  drawFrame(frame, context: context, rect: rect)
  return context.makeImage()
}

private func bitmapFor(_ frame: Frame) -> CGImage? {
  let rgba = frame.pixels.map { pixel in
    !frame.rasterizeGraphics && pixel == Ink.black.rawValue ? 0 : pixel.bigEndian
  }
  let data = rgba.withUnsafeBytes { Data($0) }
  guard let provider = CGDataProvider(data: data as CFData) else { return nil }
  return CGImage(
    width: 256, height: 256, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

private func drawGraphic(_ graphic: Graphic, context: CGContext) {
  context.setLineWidth(0.5)
  switch graphic {
  case .line(let line), .wire(let line):
    context.setStrokeColor(colour(line.ink.rawValue))
    context.beginPath()
    context.move(to: CGPoint(x: line.x0, y: line.y0))
    context.addLine(to: CGPoint(x: line.x1, y: line.y1))
    context.strokePath()
  case .ellipse(let center, let rx, let ry, let ink):
    context.setStrokeColor(colour(ink.rawValue))
    context.strokeEllipse(
      in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
  case .point(let center, let radius, let opacity, let ink):
    context.setFillColor(colour(ink.rawValue, opacity: opacity))
    context.fillEllipse(
      in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
  case .panel(let panel):
    guard let first = panel.vertices.first else { return }
    context.setFillColor(colour(panel.colour))
    context.setStrokeColor(colour(panel.colour))
    // A small overlap prevents antialiasing cracks between adjoining faces.
    context.setLineWidth(0.25)
    context.beginPath()
    context.move(to: CGPoint(x: first.x, y: first.y))
    for point in panel.vertices.dropFirst() { context.addLine(to: CGPoint(x: point.x, y: point.y)) }
    context.closePath()
    context.drawPath(using: .fillStroke)
  }
}

private func colour(_ rgba: UInt32, opacity: Double = 1) -> CGColor {
  CGColor(
    red: Double((rgba >> 24) & 255) / 255, green: Double((rgba >> 16) & 255) / 255,
    blue: Double((rgba >> 8) & 255) / 255, alpha: opacity)
}
