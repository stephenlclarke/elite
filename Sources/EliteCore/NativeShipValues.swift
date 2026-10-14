import Foundation

public enum ComparisonRating: String, Sendable {
  case better = "BETTER"
  case worse = "WORSE"
  case same = "SAME"
  case different = "DIFFERENT"
  case unavailable = "?"
  public var ink: Ink {
    switch self {
    case .better: .green
    case .worse: .orange
    case .same: .cyan
    case .different: .yellow
    case .unavailable: .white
    }
  }
  static func compare(_ a: ShipSpec?, _ b: ShipSpec?, compatible: Bool) -> Self {
    guard compatible, let a, let b else { return .unavailable }
    if a.text == "Unavailable" || b.text == "Unavailable" { return .unavailable }
    if a.text.hasPrefix("Unlimited") || b.text.hasPrefix("Unlimited") {
      if a.text == b.text { return .same }
      return b.text.hasPrefix("Unlimited") ? .better : .worse
    }
    guard let left = a.number, let right = b.number else {
      return a.text == b.text ? .same : .different
    }
    // Match the displayed precision so equal-looking values never receive conflicting badges.
    let delta = (right * 10).rounded() - (left * 10).rounded()
    if delta == 0 { return .same }
    let lowerIsBetter = ["price", "jump_spool_seconds", "required_crew_including_commander"]
      .contains(b.key)
    return (delta > 0) != lowerIsBetter ? .better : .worse
  }
}
extension Commander {
  public var gameShipProfile: ShipProfile {
    let p = performance
    func field(
      _ key: String, _ label: String, _ number: Double, _ unit: String, status: String = "game",
      basis: String = "Authoritative ship TOML and carried equipment"
    ) -> ShipSpec {
      .init(
        key: key, label: label,
        text: String(format: "%.1f", number) + (unit.isEmpty ? "" : " " + unit)
          + (status.contains("estimated") ? " (est.)" : ""), number: number,
        unit: unit, status: status, basis: basis)
    }
    var fields = [
      field("cargo_tonnes", "Cargo", Double(capacity), "t"),
      field("physical_hold", "Fitted hold", Double(standardCargoCapacity), "t"),
      field("maximum_speed_project_units", "Top speed", p.speed, "speed"),
      field(
        "acceleration_project_units_per_second_squared", "Acceleration", p.acceleration, "speed/s"),
      field("hull_energy", "Energy", p.energy, "energy"),
      field(
        "energy_recharge_per_second", "Energy recharge", p.recharge * energyRechargeMultiplier,
        "energy/s"),
      field("fore_shield_max", "Shields (each)", shieldCapacity, "energy"),
      field("fore_shield_recharge_per_second", "Shield recharge", p.shieldRecharge, "energy/s"),
      field("roll_radians_per_second", "Roll", p.roll, "rad/s"),
      field("pitch_radians_per_second", "Pitch", p.pitch, "rad/s"),
      field("yaw_radians_per_second", "Yaw", p.yaw, "rad/s"),
      field("fuel_capacity_tenths_ly", "Fuel tank", Double(fuelCapacity) / 10, "LY"),
      field("hyperspace_range_ly", "Jump capacity", min(jumpCap, Double(fuelCapacity) / 10), "LY"),
      field("jump_spool_seconds", "Jump charge", p.spool, "s"),
      field("missile_capacity", "Missile pylons", Double(missileCapacity), "pylons"),
      field(
        "laser_facings", "Laser mounts", Double(LaserMount.allCases.filter(p.supports).count),
        "mounts"),
      field("price", "Hull price", Double(p.price), "CR"),
    ]
    if let crew = try? ShipAccommodationProfile(ship: ship), let fit = passengerFit {
      fields += [
        field(
          "required_crew_including_commander", "Operating crew", Double(crew.operatingCrew),
          "people", status: crew.crewStatus, basis: crew.crewBasis),
        field(
          "reserved_crew_accommodation", "Crew quarters", Double(crew.intrinsicCrewQuarters),
          "people"),
        field(
          "fitted_passenger_berths", "Fitted cabins", Double(accommodation.fitted.count), "places"),
        field(
          "passengers_aboard", "Occupied/reserved",
          Double(accommodation.fittedBerths.filter { $0.use.used }.count), "places"),
        field(
          "free_passenger_places", "Free passenger places", Double(fit.freeCompatiblePlaces),
          "places"),
        field("hold_used_by_cabins", "Cabin hold", Double(fit.cabinCargo), "t"),
        field("usable_cargo_after_fit", "Spare freight hold", Double(fit.usableCargo), "t"),
      ]
    }
    if unlimitedCargo {
      fields[0] = .init(
        key: "cargo_tonnes", label: "Cargo", text: "Unlimited (XYZZY)", number: nil, unit: "t",
        status: "game", basis: "Cargo policy; not an integer physical capacity")
    }
    return .init(
      id: "game-" + shipID, title: ship.name + " / carried fit", group: "native-game",
      context:
        "Game units; same carried equipment on both hulls. Fuel supply is separate from tank and jump capacity.",
      fields: fields)
  }
}
extension Game {
  var selectedGameProfile: ShipProfile? {
    guard let ship = showroomShip, ship.game != nil else { return nil }
    var fit = commander
    fit.shipID = ship.id
    return fit.gameShipProfile
  }
}
extension ShipPerformance {
  /// Native combat capability index, not a historical rating or purchase price.
  public var power: Double {
    energy + 2 * shield + 32 * recharge + 64 * Double(missiles) + 128
      * Double(facings.nonzeroBitCount)
  }
}
