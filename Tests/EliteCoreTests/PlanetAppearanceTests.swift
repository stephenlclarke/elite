import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

private func appearanceSystem(economy: Int, government: Int = 3) -> StarSystem {
  let source = Universe.galaxy(number: 0)[7]
  return StarSystem(
    id: source.id, name: source.name, x: source.x, y: source.y,
    economy: economy, government: government, technology: source.technology,
    population: source.population, productivity: source.productivity,
    radius: source.radius, seed: source.seed)
}

@Test func economyAppearanceChangesWeatherAndVegetationWithoutChangingTerrainOrGovernment() {
  let industrial = appearanceSystem(economy: 0)
  let agricultural = appearanceSystem(economy: 5)
  let identity = PlanetIdentity(galaxy: 0, system: industrial)
  #expect(identity == PlanetIdentity(galaxy: 0, system: agricultural))
  let terrain = PlanetTerrain(identity: identity)
  let profiles = (0..<8).map { PlanetPalette(identity: identity, economy: $0) }
  for (economy, palette) in profiles.enumerated() {
    #expect(palette.economy == economy)
    #expect(palette == PlanetPalette(identity: identity, economy: economy))
    #expect(palette.profile.cloudLow < palette.profile.cloudHigh)
    #expect((0...1).contains(palette.seaLevel))
    #expect((0...1).contains(palette.profile.cloudOpacity))
    for other in profiles.dropFirst(economy + 1) { #expect(palette != other) }
  }
  let industry = profiles[0].profile
  let agriculture = profiles[5].profile
  #expect(industry.surfaceHaze > agriculture.surfaceHaze)
  #expect(industry.cloudOpacity > agriculture.cloudOpacity)
  #expect(industry.vegetationStrength < agriculture.vegetationStrength)
  #expect(industry.land.y < agriculture.land.y)
  let industryClouds = terrain.clouds.filter { Double($0) > industry.cloudLow }.count
  let agricultureClouds = terrain.clouds.filter { Double($0) > agriculture.cloudLow }.count
  #expect(industryClouds > agricultureClouds)
  let bounds = CanvasRect(x: 0, y: 0, width: 128, height: 128)
  let preview = PlanetPreview(galaxy: 0, system: agricultural, bounds: bounds, time: 0)
  #expect(preview.appearance == profiles[5])
  let otherGovernment = PlanetPreview(
    galaxy: 0, system: appearanceSystem(economy: 5, government: 7), bounds: bounds, time: 0)
  #expect(otherGovernment.appearance == preview.appearance)
  #expect(PlanetTerrain(identity: otherGovernment.identity) == terrain)
  let otherIdentity = PlanetIdentity(galaxy: 1, system: agricultural)
  #expect(PlanetPalette(identity: otherIdentity, economy: 5) != preview.appearance)
}

@MainActor @Test func economyAppearanceInvalidatesBothImageCachesForTheSameIdentity() throws {
  let bounds = CanvasRect(x: 0, y: 0, width: 128, height: 128)
  let industrial = PlanetPreview(
    galaxy: 0, system: appearanceSystem(economy: 0), bounds: bounds, time: 0)
  let agricultural = PlanetPreview(
    galaxy: 0, system: appearanceSystem(economy: 5), bounds: bounds, time: 0)
  #expect(industrial.identity == agricultural.identity)
  let first = try #require(PlanetRenderer.referenceImage(for: industrial, diameter: 128))
  #expect(PlanetRenderer.referenceImage(for: industrial, diameter: 128) === first)
  let second = try #require(PlanetRenderer.referenceImage(for: agricultural, diameter: 128))
  #expect(first !== second)
  let firstBytes = try #require(first.dataProvider?.data) as Data
  let secondBytes = try #require(second.dataProvider?.data) as Data
  #expect(firstBytes != secondBytes)
  // Transparent space is unchanged; the atmospheric extent varies with the profile.
  #expect(firstBytes[3] == 0 && secondBytes[3] == 0)
  #expect(
    stride(from: 3, to: firstBytes.count, by: 4).contains { firstBytes[$0] != secondBytes[$0] })
  let frame = try #require(PlanetRenderer.image(for: industrial, diameter: 128))
  let changed = try #require(PlanetRenderer.image(for: agricultural, diameter: 128))
  #expect(frame !== changed)
  #expect(PlanetRenderer.image(for: agricultural, diameter: 128) === changed)
  let restored = try #require(PlanetRenderer.referenceImage(for: industrial, diameter: 128))
  #expect(try #require(restored.dataProvider?.data) as Data == firstBytes)
}

@MainActor @Test func economyUniformLayoutUsesEveryNamedSlotAndActualPreviewProfile() {
  let preview = PlanetPreview(
    galaxy: 0, system: appearanceSystem(economy: 2),
    bounds: .init(x: 0, y: 0, width: 128, height: 128), time: 0)
  let values = PlanetGPUShader.uniformValues(
    palette: preview.appearance, angle: 0.222, diameter: 128)
  #expect(values.count == PlanetGPUUniform.allCases.count)
  let allFinite = values.allSatisfy(\.isFinite)
  #expect(allFinite)
  #expect(values[PlanetGPUUniform.diameter.rawValue] == 128)
  #expect(values[PlanetGPUUniform.angle.rawValue] == Float(0.222))
  #expect(values[PlanetGPUUniform.cloudLow.rawValue] == Float(preview.appearance.profile.cloudLow))
  #expect(
    values[PlanetGPUUniform.surfaceHaze.rawValue] == Float(preview.appearance.profile.surfaceHaze))
  #expect(
    values[PlanetGPUUniform.vegetationStrength.rawValue]
      == Float(preview.appearance.profile.vegetationStrength))
  #expect(
    values[PlanetGPUUniform.rimOpacity.rawValue] == Float(preview.appearance.profile.rimOpacity))
  #expect(PlanetGPUUniform.rimOpacity.rawValue == 30)
}
