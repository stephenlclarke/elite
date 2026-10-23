import Foundation

/// The single approved SH007 activation; other original hulls keep their own blockers.
enum OriginalImpalaVoyagerActivation {
  static let id = "SH007"
  static let specificationSHA256 =
    "a75681f60d15795e2db03b783671fbe3d572bfd75a39f62658a7dca09ac666ea"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Impala Voyager"
      && definition.family == "impala"
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
    let physical = try OriginalHullPhysicalContract.impalaVoyager.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1,
      physical.model.coordinateUnits == "metres"
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
