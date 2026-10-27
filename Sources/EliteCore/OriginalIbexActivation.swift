import Foundation

/// The single approved SH027 activation; other original hulls keep their own blockers.
enum OriginalIbexActivation {
  static let id = "SH027"
  static let specificationSHA256 =
    "8683efc69a92c85add48be7022fa1a76040b4407413c5c2a349156d47425b2ed"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Ibex"
      && definition.family == "ibex"
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
    let physical = try OriginalHullPhysicalContract.ibex.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1,
      physical.model.coordinateUnits == "metres"
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
