import Foundation

extension Game {
  /// Selected native player and common-project fit; never NPC defaults or other-edition physiology.
  var scriptCommanderQuery: ScriptValue {
    let fit = commander.passengerFit
    let accommodation = commander.scriptAccommodationQuery(fit: fit)
    let lasers = commander.scriptLaserQuery
    var fields: [String: ScriptValue] = [
      "profile": .string("elite-native-player-v1"), "name": .string(commander.name),
      "ship_id": .string(commander.shipID), "ship_name": .string(commander.ship.name),
      "credits_decicredits": .integer(Int64(commander.credits)),
      "kills": .integer(Int64(commander.kills)), "rank": .string(commander.rank),
      "legal_score": .integer(Int64(commander.legal)),
      "fuel_units": .integer(Int64(commander.fuel)),
      "fuel_capacity_units": .integer(Int64(commander.fuelCapacity)),
      "fuel_unit": .string("0.1 light year"),
      "jump_range_ly": .number(commander.maximumJumpDistance),
      "missiles": .integer(Int64(commander.missiles)),
      "missile_capacity": .integer(Int64(commander.missileCapacity)), "lasers": lasers,
      "native_maximum_speed": .number(Double(commander.performance.speed)),
      "maximum_velocity_units_per_second": .number(Double(commander.performance.speed) * 18),
      "energy_capacity": .number(commander.performance.energy),
      "shield_capacity": .number(commander.shieldCapacity),
      "energy": .number(energy), "front_shield": .number(frontShield),
      "rear_shield": .number(rearShield),
      "laser_heat": .number(laserHeat), "cabin_temperature": .number(cabinTemperature),
      "hold": commander.scriptHoldQuery,
      "equipment": .object([
        "fitted": commander.ownedGearCounts(fitted: true),
        "stored": commander.ownedGearCounts(fitted: false),
        "free_units": fit.map { .integer(Int64($0.freeEquipmentUnits)) } ?? .null,
      ]),
      "accommodation": accommodation,
      "assists": .object([
        "unlimited_cash": .bool(commander.unlimitedCash),
        "unlimited_cargo": .bool(commander.unlimitedCargo),
        "unlimited_missiles": .bool(commander.unlimitedMissiles),
        "unlimited_fuel": .bool(commander.unlimitedFuel),
        "unlimited_jumps": .bool(commander.unlimitedJumps),
      ]),
      "location": .object([
        "galaxy": .integer(Int64(commander.galaxy)),
        "system": .integer(Int64(commander.system)), "name": .string(currentSystem.name),
        "x": .integer(Int64(currentSystem.x)), "y": .integer(Int64(currentSystem.y)),
        "government": .integer(Int64(currentSystem.government)),
        "economy": .integer(Int64(currentSystem.economy)),
        "technology": .integer(Int64(currentSystem.technology)), "docked": .bool(docked),
        "main_station": .bool(docked && dockedAtMainStation),
      ]),
    ]
    if nativeStationEventFacts != nil { fields["native_station"] = nativeStationFacts }
    if let receipt = commander.nativeStations?.currentMainDock, docked && dockedAtMainStation {
      fields["native_main_arrival"] = .object([
        "world": .string(receipt.station.world.uuidString),
        "resource": .string(receipt.station.resource.uuidString),
        "station_key": .string(receipt.station.key),
        "docking_sequence": .integer(Int64(receipt.sequence)),
        "calendar_seconds": .number(receipt.calendarSeconds),
      ])
    }
    return .object(fields)
  }
}

// Build independent read-only sections before composing the full commander snapshot.
extension Commander {
  fileprivate func scriptAccommodationQuery(fit: AccommodationFit?) -> ScriptValue {
    let profile = ShipCatalogue.ship(shipID).flatMap {
      try? ShipAccommodationProfile(ship: $0)
    }
    let berths = accommodation.fittedBerths
    var occupied = 0
    var reserved = 0
    var extraCrew = 0
    for berth in berths {
      switch berth.use {
      case .occupied: occupied += 1
      case .reserved: reserved += 1
      case .extraCrew: extraCrew += 1
      case .empty: break
      }
    }
    return
      profile.map { value in
        .object([
          "profile": .string("project-common-charter-v1"),
          "required_operating_crew": .integer(Int64(value.operatingCrew)),
          "intrinsic_crew_quarters": .integer(Int64(value.intrinsicCrewQuarters)),
          "crew_status": .string(value.crewStatus), "crew_basis": .string(value.crewBasis),
          "equipment_capacity_units": .integer(Int64(value.equipmentUnits)),
          "fitted_berths": .integer(Int64(berths.count)),
          "stored_berths": .integer(Int64(accommodation.storedBerths.count)),
          "occupied_berths": .integer(Int64(occupied)),
          "reserved_berths": .integer(Int64(reserved)),
          "extra_crew_berths": .integer(Int64(extraCrew)),
          "free_compatible_places": fit.map { .integer(Int64($0.freeCompatiblePlaces)) } ?? .null,
          "fit_allowed": fit.map { .bool($0.allowed) } ?? .null,
        ])
      } ?? .null
  }

  fileprivate var scriptLaserQuery: ScriptValue {
    return .object(
      Dictionary(
        uniqueKeysWithValues: LaserMount.allCases.map { mount in
          (
            mount.rawValue,
            laser(on: mount).map { laser in
              ScriptValue.object([
                "kind": .string(laser.rawValue), "name": .string(laser.equipmentName),
                "nominal_damage": .number(laser.damage),
                "minimum_interval_seconds": .number(laser.firingInterval),
              ])
            } ?? .null
          )
        }))
  }

  fileprivate var scriptHoldQuery: ScriptValue {
    return .object([
      "capacity_tonnes": .integer(Int64(capacity)),
      "trade_capacity_tonnes": .integer(Int64(tradeCargoCapacity)),
      "used_tonnes": .integer(Int64(cargoTonnes)),
      "free_tonnes": .integer(Int64(tradeCargoCapacity - cargoTonnes)),
      "commodities": .array(
        Commodity.all.indices.map { index in
          .object([
            "id": .integer(Int64(index)), "name": .string(Commodity.all[index].name),
            "unit": .string(Commodity.all[index].unit),
            "quantity": .integer(Int64(cargo[index])),
            "available": .integer(Int64(sellableCargo(index))),
          ])
        }),
    ])
  }
}
