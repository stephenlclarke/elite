import Foundation

/// Presence changes only; rock geometry, identities and depletion namespaces stay stable.
public enum AsteroidBeltPresencePolicy: Sendable {
  case legacyUniform, economyWeighted

  public func probabilityPercent(economy: Int) -> Int {
    switch self {
    case .legacyUniform: 75
    case .economyWeighted:
      switch economy {
      case 0...2: 80
      case 3: 60
      case 4: 40
      case 5...7: 20
      default: 0
      }
    }
  }
}

/// A migration pin captures the original rule using the actual generated system.
/// Current absence is evidence too: it must survive the presence-policy transition.
public struct AsteroidPresencePin: Sendable, Equatable {
  public let system: SystemIdentity
  public let present: Bool

  public init(system: StarSystem, galaxy: Int) {
    self.system = .init(galaxy: galaxy, system: system.id)
    present = AsteroidBeltDefinition.isPresent(
      system: system, galaxy: galaxy, policy: .legacyUniform)
  }
}
