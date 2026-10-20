import Testing

@testable import EliteCore

@Test func numberedScreensAndEscapeReturnThroughHistoryWithoutLaunchingEscapePod() {
  var game = Game(executive: false)
  game.screen = .status
  game.key("3")
  game.selection = 12
  game.key("6")
  #expect(game.screen == .showroom && game.selection == 12)
  game.key("return")
  game.key("k")
  game.key("escape")
  #expect(game.screen == .showroom && game.showroom.detail)
  game.key("escape")
  #expect(game.screen == .showroom && !game.showroom.detail)
  game.key("escape")
  #expect(game.screen == .equipment && game.selection == 12)
  game.key("4")
  game.key("9")
  game.key("escape")
  #expect(game.screen == .chart)
  game.key("escape")
  #expect(game.screen == .equipment)
  game.key("escape")
  #expect(game.screen == .status)
  game.commander.equipment.insert("Escape Pod")
  game.key("0")
  #expect(game.commander.fittedEquipment(at: .utility(.escapePod)) != nil)
  game.key("1")
  game.key("6")
  #expect(game.screen == .system)
  game.key("escape")
  #expect(game.screen == .rear)
  game.key("escape")
  #expect(!game.docked && game.commander.equipment.contains("Escape Pod"))
  game.key("escape-pod")
  #expect(game.docked && !game.commander.equipment.contains("Escape Pod"))
  for docked in [false, true] {
    for number in 0...9 {
      let retired = docked && [1, 2].contains(number)
      #expect((Game.numberedScreen(number, docked: docked) == nil) == retired)
      #expect(Game.screenTitle(number, docked: docked).isEmpty == retired)
    }
  }
  #expect(Game.numberedScreen(11, docked: true) == nil)
  #expect(Game.screenTitle(11, docked: false).isEmpty)
}

@Test func searchConsumesNavigationLettersNumbersAndGalaxyBracketsUntilExplicitlyFinished() {
  var game = Game(executive: false)
  let initialName = game.commander.name
  game.screen = .status
  game.key("4")
  game.key("/")
  for character in "klnwu6[]xyzzy" { game.key(String(character)) }
  #expect(game.screen == .chart && game.acceptsTextInput && game.viewedGalaxy == 0)
  #expect(game.mapSearch.query == "klnwu6[]xyzzy" && game.commander.name == initialName)
  game.key("help-open")
  game.key("escape")
  #expect(game.screen == .chart && game.mapSearch.active)
  game.key("screen:6")
  #expect(game.screen == .showroom && !game.mapSearch.active)
  game.key("/")
  for character in "cobra" { game.key(String(character)) }
  let first = game.showroom.selection
  game.key("down")
  #expect(game.showroom.selection != first && game.showroom.searching)
  game.key("return")
  let selected = game.showroom.selection
  #expect(!game.acceptsTextInput && game.showroom.detail)
  game.key("down")
  #expect(game.showroom.detail && game.showroom.scroll == 1 && game.showroom.selection == selected)
  game.key("tab")
  game.key("up")
  #expect(!game.showroom.detail && game.showroom.selection != selected)
  game.key("/")
  game.key("search-clear")
  #expect(game.showroom.searching && game.showroom.query.isEmpty)
  for character in "not a real vessel" { game.key(String(character)) }
  #expect(game.showroomShips.isEmpty && game.showroomShip == nil)
  let frame = Display.presentation(game, width: 512, height: 518)
  #expect(frame.shipPanels.isEmpty && frame.labels.contains { $0.text.contains("No matches") })
  game.key("escape")
  game.key("x")
  #expect(ShipCatalogue.all.count == 171 && game.showroomShips.count == 171)
  #expect(Set(game.showroomShips.map(\.id)) == Set(ShipCatalogue.all.map(\.id)))
  #expect(
    ["SH168", "SH169", "SH170"].allSatisfy { id in
      game.showroomShips.contains { $0.id == id }
    })
  game.key("return")
  for _ in 0..<200 { game.key("pagedown") }
  let bottom = game.showroom.scroll
  game.key("up")
  #expect(bottom > 0 && game.showroom.scroll == bottom - 1)
  game.key("8")
  #expect(game.screen == .status)
}

@Test func showroomPointerActionsAndNestedBackAgreeWithKeyboardAtBothWindowSizes() {
  for width in [512.0, 1512] {
    var game = Game(executive: false)
    game.screen = .market
    game.viewportWidth = width
    game.viewportHeight = 768
    game.key("6")
    var layout = ShowroomLayout(width: width, height: 768, detail: false)
    func centre(_ rect: CanvasRect) -> ScreenPoint { .init(rect.x + 8, rect.y + 8) }
    game.showroomClick(x: centre(layout.list).x, y: centre(layout.list).y)
    let selected = game.showroom.selection
    for index in ShowroomLayout.actionKeys.indices {
      let before = game
      let point = centre(layout.buttons[index])
      game.showroomClick(x: point.x, y: point.y)
      var keyboard = before
      keyboard.key(ShowroomLayout.actionKeys[index])
      #expect(game.showroom.baseline == keyboard.showroom.baseline)
      #expect(game.showroom.compare == keyboard.showroom.compare)
      #expect(game.showroom.profileIndex == keyboard.showroom.profileIndex)
      #expect(game.showroom.sourceProfiles == keyboard.showroom.sourceProfiles)
      #expect(game.showroom.rotationPaused == keyboard.showroom.rotationPaused)
    }
    let point = centre(layout.pane)
    game.showroomClick(x: point.x, y: point.y)
    #expect(game.showroom.detail && game.showroom.selection == selected)
    layout = ShowroomLayout(width: width, height: 768, detail: true)
    game.showroomClick(x: centre(layout.close).x, y: centre(layout.close).y)
    #expect(game.screen == .showroom && !game.showroom.detail)
    game.showroomClick(x: centre(layout.close).x, y: centre(layout.close).y)
    #expect(game.screen == .market)
  }
}

@Test func missionDialogsRumoursRoutesAndGalleryUseEscapeWithoutUnintendedConfirmation() {
  var game = Game(executive: false)
  game.screen = .inventory
  game.key("u")
  game.key("k")
  game.key("escape")
  #expect(game.screen == .rumour)
  game.key("escape")
  #expect(game.screen == .inventory)
  for width in [512.0, 1512] {
    game.viewportWidth = width
    game.key("l")
    game.key("return")
    game.key("escape")
    #expect(game.screen == .gallery && !game.gallery.detail)
    game.key("escape")
    #expect(game.screen == .inventory)
  }
  game.screen = .navigation
  game.navigationReturn = .shortChart
  game.key("escape")
  #expect(game.screen == .shortChart)
  game.commander.galaxy = 1
  game.commander.system = 233
  game.commander.blackjack.stage = .collectFirearm
  game.screen = .buy
  game.offerBlackjackHandoff()
  let commander = game.commander
  game.key("escape")
  #expect(game.screen == .buy && game.commander == commander)
  game.screen = .mission
  game.missionElapsed = 0
  game.key("escape")
  #expect(game.screen == .mission)
  game.missionElapsed = 2
  game.key("escape")
  #expect(game.screen != .mission && game.commander == commander)
}

@Test func pausedAndTextEntryNeverAccidentallyApplyPurchasesOrShipRestoration() {
  var game = Game(executive: false)
  game.screen = .equipment
  let commander = game.commander
  game.key("pause")
  game.key("return")
  game.key("0")
  #expect(game.paused && game.docked && game.commander == commander)
  game.key("k")
  game.key("escape")
  #expect(game.paused)
  game.key("escape")
  #expect(!game.paused && game.screen == .equipment)
  game.key("4")
  for _ in 0..<20 {
    game.key("5")
    game.key("4")
  }
  #expect(game.screenHistory.count <= 2)
  game.key("screen:99")
  #expect(game.screen == .chart)
}

@Test func helpUsesTheUnderlyingInformationScreenAndExchangeContext() {
  var game = Game(executive: false)
  game.fitMaximumHardware()
  game.viewportHeight = 518
  game.screen = .inventory
  game.key("k")
  #expect(PlayerHelp.pages(for: game).first!.rows.contains("UP / DOWN / SCROLL - MORE ROWS"))
  game.key("escape")
  game.key("8")
  let statusNeedsScroll = game.informationWindow.last > 0
  game.key("k")
  let statusHelp = PlayerHelp.pages(for: game).first!
  #expect(statusHelp.title == "COMMANDER STATUS")
  #expect(statusHelp.rows.contains("ALL ROWS VISIBLE") == !statusNeedsScroll)
  #expect(statusHelp.rows.contains("UP / DOWN / SCROLL - MORE ROWS") == statusNeedsScroll)
  game.key("escape")
  game.key("6")
  game.showroom.selection = "SH013"
  game.key("showroom-trade")
  game.key("k")
  #expect(PlayerHelp.pages(for: game).first!.title == "SHIP EXCHANGE")
  #expect(!PlayerHelp.pages(for: game).contains { $0.title == "STATION SCREENS" })
}

@Test func retiredDockedMarketAliasesDoNotDismissBrowsersOrChangeState() {
  for screen in [
    Screen.status, .buy, .sell, .chart, .shortChart, .showroom, .gallery, .rumour, .navigation,
  ] {
    for key in ["1", "2", "screen:1", "screen:2"] {
      var game = Game(executive: false)
      game.screen = screen
      game.selection = 5
      game.screenHistory = [.status, .equipment]
      game.showroom.query = "cobra"
      let before = game.commander
      let history = game.screenHistory
      let showroom = game.showroom
      game.key(key)
      #expect(game.screen == screen && game.selection == 5)
      #expect(game.commander == before && game.screenHistory == history)
      #expect(
        game.showroom.query == showroom.query && game.showroom.selection == showroom.selection)
      #expect(
        game.showroom.detail == showroom.detail && game.showroom.searching == showroom.searching)
    }
  }
}

@Test func showroomHasOneNumberedShortcutAndRetiredWLeavesNestedDetailsIntact() {
  var game = Game(executive: false)
  game.screen = .status
  game.key("w")
  #expect(game.screen == .status)
  game.key("6")
  #expect(game.screen == .showroom)
  game.key("return")
  let before = game.commander
  game.key("w")
  #expect(game.screen == .showroom && game.showroom.detail && game.commander == before)
  game.key("escape")
  game.key("/")
  for letter in "wnu612" { game.key(String(letter)) }
  #expect(game.showroom.query == "wnu612" && game.acceptsTextInput)
  game.key("escape")
  game.key("escape")
  #expect(game.screen == .status)
  game.key("7")
  #expect(game.screen == .buy)
  game.key("tab")
  #expect(game.screen == .sell)
  game.launch()
  game.key("1")
  #expect(game.screen == .rear)
  game.key("2")
  #expect(game.screen == .left)
}
