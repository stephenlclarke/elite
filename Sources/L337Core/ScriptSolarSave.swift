import Foundation

struct ScriptCelestialSave: Codable, Sendable {
  let kind: String
  let position: Vector3
  let radius: Double
  var valid: Bool {
    CelestialKind(rawValue: kind) != nil && radius.isFinite && (0.001...1e9).contains(radius)
      && [position.x, position.y, position.z].allSatisfy { $0.isFinite && abs($0) <= 1e12 }
  }
}
struct ScriptSolarSave: Codable, Sendable {
  let bodies: [ScriptCelestialSave]
  let fuelRemainder: Double
  let scoopState: String
  init(game: Game) {
    bodies = game.celestials.map {
      .init(kind: $0.kind.rawValue, position: $0.position, radius: $0.radius)
    }
    fuelRemainder = game.solarFuelRemainder
    switch game.solarScoopState {
    case .inactive: scoopState = "inactive"
    case .noScoops: scoopState = "noScoops"
    case .turnTowardSun: scoopState = "turnTowardSun"
    case .collecting: scoopState = "collecting"
    case .tankFull: scoopState = "tankFull"
    }
  }
  var valid: Bool {
    bodies.count <= 32 && bodies.allSatisfy(\.valid)
      && fuelRemainder.isFinite && (0...1).contains(fuelRemainder)
      && ["inactive", "noScoops", "turnTowardSun", "collecting", "tankFull"].contains(scoopState)
  }
  func restore(into game: inout Game) {
    game.celestials = bodies.compactMap { saved in
      CelestialKind(rawValue: saved.kind).map {
        .init(kind: $0, position: saved.position, radius: saved.radius)
      }
    }
    game.solarFuelRemainder = fuelRemainder
    switch scoopState {
    case "noScoops": game.solarScoopState = .noScoops
    case "turnTowardSun": game.solarScoopState = .turnTowardSun
    case "collecting": game.solarScoopState = .collecting
    case "tankFull": game.solarScoopState = .tankFull
    default: game.solarScoopState = .inactive
    }
  }
}
