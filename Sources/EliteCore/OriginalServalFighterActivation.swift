import Foundation

/// The single approved SH041 activation; other original hulls keep their own blockers.
enum OriginalServalFighterActivation {
  static let id = "SH041"
  static let specificationSHA256 =
    "eb4fd7cee87979618eac213914f9b764bcd016c7aba19385418fdb1b57406344"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Serval Fighter"
      && definition.family == "serval"
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
    let physical = try OriginalHullPhysicalContract.servalFighter.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1,
      physical.model.coordinateUnits == "metres"
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
