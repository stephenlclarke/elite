import Foundation

/// A finite owned round uses the existing pylon and consumption transactions.
enum AlienMissileDefinition {
  static let name = "Alien Seeker Missile"
  static let node = EquipmentNodeID(
    family: EquipmentRuntimeCatalog.ammunitionFamily, key: "missile-alien-seeker")
  static let repeatPriceTenths = 600
  static var recipe: SalvageAlienRecipe { SalvageAlienDefinitions.recipe(.seekerMissile) }

  static func isResearchSource(_ lot: SalvageLot) -> Bool {
    guard case .technology(let definition, _, _) = lot.content else { return false }
    return definition == recipe.requiredDefinitionID && lot.loot?.provenance == .alien
      && lot.loot?.effect == .researchAndSale
  }

  static func profile(for node: EquipmentNodeID) -> OrdnanceProfile? {
    if node == EquipmentRuntimeCatalog.standardMissile { return .standardMissile }
    if node == self.node { return .alienSeeker }
    return nil
  }
}
