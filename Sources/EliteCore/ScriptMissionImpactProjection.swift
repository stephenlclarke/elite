import Foundation

extension Game {
  /// Consume once immediately after the native kernel, before body culling and event draining.
  /// The receipt records a real effect; this projection never applies physical damage or law.
  mutating func projectScriptMissionImpact(_ receipt: NativeMissionImpactReceipt) {
    if let shot = receipt.terminalShotID {
      commander.scriptState.projectiles.removeValue(forKey: shot)
    }
    if receipt.damageAdmitted,
      let instance = receipt.targetMissionInstanceID, let actor = receipt.targetMissionActorID,
      receipt.damage.isFinite, receipt.damage > 0
    {
      var values: [String: ScriptValue] = [
        "actor_id": .string(actor.uuidString), "amount": .number(receipt.damage),
        "player": .bool(receipt.player),
        "attacker_id": receipt.player
          ? .null : receipt.sourceActorID.map { .string($0.uuidString) } ?? .null,
      ]
      if let component = receipt.victimPart, let identity = receipt.victimComponentID {
        values["component"] = .string(component)
        values["component_id"] = .string(identity.uuidString)
      }
      emitScriptEvent("actor.damaged", values: values, only: instance, drain: false)
      if receipt.componentDestroyed,
        receipt.victimPart != nil, receipt.victimComponentID != nil
      {
        emitScriptEvent("component.destroyed", values: values, only: instance, drain: false)
      }
    }
    if receipt.hullDestroyed, let id = receipt.targetBodyID,
      let body = bodies.first(where: { $0.id == id }), body.energy <= 0
    {
      // Existing retained-actor guards and world-resource cancellation keep terminal recording
      // idempotent when the later native cull reports this same actual destroyed body.
      recordScriptActorRemoval(body, destroyed: true)
    }
  }
}
