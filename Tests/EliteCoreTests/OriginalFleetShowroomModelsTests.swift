import CryptoKit
import Foundation
import Testing

@testable import EliteCore

struct OriginalFleetShowroomModelsTests {
  private var directory: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/EliteCore/Resources/OriginalFleetShowroomModels")
  }

  private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  @Test func completeManifestRemainsSeparateFromLiveCatalogue() {
    let expected = (1...171).map { String(format: "SH%03d", $0) }
    #expect(OriginalFleetShowroomModels.ids == expected)
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id) == [
        "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
        "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH061",
      ])
  }

  @Test(arguments: ["SH001", "SH023", "SH004", "SH108"])
  func retainedAndEffectiveNewModelsPreserveCoordinatesAndUnits(id: String) throws {
    let model = try OriginalFleetShowroomModels.model(for: id)
    let expected: [String: (Int, Int, String?, Vector3)] = [
      "SH001": (984, 1772, nil, .init(0.104, 0.3, -1.702)),
      "SH023": (536, 964, nil, .init(-0.520085, -0.1, -1.50696)),
      "SH004": (152, 252, "metres", .init(2.0592, 0.48, -11.7)),
      "SH108": (122, 208, "metres", .init(0, 0, -12)),
    ]
    let facts = try #require(expected[id])
    #expect(model.id == id && model.nativeDesign.valid)
    #expect(model.nativeDesign.vertices.count == facts.0)
    #expect(model.nativeDesign.faces.count == facts.1)
    #expect(model.coordinateUnits == facts.2)
    let mesh = model.displayMesh
    #expect(mesh.vertices.first == facts.3)
    #expect(mesh.faces == model.nativeDesign.faces)
    #expect(mesh.materials == (model.nativeDesign.materials ?? []))
    #expect(mesh.faceMaterials == (model.nativeDesign.faceMaterials ?? []))
    #expect(mesh.faceTextures == model.nativeDesign.resolvedFaceTextures)
    #expect(model.sourceSHA256.count == 64 && !model.sourcePath.isEmpty)
    if id == "SH004" { #expect(model.sourcePath.contains("native-lod")) }
  }

  @Test func currentBrandingModelRetainsApprovedExactGeometryAndPalette() throws {
    let model = try OriginalFleetShowroomModels.model(for: "SH123")
    #expect(model.sourcePath == "branding-proposal/selected-ship.toml")
    #expect(
      model.sourceSHA256 == "2179227760376ed17b276153cb7cb20894f4f1bad5bf48e339b7dc874f70fe69")
    #expect(model.nativeDesign.vertices.count == 49834 && model.nativeDesign.faces.count == 99648)
    #expect(model.coordinateUnits == nil)
    #expect(model.displayMesh.materials.contains { $0.colour == 0x5D95_72FF })
    #expect(model.displayMesh.materials.contains { $0.emissive && $0.colour == 0xFFD5_5BFF })
    #expect(OriginalFleetDefinitionData.staged.first { $0.id == "SH123" }?.runtimeReady == false)
  }

  @Test func unknownIDAndAlteredAssetRefuse() throws {
    #expect(throws: OriginalFleetShowroomModels.Failure.unknownID) {
      try OriginalFleetShowroomModels.model(for: "SH999")
    }
    let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    let manifest = try OriginalFleetShowroomModels.validatedManifest(
      data, expectedSHA256: OriginalFleetShowroomModels.manifestSHA256)
    let entry = try #require(manifest.models.first)
    var asset = try Data(contentsOf: directory.appendingPathComponent(entry.file))
    asset[asset.startIndex] ^= 1
    #expect(throws: OriginalFleetShowroomModels.Failure.invalidAsset) {
      try OriginalFleetShowroomModels.decode(asset, entry: entry)
    }
  }

  @Test func incompleteDuplicateAndEscapingManifestEntriesRefuse() throws {
    let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    let parsed = try JSONSerialization.jsonObject(with: data)
    let original = try #require(parsed as? [String: Any])
    let rows = try #require(original["models"] as? [[String: Any]])
    for mode in ["missing", "duplicate", "escape", "oversized", "badHash"] {
      var changed = original
      var models = rows
      switch mode {
      case "missing": models.removeLast()
      case "duplicate": models[1]["id"] = models[0]["id"]
      case "escape": models[0]["file"] = "../SH001.json"
      case "oversized": models[0]["bytes"] = OriginalFleetShowroomModels.maximumAssetBytes + 1
      default: models[0]["sha256"] = "invalid"
      }
      changed["models"] = models
      let malformed = try JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys])
      #expect(throws: OriginalFleetShowroomModels.Failure.invalidManifest) {
        try OriginalFleetShowroomModels.validatedManifest(
          malformed, expectedSHA256: digest(malformed))
      }
    }
    #expect(throws: OriginalFleetShowroomModels.Failure.invalidManifest) {
      try OriginalFleetShowroomModels.validatedManifest(
        data, expectedSHA256: String(repeating: "0", count: 64))
    }
  }

  @Test func matchingHashDoesNotAdmitMalformedNativeShape() throws {
    let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    let manifest = try OriginalFleetShowroomModels.validatedManifest(
      data, expectedSHA256: OriginalFleetShowroomModels.manifestSHA256)
    let entry = try #require(manifest.models.first)
    let asset = try Data(contentsOf: directory.appendingPathComponent(entry.file))
    let parsed = try JSONSerialization.jsonObject(with: asset)
    var object = try #require(parsed as? [String: Any])
    var native = try #require(object["nativeDesign"] as? [String: Any])
    native["faces"] = [[0, 1, Int.max]]
    object["nativeDesign"] = native
    let malformed = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let matching = OriginalFleetShowroomModels.Entry(
      id: entry.id, file: entry.file, bytes: malformed.count, sha256: digest(malformed),
      sourcePath: entry.sourcePath, sourceSHA256: entry.sourceSHA256)
    #expect(throws: OriginalFleetShowroomModels.Failure.invalidAsset) {
      try OriginalFleetShowroomModels.decode(malformed, entry: matching)
    }
  }
}
