import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@Suite(.serialized)
struct ShipPanelRendererTests {
  @MainActor private func context(_ size: Int) throws -> CGContext {
    try #require(
      CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  }

  @MainActor private func bytes(_ context: CGContext) throws -> Data {
    Data(bytes: try #require(context.data), count: context.bytesPerRow * context.height)
  }

  private func composition() -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: 64, height: 64)
    frame.flightClip = .init(x: 4, y: 4, width: 56, height: 56)
    func panel(_ points: [ScreenPoint], _ colour: UInt32) -> Graphic {
      .panel(.init(vertices: points, colour: colour))
    }
    frame.worldGraphics = [
      panel([.init(0, 8), .init(62, 8), .init(0, 62)], 0xFF00_00FF),
      panel([.init(18, 12), .init(55, 45), .init(18, 52)], 0x0000_FF01),
      .wire(.init(x0: 4, y0: 32, x1: 60, y1: 32, ink: .white)),
      panel([.init(20, 24), .init(44, 24), .init(32, 48)], Ink.gold.rawValue),
      panel([.init(42, 8), .init(58, 8), .init(58, 20), .init(42, 20)], Ink.cyan.rawValue),
      panel([.init(46, 10), .init(57, 10), .init(57, 19)], Ink.purple.rawValue),
      panel([.init(5, 55), .init(10, 55), .init(15, 55)], Ink.orange.rawValue),
    ]
    return frame
  }

  @MainActor @Test func packingRetainsTriangleOrderCoordinatesColoursAndBoundedRefusal() throws {
    let graphics: [Graphic] = [
      .panel(.init(vertices: [.init(8, 8), .init(48, 8), .init(8, 48)], colour: 0x5D95_72FF)),
      .panel(.init(vertices: [.init(12, 12), .init(40, 12), .init(12, 40)], colour: 0xFFD5_5B01)),
    ]
    let transform = CGAffineTransform(a: 2, b: 0, c: 0, d: -2, tx: 9.25, ty: 140.5)
    let clip = CGRect(x: 0, y: 0, width: 64, height: 64)
    let batch = try #require(
      ShipPanelRenderer.batch(graphics[...], transform: transform, clip: clip))
    #expect(batch.records.count == graphics.count && batch.scale == SIMD2(2, 2))
    #expect(MemoryLayout<ShipPanelRecord>.stride == 32)
    #expect(
      batch.bounds.applying(transform).minX.rounded() == batch.bounds.applying(transform).minX)
    #expect(
      batch.bounds.applying(transform).minY.rounded() == batch.bounds.applying(transform).minY)
    #expect(
      zip(graphics, batch.records).allSatisfy { graphic, record in
        guard case .panel(let panel) = graphic else { return false }
        return record.colour == panel.colour
          && zip(panel.vertices, [record.a, record.b, record.c]).allSatisfy { original, packed in
            Double(packed.x) + batch.bounds.minX == original.x
              && Double(packed.y) + batch.bounds.minY == original.y
          }
      })
    let invalid: [[ScreenPoint]] = [
      [], [.init(0, 0), .init(1, 1)],
      [.init(0, 0), .init(1, 1), .init(2, 2)],
      [.init(.nan, 0), .init(1, 0), .init(0, 1)],
      [.init(0, 0), .init(1, 0), .init(1, 1), .init(0, 1)],
    ]
    for points in invalid {
      let run: [Graphic] = [.panel(.init(vertices: points, colour: Ink.white.rawValue))]
      #expect(ShipPanelRenderer.batch(run[...], transform: transform, clip: clip) == nil)
    }
    #expect(
      ShipPanelRenderer.batch(graphics[...], transform: .init(rotationAngle: 0.2), clip: clip)
        == nil)
    #expect(
      ShipPanelRenderer.batch(graphics[...], transform: .init(scaleX: 100, y: 100), clip: clip)
        == nil)
    let oversized = Array(repeating: graphics[0], count: 120_001)
    #expect(ShipPanelRenderer.batch(oversized[...], transform: transform, clip: clip) == nil)
  }

  @MainActor @Test func actualMetalPreservesPainterOrderClippingAndOnlyBoundaryCoverageCanDiffer()
    async throws
  {
    let renderer = ShipPanelRenderer()
    let device = await renderer.prepareGPU()
    try #require(device != nil, Comment(rawValue: renderer.failureReason ?? "Metal unavailable"))
    let frame = composition()
    let edges = frame.shipPanels.flatMap { panel in
      panel.vertices.indices.map {
        (panel.vertices[$0], panel.vertices[($0 + 1) % panel.vertices.count])
      }
    }
    for (scale, flipped) in [(1.0, false), (2.0, true)] {
      let reference = try context(160)
      let actual = try context(160)
      for drawing in [reference, actual] {
        drawing.translateBy(x: 9.25, y: flipped ? 6.5 + 64 * scale : 6.5)
        drawing.scaleBy(x: scale, y: flipped ? -scale : scale)
      }
      let transform = actual.ctm
      let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
      drawFrame(frame, context: reference, rect: rect)
      let execution = drawFrame(frame, context: actual, rect: rect, panelRenderer: renderer)
      #expect(execution.metalPanels == 4 && execution.cpuPanels == 2)
      #expect(execution.backendDescription.contains("mixed CPU"))
      let lhs = try bytes(reference)
      let rhs = try bytes(actual)
      func distance(_ p: CGPoint, _ a: ScreenPoint, _ b: ScreenPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = dx * dx + dy * dy
        let t = length > 0 ? min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length)) : 0
        return hypot(p.x - a.x - t * dx, p.y - a.y - t * dy)
      }
      var illegalDifferences = 0
      var interior = 0
      for y in 0..<160 {
        for x in 0..<160 {
          let offset = (y * 160 + x) * 4
          let point = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5).applying(transform.inverted())
          let nearBoundary = edges.contains { distance(point, $0.0, $0.1) <= 0.125 + 1 / scale }
          let differs = (0..<4).contains { lhs[offset + $0] != rhs[offset + $0] }
          if !nearBoundary {
            interior += rhs[offset + 3] == 255 ? 1 : 0
            if differs { illegalDifferences += 1 }
          }
          if point.x < 4 || point.x >= 60 || point.y < 4 || point.y >= 60 {
            if differs { illegalDifferences += 1 }
          }
        }
      }
      #expect(interior > 100 && illegalDifferences == 0)
      // These well-inside pixels exercise later panels over earlier panels, wires and CPU polygons.
      for point in [
        CGPoint(x: 12, y: 12), CGPoint(x: 32, y: 32), CGPoint(x: 54, y: 12), CGPoint(x: 44, y: 18),
      ] {
        let device = point.applying(transform)
        let offset = (Int(device.y) * 160 + Int(device.x)) * 4
        #expect((0..<4).allSatisfy { lhs[offset + $0] == rhs[offset + $0] })
        #expect(rhs[offset + 3] == 255)
      }
    }
  }

  @MainActor @Test func unpreparedUnavailableAndFailedPreparationUseExactQuartzAndWireModes()
    async throws
  {
    let unavailable = ShipPanelRenderer(compiler: {
      await Task.yield()
      return nil
    })
    let frame = composition()
    let reference = try context(64)
    let pending = try context(64)
    let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
    drawFrame(frame, context: reference, rect: rect)
    let execution = drawFrame(frame, context: pending, rect: rect, panelRenderer: unavailable)
    #expect(execution.metalPanels == 0 && execution.cpuPanels == 6 && !unavailable.failed)
    #expect(try bytes(pending) == bytes(reference))
    #expect(await unavailable.prepareGPU() == nil && unavailable.failed)
    let failed = try context(64)
    let retry = drawFrame(frame, context: failed, rect: rect, panelRenderer: unavailable)
    #expect(retry.metalPanels == 0 && retry.backendDescription == "CPU ship panels")
    #expect(try bytes(failed) == bytes(reference))
    for ink in [Ink.white, .gold] {
      var wires = frame
      wires.worldGraphics = [.wire(.init(x0: 5, y0: 6, x1: 54, y1: 55, ink: ink))]
      let cpu = try context(64)
      let candidate = try context(64)
      drawFrame(wires, context: cpu, rect: rect)
      let result = drawFrame(wires, context: candidate, rect: rect, panelRenderer: unavailable)
      #expect(result.cpuPanels == 0 && result.metalPanels == 0)
      #expect(try bytes(cpu) == bytes(candidate))
    }
    let compilationError = NSError(domain: "ShipPanelRendererTests", code: 1)
    let rejected = ShipPanelRenderer(compiler: { throw compilationError })
    #expect(await rejected.prepareGPU() == nil && rejected.failed)
    #expect(rejected.failureReason?.contains("ShipPanelRendererTests") == true)
    let errorFallback = try context(64)
    let errorExecution = drawFrame(
      frame, context: errorFallback, rect: rect, panelRenderer: rejected)
    #expect(errorExecution.metalPanels == 0 && errorExecution.cpuPanels == 6)
    #expect(try bytes(errorFallback) == bytes(reference))
    var budget = ShipPanelBudget(runs: 0, pixels: 0)
    let untouched = try context(64)
    let before = try bytes(untouched)
    #expect(unavailable.draw(frame.worldGraphics[...], context: untouched, budget: &budget) == nil)
    #expect(try bytes(untouched) == before)
  }

  @MainActor @Test func originalSH123AndActualFlippedGameViewUseGPUWithoutMutatingRetainedImages()
    async throws
  {
    let view = GameView(frame: CGRect(x: 0, y: 0, width: 768, height: 768))
    let device = await view.shipPanelRenderer.prepareGPU()
    try #require(
      device != nil, Comment(rawValue: view.shipPanelRenderer.failureReason ?? "Metal unavailable"))
    #expect(view.isFlipped)
    #expect(L337Branding.shipID == "SH123" && L337Branding.titleMesh.faces.count == 99648)
    #expect(L337Branding.titleMesh.vertices.count == 49834)
    var game = Game(executive: false)
    game.screen = .title
    game.commander.shipDisplayStyle = .shadedPanels
    var retained: CGImage?
    var retainedBytes: Data?
    for time in [0.0, 1.375] {
      game.time = time
      let frame = Display.presentation(game, width: 768, height: 768)
      let drawing = try context(1536)
      drawing.translateBy(x: 0, y: 1536)
      drawing.scaleBy(x: 2, y: -2)
      let execution = drawFrame(
        frame, context: drawing, rect: CGRect(x: 0, y: 0, width: 768, height: 768),
        panelRenderer: view.shipPanelRenderer)
      #expect(execution.metalPanels > 10000)
      #expect(execution.metalPanels + execution.cpuPanels == frame.shipPanels.count)
      #expect(try bytes(drawing).contains(where: { $0 != 0 }))
      if retained == nil {
        let graphic = try #require(
          frame.graphics.first { graphic in
            if case .panel(let panel) = graphic { return ShipPanelRenderer.eligible(panel) }
            return false
          })
        let run = [graphic]
        var budget = ShipPanelBudget()
        let result = try #require(
          view.shipPanelRenderer.image(
            run[...], transform: .identity, clip: CGRect(x: 0, y: 0, width: 768, height: 768),
            budget: &budget))
        retained = result.image
        retainedBytes = try #require(result.image.dataProvider?.data) as Data
      }
    }
    #expect(try #require(retained?.dataProvider?.data) as Data == retainedBytes)
    view.game = game
    let native = try context(1536)
    native.translateBy(x: 0, y: 1536)
    native.scaleBy(x: 2, y: -2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: native, flipped: true)
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
    #expect(try bytes(native).contains(where: { $0 != 0 }))
    #expect(try #require(retained?.dataProvider?.data) as Data == retainedBytes)
  }
}
