public struct HelpPage: Sendable {
  public let title: String
  public let rows: [String]
}

public enum PlayerHelp {
  public static func pages(for game: Game) -> [HelpPage] {
    let screen = game.screen == .help ? game.helpReturn : game.screen
    let context = context(for: screen, paused: game.paused)
    var pages = paginate(context)
    if !game.paused
      && ![Screen.demo, .title, .gameOver, .secret, .mission, .handoff, .gallery, .showroom]
        .contains(screen)
    {
      let screens = HelpPage(
        title: game.docked ? "AT THE STATION" : "IN SPACE: SCREENS",
        rows: [
          game.docked ? "0 - LAUNCH" : "0 - FRONT VIEW",
          game.docked ? "1 / 2 / 3 - BUY / SELL / EQUIPMENT" : "1 / 2 / 3 - REAR / LEFT / RIGHT",
          "4 / 5 - GALACTIC / SHORT RANGE CHART",
          game.docked ? "4 / 5 INCLUDE FULL PLANET DATA" : "6 - SYSTEM DATA / PLANET VIEW",
          "7 - MARKET PRICES",
          "8 / 9 - COMMANDER STATUS / INVENTORY",
        ])
      if [Screen.status, .inventory, .market, .system].contains(screen) {
        pages = [screens]
        if screen != .system {
          pages.append(
            .init(
              title: "BROWSE STATION INFORMATION",
              rows: ["UP / DOWN / SCROLL - MORE ROWS", "FN-UP/FN-DOWN - PAGE STATUS / INVENTORY"]))
        }
      } else {
        pages.append(screens)
      }
      if game.docked && (screen == .chart || screen == .shortChart) {
        pages.append(
          .init(
            title: "DOCKED PLANET INFORMATION",
            rows: [
              "DATA AND PLANET FOLLOW CHART SELECTION",
              "FN-UP / FN-DOWN - SCROLL PLANET DATA",
              "MISSION CLUES APPEAR WITH PLANET DATA",
            ]))
      }
      if !game.docked && !screen.isFlight {
        pages.append(contentsOf: paginate(Self.context(for: .front, paused: false)))
      }
      if !game.docked {
        pages.append(
          HelpPage(
            title: "SPIN HOLD PROTOTYPE",
            rows: [
              "V - SPIN MODE / NORMAL FLIGHT",
              "ONE FINGER CIRCLE - CHOOSE CW / CCW",
              "CIRCLE AROUND THE TRACKPAD CENTRE",
              "1 / 2 / 3 FINGERS - SLOW/HOLD/FASTER",
              "NO CONTACT - HOLD SET SPIN SPEED",
              "2 FINGERS MOVE - PITCH / YAW",
              "B - STOP SPIN SMOOTHLY",
              "[ / ] - START CCW / CW SPIN",
              "- / = OR + - SLOW / SPEED UP SPIN",
              "LEFT / RIGHT - YAW (SPIN MODE)",
              "X / S - PITCH; SPACE / SLASH - SPEED",
              "CW / CCW IS FROM FORWARD COCKPIT",
              "HELP / PAUSE / FOCUS LOSS CANCEL SPIN",
            ]))
      }
    }
    pages.append(
      HelpPage(
        title: "COMMON KEYS",
        rows: [
          "K / COMMAND-K - CONTEXT KEY GUIDE",
          "L - MISSION GALLERY (PAUSES FLIGHT)",
          "B (DOCKED) - BLACKJACK CONTACT",
          "W (DOCKED) - SHIP SHOWROOM",
          "U (DOCKED) - STATION RUMOURS",
          "COMMAND-P - PAUSE / RESUME",
          "X Y Z Z Y - CLARKE AND SECRET MENU",
          "COMMAND-S / COMMAND-O - SAVE / LOAD",
          "COMMAND-Q - QUIT",
          "LEFT / RIGHT - HELP PAGES",
          "UP / DOWN - HELP PAGES",
          "K / RETURN / ESC - CLOSE HELP",
        ]))
    return pages
  }

  private static func paginate(_ context: HelpPage) -> [HelpPage] {
    stride(from: 0, to: context.rows.count, by: 16).map { offset in
      HelpPage(
        title: context.title,
        rows: Array(context.rows[offset..<min(offset + 16, context.rows.count)]))
    }
  }

  private static func context(for screen: Screen, paused: Bool) -> HelpPage {
    if screen == .secret {
      return HelpPage(
        title: "XYZZY: COMMANDER CLARKE",
        rows: [
          "0 - WHITE / COLOUR / SHADED SHIPS",
          "1 - FIT DOCKING TARGETING TIER",
          "2 - MAXIMUM HARDWARE / RESTORE SHIP",
          "3 - UNLIMITED MISSILES",
          "4 - UNLIMITED FUEL",
          "5 - SHOW FUEL / NAV JUMP LIMIT",
          "6 - AUTO TRADE (INCLUDING ILLEGAL)",
          "7 - SPEECH",
          "8 - UNLIMITED CARGO",
          "9 - SHOW CASH (STARTS AT 1M CR)",
          "A - AUTO TARGET ASSIST", "E - AUTOMATIC ECM", "F - FIT FUEL SCOOPS",
          "B - MILITARY RETURN FIRE",
          "RETURN / ESC - RETURN TO GAME",
        ])
    }
    if paused {
      return HelpPage(title: "PAUSED", rows: ["COMMAND-P / ESC - RESUME", ": - TOGGLE SPEECH"])
    }
    switch screen {
    case .front, .rear, .left, .right:
      return HelpPage(
        title: "IN SPACE: FLIGHT",
        rows: [
          "SPACE - ACCELERATE", "? / SLASH - SLOW DOWN",
          "X / S - PULL UP / PITCH DOWN",
          "< / COMMA - ROLL LEFT", "> / FULL STOP - ROLL RIGHT",
          "A - FIRE LASER (HOLD)", "T / U / M - ARM / DISARM / MISSILE",
          "E - ECM", "TAB - ENERGY BOMB", "ESC - ESCAPE POD",
          "H - HYPERSPACE TO SELECTED SYSTEM",
          "G - GALACTIC HYPERDRIVE",
          "J - IN-SYSTEM JUMP",
          "R - TARGET STATION FOR AUTO DOCKING",
          "P / Q - CANCEL AUTOMATIC GUIDANCE",
          "WEAPONS AND DRIVES REQUIRE EQUIPMENT",
          "R - CYCLE TARGET (FITTED COMPUTER)",
          "Q - DISENGAGE AUTO / MANUAL STEER",
          "I - TARGET CAMERA DETAILS / HIDE",
          "STATION AUTO COMPLETES DOCKING",
          "SCOOPS: PASS CARGO BELOW YOUR NOSE",
          "TRACKPAD: 2 FINGERS - STEER / CRUISE",
          "1 FINGER - SLOW; 3 FINGERS - SPEED UP",
          "HOLD OFF CENTRE TO KEEP TURNING",
          "CENTRE 2 FINGERS - STOP TURNING",
          "LIFT ALL - CENTRE YOKE / KEEP SPEED",
        ])
    case .buy, .sell:
      return HelpPage(
        title: screen == .buy ? "STATION: BUY CARGO" : "STATION: SELL CARGO",
        rows: [
          "UP / DOWN / SCROLL - SELECT PRODUCT",
          "COLOUR: CATEGORY; ACTION: AVAILABILITY",
          screen == .buy ? "RETURN - BUY ONE UNIT" : "RETURN - SELL ONE UNIT",
          "RIGHT / LEFT - BUY / SELL ONE UNIT",
        ])
    case .equipment:
      return HelpPage(
        title: "STATION: EQUIPMENT",
        rows: [
          "UP / DOWN - SELECT ITEM (SKIP HEADINGS)", "RETURN - PURCHASE / REFUEL",
          "LEFT / RIGHT - SELECT LASER MOUNT",
          "CLICK FRONT/LEFT/RIGHT/REAR - MOUNT",
          "CLICK - SELECT; TRACKPAD SCROLL - BROWSE", "REWARD ITEMS ARE NOT FOR SALE",
        ])
    case .chart, .shortChart:
      var rows = [
        "LEFT / RIGHT - PREV / NEXT SYSTEM", "O - TARGET CURRENT SYSTEM", "D - SHOW DISTANCE",
        "H - HYPERSPACE WHEN IN FLIGHT",
        "M - ECONOMY / GOVERNMENT / TECHNOLOGY",
        "N - NAVIGATION ROUTES (FITTED COMPUTER)",
      ]
      rows.append("CLICK CHART - SELECT SYSTEM")
      if screen == .shortChart { rows.append("Z - ZOOM MAX JUMP / SEARCH / FUEL") }
      if screen == .chart {
        rows += [
          "[ / ] - VIEW GALAXY 1 TO 8",
          "O - RETURN TO CURRENT GALAXY/SYSTEM",
          "SLASH - SEARCH VIEWED GALAXY PLANETS", "TYPE - FILTER; UP/DOWN - SELECT",
          "RETURN - CHOOSE; ESC - CLOSE SEARCH", "BACKSPACE / CLICK CLEAR - CLEAR SEARCH",
        ]
      }
      return HelpPage(title: "NAVIGATION CHART", rows: rows)
    case .demo:
      return HelpPage(
        title: "RIGHT-ON COMMANDER DEMO",
        rows: ["THE TITLE APPEARS AFTER THE DEMO", "K - RETURN TO THE DEMO"])
    case .title:
      return HelpPage(
        title: "TITLE SCREEN",
        rows: ["SPACE / RETURN - COMMANDER SCREEN", "NEW COMMANDER: JAMESON"])
    case .gameOver:
      return HelpPage(title: "GAME OVER", rows: ["SPACE / RETURN - NEW COMMANDER JAMESON"])
    case .navigation:
      return HelpPage(
        title: "NAVIGATION ROUTES",
        rows: [
          "UP/DOWN - SELECT ALTERNATIVE", "RETURN - SET ROUTE (NO AUTOMATIC JUMP)",
          "C - CLEAR ROUTE", "N / ESC - RETURN TO CHART", "FN-UP/FN-DOWN - SCROLL ROUTE DETAILS",
          "DOCK AT EACH STOP; LAUNCH PRELOADS NEXT", "H - START EACH JUMP MANUALLY",
        ])
    case .rumour:
      return HelpPage(
        title: "STATION RUMOURS",
        rows: [
          "ASK AT THE LOCAL MAIN STATION", "RETURN / ESC / U - BACK TO STATION",
          "DISCOVERIES ARE SAVED PER GALAXY",
        ])
    case .showroom:
      return HelpPage(
        title: "DOCKED SHIP SHOWROOM",
        rows: [
          "UP/DOWN - SHIP; RETURN - DETAIL",
          "/ OR CLICK - SEARCH NAME/CLASS/SOURCE/ID",
          "TYPE - FILTER; RETURN/ESC - END SEARCH",
          "BACKSPACE - EDIT; SEARCH ID TO FIND",
          "X / FN-DELETE / CLEAR - ALL SHIPS",
          "SPACE - PAUSE / RESUME MODEL ROTATION",
          "B - PIN BASELINE; R - RESET TO COBRA",
          "C - COMPARE; V - SOURCE / REFIT",
          "COMMA / FULL STOP - SOURCE VARIANT",
          "FN-UP / FN-DOWN - SCROLL SPECS",
          "SCROLL LIST - SELECT; SPECS - READ",
          "ESC - BACK; W - CLOSE TO PREVIOUS SCREEN",
          "CATALOGUE BROWSER; NO SHIP PURCHASES",
          "SOURCE UNITS / ESTIMATES ARE LABELLED",
        ])
    case .gallery:
      return HelpPage(
        title: "MISSION GALLERY",
        rows: [
          "UP / DOWN - SELECT MISSION", "RETURN - DETAILS", "PAGE UP / PAGE DOWN - SCROLL DETAILS",
          "CLICK - SELECT MISSION", "TRACKPAD SCROLL - SCROLL DETAILS",
          "ESC - BACK / CLOSE; L - CLOSE", "READ ONLY; FLIGHT IS PAUSED",
        ])
    case .handoff:
      return HelpPage(
        title: "BLACKJACK STATION HANDOFF",
        rows: [
          "ARROWS - CONFIRM / BACK", "RETURN - SELECT", "ESC - BACK WITHOUT TRANSFER",
          "B (DOCKED) - REOPEN CONTACT", "INITIAL CONTACT ENROLS AUTOMATICALLY",
        ])
    case .mission:
      return HelpPage(
        title: "NAVAL MESSAGE",
        rows: [
          "SPACE / RETURN / ESC - CONTINUE",
          "ARROWS - PREVIOUS / NEXT PAGE",
          "FINISH THE MESSAGE TO RETURN TO STATUS",
        ])
    default:
      return HelpPage(
        title: "INFORMATION SCREEN",
        rows: ["USE NUMBER KEYS TO SELECT A SCREEN", "K - RETURN TO YOUR PREVIOUS SCREEN"])
    }
  }
}
