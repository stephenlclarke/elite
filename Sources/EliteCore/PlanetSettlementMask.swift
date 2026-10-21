import Foundation

/// Government changes brightness, not the locations of original settlements.
public struct PlanetSettlementKey: Sendable, Equatable {
  public let identity: PlanetIdentity
  public let seaLevel: Double
  public let ice: Double
  public let coverage: Double

  public init(identity: PlanetIdentity, palette: PlanetPalette, night: PlanetNightProfile) {
    self.identity = identity
    seaLevel = palette.seaLevel
    ice = palette.ice
    coverage = night.settlementCoverage
  }
}

/// Immutable land emission and its local scatter. Generated only on a bounded cache miss.
public struct PlanetSettlementMask: Sendable, Equatable {
  public let key: PlanetSettlementKey?
  public let emission: [Float]
  public let scatter: [Float]

  public static let empty = Self(
    key: nil, emission: [Float](repeating: 0, count: PlanetTerrain.width * PlanetTerrain.height),
    scatter: [Float](repeating: 0, count: PlanetTerrain.width * PlanetTerrain.height))

  private init(key: PlanetSettlementKey?, emission: [Float], scatter: [Float]) {
    self.key = key
    self.emission = emission
    self.scatter = scatter
  }

  public init(key: PlanetSettlementKey, terrain: PlanetTerrain) {
    self.key = key
    let width = PlanetTerrain.width
    let height = PlanetTerrain.height
    var emission = [Float](repeating: 0, count: width * height)
    if terrain.elevation.count == emission.count, key.coverage > 0 {
      for row in 0..<height {
        let latitude = .pi / 2 - Double(row) / Double(height - 1) * .pi
        for column in 0..<width {
          let index = row * width + column
          let elevation = Double(terrain.elevation[index])
          let polar = abs(sin(latitude))
          guard elevation > key.seaLevel + 0.008, elevation < 0.82, polar < key.ice - 0.03 else {
            continue
          }
          let longitude = Double(column) / Double(width) * 2 * .pi - .pi
          let point = Vector3(
            cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))
          let broad = PlanetTerrain.noise(point * 7, seed: key.identity.key &+ 301)
          let fine = PlanetTerrain.noise(point * 55, seed: key.identity.key &+ 302)
          let route = PlanetTerrain.noise(point * 25, seed: key.identity.key &+ 303)
          let cluster = Self.smooth(0.72 - key.coverage * 0.4, 0.91 - key.coverage * 0.3, broad)
          let city = Self.smooth(0.62 - key.coverage * 0.08, 0.88, fine) * cluster
          let corridor = pow(max(0, 1 - abs(route - 0.5) * 18), 3) * cluster * 0.16
          let coast = 1 - Self.smooth(key.seaLevel + 0.035, key.seaLevel + 0.11, elevation)
          let land =
            Self.smooth(key.seaLevel + 0.008, key.seaLevel + 0.03, elevation)
            * (1 - Self.smooth(0.70, 0.82, elevation))
            * (1 - Self.smooth(key.ice - 0.08, key.ice - 0.03, polar))
          emission[index] = Float(min(1, (city + corridor) * (0.55 + coast * 0.45) * land))
        }
      }
    }
    self.emission = emission
    var scatter = [Float](repeating: 0, count: emission.count)
    for row in 0..<height {
      for column in 0..<width {
        var total: Float = 0
        // Wrap longitude, clamp polar rows; no per-frame blur or random sampling.
        for dy in -1...1 {
          for dx in -1...1 {
            let x = (column + dx + width) % width
            let y = max(0, min(height - 1, row + dy))
            total += emission[y * width + x]
          }
        }
        scatter[row * width + column] = total / 9
      }
    }
    self.scatter = scatter
  }

  private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
    let t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)
  }
}
