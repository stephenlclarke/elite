import Foundation
import Testing

@testable import L337Core

struct PlanetNightTechnologyUnitTests {
  private func originalSystem(technology: Int) throws -> StarSystem {
    let original = try Universe.originalWorld(galaxy: 0, system: 7)
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    fields["technology"] = technology
    let record = try JSONDecoder().decode(
      OriginalWorldRecord.self, from: JSONSerialization.data(withJSONObject: fields))
    try record.validate(
      authoring: Universe.originalWorlds.authoring,
      bounds: Universe.originalWorlds.provenance.statistics.coordinateBoundsByGalaxy[0])
    // Schema-valid presentation fixture with every other field fixed; never published as a world.
    return Universe.nativeSystem(record)
  }

  @Test func originalWorldNightProfilesRetainEveryAuthoredTechnologyLevel() {
    var highLevels = Set<Int>()
    for world in Universe.originalWorlds.worlds {
      let system = Universe.nativeSystem(world)
      let night = PlanetNightProfile(system: system)
      #expect(night.technology == world.technology)
      #expect(night.economy == world.economyID && night.government == world.governmentID)
      #expect(night.settlementCoverage.isFinite && night.emissionIntensity.isFinite)
      if world.technology > 15 { highLevels.insert(world.technology) }
    }
    #expect(highLevels == [16, 17, 18, 19])
  }

  @Test func matchedOriginalEconomyAndGovernmentKeepIncreasingNightDevelopmentAboveFifteen()
    throws
  {
    let authoring = Universe.originalWorlds.authoring
    #expect(authoring.technologyMinimum == 1 && authoring.technologyMaximum == 20)
    let levels = [authoring.technologyMinimum, 15, 16, 17, 18, 19, authoring.technologyMaximum]
    let systems = try levels.map(originalSystem)
    let profiles = systems.map { PlanetNightProfile(system: $0) }
    let first = try #require(systems.first)
    let identity = PlanetIdentity(galaxy: 0, system: first)
    let palette = PlanetPalette(identity: identity, economy: first.economy)
    for (level, system) in zip(levels, systems) {
      #expect(PlanetNightProfile(system: system).technology == level)
      #expect(PlanetIdentity(galaxy: 0, system: system) == identity)
      #expect(PlanetPalette(identity: identity, economy: system.economy) == palette)
      #expect(system.government == first.government)
    }
    for (lower, higher) in zip(profiles, profiles.dropFirst()) {
      #expect(higher.settlementCoverage > lower.settlementCoverage)
      #expect(higher.emissionIntensity > lower.emissionIntensity)
      #expect(higher.smogScatter == lower.smogScatter && higher.colour == lower.colour)
    }
    let minimum = try #require(profiles.first)
    let maximum = try #require(profiles.last)
    #expect(abs(minimum.settlementCoverage - 0.64 * 0.55) < 1e-12)
    #expect(abs(minimum.emissionIntensity - 0.85 * 0.40) < 1e-12)
    #expect(abs(maximum.settlementCoverage - 0.64) < 1e-12)
    #expect(abs(maximum.emissionIntensity - 0.85 * 1.30) < 1e-12)
  }

  @Test func explicitLegacyNightProfilesKeepTheirExistingCoefficientsAndBounds() throws {
    let low = PlanetNightProfile(economy: 0, technology: 0, government: 7)
    let high = PlanetNightProfile(economy: 0, technology: 15, government: 7)
    #expect(low.technology == 0 && high.technology == 15)
    #expect(abs(low.settlementCoverage - 0.64 * 0.55) < 1e-12)
    #expect(abs(high.settlementCoverage - 0.64) < 1e-12)
    #expect(abs(high.emissionIntensity - 0.85 * 1.30) < 1e-12)
    #expect(PlanetNightProfile(economy: 0, technology: 20, government: 7) == high)
    #expect(PlanetNightProfile(economy: 0, technology: -1, government: 7) == low)
    let source = try originalSystem(technology: 20)
    let legacy = StarSystem(
      id: source.id, name: source.name, x: source.x, y: source.y, economy: source.economy,
      government: source.government, technology: source.technology, population: source.population,
      productivity: source.productivity, radius: source.radius, seed: source.seed)
    #expect(legacy.original == nil && PlanetNightProfile(system: legacy) == high)
    #expect(PlanetNightProfile.uninhabited.settlementCoverage == 0)
    #expect(PlanetNightProfile.uninhabited.emissionIntensity == 0)
  }
}
