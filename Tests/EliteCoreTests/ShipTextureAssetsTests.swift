import Foundation
import Testing

@testable import EliteCore

struct ShipTextureAssetsTests {
  @Test func selectedSourceBindingsSurviveMeshNormalizationAndPlayerScaling() throws {
    for (id, expected) in [("SH169", "sunray-diffuse"), ("SH170", "stingray-diffuse")] {
      let ship = try #require(ShipCatalogue.ship(id))
      let textures = try #require(ship.design.resolvedTextures)
      #expect(textures.count == 2 && textures[0].asset == expected)
      #expect(ship.design.sourceTextures?.map(\.name) == ["0", "1"])
      let raw = ship.design.rawMesh
      #expect(raw.faceTextures.count == raw.faces.count)
      for (index, mapping) in try #require(ship.design.sourceFaceTextures).enumerated() {
        #expect(raw.faceTextures[index]?.uv == mapping.uv)
        #expect(raw.faceTextures[index]?.asset == textures[mapping.texture].asset)
      }
      #expect(ship.previewMesh?.faceTextures == raw.faceTextures)
      var commander = Commander()
      commander.shipID = id
      #expect(commander.playerMesh.faceTextures == raw.faceTextures)
      let pixels = try #require(ShipTextureAssets.pixels(for: expected))
      #expect(pixels.width == 1024 && pixels.height == 1024)
      #expect(Set(pixels.pixels).count > 8)
      #expect(pixels.pixels.allSatisfy { $0 & 255 == 255 })
    }
    #expect(ShipTextureAssets.pixels(for: "../../untrusted") == nil)
  }

  @Test func sourceCachesRejectAnAlteredManifestDigest() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/EliteCore/Resources/ShipTextures")
    let original = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    #expect(ShipTextureAssets.load(manifest: original, directory: directory).pixels.count == 3)
    var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    var assets = try #require(object["assets"] as? [[String: Any]])
    assets[0]["rgbaSHA256"] = String(repeating: "0", count: 64)
    object["assets"] = assets
    let altered = try JSONSerialization.data(withJSONObject: object)
    #expect(ShipTextureAssets.load(manifest: altered, directory: directory).pixels.isEmpty)
  }

  @Test func bitmapTextureAdapterClipsBeforeAllocatingItsFixedCanvas() throws {
    let texture = try #require(ShipTextureAssets.pixels(for: "sunray-diffuse"))
    let u = 123.5 / Double(texture.width)
    let v = 345.5 / Double(texture.height)
    let triangle = ShipTexturedTriangle(
      vertices: [(-100.0, -100.0), (8000.0, -100.0), (-100.0, 8000.0)].map {
        .init(point: .init($0.0, $0.1), reciprocalDepth: 1, uOverDepth: u, vOverDepth: v)
      }, texture: "sunray-diffuse", brightness: 1,
      clip: .init(x: 0, y: 0, width: 8192, height: 8192))
    var frame = Frame()
    frame.flightClip = frame.canvas
    frame.textured(triangle)
    #expect(frame.pixels[255 * 256 + 255] == texture.pixels[345 * texture.width + 123])
  }

  @Test func malformedOptionalBindingsCannotBorrowAnotherModelOrAsset() throws {
    let design = try #require(ShipCatalogue.ship("SH169")).design
    let original = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(design)) as? [String: Any])
    for mutation in ["model", "asset", "material", "definition", "index", "duplicate"] {
      var object = original
      var bindings = try #require(object["resolvedTextures"] as? [[String: Any]])
      switch mutation {
      case "model": bindings[0]["modelSHA256"] = String(repeating: "a", count: 64)
      case "asset": bindings[0]["asset"] = "stingray-diffuse"
      case "material": bindings[0]["material"] = "unverified.png"
      case "definition": bindings[0]["definition"] = "commilray-player"
      case "index": bindings[0]["sourceTexture"] = -1
      default: bindings[1] = bindings[0]
      }
      object["resolvedTextures"] = bindings
      let decoded = try JSONDecoder().decode(
        ShipDesign.self, from: JSONSerialization.data(withJSONObject: object))
      #expect(!decoded.valid, "Refuse altered resolved binding: \(mutation)")
    }
    var fallback = original
    fallback.removeValue(forKey: "resolvedTextures")
    let archival = try JSONDecoder().decode(
      ShipDesign.self, from: JSONSerialization.data(withJSONObject: fallback))
    #expect(archival.valid && archival.rawMesh.faceTextures.isEmpty)
    #expect(archival.sourceTextures == design.sourceTextures)
    #expect(archival.sourceFaceTextures == design.sourceFaceTextures)
  }

  @Test func invalidOrMissingBundledPixelFilesRefuseWithoutReplacingGeometry() {
    let absent = URL(fileURLWithPath: "/nonexistent/ship-texture-fixture")
    #expect(ShipTextureAssets.load(manifest: Data("{}".utf8), directory: absent).pixels.isEmpty)
    #expect(
      ShipTextureAssets.load(manifest: Data(repeating: 0, count: 32_769), directory: absent).pixels
        .isEmpty)
    let manifest = """
      {"version":1,"archiveSHA256":"09d478852cf2485e3a1e8be2ebca9d8771ea13af08ac977010a7c07fb8a42e4a",
      "assets":[],"bindings":[]}
      """
    #expect(ShipTextureAssets.load(manifest: Data(manifest.utf8), directory: absent).pixels.isEmpty)
  }

  @Test func shadedSelectedHullUsesPixelsAndWireframesKeepTheirGeometry() throws {
    let ship = try #require(ShipCatalogue.ship("SH169"))
    var game = Game(executive: false)
    game.screen = .front
    let body = SpaceBody(id: 99, hull: .cobra, position: .init(0, 0, 320))
    var white: [WireLine] = []
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      var frame = Frame()
      frame.rasterizeGraphics = false
      Display.draw(body, game: game, into: &frame, mesh: ship.previewMesh)
      let textured = frame.graphics.compactMap { graphic -> ShipTexturedTriangle? in
        if case .textured(let triangle) = graphic { return triangle }
        return nil
      }
      if style == .shadedPanels {
        #expect(!textured.isEmpty)
        #expect(
          textured.allSatisfy { $0.texture == "sunray-diffuse" || $0.texture == "ray-details" })
      } else {
        #expect(textured.isEmpty && !frame.shipLines.isEmpty)
        if style == .whiteWireframe {
          white = frame.shipLines
        } else {
          #expect(
            frame.shipLines.map { [$0.x0, $0.y0, $0.x1, $0.y1] }
              == white.map { [$0.x0, $0.y0, $0.x1, $0.y1] })
        }
      }
    }
  }
}
