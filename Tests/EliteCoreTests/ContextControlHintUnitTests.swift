import Testing

@testable import EliteCore

struct ContextControlHintUnitTests {
  @Test func systemScrollHintsFollowActualViewportAndHelpReturnContext() {
    var observed = Set<Bool>()
    for width in [512.0, 1512] {
      for height in [300.0, 4000] {
        for inHelp in [false, true] {
          var game = Game(executive: false)
          game.viewportWidth = width
          game.viewportHeight = height
          game.screen = inHelp ? .help : .system
          game.helpReturn = .system
          let scrollable = Display.systemWindow(game, width: width, height: height).last > 0
          observed.insert(scrollable)
          let pages = PlayerHelp.pages(for: game).filter { $0.title == "SYSTEM DATA" }
          let rows = pages.flatMap(\.rows)
          #expect(!pages.isEmpty)
          #expect(rows.contains("UP / DOWN / SCROLL - LONG PLANET DATA") == scrollable)
          #expect(rows.contains("ALL ROWS VISIBLE") == !scrollable)
          #expect(rows.contains("ESC - PREVIOUS SCREEN"))
          #expect(rows.contains("K - HELP"))
        }
      }
    }
    #expect(observed == [false, true])
  }

  @Test func inventoryPagingHintsDisappearWhenAllRowsFitAndRetainSharedFlightControls() {
    var observed = Set<Bool>()
    let flightRows = [
      "W - CHANGE WEAPON", "RETURN - FIRE (HOLD)", "E - ECM", "Q - RELEASE HOLD",
      "TAB - NEXT TARGET", "F - TARGET FILTER",
    ]
    for width in [512.0, 1512] {
      for height in [300.0, 4000] {
        for inHelp in [false, true] {
          var game = Game(executive: false)
          game.viewportWidth = width
          game.viewportHeight = height
          game.screen = inHelp ? .help : .inventory
          game.helpReturn = .inventory
          var context = game
          context.screen = .inventory
          let scrollable = context.informationWindow.last > 0
          observed.insert(scrollable)
          let pages = PlayerHelp.pages(for: game).filter { $0.title == "INVENTORY" }
          let rows = pages.flatMap(\.rows)
          #expect(!pages.isEmpty)
          #expect(rows.contains("OPTION-UP/DOWN - PAGE LONG LISTS") == scrollable)
          #expect(rows.contains("UP / DOWN / SCROLL - MORE ROWS") == scrollable)
          #expect(rows.contains("ALL ROWS VISIBLE") == !scrollable)
          #expect(rows.contains("ESC - PREVIOUS SCREEN"))
          for page in pages {
            #expect(page.rows.count <= 16 && page.rows.allSatisfy { $0.count <= 40 })
            #expect(page.rows.contains("FLIGHT ONLY; MENUS KEEP THEIR KEYS"))
            #expect(flightRows.allSatisfy { page.rows.contains($0) })
          }
        }
      }
    }
    #expect(observed == [false, true])
  }
}
