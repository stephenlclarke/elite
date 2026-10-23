import Foundation

/// Exact current-body validation without materialising two Optional<SpaceBody> values.
/// Borrowed field groups finish before the caller enters the geometric sweep.
enum NativeStationSnapshot {
  @inline(never)
  static func matches(_ expected: borrowing SpaceBody, in bodies: borrowing [SpaceBody]) -> Bool {
    var found: Int?
    for index in bodies.indices where bodies[index].id == expected.id {
      guard found == nil else { return false }
      found = index
    }
    guard let found else { return false }
    return equal(expected, bodies[found])
  }

  @inline(never)
  private static func equal(_ lhs: borrowing SpaceBody, _ rhs: borrowing SpaceBody) -> Bool {
    guard geometry(lhs, rhs) else { return false }
    guard gameplay(lhs, rhs) else { return false }
    guard mission(lhs, rhs) else { return false }
    return native(lhs, rhs)
  }

  @inline(never)
  private static func geometry(_ lhs: borrowing SpaceBody, _ rhs: borrowing SpaceBody) -> Bool {
    guard lhs.id == rhs.id else { return false }
    guard lhs.hull == rhs.hull else { return false }
    guard lhs.position == rhs.position else { return false }
    guard lhs.rotation == rhs.rotation else { return false }
    guard lhs.orientation == rhs.orientation else { return false }
    guard lhs.rotationRate == rhs.rotationRate else { return false }
    return true
  }

  @inline(never)
  private static func gameplay(_ lhs: borrowing SpaceBody, _ rhs: borrowing SpaceBody) -> Bool {
    guard lhs.energy == rhs.energy else { return false }
    guard lhs.hostile == rhs.hostile else { return false }
    guard lhs.navalTarget == rhs.navalTarget else { return false }
    guard lhs.missiles == rhs.missiles else { return false }
    guard lhs.playerMissileTarget == rhs.playerMissileTarget else { return false }
    guard lhs.enemyMissile == rhs.enemyMissile else { return false }
    guard lhs.missileSourceID == rhs.missileSourceID else { return false }
    guard lhs.destroyedByPlayer == rhs.destroyedByPlayer else { return false }
    return true
  }

  @inline(never)
  private static func mission(_ lhs: borrowing SpaceBody, _ rhs: borrowing SpaceBody) -> Bool {
    guard lhs.missionActorID == rhs.missionActorID else { return false }
    guard lhs.missionInstanceID == rhs.missionInstanceID else { return false }
    guard lhs.blackjackIdentity == rhs.blackjackIdentity else { return false }
    guard lhs.blackjackRole == rhs.blackjackRole else { return false }
    guard lhs.blackjackLaserCooldown == rhs.blackjackLaserCooldown else { return false }
    return true
  }

  @inline(never)
  private static func native(_ lhs: borrowing SpaceBody, _ rhs: borrowing SpaceBody) -> Bool {
    guard lhs.scriptNPC == rhs.scriptNPC else { return false }
    guard lhs.scriptShot == rhs.scriptShot else { return false }
    guard lhs.ecmEnabled == rhs.ecmEnabled else { return false }
    guard lhs.physical == rhs.physical else { return false }
    guard lhs.nativeStationIdentity == rhs.nativeStationIdentity else { return false }
    return true
  }
}
