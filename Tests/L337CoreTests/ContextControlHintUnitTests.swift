import Testing

@testable import L337Core

struct ContextControlHintUnitTests {
  @Test
  func targetPagingHelpFollowsActualIdentificationExpansionAndViewportWithoutChangingSelection()
    throws
  {
    var observed = Set<Bool>()
    let initial = Game(executive: false)
    for hasTarget in [false, true] {
      for tier in [TargetingTier.basic, .identification, .military] {
        for expanded: Bool? in [nil, false, true] {
          for (width, height) in [(512.0, 300.0), (1512, 300), (1512, 4000)] {
            var game = initial
            game.docked = false
            game.screen = .front
            game.commander.installTargetingComputer(tier)
            game.bodies = [SpaceBody(id: 90, hull: .cobra, position: .init(0, 0, 500))]
            game.weaponsTargetID = hasTarget ? 90 : nil
            game.targetPanelExpanded = expanded
            game.targetPanelScroll = 0
            game.viewportWidth = width
            game.viewportHeight = height
            game.selectedFlightTool = .miningLaser
            let bodies = game.bodies
            let clock = game.time
            let expected: Bool
            if hasTarget, tier >= .identification, expanded ?? (width >= 1100) {
              let info = try #require(game.targetInformation)
              let cockpit = CockpitLayout(game: game, width: width, height: height)
              expected = TargetPanelLayout(game: game, info: info, cockpit: cockpit).window.last > 0
            } else {
              expected = false
            }
            observed.insert(expected)
            for inHelp in [false, true] {
              game.screen = inHelp ? .help : .front
              game.helpReturn = .front
              let pages = PlayerHelp.pages(for: game)
                .filter { $0.title == "FLIGHT: WEAPONS AND DRIVES" }
              #expect(!pages.isEmpty)
              #expect(
                pages.flatMap(\.rows).contains("OPTION-UP/DOWN - PAGE TARGET DETAILS") == expected)
              for page in pages {
                #expect(page.rows.count <= 16 && page.rows.allSatisfy { $0.count <= 40 })
                for action in FlightControlAuthority.ActionID.allCases {
                  #expect(page.rows.contains(FlightControlInput.helpRow(for: action)))
                }
              }
            }
            game.screen = .front
            game.key("pagedown")
            #expect((game.targetPanelScroll > 0) == expected)
            game.key("pageup")
            #expect(game.targetPanelScroll == 0)
            #expect(
              game.selectedFlightTool == .miningLaser
                && game.weaponsTargetID == (hasTarget ? 90 : nil))
            #expect(game.bodies == bodies && game.time == clock)
          }
        }
      }
    }
    #expect(observed == [false, true])
  }

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
