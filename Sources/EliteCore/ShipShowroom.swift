import Foundation

public struct ShowroomState: Sendable {
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
  public var sourceProfiles = false
  public var profileIndex = 0
  public init() {}
  mutating func advance(delta: Double) {
    if !rotationPaused { angle = (angle + delta * 0.4).truncatingRemainder(dividingBy: 2 * .pi) }
  }
}
extension Game {
  public var showroomShips: [CatalogueShip] {
    ShipCatalogue.all.filter {
      showroom.query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(showroom.query)
    }
  }
  public var showroomShip: CatalogueShip? { ShipCatalogue.ship(showroom.selection) }
  public var showroomBaseline: CatalogueShip? { ShipCatalogue.ship(showroom.baseline) }
  public var showroomProfile: ShipProfile? { selectedShowroomProfile(showroomShip) }
  private func selectedShowroomProfile(_ ship: CatalogueShip?) -> ShipProfile? {
    let profiles =
      ship?.profiles.filter { !showroom.sourceProfiles || $0.group != "project-refit-v1" } ?? []
    return profiles.isEmpty ? nil : profiles[showroom.profileIndex % profiles.count]
  }
  public var showroomBaselineProfile: ShipProfile? {
    if showroom.baselineUsesCurrent { return currentShowroomProfile }
    guard let group = showroomProfile?.group else { return nil }
    return showroomBaseline?.profiles.first { $0.group == group }
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
        return field.text + (field.status == "source" ? "" : " [" + field.status + "]")
      }
      return .init(
        label: b?.label ?? a!.label, baseline: text(a), selected: text(b),
        difference: ShipComparisonRow.difference(
          a, b, comparable: comparableShowroomField(a, b, baseline: baseline, selected: selected)))
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
    showroom.previousScreen = screen
    clearShowroomSearch()
    showroom.selection = "SH023"
    showroom.profileIndex = 0
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
    if key == "delete" || key == "showroom-clear" {
      clearShowroomSearch()
      return
    }
    if showroom.searching {
      switch key {
      case "escape", "return": showroom.searching = false
      case "backspace": if !showroom.query.isEmpty { showroom.query.removeLast() }
      default: if key.count == 1 && showroom.query.count < 24 { showroom.query += key }
      }
      if let first = showroomShips.first,
        !showroomShips.contains(where: { $0.id == showroom.selection })
      {
        showroom.selection = first.id
      }
      showroom.scroll = 0
      return
    }
    switch key {
    case "w": closeShowroom()
    case "x": clearShowroomSearch()
    case "escape":
      if showroom.detail { showroom.detail = false } else { closeShowroom() }
    case "/": showroom.searching = true
    case "return": showroom.detail.toggle()
    case " ": showroom.rotationPaused.toggle()
    case "b":
      showroom.baseline = showroom.selection
      showroom.baselineUsesCurrent = false
    case "r":
      showroom.baseline = "SH023"
      showroom.baselineUsesCurrent = true
    case "c":
      showroom.compare.toggle()
      showroom.scroll = 0
    case "v":
      showroom.sourceProfiles.toggle()
      showroom.profileIndex = 0
      showroom.scroll = 0
    case ",", ".":
      let profiles = showroomShip?.profiles.count ?? 1
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
      showroom.scroll = max(0, showroom.scroll + (key == "pageup" ? -8 : 8))
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
    let layout = ShowroomLayout(
      width: viewportWidth, height: viewportHeight, detail: showroom.detail)
    let point = ScreenPoint(x, y)
    if layout.clearSearch.contains(point) {
      clearShowroomSearch()
      return
    }
    if layout.search.contains(point) {
      showroom.searching = true
      return
    }
    if layout.close.contains(point) {
      closeShowroom()
      return
    }
    for (index, bounds) in layout.buttons.enumerated() where bounds.contains(point) {
      showroom.searching = false
      showroomKey(["b", "r", "c", " ", "v"][index])
      return
    }
    guard layout.listVisible, layout.list.contains(point) else { return }
    let offset = showroomListStart(layout)
    let index = offset + Int((y - layout.list.y) / layout.listRow)
    guard showroomShips.indices.contains(index) else { return }
    showroom.selection = showroomShips[index].id
    showroom.searching = false
    showroom.scroll = 0
    showroom.profileIndex = 0
  }
  func showroomListStart(_ layout: ShowroomLayout) -> Int {
    let selected = showroomShips.firstIndex { $0.id == showroom.selection } ?? 0
    return max(0, min(selected - layout.listCount + 1, showroomShips.count - layout.listCount))
  }
}
