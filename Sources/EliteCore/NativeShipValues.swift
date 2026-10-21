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
    let fittedMissiles =
      equipmentInventory.map { inventory in
        inventory.items.filter { item in
          guard item.node == EquipmentRuntimeCatalog.standardMissile,
            item.location?.hullInstanceID == inventory.activeHull,
            case .missilePylon = item.location?.slot
          else { return false }
          return true
        }.count
      } ?? missiles
    let fittedLasers = LaserMount.allCases.filter { laser(on: $0) != nil }.count
    func field(_ key: String, _ label: String, _ number: Double, _ unit: String) -> ShipSpec {
      .init(
        key: key, label: label,
        text: String(format: "%.1f", number) + (unit.isEmpty ? "" : " " + unit), number: number,
        unit: unit, status: "game", basis: "Authoritative ship TOML and carried equipment")
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
      field("fore_shield_max", "Front shield", shieldCapacity, "energy"),
      field("aft_shield_max", "Rear shield", rearShieldCapacity, "energy"),
      field(
        "fore_shield_recharge_per_second", "Front shield recharge", frontShieldRecharge, "energy/s"),
      field(
        "aft_shield_recharge_per_second", "Rear shield recharge", rearShieldRecharge, "energy/s"),
      field("roll_radians_per_second", "Roll", p.roll, "rad/s"),
      field("pitch_radians_per_second", "Pitch", p.pitch, "rad/s"),
      field("yaw_radians_per_second", "Yaw", p.yaw, "rad/s"),
      field("fuel_capacity_tenths_ly", "Fuel tank", Double(fuelCapacity) / 10, "LY"),
      field("hyperspace_range_ly", "Jump capacity", fullTankJumpDistance, "LY"),
      field("jump_spool_seconds", "Jump charge", p.spool, "s"),
      field("missile_capacity", "Missile pylons", Double(missileCapacity), "pylons"),
      field("fitted_missiles", "Loaded missiles", Double(fittedMissiles), "missiles"),
      field(
        "laser_facings", "Laser mounts", Double(LaserMount.allCases.filter(p.supports).count),
        "mounts"),
      field("fitted_lasers", "Fitted lasers", Double(fittedLasers), "lasers"),
      field("price", "Hull price", Double(p.price), "CR"),
    ]
    if unlimitedCargo {
      fields[0] = .init(
        key: "cargo_tonnes", label: "Cargo", text: "Unlimited (XYZZY)", number: nil, unit: "t",
        status: "game", basis: "Cargo policy; not an integer physical capacity")
    }
    fields += nativeAccommodationFields
    return .init(
      id: "game-" + shipID, title: ship.name + " / carried fit", group: "native-game",
      context:
        "Game units; portable equipment transfers, hull-bound fittings stay with their hull. Fuel supply is separate from tank and jump capacity.",
      fields: fields)
  }

  /// Current custody and the existing common accommodation adapter share one presentation.
  var nativeAccommodationFields: [ShipSpec] {
    let current = accommodation
    let identities = [
      ("required_crew_including_commander", "Required crew", "people"),
      ("reserved_crew_accommodation", "Reserved crew quarters", "people"),
      ("fitted_passenger_berths", "Fitted passenger berths", "berths"),
      ("stored_passenger_berths", "Stored passenger berths", "berths"),
      ("passengers_aboard", "Passengers aboard", "people"),
      ("free_passenger_places", "Free passenger places", "people"),
      ("hold_used_by_cabins", "Cabin footprint", "t"),
      ("equipment_capacity_units", "Equipment capacity", "units"),
      ("free_equipment_units", "Free equipment units", "units"),
      ("usable_cargo_after_fit", "Usable cargo after fit", "t"),
    ]
    guard current.valid, let profile = try? ShipAccommodationProfile(ship: ship),
      let fit = passengerFit
    else {
      return identities.map { key, label, unit in
        .init(
          key: key, label: label, text: "Unavailable", number: nil, unit: unit,
          status: "unavailable", basis: "No valid common accommodation adapter or custody.")
      }
    }
    let fitted = current.fitted.count
    let aboard = current.people.values.reduce(0) { count, person in
      if case .cabin = person.location { return count + 1 }
      return count
    }
    let values = [
      profile.operatingCrew, profile.intrinsicCrewQuarters, fitted,
      current.ownedBerths.count - fitted, aboard, fit.freeCompatiblePlaces, fit.cabinCargo,
      profile.equipmentUnits, fit.freeEquipmentUnits, fit.usableCargo,
    ]
    let source = ship.profiles.first { $0.group == "project-refit-v1" }?.fields ?? []
    return zip(identities, values).map { identity, value in
      let (key, label, unit) = identity
      let hasSourceMetadata = [
        "required_crew_including_commander", "reserved_crew_accommodation",
        "equipment_capacity_units",
      ].contains(key)
      let retained = source.first { $0.key == key }
      return .init(
        key: key, label: label, text: "\(value) \(unit)", number: Double(value), unit: unit,
        status: hasSourceMetadata ? retained?.status ?? profile.crewStatus : "game",
        basis: hasSourceMetadata
          ? retained?.basis ?? profile.crewBasis
          : "Actual owned cabin/person custody and the common accommodation fit.")
    }
  }
}
extension Game {
  var selectedGameProfile: ShipProfile? {
    guard let ship = showroomShip, ship.game != nil else { return nil }
    return commander.projectedGameShipProfile(to: ship.id)
  }
}
extension Commander {
  func projectedGameShipProfile(to shipID: String) -> ShipProfile? {
    guard let ship = ShipCatalogue.ship(shipID), ship.game != nil else { return nil }
    do {
      return try projectedEquipmentTransfer(to: shipID).gameShipProfile
    } catch {
      // Keep the comparison explicit without presenting a fit that cannot transfer.
      return .init(
        id: "game-" + shipID, title: ship.name + " / incompatible carried fit",
        group: "native-game",
        context:
          "Carried fittings or resources cannot transfer to this hull. Review trade for details.",
        fields: gameShipProfile.fields.map { field in
          .init(
            key: field.key, label: field.label, text: "Unavailable", number: nil,
            unit: field.unit, status: "game", basis: "Incompatible carried fit")
        })
    }
  }
}
extension ShipPerformance {
  /// Native combat capability index, not a historical rating or purchase price.
  public var power: Double {
    energy + 2 * shield + 32 * recharge + 64 * Double(missiles) + 128
      * Double(facings.nonzeroBitCount)
  }
}
