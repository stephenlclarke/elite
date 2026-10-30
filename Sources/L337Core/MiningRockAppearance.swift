import Foundation

/// Body materials are independent of orange mineable HUD and world-glow classification.
enum MiningRockAppearance {
  static func ink(for rock: MiningRock) -> Ink? {
    AsteroidBeltDefinition.chunk(for: rock.identity)?.content.ink
  }
  static func materials(for rock: MiningRock, mesh: Mesh) -> Mesh {
    guard let chunk = AsteroidBeltDefinition.chunk(for: rock.identity) else { return mesh }
    return Mesh(
      vertices: mesh.vertices, faces: mesh.faces, details: mesh.details,
      materials: [
        .init(name: chunk.content.rawValue, colour: chunk.content.colour, emissive: false)
      ],
      faceMaterials: Array(repeating: 0, count: mesh.faces.count),
      faceTextures: mesh.faceTextures, preserveWinding: true)
  }
}
