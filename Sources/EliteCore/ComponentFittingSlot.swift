import Foundation

/// A quoted fit identifies a real slot on one owned hull, including vacant slots.
public enum ComponentFittingSlot: Hashable, Codable, Sendable {
  case shield, energy, navigation, targetingCore, targetingMining, targetingSalvage, drive
  case laser(LaserMount)
  case missilePylon(Int)
  case utility(ComponentUtility)
  case fuelStorage(Int)
  case spareEscapePod(Int)
  case hullStructure

  public var valid: Bool {
    switch self {
    case .missilePylon(let index): (0..<32).contains(index)
    case .fuelStorage(let index): (0..<FuelStorage.maximumCount).contains(index)
    case .spareEscapePod(let index): (0..<2).contains(index)
    default: true
    }
  }
}

public enum ComponentUtility: String, Hashable, Codable, Sendable {
  case miningLaser, salvageCutter, fuelScoops, ecm, escapePod, energyBomb, cargoExpansion,
    galacticHyperdrive
}

public struct ComponentFittingLocation: Hashable, Codable, Sendable {
  public let hullInstanceID: UUID
  public let slot: ComponentFittingSlot
  public init(hullInstanceID: UUID, slot: ComponentFittingSlot) {
    self.hullInstanceID = hullInstanceID
    self.slot = slot
  }
}
