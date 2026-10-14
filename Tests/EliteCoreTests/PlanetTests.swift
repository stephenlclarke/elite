import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import EliteCore
@testable import EliteMac

@Test func planetIdentityTerrainAndSeamAreDeterministicAndIndependentOfGameRandomness() {
  let systems = Universe.galaxy(number: 0)
  let identity = PlanetIdentity(galaxy: 0, system: systems[7])
  let terrain = PlanetTerrain(identity: identity)
  #expect(terrain == PlanetTerrain(identity: identity))
  #expect(identity != PlanetIdentity(galaxy: 1, system: systems[7]))
  #expect(identity != PlanetIdentity(galaxy: 0, system: systems[8]))
  #expect(terrain.elevation.count == 256 * 128 && terrain.clouds.count == 256 * 128)
  #expect(terrain.elevation.allSatisfy { (0...1).contains($0) })
  #expect(terrain.clouds.allSatisfy { (0...1).contains($0) })
  for latitude in [-Double.pi / 2, -0.2, 0, 0.7, Double.pi / 2] {
    let a = terrain.sample(terrain.elevation, longitude: -.pi, latitude: latitude)
    let b = terrain.sample(terrain.elevation, longitude: .pi, latitude: latitude)
    #expect(abs(a - b) < 1e-9)
  }
  #expect(PlanetPalette(identity: identity).ocean.z > PlanetPalette(identity: identity).ocean.x)
}

@Test func dockedChartsContainPlanetFactsAndCluesWithNoSeparateDataScreen() {
  var game = Game(executive: false)
  game.commander.missionStage = .huntingConstrictor
  game.commander.galaxy = 1
  game.systems = Universe.galaxy(number: 1)
  game.selectedSystem = 118
  game.key("5")
  let commander = game.commander
  for screen in [Screen.chart, .shortChart] {
    game.screen = screen
    if screen == .chart { game.selectChartSystem(118) }
    for (width, height) in [(512.0, 518.0), (768, 768), (1512, 982)] {
      var texts: [String] = []
      for _ in 0..<4 {
        let frame = Display.presentation(game, width: width, height: height)
        texts += frame.labels.map(\.text)
        #expect(frame.labels.allSatisfy { $0.bounds.maxY <= height && $0.bounds.maxX <= width })
        game.key("pagedown")
      }
      #expect(texts.contains { $0.contains("Population:") })
      #expect(texts.contains { $0.contains("Gross productivity:") })
      #expect(texts.joined(separator: " ").contains("ORARRA"))
      game.chartInformationScroll = 0
    }
    game.key("6")
    #expect(game.screen == .showroom && game.commander == commander)
    game.key("escape")
    #expect(game.screen == screen)
  }
  game.launch()
  game.key("6")
  #expect(game.screen == .system)
  #expect(PlayerHelp.pages(for: game).flatMap(\.rows).contains("6 - SYSTEM DATA / PLANET VIEW"))
}

@MainActor @Test func nativePlanetUsesInspectedIdentityWithCachedSmoothShadedPixels() throws {
  var game = Game(executive: false)
  game.screen = .chart
  let commander = game.commander
  let market = game.market
  var images: [Data] = []
  for galaxy in 0..<8 {
    game.viewGalaxy(galaxy)
    game.selectChartSystem(7)
    let frame = Display.presentation(game, width: 1512, height: 982)
    let preview = try #require(
      frame.graphics.compactMap { graphic -> PlanetPreview? in
        if case .planet(let value) = graphic { return value }
        return nil
      }.first)
    #expect(
      preview.identity == PlanetIdentity(galaxy: galaxy, system: Universe.galaxy(number: galaxy)[7])
    )
    let image = try #require(PlanetRenderer.image(for: preview, diameter: 128))
    #expect(PlanetRenderer.image(for: preview, diameter: 128) === image)
    images.append(try #require(image.dataProvider?.data) as Data)
  }
  #expect(Set(images).count == 8)
  #expect(game.commander == commander && game.market == market)
  let bounds = CanvasRect(x: 0, y: 0, width: 256, height: 256)
  let preview = PlanetPreview(galaxy: 0, system: game.systems[7], bounds: bounds, time: 0)
  let image = try #require(PlanetRenderer.image(for: preview, diameter: 256))
  let pixels = try #require(image.dataProvider?.data) as Data
  #expect(pixels[0] == 0 && pixels[1] == 0 && pixels[2] == 0)
  let colours = Set(stride(from: 0, to: pixels.count, by: 4).map { Array(pixels[$0..<$0 + 3]) })
  #expect(colours.count > 4000)
  let rotated = try #require(
    PlanetRenderer.image(
      for: .init(galaxy: 0, system: game.systems[7], bounds: bounds, time: 30), diameter: 256))
  #expect(pixels != (try #require(rotated.dataProvider?.data) as Data))
  #expect(PlanetRenderer.image(for: preview, diameter: 0) == nil)
  game.screen = .system
  for (width, height, scale) in [(768, 768, 1), (1512, 982, 2)] {
    let result = try #require(imageForGame(game, width: width, height: height, scale: scale))
    #expect(result.width == width * scale && result.height == height * scale)
    if let directory = ProcessInfo.processInfo.environment["ELITE_RENDER_PROOF"] {
      let url = URL(fileURLWithPath: directory).appendingPathComponent(
        "planet-\(width)-\(scale).png")
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      let destination = try #require(
        CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
      CGImageDestinationAddImage(destination, result, nil)
      #expect(CGImageDestinationFinalize(destination))
    }
  }
}

@Test func cobraGeometryMatchesTheFittedAndCataloguePreviewWithoutChangingCommander() throws {
  let source = try #require(ShipCatalogue.ship("SH023")?.previewMesh)
  let flight = Mesh.hull(.cobra)
  #expect(flight.faces == source.faces && flight.vertices.count == source.vertices.count)
  for (a, b) in zip(flight.vertices, source.vertices) { #expect((a - b * 0.69).length < 1e-9) }
  #expect(flight.vertices.count > 100)
}
