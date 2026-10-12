import Foundation

public struct Vector3: Sendable, Equatable, Codable {
  public var x: Double
  public var y: Double
  public var z: Double
  public init(_ x: Double, _ y: Double, _ z: Double) {
    self.x = x
    self.y = y
    self.z = z
  }
  public func rotated(pitch: Double, roll: Double) -> Vector3 {
    let py = y * cos(pitch) - z * sin(pitch)
    let pz = y * sin(pitch) + z * cos(pitch)
    return Vector3(x * cos(roll) - py * sin(roll), x * sin(roll) + py * cos(roll), pz)
  }
  public var length: Double { sqrt(x * x + y * y + z * z) }
  public static func + (lhs: Self, rhs: Self) -> Self {
    .init(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
  }
  public static func - (lhs: Self, rhs: Self) -> Self {
    .init(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
  }
  public static func * (lhs: Self, rhs: Double) -> Self {
    .init(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
  }
  public func dot(_ other: Self) -> Double { x * other.x + y * other.y + z * other.z }
  public func cross(_ other: Self) -> Self {
    .init(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
  }
}

public enum Hull: String, Sendable, Codable, CaseIterable {
  case cobra, viper, sidewinder, asteroid, station, missile, thargoid, cargo
}

public struct Mesh: Sendable {
  public let vertices: [Vector3]
  public let faces: [[Int]]
  public static func hull(_ kind: Hull) -> Mesh {
    switch kind {
    case .station:
      return Mesh(
        vertices: [
          .init(-90, -90, -90), .init(90, -90, -90), .init(90, 90, -90), .init(-90, 90, -90),
          .init(-90, -90, 90), .init(90, -90, 90), .init(90, 90, 90), .init(-90, 90, 90),
        ],
        faces: [
          [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
        ])
    case .asteroid, .cargo:
      return Mesh(
        vertices: [
          .init(0, 48, 0), .init(-45, 0, 0), .init(0, 0, -45), .init(45, 0, 0), .init(0, 0, 45),
          .init(0, -40, 0),
        ],
        faces: [
          [0, 2, 1], [0, 3, 2], [0, 4, 3], [0, 1, 4], [5, 1, 2], [5, 2, 3], [5, 3, 4], [5, 4, 1],
        ])
    case .thargoid:
      let top = (0..<8).map { i in
        Vector3(cos(Double(i) * .pi / 4) * 70, 15, sin(Double(i) * .pi / 4) * 70)
      }
      let bottom = (0..<8).map { i in
        Vector3(cos(Double(i) * .pi / 4) * 40, -15, sin(Double(i) * .pi / 4) * 40)
      }
      return Mesh(
        vertices: top + bottom,
        faces: [Array((0..<8).reversed()), Array(8..<16)]
          + (0..<8).map { [$0, ($0 + 1) % 8, ($0 + 1) % 8 + 8, $0 + 8] })
    case .cobra, .viper, .sidewinder, .missile:
      let standardWidth: Double = kind == .cobra ? 64 : 40
      let width: Double = kind == .missile ? 8 : standardWidth
      return Mesh(
        vertices: [
          .init(-width, 0, -25), .init(width, 0, -25), .init(30, 12, 30),
          .init(-30, 12, 30), .init(0, -18, -20), .init(22, -10, 30), .init(-22, -10, 30),
        ],
        faces: [[0, 3, 2, 1], [0, 4, 6, 3], [1, 2, 5, 4], [0, 1, 4], [3, 6, 5, 2], [4, 5, 6]])
    }
  }
}

public struct SpaceBody: Sendable, Equatable, Codable, Identifiable {
  public let id: Int
  public var hull: Hull
  public var position: Vector3
  public var rotation: Double = 0
  public var energy: Double = 100
  public var hostile: Bool = false
  public init(id: Int, hull: Hull, position: Vector3, hostile: Bool = false) {
    self.id = id
    self.hull = hull
    self.position = position
    self.hostile = hostile
  }
}
