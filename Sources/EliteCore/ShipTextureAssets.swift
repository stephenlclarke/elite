import CryptoKit
import Foundation

/// An explicit resolved material binding; archival DAT tokens and UVs stay unchanged.
public struct ShipResolvedTexture: Codable, Sendable, Equatable {
  public let sourceTexture: Int
  public let asset: String
  public let material: String
  public let definition: String
  public let modelSHA256: String
}

public struct ShipMeshTexture: Sendable, Equatable {
  public let asset: String
  public let uv: [[Double]]
}

/// The bundled cache contains opaque source RGB, prepared without treating specular alpha as opacity.
/// Validation and immutable pixel loading happen once, never once per face or simulation tick.
public enum ShipTextureAssets {
  struct Manifest: Decodable {
    let version: Int
    let archiveSHA256: String
    let assets: [Asset]
    let bindings: [Binding]
  }

  struct Asset: Decodable {
    let id: String
    let member: String
    let pngSHA256: String
    let rgbaSHA256: String
    let width: Int
    let height: Int
    let license: String
  }

  struct Binding: Decodable {
    let definition: String
    let modelSHA256: String
    let materials: [String]
    let assets: [String]
  }

  struct Catalogue: Sendable {
    let pixels: [String: ShipTexturePixels]
    let bindings: [ShipResolvedTexture]
  }

  private static let catalogue: Catalogue = {
    let bundle =
      Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("Elite_EliteCore.bundle"))
      } ?? Bundle.module
    guard let folder = bundle.url(forResource: "ShipTextures", withExtension: nil),
      let data = boundedData(folder.appendingPathComponent("manifest.json"), maximum: 32_768)
    else { return .init(pixels: [:], bindings: []) }
    return load(manifest: data, directory: folder)
  }()

  public static func pixels(for asset: String) -> ShipTexturePixels? {
    if asset.hasPrefix("l337-") { return OriginalShipTextureAssets.pixels(for: asset) }
    return catalogue.pixels[asset]
  }

  public static func preload() { _ = catalogue }

  static func accepts(_ binding: ShipResolvedTexture) -> Bool {
    expectedBindings.contains(binding)
  }

  private static let expectedBindings: [ShipResolvedTexture] = [
    .init(
      sourceTexture: 0, asset: "sunray-diffuse", material: "comray.png",
      definition: "sunray-player",
      modelSHA256: "ac6723c2e1b49e12a031f6c5deed687f52e86cbd63cfa72df2abad2028152936"),
    .init(
      sourceTexture: 1, asset: "ray-details", material: "commies_details.png",
      definition: "sunray-player",
      modelSHA256: "ac6723c2e1b49e12a031f6c5deed687f52e86cbd63cfa72df2abad2028152936"),
    .init(
      sourceTexture: 0, asset: "stingray-diffuse", material: "comrayii.png",
      definition: "commilray-player",
      modelSHA256: "a29d506bf62198fdacb220b6086f2bd2983134137802a4e1cac0f88442b0bd1c"),
    .init(
      sourceTexture: 1, asset: "ray-details", material: "commies_details.png",
      definition: "commilray-player",
      modelSHA256: "a29d506bf62198fdacb220b6086f2bd2983134137802a4e1cac0f88442b0bd1c"),
  ]

  static func load(manifest data: Data, directory: URL) -> Catalogue {
    guard data.count <= 32_768,
      digest(data) == "d6f8d3fe7e6a26f3a86a3a0977cfc9bb1d20a114803957380b70b9c9dd31eebd",
      let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
      manifest.version == 1,
      manifest.archiveSHA256 == "09d478852cf2485e3a1e8be2ebca9d8771ea13af08ac977010a7c07fb8a42e4a",
      manifest.assets.count == 3, manifest.bindings.count == 2,
      Set(manifest.assets.map(\.id)).count == 3
    else { return .init(pixels: [:], bindings: []) }
    var pixels: [String: ShipTexturePixels] = [:]
    for asset in manifest.assets {
      guard ["sunray-diffuse", "stingray-diffuse", "ray-details"].contains(asset.id),
        asset.license == "CC-BY-NC-SA-3.0", asset.member.hasPrefix("Textures/"),
        asset.width == 1024, asset.height == 1024,
        let png = boundedData(
          directory.appendingPathComponent(asset.id + ".png"), maximum: 2_097_152),
        digest(png) == asset.pngSHA256,
        let rgba = boundedData(
          directory.appendingPathComponent(asset.id + ".rgba"), maximum: 4_194_304),
        rgba.count == asset.width * asset.height * 4, digest(rgba) == asset.rgbaSHA256
      else { return .init(pixels: [:], bindings: []) }
      let texels: [UInt32] = rgba.withUnsafeBytes { storage -> [UInt32] in
        let bytes = storage.bindMemory(to: UInt8.self)
        var packed: [UInt32] = []
        packed.reserveCapacity(bytes.count / 4)
        for offset in stride(from: 0, to: bytes.count, by: 4) {
          let red: UInt32 = UInt32(bytes[offset]) << 24
          let green: UInt32 = UInt32(bytes[offset + 1]) << 16
          let blue: UInt32 = UInt32(bytes[offset + 2]) << 8
          let alpha: UInt32 = UInt32(255)
          packed.append(red | green | blue | alpha)
        }
        return packed
      }
      guard let image = ShipTexturePixels(width: asset.width, height: asset.height, pixels: texels)
      else { return .init(pixels: [:], bindings: []) }
      pixels[asset.id] = image
    }
    var bindings: [ShipResolvedTexture] = []
    for binding in manifest.bindings {
      guard binding.materials.count == 2, binding.assets.count == 2,
        binding.modelSHA256.count == 64,
        ["sunray-player", "commilray-player"].contains(binding.definition),
        binding.assets.allSatisfy({ pixels[$0] != nil })
      else { return .init(pixels: [:], bindings: []) }
      for index in binding.assets.indices {
        bindings.append(
          .init(
            sourceTexture: index, asset: binding.assets[index],
            material: binding.materials[index], definition: binding.definition,
            modelSHA256: binding.modelSHA256))
      }
    }
    guard bindings.count == expectedBindings.count,
      expectedBindings.allSatisfy({ bindings.contains($0) })
    else { return .init(pixels: [:], bindings: []) }
    return .init(pixels: pixels, bindings: bindings)
  }

  private static func boundedData(_ url: URL, maximum: Int) -> Data? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
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
