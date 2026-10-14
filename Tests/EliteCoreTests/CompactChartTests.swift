import Testing

@testable import EliteCore

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
