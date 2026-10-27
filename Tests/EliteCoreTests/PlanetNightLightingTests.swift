import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

func nightPlanetSystem(economy: Int, government: Int, technology: Int) -> StarSystem {
  let original = Universe.galaxy(number: 0)[7]
  return .init(
    id: original.id, name: original.name, x: original.x, y: original.y,
    economy: economy, government: government, technology: technology,
    population: original.population,
    productivity: original.productivity, radius: original.radius, seed: original.seed)
}

@Test func nightDevelopmentIsSeparateFromGovernmentIndependentDayAppearance() {
  let identity = PlanetIdentity(galaxy: 0, system: Universe.galaxy(number: 0)[7])
  for economy in 0..<8 {
    let low = PlanetNightProfile(economy: economy, technology: 0, government: 7)
    let high = PlanetNightProfile(economy: economy, technology: 15, government: 7)
    #expect(high.settlementCoverage > low.settlementCoverage)
    #expect(high.emissionIntensity > low.emissionIntensity)
    let profiles = (0..<8).map {
      PlanetNightProfile(economy: economy, technology: 15, government: $0)
    }
    for (before, after) in zip(profiles, profiles.dropFirst()) {
      #expect(before.emissionIntensity < after.emissionIntensity)
      #expect(before.settlementCoverage == after.settlementCoverage)
    }
    #expect(profiles[0].emissionIntensity < profiles[7].emissionIntensity * 0.1)
    for government in 0..<8 {
      let system = nightPlanetSystem(economy: economy, government: government, technology: 15)
      let preview = PlanetPreview(
        galaxy: 0, system: system, bounds: .init(x: 0, y: 0, width: 128, height: 128), time: 0)
      #expect(preview.appearance == PlanetPalette(identity: identity, economy: economy))
      #expect(preview.night == profiles[government] && preview.lighting == .presentation)
    }
  }
  let industry = PlanetNightProfile(economy: 0, technology: 15, government: 7)
  let agriculture = PlanetNightProfile(economy: 5, technology: 15, government: 7)
  #expect(industry.settlementCoverage > agriculture.settlementCoverage * 8)
  #expect(industry.smogScatter > agriculture.smogScatter)
}

@Test func seededSettlementMasksStayOnHabitableLandAndRotateWithTheirTerrainCoordinates() {
  let identity = PlanetIdentity(galaxy: 0, system: Universe.galaxy(number: 0)[7])
  let terrain = PlanetTerrain(identity: identity)
  let industrial = PlanetPalette(identity: identity, economy: 0)
  let night = PlanetNightProfile(economy: 0, technology: 15, government: 7)
  let key = PlanetSettlementKey(identity: identity, palette: industrial, night: night)
  let mask = PlanetSettlementMask(key: key, terrain: terrain)
  #expect(mask == PlanetSettlementMask(key: key, terrain: PlanetTerrain(identity: identity)))
  let anarchy = PlanetNightProfile(economy: 0, technology: 15, government: 0)
  #expect(key == PlanetSettlementKey(identity: identity, palette: industrial, night: anarchy))
  #expect(mask.emission.allSatisfy { (0...1).contains($0) })
  #expect(mask.scatter.allSatisfy { (0...1).contains($0) })
  for index in mask.emission.indices where mask.emission[index] > 0 {
    let latitude =
      .pi / 2 - Double(index / PlanetTerrain.width) / Double(PlanetTerrain.height - 1) * .pi
    #expect(Double(terrain.elevation[index]) > industrial.seaLevel + 0.008)
    #expect(terrain.elevation[index] < 0.82 && abs(sin(latitude)) < industrial.ice - 0.03)
  }
  let farm = PlanetNightProfile(economy: 5, technology: 15, government: 7)
  let sparse = PlanetSettlementMask(
    key: .init(identity: identity, palette: industrial, night: farm), terrain: terrain)
  let denseCount = mask.emission.filter { $0 > 0.01 }.count
  let sparseCount = sparse.emission.filter { $0 > 0.01 }.count
  #expect(denseCount > sparseCount && sparseCount > 0)
  let a = terrain.sample(mask.emission, longitude: -.pi, latitude: 0.2)
  let b = terrain.sample(mask.emission, longitude: .pi, latitude: 0.2)
  #expect(abs(a - b) < 1e-9)
  #expect(
    mask.emission
      != PlanetSettlementMask(
        key: .init(
          identity: identity, palette: industrial,
          night: .init(economy: 0, technology: 0, government: 7)), terrain: terrain
      ).emission)
}

@Test func flightSunDirectionUsesTowardsObserverNormalsInEveryCockpitView() {
  let views: [Screen] = [.front, .rear, .left, .right]
  for view in views {
    func ship(_ vector: Vector3) -> Vector3 {
      switch view {
      case .rear: .init(-vector.x, vector.y, -vector.z)
      case .left: .init(-vector.z, vector.y, vector.x)
      case .right: .init(vector.z, vector.y, -vector.x)
      default: vector
      }
    }
    var game = Game(executive: false)
    game.screen = view
    let planet = game.viewPosition(ship(.init(0, 0, 1000)))
    let farSun = game.viewPosition(ship(.init(0, 0, 2000)))
    let nearSun = game.viewPosition(ship(.init(0, 0, 0)))
    #expect(
      PlanetLighting.flight(viewPlanet: planet, viewSun: farSun).direction == Vector3(0, 0, -1))
    #expect(
      PlanetLighting.flight(viewPlanet: planet, viewSun: nearSun).direction == Vector3(0, 0, 1))
    let lateral = PlanetLighting.flight(
      viewPlanet: planet, viewSun: game.viewPosition(ship(.init(1000, 0, 1000))))
    #expect(lateral.direction == Vector3(1, 0, 0))
    let offAxis = PlanetLighting.flight(
      viewPlanet: game.viewPosition(ship(.init(200, 50, 1000))),
      viewSun: game.viewPosition(ship(.init(-1000, 500, 0))))
    #expect(abs(offAxis.direction.length - 1) < 1e-9 && offAxis.direction.z > 0)
  }
  #expect(
    PlanetLighting.flight(viewPlanet: .init(0, 0, 1000), viewSun: .init(0, 0, 1000)) == .unlit)
  #expect(PlanetLighting.sun(direction: .init(.nan, 0, 0)) == .unlit)
}

@MainActor @Test func nightBrightnessAndSunMovementInvalidateImagesWithoutChangingLand() throws {
  let bounds = CanvasRect(x: 0, y: 0, width: 128, height: 128)
  let orderedSystem = nightPlanetSystem(economy: 0, government: 7, technology: 15)
  func preview(_ system: StarSystem, light: PlanetLighting, time: Double = 0) -> PlanetPreview {
    .init(galaxy: 0, system: system, bounds: bounds, time: time, lighting: light)
  }
  func bytes(_ value: PlanetPreview) throws -> Data {
    let image = try #require(PlanetRenderer.referenceImage(for: value, diameter: 128))
    return try #require(image.dataProvider?.data) as Data
  }
  func brightness(_ data: Data) -> Int {
    stride(from: 0, to: data.count, by: 4).reduce(0) {
      $0 + Int(data[$1]) + Int(data[$1 + 1]) + Int(data[$1 + 2])
    }
  }
  let dark = PlanetLighting.sun(direction: .init(0, 0, -1))
  let ordered = preview(orderedSystem, light: dark)
  let first = try #require(PlanetRenderer.referenceImage(for: ordered, diameter: 128))
  #expect(PlanetRenderer.referenceImage(for: ordered, diameter: 128) === first)
  let orderedBytes = try bytes(ordered)
  let anarchy = preview(nightPlanetSystem(economy: 0, government: 0, technology: 15), light: dark)
  #expect(ordered.appearance == anarchy.appearance && ordered.identity == anarchy.identity)
  #expect(brightness(orderedBytes) > brightness(try bytes(anarchy)))
  let day = preview(orderedSystem, light: .sun(direction: .init(0, 0, 1)))
  #expect(brightness(try bytes(day)) > brightness(orderedBytes))
  #expect(
    try bytes(preview(orderedSystem, light: .sun(direction: .init(1, 0, 0))))
      != bytes(preview(orderedSystem, light: .sun(direction: .init(-1, 0, 0)))))
  #expect(try bytes(preview(orderedSystem, light: dark, time: 30)) != orderedBytes)
  #expect(try bytes(ordered) == orderedBytes)
  #expect(orderedBytes[3] == 0 && orderedBytes[(128 * 64 + 64) * 4 + 3] == 255)
  let native = try #require(PlanetRenderer.image(for: ordered, diameter: 128))
  #expect(PlanetRenderer.image(for: ordered, diameter: 128) === native)
  let changed = try #require(PlanetRenderer.image(for: day, diameter: 128))
  #expect(changed !== native)
  let uniforms = PlanetGPUShader.uniformValues(
    palette: ordered.appearance, angle: 0, diameter: 128,
    lighting: dark, night: ordered.night)
  #expect(uniforms[PlanetGPUUniform.sunZ.rawValue] == -1)
  #expect(
    uniforms[PlanetGPUUniform.nightIntensity.rawValue] == Float(ordered.night.emissionIntensity))
  #expect(PlanetGPUUniform.rimOpacity.rawValue == 30 && PlanetGPUUniform.sunX.rawValue == 31)
}

@Test func cloudsAttenuateDirectCitiesAndSmogRemainsLocalToSettlements() {
  let night = PlanetNightProfile(economy: 0, technology: 15, government: 7)
  let clear = night.emission(cities: 1, scatter: 0, cloudOpacity: 0, darkness: 1)
  let covered = night.emission(cities: 1, scatter: 0, cloudOpacity: 1, darkness: 1)
  #expect(clear.x > covered.x && covered.x > 0)
  #expect(clear.x > clear.y && clear.y > clear.z)
  #expect(night.emission(cities: 1, scatter: 1, cloudOpacity: 1, darkness: 0) == Vector3(0, 0, 0))
  #expect(night.emission(cities: 0, scatter: 0, cloudOpacity: 1, darkness: 1) == Vector3(0, 0, 0))
  let haze = night.emission(cities: 0, scatter: 1, cloudOpacity: 1, darkness: 1)
  #expect(haze.x > 0 && haze.x < clear.x)
}

/// Requires the central Display call-site hook owned by Coder 1 before integration acceptance.
@Test func actualFlightPlanetPreviewTracksItsCurrentSunInAllFourViews() throws {
  for view in [Screen.front, .rear, .left, .right] {
    func ship(_ vector: Vector3) -> Vector3 {
      switch view {
      case .rear: .init(-vector.x, vector.y, -vector.z)
      case .left: .init(-vector.z, vector.y, vector.x)
      case .right: .init(vector.z, vector.y, -vector.x)
      default: vector
      }
    }
    var game = Game(executive: false)
    game.screen = view
    game.commander.shipDisplayStyle = .shadedPanels
    let planet = ship(.init(0, 0, 1000))
    for sun in [ship(.init(0, 0, 2000)), ship(.init(0, 0, 0)), ship(.init(1000, 0, 1000))] {
      game.celestials = [
        .init(kind: .planet, position: planet, radius: 100),
        .init(kind: .sun, position: sun, radius: 10),
      ]
      var frame = Frame()
      frame.rasterizeGraphics = false
      Display.celestialScene(game, projection: .legacy, into: &frame)
      let preview = try #require(
        frame.graphics.compactMap { graphic -> PlanetPreview? in
          if case .planet(let value) = graphic { return value }
          return nil
        }.first)
      #expect(
        preview.lighting
          == PlanetLighting.flight(
            viewPlanet: game.viewPosition(planet), viewSun: game.viewPosition(sun)))
    }
    game.celestials = [.init(kind: .planet, position: planet, radius: 100)]
    var unlitFrame = Frame()
    Display.celestialScene(game, projection: .legacy, into: &unlitFrame)
    let unlit = try #require(
      unlitFrame.graphics.compactMap { graphic -> PlanetPreview? in
        if case .planet(let value) = graphic { return value }
        return nil
      }.first)
    #expect(unlit.lighting == .unlit)
    for style in [ShipDisplayStyle.whiteWireframe, .colourWireframe] {
      game.commander.shipDisplayStyle = style
      var frame = Frame()
      Display.celestialScene(game, projection: .legacy, into: &frame)
      #expect(!frame.graphics.contains { if case .planet = $0 { true } else { false } })
    }
  }
}
