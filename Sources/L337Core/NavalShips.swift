/// Numerical blueprint data from the pinned BBC Second Processor source.
public struct NativeCombat: Codable, Sendable, Equatable {
  public let energy: Double
  public let bounty: Int
  public let speed: Double
  public let laserDamage: Double
  public let missiles: Int
  public let ecm: Bool
  public let bombImmune: Bool
  var valid: Bool {
    [energy, speed, laserDamage].allSatisfy { $0.isFinite && $0 > 0 && $0 <= 100000 }
      && (0...100000).contains(bounty) && (0...32).contains(missiles)
  }
}
extension Hull {
  private var nativeCombat: NativeCombat? { ShipCatalogue.nativeShip(self)?.nativeCombat }
  public var navalEnergy: Double? { nativeCombat?.energy }
  public var navalBounty: Int? { nativeCombat?.bounty }
  public var hasECM: Bool { nativeCombat?.ecm ?? false }
  public var bombImmune: Bool { self == .station || nativeCombat?.bombImmune == true }
  public var navalSpeed: Double? { nativeCombat?.speed }
  public var navalLaserDamage: Double? { nativeCombat?.laserDamage }
  public var navalMissiles: Int { nativeCombat?.missiles ?? 0 }
}

extension SpaceBody {
  var leavesLocalBubble: Bool {
    if hull == .constrictor {
      return max(abs(position.x), abs(position.y), abs(position.z)) >= 57600
    }
    return position.length > 40000
  }
}

enum NavalShips {
  static var constrictor: Mesh { Mesh.hull(.constrictor) }
  static var thargon: Mesh { Mesh.hull(.thargon) }
}
