import Testing

@testable import EliteCore

struct ShowroomNavigationHintUnitTests {
  private func pages(_ game: Game) -> [HelpPage] {
    PlayerHelp.pages(for: game).filter { $0.title == "SHIP SHOWROOM" }
  }

  @Test func specificationArrowHintsFollowActualWindowAndHelpReturnContext() {
    var observed = Set<Bool>()
    let flightRows = FlightControlAuthority.ActionID.allCases.map(FlightControlInput.helpRow)
    for width in [512.0, 1512] {
      for height in [540.0, 4000] {
        for source in [false, true] {
          for inHelp in [false, true] {
            var game = Game(executive: false)
            game.viewportWidth = width
            game.viewportHeight = height
            game.screen = inHelp ? .help : .showroom
            game.helpReturn = .showroom
            game.showroom.selection = game.commander.shipID
            game.showroom.detail = true
            game.showroom.sourceProfiles = source
            var context = game
            context.screen = .showroom
            let window = Display.showroomWindow(context)
            let scrollable = window.last > 0
            observed.insert(scrollable)
            let result = pages(game)
            let rows = result.flatMap(\.rows)
            #expect(!result.isEmpty)
            #expect(rows.contains("UP / DOWN / SCROLL - MORE SPECS") == scrollable)
            #expect(rows.contains("ALL SPECIFICATIONS VISIBLE") == !scrollable)
            #expect(!rows.contains("UP / DOWN - SELECT SHIP"))
            #expect(!rows.contains("ARROWS IN SPECS - SCROLL"))
            #expect(rows.contains("TAB - CHANGE SHIPS / SPECS PANE"))
            for page in result {
              #expect(page.rows.count <= 16 && page.rows.allSatisfy { $0.count <= 40 })
              #expect(flightRows.allSatisfy { page.rows.contains($0) })
            }
            context.showroomKey("down")
            #expect(Display.showroomWindow(context).offset == (scrollable ? 1 : 0))
            #expect(context.showroom.selection == game.showroom.selection)
            #expect(context.commander == game.commander && game.docked)
            #expect(game.screen == (inHelp ? .help : .showroom))
          }
        }
      }
    }
    #expect(observed == [false, true])
  }

  @Test func browseAndSearchKeepSelectionHintsInsteadOfInactiveSpecArrows() throws {
    for width in [512.0, 1512] {
      for (detail, searching) in [(false, false), (false, true), (true, true)] {
        for inHelp in [false, true] {
          var game = Game(executive: false)
          game.viewportWidth = width
          game.screen = inHelp ? .help : .showroom
          game.helpReturn = .showroom
          game.showroom.detail = detail
          game.showroom.searching = searching
          let ships = game.showroomShips
          try #require(ships.count > 1)
          game.showroom.selection = ships[0].id
          let rows = pages(game).flatMap(\.rows)
          #expect(rows.contains("UP / DOWN - SELECT SHIP"))
          #expect(!rows.contains("UP / DOWN / SCROLL - MORE SPECS"))
          #expect(!rows.contains("ALL SPECIFICATIONS VISIBLE"))
          #expect(!rows.contains("ARROWS IN SPECS - SCROLL"))
          var context = game
          context.screen = .showroom
          context.showroomKey("down")
          #expect(context.showroom.selection == ships[1].id)
          #expect(context.commander == game.commander && context.showroom.scroll == 0)
          #expect(context.showroom.detail == detail && context.showroom.searching == searching)
        }
      }
    }
  }
}
