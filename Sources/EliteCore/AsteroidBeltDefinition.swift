import Foundation

/// Project-authored ore colours; quantities retain each commodity's native market unit.
public enum AsteroidContent: String, CaseIterable, Sendable {
  case minerals, alloys, gold, platinum
  public var commodity: CommodityIdentity {
    switch self {
    case .minerals: .minerals
    case .alloys: .alloys
    case .gold: .gold
    case .platinum: .platinum
    }
  }
  public var ink: Ink {
    switch self {
    case .minerals: .white
    case .alloys: .blue
    case .gold: .gold
    case .platinum: .cyan
    }
  }
  public var colour: UInt32 { self == .minerals ? 0x9caa_b5ff : ink.rawValue }
}

public struct AsteroidChunk: Equatable, Sendable {
  public let units: Int
  public let content: AsteroidContent
  /// Volume scales with units; these are native collision coordinates, not metres.
  public var radius: Double { 18 * pow(Double(units), 1.0 / 3.0) }
  public var energy: Double { 100 * pow(Double(units), 1.0 / 3.0) }
}

/// One authority for chart presence, flight identity, ore quantity and appearance.
public enum AsteroidBeltDefinition {
  public static let chunkUnits = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
  public static let radialHalfWidth = 35.0
  public static func seed(for system: StarSystem) -> UInt64 {
    UInt64(system.seed.a) << 32 | UInt64(system.seed.b) << 16 | UInt64(system.seed.c)
  }
  public static func isPresent(
    system: StarSystem, galaxy: Int, policy: AsteroidBeltPresencePolicy = .economyWeighted
  ) -> Bool {
    let identity = SystemIdentity(galaxy: galaxy, system: system.id)
    guard (0..<8).contains(identity.galaxy), (0...256).contains(identity.system) else {
      return false
    }
    switch policy {
    case .legacyUniform: return isPresent(identity: identity, seed: seed(for: system))
    case .economyWeighted:
      // Lave remains an authored starting mining destination in each galaxy.
      return identity.system == 7
        || mixed(identity: identity, salt: seed(for: system)) % 100
          < UInt64(policy.probabilityPercent(economy: system.economy))
    }
  }
  /// Compatibility authority for the original uniform-presence generation.
  public static func isPresent(identity: SystemIdentity, seed: UInt64) -> Bool {
    guard (0..<8).contains(identity.galaxy), (0...256).contains(identity.system) else {
      return false
    }
    // Lave is an authored starting mining destination; other systems have a 3/4 chance.
    return identity.system == 7 || mixed(identity: identity, salt: seed) % 4 != 0
  }
  public static func radius(anchors: SystemAnchors) -> Double? {
    let value = 2 * (anchors.planet.position - anchors.sun.position).length
    return value.isFinite && value > 0 ? value : nil
  }
  public static func chunk(for rock: RockIdentity) -> AsteroidChunk? {
    guard (0..<8).contains(rock.system.galaxy), (0...256).contains(rock.system.system),
      (4..<8).contains(rock.field), rock.rock < 12
    else { return nil }
    let index = Int(rock.field - 4) * 4 + Int(rock.rock)
    let roll =
      mixed(identity: rock.system, salt: UInt64(rock.field) << 32 | UInt64(rock.rock)) % 100
    let content: AsteroidContent =
      roll < 64 ? .minerals : roll < 89 ? .alloys : roll < 97 ? .gold : .platinum
    return .init(units: chunkUnits[index % chunkUnits.count], content: content)
  }
  static func mixed(identity: SystemIdentity, salt: UInt64) -> UInt64 {
    var value =
      salt ^ 0x4245_4c54_4f52_4531
      ^ UInt64(truncatingIfNeeded: identity.galaxy) &* 0x9e37_79b9_7f4a_7c15
      ^ UInt64(truncatingIfNeeded: identity.system) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    return value ^ (value >> 31)
  }
}
