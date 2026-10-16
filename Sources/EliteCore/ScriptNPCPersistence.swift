import Foundation

extension Game {
  /// Save the same shot and launch archive in the existing station-relative frame.
  mutating func persistScriptShots(anchor: SpaceBody, unloading: Bool) {
    for body in bodies {
      guard let shot = body.scriptShot else { continue }
      if body.energy <= 0 {
        commander.scriptState.projectiles.removeValue(forKey: shot.identity)
      } else {
        persistScriptShot(body, anchor: anchor, presence: unloading ? .unloaded : .present)
      }
    }
  }

  mutating func recordScriptShotRemoval(_ body: SpaceBody) {
    guard let shot = body.scriptShot else { return }
    if body.energy <= 0 {
      commander.scriptState.projectiles.removeValue(forKey: shot.identity)
    } else if let anchor = scriptAnchor {
      // A newly emitted living shot may leave the bubble before the first save. Preserve its
      // actual last pose and tuning rather than requiring a previously published record.
      persistScriptShot(body, anchor: anchor, presence: .outside)
    } else {
      commander.scriptState.projectiles[shot.identity]?.presence = .outside
    }
  }

  private mutating func persistScriptShot(
    _ body: SpaceBody, anchor: SpaceBody, presence: ScriptActorPresence
  ) {
    guard let shot = body.scriptShot else { return }
    var canonical = body
    canonical.position = anchor.orientation.inverse(body.position - anchor.position)
    canonical.orientation = body.orientation.relative(to: anchor.orientation)
    canonical.scriptShot?.velocity = anchor.orientation.inverse(shot.velocity)
    // Archive identity and historical origin are immutable; only physical coordinates transform.
    commander.scriptState.projectiles[shot.identity] = .init(
      galaxy: commander.galaxy, system: commander.system, body: canonical, presence: presence)
  }
}
