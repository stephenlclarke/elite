import CryptoKit
import Foundation
import Testing

@testable import L337Core

struct OriginalShipTextureAssetsTests {
  private var resourceDirectory: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/L337Core/Resources/OriginalShipTextures")
  }

  @Test func pinnedOriginalPixelsLoadThroughExistingRendererLookup() throws {
    let manifestData = try Data(contentsOf: resourceDirectory.appendingPathComponent("manifest.json"))
    let manifest = try JSONDecoder().decode(OriginalShipTextureAssets.Manifest.self, from: manifestData)
    let loaded = OriginalShipTextureAssets.load(manifest: manifestData, directory: resourceDirectory)
    #expect(loaded.count == 3)
    for asset in manifest.assets {
      let optionalImage = loaded[asset.id]
      let image = try #require(optionalImage)
      let runtimeImage = ShipTextureAssets.pixels(for: asset.id)
      #expect(runtimeImage == image)
      var bytes = Data()
      for pixel in image.pixels {
        bytes.append(UInt8((pixel >> 24) & 255))
        bytes.append(UInt8((pixel >> 16) & 255))
        bytes.append(UInt8((pixel >> 8) & 255))
        bytes.append(UInt8(pixel & 255))
      }
      let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
      #expect(digest == asset.rgbaSHA256)
      #expect(image.width == 1024 && image.height == 1024)
    }
    let unknown = ShipTextureAssets.pixels(for: "l337-../../untrusted")
    #expect(unknown == nil)
  }

  @Test func missingOrAlteredOriginalDataRefuses() throws {
    let data = try Data(contentsOf: resourceDirectory.appendingPathComponent("manifest.json"))
    let absent = URL(fileURLWithPath: "/nonexistent/original-texture-fixture")
    let missing = OriginalShipTextureAssets.load(manifest: data, directory: absent)
    let invalid = OriginalShipTextureAssets.load(manifest: Data("{}".utf8), directory: resourceDirectory)
    let oversized = OriginalShipTextureAssets.load(
      manifest: Data(repeating: 0, count: 131_073), directory: resourceDirectory)
    #expect(missing.isEmpty && invalid.isEmpty && oversized.isEmpty)
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let manifest = try JSONDecoder().decode(OriginalShipTextureAssets.Manifest.self, from: data)
    for asset in manifest.assets {
      try FileManager.default.copyItem(
        at: resourceDirectory.appendingPathComponent(asset.pngFile),
        to: temporary.appendingPathComponent(asset.pngFile))
      try FileManager.default.copyItem(
        at: resourceDirectory.appendingPathComponent(asset.rgbaFile),
        to: temporary.appendingPathComponent(asset.rgbaFile))
    }
    try Data("bad PNG".utf8).write(to: temporary.appendingPathComponent(manifest.assets[0].pngFile))
    let corruptPNG = OriginalShipTextureAssets.load(manifest: data, directory: temporary)
    #expect(corruptPNG.isEmpty)
    try FileManager.default.removeItem(at: temporary.appendingPathComponent(manifest.assets[0].pngFile))
    try FileManager.default.copyItem(
      at: resourceDirectory.appendingPathComponent(manifest.assets[0].pngFile),
      to: temporary.appendingPathComponent(manifest.assets[0].pngFile))
    try Data([0]).write(to: temporary.appendingPathComponent(manifest.assets[0].rgbaFile))
    let corruptCache = OriginalShipTextureAssets.load(manifest: data, directory: temporary)
    #expect(corruptCache.isEmpty)
  }

  private func design(texture: Int = 0, uv: [[Double]]? = nil,
                      reference: OriginalShipTextureReference? = nil) -> ShipDesign {
    let mapping = ShipSourceFaceTexture(
      texture: texture, uv: uv ?? [[-1.25, 2.75], [1.5, -0.5], [0, 1]])
    return ShipDesign(
      vertices: [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]],
      faces: [[0, 2, 1], [0, 1, 3], [0, 3, 2], [1, 2, 3]], license: "MIT", source: "Original test",
      textures: [reference ?? .init(asset: "l337-patrol-diffuse", license: "MIT", repeat: true)],
      faceTextures: Array(repeating: mapping, count: 4))
  }

  @Test func originalDecodingAndMeshTransformsRetainAuthoredUVs() throws {
    let original = design()
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ShipDesign.self, from: encoded)
    #expect(decoded.valid)
    let raw = decoded.rawMesh
    #expect(raw.faceTextures.count == 4)
    #expect(raw.faceTextures[0]?.uv == [[-1.25, 2.75], [1.5, -0.5], [0, 1]])
    let normalized = raw.showroomNormalised
    #expect(normalized.faceTextures == raw.faceTextures)
    let playerScaled = Mesh(
      vertices: normalized.vertices.map { $0 * 0.69 }, faces: normalized.faces,
      faceTextures: normalized.faceTextures, preserveWinding: true)
    #expect(playerScaled.faceTextures == raw.faceTextures)
  }

  @Test func originalNegativeOneAndInvalidReferencesHaveExplicitSemantics() {
    let placeholders = design(texture: -1, uv: [[0, 0], [0, 0], [0, 0]])
    #expect(placeholders.valid)
    #expect(placeholders.rawMesh.faceTextures.allSatisfy { $0 == nil })
    for invalid in [
      design(texture: 5), design(uv: [[0, 0]]),
      design(uv: [[.nan, 0], [0, 0], [0, 0]]),
      design(reference: .init(asset: "unknown", license: "MIT", repeat: true)),
      design(reference: .init(asset: "l337-patrol-diffuse", license: "unknown", repeat: true)),
      design(reference: .init(asset: "l337-patrol-diffuse", license: "MIT", repeat: false)),
    ] {
      #expect(!invalid.valid)
    }
  }

  @Test func simultaneousImportedAndOriginalMappingsAreRefused() throws {
    let data = try JSONEncoder().encode(design())
    let value = try JSONSerialization.jsonObject(with: data)
    var object = try #require(value as? [String: Any])
    object["sourceTextures"] = [["name": "imported", "source": "archive", "license": "unknown"]]
    let ambiguousData = try JSONSerialization.data(withJSONObject: object)
    let ambiguous = try JSONDecoder().decode(ShipDesign.self, from: ambiguousData)
    #expect(!ambiguous.valid)
    #expect(ambiguous.resolvedFaceTextures.isEmpty)
  }

  @Test func originalFaceCountAndDuplicateReferencesAreRefused() throws {
    let data = try JSONEncoder().encode(design())
    let value = try JSONSerialization.jsonObject(with: data)
    let original = try #require(value as? [String: Any])
    var short = original
    let mappings = try #require(short["faceTextures"] as? [[String: Any]])
    short["faceTextures"] = Array(mappings.dropLast())
    let shortData = try JSONSerialization.data(withJSONObject: short)
    let shortDesign = try JSONDecoder().decode(ShipDesign.self, from: shortData)
    #expect(!shortDesign.valid)
    var duplicate = original
    let references = try #require(duplicate["textures"] as? [[String: Any]])
    duplicate["textures"] = [references[0], references[0]]
    let duplicateData = try JSONSerialization.data(withJSONObject: duplicate)
    let duplicateDesign = try JSONDecoder().decode(ShipDesign.self, from: duplicateData)
    #expect(!duplicateDesign.valid)
  }
}
