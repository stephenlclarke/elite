import Testing

@testable import EliteCore

struct PanelClippingTests {
  @Test func containedInclusiveBoundaryAndDegeneratePanelsKeepExactVerticesColourAndOrder() {
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.flightClip = .init(x: 16, y: 16, width: 33, height: 33)
    let polygons: [[ScreenPoint]] = [
      [.init(20.125, 20.25), .init(43.5, 25.75), .init(24.625, 41.875)],
      [.init(16, 16), .init(48, 16), .init(48, 48), .init(16, 48)],
      [.init(24, 24), .init(32, 32), .init(40, 40)],
      [.init(32, 32), .init(32, 32), .init(32, 32)],
    ]
    let colours: [UInt32] = [0x5D95_72FF, 0xFFD5_5BFF, 0x356A_5CFF, 0x183A_36FF]
    let pixels = frame.pixels
    for (polygon, colour) in zip(polygons, colours) { frame.panel(polygon, colour: colour) }
    let panels = frame.shipPanels
    #expect(panels.count == polygons.count)
    for (index, panel) in panels.enumerated() {
      #expect(panel.vertices == polygons[index] && panel.colour == colours[index])
    }
    #expect(frame.graphics.count == polygons.count && frame.pixels == pixels)
    var raster = Frame()
    raster.flightClip = frame.flightClip
    raster.panel(polygons[2], colour: colours[2])
    var expectedPixels = pixels
    for coordinate in 24..<40 { expectedPixels[coordinate * Frame.width + coordinate] = colours[2] }
    #expect(raster.pixels == expectedPixels)
    raster.panel(polygons[3], colour: colours[3])
    #expect(raster.pixels == expectedPixels)
  }

  @Test func crossingEveryEdgeRetainsClippedGeometryAndIdenticalRasterOutput() {
    func rectangle(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double)
      -> [ScreenPoint]
    {
      [.init(left, top), .init(right, top), .init(right, bottom), .init(left, bottom)]
    }
    let cases = [
      (rectangle(0, 16, 32, 48), rectangle(16, 16, 32, 48)),
      (rectangle(32, 16, 64, 48), rectangle(32, 16, 48, 48)),
      (rectangle(16, 0, 48, 32), rectangle(16, 16, 48, 32)),
      (rectangle(16, 32, 48, 64), rectangle(16, 32, 48, 48)),
      (rectangle(0, 0, 64, 64), rectangle(16, 16, 48, 48)),
    ]
    func ordered(_ points: [ScreenPoint]) -> [ScreenPoint] {
      points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
    }
    for (crossing, expected) in cases {
      for rasterize in [false, true] {
        var frame = Frame()
        frame.rasterizeGraphics = rasterize
        frame.flightClip = .init(x: 16, y: 16, width: 33, height: 33)
        var reference = frame
        frame.panel(crossing, colour: 0x5D95_72FF)
        reference.panel(expected, colour: 0x5D95_72FF)
        #expect(frame.shipPanels.count == 1 && reference.shipPanels.count == 1)
        if let actual = frame.shipPanels.first {
          #expect(ordered(actual.vertices) == ordered(expected))
          #expect(actual.colour == 0x5D95_72FF)
        }
        #expect(frame.pixels == reference.pixels)
        if rasterize { #expect(frame.pixels.contains(0x5D95_72FF)) }
      }
    }
  }

  @Test func shortNonfiniteAndFullyOutsidePanelsStillProduceNoOutput() {
    let rejected: [[ScreenPoint]] = [
      [], [.init(20, 20), .init(30, 30)],
      [.init(.nan, 20), .init(40, 20), .init(30, 40)],
      [.init(20, .infinity), .init(40, 20), .init(30, 40)],
      [.init(0, 0), .init(8, 0), .init(0, 8)],
      [.init(64, 16), .init(72, 16), .init(64, 32)],
    ]
    for rasterize in [false, true] {
      var frame = Frame()
      frame.rasterizeGraphics = rasterize
      frame.flightClip = .init(x: 16, y: 16, width: 33, height: 33)
      let before = frame
      for polygon in rejected { frame.panel(polygon, colour: 0xFFD5_5BFF) }
      #expect(frame == before)
    }
  }
}
