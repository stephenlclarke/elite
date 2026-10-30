/// Approved authoring values are retained data. Loading them enables no gameplay policy.
public struct OriginalWorldAuthoring: Decodable, Sendable {
  public let version: String
  public let seed: String
  public let systemsPerGalaxy: Int
  public let coordinateUnit: String
  public let minimumLinkRangeLY: Double
  public let technologyMinimum: Int
  public let technologyMaximum: Int
  public let moneyUnit: String
  public let startingCreditsCR: Double
  public let startingShipID: String
  public let startingFuelFraction: Double
  public let tickHours: Int
  public let stockRecovery: Double
  public let minimumSpread: Double
  public let minimumPriceFactor: Double
  public let maximumPriceFactor: Double
  public let galaxies: [OriginalWorldGalaxy]
  public let governments: [OriginalWorldGovernment]
  public let commodities: [OriginalWorldCommodity]
  public let equipment: [OriginalWorldEquipment]
}

public struct OriginalWorldGalaxy: Decodable, Sendable {
  public let name: String
  public let spacing: [Double]
  public let warp: [Double]
  public let phase: Double
  public let industryBias: Double
  public let wealthBias: Double
}

public struct OriginalWorldGovernment: Decodable, Sendable {
  public let name: String
  public let hostileFraction: Double
  public let civicInfrastructure: Double
}

public struct OriginalWorldCommodity: Decodable, Sendable {
  public let index: Int
  public let name: String
  public let unit: String
  public let sector: String
  public let basePriceCR: Double
  public let targetStock: Int
  public let technology: Int
  public let volatility: Double
}

public struct OriginalWorldEquipment: Decodable, Sendable {
  public let id: String
  public let name: String
  public let priceCR: Double
  public let technology: Int
  public let damage: Double?
  public let energyCost: Double?
  public let damagePerSecond: Double?
  public let energyPerSecond: Double?
  public let heatPerSecond: Double?
  public let rechargeMultiplier: Double?
  public let exclusiveGroup: String?
}

public struct OriginalWorldProvenance: Decodable, Sendable {
  public let schemaVersion: Int
  public let importedOn: String
  public let authority: String
  public let verifiedHandoff: String
  public let proposalSHA256: String
  public let sourceDirectory: String
  public let files: [String: OriginalWorldSourceFile]
  public let preservation: String
  public let scope: String
  public let statistics: OriginalWorldStatistics
}

public struct OriginalWorldSourceFile: Decodable, Sendable {
  public let sha256: String
  public let bytes: Int
}

public struct OriginalWorldStatistics: Decodable, Sendable {
  public let worlds: Int
  public let uniqueNames: Int
  public let ringed: Int
  public let christmasConvoy: Int
  public let surfaceCounts: [String: Int]
  public let climateCounts: [String: Int]
  public let coordinateBoundsByGalaxy: [OriginalWorldCoordinateBounds]
}

public struct OriginalWorldCoordinateBounds: Decodable, Sendable {
  public let galaxy: Int
  public let minimumXLY: Double
  public let maximumXLY: Double
  public let minimumYLY: Double
  public let maximumYLY: Double
}
