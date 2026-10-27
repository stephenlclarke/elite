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
    case "SH032", "SH033": return try OriginalPantherFamilyActivation.resolve(retained)
    case "SH035": return try OriginalStagLinerActivation.resolve(retained)
    case "SH036": return try OriginalZebuActivation.resolve(retained)
    case "SH041": return try OriginalServalFighterActivation.resolve(retained)
    case "SH042": return try OriginalSakerActivation.resolve(retained)
    case "SH043": return try OriginalEagleCruiserActivation.resolve(retained)
    case "SH044", "SH046", "SH047": return try OriginalHarpyFamilyActivation.resolve(retained)
    case "SH045": return try OriginalErneCorvetteActivation.resolve(retained)
    case "SH054": return try OriginalHobbyFighterActivation.resolve(retained)
    case "SH055": return try OriginalCondorActivation.resolve(retained)
    case "SH057": return try OriginalFalconetActivation.resolve(retained)
    case "SH059": return try OriginalBarbaryActivation.resolve(retained)
    case "SH062": return try OriginalMooseClipperActivation.resolve(retained)
    case "SH064": return try OriginalArnaCutterActivation.resolve(retained)
    case "SH065": return try OriginalVultureRaiderActivation.resolve(retained)
    case "SH068": return try OriginalBadgerActivation.resolve(retained)
    case "SH069": return try OriginalBazaFighterActivation.resolve(retained)
    case "SH070": return try OriginalBazaMkIIActivation.resolve(retained)
    case "SH074": return try OriginalDzoActivation.resolve(retained)
    case "SH075": return try OriginalDzoMkIIActivation.resolve(retained)
    case "SH077": return try OriginalTamarawActivation.resolve(retained)
    case "SH078": return try OriginalOryxVoyagerActivation.resolve(retained)
    case "SH079": return try OriginalCarabaoCarrierActivation.resolve(retained)
    case "SH080": return try OriginalCarabaoHighlinerActivation.resolve(retained)
    case "SH081": return try OriginalJaguarActivation.resolve(retained)
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
      [ShipCatalogueRole.trader, .military, .leisure, .bountyHunter, .pirate, .transporter, .miner]
        .contains(role),
      let type = ShipCatalogueType(rawValue: definition.role), definition.playerFlyable,
      let policy = acquisitionPolicy(retained: retained, definition: definition),
      let performance = definition.nativePerformance, performance.valid(purchasePolicy: policy)
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
      catalogue: metadata(
        from: retained.catalogue, definition: definition, role: role, type: type, policy: policy),
      design: physical.model.nativeDesign, nativeHull: retained.nativeHull,
      nativeDesign: physical.model.nativeDesign, nativeCombat: retained.nativeCombat)
    guard
      ship.catalogue.valid(shipID: id, performance: performance, nativeCombat: ship.nativeCombat),
      ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles)
    else { throw Failure.invalidCatalogue }
    return ship
  }

  private static func acquisitionPolicy(
    retained: CatalogueShip, definition: OriginalFleetDefinition
  ) -> ShipCataloguePurchasePolicy? {
    switch definition.purchasePolicy {
    case "blueprintFabrication": return .blueprintFabrication
    case "never":
      let metadata = retained.catalogue
      guard definition.role == "military", metadata.purchasePolicy == .never,
        metadata.isCapital, metadata.capitalSubtype == .vessel,
        metadata.collectionMilestone == .destruction, metadata.damagePolicy == .destructible,
        !metadata.normalPurchaseEligible
      else { return nil }
      return .never
    default: return nil
    }
  }

  private static func metadata(
    from retained: ShipCatalogueMetadata, definition: OriginalFleetDefinition,
    role: ShipCatalogueRole, type: ShipCatalogueType, policy: ShipCataloguePurchasePolicy
  ) -> ShipCatalogueMetadata {
    .init(
      schemaVersion: retained.schemaVersion, family: definition.family, aliases: retained.aliases,
      objectKind: .ship, origin: .human, primaryType: type,
      primaryRole: role,
      roleWeights: [.init(role: role, weight: 1)], access: .normal, playerFlyable: true,
      normalPurchaseEligible: policy == .blueprintFabrication, purchasePolicy: policy,
      minimumBuildTechLevel: policy == .never ? nil : retained.minimumBuildTechLevel,
      isCapital: policy == .never && retained.isCapital,
      capitalSubtype: policy == .never ? retained.capitalSubtype : nil,
      collectionMilestone: policy == .never
        ? retained.collectionMilestone : .blueprintAndFabrication,
      damagePolicy: .destructible,
      habitat: retained.habitat, discoveryEligible: true, encounterMode: retained.encounterMode,
      mechanicsStatus: .ready, placementStatus: retained.placementStatus, rarity: retained.rarity,
      galaxies: retained.galaxies, regions: retained.regions,
      authoredSystems: retained.authoredSystems,
      basis:
        "Original " + definition.id + " " + definition.name
        + " " + role.rawValue
        + (policy == .never ? " capital; not for sale. " : " and blueprint-fabrication policy. ")
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
        "Original authored mechanics; retained project accommodation/fitting estimate. "
        + "Actual carried fittings and cabin footprints remain inventory-owned.", fields: fields)
  }
}
