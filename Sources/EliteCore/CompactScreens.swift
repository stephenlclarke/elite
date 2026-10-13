import Foundation

extension Display {
  /// The native app and media exports share this responsive, fixed-size text path.
  public static func presentation(_ game: Game, width: Double, height: Double) -> Frame {
    switch game.screen {
    case .showroom: showroomScreen(game, width: width, height: height)
    case .equipment: equipmentScreen(game, width: width, height: height)
    case .market, .buy, .sell: marketScreen(game, width: width, height: height)
    case .status, .inventory: information(game, width: width, height: height)
    case .chart, .shortChart: map(game, width: width, height: height)
    case .navigation: navigation(game, width: width, height: height)
    case .gallery: gallery(game, width: width, height: height)
    case .handoff: blackjackHandoff(game, width: width, height: height)
    case .demo, .title: startupScreen(game, width: width, height: height)
    case .help: helpScreen(game, width: width, height: height)
    case .system, .secret, .mission, .rumour, .gameOver:
      compactScreen(game, width: width, height: height)
    case .front, .rear, .left, .right: cockpit(game, width: width, height: height)
    }
  }
  static func helpScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let layout = CompactLayout(game: game, width: width, height: height, plain: true)
    let pages = PlayerHelp.pages(for: game)
    let page = max(0, min(game.helpPage, pages.count - 1))
    frame.compactTitle("PLAYER KEY GUIDE", layout: layout)
    frame.label(pages[page].title, layout.left, 50, scale: layout.font, ink: .cyan)
    frame.compactRows(pages[page].rows.map { ($0, .white) }, layout: layout, top: 80)
    frame.label(
      "Page \(page + 1) of \(pages.count)", layout.left, height - 44,
      scale: layout.font, ink: .yellow)
    frame.label(
      "Arrows: more  K/Return/Esc: back", layout.left, height - 24,
      scale: layout.font, ink: .cyan)
    return frame
  }
  static func compactScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = cockpit(game, width: width, height: height)
    let layout = CompactLayout(game: game, width: width, height: height)
    switch game.screen {
    case .rumour:
      frame.compactTitle("STATION RUMOURS / GALAXY \(game.commander.galaxy + 1)", layout: layout)
      frame.compactRows([(game.stationRumour, .white)], layout: layout, top: 56)
      frame.label(
        "Return / Escape: back  K: help", layout.left, layout.bottom - 22, scale: layout.font,
        ink: .cyan)
      return frame
    case .system:
      frame.compactTitle(
        "DATA ON G\(game.inspectedGalaxy + 1) / " + game.inspectedSystem.name, layout: layout)
      frame.compactRows(systemRows(game), layout: layout, top: 56)
    case .secret:
      frame.compactTitle("XYZZY", layout: layout)
      frame.label("A hollow voice says...", layout.left, 50, scale: layout.font, ink: .cyan)
      frame.compactRows(game.secretChoices.map { ($0, .white) }, layout: layout, top: 76)
    case .mission:
      compactMission(game, layout: layout, into: &frame)
      return frame
    case .gameOver:
      frame.compactTitle("GAME OVER", layout: layout)
      frame.label("Press Space / Return for a new commander", layout.left, 60, scale: layout.font)
    default: break
    }
    let footer = game.screen == .secret ? "Return / Escape: resume  K: help" : "K: help"
    frame.label(footer, layout.left, layout.bottom - 22, scale: layout.font, ink: .cyan)
    if game.messageTime > 0 && !game.paused {
      frame.label(game.message, layout.left, layout.bottom - 44, scale: layout.font, ink: .orange)
    }
    if game.paused {
      frame.label(
        "PAUSED - COMMAND-P TO RESUME", layout.left, layout.bottom - 44,
        scale: layout.font, ink: .yellow)
    }
    return frame
  }
  private static func systemRows(_ game: Game) -> [(String, Ink)] {
    let star = game.inspectedSystem
    var rows: [(String, Ink)] = [
      ("Economy: " + star.economyName, .white),
      ("Government: " + star.governmentName, .white),
      ("Tech level: \(star.technology + 1)", .white),
      (String(format: "Population: %.1f billion", Double(star.population) / 10), .white),
      ("Gross productivity: \(star.productivity) MCR", .white),
      ("Average radius: \(star.radius) km", .white),
    ]
    if star.isPlugh {
      rows += [
        (
          "Hidden discount trading port. 25% purchase discount; all goods stocked and all supported equipment for sale. Fitting limits and launch legality still apply.",
          .cyan
        )
      ]
    }
    if let clue = game.missionClue { rows += [("", .cyan), (clue, .cyan)] }
    if game.commander.executive && game.docked {
      if star.name == "LAVE" { rows.append(("XYZZY HOME PORT", .cyan)) }
      if star.name == "RIEDQUAT" { rows.append(("XYZZY: INFINITE RANGE", .cyan)) }
    }
    return rows
  }
  private static func compactMission(_ game: Game, layout: CompactLayout, into frame: inout Frame) {
    frame.compactTitle("INCOMING MESSAGE", layout: layout)
    guard game.missionElapsed >= 2, let notice = game.missionNotice else { return }
    let page = min(game.missionPage, notice.pages.count - 1)
    if notice.showsShip {
      var ship = SpaceBody(id: 0, hull: .constrictor, position: .init(0, 0, 600))
      ship.rotation = game.time * 0.6
      draw(
        ship, game: game, into: &frame,
        projection: .init(center: .init(frame.canvas.width / 2, 88), focal: 360))
    }
    frame.compactRows(
      notice.pages[page].map { ($0, .white) }, layout: layout,
      top: notice.showsShip ? 132 : 56)
    let text = game.paused ? "Command-P: resume" : "Space / Return / Esc: continue"
    frame.label(text, layout.left, layout.bottom - 22, scale: layout.font, ink: .cyan)
    let counter = "\(page + 1)/\(notice.pages.count)"
    frame.label(
      counter, layout.left + layout.width - Double(counter.count) * 6 * layout.font,
      layout.bottom - 22, scale: layout.font, ink: .yellow)
  }
}
