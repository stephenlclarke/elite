import Foundation

public enum PlayerAmmunitionSource: Equatable, Codable, Sendable {
  case physical(item: UUID)
  case virtualUnlimited
}
