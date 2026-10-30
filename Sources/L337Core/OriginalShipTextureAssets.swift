import CryptoKit
import Foundation

/// Current-original material identity; not an archival imported-model binding.
public struct OriginalShipTextureReference: Codable, Sendable, Equatable {
  public let asset: String
  public let license: String
  public let `repeat`: Bool

  public init(asset: String, license: String, `repeat`: Bool) {
    self.asset = asset
    self.license = license
    self.`repeat` = `repeat`
  }
}

/// Authenticated original diffuse pixels, loaded once and never transformed or premultiplied.
public enum OriginalShipTextureAssets {
  public static let allowedIDs: Set<String> = [
    "l337-patrol-diffuse", "l337-strike-diffuse", "l337-service-details",
  ]
  static let expectedManifestSHA256 =
    "96c4c9699b81f50be5a8aefeeca74a6e4870e0bb981d1cd33a9ff2921cd2bd3c"

  struct Manifest: Decodable {
    let version: Int
    let kind: String
    let assets: [Asset]
  }

  struct Asset: Decodable {
    let id: String
    let width: Int
    let height: Int
    let license: String
    let authorship: String
    let pngFile: String
    let rgbaFile: String
    let pngSHA256: String
    let rgbaSHA256: String
  }

  private static let pixels: [String: ShipTexturePixels] = {
    let bundle =
      Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
      } ?? Bundle.module
    guard let folder = bundle.url(forResource: "OriginalShipTextures", withExtension: nil),
      let manifest = boundedData(folder.appendingPathComponent("manifest.json"), maximum: 131_072)
    else { return [:] }
    return load(manifest: manifest, directory: folder)
  }()

  public static func pixels(for asset: String) -> ShipTexturePixels? {
    guard allowedIDs.contains(asset) else { return nil }
    return pixels[asset]
  }

  public static func preload() { _ = pixels }

  static func accepts(_ reference: OriginalShipTextureReference) -> Bool {
    // The current raster samples repeated UVs; clamped materials must not silently repeat.
    allowedIDs.contains(reference.asset) && reference.license == "MIT" && reference.`repeat`
  }

  static func load(manifest data: Data, directory: URL) -> [String: ShipTexturePixels] {
    guard data.count <= 131_072, digest(data) == expectedManifestSHA256,
      let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
      manifest.version == 1, manifest.kind == "current-original-ship-textures",
      manifest.assets.count == allowedIDs.count,
      Set(manifest.assets.map(\.id)) == allowedIDs
    else { return [:] }
    var result: [String: ShipTexturePixels] = [:]
    for asset in manifest.assets {
      guard asset.width == 1024, asset.height == 1024,
        asset.license == "MIT", !asset.authorship.isEmpty,
        asset.pngFile == asset.id + ".png", asset.rgbaFile == asset.id + ".rgba",
        let png = boundedData(
          directory.appendingPathComponent(asset.pngFile), maximum: 2_097_152),
        digest(png) == asset.pngSHA256,
        let rgba = boundedData(
          directory.appendingPathComponent(asset.rgbaFile), maximum: 4_194_304),
        rgba.count == 4_194_304, digest(rgba) == asset.rgbaSHA256
      else { return [:] }
      // A's bounded PNG decoder authenticated exact PNG/cache pixel agreement. Both byte
      // hashes are pinned by this manifest, so no second image decode is needed at runtime.
      let texels: [UInt32] = rgba.withUnsafeBytes { storage -> [UInt32] in
        let bytes = storage.bindMemory(to: UInt8.self)
        var packed: [UInt32] = []
        packed.reserveCapacity(bytes.count / 4)
        for offset in stride(from: 0, to: bytes.count, by: 4) {
          let red: UInt32 = UInt32(bytes[offset]) << 24
          let green: UInt32 = UInt32(bytes[offset + 1]) << 16
          let blue: UInt32 = UInt32(bytes[offset + 2]) << 8
          let alpha: UInt32 = UInt32(bytes[offset + 3])
          packed.append(red | green | blue | alpha)
        }
        return packed
      }
      guard texels.allSatisfy({ $0 & 255 == 255 }),
        let image = ShipTexturePixels(width: asset.width, height: asset.height, pixels: texels)
      else { return [:] }
      result[asset.id] = image
    }
    return result
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

  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
