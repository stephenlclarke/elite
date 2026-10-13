import Foundation

public struct ShowroomLayout: Sendable {
  public let wide: Bool
  public let listVisible: Bool
  public let search: CanvasRect
  public let clearSearch: CanvasRect
  public let close: CanvasRect
  public let buttons: [CanvasRect]
  public let list: CanvasRect
  public let listRow = 36.0
  public let model: CanvasRect
  public let details: CanvasRect
  public var listCount: Int { max(1, Int(list.height / listRow)) }
  public init(width: Double, height: Double, detail: Bool) {
    wide = width >= 1000
    listVisible = wide || !detail
    let left = wide ? 272.0 : 16
    let available = width - left - 16
    search = .init(x: 16, y: 42, width: min(680, width - 184), height: 24)
    clearSearch = .init(x: search.maxX + 8, y: 42, width: 144, height: 24)
    close = .init(x: width - 106, y: 8, width: 90, height: 24)
    buttons = (0..<5).map { index in
      .init(x: left + Double(index) * available / 5, y: 72, width: available / 5 - 4, height: 24)
    }
    list = .init(
      x: 16, y: 108, width: wide ? 240 : width - 32,
      height: wide ? height - 148 : min(160, height * 0.30))
    let modelTop = wide || detail ? 108 : list.maxY + 14
    let modelHeight = wide || detail ? min(260, height * 0.30) : max(80, height - modelTop - 40)
    model = .init(x: left, y: modelTop, width: available, height: modelHeight)
    details = .init(
      x: left, y: model.maxY + 18, width: available,
      height: max(0, height - model.maxY - 60))
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
  let valueWidth: Double
  var labelColumns: Int { max(1, Int(labelWidth / (6 * GameTypography.scale))) }
  var valueColumns: Int { max(1, Int(valueWidth / (6 * GameTypography.scale))) }
  init(width: Double, labels: [String]) {
    let gutter = 16.0
    let longest =
      labels.map {
        BitmapLabel(text: $0, x: 0, y: 0, scale: GameTypography.scale, ink: .white).bounds.width
      }.max() ?? 0
    // Reserve useful value columns on narrow windows; use measured labels everywhere else.
    labelWidth = min(longest, max(60, width - 2 * 96 - 2 * gutter))
    baselineX = labelWidth + gutter
    valueWidth = (width - labelWidth - 2 * gutter) / 2
    selectedX = baselineX + valueWidth + gutter
  }
}

private struct ShowroomTextLine {
  let text: String
  let x: Double
  let ink: Ink
}

extension Display {
  public static func showroomScreen(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let layout = ShowroomLayout(width: width, height: height, detail: game.showroom.detail)
    let font = GameTypography.scale
    frame.label("SHIP SHOWROOM", 16, 12, scale: font, ink: .yellow)
    frame.label("W: Close", layout.close.x + 8, 12, scale: font, ink: .cyan)
    let countText =
      game.showroom.query.isEmpty
      ? "\(game.showroomShips.count)/\(ShipCatalogue.all.count) ships"
      : "FILTER ACTIVE: \(game.showroomShips.count)/\(ShipCatalogue.all.count) ships"
    frame.label(
      countText + " | You own: Cobra Mk III", 16, 28, scale: font,
      ink: game.showroom.query.isEmpty ? .white : .orange)
    frame.label(
      game.showroom.searching ? "Fn-Del: Clear" : "X: Clear filter", layout.clearSearch.x + 4,
      layout.clearSearch.y + 8, scale: font, ink: .cyan)
    let query = game.showroom.query.isEmpty ? "Name / class / source / ID" : game.showroom.query
    frame.label(
      (game.showroom.searching ? "> " : "/ ") + query,
      layout.search.x + 8, layout.search.y + 8, scale: font, ink: .cyan)
    let buttonTitles = [
      "B: Pin", "R: Your ship", "C: Compare",
      game.showroom.rotationPaused ? "Space:Spin" : "Space:Stop",
      game.showroom.sourceProfiles ? "V: Refit" : "V: Source",
    ]
    for (index, bounds) in layout.buttons.enumerated() {
      frame.label(buttonTitles[index], bounds.x + 4, bounds.y + 8, scale: font, ink: .cyan)
    }
    if layout.listVisible { showroomList(game, layout: layout, into: &frame) }
    if let selected = game.showroomShip {
      if layout.wide && game.showroom.compare, let baseline = game.showroomBaseline {
        let half = (layout.model.width - 16) / 2
        showroomModel(
          baseline, game: game,
          bounds: .init(
            x: layout.model.x, y: layout.model.y,
            width: half, height: layout.model.height),
          title: game.showroom.baselineUsesCurrent ? "Your Cobra Mk III" : "PINNED BASELINE",
          currentNative: game.showroom.baselineUsesCurrent, into: &frame)
        showroomModel(
          selected, game: game,
          bounds: .init(
            x: layout.model.x + half + 16,
            y: layout.model.y, width: half, height: layout.model.height),
          title: "CATALOGUE PREVIEW",
          into: &frame)
      } else {
        showroomModel(
          selected, game: game, bounds: layout.model, title: "Browsing: " + selected.name,
          into: &frame)
      }
      if layout.wide || game.showroom.detail {
        showroomDetails(game, bounds: layout.details, into: &frame)
      }
    } else {
      frame.label(
        "Catalogue unavailable", layout.model.x, layout.model.y + 40, scale: font, ink: .orange)
    }
    let help =
      layout.wide || game.showroom.detail
      ? "Fn-Up/Down: specs  ,/.: variant  Esc: back  K: help"
      : "Up/Down: ship  Return: specs  /: search  K: help"
    frame.label(help, 16, height - 24, scale: font, ink: .cyan)
    return frame
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
    title: String, currentNative: Bool = false, into frame: inout Frame
  ) {
    let font = GameTypography.scale
    let columns = max(10, Int(bounds.width / (6 * font)))
    let lines = ShowroomText.wrap(title, width: columns)
    for (index, line) in lines.prefix(2).enumerated() {
      frame.label(line, bounds.x, bounds.y + Double(index) * 14, scale: font, ink: .yellow)
    }
    guard let mesh = currentNative ? ShipCatalogue.ship("SH023")?.previewMesh : ship.previewMesh
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
      currentNative ? "Your fitted Cobra / Oolite model" : (ship.modelSource ?? "Source geometry")
    for (index, line) in ShowroomText.wrap(caption, width: columns).prefix(2).enumerated() {
      frame.label(line, bounds.x, bounds.maxY - 28 + Double(index) * 14, scale: font, ink: .cyan)
    }
  }

  private static func showroomDetails(_ game: Game, bounds: CanvasRect, into frame: inout Frame) {
    let rows = showroomDetailRows(game, width: bounds.width)
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

  private static func showroomDetailRows(_ game: Game, width: Double) -> [[ShowroomTextLine]] {
    guard let ship = game.showroomShip else { return [] }
    let columns = Int(width / (6 * GameTypography.scale))
    let metadata = [
      ship.name + " / " + ship.shipClass,
      ship.availability, "Editions: " + ship.appearances,
      "Evidence: " + ship.evidence, ship.geometryContext,
      "Dimensions: "
        + (ship.dimensions.map { $0.map { String(format: "%.4g", $0) }.joined(separator: " x ") }
          ?? "Unavailable"),
      "Profile: " + (game.showroomProfile?.title ?? "Unavailable"),
      game.showroomProfile?.context ?? "No numerical profile for this object.",
    ]
    var rows = [metadata[0], metadata[6], metadata[7]].flatMap {
      ShowroomText.wrap($0, width: columns)
    }.map {
      [ShowroomTextLine(text: $0, x: 0, ink: .cyan)]
    }
    if game.showroom.compare {
      rows += game.showroomTradeoffs.flatMap {
        ShowroomText.wrap("Tradeoff: " + $0, width: columns)
      }.map {
        [ShowroomTextLine(text: $0, x: 0, ink: .yellow)]
      }
      rows += comparisonRows(game, width: width)
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
    rows += Array(metadata[1...5]).flatMap { ShowroomText.wrap($0, width: columns) }.map {
      [ShowroomTextLine(text: $0, x: 0, ink: .cyan)]
    }
    rows += currentCraftRows(game).flatMap { ShowroomText.wrap($0, width: columns) }.map {
      [ShowroomTextLine(text: $0, x: 0, ink: .yellow)]
    }
    return rows
  }

  private static func comparisonRows(_ game: Game, width: Double) -> [[ShowroomTextLine]] {
    var rows: [[ShowroomTextLine]] = []
    let a =
      (game.showroom.baselineUsesCurrent ? "Current fitted: " : "Baseline: ")
      + (game.showroomBaseline?.name ?? "Unavailable")
    let b = "Selected: " + (game.showroomShip?.name ?? "Unavailable")
    let pairs =
      [("Comparison", a, b)]
      + game.showroomComparison.map {
        ($0.label, $0.baseline, $0.selected + ($0.difference.isEmpty ? "" : " / " + $0.difference))
      }
    let layout = ShipComparisonLayout(width: width, labels: pairs.map { $0.0 })
    for (label, baseline, selected) in pairs {
      let names = ShowroomText.wrap(label, width: layout.labelColumns)
      let left = ShowroomText.wrap(baseline, width: layout.valueColumns)
      let right = ShowroomText.wrap(selected, width: layout.valueColumns)
      for line in 0..<max(names.count, left.count, right.count) {
        var cells: [ShowroomTextLine] = []
        if names.indices.contains(line) {
          cells.append(.init(text: names[line], x: 0, ink: .yellow))
        }
        if left.indices.contains(line) {
          cells.append(.init(text: left[line], x: layout.baselineX, ink: .white))
        }
        if right.indices.contains(line) {
          cells.append(.init(text: right[line], x: layout.selectedX, ink: .white))
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
      "", "CURRENT FITTED CRAFT: COBRA MK III (NATIVE)",
      "Native performance units stay separate from source/project units.",
      "Required crew: 1; reserved crew quarters: 1 (assigned)",
      "Fitted berths: 0; passengers aboard: 0; free places: 0",
      "Cabin footprint: 0t; no passenger modules are fitted",
      "Usable cargo after fit: " + freeText,
      "Cargo \(commander.cargoTonnes)/\(capacityText) t; missiles \(commander.missiles)/4",
      String(
        format: "Fuel %.1f/%.1f LY; jump limit %.1f LY", Double(commander.fuel) / 10,
        Double(commander.fuelCapacity) / 10, commander.maximumJumpDistance),
      String(format: "Front/rear shield capacity %.1f native units", commander.shieldCapacity),
      "Energy capacity 256 native units; max throttle 32 native units",
      "Targeting: " + (commander.targetingTier?.label ?? "None"),
      "Navigation: " + (commander.navigationTier?.label ?? "None"),
    ]
    rows += commander.laserMountSummary
    rows.append("Fitted equipment: " + commander.equipment.sorted().joined(separator: ", "))
    return rows
  }
}
