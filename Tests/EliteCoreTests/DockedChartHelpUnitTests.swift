import Testing

@testable import EliteCore

struct DockedChartHelpUnitTests {
  private func pages(_ game: Game) -> [HelpPage] {
    PlayerHelp.pages(for: game).filter { $0.title == "CHARTS AND PLANET DATA" }
  }

  @Test func dockedChartHintsFollowActualWindowAndHelpReturnContext() {
    var observed = Set<Bool>()
    let flightRows = FlightControlAuthority.ActionID.allCases.map(FlightControlInput.helpRow)
    for chart in [Screen.chart, .shortChart] {
      for width in [512.0, 1512] {
        for height in [540.0, 4000] {
          for inHelp in [false, true] {
            var game = Game(executive: false)
            game.viewportWidth = width
            game.viewportHeight = height
            game.screen = inHelp ? .help : chart
            game.helpReturn = chart
            var context = game
            context.screen = chart
            let scrollable = Display.chartDataWindow(context).last > 0
            observed.insert(scrollable)
            let commander = game.commander
            let selection = game.selectedSystem
            let result = pages(game)
            let rows = result.flatMap(\.rows)
            #expect(!result.isEmpty)
            #expect(rows.contains("UP / DOWN / SCROLL - PLANET DATA") == scrollable)
            #expect(rows.contains("ALL PLANET DATA VISIBLE") == !scrollable)
            #expect(!rows.contains("PLANET DATA: 6"))
            #expect(rows.contains("LEFT / RIGHT OR CLICK - SELECT PLANET"))
            #expect(rows.contains("ESC - PREVIOUS SCREEN"))
            for page in result {
              #expect(page.rows.count <= 16 && page.rows.allSatisfy { $0.count <= 40 })
              #expect(flightRows.allSatisfy { page.rows.contains($0) })
            }
            #expect(game.commander == commander && game.selectedSystem == selection)
            #expect(game.screen == (inHelp ? .help : chart) && game.helpReturn == chart)
          }
        }
      }
    }
    #expect(observed == [false, true])
  }

  @Test func flightChartsKeepSeparatePlanetDataShortcutWithoutDockedScrollHints() {
    for chart in [Screen.chart, .shortChart] {
      for inHelp in [false, true] {
        var game = Game(executive: false)
        game.docked = false
        game.screen = inHelp ? .help : chart
        game.helpReturn = chart
        let commander = game.commander
        let rows = pages(game).flatMap(\.rows)
        #expect(rows.contains("PLANET DATA: 6"))
        #expect(!rows.contains("UP / DOWN / SCROLL - PLANET DATA"))
        #expect(!rows.contains("ALL PLANET DATA VISIBLE"))
        #expect(rows.contains("ESC - PREVIOUS SCREEN"))
        #expect(!game.docked && game.commander == commander)
      }
    }
  }
}
