import Testing

@testable import EliteCore

struct OriginalTexturePaletteDisplayTests {
  @Test(arguments: [false, true])
  func texturedDisplayCarriesActualPaletteAndEmission(emissive: Bool) throws {
    var game = Game(executive: false)
    game.screen = .front
    game.commander.shipDisplayStyle = .shadedPanels
    let body = SpaceBody(id: 99, hull: .cobra, position: .init(0, 0, 320))
    let neutral = try #require(ShipTexturePixels(width: 1, height: 1, pixels: [0x5656_56FF]))
    var results: [UInt32] = []
    for colour: UInt32 in [0xC828_14FF, 0x1428_C8FF] {
      let mesh = Mesh(
        vertices: [.init(-20, -20, 0), .init(0, 20, 0), .init(20, -20, 0)],
        faces: [[0, 1, 2]],
        materials: [.init(name: "authored", colour: colour, emissive: emissive)],
        faceMaterials: [0],
        faceTextures: [
          ShipMeshTexture(asset: "l337-patrol-diffuse", uv: [[0, 0], [0, 0], [0, 0]])
        ],
        preserveWinding: true)
      var frame = Frame()
      frame.rasterizeGraphics = false
      Display.draw(body, game: game, into: &frame, mesh: mesh)
      let triangles = frame.graphics.compactMap { graphic -> ShipTexturedTriangle? in
        if case .textured(let triangle) = graphic { return triangle }
        return nil
      }
      let triangle = try #require(triangles.first)
      let expected = ShipProjection.shade(colour, normal: .init(0, 0, -1600), emissive: emissive)
      #expect(triangle.appearance == .originalSurface(litMaterial: expected))
      let tile = try #require(ShipTextureRaster.tile(triangle: triangle, pixels: neutral))
      let pixel = try #require(tile.rgba.first { $0 & 255 != 0 })
      #expect(pixel == expected)
      if emissive { #expect(pixel == colour) }
      results.append(pixel)
    }
    #expect(results.count == 2 && results[0] != results[1])
    #expect((results[0] >> 24) > ((results[0] >> 8) & 255))
    #expect((results[1] >> 24) < ((results[1] >> 8) & 255))
  }
}
