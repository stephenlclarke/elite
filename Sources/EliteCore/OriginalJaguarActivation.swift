import Foundation

/// The single approved SH081 activation; other original hulls keep their own blockers.
enum OriginalJaguarActivation {
  static let id = "SH081"
  static let specificationSHA256 =
    "5e326c8f2b7f67e55a3575a3144043de71b7a6c07e3939342a047a02c9efb82e"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Jaguar"
      && definition.family == "jaguar"
      && definition.role == "military" && definition.playerFlyable
      && definition.purchasePolicy == "never"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.price == 0
      && definition.nativePerformance?.valid(purchasePolicy: .never) == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.jaguar.get()
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
        + " SH081 accommodation and fitting estimates follow original-fleet E01.",
      fields: profile.fields.map { field in
        let value: Double
        let unit: String
        switch field.key {
        case "equipment_capacity_units":
          value = 37
          unit = "equipment-budget units"
        case "required_crew_including_commander", "reserved_crew_accommodation":
          value = 6
          unit = "people"
        default: return field
        }
        return .init(
          key: field.key, label: field.label, text: String(Int(value)) + " " + unit,
          number: value, unit: unit, status: "original-fleet design estimate",
          basis:
            "Meridian 8c899a7e0d351551498b05a7b371b84758575085 / "
            + "docs/meridian/SHIP-REFERENCE.md SH081 E01: cargo144, size tier5, equipment37, operating crew6 and intrinsic places6; "
            + "capacity estimates; no people or equipment are issued.")
      })
  }
}
