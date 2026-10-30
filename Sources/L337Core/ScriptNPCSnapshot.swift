import Foundation

extension Vector3 {
  var scriptVector: ScriptValue { .array([.number(x), .number(y), .number(z)]) }
}

extension Game {
  func scriptNPCSnapshot(_ npc: ScriptNPCState?) -> ScriptValue {
    guard let npc else { return .null }
    func guns(_ values: [String: ScriptNPCGunState]) -> ScriptValue {
      .object(
        values.mapValues {
          .object([
            "cooldown": .number($0.cooldown), "heat": .number($0.heat),
            "aim": $0.aim?.scriptVector ?? .null,
          ])
        })
    }
    return .object([
      "name": .string(npc.fit.definition.name),
      "source": .string(npc.fit.definition.source), "basis": .string(npc.fit.definition.basis),
      "velocity": npc.velocity.scriptVector, "fuel": .number(npc.fuel),
      "maximum_speed": .number(npc.fit.definition.speed), "shots": .integer(Int64(npc.shots)),
      "intent": npc.intent.map {
        .object([
          "request": .string($0.request), "mode": .string($0.mode.rawValue),
          "status": .string($0.status.rawValue),
          "target": $0.target.map { .string($0.uuidString) } ?? .null,
          "player": .bool($0.player),
        ])
      } ?? .null,
      "guns": guns(npc.guns),
      "components": .object(
        npc.components.mapValues {
          .object([
            "identity": .string($0.identity.uuidString), "energy": .number($0.energy),
            "guns": guns($0.guns),
          ])
        }),
    ])
  }
}
