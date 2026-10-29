import Testing

@testable import EliteCore

struct MarketDisplayOrderUnitTests {
  @Test func authoredOrderKeepsEachStableCommodityIDAndCargoIndex() {
    let expected = [9, 8, 10, 2, 7, 12, 13, 15, 14, 1, 4, 5, 0, 11, 6, 3, 16]
    #expect(MarketDisplayOrder.commodityIDs == expected)
    #expect(Set(expected) == Set(Commodity.all.indices))
    #expect(Commodity.all[0].name == "Food" && Commodity.all[9].name == "Alloys")
    #expect(Commodity.all[10].name == "Weapons" && Commodity.all[16].name == "Alien Items")
    #expect(MarketDisplayOrder.start(selection: 0, visible: 17) == 0)
    #expect(MarketDisplayOrder.start(selection: 0, visible: 4) == 9)
    #expect(MarketDisplayOrder.start(selection: 16, visible: 4) == 13)
  }

  @Test func arrowSelectionFollowsAuthoredOrderWithoutTradingOrChangingModes() {
    let ids = MarketDisplayOrder.commodityIDs
    for screen in [Screen.buy, .sell, .market] {
      var game = Game(executive: false)
      game.screen = screen
      game.selection = ids[0]
      let commander = game.commander
      let stock = game.market
      game.key("up")
      #expect(game.selection == ids[0])
      for id in ids.dropFirst() {
        game.key("down")
        #expect(game.selection == id && game.screen == screen)
      }
      game.key("down")
      #expect(game.selection == ids.last)
      for id in ids.dropLast().reversed() {
        game.key("up")
        #expect(game.selection == id && game.screen == screen)
      }
      game.selection = 0  // Food remains stable ID0, despite moving to authored display row12.
      _ = Display.marketScreen(game, width: 768, height: 768)
      game.key("tab")
      #expect(game.selection == 0)
      #expect(game.commander == commander && game.market == stock)
    }
  }

  @Test func renderedRowsAndClicksUseTheSameStableIDsAtCompactAndWideSizes() throws {
    let ids = MarketDisplayOrder.commodityIDs
    for (width, height) in [(512.0, 518.0), (1512.0, 982.0), (1512.0, 4000.0)] {
      var seen = Set<Int>()
      for selected in ids {
        var game = Game(executive: false)
        game.screen = .buy
        game.viewportWidth = width
        game.viewportHeight = height
        game.selection = selected
        let before = game.commander
        let stock = game.market
        let layout = StationLayout(game: game, width: width, height: height, footer: 144)
        let start = MarketDisplayOrder.start(selection: selected, visible: layout.count)
        let visible = Array(ids.dropFirst(start).prefix(layout.count))
        let frame = Display.marketScreen(game, width: width, height: height)
        for (row, id) in visible.enumerated() {
          let y = 114 + Double(row) * layout.row
          let label = try #require(
            frame.labels.first { $0.x == layout.left && $0.y == y })
          #expect(label.text == Commodity.all[id].name)
          #expect(frame.labels.contains { $0.y == y && $0.text == ">" } == (selected == id))
          var clicked = game
          clicked.marketClick(x: layout.left + 1, y: y + 1)
          #expect(clicked.selection == id)
          #expect(clicked.commander == before && clicked.market == stock)
          seen.insert(id)
        }
        #expect(game.selection == selected && game.commander == before && game.market == stock)
      }
      #expect(seen == Set(ids))
    }
  }
}
