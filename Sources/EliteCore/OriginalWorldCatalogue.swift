import CryptoKit
import Foundation
import TOMLDecoder

public enum OriginalWorldCatalogueError: Error, Sendable, Equatable {
  case missingResource(String)
  case fingerprintMismatch(String)
  case invalidSchema(String)
  case invalidIdentity(galaxy: Int, system: Int)
  case unknownKey(String)
  case crossGalaxy(source: Int, destination: Int)
}

/// The single authenticated authority for ordinary live worlds and their complete authored data.
public struct OriginalWorldCatalogue: Sendable {
  public let version: String
  public let worlds: [OriginalWorldRecord]
  public let authoring: OriginalWorldAuthoring
  public let provenance: OriginalWorldProvenance
  private let byKey: [String: OriginalWorldRecord]
  private let byGalaxy: [[OriginalWorldRecord]]

  public static let approvedFingerprints = [
    "catalogue.json": "120543eedc02a705cce0e37d026125bf926ec22651cff9337ca5d943f2ffd99d",
    "authoring.toml": "47d83caae5a9b22a4a932f19c55f79c5cb5435b962826a0969ece096b11f80eb",
    "PROVENANCE.json": "544f77f4b7c285fadbbbcefd9fdefa258272fe1097a6658909ac2793e6c2de6d",
  ]

  private static let bundled: Result<Self, Error> = Result {
    try load(from: resourceDirectory())
  }

  public static func loadBundled() throws -> Self { try bundled.get() }

  static func resourceDirectory() throws -> URL {
    guard let root = resources.resourceURL else {
      throw OriginalWorldCatalogueError.missingResource("OriginalWorlds")
    }
    return root.appendingPathComponent("OriginalWorlds", isDirectory: true)
  }

  /// The same exact-byte gate applies to app bundles and source-resource verification.
  static func load(from directory: URL) throws -> Self {
    var bytes: [String: Data] = [:]
    for (name, expected) in approvedFingerprints {
      let url = directory.appendingPathComponent(name)
      guard let data = try? Data(contentsOf: url) else {
        throw OriginalWorldCatalogueError.missingResource(name)
      }
      guard fingerprint(data) == expected else {
        throw OriginalWorldCatalogueError.fingerprintMismatch(name)
      }
      bytes[name] = data
    }
    guard let catalogue = bytes["catalogue.json"], let authoring = bytes["authoring.toml"],
      let provenance = bytes["PROVENANCE.json"]
    else {
      throw OriginalWorldCatalogueError.invalidSchema("Resource inventory")
    }
    return try decode(catalogue: catalogue, authoring: authoring, provenance: provenance)
  }

  public func world(key: String) throws -> OriginalWorldRecord {
    guard let world = byKey[key] else { throw OriginalWorldCatalogueError.unknownKey(key) }
    return world
  }

  public func world(galaxy: Int, system: Int) throws -> OriginalWorldRecord {
    guard (0..<8).contains(galaxy), (0..<256).contains(system) else {
      throw OriginalWorldCatalogueError.invalidIdentity(galaxy: galaxy, system: system)
    }
    return byGalaxy[galaxy][system]
  }

  public func galaxyName(_ galaxy: Int) throws -> String {
    guard authoring.galaxies.indices.contains(galaxy) else {
      throw OriginalWorldCatalogueError.invalidIdentity(galaxy: galaxy, system: 0)
    }
    return authoring.galaxies[galaxy].name
  }

  /// Coordinates already are Cartesian light-years: no anisotropic conversion or rounding.
  public func distanceLY(from sourceKey: String, to destinationKey: String) throws -> Double {
    let source = try world(key: sourceKey)
    let destination = try world(key: destinationKey)
    guard source.galaxy == destination.galaxy else {
      throw OriginalWorldCatalogueError.crossGalaxy(
        source: source.galaxy, destination: destination.galaxy)
    }
    return hypot(source.xLY - destination.xLY, source.yLY - destination.yLY)
  }

  // Internal decoding permits focused malformed-schema tests; bundled callers always pass the
  // exact approved hash gate above. There is no old-data fallback on any error.
  static func decode(catalogue: Data, authoring: Data, provenance: Data) throws -> Self {
    try validateFieldInventory(catalogue)
    let document = try JSONDecoder().decode(Document.self, from: catalogue)
    let config = try TOMLDecoder().decode(OriginalWorldAuthoring.self, from: authoring)
    let origin = try JSONDecoder().decode(OriginalWorldProvenance.self, from: provenance)
    try validate(config: config, provenance: origin)
    try validateEconomyAuthoring(config)
    guard document.version == config.version, document.systems.count == 2048 else {
      throw OriginalWorldCatalogueError.invalidSchema("Version or world count")
    }
    var keys = Set<String>()
    var names = Set<String>()
    var galaxies = Array(repeating: [OriginalWorldRecord](), count: 8)
    for world in document.systems {
      guard (0..<8).contains(world.galaxy) else {
        throw OriginalWorldCatalogueError.invalidIdentity(
          galaxy: world.galaxy, system: world.system)
      }
      try world.validate(
        authoring: config,
        bounds: origin.statistics.coordinateBoundsByGalaxy[world.galaxy])
      guard keys.insert(world.key).inserted, names.insert(world.name).inserted else {
        throw OriginalWorldCatalogueError.invalidSchema("Duplicate world identity or name")
      }
      galaxies[world.galaxy].append(world)
    }
    for index in galaxies.indices {
      galaxies[index].sort { $0.system < $1.system }
      guard galaxies[index].map(\.system) == Array(0..<256) else {
        throw OriginalWorldCatalogueError.invalidSchema("Galaxy must contain systems0...255")
      }
    }
    try validateStatistics(origin.statistics, worlds: document.systems)
    return .init(
      version: document.version, worlds: document.systems, authoring: config,
      provenance: origin,
      byKey: Dictionary(uniqueKeysWithValues: document.systems.map { ($0.key, $0) }),
      byGalaxy: galaxies)
  }

  private struct Document: Decodable {
    let version: String
    let systems: [OriginalWorldRecord]
  }

  private static let resources: Bundle =
    Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("L337_EliteCore.bundle"))
    } ?? Bundle.module

  private static func fingerprint(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func validateFieldInventory(_ data: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      Set(root.keys) == ["version", "systems"], let systems = root["systems"] as? [[String: Any]],
      systems.allSatisfy({ Set($0.keys) == OriginalWorldRecord.fieldNames })
    else {
      throw OriginalWorldCatalogueError.invalidSchema("Exact catalogue/world fields required")
    }
  }

  private static func validate(config: OriginalWorldAuthoring, provenance: OriginalWorldProvenance)
    throws
  {
    guard config.version == "l337-world-1", config.systemsPerGalaxy == 256,
      config.coordinateUnit == "LY", config.technologyMinimum == 1, config.technologyMaximum == 20,
      config.galaxies.count == 8, config.governments.count == 8,
      Set(config.galaxies.map(\.name)).count == 8,
      config.galaxies.allSatisfy({
        !$0.name.isEmpty && $0.spacing.count == 2 && $0.warp.count == 2
          && ($0.spacing + $0.warp + [$0.phase, $0.industryBias, $0.wealthBias]).allSatisfy(
            \.isFinite)
      }),
      config.governments.allSatisfy({
        !$0.name.isEmpty && $0.hostileFraction.isFinite && (0...1).contains($0.hostileFraction)
          && $0.civicInfrastructure.isFinite && (0...1).contains($0.civicInfrastructure)
      }), provenance.schemaVersion == 1, provenance.importedOn == "2026-10-18",
      provenance.statistics.coordinateBoundsByGalaxy.map(\.galaxy) == Array(0..<8),
      provenance.statistics.coordinateBoundsByGalaxy.allSatisfy({
        [$0.minimumXLY, $0.maximumXLY, $0.minimumYLY, $0.maximumYLY].allSatisfy(\.isFinite)
          && $0.minimumXLY <= $0.maximumXLY && $0.minimumYLY <= $0.maximumYLY
      })
    else { throw OriginalWorldCatalogueError.invalidSchema("Authoring/provenance") }
  }

  private static func validateEconomyAuthoring(_ config: OriginalWorldAuthoring) throws {
    let positive = [
      config.minimumLinkRangeLY, config.startingCreditsCR,
      config.minimumPriceFactor, config.maximumPriceFactor,
    ]
    guard !config.seed.isEmpty, config.moneyUnit == "0.1 CR", config.startingShipID == "SH025",
      positive.allSatisfy({ $0.isFinite && $0 > 0 }),
      config.minimumPriceFactor <= config.maximumPriceFactor, config.tickHours > 0,
      [config.startingFuelFraction, config.stockRecovery, config.minimumSpread].allSatisfy({
        $0.isFinite && (0...1).contains($0)
      }),
      config.galaxies.allSatisfy({
        $0.spacing.allSatisfy({ $0 > 0 }) && $0.warp.allSatisfy({ $0 >= 0 })
          && (-1...1).contains($0.industryBias) && (-1...1).contains($0.wealthBias)
      }), config.commodities.count == 17, config.commodities.map(\.index).sorted() == Array(0..<17),
      Set(config.commodities.map(\.name)).count == 17,
      config.commodities.allSatisfy({
        !$0.name.isEmpty && ["t", "kg", "g"].contains($0.unit)
          && ["industrial", "extraction", "consumer", "agricultural", "special"].contains($0.sector)
          && $0.basePriceCR.isFinite && $0.basePriceCR > 0 && $0.targetStock >= 0
          && (1...20).contains($0.technology) && $0.volatility.isFinite
          && (0...1).contains($0.volatility)
      }), config.equipment.count == 14, Set(config.equipment.map(\.id)).count == 14,
      Set(config.equipment.map(\.name)).count == 14,
      config.equipment.allSatisfy({
        !$0.id.isEmpty && !$0.name.isEmpty && $0.priceCR.isFinite && $0.priceCR >= 0
          && (1...20).contains($0.technology)
          && [
            $0.damage, $0.energyCost, $0.damagePerSecond, $0.energyPerSecond,
            $0.heatPerSecond, $0.rechargeMultiplier,
          ].compactMap({ $0 }).allSatisfy({
            $0.isFinite && $0 > 0
          }) && ($0.exclusiveGroup.map({ !$0.isEmpty }) ?? true)
      })
    else { throw OriginalWorldCatalogueError.invalidSchema("Economy authoring") }
  }

  private static func validateStatistics(
    _ statistics: OriginalWorldStatistics,
    worlds: [OriginalWorldRecord]
  ) throws {
    let surfaces = Dictionary(grouping: worlds, by: { $0.surface.rawValue }).mapValues(\.count)
    let climates = Dictionary(grouping: worlds, by: { $0.climate.rawValue }).mapValues(\.count)
    for bounds in statistics.coordinateBoundsByGalaxy {
      let galaxy = worlds.filter { $0.galaxy == bounds.galaxy }
      guard galaxy.map(\.xLY).min() == bounds.minimumXLY,
        galaxy.map(\.xLY).max() == bounds.maximumXLY,
        galaxy.map(\.yLY).min() == bounds.minimumYLY,
        galaxy.map(\.yLY).max() == bounds.maximumYLY
      else {
        throw OriginalWorldCatalogueError.invalidSchema("Approved coordinate bounds")
      }
    }
    guard statistics.worlds == worlds.count,
      statistics.uniqueNames == Set(worlds.map(\.name)).count,
      statistics.ringed == worlds.filter(\.ringed).count,
      statistics.christmasConvoy == worlds.filter(\.christmasConvoy).count,
      statistics.surfaceCounts == surfaces, statistics.climateCounts == climates
    else {
      throw OriginalWorldCatalogueError.invalidSchema("Approved statistics")
    }
  }
}
