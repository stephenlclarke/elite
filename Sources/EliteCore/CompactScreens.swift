import Foundation

extension Display {
  /// The native app and media exports share this responsive, fixed-size text path.
  public static func presentation(_ game: Game, width: Double, height: Double) -> Frame {
    switch game.screen {
    case .system: systemScreen(game, width: width, height: height)
    case .showroom: showroomScreen(game, width: width, height: height)
    case .equipment: equipmentScreen(game, width: width, height: height)
    case .market, .buy, .sell: marketScreen(game, width: width, height: height)
    case .status, .inventory: information(game, width: width, height: height)
    case .chart, .shortChart: map(game, width: width, height: height)
    case .navigation: navigation(game, width: width, height: height)
    case .library: referenceLibrary(game, width: width, height: height)
    case .gallery: gallery(game, width: width, height: height)
    case .contracts: contractBoard(game, width: width, height: height)
    case .handoff: blackjackHandoff(game, width: width, height: height)
    case .demo, .title: startupScreen(game, width: width, height: height)
    case .help: helpScreen(game, width: width, height: height)
    case .secret, .mission, .rumour, .gameOver:
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
    var paging: String?
    if pages.count > 1 {
      if page == 0 {
        paging = "Right/Down: next page"
      } else if page == pages.count - 1 {
        paging = "Left/Up: previous page"
      } else {
        paging = "Arrows: help pages"
      }
    }
    frame.label(
      [
        paging,
        "Esc: back",
      ].compactMap {
        $0
      }.joined(separator: "  "), layout.left, height - 24,
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
        "Esc: back  K: help", layout.left, layout.bottom - 22, scale: layout.font,
        ink: .cyan)
      return frame
    case .secret:
      frame.compactTitle("XYZZY", layout: layout)
      frame.label("A hollow voice says...", layout.left, 50, scale: layout.font, ink: .cyan)
      var positioned = game
      positioned.viewportWidth = width
      positioned.viewportHeight = height
      let window = positioned.secretWindow
      for (index, row) in positioned.secretRows.dropFirst(window.offset).prefix(window.visible)
        .enumerated()
      {
        frame.label(row.1, layout.left, 76 + Double(index) * layout.row, scale: layout.font)
      }
      if let hint = window.hint {
        frame.label(hint, layout.left, layout.bottom - 62, scale: layout.font, ink: .cyan)
      }
    case .mission:
      compactMission(game, layout: layout, into: &frame)
      return frame
    case .gameOver:
      frame.compactTitle("GAME OVER", layout: layout)
      frame.label("Press Space / Return for a new commander", layout.left, 60, scale: layout.font)
    default: break
    }
    let footer = game.screen == .secret ? "Esc: back  K: help" : "K: help"
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
  static func systemRows(_ game: Game) -> [(String, Ink)] {
    let star = game.inspectedSystem
    var rows: [(String, Ink)] = [
      ("Economy: " + star.economyName, .white),
      ("Government: " + star.governmentName, .white),
      ("Tech level: \(star.technology + 1)", .white),
      (String(format: "Population: %.1f billion", Double(star.population) / 10), .white),
      ("Gross productivity: \(star.productivity) MCR", .white),
      ("Average radius: \(star.radius) km", .white),
    ]
    let belt = AsteroidBeltDefinition.isPresent(system: star, galaxy: game.inspectedGalaxy)
    rows.append(("Asteroid belt: " + (belt ? "sparse star-centred ring" : "none"), .cyan))
    if belt {
      rows += [
        (
          "Ring radius: 2x planet-star distance. Chunks: 1, 5, 10, ... 50 native commodity units.",
          .white
        ),
        (
          "Ore surfaces: minerals grey/white; alloys blue; gold gold; platinum cyan. Mineable cues: orange.",
          .white
        ),
      ]
    }
    if star.isPlugh {
      rows += [
        (
          "Hidden discount trading port. 25% purchase discount; all goods stocked and all supported equipment for sale. Fitting limits and launch legality still apply.",
          .cyan
        )
      ]
    }
    let chart = game.screen == .chart || game.screen == .shortChart
    let clue: String?
    if !chart {
      clue = game.missionClue
    } else if game.inspectedGalaxy == game.commander.galaxy {
      clue = MissionRules.clue(
        stage: game.commander.missionStage, galaxy: game.inspectedGalaxy, system: star.id,
        variation: Int(PlanetIdentity(galaxy: game.inspectedGalaxy, system: star).key % 5))
    } else {
      clue = nil
    }
    if let clue { rows += [("", .cyan), (clue, .cyan)] }
    if game.commander.executive && game.docked && star.name == "LAVE" {
      rows.append(("XYZZY HOME PORT", .cyan))
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
    let text = game.paused ? "Command-P: resume" : "Return: next  Esc: close"
    frame.label(text, layout.left, layout.bottom - 22, scale: layout.font, ink: .cyan)
    let counter = "\(page + 1)/\(notice.pages.count)"
    frame.label(
      counter, layout.left + layout.width - Double(counter.count) * 6 * layout.font,
      layout.bottom - 22, scale: layout.font, ink: .yellow)
  }
}
