import Foundation

/// Archival source references do not imply bundled texture pixels or a rendered livery.
public struct ShipSourceTexture: Codable, Sendable, Equatable {
  public let name: String
  public let source: String
  public let license: String
}

public struct ShipSourceFaceTexture: Codable, Sendable, Equatable {
  public let texture: Int
  public let uv: [[Double]]
}

extension ShipDesign {
  var sourceAppearanceValid: Bool {
    if let colours = sourceFaceColours,
      colours.count != faces.count
        || !colours.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) })
    {
      return false
    }
    let textures = sourceTextures ?? []
    let mappings = sourceFaceTextures ?? []
    guard textures.allSatisfy({ !$0.name.isEmpty && !$0.source.isEmpty && !$0.license.isEmpty })
    else { return false }
    if mappings.isEmpty { return textures.isEmpty }
    guard mappings.count == faces.count else { return false }
    return zip(faces, mappings).allSatisfy { face, mapping in
      if mapping.texture == -1 { return mapping.uv.isEmpty }
      return textures.indices.contains(mapping.texture) && mapping.uv.count == face.count
        && mapping.uv.allSatisfy { $0.count == 2 && $0.allSatisfy(\.isFinite) }
    }
  }
}
