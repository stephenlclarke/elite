import Foundation

/// The single approved SH061 activation; other original hulls keep their own blockers.
enum OriginalHaflingerActivation {
  static let id = "SH061"
  static let specificationSHA256 =
    "71000f32ab2cc28cacc3406e49bee33550fb339f89d43a64e04dad3a15ca46db"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Haflinger" && definition.family == "haflinger"
      && definition.role == "trader" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.haflinger.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 20,
      physical.model.coordinateUnits == nil
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
