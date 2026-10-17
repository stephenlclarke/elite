import AppKit
import EliteCore

@MainActor
func drawGame(_ game: Game, context: CGContext, rect: CGRect) {
  drawFrame(
    Display.presentation(game, width: rect.width, height: rect.height),
    context: context, rect: rect)
}

@MainActor
func imageForGame(_ game: Game, width: Int, height: Int, scale: Int = 1) -> CGImage? {
  guard width >= 320, height >= 320, width <= 4096, height <= 4096, (1...2).contains(scale),
    let context = CGContext(
      data: nil, width: width * scale, height: height * scale, bitsPerComponent: 8,
      bytesPerRow: width * scale * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { return nil }
  context.setFillColor(colour(Ink.black.rawValue))
  context.fill(CGRect(x: 0, y: 0, width: width * scale, height: height * scale))
  context.translateBy(x: 0, y: Double(height * scale))
  context.scaleBy(x: Double(scale), y: Double(-scale))
  drawGame(game, context: context, rect: CGRect(x: 0, y: 0, width: width, height: height))
  return context.makeImage()
}

/// The window and exported media share the same drawing path at any pixel size.
@MainActor
func drawFrame(_ frame: Frame, context: CGContext, rect: CGRect) {
  context.saveGState()
  context.translateBy(x: rect.minX, y: rect.minY)
  context.scaleBy(x: rect.width / frame.canvas.width, y: rect.height / frame.canvas.height)
  context.clip(to: CGRect(x: 0, y: 0, width: frame.canvas.width, height: frame.canvas.height))
  context.setShouldAntialias(true)
  context.setAllowsAntialiasing(true)
  context.setLineJoin(.round)
  context.setLineCap(.round)
  if !frame.rasterizeGraphics {
    if frame.responsive {
      context.saveGState()
      let clip = frame.flightClip
      context.clip(to: CGRect(x: clip.x, y: clip.y, width: clip.width, height: clip.height))
      for graphic in frame.worldGraphics { drawGraphic(graphic, context: context, lineWidth: 0.85) }
      context.restoreGState()
    }
    for graphic in frame.graphics {
      drawGraphic(graphic, context: context, lineWidth: frame.responsive ? 0.85 : 0.5)
    }
  }
  if frame.responsive {
    context.setShouldAntialias(false)
    for label in frame.labels {
      context.setFillColor(colour(label.ink.rawValue))
      for (index, char) in label.text.uppercased().enumerated() {
        let rows = BitmapFont.rows(char)
        for row in 0..<7 {
          for column in 0..<5 where rows[row] & (1 << (4 - column)) != 0 {
            context.fill(
              CGRect(
                x: label.x + Double(index * 6 + column) * label.scale,
                y: label.y + Double(row) * label.scale, width: label.scale, height: label.scale))
          }
        }
      }
    }
  } else if let bitmap = bitmapFor(frame) {
    context.interpolationQuality = .none
    context.translateBy(x: 0, y: 256)
    context.scaleBy(x: 1, y: -1)
    context.draw(bitmap, in: CGRect(x: 0, y: 0, width: 256, height: 256))
  }
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

@MainActor
private func drawGraphic(_ graphic: Graphic, context: CGContext, lineWidth: Double = 0.5) {
  context.setLineWidth(lineWidth)
  switch graphic {
  case .textured(let triangle): drawShipTexture(triangle, context: context)
  case .planet(let preview): PlanetRenderer.draw(preview, context: context)
  case .line(let line), .wire(let line):
    context.setStrokeColor(colour(line.ink.rawValue))
    context.beginPath()
    context.move(to: CGPoint(x: line.x0, y: line.y0))
    context.addLine(to: CGPoint(x: line.x1, y: line.y1))
    context.strokePath()
  case .ring(let center, let rx, let ry, let ink, let style):
    context.setStrokeColor(colour(ink.rawValue))
    let dash: [CGFloat]
    switch style {
    case .dashed: dash = [8, 5]
    case .dotted: dash = [1, 4]
    case .solid: dash = []
    }
    context.setLineDash(phase: 0, lengths: dash)
    context.strokeEllipse(
      in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
    context.setLineDash(phase: 0, lengths: [])
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

@MainActor
private func drawShipTexture(_ triangle: ShipTexturedTriangle, context: CGContext) {
  let transform = context.ctm
  let scale = min(4, max(hypot(transform.a, transform.b), hypot(transform.c, transform.d)))
  guard let pixels = ShipTextureAssets.pixels(for: triangle.texture),
    let tile = ShipTextureRaster.tile(triangle: triangle, pixels: pixels, scale: scale)
  else { return }
  let bytes = tile.rgba.map(\.bigEndian).withUnsafeBytes { Data($0) }
  guard let provider = CGDataProvider(data: bytes as CFData),
    let image = CGImage(
      width: tile.width, height: tile.height, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: tile.width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  else { return }
  context.saveGState()
  context.interpolationQuality = .none
  context.translateBy(x: tile.origin.x, y: tile.origin.y + Double(tile.height) / tile.scale)
  context.scaleBy(x: 1 / tile.scale, y: -1 / tile.scale)
  context.draw(image, in: CGRect(x: 0, y: 0, width: tile.width, height: tile.height))
  context.restoreGState()
}

private func colour(_ rgba: UInt32, opacity: Double = 1) -> CGColor {
  CGColor(
    red: Double((rgba >> 24) & 255) / 255, green: Double((rgba >> 16) & 255) / 255,
    blue: Double((rgba >> 8) & 255) / 255, alpha: opacity)
}
