import Foundation

/// Only the two individually approved Command and Patrol registrations.
enum OriginalGyrfalconFamilyActivation {
  struct Registration: Sendable {
    let id: String
    let name: String
    let specificationSHA256: String
    let modelSHA256: String
    var modelPath: String {
      "fleet-completion-20261019/batch-01-native-lod/" + id + "-design.toml"
    }
  }

  static func registration(for id: String) -> Registration? {
    switch id {
    case "SH003":
      return .init(
        id: id, name: "Gyrfalcon Command",
        specificationSHA256: "9d27c7a3cb17e63a44b95a3c2d760e05634407750539d339a31169146b8701b2",
        modelSHA256: "fb28b8fbf3ac54e12bd0513f70ab6ca9140e8c361086b42bc3bfe5e71b91a90a")
    case "SH004":
      return .init(
        id: id, name: "Gyrfalcon Patrol",
        specificationSHA256: "aa14680c9e193b217bc6c72ece2aa63ccb98482880f9425087a7f6322211ba0f",
        modelSHA256: "aa7bd053625093d77bdb1414e43c77278e68f1bbb6db3ab37c409700bcdcfeb5")
    default: return nil
    }
  }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    guard let approved = registration(for: definition.id) else { return false }
    return definition.name == approved.name && definition.family == "gyrfalcon"
      && definition.role == "military" && definition.playerFlyable
      && definition.purchasePolicy == "blueprintFabrication"
      && definition.sourceSHA256 == approved.specificationSHA256
      && definition.approvedMeshAvailable && definition.nativePerformance?.valid == true
  }

  static func resolve(_ retained: CatalogueShip) throws -> CatalogueShip {
    guard registration(for: retained.id) != nil else { return retained }
    guard let definition = OriginalFleetDefinitionData.definition(for: retained.id),
      supports(definition)
    else { throw OriginalHullPhysicalContract.Failure.unsupportedSource }
    let physical: OriginalHullPhysicalContract
    switch retained.id {
    case "SH003": physical = try OriginalHullPhysicalContract.gyrfalconCommand.get()
    case "SH004": physical = try OriginalHullPhysicalContract.gyrfalconPatrol.get()
    default: throw OriginalHullPhysicalContract.Failure.unsupportedSource
    }
    return try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
  }
}
