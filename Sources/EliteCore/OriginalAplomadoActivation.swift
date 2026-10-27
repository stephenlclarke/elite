import Foundation

/// The single approved SH056 activation; other original hulls keep their own blockers.
enum OriginalAplomadoActivation {
  static let id = "SH056"
  static let specificationSHA256 =
    "92bb47688401917bfafd91820264e5f6a20387a5d5a0b44ad7efeaeb939bd786"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Aplomado Interceptor"
      && definition.family == "aplomado"
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
    let physical = try OriginalHullPhysicalContract.aplomado.get()
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
        + " SH056 accommodation and fitting estimates follow original-fleet E01.",
      fields: profile.fields.map { field in
        let value: Double
        let unit: String
        switch field.key {
        case "required_crew_including_commander", "reserved_crew_accommodation":
          value = 1
          unit = "people"
        default: return field
        }
        return .init(
          key: field.key, label: field.label, text: String(Int(value)) + " " + unit,
          number: value, unit: unit, status: "original-fleet design estimate",
          basis:
            "Meridian 8c899a7e0d351551498b05a7b371b84758575085 / "
            + "docs/meridian/SHIP-REFERENCE.md SH056 E01: cargo18, size tier2, equipment12, operating crew1 and intrinsic places1; "
            + "capacity estimates; no people or equipment are issued.")
      })
  }
}
