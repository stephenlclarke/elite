import Foundation

/// Common fit projection for individually authenticated original player-hull activations.
enum OriginalPlayerHullActivation {
  enum Failure: Error { case missingStandardFit, invalidCatalogue }

  /// Closed per-ID routing; a family name or runtime-ready flag never selects an adapter.
  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    switch retained.id {
    case "SH002": return try OriginalGyrfalconAssaultActivation.resolve(retained)
    case "SH003", "SH004": return try OriginalGyrfalconFamilyActivation.resolve(retained)
    case "SH007": return try OriginalImpalaVoyagerActivation.resolve(retained)
    case "SH012": return try OriginalSableLinerActivation.resolve(retained)
    case "SH018": return try OriginalDonkeyActivation.resolve(retained)
    case "SH019": return try OriginalGazelleExplorerActivation.resolve(retained)
    case "SH027": return try OriginalIbexActivation.resolve(retained)
    case "SH030": return try OriginalSparrowhawkActivation.resolve(retained)
    case "SH031": return try OriginalKiteInterceptorActivation.resolve(retained)
    case "SH029": return try OriginalBurroActivation.resolve(retained)
    case "SH061": return try OriginalHaflingerActivation.resolve(retained)
    default: return retained
    }
  }

  static func resolve(
    _ retained: CatalogueShip, definition: OriginalFleetDefinition,
    physical: OriginalHullPhysicalContract
  ) throws -> CatalogueShip {
    guard retained.id == definition.id, physical.id == definition.id,
      physical.specificationSHA256 == definition.sourceSHA256,
      let role = ShipCatalogueRole(rawValue: definition.role),
      [ShipCatalogueRole.trader, .military, .leisure, .bountyHunter].contains(role),
      let type = ShipCatalogueType(rawValue: definition.role), definition.playerFlyable,
      definition.purchasePolicy == "blueprintFabrication",
      let performance = definition.nativePerformance
    else { throw Failure.invalidCatalogue }
    guard let standard = retained.profiles.first(where: { $0.group == "project-refit-v1" }) else {
      throw Failure.missingStandardFit
    }
    let historical = retained.profiles.map { profile in
      guard profile.group == "project-refit-v1" else { return profile }
      return ShipProfile(
        id: profile.id, title: profile.title, group: "historical-project-refit-v1",
        context: "Historical inactive project profile. " + profile.context, fields: profile.fields)
    }
    let id = definition.id
    let specificationSHA256 = definition.sourceSHA256
    let ship = CatalogueShip(
      id: id, name: definition.name, shipClass: retained.shipClass, appearances: "L337",
      evidence: "Original specification " + specificationSHA256,
      refit: retained.refit, model: "L337-" + id, modelSource: "Original L337",
      dimensions: [
        physical.envelope.dimensions.x, physical.envelope.dimensions.y,
        physical.envelope.dimensions.z,
      ],
      geometryContext:
        physical.unitBasis + " No showroom normalization in physical geometry. "
        + physical.model.sourcePath + " / " + physical.model.sourceSHA256,
      profiles: historical + [
        standardProfile(from: standard, performance: performance, definition: definition)
      ],
      game: performance,
      catalogue: metadata(from: retained.catalogue, definition: definition, role: role, type: type),
      design: physical.model.nativeDesign, nativeHull: retained.nativeHull,
      nativeDesign: physical.model.nativeDesign, nativeCombat: retained.nativeCombat)
    guard
      ship.catalogue.valid(shipID: id, performance: performance, nativeCombat: ship.nativeCombat),
      ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles)
    else { throw Failure.invalidCatalogue }
    return ship
  }

  private static func metadata(
    from retained: ShipCatalogueMetadata, definition: OriginalFleetDefinition,
    role: ShipCatalogueRole, type: ShipCatalogueType
  ) -> ShipCatalogueMetadata {
    .init(
      schemaVersion: retained.schemaVersion, family: definition.family, aliases: retained.aliases,
      objectKind: .ship, origin: .human, primaryType: type,
      primaryRole: role,
      roleWeights: [.init(role: role, weight: 1)], access: .normal, playerFlyable: true,
      normalPurchaseEligible: true, purchasePolicy: .blueprintFabrication,
      minimumBuildTechLevel: retained.minimumBuildTechLevel, isCapital: false, capitalSubtype: nil,
      collectionMilestone: .blueprintAndFabrication, damagePolicy: .destructible,
      habitat: retained.habitat, discoveryEligible: true, encounterMode: retained.encounterMode,
      mechanicsStatus: .ready, placementStatus: retained.placementStatus, rarity: retained.rarity,
      galaxies: retained.galaxies, regions: retained.regions,
      authoredSystems: retained.authoredSystems,
      basis:
        "Original " + definition.id + " " + definition.name
        + " " + role.rawValue + " and blueprint-fabrication policy. "
        + "Existing project placement, rarity and fabrication technology policy retained; "
        + "catalogue eligibility does not grant discovery, a blueprint or a fabricated hull.")
  }

  private static func standardProfile(
    from retained: ShipProfile, performance p: ShipPerformance, definition: OriginalFleetDefinition
  )
    -> ShipProfile
  {
    let specificationSHA256 = definition.sourceSHA256
    let values: [String: Double] = [
      "cargo_tonnes": Double(p.cargo), "maximum_speed_project_units": p.speed,
      "acceleration_project_units_per_second_squared": p.acceleration,
      "hull_energy": p.energy, "fore_shield_max": p.shield, "aft_shield_max": p.shield,
      "energy_recharge_per_second": p.recharge,
      "fore_shield_recharge_per_second": p.shieldRecharge,
      "aft_shield_recharge_per_second": p.shieldRecharge,
      "roll_radians_per_second": p.roll, "pitch_radians_per_second": p.pitch,
      "yaw_radians_per_second": p.yaw, "hyperspace_range_ly": p.jump,
      "jump_spool_seconds": p.spool, "fuel_capacity_tenths_ly": Double(p.fuel),
      "laser_facing_mask": Double(p.facings), "missile_capacity": Double(p.missiles),
      "cargo_expansion_tonnes": Double(p.cargoExpansion), "usable_cargo_after_fit": Double(p.cargo),
    ]
    let fields = retained.fields.map { field -> ShipSpec in
      if let value = values[field.key] {
        return .init(
          key: field.key, label: field.label,
          text: String(format: "%.4g", value) + (field.unit.isEmpty ? "" : " " + field.unit),
          number: value, unit: field.unit, status: "original authored",
          basis: "Approved " + definition.sourcePath + " / " + specificationSHA256)
      }
      if ["rear_laser", "left_laser", "right_laser"].contains(field.key) {
        return .init(
          key: field.key, label: field.label, text: "Optional laser mount", number: nil,
          unit: field.unit, status: "original authored",
          basis: definition.id + " facing mask " + String(p.facings))
      }
      return field
    }
    return .init(
      id: "L337-PLAYER-" + definition.id, title: definition.name + " original standard fit",
      group: "project-refit-v1",
      context:
        "Original authored mechanics; retained common one-commander accommodation/fitting estimate. "
        + "Actual carried fittings and cabin footprints remain inventory-owned.", fields: fields)
  }
}
