import Foundation
import Testing

@testable import EliteCore

struct ShipCatalogueMetadataTests {
  @Test func sevenFunctionalRolesHaveOnlyTheirDeclaredCargoFloors() {
    #expect(ShipCatalogueRole.allCases.count == 7)
    #expect(ShipCatalogueRole.trader.minimumStandardCargoTonnes == 25)
    #expect(ShipCatalogueRole.transporter.minimumStandardCargoTonnes == 150)
    for role in ShipCatalogueRole.allCases where role != .trader && role != .transporter {
      #expect(role.minimumStandardCargoTonnes == 0)
    }
    #expect(ShipCatalogueRole.bountyHunter.label == "Bounty hunter")
  }

  @Test func originDoesNotChangeFunctionalRoleOrImplyAllegiance() {
    let human = metadata(origin: .human)
    let alien = metadata(origin: .alien)
    #expect(human.primaryRole == alien.primaryRole)
    #expect(human.encounterWeight(for: .military) == alien.encounterWeight(for: .military))
    #expect(alien.encounterWeight(for: .pirate) == 0)
    #expect(alien.minimumStandardCargoTonnes == 0)
  }

  @Test func pendingMissionMechanicsRemainExplicitlyEligibleWithoutFakeAmbientCoverage() {
    let pending = metadata(
      encounterMode: .authored, mechanicsStatus: .pending, galaxies: [], regions: [])
    #expect(pending.normallyDiscoverable)
    #expect(!pending.readyForNaturalEncounters)
    #expect(pending.encounterWeight(for: .military) == 0)
    #expect(pending.valid(shipID: "SH163", performance: nil, nativeCombat: nil))
    let falsePlacement = metadata(
      encounterMode: .authored, mechanicsStatus: .pending,
      placementStatus: .declared, galaxies: [], regions: [])
    #expect(!falsePlacement.valid(shipID: "SH163", performance: nil, nativeCombat: nil))
    let premature = metadata(mechanicsStatus: .ready)
    #expect(!premature.valid(shipID: "SH163", performance: nil, nativeCombat: nil))
  }

  @Test func galaxyRegionRoleAndLiberatorRestrictionsFailClosed() throws {
    let performance = try #require(ShipCatalogue.ship("SH023")?.game)
    let valid = metadata()
    #expect(valid.valid(shipID: "SH023", performance: performance, nativeCombat: nil))
    #expect(
      !metadata(galaxies: [8]).valid(shipID: "SH023", performance: performance, nativeCombat: nil))
    #expect(
      !metadata(galaxies: [0, 0]).valid(
        shipID: "SH023", performance: performance, nativeCombat: nil))
    #expect(
      !metadata(regions: [.tradeLane, .tradeLane]).valid(
        shipID: "SH023", performance: performance, nativeCombat: nil))
    #expect(
      !metadata(weights: [.init(role: .military, weight: 0)]).valid(
        shipID: "SH023", performance: performance, nativeCombat: nil))
    #expect(
      !metadata(weights: [.init(role: .military, weight: 1), .init(role: .military, weight: 2)])
        .valid(shipID: "SH023", performance: performance, nativeCombat: nil))
    #expect(!valid.valid(shipID: "SH171", performance: performance, nativeCombat: nil))
    let liberator = ShipCatalogueMetadata(
      schemaVersion: 2, family: "Liberator", aliases: nil, objectKind: .ship,
      origin: .human, primaryType: .alien, primaryRole: .military,
      roleWeights: [.init(role: .military, weight: 1)],
      access: .xyzzyOnly, playerFlyable: true, normalPurchaseEligible: false,
      purchasePolicy: .xyzzyOnly, minimumBuildTechLevel: nil, isCapital: false,
      collectionMilestone: .none, damagePolicy: .destructible, habitat: nil,
      discoveryEligible: false,
      encounterMode: .none, mechanicsStatus: .ready, placementStatus: .declared, rarity: .rare,
      galaxies: [], regions: [], authoredSystems: nil,
      basis: "Project fixture")
    #expect(liberator.valid(shipID: "SH171", performance: performance, nativeCombat: nil))
    #expect(!liberator.normallyDiscoverable && !liberator.readyForNaturalEncounters)
    #expect(liberator.encounterWeight(for: .military) == 0)
  }

  @Test func actualTOMLLoaderRequiresAndValidatesCatalogueMetadata() throws {
    let source = ShipCatalogue.folder.appendingPathComponent("SH023.toml")
    let original = try String(contentsOf: source, encoding: .utf8)
    let start = try #require(original.range(of: "[catalogue]"))
    let end = try #require(
      original.range(of: "[game]", range: start.upperBound..<original.endIndex))
    let catalogue = String(original[start.lowerBound..<end.lowerBound])
    let missing = String(original[..<start.lowerBound]) + String(original[end.lowerBound...])
    let invalid =
      String(original[..<start.lowerBound])
      + catalogue.replacingOccurrences(of: "schemaVersion = 2", with: "schemaVersion = 3")
      + String(original[end.lowerBound...])
    #expect(invalid != original)
    let tech = try #require(ShipCatalogue.ship("SH023")?.catalogue.minimumBuildTechLevel)
    let invalidTech =
      String(original[..<start.lowerBound])
      + catalogue.replacingOccurrences(
        of: "minimumBuildTechLevel = " + String(tech), with: "minimumBuildTechLevel = 0")
      + String(original[end.lowerBound...])
    #expect(invalidTech != original)
    let gameStart = try #require(original.range(of: "[game]"))
    let gameEnd = try #require(
      original.range(of: "[design]", range: gameStart.upperBound..<original.endIndex))
    let performance = try #require(ShipCatalogue.ship("SH023")?.game)
    let gameText = String(original[gameStart.lowerBound..<gameEnd.lowerBound])
    let drift =
      String(original[..<gameStart.lowerBound])
      + gameText.replacingOccurrences(
        of: "cargoExpansion = " + String(performance.cargoExpansion),
        with: "cargoExpansion = " + String(performance.cargoExpansion + 1))
      + String(original[gameEnd.lowerBound...])
    #expect(drift != original)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "ship-role-loader-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("SH023.toml")
    try original.write(to: file, atomically: true, encoding: .utf8)
    let loaded = try ShipCatalogue.load(from: directory)
    #expect(loaded.count == 1 && loaded[0].catalogue.schemaVersion == 2)
    for text in [missing, invalid, invalidTech, drift] {
      try text.write(to: file, atomically: true, encoding: .utf8)
      #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    }
  }

  @Test func reviewedCatalogueRolesCargoFamiliesAndDeclaredCoverageAreConsistent() throws {
    let ships = ShipCatalogue.all
    #expect(ships.count == 171)
    let vessels = ships.filter { $0.catalogue.objectKind == .ship }
    #expect(vessels.count == 162)
    let counts = Dictionary(
      grouping: vessels, by: { $0.catalogue.primaryRole?.rawValue ?? "missing" }
    ).mapValues(\.count)
    #expect(counts["transporter"] == 27 && counts["trader"] == 26 && counts["pirate"] == 14)
    #expect(
      counts["military"] == 65 && counts["bountyHunter"] == 10 && counts["miner"] == 8
        && counts["leisure"] == 12)
    for ship in ships {
      #expect(
        ship.catalogue.valid(
          shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat))
      #expect(ship.catalogue.validEffectiveCargo(performance: ship.game, profiles: ship.profiles))
      if let game = ship.game { #expect(game.cargo >= ship.catalogue.minimumStandardCargoTonnes) }
      if ship.catalogue.encounterMode == .authored {
        #expect(ship.catalogue.placementStatus == .pending)
      }
    }
    let natural = ships.filter { $0.catalogue.readyForNaturalEncounters }
    #expect(Set(natural.flatMap { $0.catalogue.galaxies }) == Set(0..<8))
    #expect(natural.contains { $0.catalogue.rarity == .rare })
    #expect(natural.allSatisfy { !$0.catalogue.galaxies.isEmpty && !$0.catalogue.regions.isEmpty })
    // These are declared placements only. Native admitted-provider coverage is integrator-owned.
    for (id, cargo) in [
      ("SH005", 750), ("SH006", 800), ("SH099", 150), ("SH100", 175),
      ("SH096", 750), ("SH097", 800), ("SH024", 40), ("SH025", 35),
    ] {
      #expect(ShipCatalogue.ship(id)?.game?.cargo == cargo)
    }
    let ray = try #require(ShipCatalogue.ship("SH169"))
    let rayProfile = try #require(ray.profiles.first { $0.group == "project-refit-v1" })
    #expect(ray.game?.cargo == 30)
    #expect(rayProfile.fields.first { $0.key == "initial_charter_passenger_berths" }?.number == 1)
    #expect(rayProfile.fields.first { $0.key == "hold_used_by_cabins" }?.number == 5)
    #expect(rayProfile.fields.first { $0.key == "usable_cargo_after_fit" }?.number == 25)
    let widow = try #require(ShipCatalogue.ship("SH163"))
    #expect(widow.game == nil && widow.catalogue.objectKind == .ship)
    #expect(widow.catalogue.normallyDiscoverable && widow.catalogue.placementStatus == .pending)
    #expect(widow.catalogue.mechanicsStatus == .pending && !widow.catalogue.normalPurchaseEligible)
    let capsule = try #require(ShipCatalogue.ship("SH040"))
    #expect(capsule.game != nil && capsule.catalogue.objectKind == .capsule)
    #expect(!capsule.catalogue.discoveryEligible && !capsule.catalogue.normalPurchaseEligible)
    let carrier = try #require(ShipCatalogue.ship("SH161"))
    #expect(carrier.catalogue.objectKind == .station && carrier.catalogue.primaryRole == .military)
    #expect(
      carrier.catalogue.encounterMode == .authored && carrier.catalogue.placementStatus == .pending)
    for id in ["SH150", "SH151"] {
      let seasonal = try #require(ShipCatalogue.ship(id))
      #expect(seasonal.catalogue.galaxies == [7] && seasonal.catalogue.placementStatus == .pending)
      #expect(
        seasonal.catalogue.encounterMode == .authored
          && !seasonal.catalogue.readyForNaturalEncounters)
    }
    #expect(ShipCatalogue.ship("SH150")?.catalogue.primaryRole == .transporter)
    #expect(ShipCatalogue.ship("SH150")?.game?.cargo == 150)
    #expect(ShipCatalogue.ship("SH151")?.name == "Rudolf")
    #expect(ShipCatalogue.ship("SH151")?.catalogue.aliases == ["Armed reindeer escort"])
  }

  @Test func hullPreferencesHavePositiveWeightedAlternatives() throws {
    let wolf = try #require(ShipCatalogue.ship("SH142"))
    for id in ["SH048", "SH082"] {
      let preferred = try #require(ShipCatalogue.ship(id))
      #expect(
        preferred.catalogue.encounterWeight(for: .bountyHunter)
          > wolf.catalogue.encounterWeight(for: .bountyHunter))
    }
    let sidewinder = try #require(ShipCatalogue.ship("SH107"))
    #expect(sidewinder.catalogue.encounterWeight(for: .pirate) > 0)
    for id in ["SH037", "SH038", "SH039", "SH051", "SH065", "SH071", "SH072", "SH073"] {
      let preferred = try #require(ShipCatalogue.ship(id))
      #expect(
        preferred.catalogue.encounterWeight(for: .pirate)
          > sidewinder.catalogue.encounterWeight(for: .pirate))
    }
  }

  private func metadata(
    origin: ShipCatalogueOrigin = .human,
    encounterMode: ShipCatalogueEncounterMode = .natural,
    mechanicsStatus: ShipCatalogueMechanicsStatus = .ready,
    placementStatus: ShipCataloguePlacementStatus? = nil, galaxies: [Int] = [0],
    regions: [EncounterRegion] = [.deepSpace],
    weights: [ShipCatalogueRoleWeight] = [.init(role: .military, weight: 2)]
  )
    -> ShipCatalogueMetadata
  {
    .init(
      schemaVersion: 2, family: "Fixture", aliases: nil, objectKind: .ship, origin: origin,
      primaryType: origin == .alien ? .alien : .military,
      primaryRole: .military, roleWeights: weights, access: .normal,
      playerFlyable: mechanicsStatus == .ready, normalPurchaseEligible: mechanicsStatus == .ready,
      purchasePolicy: mechanicsStatus == .ready ? .blueprintFabrication : .pendingFabrication,
      minimumBuildTechLevel: 10, isCapital: false, collectionMilestone: .blueprintAndFabrication,
      damagePolicy: .destructible, habitat: nil, discoveryEligible: true,
      encounterMode: encounterMode,
      mechanicsStatus: mechanicsStatus,
      placementStatus: placementStatus ?? (encounterMode == .authored ? .pending : .declared),
      rarity: .rare,
      galaxies: galaxies, regions: regions, authoredSystems: nil,
      basis: "Project fixture")
  }
}
