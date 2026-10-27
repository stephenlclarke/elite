import Foundation

/// The single approved SH057 activation; other original hulls keep their own blockers.
enum OriginalFalconetActivation {
  static let id = "SH057"
  static let specificationSHA256 =
    "96e8038ebb2a3545c430869bfd9d76acfafe0c772275a89f9e448780d76cf482"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Falconet"
      && definition.family == "falconet"
      && definition.role == "military" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.falconet.get()
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
      profiles: ship.profiles.map(originalCrewEstimate), game: ship.game,
      catalogue: ship.catalogue, design: ship.design, nativeHull: ship.nativeHull,
      nativeDesign: ship.nativeDesign, nativeCombat: ship.nativeCombat)
  }

  private static func originalCrewEstimate(_ profile: ShipProfile) -> ShipProfile {
    guard profile.group == "project-refit-v1" else { return profile }
    return .init(
      id: profile.id, title: profile.title, group: profile.group,
      context: profile.context + " SH057 crew and quarters estimates follow original-fleet E01.",
      fields: profile.fields.map { field in
        guard
          ["required_crew_including_commander", "reserved_crew_accommodation"].contains(field.key)
        else { return field }
        return .init(
          key: field.key, label: field.label, text: "1 person", number: 1,
          unit: "people", status: "original-fleet design estimate",
          basis:
            "Meridian 8c899a7e0d351551498b05a7b371b84758575085 / "
            + "docs/meridian/SHIP-REFERENCE.md SH057 E01: one operating crew place and one intrinsic crew place; "
            + "crew/accommodation estimate; no people are issued.")
      })
  }
}
