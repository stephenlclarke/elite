import Foundation

/// Directions use displayed sphere normals: x right, y up, z towards the observer.
public struct PlanetLighting: Sendable, Equatable {
  public let direction: Vector3
  public let strength: Double

  private init(direction: Vector3, strength: Double) {
    self.direction = direction
    self.strength = strength
  }

  /// Stable, explicitly presentation-only lighting for charts and data previews.
  public static let presentation = sun(direction: .init(-0.52, 0.35, 0.78))
  public static let unlit = Self(direction: .init(0, 0, 0), strength: 0)

  public static func sun(direction: Vector3) -> Self {
    guard direction.finite, direction.length.isFinite, direction.length > 1e-9 else {
      return .unlit
    }
    return .init(direction: direction.unit, strength: 1)
  }

  /// Supply both positions AFTER the same front/rear/side camera transform.
  /// The front of a displayed sphere points towards the camera, opposite positive view depth.
  public static func flight(viewPlanet: Vector3, viewSun: Vector3) -> Self {
    guard viewPlanet.finite, viewSun.finite, viewPlanet.length.isFinite, viewSun.length.isFinite
    else { return .unlit }
    let light = viewSun - viewPlanet
    guard light.length.isFinite, light.length > 1e-9 else { return .unlit }
    let towards = viewPlanet.length > 1e-9 ? (viewPlanet * -1).unit : Vector3(0, 0, -1)
    var right = Vector3(1, 0, 0) - towards * towards.x
    if right.length < 1e-9 { right = towards.cross(.init(0, 1, 0)) }
    right = right.unit
    let up = right.cross(towards).unit
    let direction = light.unit
    return sun(direction: .init(direction.dot(right), direction.dot(up), direction.dot(towards)))
  }
}

/// Fictional settlement art direction, independent of daytime colour and hostility policy.
public struct PlanetNightProfile: Sendable, Equatable {
  public let economy: Int
  public let technology: Int
  public let government: Int
  public let settlementCoverage: Double
  public let emissionIntensity: Double
  public let smogScatter: Double
  public let colour: Vector3

  public static let uninhabited = Self(economy: 7, technology: 0, government: 0, inhabited: false)

  public init(system: StarSystem) {
    self.init(economy: system.economy, technology: system.technology, government: system.government)
  }

  public init(economy: Int, technology: Int, government: Int) {
    self.init(economy: economy, technology: technology, government: government, inhabited: true)
  }

  /// Direct city light is cloud-attenuated; only nearby settlements supply smog scatter.
  public func emission(cities: Double, scatter: Double, cloudOpacity: Double, darkness: Double)
    -> Vector3
  {
    let light =
      cities * (1 - cloudOpacity * 0.85)
      + scatter * smogScatter * (0.15 + cloudOpacity * 0.85)
    return colour * (light * emissionIntensity * darkness)
  }

  private init(economy: Int, technology: Int, government: Int, inhabited: Bool) {
    self.economy = max(0, min(7, economy))
    self.technology = max(0, min(15, technology))
    self.government = max(0, min(7, government))
    let development = Double(self.technology) / 15
    let coverage = [0.64, 0.55, 0.48, 0.34, 0.12, 0.07, 0.05, 0.035][self.economy]
    let intensity = [0.85, 0.74, 0.65, 0.50, 0.20, 0.12, 0.09, 0.07][self.economy]
    // These are bounded visual coefficients, not real-world government claims or hostility rates.
    let order = [0.08, 0.22, 0.36, 0.45, 0.56, 0.70, 0.86, 1.0][self.government]
    settlementCoverage = inhabited ? coverage * (0.55 + 0.45 * development) : 0
    emissionIntensity = inhabited ? intensity * (0.40 + 0.90 * development) * order : 0
    smogScatter = [0.26, 0.23, 0.28, 0.18, 0.07, 0.04, 0.035, 0.025][self.economy]
    colour = .init(1.0, 0.63, 0.27)
  }
}
