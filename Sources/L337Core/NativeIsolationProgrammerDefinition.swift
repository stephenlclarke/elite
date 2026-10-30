import Foundation

/// The single physical loan. It is held equipment, never a shop offer or a fitted weapon.
enum NativeIsolationProgrammerDefinition {
  static let resource = "g11-isolation-programmer"
  static let name = "Lerr Isolation Programmer"
  static let node = EquipmentNodeID(family: .init("g11-programmer"), key: name)
  static let cargoTonnes = 1
  static let location = SystemIdentity(galaxy: 0, system: 7)
  static let purchaseNode = EquipmentPurchaseNode(
    id: node, displayName: name, policy: .acquisitionOnly)
  static let gear = ScriptGearDefinition(
    id: resource, name: name, quantity: 1, loan: true, mount: nil, returnPolicy: "all")

  static func issuer(owner: UUID) -> UUID {
    ScriptIdentity.uuid("g11-lerr-utility-owner-v1:\(owner)")
  }

  static func serial(parent: UUID) -> UUID {
    OwnedGear.issuedIdentity(mission: parent, resource: resource, index: 0)
  }

  /// Count physical property, including held property, without trusting a mission label.
  static func occupiedTonnes(in inventory: OwnedEquipmentInventory?) -> Int {
    inventory?.items.filter { $0.node == node }.count ?? 0
  }
}
