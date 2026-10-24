import Testing

@testable import EliteCore

struct StationScreenGuideTests {
  @Test(arguments: [false, true])
  func flightGuideKeepsFlightDestinationsRegardlessOfDockServices(available: Bool) {
    let page = StationScreenGuide.page(
      docked: false, stationName: "RRS Headquarters", equipmentAvailable: available,
      marketAvailable: available, exchangeAvailable: available)
    #expect(page.title == "SCREENS IN SPACE")
    #expect(page.rows.contains("0 / 1 / 2 / 3 - FRONT/REAR/LEFT/RIGHT"))
    #expect(page.rows.contains("6 - SYSTEM DATA / PLANET VIEW"))
    #expect(page.rows.contains("7 - MARKET PRICES"))
    #expect(!page.rows.contains { $0.contains("UNAVAILABLE") || $0.contains("EXCHANGE") })
    #expect(page.rows.count == 9)
  }

  @Test(arguments: ["Main station", "RRS Waystation", "RRS Headquarters"])
  func stationGuideNamesTheActualDockAndKeepsEveryDestination(station: String) {
    let main = station == "Main station"
    let page = StationScreenGuide.page(
      docked: true, stationName: main ? nil : station, equipmentAvailable: main,
      marketAvailable: main, exchangeAvailable: main)
    #expect(page.title == (main ? "STATION SCREENS" : station.uppercased() + " SCREENS"))
    #expect(page.rows.contains("0 - LAUNCH"))
    #expect(page.rows.contains("4 / 5 - CHARTS WITH PLANET DATA"))
    #expect(page.rows.contains("8 / 9 - STATUS / INVENTORY"))
    #expect(page.rows.contains("ESC - BACK ONE LEVEL; K - HELP"))
    if main {
      #expect(page.rows.contains("3 - EQUIPMENT"))
      #expect(page.rows.contains("6 - SHIP SHOWROOM"))
      #expect(page.rows.contains("7 - MARKET: BUY / SELL"))
    } else {
      #expect(page.rows.contains("3 - EQUIPMENT (SHOP UNAVAILABLE)"))
      #expect(page.rows.contains("6 - SHIP SHOWROOM (NO EXCHANGE)"))
      #expect(page.rows.contains("7 - MARKET (TRADING UNAVAILABLE)"))
      #expect(!page.rows.contains("7 - MARKET: BUY / SELL"))
    }
    #expect(page.rows.count == 9)
  }

  @Test(arguments: ["equipment", "market", "exchange"])
  func oneUnavailableServiceDoesNotHideOtherAvailableServices(unavailable: String) {
    let page = StationScreenGuide.page(
      docked: true, stationName: nil, equipmentAvailable: unavailable != "equipment",
      marketAvailable: unavailable != "market", exchangeAvailable: unavailable != "exchange")
    let unavailableRows = page.rows.filter {
      $0.contains("UNAVAILABLE") || $0.contains("NO EXCHANGE")
    }
    #expect(unavailableRows.count == 1)
    switch unavailable {
    case "equipment":
      #expect(unavailableRows == ["3 - EQUIPMENT (SHOP UNAVAILABLE)"])
      #expect(page.rows.contains("7 - MARKET: BUY / SELL"))
      #expect(page.rows.contains("6 - SHIP SHOWROOM"))
    case "market":
      #expect(unavailableRows == ["7 - MARKET (TRADING UNAVAILABLE)"])
      #expect(page.rows.contains("3 - EQUIPMENT"))
      #expect(page.rows.contains("6 - SHIP SHOWROOM"))
    default:
      #expect(unavailableRows == ["6 - SHIP SHOWROOM (NO EXCHANGE)"])
      #expect(page.rows.contains("3 - EQUIPMENT"))
      #expect(page.rows.contains("7 - MARKET: BUY / SELL"))
    }
  }
}
