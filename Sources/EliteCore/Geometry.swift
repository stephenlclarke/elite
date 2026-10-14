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
  public func rotated(pitch: Double, roll: Double, yaw: Double = 0) -> Vector3 {
    let py = y * cos(pitch) - z * sin(pitch)
    let pz = y * sin(pitch) + z * cos(pitch)
    let yx = x * cos(yaw) - pz * sin(yaw)
    let yz = x * sin(yaw) + pz * cos(yaw)
    return Vector3(yx * cos(roll) - py * sin(roll), yx * sin(roll) + py * cos(roll), yz)
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
  case cobra, viper, sidewinder, asteroid, station, missile, thargoid, cargo, constrictor, thargon
}

public struct MeshDetail: Codable, Sendable, Equatable {
  public let start: Int
  public let end: Int
  public let face: Int
}

public struct Mesh: Sendable {
  public let vertices: [Vector3]
  public let faces: [[Int]]
  public let details: [MeshDetail]
  public init(
    vertices: [Vector3], faces: [[Int]], details: [MeshDetail] = [], preserveWinding: Bool = false
  ) {
    self.vertices = vertices
    self.details = details
    let center = vertices.reduce(Vector3(0, 0, 0), +) * (1 / Double(vertices.count))
    if preserveWinding {
      self.faces = faces
      return
    }
    // A consistent outward winding is essential to preserve silhouette edges.
    self.faces = faces.map { face in
      let a = vertices[face[0]]
      let b = vertices[face[1]]
      let c = vertices[face[2]]
      let faceCenter =
        face.reduce(Vector3(0, 0, 0)) { $0 + vertices[$1] } * (1 / Double(face.count))
      return (b - a).cross(c - a).dot(faceCenter - center) < 0 ? Array(face.reversed()) : face
    }
  }
  public static func hull(_ kind: Hull) -> Mesh {
    if let mesh = ShipCatalogue.nativeMesh(kind) { return mesh }
    switch kind {
    case .asteroid, .cargo:
      return Mesh(
        vertices: [
          .init(0, 48, 0), .init(-45, 0, 0), .init(0, 0, -45), .init(45, 0, 0), .init(0, 0, 45),
          .init(0, -40, 0),
        ],
        faces: [
          [0, 2, 1], [0, 3, 2], [0, 4, 3], [0, 1, 4], [5, 1, 2], [5, 2, 3], [5, 3, 4], [5, 4, 1],
        ])
    case .missile:
      let width = 8.0
      return Mesh(
        vertices: [
          .init(-width, 0, -25), .init(width, 0, -25), .init(30, 12, 30),
          .init(-30, 12, 30), .init(0, -18, -20), .init(22, -10, 30), .init(-22, -10, 30),
        ],
        // The wing sides bend along 0-6 and 1-5. Treating either pair of
        // triangles as a flat quad incorrectly culls its visible outer edges.
        faces: [
          [0, 3, 2, 1], [0, 4, 6], [0, 6, 3], [1, 2, 5], [1, 5, 4],
          [0, 1, 4], [3, 6, 5, 2], [4, 5, 6],
        ])
    default: preconditionFailure("Missing native ship definition: " + kind.rawValue)
    }
  }

}

public struct SpaceBody: Sendable, Equatable, Codable, Identifiable {
  public var id: Int
  public var hull: Hull
  public var position: Vector3
  public var rotation: Double = 0
  public var orientation = Basis3()
  public var rotationRate: Double = 0.5
  public var energy: Double = 100
  public var hostile: Bool = false
  public var navalTarget = false
  public var missiles = 0
  public var playerMissileTarget: Int?
  public var enemyMissile = false
  public var missileSourceID: Int?
  public var destroyedByPlayer: Bool?
  public var missionActorID: UUID?
  public var missionInstanceID: UUID?
  public var blackjackIdentity: UUID?
  public var blackjackRole: BlackjackTarget?
  public var blackjackLaserCooldown: Double?
  public var ecmEnabled = false
  public init(id: Int, hull: Hull, position: Vector3, hostile: Bool = false) {
    self.id = id
    self.hull = hull
    self.rotationRate = hull == .station ? 0.3 : 0.5
    self.position = position
    self.hostile = hostile
    self.energy = hull.navalEnergy ?? 100
    self.missiles = hull.navalMissiles
    self.ecmEnabled = hull.hasECM
  }
}
