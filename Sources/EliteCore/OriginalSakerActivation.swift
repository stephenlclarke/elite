import Foundation

/// The single approved SH042 activation; other original hulls keep their own blockers.
enum OriginalSakerActivation {
  static let id = "SH042"
  static let specificationSHA256 =
    "6ec7baa6ca072273a2195afaa992512ca59aa9e176daead003112d025eba8c92"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Saker"
      && definition.family == "saker"
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
    let physical = try OriginalHullPhysicalContract.saker.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1,
      physical.model.coordinateUnits == "metres"
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
