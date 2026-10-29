import Foundation

public enum ShowroomSort: String, Sendable {
  case alphabetical = "A-Z"
  case power = "Power"
}

public struct ShowroomState: Sendable {
  public var sort: ShowroomSort = .alphabetical
  public var trading = false
  public var confirmTrade = false
  public var tradeScroll = 0
  public var previousScreen: Screen = .status
  public var selection = "SH023"
  public var baseline = "SH023"
  public var baselineUsesCurrent = true
  public var query = ""
  public var searching = false
  public var detail = false
  public var compare = true
  public var rotationPaused = false
  public var angle = 0.0
  public var scroll = 0
  public var listOffset = 0
  public var sourceProfiles = false
  public var profileIndex = 0
  public init() {}
  mutating func advance(delta: Double) {
    if !rotationPaused { angle = (angle + delta * 0.4).truncatingRemainder(dividingBy: 2 * .pi) }
  }
}
extension Game {
  public var showroomShips: [CatalogueShip] {
    let filtered = ShipCatalogue.all.filter {
      showroom.query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(showroom.query)
    }
    return filtered.sorted { a, b in
      if showroom.sort == .power {
        let left = a.game?.power ?? -1
        let right = b.game?.power ?? -1
        if left != right { return left > right }
      }
      let order = a.name.localizedStandardCompare(b.name)
      return order == .orderedSame ? a.id < b.id : order == .orderedAscending
    }
  }
  public var showroomShip: CatalogueShip? {
    guard let ship = ShipCatalogue.ship(showroom.selection),
      showroom.query.isEmpty || ship.searchText.localizedCaseInsensitiveContains(showroom.query)
    else { return nil }
    return ship
  }
  var showroomProfiles: [ShipProfile] {
    if !showroom.sourceProfiles { return selectedGameProfile.map { [$0] } ?? [] }
    return showroomShip?.sourceProfilesIncludingPhysical ?? []
  }
  public var showroomBaseline: CatalogueShip? {
    ShipCatalogue.ship(showroom.baselineUsesCurrent ? commander.shipID : showroom.baseline)
  }
  public var showroomProfile: ShipProfile? {
    let profiles = showroomProfiles
    return profiles.isEmpty ? nil : profiles[showroom.profileIndex % profiles.count]
  }
  public var showroomBaselineProfile: ShipProfile? {
    if !showroom.sourceProfiles {
      if showroom.baselineUsesCurrent { return commander.gameShipProfile }
      guard let ship = showroomBaseline, ship.game != nil else { return nil }
      return commander.projectedGameShipProfile(to: ship.id)
    }
    return showroomBaseline?.sourceProfilesIncludingPhysical.first {
      $0.group == showroomProfile?.group
    }
  }
  public var showroomComparison: [ShipComparisonRow] {
    let selected = showroomProfile
    let baseline = showroomBaselineProfile
    var keys = baseline?.fields.map(\.key) ?? []
    for key in selected?.fields.map(\.key) ?? [] where !keys.contains(key) { keys.append(key) }
    return keys.map { key in
      let a = baseline?.fields.first { $0.key == key }
      let b = selected?.fields.first { $0.key == key }
      func text(_ field: ShipSpec?) -> String {
        guard let field else { return "Unavailable" }
        return field.text
          + (["source", "game"].contains(field.status) ? "" : " [" + field.status + "]")
      }
      return .init(
        label: b?.label ?? a!.label, baseline: text(a), selected: text(b),
        difference: ShipComparisonRow.difference(
          a, b, comparable: comparableShowroomField(a, b, baseline: baseline, selected: selected)),
        rating: ComparisonRating.compare(
          a, b, compatible: comparableShowroomField(a, b, baseline: baseline, selected: selected)))
    }
  }
  public var showroomTradeoffs: [String] {
    let baseline = showroomBaselineProfile
    let selected = showroomProfile
    return [
      ("cargo_tonnes", "More cargo capacity", "Less cargo capacity"),
      ("maximum_speed_project_units", "Higher maximum speed", "Lower maximum speed"),
      (
        "required_crew_including_commander", "More operating crew required",
        "Fewer operating crew required"
      ),
      ("missile_capacity", "More missile pylons", "Fewer missile pylons"),
      ("hyperspace_range_ly", "Longer jump reach", "Shorter jump reach"),
    ].compactMap { key, higher, lower in
      let a = baseline?.fields.first { $0.key == key }
      let b = selected?.fields.first { $0.key == key }
      guard comparableShowroomField(a, b, baseline: baseline, selected: selected),
        let left = a?.number, let right = b?.number, left != right
      else { return nil }
      return right > left ? higher : lower
    }
  }
  public mutating func openShowroom() {
    guard docked else {
      notify("DOCK TO VISIT THE SHIP SHOWROOM")
      return
    }
    guard
      ![
        Screen.demo, .title, .help, .secret, .mission, .handoff, .gallery, .showroom, .rumour,
        .gameOver,
      ]
      .contains(screen)
    else { return }
    mapSearch.active = false
    showroom.previousScreen = screen
    clearShowroomSearch()
    showroom.selection = commander.shipID
    showroom.profileIndex = 0
    showroom.trading = false
    showroom.detail = false
    showroom.scroll = 0
    screen = .showroom
  }
  mutating func closeShowroom() { screen = showroom.previousScreen }
  public mutating func clearShowroomSearch() {
    showroom.query = ""
    showroom.searching = false
    showroom.scroll = 0
  }
  mutating func showroomKey(_ key: String) {
    defer {
      showroom.scroll = max(0, min(showroom.scroll, Display.showroomMaximumScroll(self)))
      let layout = ShowroomLayout(
        width: viewportWidth, height: viewportHeight, detail: showroom.detail)
      showroom.listOffset = showroomListStart(layout)
    }
    if showroom.trading {
      shipTradeKey(key)
      return
    }
    if ["delete", "showroom-clear", "search-clear"].contains(key) {
      let editing = showroom.searching
      clearShowroomSearch()
      showroom.searching = editing
      return
    }
    if showroom.searching {
      switch key {
      case "escape", "return", "tab": showroom.searching = false
      case "up", "down": moveShowroomSelection(key == "up" ? -1 : 1)
      case "pageup", "pagedown": moveShowroomSelection(key == "pageup" ? -8 : 8)
      case "backspace": if !showroom.query.isEmpty { showroom.query.removeLast() }
      default: if key.count == 1 && showroom.query.count < 24 { showroom.query += key }
      }
      if let first = showroomShips.first,
        !showroomShips.contains(where: { $0.id == showroom.selection })
      {
        showroom.selection = first.id
      }
      showroom.scroll = 0
      if key == "return" { showroom.detail = showroomShip != nil }
      return
    }
    switch key {
    case "x": clearShowroomSearch()
    case "escape":
      if showroom.detail { showroom.detail = false } else { closeShowroom() }
    case "/":
      showroom.searching = true
      showroom.detail = false
    case "return":
      if showroom.detail { openShipTrade() } else { showroom.detail = true }
    case "tab": showroom.detail.toggle()
    case " ": showroom.rotationPaused.toggle()
    case "showroom-sort":
      showroom.sort = showroom.sort == .alphabetical ? .power : .alphabetical
    case "showroom-trade": openShipTrade()
    case "b":
      guard showroomShip != nil else { return }
      showroom.baseline = showroom.selection
      showroom.baselineUsesCurrent = false
    case "r":
      showroom.baseline = commander.shipID
      showroom.baselineUsesCurrent = true
    case "c":
      showroom.compare.toggle()
      showroom.scroll = 0
    case "v":
      showroom.sourceProfiles.toggle()
      showroom.compare = !showroom.sourceProfiles
      showroom.profileIndex = 0
      showroom.scroll = 0
    case ",", ".":
      let profiles = showroomProfiles.count
      showroom.profileIndex =
        (showroom.profileIndex + (key == "." ? 1 : max(0, profiles - 1))) % max(1, profiles)
      showroom.scroll = 0
    case "up", "down":
      if showroom.detail {
        showroom.scroll = max(0, showroom.scroll + (key == "up" ? -1 : 1))
      } else {
        moveShowroomSelection(key == "up" ? -1 : 1)
      }
    case "pageup", "pagedown":
      if showroom.detail {
        showroom.scroll = max(0, showroom.scroll + (key == "pageup" ? -8 : 8))
      } else {
        moveShowroomSelection(key == "pageup" ? -8 : 8)
      }
    default:
      if key.hasPrefix("showroom-list:"), let amount = Int(key.dropFirst(14)) {
        moveShowroomSelection(amount)
      } else if key.hasPrefix("showroom-scroll:"), let amount = Int(key.dropFirst(16)) {
        if showroom.detail || viewportWidth >= 1000 {
          showroom.scroll = max(0, showroom.scroll + amount)
        } else {
          moveShowroomSelection(amount)
        }
      }
    }
  }
  mutating func moveShowroomSelection(_ amount: Int) {
    let ships = showroomShips
    guard !ships.isEmpty else { return }
    let old = ships.firstIndex { $0.id == showroom.selection } ?? 0
    showroom.selection = ships[max(0, min(ships.count - 1, old + amount))].id
    showroom.profileIndex = 0
    showroom.scroll = 0
  }
  public mutating func showroomClick(x: Double, y: Double) {
    guard screen == .showroom else { return }
    if showroom.trading {
      let trade = ShipTradeLayout(width: viewportWidth, height: viewportHeight)
      if trade.back.contains(.init(x, y)) { showroom.trading = false }
      if trade.confirm.contains(.init(x, y)) { confirmShipTrade() }
      return
    }
    let layout = ShowroomLayout(
      width: viewportWidth, height: viewportHeight, detail: showroom.detail)
    let point = ScreenPoint(x, y)
    if layout.clearSearch.contains(point) {
      clearShowroomSearch()
      return
    }
    if layout.search.contains(point) {
      showroom.searching = true
      showroom.detail = false
      return
    }
    if layout.close.contains(point) {
      showroomKey("escape")
      return
    }
    if layout.trade.contains(point) {
      showroom.searching = false
      openShipTrade()
      return
    }
    if layout.pane.contains(point) {
      showroom.searching = false
      showroomKey("tab")
      return
    }
    for (index, bounds) in layout.buttons.enumerated() where bounds.contains(point) {
      if [",", "."].contains(ShowroomLayout.actionKeys[index]) && showroomProfiles.count <= 1 {
        return
      }
      showroom.searching = false
      showroomKey(ShowroomLayout.actionKeys[index])
      return
    }
    if layout.details.contains(point) {
      showroom.searching = false
      showroom.detail = true
      return
    }
    guard layout.listVisible, layout.list.contains(point) else { return }
    let offset = showroomListStart(layout)
    let index = offset + Int((y - layout.list.y) / layout.listRow)
    guard showroomShips.indices.contains(index) else { return }
    showroom.selection = showroomShips[index].id
    showroom.detail = false
    showroom.searching = false
    showroom.scroll = 0
    showroom.profileIndex = 0
    showroom.listOffset = showroomListStart(layout)
  }
  private mutating func openShipTrade() {
    guard let ship = showroomShip, ship.game != nil else {
      notify("THIS OBJECT IS NOT A FLYABLE HULL")
      return
    }
    guard ship.id != commander.shipID else {
      notify("CURRENTLY FLYING " + commander.ship.name.uppercased())
      return
    }
    showroom.trading = true
    showroom.confirmTrade = false
    showroom.tradeScroll = 0
  }
  func showroomListStart(_ layout: ShowroomLayout) -> Int {
    let selected = showroomShips.firstIndex { $0.id == showroom.selection } ?? 0
    var offset = max(0, min(showroom.listOffset, showroomShips.count - layout.listCount))
    if selected < offset { offset = selected }
    if selected >= offset + layout.listCount { offset = selected - layout.listCount + 1 }
    return max(0, offset)
  }
}
