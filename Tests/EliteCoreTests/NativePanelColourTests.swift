import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

struct NativePanelColourTests {
  @MainActor @Test func reusedPanelColourPreservesOriginalNativeBitmap() throws {
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.responsive = true
    frame.canvas = .init(x: 0, y: 0, width: 64, height: 64)
    let panels: [ShipPanel] = [
      .init(vertices: [], colour: 0xFFFF_FFFF),
      .init(
        vertices: [.init(8.25, 9.5), .init(54.5, 12.25), .init(25.75, 54.5)],
        colour: 0x5D95_72FF),
      .init(
        vertices: [.init(16.5, 20.25), .init(48.75, 18.5), .init(42.25, 48.75)],
        colour: 0xFFD5_5B40),
      .init(vertices: [.init(10, 40), .init(20, 45), .init(30, 50)], colour: 0x356A_5CFF),
      .init(vertices: [.init(32, 32), .init(32, 32), .init(32, 32)], colour: 0x183A_36FF),
    ]
    frame.graphics = panels.map(Graphic.panel)
    func context() throws -> CGContext {
      try #require(
        CGContext(
          data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 128 * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    }
    let actual = try context()
    drawFrame(frame, context: actual, rect: CGRect(x: 0, y: 0, width: 128, height: 128))
    let reference = try context()
    reference.scaleBy(x: 2, y: 2)
    reference.clip(to: CGRect(x: 0, y: 0, width: 64, height: 64))
    reference.setShouldAntialias(true)
    reference.setAllowsAntialiasing(true)
    reference.setLineJoin(.round)
    reference.setLineCap(.round)
    // Keep the original two-colour construction as an independent native drawing oracle.
    func originalColour(_ rgba: UInt32) -> CGColor {
      CGColor(
        red: Double((rgba >> 24) & 255) / 255, green: Double((rgba >> 16) & 255) / 255,
        blue: Double((rgba >> 8) & 255) / 255, alpha: 1)
    }
    for panel in panels {
      reference.setLineWidth(0.85)
      guard let first = panel.vertices.first else { continue }
      reference.setFillColor(originalColour(panel.colour))
      reference.setStrokeColor(originalColour(panel.colour))
      reference.setLineWidth(0.25)
      reference.beginPath()
      reference.move(to: CGPoint(x: first.x, y: first.y))
      for point in panel.vertices.dropFirst() {
        reference.addLine(to: CGPoint(x: point.x, y: point.y))
      }
      reference.closePath()
      reference.drawPath(using: .fillStroke)
    }
    let actualBytes = try #require(actual.data).assumingMemoryBound(to: UInt8.self)
    let referenceBytes = try #require(reference.data).assumingMemoryBound(to: UInt8.self)
    let count = 128 * 128 * 4
    let actualPixels = Array(UnsafeBufferPointer(start: actualBytes, count: count))
    #expect(actualPixels.contains(where: { $0 != 0 }))
    #expect(actualPixels == Array(UnsafeBufferPointer(start: referenceBytes, count: count)))
  }
}
