import Foundation

public struct PlanetIdentity: Sendable, Equatable, Hashable {
  public let galaxy: Int
  public let system: Int
  public let key: UInt64
  public init(galaxy: Int, system: StarSystem) {
    self.galaxy = galaxy
    self.system = system.id
    var value: UInt64 = 0xcbf2_9ce4_8422_2325
    // Stable FNV-1a word encoding; Swift Hasher and simulation randomness are excluded.
    for word in [galaxy, system.id, Int(system.seed.a), Int(system.seed.b), Int(system.seed.c)] {
      for shift in stride(from: 0, to: 32, by: 8) {
        value = (value ^ UInt64((word >> shift) & 255)) &* 0x100_0000_01b3
      }
    }
    key = value
  }
}

public struct PlanetPreview: Sendable, Equatable {
  public let identity: PlanetIdentity
  public let appearance: PlanetPalette
  public let lighting: PlanetLighting
  public let night: PlanetNightProfile
  public let bounds: CanvasRect
  public let angle: Double
  public init(
    galaxy: Int, system: StarSystem, bounds: CanvasRect, time: Double,
    lighting: PlanetLighting = .presentation
  ) {
    identity = .init(galaxy: galaxy, system: system)
    appearance = PlanetPalette(identity: identity, economy: system.economy)
    self.lighting = lighting
    night = PlanetNightProfile(system: system)
    self.bounds = bounds
    angle = time * 0.025
  }
}

/// Economy selects art direction; identity supplies small, stable local variation.
public struct PlanetPalette: Sendable, Equatable {
  public let economy: Int
  public let profile: PlanetAppearanceProfile
  public let ocean: Vector3
  public let land: Vector3
  public let ice: Double
  public let seaLevel: Double

  public init(identity: PlanetIdentity, economy: Int = 5) {
    self.economy = max(0, min(7, economy))
    profile = PlanetAppearanceProfile.forEconomy(self.economy)
    let brightness = 0.95 + Double((identity.key >> 16) & 255) / 255 * 0.10
    ocean = profile.ocean * brightness
    land = profile.land * brightness
    ice = profile.ice + (Double((identity.key >> 24) & 255) / 255 - 0.5) * 0.03
    seaLevel = profile.seaLevel + (Double((identity.key >> 8) & 255) / 255 - 0.5) * 0.035
  }
}

/// Immutable spherical texture, generated once per inspected identity by the presentation cache.
public struct PlanetTerrain: Sendable, Equatable {
  public static let width = 256
  public static let height = 128
  public let elevation: [Float]
  public let clouds: [Float]
  public init(identity: PlanetIdentity) {
    var elevation = [Float]()
    var clouds = [Float]()
    elevation.reserveCapacity(Self.width * Self.height)
    clouds.reserveCapacity(Self.width * Self.height)
    for row in 0..<Self.height {
      let latitude = (.pi / 2) - Double(row) / Double(Self.height - 1) * .pi
      for column in 0..<Self.width {
        let longitude = Double(column) / Double(Self.width) * 2 * .pi - .pi
        let point = Vector3(
          cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))
        let shape =
          Self.noise(point * 2.3, seed: identity.key) * 0.62
          + Self.noise(point * 5.7, seed: identity.key &+ 1) * 0.25
          + Self.noise(point * 13, seed: identity.key &+ 2) * 0.13
        let cloud =
          Self.noise(point * 5, seed: identity.key &+ 101) * 0.7
          + Self.noise(point * 17, seed: identity.key &+ 102) * 0.3
        elevation.append(Float(shape))
        clouds.append(Float(cloud))
      }
    }
    self.elevation = elevation
    self.clouds = clouds
  }
  public func sample(_ values: [Float], longitude: Double, latitude: Double) -> Double {
    var u = (longitude / (2 * .pi) + 0.5).truncatingRemainder(dividingBy: 1)
    if u < 0 { u += 1 }
    let x = u * Double(Self.width)
    let y = max(0, min(Double(Self.height - 1), (0.5 - latitude / .pi) * Double(Self.height - 1)))
    let ix = Int(x)
    let iy = Int(y)
    let nextX = (ix + 1) % Self.width
    let nextY = min(iy + 1, Self.height - 1)
    let top = Self.mix(
      Double(values[iy * Self.width + ix]), Double(values[iy * Self.width + nextX]), x - Double(ix))
    let bottom = Self.mix(
      Double(values[nextY * Self.width + ix]), Double(values[nextY * Self.width + nextX]),
      x - Double(ix))
    return Self.mix(top, bottom, y - Double(iy))
  }
  private static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
  static func noise(_ p: Vector3, seed: UInt64) -> Double {
    let x = Int(floor(p.x))
    let y = Int(floor(p.y))
    let z = Int(floor(p.z))
    func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    let u = smooth(p.x - Double(x))
    let v = smooth(p.y - Double(y))
    let w = smooth(p.z - Double(z))
    func layer(_ dz: Int) -> Double {
      let a = mix(lattice(x, y, z + dz, seed), lattice(x + 1, y, z + dz, seed), u)
      let b = mix(lattice(x, y + 1, z + dz, seed), lattice(x + 1, y + 1, z + dz, seed), u)
      return mix(a, b, v)
    }
    return mix(layer(0), layer(1), w)
  }
  private static func lattice(_ x: Int, _ y: Int, _ z: Int, _ seed: UInt64) -> Double {
    var n = seed ^ (UInt64(bitPattern: Int64(x)) &* 0x9e37_79b1)
    n ^= UInt64(bitPattern: Int64(y)) &* 0x85eb_ca77
    n ^= UInt64(bitPattern: Int64(z)) &* 0xc2b2_ae3d
    n = (n ^ (n >> 30)) &* 0xbf58_476d_1ce4_e5b9
    n = (n ^ (n >> 27)) &* 0x94d0_49bb_1331_11eb
    return Double((n ^ (n >> 31)) & 0xffff) / 65535
  }
}
