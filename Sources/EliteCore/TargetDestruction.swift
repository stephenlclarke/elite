extension Game {
  mutating func clearRemovedTarget(_ body: SpaceBody) {
    guard autoPilot.targetID == body.id || weaponsTargetID == body.id else { return }
    if autoPilot.targetID == body.id { cancelAutoTarget() }
    if weaponsTargetID == body.id { weaponsTargetID = nil }
    notify(body.destroyedByPlayer == true ? "TARGET DESTROYED - YOUR KILL" : "TARGET LOST")
  }
}
