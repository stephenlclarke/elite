import Foundation

public struct SystemSeed: Sendable, Equatable, Codable {
  public var a: UInt16
  public var b: UInt16
  public var c: UInt16
  public mutating func twist() {
    let next = a &+ b &+ c
    a = b
    b = c
    c = next
  }
}

public struct StarSystem: Sendable, Equatable, Codable {
  public let id: Int
  public let name: String
  public let x: Double
  public let y: Double
  public let economy: Int
  public let government: Int
  public let technology: Int
  public let population: Int
  public let productivity: Int
  public let radius: Int
  public let seed: SystemSeed
  public var original: OriginalWorldRecord? = nil
  public var nativeGalaxy: Int = 0
  public var galaxy: Int { original?.galaxy ?? nativeGalaxy }
  public var hostileFraction: Double { original?.hostileFraction ?? Double(7 - government) / 7 }
  public var economyName: String {
    if let original { return original.economy }
    return [
      "Rich Industrial", "Average Industrial", "Poor Industrial", "Mainly Industrial",
      "Mainly Agricultural", "Rich Agricultural", "Average Agricultural", "Poor Agricultural",
    ][economy]
  }
  public var governmentName: String {
    if let original { return original.government }
    return [
      "Anarchy", "Feudal", "Multi-government", "Dictatorship", "Communist", "Confederacy",
      "Democracy", "Corporate State",
    ][government]
  }
  public func distance(to other: StarSystem) -> Double {
    guard galaxy == other.galaxy else { return .infinity }
    return hypot(x - other.x, y - other.y)
  }
}

public enum Universe {
  static let originalWorlds: OriginalWorldCatalogue = {
    do { return try OriginalWorldCatalogue.loadBundled() } catch {
      preconditionFailure("Invalid bundled original world catalogue: \(error)")
    }
  }()

  public static func originalWorld(galaxy: Int, system: Int) throws -> OriginalWorldRecord {
    try originalWorlds.world(galaxy: galaxy, system: system)
  }

  private static let galaxies: [[StarSystem]] = (0..<8).map { galaxy in
    originalWorlds.worlds.filter { $0.galaxy == galaxy }
      .sorted { $0.system < $1.system }.map(nativeSystem)
  }
  public static func galaxy(number: Int = 0) -> [StarSystem] {
    precondition((0..<8).contains(number), "Invalid galaxy")
    return galaxies[number]
  }

  static func nativeSystem(_ world: OriginalWorldRecord) -> StarSystem {
    // Stable native procedural identity comes from the original authoring seed and key.
    // Coordinates, economics and world identity are never recovered from BBC seed bytes.
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in (originalWorlds.authoring.seed + ":" + world.key).utf8 {
      hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
    }
    return .init(
      id: world.system, name: world.name, x: world.xLY, y: world.yLY,
      economy: world.economyID, government: world.governmentID, technology: world.technology,
      population: Int((world.populationBillions * 10).rounded()),
      productivity: Int((world.productivityBillionCR * 1000).rounded()), radius: world.radiusKM,
      seed: .init(
        a: UInt16(truncatingIfNeeded: hash),
        b: UInt16(truncatingIfNeeded: hash >> 16), c: UInt16(truncatingIfNeeded: hash >> 32)),
      original: world)
  }
}

public struct Commodity: Sendable, Equatable {
  public let name: String
  public let unit: String
  public let basePrice: Int
  public let baseQuantity: Int
  public static let all: [Commodity] = Universe.originalWorlds.authoring.commodities
    .sorted { $0.index < $1.index }.map {
      .init(
        name: $0.name, unit: $0.unit, basePrice: Int(($0.basePriceCR * 10).rounded()),
        baseQuantity: $0.targetStock)
    }
}

public struct MarketItem: Sendable, Equatable, Codable {
  public var price: Int  // Tenths of a credit, avoiding floating point accounting.
  public var quantity: Int
  public var bidPrice: Int
  public init(price: Int, quantity: Int, bidPrice: Int? = nil) {
    self.price = price
    self.quantity = quantity
    self.bidPrice = bidPrice ?? price
  }
  /// Authored manifest valuation for unknown cargo, not live stock at any station.
  static var authoredManifest: [MarketItem] {
    Commodity.all.map { .init(price: $0.basePrice, quantity: $0.baseQuantity) }
  }
}
