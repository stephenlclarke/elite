import Foundation

/// The single approved SH101 activation; other original hulls keep their own blockers.
enum OriginalDorcasRacerActivation {
  static let id = "SH101"
  static let specificationSHA256 =
    "a5d9bd1d8480634ed6b4512c339c6048748b41f5bd4e3d292b1cdfc8ad2f3785"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Dorcas Racer"
      && definition.family == "dorcas-racer"
      && definition.role == "leisure" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.dorcasRacer.get()
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
      catalogue: ship.catalogue, design: ship.design, nativeHull: ship.nativeHull,
      nativeDesign: ship.nativeDesign, nativeCombat: ship.nativeCombat)
  }

  private static func originalEquipmentBudget(_ profile: ShipProfile) -> ShipProfile {
    guard profile.group == "project-refit-v1" else { return profile }
    return .init(
      id: profile.id, title: profile.title, group: profile.group,
      context: profile.context + " SH101 equipment budget follows original-fleet E01.",
      fields: profile.fields.map { field in
        guard field.key == "equipment_capacity_units" else { return field }
        return .init(
          key: field.key, label: field.label, text: "14 equipment-budget units", number: 14,
          unit: "equipment-budget units", status: "original-fleet design estimate",
          basis:
            "Meridian 8c899a7e0d351551498b05a7b371b84758575085 / "
            + "docs/meridian/SHIP-REFERENCE.md SH101 E01: 8 + ceil(26 / 5) = 14; "
            + "original-hull capacity estimate; no equipment is issued.")
      })
  }
}
