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
  var hasOriginalTextureFields: Bool { textures != nil || faceTextures != nil }

  var originalAppearanceValid: Bool {
    guard hasOriginalTextureFields else { return true }
    guard (sourceTextures ?? []).isEmpty, (sourceFaceTextures ?? []).isEmpty,
      (resolvedTextures ?? []).isEmpty, let references = textures, let mappings = faceTextures,
      Set(references.map(\.asset)).count == references.count,
      references.allSatisfy(OriginalShipTextureAssets.accepts)
    else { return false }
    if mappings.isEmpty { return references.isEmpty }
    guard mappings.count == faces.count else { return false }
    return zip(faces, mappings).allSatisfy { face, mapping in
      if mapping.texture == -1 {
        return mapping.uv.isEmpty
          || (mapping.uv.count == face.count
            && mapping.uv.allSatisfy { $0.count == 2 && $0.allSatisfy(\.isFinite) })
      }
      return references.indices.contains(mapping.texture) && mapping.uv.count == face.count
        && mapping.uv.allSatisfy { $0.count == 2 && $0.allSatisfy(\.isFinite) }
    }
  }

  var sourceAppearanceValid: Bool {
    if let colours = sourceFaceColours,
      colours.count != faces.count
        || !colours.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) })
    {
      return false
    }
    let textures = sourceTextures ?? []
    let mappings = sourceFaceTextures ?? []
    let resolved = resolvedTextures ?? []
    guard resolved.count <= textures.count,
      Set(resolved.map(\.sourceTexture)).count == resolved.count,
      resolved.allSatisfy({
        textures.indices.contains($0.sourceTexture)
          && textures[$0.sourceTexture].source.contains("sha256=" + $0.modelSHA256)
          && ShipTextureAssets.accepts($0)
      })
    else { return false }
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

  var resolvedFaceTextures: [ShipMeshTexture?] {
    if hasOriginalTextureFields {
      guard originalAppearanceValid, let references = textures, let mappings = faceTextures
      else { return [] }
      return mappings.map { mapping in
        guard mapping.texture != -1 else { return nil }
        return ShipMeshTexture(asset: references[mapping.texture].asset, uv: mapping.uv)
      }
    }
    guard let resolvedTextures, !resolvedTextures.isEmpty, let mappings = sourceFaceTextures else {
      return []
    }
    let assets = Dictionary(
      uniqueKeysWithValues: resolvedTextures.map { ($0.sourceTexture, $0.asset) })
    return mappings.map { mapping in
      guard let asset = assets[mapping.texture] else { return nil }
      return .init(asset: asset, uv: mapping.uv)
    }
  }
}
