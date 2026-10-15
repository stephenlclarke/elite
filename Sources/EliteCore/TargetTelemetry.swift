import Foundation

/// Pure disclosure of supplied NPC facts. The runtime owns their acquisition and updates.
public enum TargetTelemetry {
  public enum RouteProvenance: Equatable, Sendable {
    case recorded, inferredLocal
  }

  public struct RouteFact: Equatable, Sendable {
    public let identity: SystemIdentity
    public let provenance: RouteProvenance
    public init(identity: SystemIdentity, provenance: RouteProvenance) {
      self.identity = identity
      self.provenance = provenance
    }
  }

  /// Current readings must come from tracked actor state, never maxima or player resources.
  /// Shields and heat retain simulation units; fuel uses the game's tenths of a LY.
  public struct Resources: Equatable, Sendable {
    public let frontShield: Double
    public let frontCapacity: Double
    public let rearShield: Double
    public let rearCapacity: Double
    public let laserHeat: Double
    public let heatCapacity: Double
    public let fuelTenthsLY: Int
    public let fuelCapacityTenthsLY: Int
    public init(
      frontShield: Double, frontCapacity: Double, rearShield: Double, rearCapacity: Double,
      laserHeat: Double, heatCapacity: Double, fuelTenthsLY: Int, fuelCapacityTenthsLY: Int
    ) {
      self.frontShield = frontShield
      self.frontCapacity = frontCapacity
      self.rearShield = rearShield
      self.rearCapacity = rearCapacity
      self.laserHeat = laserHeat
      self.heatCapacity = heatCapacity
      self.fuelTenthsLY = fuelTenthsLY
      self.fuelCapacityTenthsLY = fuelCapacityTenthsLY
    }
  }

  public struct Facts: Equatable, Sendable {
    /// Caller supplies ordinary cargo only, excluding mission-reserved custody.
    /// An empty array means a known empty manifest; nil means it was not observed.
    public let cargo: [CommodityAmount]?
    public let origin: RouteFact?
    public let destination: RouteFact?
    public let legal: LegalRecord?
    public let hostile: Bool
    public let resources: Resources?
    public init(
      cargo: [CommodityAmount]?, origin: RouteFact?, destination: RouteFact?,
      legal: LegalRecord?, hostile: Bool, resources: Resources?
    ) {
      self.cargo = cargo
      self.origin = origin
      self.destination = destination
      self.legal = legal
      self.hostile = hostile
      self.resources = resources
    }
    public var attitude: String { hostile ? "Hostile" : "Neutral" }
  }

  /// Ship-only fields. Station/debris and Mining/Salvage policies remain with their adapters.
  /// Legal disclosure requires explicit policy approval in addition to Identification.
  public static func fields(
    facts: Facts, tier: TargetingTier, targetIsShip: Bool, observerGalaxy: Int,
    discloseLegal: Bool = false
  ) -> [TargetField] {
    guard targetIsShip else { return [] }
    var result: [TargetField] = []
    if tier >= .identification && discloseLegal {
      result.append(.init(label: "Legal status", value: legalName(facts.legal)))
    }
    if tier >= .pirate {
      result += [
        .init(label: "Cargo", value: cargoManifest(facts.cargo)),
        .init(label: "Origin", value: systemName(facts.origin, observerGalaxy: observerGalaxy)),
        .init(
          label: "Destination", value: systemName(facts.destination, observerGalaxy: observerGalaxy)
        ),
      ]
    }
    if tier >= .military {
      let resources = facts.resources
      let fuel: String
      if let resources, resources.fuelCapacityTenthsLY >= 0,
        (0...resources.fuelCapacityTenthsLY).contains(resources.fuelTenthsLY)
      {
        fuel =
          number(Double(resources.fuelTenthsLY) / 10) + " / "
          + number(Double(resources.fuelCapacityTenthsLY) / 10) + " LY"
      } else {
        fuel = "Unknown"
      }
      result += [
        .init(
          label: "Front shield", value: reading(resources?.frontShield, resources?.frontCapacity)),
        .init(label: "Rear shield", value: reading(resources?.rearShield, resources?.rearCapacity)),
        .init(label: "Laser heat", value: reading(resources?.laserHeat, resources?.heatCapacity)),
        .init(label: "Fuel", value: fuel),
      ]
    }
    return result
  }

  public static func cargoManifest(_ cargo: [CommodityAmount]?) -> String {
    guard let cargo, cargo.allSatisfy(\.valid) else { return "Unknown" }
    guard !cargo.isEmpty else { return "None" }
    return cargo.map { "\($0.commodity.name) \($0.quantity) \($0.commodity.unit)" }.joined(
      separator: "; ")
  }

  public static func systemName(_ route: RouteFact?, observerGalaxy: Int) -> String {
    guard let route, (0..<8).contains(route.identity.galaxy),
      (0...Plugh.systemID).contains(route.identity.system)
    else { return "Unknown" }
    let identity = route.identity
    let name =
      identity.system == Plugh.systemID
      ? Plugh.name : Universe.galaxy(number: identity.galaxy)[identity.system].name
    let galaxy = identity.galaxy == observerGalaxy ? "" : " (Galaxy \(identity.galaxy + 1))"
    let provenance = route.provenance == .inferredLocal ? " (inferred local)" : ""
    return name + galaxy + provenance
  }

  /// This identity resolver does not itself grant disclosure; call it after the model gate.
  public static func modelName(
    catalogueShipID: String?, missionName: String?, fallbackHull: Hull
  ) -> String {
    if let missionName, !missionName.isEmpty { return missionName }
    if let catalogueShipID, let ship = ShipCatalogue.ship(catalogueShipID) { return ship.name }
    return fallbackHull.modelName
  }

  private static func legalName(_ record: LegalRecord?) -> String {
    guard let record, (0...255).contains(record.value) else { return "Unknown" }
    if record.value == 0 { return "Clean" }
    return record.value < 50 ? "Offender" : "Fugitive"
  }

  private static func reading(_ current: Double?, _ capacity: Double?) -> String {
    guard let current, let capacity, current.isFinite, capacity.isFinite,
      capacity >= 0, current >= 0, current <= capacity
    else { return "Unknown" }
    return number(current) + " / " + number(capacity)
  }

  private static func number(_ value: Double) -> String {
    String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
  }
}
