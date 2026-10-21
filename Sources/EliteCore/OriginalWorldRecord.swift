import Foundation

public enum OriginalWorldSurface: String, Decodable, Sendable, Equatable {
  case mixed
  case pollutedIndustrial = "polluted-industrial"
  case greenAgricultural = "green-agricultural"
  case snowAndEvergreen = "snow-and-evergreen"
}

public enum OriginalWorldClimate: String, Decodable, Sendable, Equatable {
  case temperate
  case permanentWinter = "permanent-winter"
}

/// All 29 approved world fields, without legacy coordinates or inferred aliases.
/// Catalogue loading validates the complete record before exposing it to callers.
public struct OriginalWorldRecord: Decodable, Sendable, Equatable {
  public let key: String
  public let galaxy: Int
  public let system: Int
  public let name: String
  public let xLY: Double
  public let yLY: Double
  public let government: String
  public let governmentID: Int
  public let hostileFraction: Double
  public let technology: Int
  public let economyID: Int
  public let economy: String
  public let industry: Double
  public let agriculture: Double
  public let extraction: Double
  public let consumer: Double
  public let special: Double
  public let wealth: Double
  public let populationBillions: Double
  public let productivityBillionCR: Double
  public let radiusKM: Int
  public let axialTiltDegrees: Double
  public let ringed: Bool
  public let nightLight: Double
  public let pollution: Double
  public let surface: OriginalWorldSurface
  public let climate: OriginalWorldClimate
  public let christmasConvoy: Bool
  public let worldVersion: String

  static let fieldNames: Set<String> = [
    "key", "galaxy", "system", "name", "xLY", "yLY", "government", "governmentID",
    "hostileFraction", "technology", "economyID", "economy", "industry", "agriculture",
    "extraction", "consumer", "special", "wealth", "populationBillions", "productivityBillionCR",
    "radiusKM", "axialTiltDegrees", "ringed", "nightLight", "pollution", "surface", "climate",
    "christmasConvoy", "worldVersion",
  ]

  func validate(authoring: OriginalWorldAuthoring, bounds: OriginalWorldCoordinateBounds) throws {
    guard (0..<8).contains(galaxy), (0..<256).contains(system),
      key == String(format: "G%02d-S%03d", galaxy + 1, system), !name.isEmpty,
      name == name.trimmingCharacters(in: .whitespacesAndNewlines),
      worldVersion == authoring.version, xLY.isFinite, yLY.isFinite,
      bounds.galaxy == galaxy, (bounds.minimumXLY...bounds.maximumXLY).contains(xLY),
      (bounds.minimumYLY...bounds.maximumYLY).contains(yLY),
      authoring.governments.indices.contains(governmentID),
      government == authoring.governments[governmentID].name,
      hostileFraction == authoring.governments[governmentID].hostileFraction,
      (authoring.technologyMinimum...authoring.technologyMaximum).contains(technology),
      Self.economyNames.indices.contains(economyID), economy == Self.economyNames[economyID],
      [
        hostileFraction, industry, agriculture, extraction, consumer, special, wealth, nightLight,
        pollution,
      ].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
      abs(industry + agriculture - 1) < 1e-9,
      populationBillions.isFinite, populationBillions > 0,
      productivityBillionCR.isFinite, productivityBillionCR > 0, radiusKM > 0,
      axialTiltDegrees.isFinite, (0...180).contains(axialTiltDegrees)
    else { throw OriginalWorldCatalogueError.invalidSchema("World: " + key) }
  }

  private static let economyNames = [
    "Rich Industrial", "Average Industrial", "Poor Industrial", "Mainly Industrial",
    "Mainly Agricultural", "Rich Agricultural", "Average Agricultural", "Poor Agricultural",
  ]
}
