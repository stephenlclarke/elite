import Foundation

/// The single approved SH043 activation; other original hulls keep their own blockers.
enum OriginalEagleCruiserActivation {
  static let id = "SH043"
  static let specificationSHA256 =
    "eb40037811544aa169c98bbb7246e50472d63e6272a0c65d21b8a16a794b09f1"

  enum Failure: Error { case unsupportedDefinition }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    definition.id == id && definition.name == "Eagle Cruiser"
      && definition.family == "eagle"
      && definition.role == "military" && definition.playerFlyable
      && definition.purchasePolicy == "never"
      && definition.sourceSHA256 == specificationSHA256 && definition.approvedMeshAvailable
      && definition.nativePerformance?.valid(purchasePolicy: .never) == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard retained.id == id else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: id),
      supports(definition)
    else { throw Failure.unsupportedDefinition }
    let physical = try OriginalHullPhysicalContract.eagleCruiser.get()
    guard physical.specificationSHA256 == specificationSHA256,
      physical.metresPerSourceUnit == 1,
      physical.model.coordinateUnits == "metres"
    else { throw Failure.unsupportedDefinition }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
