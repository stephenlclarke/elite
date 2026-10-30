import Foundation

extension Game {
  var inductionUtilityWorkLines: [String] {
    guard !docked, screen == .front,
      let body = inductionUtilityContactBody, let role = inductionUtilityRole(body),
      let module = inductionUtilityChild?.savedNativeInductionUtility?.modules.first(where: {
        $0.role == role
      })
    else { return [] }
    var lines = [
      "ENRON " + role.rawValue.uppercased() + " / " + module.fault.uppercased(),
      String(
        format: "MEASURED WORK %.2f / 20s / LOCAL KITS %d", module.work?.seconds ?? 0,
        module.availableKits),
    ]
    if module.work?.repair != nil {
      lines.append("REPAIRED - RETURN TO ENRON AFTER ALL THREE")
    } else {
      lines.append(inductionUtilityWorkRuntime.reason)
      lines.append("FRONT SURFACE 50-150m / RELATIVE <=1m/s / AIM <=2deg")
      lines.append("RETURN REVIEW / CONFIRM; Q OR ESC STOPS")
    }
    return lines
  }
}

extension Display {
  static func inductionUtilityWorkPanel(
    _ game: Game, layout: CockpitLayout, into frame: inout Frame
  ) {
    let font = layout.font
    let columns = max(20, Int((layout.width * 0.5 - 24) / (6 * font)))
    let lines = game.inductionUtilityWorkLines.flatMap { ShowroomText.wrap($0, width: columns) }
    for (index, line) in lines.enumerated() {
      let y = 100 + Double(index) * layout.row
      guard y < layout.flightClip.maxY - layout.row else { break }
      frame.label(line, 12, y, scale: font, ink: .cyan)
    }
  }
}
