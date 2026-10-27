import Foundation

/// The single approved SH065 activation; other original hulls keep their own blockers.
enum OriginalVultureRaiderActivation {
  static let id = "SH065"
  static let specificationSHA256 =
    "24bd731a4b4e35b11e20b541d6159cc98cdd79658a7cd7c45c290570f5206ff9"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Vulture Raider"
      && definition.family == "vulture"
      && definition.role == "pirate" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.vultureRaider.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1,
      physical.model.coordinateUnits == "metres"
    else { throw Failure.unsupportedDefinition }
    let ship = try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
    return .init(
      id: ship.id, name: ship.name, shipClass: ship.shipClass, appearances: ship.appearances,
      evidence: ship.evidence, refit: ship.refit, model: ship.model, modelSource: ship.modelSource,
      dimensions: ship.dimensions, geometryContext: ship.geometryContext,
      profiles: ship.profiles.map(originalEquipmentBudget), game: ship.game,
      catalogue: retainedPiratePreference(ship.catalogue), design: ship.design,
      nativeHull: ship.nativeHull,
      nativeDesign: ship.nativeDesign, nativeCombat: ship.nativeCombat)
  }

  /// Keep SH065's existing eightfold pirate preference; actor intent remains separately owned.
  private static func retainedPiratePreference(_ metadata: ShipCatalogueMetadata)
    -> ShipCatalogueMetadata
  {
    .init(
      schemaVersion: metadata.schemaVersion, family: metadata.family, aliases: metadata.aliases,
      objectKind: metadata.objectKind, origin: metadata.origin, primaryType: metadata.primaryType,
      primaryRole: metadata.primaryRole, roleWeights: [.init(role: .pirate, weight: 8)],
      access: metadata.access, playerFlyable: metadata.playerFlyable,
      normalPurchaseEligible: metadata.normalPurchaseEligible,
      purchasePolicy: metadata.purchasePolicy,
      minimumBuildTechLevel: metadata.minimumBuildTechLevel, isCapital: metadata.isCapital,
      capitalSubtype: metadata.capitalSubtype, collectionMilestone: metadata.collectionMilestone,
      damagePolicy: metadata.damagePolicy, habitat: metadata.habitat,
      discoveryEligible: metadata.discoveryEligible, encounterMode: metadata.encounterMode,
      mechanicsStatus: metadata.mechanicsStatus, placementStatus: metadata.placementStatus,
      rarity: metadata.rarity, galaxies: metadata.galaxies, regions: metadata.regions,
      authoredSystems: metadata.authoredSystems, basis: metadata.basis)
  }

  private static func originalEquipmentBudget(_ profile: ShipProfile) -> ShipProfile {
    guard profile.group == "project-refit-v1" else { return profile }
    return .init(
      id: profile.id, title: profile.title, group: profile.group,
      context: profile.context + " SH065 equipment budget follows original-fleet E01.",
      fields: profile.fields.map { field in
        guard field.key == "equipment_capacity_units" else { return field }
        return .init(
          key: field.key, label: field.label, text: "11 equipment-budget units", number: 11,
          unit: "equipment-budget units", status: "original-fleet design estimate",
          basis:
            "Meridian 8c899a7e0d351551498b05a7b371b84758575085 / "
            + "docs/meridian/SHIP-REFERENCE.md SH065 E01: 8 + ceil(14 / 5) = 11; "
            + "original-hull capacity estimate; no equipment is issued.")
      })
  }
}
