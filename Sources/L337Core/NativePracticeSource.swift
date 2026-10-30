import Foundation

enum NativePracticeLesson: String, Codable, Sendable {
  case gunnery = "l337.training/safe-gunnery"
  case defensiveFlight = "l337.training/defensive-flight"
}

/// Initial L337 authoring, supplied explicitly for T02.P01.provider; not Oric geometry.
enum NativePracticeSource {
  static let profile = "native-uncrewed-practice-beacons-v1"
  static let consentChoice = "begin-practice"
  static let consentGroup = "native-practice"
  static let offsets: [Vector3] = [
    .init(-120, 0, 1500), .init(0, 0, 1800), .init(120, 0, 2100),
  ]
  static let volumeOffset = Vector3(0, 0, 1800)
  static let volumeRadius = 650.0
  static let halfSide = 3.0
  static let radius = sqrt(27.0)
  static let energy = 100.0

  static func mesh(flashing: Bool = false) -> Mesh {
    .init(
      vertices: [
        .init(-3, -3, -3), .init(3, -3, -3), .init(3, 3, -3), .init(-3, 3, -3),
        .init(-3, -3, 3), .init(3, -3, 3), .init(3, 3, 3), .init(-3, 3, 3),
      ],
      faces: [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
        [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
      ],
      materials: [
        .init(
          name: "Uncrewed training beacon", colour: (flashing ? Ink.white : Ink.cyan).rawValue,
          emissive: true)
      ], faceMaterials: Array(repeating: 0, count: 6), preserveWinding: true)
  }

  static func targetIdentity(operation: UUID, ordinal: Int) -> UUID {
    ScriptIdentity.uuid("\(profile):\(operation):beacon:\(ordinal)")
  }

  static func properRotation(_ basis: Basis3) -> Bool {
    basis.validRotation && basis.x.cross(basis.y).dot(basis.z) > 0.9999
  }
}
