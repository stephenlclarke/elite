import Foundation

public struct ScriptProjectileRecord: Codable, Sendable, Equatable {
  public let galaxy: Int
  public let system: Int
  public var body: SpaceBody
  public var presence: ScriptActorPresence
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system) && body.scriptShot?.valid == true
      && body.scriptNPC == nil && body.missionActorID == nil && body.missionInstanceID == nil
      && body.hull == .missile && body.position.finite && body.position.length <= 1e9
      && body.orientation.validRotation && body.energy > 0 && body.energy.isFinite
      && (0..<1_000_000_000).contains(body.id)
      && [.present, .outside, .unloaded].contains(presence)
  }
}

extension SpaceBody {
  var scriptNativeUnits: Int {
    1
      + (scriptNPC?.fit.definition.components ?? []).filter {
        $0.solid && (scriptNPC?.components[$0.id]?.energy ?? 0) > 0
      }.count
  }
}

extension Game {
  mutating func persistScriptShots(anchor: SpaceBody, unloading: Bool) {
    for body in bodies {
      guard let shot = body.scriptShot else { continue }
      if body.energy <= 0 {
        commander.scriptState.projectiles.removeValue(forKey: shot.identity)
        continue
      }
      var canonical = body
      canonical.position = anchor.orientation.inverse(body.position - anchor.position)
      canonical.orientation = body.orientation.relative(to: anchor.orientation)
      canonical.scriptShot?.velocity = anchor.orientation.inverse(shot.velocity)
      commander.scriptState.projectiles[shot.identity] = .init(
        galaxy: commander.galaxy,
        system: commander.system, body: canonical, presence: unloading ? .unloaded : .present)
    }
  }
  mutating func recordScriptShotRemoval(_ body: SpaceBody) {
    guard let shot = body.scriptShot else { return }
    if body.energy <= 0 {
      commander.scriptState.projectiles.removeValue(forKey: shot.identity)
    } else {
      commander.scriptState.projectiles[shot.identity]?.presence = .outside
    }
  }
  mutating func restoreScriptShots(anchor: SpaceBody) {
    let present = Set(bodies.compactMap { $0.scriptShot?.identity })
    for key in commander.scriptState.projectiles.keys.sorted(by: { $0.uuidString < $1.uuidString })
    {
      guard var record = commander.scriptState.projectiles[key], record.galaxy == commander.galaxy,
        record.system == commander.system, !present.contains(key),
        let shot = record.body.scriptShot,
        let instance = commander.scriptState.instances[shot.instance],
        scriptPack(for: instance) != nil,
        bodies.reduce(0, { $0 + $1.scriptNativeUnits }) < 1024, nextBodyID < 999_999_999
      else { continue }
      var body = record.body
      body.position = anchor.position + anchor.orientation.apply(body.position)
      body.orientation = body.orientation.transformed(by: anchor.orientation)
      body.scriptShot?.velocity = anchor.orientation.apply(shot.velocity)
      guard !body.leavesLocalBubble else { continue }
      body.id = nextBodyID
      nextBodyID += 1
      bodies.append(body)
      record.body.id = body.id
      record.presence = .present
      commander.scriptState.projectiles[key] = record
    }
  }
}
