extension Game {
  public var acceptsTextInput: Bool {
    (screen == .chart && mapSearch.active) || (screen == .showroom && showroom.searching)
  }

  public static func numberedScreen(_ number: Int, docked: Bool) -> Screen? {
    switch number {
    case 0: .front
    case 1: docked ? nil : .rear
    case 2: docked ? nil : .left
    case 3: docked ? .equipment : .right
    case 4: .chart
    case 5: .shortChart
    case 6: docked ? .showroom : .system
    case 7: docked ? .buy : .market
    case 8: .status
    case 9: .inventory
    default: nil
    }
  }

  public static func screenTitle(_ number: Int, docked: Bool) -> String {
    switch number {
    case 0: docked ? "Launch" : "Front View"
    case 1: docked ? "" : "Rear View"
    case 2: docked ? "" : "Left View"
    case 3: docked ? "Equipment" : "Right View"
    case 4: "Galactic Chart"
    case 5: "Short Range Chart"
    case 6: docked ? "Ship Showroom" : "System Data"
    case 7: docked ? "Market" : "Market Prices"
    case 8: "Commander Status"
    case 9: "Inventory"
    default: ""
    }
  }

  mutating func navigatePrimary(to destination: Screen) {
    guard destination != screen else { return }
    if destination.isFlight {
      screenHistory.removeAll()
      flightReturn = destination
    } else if let index = screenHistory.firstIndex(of: destination) {
      screenHistory.removeSubrange(index...)
    } else {
      screenHistory.append(screen)
    }
    if screen.isFlight && !destination.isFlight { flightReturn = screen }
    screen = destination
    selection = 0
    informationScroll = 0
    chartInformationScroll = 0
    if !destination.isFlight {
      spin.stop(immediate: true)
      cancelAutoTarget()
    }
  }

  mutating func backFromPrimary() {
    guard !screen.isFlight, ![Screen.demo, .title, .gameOver].contains(screen) else { return }
    screen = screenHistory.popLast() ?? (docked ? .status : flightReturn)
    mapSearch.active = false
  }

  mutating func toggleHelp() {
    if screen == .help {
      screen = helpReturn
      return
    }
    if ![Screen.gallery, .handoff, .showroom].contains(screen) { spin.stop(immediate: true) }
    helpReturn = screen
    helpPage = 0
    screen = .help
  }

  /// Resolve text and nested panels before gameplay shortcuts. Menu commands are explicit.
  mutating func interfaceKey(_ key: String) -> Bool {
    if key == "help-open" || (key == "k" && !acceptsTextInput) {
      toggleHelp()
      return true
    }
    if screen == .help {
      if ["return", "escape"].contains(key) { screen = helpReturn }
      let last = PlayerHelp.pages(for: self).count - 1
      if ["right", "down", "pagedown"].contains(key) { helpPage = min(last, helpPage + 1) }
      if ["left", "up", "pageup"].contains(key) { helpPage = max(0, helpPage - 1) }
      return true
    }
    if key == "pause" || key == "copy" {
      if screen != .gallery {
        paused.toggle()
        if paused {
          spin.stop(immediate: true)
          cancelAutoTarget()
        }
      }
      return true
    }
    if key == "spin-cancel" {
      if screen != .gallery {
        spin.stop(immediate: true)
        cancelAutoTarget()
      }
      return true
    }
    if key.hasPrefix("screen:"), let number = Int(key.dropFirst(7)) {
      openNumberedScreen(number)
      return true
    }
    if key == "contacts-open" {
      let previous = screen
      offerBlackjackHandoff()
      if screen == previous { notify("NO MISSION CONTACT AT THIS STATION") }
      return true
    }
    if key == "rumours-open" {
      openStationRumour()
      return true
    }
    if key == "gallery-open" {
      openGallery()
      return true
    }
    if key == "showroom-open" {
      openShowroom()
      return true
    }
    if key == "search-clear", screen == .chart {
      searchKey(key)
      return true
    }
    if acceptsTextInput {
      if screen == .chart { searchKey(key) } else { showroomKey(key) }
      return true
    }
    if paused && ![Screen.gallery, .showroom, .rumour].contains(screen) {
      if key == "escape" { paused = false }
      if key == ":" { commander.speech.toggle() }
      if key == "l" { openGallery() }
      return true
    }
    if key.count == 1, let number = Int(key), (0...9).contains(number),
      [Screen.showroom, .gallery, .rumour, .navigation].contains(screen)
    {
      openNumberedScreen(number)
      return true
    }
    switch screen {
    case .rumour:
      if ["return", "escape", "u"].contains(key) { screen = rumourReturn }
      return true
    case .showroom:
      showroomKey(key)
      return true
    case .handoff:
      blackjackHandoffKey(key)
      return true
    case .gallery:
      galleryKey(key)
      return true
    case .navigation:
      navigationKey(key)
      return true
    case .secret:
      secretKey(key)
      return true
    case .mission:
      missionKey(key)
      return true
    default: break
    }
    if docked && ["1", "2"].contains(key) { return true }
    if marketKey(key) { return true }
    if key == "escape" {
      backFromPrimary()
      return true
    }
    if key == "u" && docked {
      openStationRumour()
      return true
    }
    if key == "l" {
      openGallery()
      return true
    }
    if chartKey(key) { return true }
    if screen == .system, ["up", "down", "pageup", "pagedown"].contains(key) {
      let direction = key == "up" || key == "pageup" ? -1 : 1
      informationScroll = Display.systemWindow(self, width: viewportWidth, height: viewportHeight)
        .moved(direction * (key.hasPrefix("page") ? 8 : 1))
      return true
    }
    if screen == .status || screen == .inventory,
      ["up", "down", "pageup", "pagedown"].contains(key)
    {
      let direction = key == "up" || key == "pageup" ? -1 : 1
      informationScroll = informationWindow.moved(direction * (key.hasPrefix("page") ? 8 : 1))
      return true
    }
    if screen == .equipment && key.hasPrefix("equipment-scroll:"),
      let amount = Int(key.dropFirst(17))
    {
      moveEquipmentSelection(amount)
      return true
    }
    if key.count == 1 {
      secretBuffer = String((secretBuffer + key).suffix(5))
      if secretBuffer == "xyzzy" {
        spin.stop(immediate: true)
        commander.name = "CLARKE"
        if !commander.xyzzyActive { enableXYZzy() } else { restoreXYZzyCobra() }
        secretReturn = screen
        secretScroll = 0
        screen = .secret
        selection = 0
        secretBuffer = ""
        return true
      }
    }
    return false
  }

  mutating func openNumberedScreen(_ number: Int) {
    guard Self.numberedScreen(number, docked: docked) != nil, !paused, !showroom.trading,
      ![Screen.help, .secret, .mission, .handoff, .demo, .title, .gameOver].contains(screen)
    else { return }
    if number == 6 && screen == .showroom { return }
    mapSearch.active = false
    showroom.searching = false
    switch screen {
    case .showroom: closeShowroom()
    case .gallery: closeGallery()
    case .rumour: screen = rumourReturn
    case .navigation: screen = navigationReturn
    default: break
    }
    functionKey(number)
  }

  private mutating func chartKey(_ key: String) -> Bool {
    guard screen == .chart || screen == .shortChart else { return false }
    if key == "p" {
      toggleProfitScan()
      return true
    }
    if key == "n" {
      openNavigation()
      return true
    }
    if key == "m" {
      mapColour = mapColour.next
      return true
    }
    if docked && ["up", "down", "pageup", "pagedown"].contains(key) {
      let direction = key == "up" || key == "pageup" ? -1 : 1
      chartInformationScroll = Display.chartDataWindow(self).moved(
        direction * (key.hasPrefix("page") ? 8 : 1))
      return true
    }
    guard screen == .chart else { return false }
    if ["[", "]"].contains(key) {
      viewGalaxy(viewedGalaxy + (key == "]" ? 1 : -1))
      return true
    }
    if key == "/" {
      mapSearch.active = true
      return true
    }
    return false
  }
}
