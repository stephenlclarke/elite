import CryptoKit
import Foundation

/// Authored native geometry for display only. No performance, fitting or collision authority.
public struct OriginalFleetShowroomModel: Sendable {
  public let id: String
  public let sourcePath: String
  public let sourceSHA256: String
  /// Absent when the author did not declare units; never inferred from dimensions.
  public let coordinateUnits: String?
  public let nativeDesign: ShipDesign

  /// Preserves authored coordinates and winding; callers own any display projection.
  public var displayMesh: Mesh { nativeDesign.rawMesh }
}

/// Read-only access to an isolated asset set; does not register ships in ShipCatalogue.
public enum OriginalFleetShowroomModels {
  public enum Failure: Error, Equatable, Sendable {
    case unavailable
    case invalidManifest
    case unknownID
    case invalidAsset
  }

  static let manifestSHA256 = "89b7cac43da1b883ec6c1ccc08c0f13426e46d8895b1ad350b7e1609f23c2064"
  static let deliveryIndexSHA256 =
    "3fbc5198639819f4bafbbe538c2af688dfe6a6564c92807f9fe54825115dedff"
  static let maximumAssetBytes = 8 * 1024 * 1024
  static let maximumManifestBytes = 262_144

  struct Entry: Decodable, Sendable {
    let id: String
    let file: String
    let bytes: Int
    let sha256: String
    let sourcePath: String
    let sourceSHA256: String
  }

  struct Manifest: Decodable, Sendable {
    let schemaVersion: Int
    let kind: String
    let deliveryIndexSHA256: String
    let models: [Entry]
  }

  private struct Document: Decodable {
    let id: String
    let sourcePath: String
    let sourceSHA256: String
    let coordinateUnits: String?
    let nativeDesign: ShipDesign
  }

  private struct Store: Sendable {
    let directory: URL
    let entries: [String: Entry]
  }

  private static let bundled: Result<Store, Failure> = {
    let bundle =
      Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("Elite_EliteCore.bundle"))
      } ?? Bundle.module
    guard
      let directory = bundle.url(forResource: "OriginalFleetShowroomModels", withExtension: nil),
      let data = boundedData(
        directory.appendingPathComponent("manifest.json"), maximum: maximumManifestBytes),
      let manifest = try? validatedManifest(data, expectedSHA256: manifestSHA256)
    else { return .failure(.unavailable) }
    return .success(
      Store(
        directory: directory,
        entries: Dictionary(uniqueKeysWithValues: manifest.models.map { ($0.id, $0) })))
  }()

  public static var ids: [String] {
    guard case .success(let store) = bundled else { return [] }
    return store.entries.keys.sorted()
  }

  /// Decodes one requested asset. No mutable global cache or eager full-fleet mesh load.
  public static func model(for id: String) throws -> OriginalFleetShowroomModel {
    let store = try bundled.get()
    guard let entry = store.entries[id] else { throw Failure.unknownID }
    guard
      let data = boundedData(
        store.directory.appendingPathComponent(entry.file), maximum: entry.bytes)
    else { throw Failure.invalidAsset }
    return try decode(data, entry: entry)
  }

  static func validatedManifest(_ data: Data, expectedSHA256: String) throws -> Manifest {
    guard data.count <= maximumManifestBytes, digest(data) == expectedSHA256,
      let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
      manifest.schemaVersion == 1, manifest.kind == "original-fleet-showroom-models",
      manifest.deliveryIndexSHA256 == deliveryIndexSHA256,
      manifest.models.count == 171
    else { throw Failure.invalidManifest }
    let expected = Set((1...171).map { String(format: "SH%03d", $0) })
    guard Set(manifest.models.map(\.id)) == expected,
      manifest.models.allSatisfy({
        $0.file == $0.id + ".json" && (1...maximumAssetBytes).contains($0.bytes)
          && validDigest($0.sha256) && validDigest($0.sourceSHA256) && !$0.sourcePath.isEmpty
      }), manifest.models.reduce(0, { $0 + $1.bytes }) <= 128 * 1024 * 1024
    else { throw Failure.invalidManifest }
    return manifest
  }

  static func decode(_ data: Data, entry: Entry) throws -> OriginalFleetShowroomModel {
    guard data.count == entry.bytes, data.count <= maximumAssetBytes, digest(data) == entry.sha256,
      let document = try? JSONDecoder().decode(Document.self, from: data),
      document.id == entry.id, document.sourcePath == entry.sourcePath,
      document.sourceSHA256 == entry.sourceSHA256, document.nativeDesign.valid,
      document.coordinateUnits.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        ?? true
    else { throw Failure.invalidAsset }
    return OriginalFleetShowroomModel(
      id: document.id, sourcePath: document.sourcePath, sourceSHA256: document.sourceSHA256,
      coordinateUnits: document.coordinateUnits, nativeDesign: document.nativeDesign)
  }

  private static func validDigest(_ value: String) -> Bool {
    value.utf8.count == 64
      && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }

  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func boundedData(_ url: URL, maximum: Int) -> Data? {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
      values.isRegularFile == true, values.isSymbolicLink != true,
      let handle = try? FileHandle(forReadingFrom: url)
    else { return nil }
    defer { try? handle.close() }
    guard let data = try? handle.read(upToCount: maximum + 1), data.count <= maximum else {
      return nil
    }
    return data
  }
}
