enum StationScreenGuide {
  static func page(
    docked: Bool, stationName: String?, equipmentAvailable: Bool,
    marketAvailable: Bool, exchangeAvailable: Bool
  ) -> HelpPage {
    let navigation = [
      "ARROWS - MOVE; RETURN - CHOOSE",
      "ESC - BACK ONE LEVEL; K - HELP",
      "SCREENS MENU HAS THE SAME DESTINATIONS",
    ]
    guard docked else {
      return .init(
        title: "SCREENS IN SPACE",
        rows: [
          "0 / 1 / 2 / 3 - FRONT/REAR/LEFT/RIGHT",
          "4 / 5 - GALACTIC / LOCAL CHART",
          "6 - SYSTEM DATA / PLANET VIEW",
          "7 - MARKET PRICES",
          "8 / 9 - STATUS / INVENTORY",
          "ESC - PREVIOUS SCREEN / COCKPIT",
        ] + navigation)
    }
    return .init(
      title: stationName.map { $0.uppercased() + " SCREENS" } ?? "STATION SCREENS",
      rows: [
        "0 - LAUNCH",
        equipmentAvailable ? "3 - EQUIPMENT" : "3 - EQUIPMENT (SHOP UNAVAILABLE)",
        "4 / 5 - CHARTS WITH PLANET DATA",
        exchangeAvailable ? "6 - SHIP SHOWROOM" : "6 - SHIP SHOWROOM (NO EXCHANGE)",
        marketAvailable ? "7 - MARKET: BUY / SELL" : "7 - MARKET (TRADING UNAVAILABLE)",
        "8 / 9 - STATUS / INVENTORY",
      ] + navigation)
  }
}
