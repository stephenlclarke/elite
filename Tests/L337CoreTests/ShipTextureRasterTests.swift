import Testing

@testable import L337Core

struct ShipTextureRasterTests {
  private let clip = CanvasRect(x: 0, y: 0, width: 4, height: 4)

  private func vertex(_ x: Double, _ y: Double, depth: Double = 1, u: Double, v: Double)
    -> ShipTextureVertex
  {
    .init(
      point: .init(x, y), reciprocalDepth: 1 / depth, uOverDepth: u / depth, vOverDepth: v / depth)
  }

  private func triangle(u: Double, v: Double, brightness: Double = 1) -> ShipTexturedTriangle {
    .init(
      vertices: [vertex(0, 0, u: u, v: v), vertex(4, 0, u: u, v: v), vertex(0, 4, u: u, v: v)],
      texture: "test", brightness: brightness, clip: clip)
  }

  @Test func sourceAlphaIsNotTransparencyAndTexelsRemainDistinct() throws {
    let pixels = try #require(
      ShipTexturePixels(
        width: 2, height: 2, pixels: [0xFF00_0000, 0x00FF_0080, 0x0000_FF00, 0xFFFF_FF00]))
    let red = try #require(
      ShipTextureRaster.tile(triangle: triangle(u: 0.25, v: 0.25), pixels: pixels))
    let blue = try #require(
      ShipTextureRaster.tile(triangle: triangle(u: 0.25, v: 0.75), pixels: pixels))
    #expect(red.rgba[0] == 0xFF00_00FF)
    #expect(blue.rgba[0] == 0x0000_FFFF)
    #expect(red.rgba.last == 0)
    let shaded = try #require(
      ShipTextureRaster.tile(triangle: triangle(u: 0.25, v: 0.25, brightness: 0.5), pixels: pixels))
    #expect(shaded.rgba[0] == 0x8000_00FF)
  }

  @Test func bilinearSamplingRepeatsAcrossBothTextureEdges() throws {
    let pixels = try #require(
      ShipTexturePixels(width: 2, height: 1, pixels: [0xFF00_0000, 0x0000_FF00]))
    let mixed = try #require(
      ShipTextureRaster.tile(triangle: triangle(u: 0.5, v: 0), pixels: pixels))
    #expect(mixed.rgba[0] == 0x8000_80FF)
    let repeated = try #require(
      ShipTextureRaster.tile(triangle: triangle(u: -0.75, v: 3.5), pixels: pixels))
    #expect(repeated.rgba[0] == 0xFF00_00FF)
  }

  @Test func interpolationUsesReciprocalDepthRatherThanAffineUV() throws {
    let pixels = try #require(
      ShipTexturePixels(
        width: 4, height: 1, pixels: [0xFF00_00FF, 0x00FF_00FF, 0x0000_FFFF, 0xFFFF_FFFF]))
    let perspective = ShipTexturedTriangle(
      vertices: [
        vertex(0, 0, u: 0, v: 0.5), vertex(4, 0, depth: 4, u: 1, v: 0.5),
        vertex(0, 4, u: 0, v: 0.5),
      ],
      texture: "test", brightness: 1, clip: .init(x: 1, y: 0, width: 1, height: 1))
    let tile = try #require(ShipTextureRaster.tile(triangle: perspective, pixels: pixels))
    // At (1.5, 0.5), affine u=.375 samples green; perspective u=3/23 samples red.
    #expect((tile.rgba[0] >> 24) & 255 > 240)
    #expect((tile.rgba[0] >> 16) & 255 < 16)
    let reversed = ShipTexturedTriangle(
      vertices: Array(perspective.vertices.reversed()), texture: "test", brightness: 1,
      clip: perspective.clip)
    #expect(ShipTextureRaster.tile(triangle: reversed, pixels: pixels) == tile)
  }

  @Test func nearPlaneClippingInterpolatesUVAndPreservesFanOrder() {
    let triangles = ShipTextureProjection.triangles(
      vertices: [.init(-1, 0, 0), .init(1, 0, 2), .init(0, 1, 2)],
      uv: [[0, 0], [1, 0], [0, 1]], projection: .init(center: .init(2, 2), focal: 1),
      texture: "test", brightness: 1, clip: clip)
    #expect(triangles.count == 2)
    guard triangles.count == 2 else { return }
    let first = triangles[0].vertices
    #expect(first[0].reciprocalDepth == 1)
    #expect(first[0].uOverDepth == 0)
    #expect(first[0].vOverDepth == 0.5)
    #expect(first[1].reciprocalDepth == 1)
    #expect(first[1].uOverDepth == 0.5)
    #expect(first[1].vOverDepth == 0)
    #expect(first[2].reciprocalDepth == 0.5)
    #expect(triangles[1].vertices[0] == first[0])
    #expect(triangles[1].vertices[1] == first[2])
    #expect(
      ShipTextureProjection.triangles(
        vertices: [.init(0, 0, 0), .init(1, 0, 0), .init(0, 1, 0)],
        uv: [[0, 0], [1, 0], [0, 1]], projection: .legacy, texture: "test", brightness: 1,
        clip: clip
      ).isEmpty)
  }

  @Test func clippingAndScaleBoundTheTileAndLeaveOutsidePixelsTransparent() throws {
    let pixels = try #require(ShipTexturePixels(width: 1, height: 1, pixels: [0x1234_5600]))
    let clipped = ShipTexturedTriangle(
      vertices: triangle(u: 0, v: 0).vertices, texture: "test", brightness: 1,
      clip: .init(x: 0.4, y: 0.4, width: 1, height: 1))
    let tile = try #require(ShipTextureRaster.tile(triangle: clipped, pixels: pixels, scale: 2))
    #expect(tile.origin == .init(0, 0))
    #expect(tile.width == 3 && tile.height == 3)
    #expect(tile.rgba[0] == 0)
    #expect(tile.rgba[4] == 0x1234_56FF)
  }

  @Test func malformedAndExcessiveInputsFailWithoutAllocationOrIntegerConversionTraps() throws {
    #expect(ShipTexturePixels(width: Int.max, height: 2, pixels: []) == nil)
    #expect(ShipTexturePixels(width: 2049, height: 1, pixels: []) == nil)
    #expect(ShipTexturePixels(width: 2, height: 2, pixels: [0]) == nil)
    let pixels = try #require(ShipTexturePixels(width: 1, height: 1, pixels: [0xFFFF_FFFF]))
    for scale in [Double.nan, Double.infinity, 0, -1, 17] {
      #expect(
        ShipTextureRaster.tile(triangle: triangle(u: 0, v: 0), pixels: pixels, scale: scale) == nil)
    }
    let negativeBounds = ShipTexturedTriangle(
      vertices: [
        vertex(-4, -4, u: 0, v: 0), vertex(0, -4, u: 0, v: 0),
        vertex(-4, 0, u: 0, v: 0),
      ], texture: "test", brightness: 1,
      clip: .init(x: -4, y: -4, width: 4, height: 4))
    #expect(
      ShipTextureRaster.tile(
        triangle: negativeBounds, pixels: pixels, scale: Double.leastNonzeroMagnitude) == nil)
    let smallTile = try #require(
      ShipTextureRaster.tile(
        triangle: negativeBounds, pixels: pixels, scale: 1 / 8192))
    #expect(smallTile.origin.x.isFinite && smallTile.origin.y.isFinite)
    let invalid = ShipTexturedTriangle(
      vertices: [vertex(.nan, 0, u: 0, v: 0)], texture: "test", brightness: 1, clip: clip)
    #expect(ShipTextureRaster.tile(triangle: invalid, pixels: pixels) == nil)
    let excessive = ShipTexturedTriangle(
      vertices: [
        vertex(0, 0, u: 0, v: 0), vertex(4096, 0, u: 0, v: 0), vertex(0, 4096, u: 0, v: 0),
      ],
      texture: "test", brightness: 1, clip: .init(x: 0, y: 0, width: 4096, height: 4096))
    let reduced = try #require(
      ShipTextureRaster.tile(triangle: excessive, pixels: pixels, scale: 2))
    #expect(reduced.scale < 1)
    #expect(reduced.width <= 4096 && reduced.height <= 4096)
    #expect(reduced.rgba.count <= 4_194_304)
    #expect(reduced.rgba[0] == 0xFFFF_FFFF)
    for invalidClip in [
      CanvasRect(x: .infinity, y: 0, width: 1, height: 1),
      CanvasRect(x: 0, y: 0, width: -1, height: 1),
    ] {
      let candidate = ShipTexturedTriangle(
        vertices: triangle(u: 0, v: 0).vertices, texture: "test", brightness: 1, clip: invalidClip)
      #expect(ShipTextureRaster.tile(triangle: candidate, pixels: pixels) == nil)
    }
    #expect(
      ShipTextureProjection.triangles(
        vertices: [.init(.nan, 0, 1), .init(1, 0, 1), .init(0, 1, 1)],
        uv: [[0, 0], [1, 0], [0, 1]],
        projection: .legacy, texture: "test", brightness: 1, clip: clip
      ).isEmpty)
  }
  @Test func originalReliefPreservesPaletteAndDoesNotLightItTwice() throws {
    let neutral = try #require(ShipTexturePixels(width: 1, height: 1, pixels: [0x5656_5600]))
    let base = triangle(u: -0.25, v: 3.5, brightness: 0.5)
    for colour: UInt32 in [0xC828_14FF, 0x1428_C8FF] {
      let original = ShipTexturedTriangle(
        vertices: base.vertices, texture: "l337-patrol-diffuse", brightness: base.brightness,
        clip: base.clip, appearance: .originalSurface(litMaterial: colour))
      let tile = try #require(ShipTextureRaster.tile(triangle: original, pixels: neutral))
      #expect(tile.rgba[0] == colour)
      #expect(tile.rgba.last == 0)
    }
    let raw = try #require(ShipTextureRaster.tile(triangle: base, pixels: neutral))
    #expect(raw.rgba[0] == 0x2B2B_2BFF)
  }

  @Test func originalReliefHasAuthoredBoundsAndRefusesUnrelatedAssets() throws {
    let base = triangle(u: 0, v: 0)
    let original = ShipTexturedTriangle(
      vertices: base.vertices, texture: "l337-service-details", brightness: 1,
      clip: base.clip, appearance: .originalSurface(litMaterial: 0xC864_32FF))
    for (sample, expected): (UInt32, UInt32) in [
      (0x0000_0000, 0x361B_0EFF), (0xFFFF_FF00, 0xDC6E_37FF),
    ] {
      let pixels = try #require(ShipTexturePixels(width: 1, height: 1, pixels: [sample]))
      let tile = try #require(ShipTextureRaster.tile(triangle: original, pixels: pixels))
      #expect(tile.rgba[0] == expected)
    }
    let pixels = try #require(ShipTexturePixels(width: 1, height: 1, pixels: [0x5656_56FF]))
    let archival = ShipTexturedTriangle(
      vertices: base.vertices, texture: "sunray-diffuse", brightness: 1, clip: base.clip,
      appearance: original.appearance)
    #expect(ShipTextureRaster.tile(triangle: archival, pixels: pixels) == nil)
    let translucent = ShipTexturedTriangle(
      vertices: base.vertices, texture: original.texture, brightness: 1, clip: base.clip,
      appearance: .originalSurface(litMaterial: 0xC864_3280))
    #expect(ShipTextureRaster.tile(triangle: translucent, pixels: pixels) == nil)
  }

  @Test func originalMaterialSurvivesNearPlaneClipping() {
    let appearance = ShipTextureAppearance.originalSurface(litMaterial: 0x1234_56FF)
    let projected = ShipTextureProjection.triangles(
      vertices: [.init(-1, 0, 0), .init(1, 0, 2), .init(0, 1, 2)],
      uv: [[-1, 0], [1, 0], [0, 1]], projection: .init(center: .init(2, 2), focal: 1),
      texture: "l337-patrol-diffuse", brightness: 1, clip: clip, appearance: appearance)
    #expect(projected.count == 2)
    #expect(projected.allSatisfy { $0.appearance == appearance })
  }

}
