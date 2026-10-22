import Foundation

extension Display {
  /// The portrait exporter calls Frame.label directly, not this live cockpit wrapper.
  /// Live tutorial overlays therefore do not alter ship-portrait renderer inputs.
  static func defensiveFlightCockpit(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    guard let active = game.activeDefensiveFlight else { return frame }
    let layout = CockpitLayout(game: game, width: width, height: height)
    let state = active.state
    let phase = state.windows.count
    let stages = [
      "MANUAL PRACTICE REFERENCE", "GATE A: RIGHT", "GATE B: REVERSE LEFT", "WITHDRAW: NOSE AWAY",
    ]
    var lines: [String]
    if state.failure != nil {
      lines = ["DEFENSIVE PRACTICE FAILED - NO AWARD"]
    } else if state.ready {
      lines = ["DEFENSIVE PRACTICE READY - RECEIVE AT AVENOR"]
    } else {
      lines = [stages[min(phase, 3)], "NO FIRE / ESC LEAVES ONLY THIS PRACTICE"]
      if game.autoPilot.targetID != nil || game.dockingComputer || game.workGuidance != nil
        || game.workBraking != nil
      {
        lines.append("Q: RELEASE GUIDANCE FOR MANUAL PRACTICE")
      }
      if let sample = state.previous {
        lines.append(
          String(
            format: "RANGE %.0fm / SPEED %.1fm/s / WINDOW %.2fs", sample.reading.position.length,
            sample.reading.speed, state.pending?.duration ?? 0))
        if !sample.clear { lines.append("COURSE INTRUSION - CURRENT WINDOW RESET") }
      } else {
        lines.append("WAITING FOR COHERENT NATIVE OBSERVATION")
      }
    }
    for (index, line) in lines.enumerated() {
      frame.label(line, 12, 96 + Double(index) * layout.row, scale: layout.font, ink: .cyan)
    }
    if state.failure == nil, !state.workVerified, let original = state.original,
      phase == 1 || phase == 2
    {
      let gate = phase == 1 ? NativeDefensiveFlightGeometry.Gate.positive : .negative
      let world = original.permission.frame.systemPoint(
        NativePracticeSource.volumeOffset + gate.offset)
      let point = game.viewPosition(game.commander.flightSimulation.pose.shipPoint(world))
      if point.z > 1 {
        let centre = layout.projection.point(point)
        let radius = NativeDefensiveFlightGeometry.gateRadius * layout.projection.focal / point.z
        if centre.x.isFinite, centre.y.isFinite, radius.isFinite, radius > 0, radius < 4096 {
          frame.graphics.append(
            .ring(center: centre, radiusX: radius, radiusY: radius, ink: .cyan, style: .dashed))
        }
      }
    }
    return frame
  }
}
