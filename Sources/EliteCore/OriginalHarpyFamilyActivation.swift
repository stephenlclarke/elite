import Foundation

/// Only these three authenticated Harpy variants share this original-family projection.
enum OriginalHarpyFamilyActivation {
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
    case "SH044":
      return .init(
        id: id, name: "Harpy Assault",
        specificationSHA256: "573f32a6b6f32e1b6152572725264d4e044d524c423d9ab1b83cc24d4ab3ac69",
        modelSHA256: "6221e902c9893e7c3e9b9557e7f3331dc95da26282b76c1edfdbeba8f9f94f25")
    case "SH046":
      return .init(
        id: id, name: "Harpy Dropship",
        specificationSHA256: "22887ffdc80bcc21897d2a14ca65f7c4db2e3a862208e9050f1a1d32cef93f9d",
        modelSHA256: "2619b8ca62cad610226c8f3862882d17de9b6b83186c192eb0e099dc66eb1c4f")
    case "SH047":
      return .init(
        id: id, name: "Harpy Gunship",
        specificationSHA256: "4186c90ac3c6e695df1f27ff02bc3b37f53ac608d9c323490dd3dc015cdfbca2",
        modelSHA256: "7cb0dad60b3f677c8710677403cba2213ffd5bfb1a7ee1a2d2b012cacc381dd7")
    default: return nil
    }
  }

  static func supports(_ definition: OriginalFleetDefinition) -> Bool {
    guard let approved = registration(for: definition.id) else { return false }
    return definition.name == approved.name && definition.family == "harpy"
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
    case "SH044": physical = try OriginalHullPhysicalContract.harpyAssault.get()
    case "SH046": physical = try OriginalHullPhysicalContract.harpyDropship.get()
    case "SH047": physical = try OriginalHullPhysicalContract.harpyGunship.get()
    default: throw OriginalHullPhysicalContract.Failure.unsupportedSource
    }
    let ship = try OriginalPlayerHullActivation.resolve(
      retained, definition: definition, physical: physical)
    return .init(
      id: ship.id, name: ship.name, shipClass: ship.shipClass, appearances: ship.appearances,
      evidence: ship.evidence, refit: ship.refit, model: ship.model, modelSource: ship.modelSource,
      dimensions: ship.dimensions, geometryContext: ship.geometryContext,
      profiles: ship.profiles.map(originalEquipmentBudget), game: ship.game,
      catalogue: ship.catalogue, design: ship.design, nativeHull: ship.nativeHull,
      nativeDesign: ship.nativeDesign, nativeCombat: ship.nativeCombat)
  }

  private static func originalEquipmentBudget(_ profile: ShipProfile) -> ShipProfile {
    guard profile.group == "project-refit-v1" else { return profile }
    return .init(
      id: profile.id, title: profile.title, group: profile.group,
      context: profile.context + " Harpy equipment budget follows original-fleet E01.",
      fields: profile.fields.map { field in
        guard field.key == "equipment_capacity_units" else { return field }
        return .init(
          key: field.key, label: field.label, text: "12 equipment-budget units", number: 12,
          unit: "equipment-budget units", status: "original-fleet design estimate",
          basis:
            "Meridian 8c899a7e0d351551498b05a7b371b84758575085 / "
            + "docs/meridian/SHIP-REFERENCE.md SH044/SH046/SH047 E01: 8 + ceil(16 / 5) = 12; "
            + "original-hull capacity estimate; no equipment is issued.")
      })
  }
}
