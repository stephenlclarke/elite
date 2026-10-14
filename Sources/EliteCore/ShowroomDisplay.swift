import Foundation

public struct ShowroomLayout: Sendable {
  public static let actionKeys = [
    "b", "r", "c", "v", ",", ".", " ", "showroom-sort",
  ]
  public let wide: Bool
  public let listVisible: Bool
  public let search: CanvasRect
  public let clearSearch: CanvasRect
  public let close: CanvasRect
  public let buttons: [CanvasRect]
  public let trade: CanvasRect
  public let pane: CanvasRect
  public let list: CanvasRect
  public let listRow = 36.0
  public let model: CanvasRect
  public let details: CanvasRect
  public var selectedModelX: Double { model.x + Self.selectedModelOffset(model.width) }
  static func selectedModelOffset(_ width: Double) -> Double { (width + 16) / 2 }
  public var listCount: Int { max(1, Int(list.height / listRow)) }
  public init(width: Double, height: Double, detail: Bool) {
    wide = width >= 1000
    listVisible = wide || !detail
    let left = wide ? 272.0 : 16
    let available = width - left - 16
    search = .init(x: 16, y: 42, width: min(680, width - 184), height: 24)
    clearSearch = .init(x: search.maxX + 8, y: 42, width: 144, height: 24)
    close = .init(x: width - 106, y: 8, width: 90, height: 24)
    buttons = Self.actionKeys.indices.map { index in
      .init(
        x: left + Double(index % 4) * available / 4, y: 72 + Double(index / 4) * 28,
        width: available / 4 - 4, height: 24)
    }
    trade = .init(x: left, y: 132, width: available * 0.68 - 8, height: 32)
    pane = .init(x: trade.maxX + 16, y: 132, width: available - trade.width - 16, height: 32)
    list = .init(
      x: 16, y: 222, width: wide ? 240 : width - 32,
      height: wide ? height - 282 : min(160, height * 0.25))
    let modelTop = wide || detail ? 222 : list.maxY + 14
    let modelHeight = wide || detail ? min(240, height * 0.24) : max(80, height - modelTop - 60)
    model = .init(x: left, y: modelTop, width: available, height: modelHeight)
    details = .init(
      x: left, y: model.maxY + 18, width: available,
      height: max(0, height - model.maxY - 80))
  }
}

enum ShowroomText {
  static func wrap(_ text: String, width: Int) -> [String] {
    let columns = max(1, width)
    let pieces = text.split(separator: " ", omittingEmptySubsequences: false).flatMap { word in
      stride(from: 0, to: max(1, word.count), by: columns).map { offset in
        String(word.dropFirst(offset).prefix(columns))
      }
    }
    return MissionNotice.wrap(pieces.joined(separator: " "), width: columns)
  }
}

struct ShipComparisonLayout {
  let labelWidth: Double
  let baselineX: Double
  let selectedX: Double
  let baselineWidth: Double
  let selectedWidth: Double
  var labelColumns: Int { max(1, Int(labelWidth / (6 * GameTypography.scale))) }
  var baselineColumns: Int { max(1, Int(baselineWidth / (6 * GameTypography.scale))) }
  var selectedColumns: Int { max(1, Int(selectedWidth / (6 * GameTypography.scale))) }
  init(width: Double, labels: [String], modelAligned: Bool) {
    let gutter = 16.0
    let longest =
      labels.map {
        BitmapLabel(text: $0, x: 0, y: 0, scale: GameTypography.scale, ink: .white).bounds.width
      }.max() ?? 0
    if modelAligned {
      selectedX = ShowroomLayout.selectedModelOffset(width)
      labelWidth = min(longest, max(60, selectedX - 96 - 2 * gutter))
      baselineX = labelWidth + gutter
      baselineWidth = selectedX - baselineX - gutter
      selectedWidth = width - selectedX
    } else {
      // Narrow detail views retain equal value columns and wrap their shared rows.
      labelWidth = min(longest, max(60, width - 2 * 96 - 2 * gutter))
      baselineX = labelWidth + gutter
      baselineWidth = (width - labelWidth - 2 * gutter) / 2
      selectedX = baselineX + baselineWidth + gutter
      selectedWidth = baselineWidth
    }
  }
}

private struct ShowroomTextLine {
  let text: String
  let x: Double
  let ink: Ink
}

extension Display {
  public static func showroomScreen(_ game: Game, width: Double, height: Double) -> Frame {
    if game.showroom.trading { return shipTradeScreen(game, width: width, height: height) }
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let layout = ShowroomLayout(width: width, height: height, detail: game.showroom.detail)
    let font = GameTypography.scale
    frame.label("SHIP SHOWROOM", 16, 12, scale: font, ink: .yellow)
    frame.label("Esc: Back", layout.close.x + 4, 12, scale: font, ink: .cyan)
    let countText =
      game.showroom.query.isEmpty
      ? "\(game.showroomShips.count)/\(ShipCatalogue.all.count) ships"
      : "FILTER ACTIVE: \(game.showroomShips.count)/\(ShipCatalogue.all.count) ships"
    let banner = countText + " | You own: " + game.commander.ship.name
    let columns = Int((width - 32) / (6 * font))
    let compactBanner =
      "\(game.showroomShips.count)/\(ShipCatalogue.all.count) | Owned: " + game.commander.ship.name
    frame.label(
      banner.count <= columns ? banner : String(compactBanner.prefix(columns)), 16, 28, scale: font,
      ink: game.showroom.query.isEmpty ? .white : .orange)
    frame.label(
      game.showroom.searching ? "Clear search" : "Clear filter", layout.clearSearch.x + 4,
      layout.clearSearch.y + 8, scale: font, ink: .cyan)
    let query = game.showroom.query.isEmpty ? "Name / class / source / ID" : game.showroom.query
    frame.label(
      (game.showroom.searching ? "> " : "/: ") + query,
      layout.search.x + 8, layout.search.y + 8, scale: font, ink: .cyan)
    let buttonTitles = [
      "Pin baseline", "Your ship",
      game.showroom.compare ? "Compare: on" : "Compare: off",
      game.showroom.sourceProfiles ? "Game values" : "Source notes",
      game.showroomProfiles.count > 1 ? "Prev profile" : "Single profile",
      game.showroomProfiles.count > 1 ? "Next profile" : "Single profile",
      game.showroom.rotationPaused ? "Rotate model" : "Pause model",
      "Sort: " + game.showroom.sort.rawValue,
    ]
    for (index, bounds) in layout.buttons.enumerated() {
      frame.stroke(bounds.x, bounds.maxY, bounds.maxX, bounds.maxY, .blue)
      let title = buttonTitles[index]
      let columns = max(1, Int((bounds.width - 8) / (6 * font)))
      frame.label(
        String(title.prefix(columns)), bounds.x + 4, bounds.y + 8, scale: font,
        ink: ([",", "."].contains(ShowroomLayout.actionKeys[index])
          && game.showroomProfiles.count <= 1) ? .blue : .cyan)
    }
    showroomTradeAction(game, layout: layout, into: &frame)
    frame.stroke(layout.pane.x, layout.pane.maxY, layout.pane.maxX, layout.pane.maxY, .blue)
    frame.label(
      game.showroom.detail ? "Browse ships" : "Read specs", layout.pane.x + 8,
      layout.pane.y + 10, scale: font, ink: .cyan)
    let window = showroomWindow(game)
    var focus = "Ships: arrows / Return"
    if game.showroom.detail {
      focus = window.hint ?? "All specifications visible"
      if game.showroomShip?.id != game.commander.shipID && game.shipTradeQuote != nil {
        focus += " | Return: review trade"
      }
    }
    if game.showroom.searching { focus = "Search: type / arrows / Return" }
    frame.label(focus, 16, height - 42, scale: font, ink: .yellow)
    if layout.listVisible {
      frame.label(
        game.showroom.detail ? "Ships" : "> Ships", layout.list.x, layout.list.y - 18,
        scale: font, ink: .cyan)
      showroomList(game, layout: layout, into: &frame)
    }
    if layout.wide || game.showroom.detail {
      frame.label(
        game.showroom.detail ? "> Specifications" : "Specifications", layout.details.x,
        layout.details.y - 14, scale: font, ink: .cyan)
    }
    if let selected = game.showroomShip {
      if layout.wide && game.showroom.compare, let baseline = game.showroomBaseline {
        let half = (layout.model.width - 16) / 2
        showroomModel(
          baseline, game: game,
          bounds: .init(
            x: layout.model.x, y: layout.model.y,
            width: half, height: layout.model.height),
          title: game.showroom.baselineUsesCurrent
            ? "CURRENT SHIP" : "PINNED BASELINE",
          into: &frame)
        showroomModel(
          selected, game: game,
          bounds: .init(
            x: layout.selectedModelX,
            y: layout.model.y, width: half, height: layout.model.height),
          title: "SELECTED SHIP",
          into: &frame)
      } else {
        showroomModel(
          selected, game: game, bounds: layout.model, title: "Browsing: " + selected.name,
          into: &frame)
      }
      if layout.wide || game.showroom.detail {
        showroomDetails(game, bounds: layout.details, modelAligned: layout.wide, into: &frame)
      }
    } else {
      frame.label(
        "No matches - clear or edit search", layout.model.x, layout.model.y + 40, scale: font,
        ink: .orange)
    }
    let help = "Tab: ships/specs  /: search  Esc: back  K: help"
    frame.label(help, 16, height - 24, scale: font, ink: .cyan)
    return frame
  }

  private static func showroomTradeAction(
    _ game: Game, layout: ShowroomLayout, into frame: inout Frame
  ) {
    let owned = game.showroomShip?.id == game.commander.shipID
    let quote = game.shipTradeQuote
    let title: String
    if owned {
      title = "Currently flying"
    } else if quote != nil {
      title = "Switch ship - review trade"
    } else {
      title = game.showroomShip == nil ? "Select a ship" : "Display only - cannot fly"
    }
    let ink: Ink
    if owned { ink = .cyan } else if quote?.allowed == true { ink = .green } else { ink = .orange }
    let bounds = layout.trade
    frame.stroke(bounds.x, bounds.y, bounds.maxX, bounds.y, ink)
    frame.stroke(bounds.x, bounds.maxY, bounds.maxX, bounds.maxY, ink)
    frame.stroke(bounds.x, bounds.y, bounds.x, bounds.maxY, ink)
    frame.stroke(bounds.maxX, bounds.y, bounds.maxX, bounds.maxY, ink)
    frame.label(title, bounds.x + 8, bounds.y + 10, scale: GameTypography.scale, ink: ink)
    let rows: [String]
    if let quote, !owned {
      rows = [
        String(
          format: "Price %.1f CR | Trade-in %.1f CR", Double(quote.purchase) / 10,
          Double(quote.allowance) / 10),
        String(
          format: "%@ %.1f CR | Balance %.1f CR", quote.net < 0 ? "Credit" : "Pay",
          Double(abs(quote.net)) / 10, Double(quote.balance) / 10),
        quote.allowed
          ? "Review fit, then confirm or go back" : "Trade blocked - open review for reasons",
      ]
    } else {
      rows = ["Current ship: " + game.commander.ship.name]
    }
    let columns = Int(layout.model.width / (6 * GameTypography.scale))
    for (index, row) in rows.enumerated() {
      frame.label(
        String(row.prefix(columns)), bounds.x, bounds.maxY + 8 + Double(index) * 14,
        scale: GameTypography.scale, ink: index == 2 ? ink : .white)
    }
  }

  private static func showroomList(_ game: Game, layout: ShowroomLayout, into frame: inout Frame) {
    let ships = game.showroomShips
    let start = game.showroomListStart(layout)
    if ships.isEmpty {
      frame.label(
        "No matching ships", layout.list.x + 8, layout.list.y + 8,
        scale: GameTypography.scale, ink: .orange)
    }
    for (row, ship) in ships.dropFirst(start).prefix(layout.listCount).enumerated() {
      let y = layout.list.y + Double(row) * layout.listRow
      let selected = ship.id == game.showroom.selection
      let name = (selected ? "> " : "  ") + ship.name
      let lines = ShowroomText.wrap(
        name, width: Int((layout.list.width - 16) / (6 * GameTypography.scale)))
      for (line, text) in lines.enumerated() {
        frame.label(
          text, layout.list.x + 8, y + Double(line) * 14, scale: GameTypography.scale,
          ink: selected ? .cyan : .white)
      }
    }
  }

  private static func showroomModel(
    _ ship: CatalogueShip, game: Game, bounds: CanvasRect,
    title: String, into frame: inout Frame
  ) {
    let font = GameTypography.scale
    let columns = max(10, Int(bounds.width / (6 * font)))
    let lines = ShowroomText.wrap(title, width: columns)
    for (index, line) in lines.prefix(2).enumerated() {
      frame.label(line, bounds.x, bounds.y + Double(index) * 14, scale: font, ink: .yellow)
    }
    guard let mesh = ship.previewMesh
    else {
      frame.label(
        "Model unavailable", bounds.x + 4, bounds.y + bounds.height / 2,
        scale: font, ink: .orange)
      return
    }
    var preview = game
    preview.screen = .front
    preview.commander.shipDisplayStyle = .shadedPanels
    var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 400))
    body.orientation.rotate(
      pitch: 0.25 + game.showroom.angle * 0.3,
      roll: game.showroom.angle * 0.15, yaw: game.showroom.angle)
    let clip = frame.flightClip
    frame.flightClip = .init(
      x: bounds.x, y: bounds.y + 28, width: bounds.width,
      height: bounds.height - 62)
    let projection = FlightProjection(
      center: .init(
        bounds.x + bounds.width / 2,
        bounds.y + bounds.height / 2), focal: min(bounds.width, bounds.height - 62) * 1.6)
    draw(body, game: preview, into: &frame, projection: projection, mesh: mesh)
    frame.flightClip = clip
    let caption =
      ship.name
    for (index, line) in ShowroomText.wrap(caption, width: columns).prefix(2).enumerated() {
      frame.label(line, bounds.x, bounds.maxY - 28 + Double(index) * 14, scale: font, ink: .cyan)
    }
  }

  static func showroomWindow(_ game: Game) -> ScrollWindow {
    let layout = ShowroomLayout(
      width: game.viewportWidth, height: game.viewportHeight, detail: game.showroom.detail)
    let rows = showroomDetailRows(game, width: layout.details.width, modelAligned: layout.wide)
    return .init(
      count: rows.count, visible: max(1, Int(layout.details.height / GameTypography.row)),
      offset: game.showroom.scroll)
  }
  static func showroomMaximumScroll(_ game: Game) -> Int { showroomWindow(game).last }

  private static func showroomDetails(
    _ game: Game, bounds: CanvasRect, modelAligned: Bool, into frame: inout Frame
  ) {
    let rows = showroomDetailRows(game, width: bounds.width, modelAligned: modelAligned)
    let visible = max(1, Int(bounds.height / GameTypography.row))
    let start = min(game.showroom.scroll, max(0, rows.count - visible))
    for (index, labels) in rows.dropFirst(start).prefix(visible).enumerated() {
      for label in labels {
        frame.label(
          label.text, bounds.x + label.x, bounds.y + Double(index) * GameTypography.row,
          scale: GameTypography.scale, ink: label.ink)
      }
    }
  }

  private static func showroomDetailRows(_ game: Game, width: Double, modelAligned: Bool)
    -> [[ShowroomTextLine]]
  {
    guard let ship = game.showroomShip else { return [] }
    let columns = Int(width / (6 * GameTypography.scale))
    let dimensions =
      ship.dimensions.map {
        $0.map { String(format: "%.4g", $0) }.joined(separator: " x ")
      } ?? "Unavailable"
    let profileTitle = game.showroomProfile?.title ?? "Unavailable"
    let profileLabel =
      "Profile \(game.showroom.profileIndex + 1)/\(game.showroomProfiles.count): \(profileTitle)"
    let metadata: [String] = [
      ship.name + " / " + ship.shipClass,
      ship.availability, "Editions: " + ship.appearances,
      "Evidence: " + ship.evidence, "Design provenance: docs/SHIP-PROVENANCE.md",
      "Dimensions: " + dimensions,
      profileLabel,
      game.showroomProfile?.context ?? "No numerical profile for this object.",
    ]
    let headings =
      game.showroom.sourceProfiles
      ? [metadata[0], metadata[6], metadata[7]]
      : [
        ship.name + " / carried fit"
      ]
    var rows = headings.flatMap { ShowroomText.wrap($0, width: columns) }.map {
      [ShowroomTextLine(text: $0, x: 0, ink: .cyan)]
    }
    if game.showroom.compare {
      rows += game.showroomTradeoffs.flatMap {
        ShowroomText.wrap("Tradeoff: " + $0, width: columns)
      }.map {
        [ShowroomTextLine(text: $0, x: 0, ink: .yellow)]
      }
      rows += comparisonRows(game, width: width, modelAligned: modelAligned)
    } else {
      for field in game.showroomProfile?.fields ?? [] {
        let text = field.label + ": " + field.text + " [" + field.status + "]"
        rows += ShowroomText.wrap(text, width: columns).map {
          [ShowroomTextLine(text: $0, x: 0, ink: .white)]
        }
        if game.showroom.sourceProfiles {
          rows += ShowroomText.wrap(field.basis, width: columns).map {
            [ShowroomTextLine(text: $0, x: 0, ink: .cyan)]
          }
        }
      }
    }
    if !game.showroom.sourceProfiles { return rows }
    rows += Array(metadata[1...5]).flatMap { ShowroomText.wrap($0, width: columns) }.map {
      [ShowroomTextLine(text: $0, x: 0, ink: .cyan)]
    }
    rows += currentCraftRows(game).flatMap { ShowroomText.wrap($0, width: columns) }.map {
      [ShowroomTextLine(text: $0, x: 0, ink: .yellow)]
    }
    return rows
  }

  private static func comparisonRows(_ game: Game, width: Double, modelAligned: Bool)
    -> [[ShowroomTextLine]]
  {
    var rows: [[ShowroomTextLine]] = []
    if !game.showroom.sourceProfiles {
      rows.append([.init(text: "Comparison: same carried fit", x: 0, ink: .cyan)])
      rows.append([
        .init(text: "BETTER", x: 0, ink: .green),
        .init(text: "WORSE", x: 72, ink: .orange),
        .init(text: "SAME", x: 132, ink: .cyan),
      ])
    }
    let a =
      (game.showroom.baselineUsesCurrent ? "Your fitted: " : "Baseline: ")
      + (game.showroomBaseline?.name ?? "Unavailable")
    let b = "Selected: " + (game.showroomShip?.name ?? "Unavailable")
    let pairs =
      [("Comparison", a, b, Ink.cyan)]
      + game.showroomComparison.map {
        var comparison = " " + $0.rating.rawValue
        if game.showroom.sourceProfiles {
          comparison = $0.difference.isEmpty ? "" : " / " + $0.difference
        }
        return (
          $0.label, $0.baseline,
          $0.selected + comparison,
          $0.rating.ink
        )
      }
    let layout = ShipComparisonLayout(
      width: width, labels: pairs.map { $0.0 }, modelAligned: modelAligned)
    for (label, baseline, selected, ink) in pairs {
      let names = ShowroomText.wrap(label, width: layout.labelColumns)
      let left = ShowroomText.wrap(baseline, width: layout.baselineColumns)
      let right = ShowroomText.wrap(selected, width: layout.selectedColumns)
      for line in 0..<max(names.count, left.count, right.count) {
        var cells: [ShowroomTextLine] = []
        if names.indices.contains(line) {
          cells.append(.init(text: names[line], x: 0, ink: .yellow))
        }
        if left.indices.contains(line) {
          cells.append(.init(text: left[line], x: layout.baselineX, ink: .white))
        }
        if right.indices.contains(line) {
          cells.append(.init(text: right[line], x: layout.selectedX, ink: ink))
        }
        rows.append(cells)
      }
    }
    return rows
  }

  private static func currentCraftRows(_ game: Game) -> [String] {
    let commander = game.commander
    let capacityText = commander.unlimitedCargo ? "Unlimited" : String(commander.capacity)
    let freeText =
      commander.unlimitedCargo
      ? "Unlimited (XYZZY)" : "\(commander.capacity - commander.cargoTonnes)t free"
    var rows: [String] = [
      "", "CURRENT FITTED CRAFT: " + commander.ship.name.uppercased(),
      "Native performance units stay separate from source/project units.",
      "Required crew: 1; reserved crew quarters: 1 (assigned)",
      "Fitted berths: 0; passengers aboard: 0; free places: 0",
      "Cabin footprint: 0t; no passenger modules are fitted",
      "Usable cargo after fit: " + freeText,
      "Cargo \(commander.cargoTonnes)/\(capacityText) t; missiles \(commander.missiles)/\(commander.missileCapacity)",
      String(
        format: "Fuel %.1f/%.1f LY; jump limit %.1f LY", Double(commander.fuel) / 10,
        Double(commander.fuelCapacity) / 10, commander.maximumJumpDistance),
      String(format: "Front/rear shield capacity %.1f native units", commander.shieldCapacity),
      String(
        format: "Energy %.1f; top speed %.1f", commander.performance.energy,
        commander.performance.speed),
      "Targeting: " + (commander.targetingTier?.label ?? "None"),
      "Navigation: " + (commander.navigationTier?.label ?? "None"),
    ]
    rows += commander.laserMountSummary
    rows.append("Fitted equipment: " + commander.equipment.sorted().joined(separator: ", "))
    return rows
  }
}
