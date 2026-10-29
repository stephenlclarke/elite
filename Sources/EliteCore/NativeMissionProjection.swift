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
  var scriptPlayerMesh: Mesh {
    commander.ship.nativeDesign?.rawMesh ?? commander.ship.design.rawMesh
  }
}
