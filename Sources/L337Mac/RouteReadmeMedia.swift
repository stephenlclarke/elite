import AppKit
import ImageIO
import L337Core
import UniformTypeIdentifiers

@MainActor
func exportRouteReadmeMedia(at root: URL = URL(fileURLWithPath: ".")) throws {
  let directory = root.appendingPathComponent("docs/images")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  var game = try makeRouteReadmeMediaGame()
  try writeRoutePNG(game, to: directory.appendingPathComponent("route-alternatives-galaxy.png"))
  game.key("5")
  guard game.navigationReturn == .shortChart else { throw SaveError.invalidCommander }
  try writeRoutePNG(game, to: directory.appendingPathComponent("route-alternatives-local.png"))
}

/// Shared native planner scene for README exports and their pixel regression.
@MainActor
func makeRouteReadmeMediaGame() throws -> Game {
  var game = Game(executive: false)
  // Prepare a real current fit through the ordinary shop's paid predecessor chain.
  game.commander.credits = 1_000_000
  game.screen = .equipment
  for tier in [NavigationTier.advanced, .military] {
    guard let index = Equipment.all.firstIndex(where: { $0.name == tier.equipmentName }),
      game.equipmentAvailable(Equipment.all[index])
    else { throw SaveError.invalidCommander }
    let credits = game.commander.credits
    game.selection = index
    game.purchase()
    guard game.commander.navigationTier == tier,
      game.commander.credits == credits - tier.price
    else { throw SaveError.invalidCommander }
  }
  guard game.commander.equipmentInventory != nil,
    game.commander.equipmentPurchaseHistory?.paid.count == 2,
    game.commander.fuel == game.commander.fuelCapacity, game.commander.valid
  else { throw SaveError.invalidCommander }
  game.commander.profitScanEnabled = true
  game.viewportWidth = 1024
  game.viewportHeight = 768
  // Original world geometry need not give the old BBC target multiple routes.
  // Select the first real alternative-bearing destination in stable numeric order.
  let origin = game.commander.system
  let galaxy = game.commander.galaxy
  let destinations = game.knownSystems.filter { $0.id != origin }.sorted { $0.id < $1.id }
  for destination in destinations {
    game.screen = .chart
    game.selectedSystem = destination.id
    game.galacticBrowse.targets[galaxy] = destination.id
    game.key("n")
    if game.screen != .navigation { continue }
    if game.navigationOptions.count > 1 { break }
  }
  guard game.screen == .navigation, game.navigationOptions.count > 1 else {
    throw SaveError.invalidCommander
  }
  // Use the real planner and input path, including the selected hull's actual fuel and navigation limits.
  game.key("down")
  return game
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
