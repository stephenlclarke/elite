import Foundation

/// Shared CPU/GPU art direction for the eight generated economy classes.
/// Weather changes coverage as well as colour; government has no visual input.
public struct PlanetAppearanceProfile: Sendable, Equatable {
  public let ocean: Vector3
  public let land: Vector3
  public let highland: Vector3
  public let vegetation: Vector3
  public let cloudColour: Vector3
  public let atmosphereColour: Vector3
  public let ice: Double
  public let seaLevel: Double
  public let cloudLow: Double
  public let cloudHigh: Double
  public let cloudOpacity: Double
  public let vegetationStrength: Double
  public let highlandStrength: Double
  public let surfaceHaze: Double
  public let atmosphereStrength: Double
  public let rimWidth: Double
  public let rimOpacity: Double

  public static func forEconomy(_ economy: Int) -> Self {
    profiles[max(0, min(7, economy))]
  }

  private static let profiles: [Self] = [
    // Rich Industrial
    .init(
      ocean: .init(0.08, 0.13, 0.17),
      land: .init(0.25, 0.27, 0.29),
      highland: .init(0.43, 0.42, 0.38),
      vegetation: .init(0.23, 0.3, 0.21),
      cloudColour: .init(0.53, 0.5, 0.44),
      atmosphereColour: .init(0.47, 0.39, 0.27),
      ice: 0.86,
      seaLevel: 0.48,
      cloudLow: 0.34,
      cloudHigh: 0.58,
      cloudOpacity: 0.9,
      vegetationStrength: 0.08,
      highlandStrength: 0.65,
      surfaceHaze: 0.15,
      atmosphereStrength: 0.52,
      rimWidth: 0.045,
      rimOpacity: 0.28
    ),
    // Average Industrial
    .init(
      ocean: .init(0.1, 0.17, 0.21),
      land: .init(0.37, 0.32, 0.27),
      highland: .init(0.53, 0.42, 0.31),
      vegetation: .init(0.25, 0.32, 0.22),
      cloudColour: .init(0.61, 0.58, 0.52),
      atmosphereColour: .init(0.48, 0.42, 0.32),
      ice: 0.88,
      seaLevel: 0.46,
      cloudLow: 0.36,
      cloudHigh: 0.62,
      cloudOpacity: 0.87,
      vegetationStrength: 0.1,
      highlandStrength: 0.65,
      surfaceHaze: 0.14,
      atmosphereStrength: 0.48,
      rimWidth: 0.04,
      rimOpacity: 0.27
    ),
    // Poor Industrial
    .init(
      ocean: .init(0.12, 0.18, 0.19),
      land: .init(0.29, 0.23, 0.19),
      highland: .init(0.5, 0.34, 0.22),
      vegetation: .init(0.26, 0.29, 0.19),
      cloudColour: .init(0.48, 0.45, 0.38),
      atmosphereColour: .init(0.43, 0.36, 0.24),
      ice: 0.92,
      seaLevel: 0.4,
      cloudLow: 0.3,
      cloudHigh: 0.58,
      cloudOpacity: 0.94,
      vegetationStrength: 0.06,
      highlandStrength: 0.7,
      surfaceHaze: 0.2,
      atmosphereStrength: 0.55,
      rimWidth: 0.048,
      rimOpacity: 0.29
    ),
    // Mainly Industrial
    .init(
      ocean: .init(0.06, 0.22, 0.37),
      land: .init(0.31, 0.42, 0.27),
      highland: .init(0.5, 0.44, 0.32),
      vegetation: .init(0.22, 0.48, 0.24),
      cloudColour: .init(0.67, 0.68, 0.63),
      atmosphereColour: .init(0.42, 0.46, 0.4),
      ice: 0.86,
      seaLevel: 0.5,
      cloudLow: 0.43,
      cloudHigh: 0.65,
      cloudOpacity: 0.76,
      vegetationStrength: 0.28,
      highlandStrength: 0.65,
      surfaceHaze: 0.09,
      atmosphereStrength: 0.43,
      rimWidth: 0.038,
      rimOpacity: 0.25
    ),
    // Mainly Agricultural
    .init(
      ocean: .init(0.03, 0.25, 0.52),
      land: .init(0.25, 0.48, 0.21),
      highland: .init(0.53, 0.47, 0.29),
      vegetation: .init(0.13, 0.6, 0.19),
      cloudColour: .init(0.9, 0.94, 0.98),
      atmosphereColour: .init(0.18, 0.46, 0.77),
      ice: 0.84,
      seaLevel: 0.52,
      cloudLow: 0.49,
      cloudHigh: 0.7,
      cloudOpacity: 0.65,
      vegetationStrength: 0.58,
      highlandStrength: 0.55,
      surfaceHaze: 0.035,
      atmosphereStrength: 0.37,
      rimWidth: 0.032,
      rimOpacity: 0.22
    ),
    // Rich Agricultural
    .init(
      ocean: .init(0.025, 0.26, 0.58),
      land: .init(0.16, 0.55, 0.16),
      highland: .init(0.42, 0.46, 0.22),
      vegetation: .init(0.07, 0.67, 0.13),
      cloudColour: .init(0.96, 0.98, 1),
      atmosphereColour: .init(0.16, 0.45, 0.83),
      ice: 0.88,
      seaLevel: 0.5,
      cloudLow: 0.53,
      cloudHigh: 0.72,
      cloudOpacity: 0.55,
      vegetationStrength: 0.75,
      highlandStrength: 0.48,
      surfaceHaze: 0.018,
      atmosphereStrength: 0.34,
      rimWidth: 0.029,
      rimOpacity: 0.2
    ),
    // Average Agricultural
    .init(
      ocean: .init(0.04, 0.26, 0.48),
      land: .init(0.31, 0.49, 0.22),
      highland: .init(0.55, 0.46, 0.27),
      vegetation: .init(0.15, 0.52, 0.15),
      cloudColour: .init(0.92, 0.95, 0.98),
      atmosphereColour: .init(0.19, 0.46, 0.76),
      ice: 0.86,
      seaLevel: 0.48,
      cloudLow: 0.5,
      cloudHigh: 0.7,
      cloudOpacity: 0.6,
      vegetationStrength: 0.55,
      highlandStrength: 0.55,
      surfaceHaze: 0.025,
      atmosphereStrength: 0.36,
      rimWidth: 0.031,
      rimOpacity: 0.21
    ),
    // Poor Agricultural
    .init(
      ocean: .init(0.09, 0.23, 0.39),
      land: .init(0.45, 0.43, 0.25),
      highland: .init(0.64, 0.47, 0.26),
      vegetation: .init(0.31, 0.47, 0.2),
      cloudColour: .init(0.9, 0.92, 0.94),
      atmosphereColour: .init(0.27, 0.43, 0.62),
      ice: 0.93,
      seaLevel: 0.39,
      cloudLow: 0.57,
      cloudHigh: 0.77,
      cloudOpacity: 0.45,
      vegetationStrength: 0.3,
      highlandStrength: 0.65,
      surfaceHaze: 0.03,
      atmosphereStrength: 0.35,
      rimWidth: 0.03,
      rimOpacity: 0.21
    ),
  ]
}
