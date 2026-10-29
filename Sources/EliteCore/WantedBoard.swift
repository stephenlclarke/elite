import Foundation

struct WantedReadContext: Equatable, Sendable {
  let owner: UUID?
  let galaxy: Int
  let system: Int
  let visit: UInt64
  let key: String
  let sighting: WantedSighting?
}

struct WantedBoardLayout {
  let left: Double
  let width: Double
  let top = 138.0
  let row = 28.0
  let capacity: Int
  let bottom: Double
  let back: CanvasRect
  let details: CanvasRect
  let plot: CanvasRect
  init(width: Double, height: Double) {
    self.width = min(1000, max(200, width - 32))
    left = (width - self.width) / 2
    bottom = height - 72
    capacity = max(1, Int((bottom - top) / row))
    back = .init(x: left, y: height - 50, width: 80, height: 24)
    details = .init(x: left + 92, y: height - 50, width: 92, height: 24)
    plot = .init(x: left + 196, y: height - 50, width: min(240, self.width - 196), height: 24)
  }
  func cell(_ index: Int) -> CanvasRect {
    .init(x: left, y: top + Double(index) * row, width: width, height: row)
  }
}

extension Game {
  var selectedWantedEntry: WantedBoardEntry? {
    let player = wantedPlayerSelected
    let identity = wantedSelection
    return wantedBoard.first { player ? $0.isPlayer : $0.identity == identity && !$0.isPlayer }
  }
  func wantedContext(_ entry: WantedBoardEntry) -> WantedReadContext {
    .init(
      owner: commander.equipmentOwnerID, galaxy: commander.galaxy,
      system: commander.system, visit: commander.flightSimulation.visit,
      key: entry.stableKey, sighting: entry.sighting)
  }
  mutating func selectWanted(_ entry: WantedBoardEntry) {
    wantedSelection = entry.identity
    wantedPlayerSelected = entry.isPlayer
    wantedScroll = 0
  }
  mutating func wantedKey(_ key: String) {
    let rows = wantedBoard
    switch key {
    case "escape", "u":
      if wantedRumourDetail {
        wantedRumourDetail = false
        wantedScroll = 0
      } else if wantedDetail {
        wantedDetail = false
        wantedScroll = 0
      } else {
        screen = rumourReturn
      }
    case "up", "down":
      if wantedDetail || wantedRumourDetail {
        wantedScroll = max(0, wantedScroll + (key == "up" ? -1 : 1))
      } else if !rows.isEmpty {
        let current = rows.firstIndex { $0.stableKey == selectedWantedEntry?.stableKey } ?? 0
        selectWanted(rows[max(0, min(rows.count - 1, current + (key == "up" ? -1 : 1)))])
      }
    case "g":
      wantedRumourDetail.toggle()
      wantedDetail = false
      wantedScroll = 0
    case "return", "details":
      if wantedRumourDetail {
        wantedRumourDetail = false
        wantedScroll = 0
        return
      }
      guard !rows.isEmpty else { return }
      if selectedWantedEntry == nil { selectWanted(rows[0]) }
      wantedDetail = true
      wantedScroll = 0
      if let entry = selectedWantedEntry { wantedReadContext = wantedContext(entry) }
    case "p", "plot": plotWantedSighting()
    default: break
    }
  }

  /// A retained dossier is descriptive. Rejoin the current row before opening a route preview.
  mutating func plotWantedSighting() {
    guard screen == .rumour, docked, wantedDetail, let entry = selectedWantedEntry,
      wantedReadContext == wantedContext(entry),
      !entry.isPlayer, let sighting = entry.sighting, sighting.valid,
      sighting.system.galaxy == commander.galaxy,
      sighting.time <= commander.flightSimulation.physicalTime,
      knownSystems.contains(where: { $0.id == sighting.system.system }),
      sighting.system.system != commander.system
    else {
      notify("NO CURRENT ROUTE TO THIS REPORTED SIGHTING")
      return
    }
    selectedSystem = sighting.system.system
    openNavigation()
  }

  public mutating func wantedBoardClick(x: Double, y: Double) {
    guard screen == .rumour, x.isFinite, y.isFinite else { return }
    let layout = WantedBoardLayout(width: viewportWidth, height: viewportHeight)
    let point = ScreenPoint(x, y)
    if layout.back.contains(point) {
      wantedKey("escape")
      return
    }
    if layout.details.contains(point), !wantedDetail {
      wantedKey("details")
      return
    }
    if layout.plot.contains(point) {
      wantedKey(wantedDetail ? "plot" : "g")
      return
    }
    let rows = wantedBoard
    let selected = rows.firstIndex { $0.stableKey == selectedWantedEntry?.stableKey } ?? 0
    let offset = max(0, min(max(0, rows.count - layout.capacity), selected - layout.capacity + 1))
    for index in 0..<min(layout.capacity, max(0, rows.count - offset)) {
      if !wantedDetail, !wantedRumourDetail, layout.cell(index).contains(point) {
        selectWanted(rows[index + offset])
        return
      }
    }
  }

  func wantedDossier(_ entry: WantedBoardEntry) -> [String] {
    let craft = entry.ship.flatMap { ShipCatalogue.ship($0)?.name } ?? "Unknown craft"
    var lines = [
      entry.name, "Craft: " + craft,
      "Outstanding reward: " + Self.wantedCredits(entry.legal.bountyTenths) + " CR",
      "Legal record: \(entry.legal.value) / WANTED",
      "Recorded ship kills: \(entry.recordedKills) (earlier history Unknown)",
    ]
    if let sighting = entry.sighting {
      let system = Self.wantedReportedSystemName(sighting.system)
      lines.append("Last report: Galaxy \(sighting.system.galaxy + 1) / " + system)
      lines.append(
        String(
          format: "Reported location: %.0f, %.0f, %.0f", sighting.position.x, sighting.position.y,
          sighting.position.z))
      lines.append(
        String(
          format: "Reported heading: %.2f, %.2f, %.2f", sighting.heading.x, sighting.heading.y,
          sighting.heading.z))
      lines.append(
        String(
          format: "Seen at %.1f / age %.1f simulation seconds", sighting.time,
          max(0, commander.flightSimulation.physicalTime - sighting.time)))
      let next =
        sighting.destination.map { destination in
          "Galaxy \(destination.galaxy + 1) / " + Self.wantedReportedSystemName(destination)
        } ?? "Unknown"
      lines.append("Next reported destination: " + next)
      lines.append("Reports are historical, not a live position or intercept.")
    } else {
      lines += ["Last location / heading / next destination / time: Unknown"]
    }
    if entry.isPlayer { lines.append("YOU - no self-hunt or route action.") }
    lines.append("Paid only by native lawful death settlement. No board bonus.")
    return lines
  }

  private static func wantedReportedSystemName(_ identity: SystemIdentity) -> String {
    TargetTelemetry.systemName(
      .init(identity: identity, provenance: .recorded), observerGalaxy: identity.galaxy)
  }
}

extension Display {
  static func wantedBoard(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let layout = WantedBoardLayout(width: width, height: height)
    let font = GameTypography.scale
    let columns = max(1, Int(layout.width / (6 * font)))
    func draw(_ text: String, _ y: Double, _ ink: Ink = .white) {
      frame.label(String(text.prefix(columns)), layout.left, y, scale: font, ink: ink)
    }
    draw("STATION GOSSIP / MOST WANTED / GALAXY \(game.commander.galaxy + 1)", 12, .yellow)
    for (index, line) in MissionNotice.wrap(game.stationRumour, width: columns).prefix(3)
      .enumerated()
    {
      draw(line, 36 + Double(index) * 14, .cyan)
    }
    let rows = game.wantedBoard
    if game.commander.wantedCareers.registrationLimited
      || game.commander.wantedCareers.historyLimited
    {
      draw("Registry/history limit reached: unrecorded facts Unknown.", 92, .orange)
    }
    let selected = rows.firstIndex { $0.stableKey == game.selectedWantedEntry?.stableKey } ?? 0
    if game.wantedRumourDetail {
      let lines = MissionNotice.wrap(game.stationRumour, width: columns)
      let capacity = max(1, Int((layout.bottom - 110) / 18))
      let offset = min(max(0, lines.count - capacity), game.wantedScroll)
      for (index, line) in lines.dropFirst(offset).prefix(capacity).enumerated() {
        draw(line, 110 + Double(index) * 18)
      }
    } else if game.wantedDetail {
      if let entry = game.selectedWantedEntry {
        let lines = game.wantedDossier(entry).flatMap { MissionNotice.wrap($0, width: columns) }
        let capacity = max(1, Int((layout.bottom - 110) / 18))
        let offset = min(max(0, lines.count - capacity), game.wantedScroll)
        for (index, line) in lines.dropFirst(offset).prefix(capacity).enumerated() {
          draw(line, 110 + Double(index) * 18, index == 0 ? .purple : .white)
        }
      } else {
        draw("This listing is no longer current. Escape returns to the board.", 116)
      }
    } else {
      draw("Rank / pilot / craft / outstanding reward", 108, .purple)
      if rows.isEmpty { draw("No eligible wanted careers reported in this galaxy.", layout.top) }
      let offset = max(0, min(max(0, rows.count - layout.capacity), selected - layout.capacity + 1))
      for (index, entry) in rows.dropFirst(offset).prefix(layout.capacity).enumerated() {
        let rank = index + offset + 1
        let ship = entry.ship.flatMap { ShipCatalogue.ship($0)?.name } ?? "Unknown"
        draw(
          "\(rank == selected + 1 ? ">" : " ")\(rank) \(entry.name)", layout.cell(index).y, .purple)
        let reward = " / " + Game.wantedCredits(entry.legal.bountyTenths) + " CR"
        let craft = String(ship.prefix(max(1, columns - reward.count - 2)))
        draw("  " + craft + reward, layout.cell(index).y + 13, .purple)
      }
    }
    let hint =
      game.wantedRumourDetail
      ? "Arrows: scroll  Esc: board  K: help"
      : game.wantedDetail
        ? "Arrows: scroll  P: plot last report  K: help"
        : "Arrows/click: select  Return: details  G: gossip  K: help"
    draw(hint, height - 72, .cyan)
    let detailTitle = game.wantedRumourDetail ? "Most Wanted" : game.wantedDetail ? "" : "Details"
    let plotTitle =
      game.wantedDetail ? "Plot last sighting" : game.wantedRumourDetail ? "" : "Gossip"
    for (rect, title) in [
      (layout.back, "Back"), (layout.details, detailTitle), (layout.plot, plotTitle),
    ]
    where !title.isEmpty {
      let count = max(1, Int((rect.width - 12) / (6 * font)))
      frame.label(String(title.prefix(count)), rect.x + 6, rect.y + 5, scale: font, ink: .cyan)
    }
    return frame
  }
}

extension GameRuntime {
  public func wantedBoardClick(x: Double, y: Double) {
    nativeCommand { $0.wantedBoardClick(x: x, y: y) }
  }
}
