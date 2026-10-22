import Foundation

extension Game {
  var isolationWorkLines: [String] {
    guard let body = isolationWorkContactBody, let role = isolationWorkRole(body),
      let module = isolationWorkChild?.savedIsolationWork?.modules.first(where: { $0.role == role })
    else { return [] }
    let contact: String
    switch module.contact {
    case .connected: contact = "CONNECTED / FLOWING WHEN BOTH FEEDERS ARE LIVE"
    case .latchedOpen: contact = "CONTACT LATCHED OPEN"
    }
    var lines = [
      "RENAS " + role.rawValue.uppercased() + " / " + contact,
      String(
        format: "SOURCE %.2f / LOAD %.2f (TOTAL 10000)",
        module.accounts.remainingSupply, module.accounts.deliveredLoad),
      String(
        format: "MEASURED WORK %.2f/20s / ZERO-FLOW OBSERVATION %.2f/1s",
        module.history.seconds(.work), module.history.seconds(.observation)),
    ]
    if module.verification != nil {
      lines.append("INDEPENDENT ZERO-FLOW MEASUREMENT VERIFIED")
    } else {
      lines.append(isolationWorkRuntime.reason)
      lines.append("FRONT SURFACE 50-150m / RELATIVE SPEED <=1m/s / AIM <=2deg")
      lines.append("RETURN REVIEW / FRESH RETURN ARM; Q OR ESC STOPS")
    }
    return lines
  }
}

extension Display {
  static func isolationWorkPanel(_ game: Game, layout: CockpitLayout, into frame: inout Frame) {
    let columns = max(20, Int((layout.width * 0.5 - 24) / (6 * layout.font)))
    let lines = game.isolationWorkLines.flatMap { ShowroomText.wrap($0, width: columns) }
    for (index, line) in lines.enumerated() {
      let y = 100 + Double(index) * layout.row
      guard y < layout.flightClip.maxY - layout.row else { break }
      frame.label(line, 12, y, scale: layout.font, ink: .cyan)
    }
  }
}
