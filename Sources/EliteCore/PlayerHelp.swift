public struct HelpPage: Sendable {
  public let title: String
  public let rows: [String]
}

public enum PlayerHelp {
  public static func pages(for game: Game) -> [HelpPage] {
    let screen = game.screen == .help ? game.helpReturn : game.screen
    if game.paused {
      return [
        .init(
          title: "PAUSED",
          rows: ["ESC / COMMAND-P - RESUME", "K - CLOSE HELP", ": - SPEECH ON/OFF"])
      ]
    }
    var pages = paginate(context(for: screen))
    if ![Screen.demo, .title, .gameOver, .secret, .mission, .handoff].contains(screen) {
      pages.append(
        .init(
          title: game.docked ? "STATION SCREENS" : "SCREENS IN SPACE",
          rows: [
            game.docked ? "0 - LAUNCH" : "0 / 1 / 2 / 3 - FRONT/REAR/LEFT/RIGHT",
            game.docked ? "1 / 2 / 3 - BUY / SELL / EQUIPMENT" : "4 / 5 - GALACTIC / LOCAL CHART",
            game.docked ? "4 / 5 - CHARTS WITH PLANET DATA" : "6 - SYSTEM DATA / PLANET VIEW",
            game.docked ? "6 - SHIP SHOWROOM" : "7 - MARKET PRICES",
            game.docked ? "7 - MARKET PRICES" : "8 / 9 - STATUS / INVENTORY",
            game.docked ? "8 / 9 - STATUS / INVENTORY" : "ESC - PREVIOUS SCREEN / COCKPIT",
            "ARROWS - MOVE; RETURN - CHOOSE",
            "ESC - BACK ONE LEVEL; K - HELP",
            "SCREENS MENU HAS THE SAME DESTINATIONS",
          ]))
      pages.append(
        .init(
          title: "MORE ACTIONS",
          rows: [
            "GAME MENU: MISSIONS / CONTACTS / RUMOURS",
            "L - MISSION GALLERY",
            "B (DOCKED) - MISSION CONTACTS",
            "U (DOCKED) - STATION RUMOURS",
            "OPTION-UP/DOWN - PAGE LONG LISTS",
            "SCROLL - BROWSE THE AREA UNDER POINTER",
            "COMMAND-P - PAUSE / RESUME",
            "COMMAND-S / COMMAND-O - SAVE / LOAD",
            "X Y Z Z Y - CLARKE / SECRET OPTIONS",
            "COMMAND-Q - QUIT",
          ]))
      if !game.docked {
        if !screen.isFlight { pages.append(context(for: .front)) }
        pages.append(contentsOf: flightReference)
      }
    }
    pages.append(
      .init(
        title: "KEY GUIDE",
        rows: [
          "ARROWS - PREVIOUS / NEXT HELP PAGE",
          "K / ESC - CLOSE HELP",
          "COMMAND-K OR HELP MENU - OPEN GUIDE",
          "RETURN ALSO CLOSES THIS GUIDE",
          "NO FUNCTION OR KEYPAD KEYS REQUIRED",
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

  private static func context(for screen: Screen) -> HelpPage {
    switch screen {
    case .front, .rear, .left, .right:
      .init(
        title: "FLIGHT: START HERE",
        rows: [
          "ARROWS - PITCH / ROLL",
          "SPACE - ACCELERATE; DELETE - BRAKE",
          "RETURN - FIRE LASER (HOLD)",
          "TAB - NEXT TARGET / STATION AUTO DOCK",
          "Q - CANCEL AUTOMATIC GUIDANCE",
          "4 / 5 - CHART; H - HYPERSPACE",
          "FLIGHT MENU - WEAPONS / DRIVES / POD",
          "ESC - BACK; NEVER LAUNCHES ESCAPE POD",
          "TRACKPAD: 2 FINGERS - STEER / CRUISE",
          "1 FINGER - SLOW; 3 FINGERS - SPEED UP",
          "HOLD OFF CENTRE TO KEEP TURNING",
          "CENTRE 2 FINGERS - STOP TURNING",
          "LIFT ALL - CENTRE YOKE / KEEP SPEED",
        ])
    case .buy, .sell:
      .init(
        title: screen == .buy ? "BUY CARGO" : "SELL CARGO",
        rows: [
          "UP / DOWN / SCROLL - SELECT PRODUCT",
          screen == .buy ? "RETURN - BUY ONE UNIT" : "RETURN - SELL ONE UNIT",
          "COLOUR: CATEGORY; ACTION: AVAILABILITY",
          "1 / 2 - SWITCH BUY / SELL",
          "ESC - PREVIOUS SCREEN",
        ])
    case .equipment:
      .init(
        title: "EQUIPMENT",
        rows: [
          "UP / DOWN / SCROLL - SELECT ITEM",
          "RETURN - PURCHASE / REFUEL",
          "LEFT / RIGHT - SELECT LASER MOUNT",
          "CLICK FRONT/LEFT/RIGHT/REAR - MOUNT",
          "CLICK AN ITEM TO SELECT IT",
          "REWARD ITEMS ARE NOT FOR SALE",
          "ESC - PREVIOUS SCREEN",
        ])
    case .chart, .shortChart:
      .init(
        title: "CHARTS AND PLANET DATA",
        rows: [
          "LEFT / RIGHT OR CLICK - SELECT PLANET",
          "OPTION-UP/DOWN - SCROLL DOCKED DATA",
          "SLASH (GALACTIC CHART) - SEARCH",
          "TYPE - FILTER; UP / DOWN - RESULT",
          "RETURN - CHOOSE; ESC - END SEARCH",
          "DELETE - ERASE ONE LETTER",
          "COMMAND-DELETE / CLICK CLEAR - RESET",
          "O - CURRENT LOCATION; D - DISTANCE",
          "M - ECONOMY / GOVERNMENT / TECHNOLOGY",
          "N - ROUTES (FITTED NAV COMPUTER)",
          "Z (LOCAL) - CHANGE RANGE",
          "[ / ] OR GALAXY BUTTONS - VIEW GALAXY",
          "H - HYPERSPACE WHEN IN FLIGHT",
          "ESC - PREVIOUS SCREEN",
        ])
    case .navigation:
      .init(
        title: "NAVIGATION ROUTES",
        rows: [
          "UP / DOWN - SELECT ALTERNATIVE",
          "RETURN - SET ROUTE; ESC - BACK",
          "OPTION-UP/DOWN - SCROLL DETAILS",
          "C - CLEAR ROUTE",
          "DOCK AT EACH STOP; H STARTS EACH JUMP",
        ])
    case .showroom:
      .init(
        title: "SHIP SHOWROOM",
        rows: [
          "UP / DOWN - SELECT SHIP",
          "RETURN / SPECS BUTTON - READ SPECS",
          "TAB / SHIPS BUTTON - CHANGE PANE",
          "ARROWS IN SPECS - SCROLL",
          "SLASH / CLICK SEARCH - FILTER SHIPS",
          "UP / DOWN IN SEARCH - SELECT RESULT",
          "RETURN - SPECS; ESC - FINISH SEARCH",
          "DELETE - ERASE; COMMAND-DELETE - CLEAR",
          "CLICK CLEAR FILTER - SHOW ALL SHIPS",
          "CLICK PIN BASE / COBRA BASE / COMPARE",
          "CLICK PREV / NEXT TO CHANGE PROFILE",
          "CLICK SOURCES / REFITS TO CHANGE DATA",
          "CLICK PAUSE / ROTATE TO STOP MOTION",
          "OPTION-UP/DOWN - PAGE ACTIVE PANE",
          "ESC - SEARCH, THEN LIST, THEN STATION",
          "BROWSING CANNOT BUY OR REPLACE SHIPS",
        ])
    case .gallery:
      .init(
        title: "MISSION GALLERY",
        rows: [
          "UP / DOWN - SELECT MISSION",
          "RETURN / CLICK - READ DETAILS",
          "TAB - SWITCH LIST / DETAILS",
          "ARROWS / SCROLL IN DETAILS - READ MORE",
          "OPTION-UP/DOWN - PAGE DETAILS",
          "ESC - LIST, THEN PREVIOUS SCREEN",
          "READ ONLY; FLIGHT IS PAUSED",
        ])
    case .handoff:
      .init(
        title: "MISSION DIALOG",
        rows: [
          "ARROWS - CHOOSE CONFIRM / BACK",
          "RETURN / CLICK - SELECT",
          "ESC - BACK WITHOUT TRANSFER",
          "GAME MENU: MISSION CONTACTS TO REOPEN",
          "B (DOCKED) ALSO REOPENS A CONTACT",
        ])
    case .mission:
      .init(
        title: "MISSION MESSAGE",
        rows: [
          "RETURN / SPACE - NEXT PAGE",
          "ARROWS - PREVIOUS / NEXT PAGE",
          "ESC - CLOSE MESSAGE",
          "ORDERS AND REWARDS ARE AUTOMATIC",
          "WAIT TWO SECONDS FOR INCOMING MESSAGE",
        ])
    case .rumour:
      .init(
        title: "STATION RUMOURS",
        rows: [
          "ASK AT THE LOCAL MAIN STATION",
          "ESC - BACK TO PREVIOUS SCREEN",
          "DISCOVERIES ARE SAVED PER GALAXY",
        ])
    case .secret:
      .init(
        title: "XYZZY: COMMANDER CLARKE",
        rows: [
          "0 - WHITE / COLOUR / SHADED SHIPS", "1 - DOCKING TARGETING TIER",
          "2 - MAXIMUM HARDWARE / RESTORE SHIP", "3 - UNLIMITED MISSILES", "4 - UNLIMITED FUEL",
          "5 - SHOW FUEL / NAV JUMP LIMIT", "6 - AUTO TRADE (INCLUDING ILLEGAL)", "7 - SPEECH",
          "8 - UNLIMITED CARGO", "9 - SHOW CASH (STARTS AT 1M CR)",
          "A - AUTO TARGET; E - AUTO ECM", "F - FUEL SCOOPS; B - RETURN FIRE",
          "ESC - RETURN TO GAME",
        ])
    case .demo:
      .init(
        title: "RIGHT-ON COMMANDER DEMO",
        rows: ["THE TITLE APPEARS AFTER THE DEMO", "ESC - CLOSE HELP"])
    case .title:
      .init(
        title: "TITLE SCREEN",
        rows: ["RETURN / SPACE - COMMANDER SCREEN", "NEW COMMANDER: JAMESON"])
    case .gameOver:
      .init(title: "GAME OVER", rows: ["RETURN / SPACE - NEW COMMANDER JAMESON"])
    default:
      .init(
        title: "STATION / SHIP INFORMATION",
        rows: [
          "UP / DOWN / SCROLL - MORE ROWS", "OPTION-UP/DOWN - PAGE LONG LISTS",
          "NUMBER KEYS - CHOOSE SCREEN", "ESC - PREVIOUS SCREEN",
        ])
    }
  }

  private static let flightReference: [HelpPage] = [
    .init(
      title: "FLIGHT: WEAPONS AND DRIVES",
      rows: [
        "FLIGHT MENU SHOWS ALL THESE ACTIONS",
        "T / U / M - ARM / DISARM / MISSILE",
        "E - ECM; G - GALACTIC HYPERDRIVE",
        "J - IN-SYSTEM JUMP",
        "R ALSO SELECTS TARGET / STATION AUTO",
        "P / Q - CANCEL AUTOMATIC GUIDANCE",
        "I - TARGET CAMERA DETAILS / HIDE",
        "COMMAND-SHIFT-E - LAUNCH ESCAPE POD",
        "FLIGHT MENU: DETONATE ENERGY BOMB",
        "SCOOPS: PASS CARGO BELOW YOUR NOSE",
        "WEAPONS / DRIVES REQUIRE EQUIPMENT",
      ]),
    .init(
      title: "OPTIONAL SPIN HOLD",
      rows: [
        "GAME MENU: TOGGLE SPIN HOLD / STOP",
        "V - SPIN MODE; B - STOP SMOOTHLY",
        "ONE FINGER CIRCLE - CHOOSE CW / CCW",
        "CIRCLE AROUND THE TRACKPAD CENTRE",
        "1 / 2 / 3 FINGERS - SLOW/HOLD/FASTER",
        "NO CONTACT - HOLD SET SPIN SPEED",
        "2 FINGERS MOVE - PITCH / YAW",
        "[ / ] - START CCW / CW SPIN",
        "- / = OR + - SLOW / SPEED UP SPIN",
        "LEFT / RIGHT - YAW IN SPIN MODE",
        "UP / DOWN - PITCH; SPACE/DELETE - SPEED",
        "HELP / PAUSE / FOCUS LOSS CANCEL SPIN",
      ]),
  ]
}
