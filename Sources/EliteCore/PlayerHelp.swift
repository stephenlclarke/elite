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
    var contextGame = game
    contextGame.screen = screen
    var pages = paginate(context(for: screen, game: contextGame))
    if ![Screen.demo, .title, .gameOver, .secret, .mission, .handoff].contains(screen)
      && !(screen == .showroom && game.showroom.trading)
    {
      pages.append(
        .init(
          title: game.docked ? "STATION SCREENS" : "SCREENS IN SPACE",
          rows: [
            game.docked ? "0 - LAUNCH" : "0 / 1 / 2 / 3 - FRONT/REAR/LEFT/RIGHT",
            game.docked ? "3 - EQUIPMENT" : "4 / 5 - GALACTIC / LOCAL CHART",
            game.docked ? "4 / 5 - CHARTS WITH PLANET DATA" : "6 - SYSTEM DATA / PLANET VIEW",
            game.docked ? "6 - SHIP SHOWROOM" : "7 - MARKET PRICES",
            game.docked ? "7 - MARKET: BUY / SELL" : "8 / 9 - STATUS / INVENTORY",
            game.docked ? "8 / 9 - STATUS / INVENTORY" : "ESC - PREVIOUS SCREEN / COCKPIT",
            "ARROWS - MOVE; RETURN - CHOOSE",
            "ESC - BACK ONE LEVEL; K - HELP",
            "SCREENS MENU HAS THE SAME DESTINATIONS",
          ]))
      pages.append(
        .init(
          title: "MORE ACTIONS",
          rows: [
            "GAME: MISSIONS / CONTACTS / CONTRACTS",
            "GAME MENU: MISSION LIBRARY",
            "L - MISSION GALLERY",
            "B (DOCKED) - MISSION CONTACTS",
            "U (DOCKED) - STATION RUMOURS",
            "OPTION-UP/DOWN - PAGE LONG LISTS",
            "SCROLL - BROWSE THE AREA UNDER POINTER",
            "COMMAND-P - PAUSE / RESUME",
            "COMMAND-S / COMMAND-O - SAVE / RELOAD",
            "COMMAND-SHIFT-S / O - SAVE AS / OPEN",
            "X Y Z Z Y - CLARKE / SECRET OPTIONS",
            "COMMAND-Q - QUIT",
          ]))
      if !game.docked {
        if !screen.isFlight { pages.append(contentsOf: paginate(context(for: .front, game: game))) }
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
    return pages.flatMap(paginate)
  }

  private static func paginate(_ context: HelpPage) -> [HelpPage] {
    let rows = context.rows.flatMap { ScriptLibraryText.wrap($0, width: 40) }
    return stride(from: 0, to: rows.count, by: 16).map { offset in
      HelpPage(
        title: context.title,
        rows: Array(rows[offset..<min(offset + 16, rows.count)]))
    }
  }

  private static func galleryRows(_ game: Game) -> [String] {
    var rows: [String]
    if game.gallery.campaignReview != nil {
      rows = [
        "ARROWS - CHOOSE START / BACK",
        "RETURN / CLICK - SELECT; BACK IS DEFAULT",
        "ESC - BACK WITHOUT STARTING A TRIAL",
        "START CREATES A PRIVATE CAMPAIGN TRIAL",
      ]
    } else if game.gallery.detail && game.gallery.campaignLinks {
      rows = [
        "UP / DOWN - SELECT CAMPAIGN LINK",
        "RETURN / CLICK - FOLLOW SELECTED LINK",
        "PAGE-UP/DOWN - MOVE EIGHT LINKS",
        "TAB - RETURN TO DETAILS",
        "ESC - PREVIOUS CAMPAIGN PAGE",
      ]
    } else {
      rows = [
        "UP / DOWN - SELECT MISSION OR SCROLL",
        "RETURN / CLICK - DETAILS OR CAMPAIGN LINKS",
        "TAB - SWITCH LIST / DETAILS",
        "OPTION-UP/DOWN - PAGE DETAILS",
        "ESC - PREVIOUS PAGE, LIST, THEN EXIT",
      ]
    }
    if game.gallery.campaignReview == nil {
      if MissionUIAction.trial.isEnabled(in: game) {
        rows.append(
          game.selectedGalleryMissionIsOwnedAssignment
            ? "T - REVIEW PRIVATE CAMPAIGN TRIAL" : "T - START PRIVATE MISSION TRIAL")
      }
      if MissionUIAction.retry.isEnabled(in: game) { rows.append("R - RETRY SELECTED MISSION") }
    }
    if game.isMissionTrial {
      rows += ["GAME MENU - RESTART TRIAL / RETURN TO COMMANDER"]
    }
    rows += ["READING DOES NOT ACCEPT WORK; FLIGHT IS PAUSED"]
    return rows
  }

  private static func context(for screen: Screen, game: Game) -> HelpPage {
    switch screen {
    case .front, .rear, .left, .right:
      .init(
        title: "FLIGHT: START HERE",
        rows: [
          "ARROWS - PITCH / ROLL",
          "SPACE - ACCELERATE; DELETE - BRAKE",
          "RETURN - USE SELECTED TOOL (HOLD)",
          "W - COMBAT / MINING / SALVAGE CUTTER",
          "TAB / R - NEXT TARGET / AUTO GUIDANCE",
          "F - SHIPS / MINING / SALVAGE / ALL",
          "WORK HOLD NEEDS ITS FITTED MODULE",
          "SMALL ITEMS: AUTO SCOOP; LARGE: HOLD",
          "Q - CANCEL AUTOMATIC GUIDANCE",
          "4 / 5 - CHART; H - HYPERSPACE",
          "SUN / PLANET BEARINGS - FLIGHT HUD",
          "FUEL SCOOPS - CRUISE TOWARD SUN",
          "WATCH CABIN TEMP; TURN AWAY TO COOL",
          "OVERHEATING / SURFACE IMPACT IS FATAL",
          "FLIGHT MENU - WEAPONS / DRIVES / POD",
          "ESC - BACK; NEVER LAUNCHES ESCAPE POD",
          "TRACKPAD: 2 FINGERS - STEER / CRUISE",
          "1 FINGER - SLOW; 3 FINGERS - SPEED UP",
          "HOLD OFF CENTRE TO KEEP TURNING",
          "CENTRE 2 FINGERS - STOP TURNING",
          "LIFT ALL - CENTRE YOKE / KEEP SPEED",
        ])
    case .system:
      .init(
        title: "SYSTEM DATA",
        rows: ["UP / DOWN / SCROLL - LONG PLANET DATA", "ESC - PREVIOUS SCREEN", "K - HELP"])
    case .market where !game.docked:
      .init(
        title: "MARKET PRICES",
        rows: [
          "UP / DOWN / SCROLL - BROWSE PRICES",
          "DOCK TO BUY OR SELL IN MARKET (7)",
          "ESC - PREVIOUS SCREEN",
        ])
    case .status:
      .init(
        title: "COMMANDER STATUS",
        rows: [
          "LOCATION, CASH, CONDITION AND LEGALITY",
          "FITTED SHIELD, NAVIGATION AND ENERGY",
          "CORE AND SEPARATE SPECIALTY MODULES",
          "9 - INVENTORY: CARGO AND FULL FITTINGS",
          game.informationWindow.hint == nil
            ? "ALL ROWS VISIBLE" : "UP / DOWN / SCROLL - MORE ROWS",
          "ESC - PREVIOUS SCREEN",
        ])
    case .inventory:
      .init(
        title: "INVENTORY",
        rows: [
          "CARGO, MISSION PROPERTY AND FITTINGS",
          "ACTUAL FITTED AND HELD EQUIPMENT",
          "GRADE AND ACQUISITION SOURCE",
          "TAB - SELECT VISIBLE FIT / STORE ACTION",
          "RETURN - APPLY THE SELECTED ACTION",
          "LEFT / RIGHT - RECOVERED UPGRADE CHOICE",
          "RECOVERED: BEFORE / AFTER AND NEXT GRADE",
          "RECOVERED DEVICES: FIT NOW IN SPACE",
          "MINING / SALVAGE MODULES REQUIRE A CORE",
          game.informationWindow.hint == nil
            ? "ALL ROWS VISIBLE" : "UP / DOWN / SCROLL - MORE ROWS",
          "OPTION-UP/DOWN - PAGE LONG LISTS",
          "ESC - PREVIOUS SCREEN",
        ])
    case .buy, .sell, .market:
      .init(
        title: "MARKET: BUY / SELL",
        rows: [
          "UP / DOWN / SCROLL - SELECT PRODUCT",
          screen == .sell ? "RETURN - SELL ONE UNIT" : "RETURN - BUY ONE UNIT",
          "COLOUR: CATEGORY; ACTION: AVAILABILITY",
          "TAB / CLICK BUY OR SELL - MODE",
          "CLICK TRADE BUTTON - ONE UNIT",
          "LEFT - SELL ONE; RIGHT - BUY ONE",
          "ESC - PREVIOUS SCREEN",
        ])
    case .equipment:
      .init(
        title: "EQUIPMENT",
        rows: [
          "UP / DOWN / SCROLL - SELECT ITEM",
          "RETURN - PURCHASE / REFUEL",
          "LEFT / RIGHT - SELECT COMBAT MOUNT",
          "CLICK FRONT/LEFT/RIGHT/REAR - MOUNT",
          "CLICK AN ITEM TO SELECT IT",
          "INVENTORY (9) - FITTED / HELD DETAILS",
          "ESC - PREVIOUS SCREEN",
        ]
          + (game.passengerBerthSelected
            ? ["S - STORE EMPTY PASSENGER CABIN", "R - REFIT STORED PASSENGER CABIN"] : []))
    case .chart, .shortChart:
      .init(
        title: "CHARTS AND PLANET DATA",
        rows: [
          "LEFT / RIGHT OR CLICK - SELECT PLANET",
          game.docked ? "UP / DOWN / SCROLL - PLANET DATA" : "PLANET DATA: 6",
          "SLASH (GALACTIC CHART) - SEARCH",
          "TYPE - FILTER; UP / DOWN - RESULT",
          "RETURN - CHOOSE; ESC - END SEARCH",
          "DELETE - ERASE ONE LETTER",
          "COMMAND-DELETE / CLICK CLEAR - RESET",
          "O - CURRENT LOCATION; D - DISTANCE",
          "M - ECONOMY / GOVERNMENT / TECHNOLOGY",
          "N - ROUTES (FITTED NAV COMPUTER)",
          "P - TOGGLE TOP-FIVE PROFIT SCAN",
          "Z (LOCAL) - CHANGE RANGE",
          "[ / ] (GALACTIC) - VIEW GALAXY",
          "GALAXY BUTTONS - VIEW GALAXY",
          "H - HYPERSPACE WHEN IN FLIGHT",
          "ESC - PREVIOUS SCREEN",
        ])
    case .navigation:
      .init(
        title: "NAVIGATION ROUTES",
        rows: [
          "UP / DOWN / CLICK - PREVIEW CANDIDATE",
          "RETURN / SET ROUTE - COMMIT PREVIEW",
          "ESC / BACK - KEEP ACTIVE ROUTE",
          "4 / 5 - GALAXY / LOCAL PREVIEW",
          "LOCAL LEGS CLIP; CUES CONTINUE OFFSCREEN",
          "OPTION-UP/DOWN - SCROLL DETAILS",
          "C - CLEAR ROUTE",
          "P - TOGGLE TOP-FIVE PROFIT SCAN",
          "FEWEST / SAFEST / TRADE / CARGO",
          "IDENTICAL PATHS COMBINE THEIR LABELS",
          "BASIC SEARCH: TANK CAPACITY LY + 7",
          "ADVANCED: CAPACITY + 14; MILITARY: ALL",
          "FIRST LEG: ACTUAL FUEL; THEN REFUEL",
          "DOCK AT EACH STOP; H STARTS EACH JUMP",
        ])
    case .showroom where game.showroom.trading:
      .init(
        title: "SHIP EXCHANGE",
        rows: [
          "REVIEW PRICE, TRADE-IN AND FITTING", "LEFT / RIGHT / TAB - BACK OR CONFIRM",
          "RETURN / CLICK - SELECT", "UP / DOWN / SCROLL - LONG QUOTES",
          "ESC - CANCEL WITHOUT CHANGES", "BLOCKED TRADES EXPLAIN EACH CONFLICT",
        ])
    case .showroom:
      .init(
        title: "SHIP SHOWROOM",
        rows: [
          "UP / DOWN - SELECT SHIP",
          "RETURN - SPECS, THEN REVIEW TRADE",
          "TAB - CHANGE SHIPS / SPECS PANE",
          "ARROWS IN SPECS - SCROLL",
          "SLASH / CLICK SEARCH - FILTER SHIPS",
          "UP / DOWN IN SEARCH - SELECT RESULT",
          "RETURN - SPECS; ESC - FINISH SEARCH",
          "DELETE - ERASE; COMMAND-DELETE - CLEAR",
          "CLICK CLEAR FILTER - SHOW ALL SHIPS",
          "CLICK PIN BASE / YOUR SHIP / COMPARE",
          "CLICK PREV / NEXT TO CHANGE PROFILE",
          "CLICK SOURCE NOTES / GAME VALUES",
          "CLICK PAUSE / ROTATE TO STOP MOTION",
          "OPTION-UP/DOWN - PAGE ACTIVE PANE",
          "ESC - SEARCH, THEN LIST, THEN STATION",
          "CLICK SWITCH SHIP - REVIEW EXCHANGE",
          "LEFT / RIGHT, RETURN - CONFIRM / BACK",
          "CLICK SORT: A-Z / POWER (STRONGEST)",
          "POWER: ENERGY + SHIELDS + WEAPONS",
        ])
    case .contracts:
      .init(
        title: "STATION CONTRACTS",
        rows: [
          "UP / DOWN - SELECT OFFER", "RETURN / CLICK - READ BRIEFING",
          "LEFT / RIGHT - ACCEPT / DECLINE / BACK", "RETURN - CHOOSE; BACK IS THE DEFAULT",
          "ESC - BACK TO BOARD, THEN STATION", "SCROLL - READ LONG BRIEFINGS",
          "READING DOES NOT START A DEADLINE", "ACTIVE WORK REMAINS IN MISSION GALLERY",
        ])
    case .library:
      .init(
        title: "MISSION LIBRARY",
        rows: [
          "UP / DOWN - SELECT OR SCROLL",
          "RETURN / CLICK - OPEN BOOK OR CHAPTER",
          "LEFT / RIGHT - PREVIOUS / NEXT CHAPTER",
          "TAB - CONTENTS / READING",
          "I - BOOK SOURCE / LICENCE",
          "OPTION-UP/DOWN - PAGE TEXT",
          "ESC - CONTENTS, BOOKS, PREVIOUS SCREEN",
          "READ ONLY; FLIGHT IS PAUSED",
        ])
    case .gallery:
      .init(title: "MISSION GALLERY", rows: galleryRows(game))
    case .handoff:
      .init(
        title: "MISSION DIALOG",
        rows: (game.offeredScriptChoices.isEmpty
          ? ["ARROWS - CHOOSE CONFIRM / BACK"]
          : [
            "UP / DOWN - BROWSE CHOICES",
            "LEFT / RIGHT - CHOOSE CONFIRM / BACK",
            game.offeredScriptChoices.allSatisfy { $0.group == nil }
              ? "READING / BACK DOES NOT ANSWER" : "READING / BACK DOES NOT CHOOSE A BRANCH",
          ]) + [
            "RETURN / CLICK - SELECT",
            "ESC - BACK WITHOUT TRANSFER",
            "GAME MENU: MISSION CONTACTS TO REOPEN",
            "B (DOCKED) ALSO REOPENS A CONTACT",
          ] + (game.packDialogWindow.last > 0 ? ["OPTION-UP/DOWN - READ MESSAGE"] : []))
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
          "2 - MAXIMUM HARDWARE", "C - FREE COBRA MK III / MAXIMUM REFIT",
          "3 - UNLIMITED MISSILES", "4 - UNLIMITED FUEL",
          "5 - SHOW FUEL / NAV JUMP LIMIT", "6 - AUTO TRADE (INCLUDING ILLEGAL)", "7 - SPEECH",
          "8 - UNLIMITED CARGO", "9 - SHOW CASH (STARTS AT 1M CR)",
          "A - AUTO TARGET; E - AUTO ECM", "F - FUEL SCOOPS; B - RETURN FIRE",
          "L - RESET LEGAL STATUS TO CLEAN",
          "ESC - RETURN TO GAME",
        ])
    case .demo:
      .init(
        title: "RIGHT-ON COMMANDER DEMO",
        rows: ["THE TITLE APPEARS AFTER THE DEMO", "ESC - CLOSE HELP"])
    case .title:
      .init(
        title: "TITLE SCREEN",
        rows: ["RETURN / SPACE - CONTINUE COMMANDER", "COMMANDER: " + game.commander.name])
    case .gameOver:
      .init(title: "GAME OVER", rows: ["RETURN / SPACE - NEW COMMANDER JAMESON"])
    default:
      .init(
        title: "STATION / SHIP INFORMATION",
        rows: [
          game.informationWindow.hint == nil
            ? "ALL ROWS VISIBLE" : "UP / DOWN / SCROLL - MORE ROWS",
          game.informationWindow.hint == nil
            ? "NUMBER KEYS - CHOOSE SCREEN" : "OPTION-UP/DOWN - PAGE LONG LISTS",
          "NUMBER KEYS - CHOOSE SCREEN", "ESC - PREVIOUS SCREEN",
        ])
    }
  }

  private static let flightReference: [HelpPage] = [
    .init(
      title: "FINDING THE STATION",
      rows: [
        "YELLOW COMPASS - CURRENT VIEW BEARING",
        "RANGE IS IN LOCAL FLIGHT UNITS",
        "BEHIND - TURN TOWARD LEFT / RIGHT",
        "COMPASS UP / DOWN - STATION ELEVATION",
        "VIEWS: 0 FRONT; 1 REAR; 2 LEFT; 3 RIGHT",
        "COMPASS WORKS BEYOND SCANNER RANGE",
        "NO TARGETING COMPUTER NEEDED FOR CUE",
        "TAB - CYCLE SHIPS, THEN STATIONS",
        "AUTO: DOCKING TARGETING TIER OR BETTER",
        "AUTO FACES WAYPOINT, BRAKES, ALIGNS",
        "Q OR MANUAL CONTROLS - CANCEL AUTO",
      ]),
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
        "OPTION-UP/DOWN - PAGE TARGET DETAILS",
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
