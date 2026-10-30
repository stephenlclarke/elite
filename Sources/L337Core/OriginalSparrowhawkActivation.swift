import Foundation

/// The single approved SH030 activation; other original hulls keep their own blockers.
enum OriginalSparrowhawkActivation {
  static let id = "SH030"
  static let specificationSHA256 =
    "f069a8d048fe7eb978673a2229d420a79eba020505157a7bd941d8beb8007fb1"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Sparrowhawk"
      && definition.family == "sparrowhawk"
      && definition.role == "bountyHunter" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.sparrowhawk.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1,
      physical.model.coordinateUnits == "metres"
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
