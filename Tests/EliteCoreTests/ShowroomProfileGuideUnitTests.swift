import Testing

@testable import EliteCore

struct ShowroomProfileGuideUnitTests {
  private func pages(_ game: Game) -> [HelpPage] {
    PlayerHelp.pages(for: game).filter { $0.title == "SHIP SHOWROOM" }
  }

  @Test func carriedFitHelpDoesNotAdvertiseDisabledProfileButtons() {
    for inHelp in [false, true] {
      var game = Game(executive: false)
      game.screen = inHelp ? .help : .showroom
      game.helpReturn = .showroom
      game.showroom.selection = "SH025"
      game.showroom.sourceProfiles = false
      #expect(game.showroomProfiles.count == 1)
      let help = pages(game)
      let rows = help.flatMap(\.rows)
      #expect(!help.isEmpty)
      #expect(rows.contains("ONE PROFILE; NO CYCLING"))
      #expect(!rows.contains("CLICK PREV / NEXT TO CHANGE PROFILE"))
      #expect(!rows.contains("COMMA / PERIOD - CHANGE PROFILE"))
      #expect(rows.contains("CLICK SOURCE NOTES / GAME VALUES"))
      #expect(rows.contains("TAB - CHANGE SHIPS / SPECS PANE"))
    }
  }

  @Test func sourceProfileHelpRetainsRealCyclingControlsAndCompactPaging() throws {
    let ship = try #require(ShipCatalogue.ship("SH025"))
    try #require(ship.sourceProfilesIncludingPhysical.count > 1)
    for inHelp in [false, true] {
      var game = Game(executive: false)
      game.screen = inHelp ? .help : .showroom
      game.helpReturn = .showroom
      game.showroom.selection = ship.id
      game.showroom.sourceProfiles = true
      game.showroom.detail = true
      let count = game.showroomProfiles.count
      try #require(count > 1)
      for index in 0..<count {
        game.showroom.profileIndex = index
        let help = pages(game)
        let rows = help.flatMap(\.rows)
        #expect(rows.contains("COMMA / PERIOD - CHANGE PROFILE"))
        #expect(rows.contains("CLICK PREV / NEXT TO CHANGE PROFILE"))
        #expect(!rows.contains("ONE PROFILE; NO CYCLING"))
        #expect(help.allSatisfy { $0.rows.count <= 16 && $0.rows.allSatisfy { $0.count <= 40 } })
        #expect(game.showroom.selection == ship.id && game.showroom.profileIndex == index)
        #expect(game.showroom.detail && game.showroom.sourceProfiles)
      }
    }
  }

  @Test func noFilteredProfileDoesNotInventCyclingInEitherValueMode() {
    for source in [false, true] {
      var game = Game(executive: false)
      game.screen = .help
      game.helpReturn = .showroom
      game.showroom.selection = "SH025"
      game.showroom.query = "NO-SUCH-CATALOGUE-SHIP"
      game.showroom.sourceProfiles = source
      #expect(game.showroomShip == nil && game.showroomProfiles.isEmpty)
      let rows = pages(game).flatMap(\.rows)
      #expect(rows.contains("NO SPECIFICATION PROFILE AVAILABLE"))
      #expect(!rows.contains("ONE PROFILE; NO CYCLING"))
      #expect(!rows.contains("CLICK PREV / NEXT TO CHANGE PROFILE"))
      #expect(!rows.contains("COMMA / PERIOD - CHANGE PROFILE"))
      #expect(rows.contains("CLICK CLEAR FILTER - SHOW ALL SHIPS"))
      #expect(rows.contains("CLICK SOURCE NOTES / GAME VALUES"))
    }
  }
}
