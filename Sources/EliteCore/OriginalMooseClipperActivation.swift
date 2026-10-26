import Foundation

/// The single approved SH062 activation; other original hulls keep their own blockers.
enum OriginalMooseClipperActivation {
  static let id = "SH062"
  static let specificationSHA256 =
    "39fc71f28c9597a79b7f06ab1d1e578703bc77ff9cb9e1d2f2b823504e224833"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Moose Clipper"
      && definition.family == "moose"
      && definition.role == "transporter" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.mooseClipper.get()
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
      profiles: ship.profiles.map(originalAccommodation), game: ship.game,
      catalogue: ship.catalogue, design: ship.design, nativeHull: ship.nativeHull,
      nativeDesign: ship.nativeDesign, nativeCombat: ship.nativeCombat)
  }

  private static func originalAccommodation(_ profile: ShipProfile) -> ShipProfile {
    guard profile.group == "project-refit-v1" else { return profile }
    return .init(
      id: profile.id, title: profile.title, group: profile.group,
      context: profile.context
        + " SH062 accommodation and fitting estimates follow original-fleet E01.",
      fields: profile.fields.map { field in
        let value: Double
        let unit: String
        switch field.key {
        case "equipment_capacity_units":
          value = 88
          unit = "equipment-budget units"
        case "required_crew_including_commander", "reserved_crew_accommodation":
          value = 5
          unit = "people"
        default: return field
        }
        return .init(
          key: field.key, label: field.label, text: String(Int(value)) + " " + unit,
          number: value, unit: unit, status: "original-fleet design estimate",
          basis:
            "Meridian 8c899a7e0d351551498b05a7b371b84758575085 / "
            + "docs/meridian/SHIP-REFERENCE.md SH062 E01: cargo396, size tier3, equipment88, operating crew5 and intrinsic places5; "
            + "capacity estimates; no people or equipment are issued.")
      })
  }
}
