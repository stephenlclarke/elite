import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@MainActor @Test func routePreviewSequentialExportsRetainEveryCandidateAndMetricRow() throws {
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  game.commander.profitScanEnabled = true
  game.viewportWidth = 1024
  game.viewportHeight = 768
  game.screen = .chart
  game.selectedSystem = 0
  game.key("n")
  game.key("down")
  #expect(game.navigationOptions.count == 3)
  for local in [false, true] {
    if local { game.key("5") }
    let frame = Display.presentation(game, width: 1024, height: 768)
    let layout = NavigationPreviewLayout(game: game, width: 1024, height: 768)
    #expect(layout.chart.local == local)
    #expect(frame.labels.contains { $0.text.contains("3 [dash3] Trade Opportunities") })
    let metrics = frame.labels.filter {
      $0.text.contains("jumps /") && $0.ink == .white
    }
    #expect(metrics.count == 3)
    let image = try #require(imageForGame(game, width: 1024, height: 768, scale: 2))
    let data = try #require(image.dataProvider?.data)
    let bytes = CFDataGetBytePtr(data)!
    for label in metrics {
      var white = 0
      for y in Int(label.bounds.y * 2)..<Int(label.bounds.maxY * 2) {
        for x in Int(label.bounds.x * 2)..<Int(label.bounds.maxX * 2) {
          let offset = y * image.bytesPerRow + x * 4
          if bytes[offset] > 220 && bytes[offset + 1] > 220 && bytes[offset + 2] > 220 {
            white += 1
          }
        }
      }
      #expect(
        white > 0, "Missing exported metric pixels for \(local ? "local" : "galaxy"): \(label.text)"
      )
    }
  }
}
