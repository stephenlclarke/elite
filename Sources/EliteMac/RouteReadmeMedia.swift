import AppKit
import EliteCore
import ImageIO
import UniformTypeIdentifiers

@MainActor
func exportRouteReadmeMedia(at root: URL = URL(fileURLWithPath: ".")) throws {
  let directory = root.appendingPathComponent("docs/images")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  game.commander.profitScanEnabled = true
  game.viewportWidth = 1024
  game.viewportHeight = 768
  game.screen = .chart
  game.selectedSystem = 0
  game.key("n")
  guard game.screen == .navigation, game.navigationOptions.count > 1 else {
    throw SaveError.invalidCommander
  }
  // Use the real planner and input path, including its unchanged seven-LY tank limits.
  game.key("down")
  try writeRoutePNG(game, to: directory.appendingPathComponent("route-alternatives-galaxy.png"))
  game.key("5")
  guard game.navigationReturn == .shortChart else { throw SaveError.invalidCommander }
  try writeRoutePNG(game, to: directory.appendingPathComponent("route-alternatives-local.png"))
}

@MainActor
private func writeRoutePNG(_ game: Game, to url: URL) throws {
  guard let image = imageForGame(game, width: 1024, height: 768, scale: 2),
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { throw SaveError.invalidCommander }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { throw SaveError.invalidCommander }
}
