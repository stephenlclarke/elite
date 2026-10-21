import Foundation

extension Game {
  /// Selected native player and common-project fit; never NPC defaults or other-edition physiology.
  var scriptCommanderQuery: ScriptValue {
    withReadOnlyCommander { makeScriptCommanderQuery($0) }
  }

  @inline(never)
  private func makeScriptCommanderQuery(_ commander: borrowing Commander) -> ScriptValue {
    var fields = commander.scriptCommanderFields
    fields["energy"] = .number(energy)
    fields["front_shield"] = .number(frontShield)
    fields["rear_shield"] = .number(rearShield)
    fields["laser_heat"] = .number(laserHeat)
    fields["cabin_temperature"] = .number(cabinTemperature)
    fields["location"] = scriptCommanderLocationQuery
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
    if let state = recordRecoveryState {
      fields["record_recovery"] = .object([
        "identified": .bool(state.identification != nil),
        "held": .integer(Int64(state.held.count)),
        "captured": .integer(Int64(state.captures.count)),
        "lost": .integer(Int64(state.losses.count)),
        "owner": .string("Cedamar flight-record archive / SENN"),
        "closed": .bool(state.reception != nil),
      ])
    }
    if let state = identifiedSalvageState {
      fields["identified_salvage"] = .object([
        "held": .integer(Int64(state.held.count)),
        "captured": .integer(Int64(state.captures.count)),
        "lost": .integer(Int64(state.losses.count)),
        "owner": .string("Avenor recovery depot / PELL"),
        "closed": .bool(state.reception != nil),
      ])
    }
    if let source = originalSurveyState {
      fields["consented_survey"] = .object([
        "mission": source.permission.map { .string($0.mission.uuidString) } ?? .null,
        "completed_readings": .integer(Int64(source.readings.count)),
        "next_target": source.readings.count < 3
          ? .string(NativeOriginalSurvey.targets[source.readings.count]) : .null,
        "status": originalSurveyScanStatus.map(ScriptValue.string) ?? .null,
      ])
    }
    if let source = commander.nativePeople?.outlookJourney {
      fields["orbital_outlook"] = .object([
        "people": .integer(Int64(source.references.count)),
        "aboard": .integer(
          Int64(
            commander.nativePeople?.held.filter { source.references.contains($0.person) }.count ?? 0
          )),
        "mission": source.boarding.map { .string($0.mission.uuidString) } ?? .null,
        "completed_views": .integer(Int64(source.readings.count)),
        "next_view": source.readings.count < 3
          ? .string(NativeOrbitalOutlookJourney.views[source.readings.count]) : .null,
        "status": orbitalOutlookScanStatus.map(ScriptValue.string) ?? .null,
      ])
    }
    if let state = commander.nativePeople?.orbitalEvacuation {
      fields["orbital_evacuation"] = .object([
        "registered": .integer(Int64(state.people.count)),
        "aboard": .integer(
          Int64(commander.nativePeople?.held.filter { $0.person.evacuation != nil }.count ?? 0)),
        "destination": .integer(185), "closed": .bool(state.terminalOperation != nil),
      ])
    }
    if let state = commander.nativePeople?.originalRescue {
      fields["original_rescue"] = .object([
        "mission": .string(state.mission.uuidString),
        "original_people": .integer(2), "capsules_recovered": .integer(Int64(state.captures.count)),
        "aboard": .integer(
          Int64(commander.nativePeople?.held.filter { $0.person.rescue != nil }.count ?? 0)),
        "transport_boarded": .bool(state.boarding != nil),
        "original_record_aboard": .bool(NativeOriginalRescueJourney.recordCarried(state)),
        "closed": .bool(state.terminalOperation != nil),
      ])
    }
    return .object(fields)
  }
  private var scriptCommanderLocationQuery: ScriptValue {
    let location = withReadOnlyCommander { ($0.galaxy, $0.system) }
    let system = systems[location.1]
    return .object([
      "galaxy": .integer(Int64(location.0)),
      "system": .integer(Int64(location.1)), "name": .string(system.name),
      "x": .integer(Int64(system.x)), "y": .integer(Int64(system.y)),
      "government": .integer(Int64(system.government)),
      "economy": .integer(Int64(system.economy)),
      "technology": .integer(Int64(system.technology)), "docked": .bool(docked),
      "main_station": .bool(docked && dockedAtMainStation),
    ])
  }

}

// Build independent read-only sections before composing the full commander snapshot.
extension Commander {
  fileprivate var scriptCommanderFields: [String: ScriptValue] {
    let fit = passengerFit
    let accommodation = scriptAccommodationQuery(fit: fit)
    let lasers = scriptLaserQuery
    return [
      "profile": .string("elite-native-player-v1"), "name": .string(name),
      "ship_id": .string(shipID), "ship_name": .string(ship.name),
      "credits_decicredits": .integer(Int64(credits)),
      "kills": .integer(Int64(kills)), "rank": .string(rank),
      "legal_score": .integer(Int64(legal)),
      "fuel_units": .integer(Int64(fuel)),
      "fuel_capacity_units": .integer(Int64(fuelCapacity)),
      "fuel_unit": .string("0.1 light year"),
      "jump_range_ly": .number(maximumJumpDistance),
      "missiles": .integer(Int64(missiles)),
      "missile_capacity": .integer(Int64(missileCapacity)), "lasers": lasers,
      "native_maximum_speed": .number(Double(performance.speed)),
      "maximum_velocity_units_per_second": .number(Double(performance.speed) * 18),
      "energy_capacity": .number(performance.energy),
      "shield_capacity": .number(shieldCapacity),
      "hold": scriptHoldQuery,
      "equipment": .object([
        "fitted": ownedGearCounts(fitted: true),
        "stored": ownedGearCounts(fitted: false),
        "free_units": fit.map { .integer(Int64($0.freeEquipmentUnits)) } ?? .null,
      ]),
      "accommodation": accommodation,
      "assists": .object([
        "unlimited_cash": .bool(unlimitedCash),
        "unlimited_cargo": .bool(unlimitedCargo),
        "unlimited_missiles": .bool(unlimitedMissiles),
        "unlimited_fuel": .bool(unlimitedFuel),
        "unlimited_jumps": .bool(unlimitedJumps),
      ]),
    ]
  }

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
      case .occupied, .nativePerson: occupied += 1
      case .reserved: reserved += 1
      case .extraCrew: extraCrew += 1
      case .empty: break
      }
    }
    return
      profile.map { value in
        .object([
          "profile": .string("project-cabin-places-v2"),
          "required_operating_crew": .integer(Int64(value.operatingCrew)),
          "intrinsic_crew_quarters": .integer(Int64(value.intrinsicCrewQuarters)),
          "crew_status": .string(value.crewStatus), "crew_basis": .string(value.crewBasis),
          "equipment_capacity_units": .integer(Int64(value.equipmentUnits)),
          "fitted_cabins": .integer(Int64(accommodation.fittedCabins.count)),
          "stored_cabins": .integer(Int64(accommodation.storedCabins.count)),
          "stasis_places": .integer(Int64(accommodation.availablePlaces(mode: .stasis).count)),
          "cabins": .array(
            accommodation.ownedCabins.map { cabin in
              .object([
                "id": .string(cabin.id.uuidString), "grade": .string(cabin.grade.rawValue),
                "places": .integer(Int64(cabin.grade.places)),
                "fitted": .bool(accommodation.fitted.contains(cabin.id)),
                "life_support": .bool(cabin.lifeSupportWorking),
                "stasis_working": .bool(cabin.stasisWorking),
              ])
            }),
          "fitted_berths": .integer(Int64(berths.count)),
          "stored_berths": .integer(Int64(accommodation.storedBerths.count)),
          "occupied_berths": .integer(Int64(occupied)),
          "reserved_berths": .integer(Int64(reserved)),
          "extra_crew_berths": .integer(Int64(extraCrew)),
          "free_awake_places": fit.map { .integer(Int64($0.freeCompatiblePlaces)) } ?? .null,
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
