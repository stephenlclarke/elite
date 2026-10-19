import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@MainActor @Test func routePreviewSequentialExportsRetainEveryCandidateAndMetricRow() throws {
  var game = try makeRouteReadmeMediaGame()
  try #require(game.screen == .navigation && game.navigationOptions.count > 1)
  try #require(game.commander.navigationTier == .military && game.commander.valid)
  try #require(game.commander.equipmentPurchaseHistory?.paid.count == 2)
  try #require(game.commander.fuel == 70 && game.commander.fuelCapacity == 70)
  let options = game.navigationOptions
  let selected = game.navigationSelection
  try #require(selected == 1)
  for local in [false, true] {
    if local { game.key("5") }
    #expect(game.screen == .navigation && game.navigationSelection == selected)
    #expect(game.navigationOptions.map(\.plan) == options.map(\.plan))
    #expect(game.navigationOptions.map(\.labels) == options.map(\.labels))
    let frame = Display.presentation(game, width: 1024, height: 768)
    let layout = NavigationPreviewLayout(game: game, width: 1024, height: 768)
    #expect(layout.chart.local == local)
    #expect(layout.candidateRects.count == options.count)
    let titles = frame.labels.filter { label in
      layout.candidateRects.contains { $0.y == label.bounds.y }
    }
    #expect(titles.count == options.count)
    let metrics = frame.labels.filter {
      $0.text.contains("jumps /") && $0.ink == .white
    }
    #expect(metrics.count == options.count)
    let row = ceil(GameTypography.scale * 7) + 8
    for (index, option) in options.enumerated() {
      let rect = layout.candidateRects[index]
      let pattern = index == selected ? "solid" : "dash\(index + 1)"
      let title =
        (index == selected ? "> " : "  ") + "\(index + 1) [\(pattern)] "
        + option.labels.joined(separator: "/")
      #expect(titles.contains { $0.text == title && $0.bounds.y == rect.y })
      if index == selected { #expect(titles.contains { $0.text == title && $0.ink == .cyan }) }
      #expect(game.routeCandidateIsFeasible(option.plan))
      let metric = String(
        format: "%d jumps / %.1f ly / fuel OK; refuel at stops",
        option.plan.path.count - 1 - option.plan.stopIndex, option.distance)
      #expect(metrics.contains { $0.text == metric && $0.bounds.y == rect.y + row })
    }
    let image = try #require(imageForGame(game, width: 1024, height: 768, scale: 2))
    let data = try #require(image.dataProvider?.data)
    let bytes = CFDataGetBytePtr(data)!
    for label in titles + metrics {
      var bright = 0
      for y in Int(label.bounds.y * 2)..<Int(label.bounds.maxY * 2) {
        for x in Int(label.bounds.x * 2)..<Int(label.bounds.maxX * 2) {
          let offset = y * image.bytesPerRow + x * 4
          let white = bytes[offset] > 220 && bytes[offset + 1] > 220 && bytes[offset + 2] > 220
          let coloured = max(bytes[offset], max(bytes[offset + 1], bytes[offset + 2])) > 220
          if label.ink == .white ? white : coloured {
            bright += 1
          }
        }
      }
      #expect(
        bright > 0, "Missing exported row pixels for \(local ? "local" : "galaxy"): \(label.text)"
      )
    }
  }
}
