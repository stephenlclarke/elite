import Testing

@testable import L337Core

@Test func chartRangeNotesFactsNamesLegendAndFooterNeverOverlap() {
  for size in [(512.0, 518.0), (768, 768), (1000, 518), (1512, 900)] {
    for screen in [Screen.chart, .shortChart] {
      for docked in [true, false] {
        var game = Game(executive: true)
        game.enableXYZzy()
        game.commander.profitScanEnabled = true
        game.messageTime = 0
        game.docked = docked
        game.screen = screen
        game.commander.fuel = 70
        for zoom in MapZoom.allCases {
          game.mapZoom = zoom
          let frame = Display.map(game, width: size.0, height: size.1)
          for (index, label) in frame.labels.enumerated() {
            #expect(
              label.bounds.x >= 0 && label.bounds.maxX <= size.0 && label.bounds.maxY <= size.1)
            for other in frame.labels.dropFirst(index + 1) {
              #expect(
                !label.bounds.overlaps(other.bounds),
                "\(size) \(screen) \(docked): \(label.text) / \(other.text)")
            }
          }
        }
      }
    }
  }
}

@Test func profitScanToggleNoticeFitsTheSmallestChart() {
  var game = Game(executive: true)
  game.enableXYZzy()
  game.screen = .shortChart
  for _ in 0..<2 {
    game.toggleProfitScan()
    let frame = Display.map(game, width: 512, height: 518)
    let notice = frame.labels.first { $0.text == game.message }
    #expect(notice != nil)
    #expect(notice!.bounds.maxX <= 496)
    #expect(
      !frame.labels.filter { $0.text != game.message }.contains {
        $0.bounds.overlaps(notice!.bounds)
      })
  }
}
