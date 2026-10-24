import Foundation

/// Reasons behind the existing generic protection set, derived from the current body only.
struct GameplayActorProtectionReasons: OptionSet, Sendable {
  let rawValue: UInt8
  static let empCrewPod = Self(rawValue: 1 << 0)
  static let navalTarget = Self(rawValue: 1 << 1)
  static let blackjackRole = Self(rawValue: 1 << 2)
  static let missionNPC = Self(rawValue: 1 << 3)
  static let missionInstance = Self(rawValue: 1 << 4)
}

extension SpaceBody {
  var gameplayProtectionReasons: GameplayActorProtectionReasons {
    var reasons: GameplayActorProtectionReasons = []
    if physical?.empCrewPod != nil { reasons.insert(.empCrewPod) }
    if navalTarget { reasons.insert(.navalTarget) }
    if blackjackRole != nil { reasons.insert(.blackjackRole) }
    if physical?.npc?.role == .mission { reasons.insert(.missionNPC) }
    if missionInstanceID != nil { reasons.insert(.missionInstance) }
    return reasons
  }
}
