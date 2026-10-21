import CryptoKit
import Foundation
import Testing

@testable import EliteCore

private func originalWorldResourceBytes() throws -> (
  catalogue: Data, authoring: Data, provenance: Data
) {
  let directory = try OriginalWorldCatalogue.resourceDirectory()
  return (
    try Data(contentsOf: directory.appendingPathComponent("catalogue.json")),
    try Data(contentsOf: directory.appendingPathComponent("authoring.toml")),
    try Data(contentsOf: directory.appendingPathComponent("PROVENANCE.json"))
  )
}

struct OriginalWorldCatalogueTests {
  @Test func actualBundledCataloguePreservesAllOrdinaryIdentitiesGalaxyNamesAndStatistics() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    #expect(catalogue.version == "l337-world-1")
    #expect(catalogue.worlds.count == 2048 && Set(catalogue.worlds.map(\.name)).count == 2048)
    let expectedNames = [
      "Lantern Reach", "Copper Shoals", "Verdant Fold", "Quiet Current",
      "Amber Divide", "Velvet Expanse", "Cinder Weave", "Frostward Sea",
    ]
    for galaxy in 0..<8 {
      #expect(try catalogue.galaxyName(galaxy) == expectedNames[galaxy])
      let worlds = catalogue.worlds.filter { $0.galaxy == galaxy }
      #expect(worlds.count == 256 && Set(worlds.map(\.system)) == Set(0..<256))
      for world in worlds {
        #expect(try catalogue.world(galaxy: galaxy, system: world.system) == world)
        #expect(try catalogue.world(key: world.key) == world)
      }
    }
    #expect(catalogue.worlds.filter(\.ringed).count == 823)
    #expect(catalogue.worlds.filter(\.christmasConvoy).map(\.key) == ["G08-S008"])
    #expect(catalogue.worlds.filter { $0.surface == .snowAndEvergreen }.map(\.name) == ["Crimbo"])
    #expect(
      catalogue.provenance.statistics.surfaceCounts == [
        "polluted-industrial": 776,
        "green-agricultural": 722, "mixed": 549, "snow-and-evergreen": 1,
      ])
    #expect(
      catalogue.provenance.statistics.climateCounts == [
        "temperate": 2047,
        "permanent-winter": 1,
      ])
    #expect(catalogue.provenance.importedOn == "2026-10-18")
    #expect(catalogue.provenance.statistics.coordinateBoundsByGalaxy[1].minimumXLY == -1.4223)
    #expect(catalogue.worlds.contains { $0.xLY < 0 } && catalogue.worlds.contains { $0.yLY < 0 })
  }

  @Test func actualAvenorRetainsEveryAuthoredFieldAndEuclideanLightYearDistances() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    let avenor = try catalogue.world(key: "G01-S007")
    let expected = OriginalWorldRecord(
      key: "G01-S007", galaxy: 0, system: 7, name: "Avenor",
      xLY: 52.4955, yLY: 51.0662, government: "Corporate State", governmentID: 7,
      hostileFraction: 0, technology: 12, economyID: 0, economy: "Rich Industrial",
      industry: 0.663, agriculture: 0.337, extraction: 0.81, consumer: 0.75, special: 0.14,
      wealth: 0.781, populationBillions: 2.684, productivityBillionCR: 158.62, radiusKM: 9950,
      axialTiltDegrees: 41.4, ringed: true, nightLight: 0.2174, pollution: 0.319,
      surface: .pollutedIndustrial, climate: .temperate, christmasConvoy: false,
      worldVersion: "l337-world-1")
    #expect(avenor == expected)
    let nearby = try catalogue.distanceLY(from: avenor.key, to: "G01-S185")
    #expect(abs(nearby - 3.364975176728651) < 1e-12)
    let farther = try catalogue.distanceLY(from: avenor.key, to: "G01-S000")
    #expect(abs(farther - 8.78262916557451) < 1e-12)
    #expect(try catalogue.distanceLY(from: "G01-S000", to: avenor.key) == farther)
    #expect(try catalogue.distanceLY(from: avenor.key, to: avenor.key) == 0)
    #expect(throws: OriginalWorldCatalogueError.crossGalaxy(source: 0, destination: 1)) {
      try catalogue.distanceLY(from: avenor.key, to: "G02-S007")
    }
  }

  @Test func authoringRemainsCompleteReadOnlyDataWithoutAliasesOrSecretWorldCoordinates() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    let config = catalogue.authoring
    #expect(config.seed == "lanterns-between-the-tides-2026" && config.coordinateUnit == "LY")
    #expect(config.startingCreditsCR == 720 && config.startingShipID == "SH025")
    #expect(config.systemsPerGalaxy == 256 && config.minimumLinkRangeLY == 6)
    #expect(config.technologyMinimum == 1 && config.technologyMaximum == 20)
    #expect(config.moneyUnit == "0.1 CR" && config.startingFuelFraction == 1)
    #expect(config.tickHours == 24 && config.stockRecovery == 0.32 && config.minimumSpread == 0.08)
    #expect(config.minimumPriceFactor == 0.34 && config.maximumPriceFactor == 2.8)
    #expect(config.galaxies[0].spacing == [4.2, 3.65] && config.galaxies[0].warp == [1.4, 1])
    #expect(config.galaxies[7].phase == 5.7 && config.galaxies[7].wealthBias == 0.03)
    #expect(config.governments[7].civicInfrastructure == 0.94)
    #expect(config.commodities.count == 17 && config.equipment.count == 14)
    #expect(config.commodities.first { $0.index == 7 }?.basePriceCR == 265)
    #expect(config.equipment.first { $0.id == "military-laser" }?.damagePerSecond == 91)
    #expect(config.equipment.first { $0.id == "naval-energy-unit" }?.rechargeMultiplier == 2.35)
    for (galaxy, system) in [(-1, 0), (8, 0), (0, -1), (0, 256)] {
      #expect(throws: OriginalWorldCatalogueError.invalidIdentity(galaxy: galaxy, system: system)) {
        try catalogue.world(galaxy: galaxy, system: system)
      }
    }
    for key in ["PLUGH", "G01-S256", "Avenor", "g01-s007", "Lave"] {
      #expect(throws: OriginalWorldCatalogueError.unknownKey(key)) { try catalogue.world(key: key) }
    }
    #expect(throws: OriginalWorldCatalogueError.invalidIdentity(galaxy: 8, system: 0)) {
      try catalogue.galaxyName(8)
    }
  }

  @Test func bundledSourceFingerprintsMatchTheDatedByteForByteProvenance() throws {
    let directory = try OriginalWorldCatalogue.resourceDirectory()
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    for (name, expected) in OriginalWorldCatalogue.approvedFingerprints {
      let data = try Data(contentsOf: directory.appendingPathComponent(name))
      let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
      #expect(actual == expected)
      if name != "PROVENANCE.json" {
        #expect(catalogue.provenance.files[name]?.sha256 == expected)
        #expect(catalogue.provenance.files[name]?.bytes == data.count)
      }
    }
  }

  @Test(arguments: [
    "duplicate-id", "duplicate-name", "missing-world", "wrong-version",
    "world-version", "identity-key", "galaxy", "system", "coordinate", "technology",
    "government", "economy", "fraction", "physical", "appearance", "missing-field",
    "unknown-field", "unknown-root", "non-finite-coordinate",
  ])
  func malformedCataloguesRefuseWithoutPartialPublication(change: String) throws {
    let bytes = try originalWorldResourceBytes()
    var root = try #require(JSONSerialization.jsonObject(with: bytes.catalogue) as? [String: Any])
    var worlds = try #require(root["systems"] as? [[String: Any]])
    switch change {
    case "duplicate-id": worlds[1] = worlds[0]
    case "duplicate-name": worlds[1]["name"] = worlds[0]["name"]
    case "missing-world": worlds.removeLast()
    case "wrong-version": root["version"] = "superseded"
    case "world-version": worlds[0]["worldVersion"] = "superseded"
    case "identity-key": worlds[0]["key"] = "G01-S001"
    case "galaxy": worlds[0]["galaxy"] = 8
    case "system": worlds[0]["system"] = 256
    case "coordinate": worlds[0]["xLY"] = 1000
    case "technology": worlds[0]["technology"] = 21
    case "government": worlds[0]["government"] = "Corporate State"
    case "economy": worlds[0]["economyID"] = 8
    case "fraction": worlds[0]["pollution"] = -0.1
    case "physical": worlds[0]["radiusKM"] = 0
    case "appearance": worlds[0]["surface"] = "unapproved"
    case "missing-field": worlds[0].removeValue(forKey: "consumer")
    case "unknown-field": worlds[0]["legacyX"] = 128
    case "unknown-root": root["oldUniverse"] = true
    default: worlds[0]["xLY"] = "NaN"
    }
    root["systems"] = worlds
    let malformed = try JSONSerialization.data(withJSONObject: root)
    #expect(throws: (any Error).self) {
      try OriginalWorldCatalogue.decode(
        catalogue: malformed, authoring: bytes.authoring,
        provenance: bytes.provenance)
    }
  }

  @Test(arguments: ["nan", "technology", "galaxy-name", "commodity", "equipment"])
  func malformedAuthoringRefusesBeforeAnyRecordCanBeUsed(change: String) throws {
    let bytes = try originalWorldResourceBytes()
    var text = try #require(String(data: bytes.authoring, encoding: .utf8))
    switch change {
    case "nan":
      text = text.replacingOccurrences(
        of: "\"minimumLinkRangeLY\" = 6.0",
        with: "\"minimumLinkRangeLY\" = nan")
    case "technology":
      text = text.replacingOccurrences(
        of: "\"technologyMaximum\" = 20",
        with: "\"technologyMaximum\" = 0")
    case "galaxy-name": text = text.replacingOccurrences(of: "Copper Shoals", with: "Lantern Reach")
    case "commodity":
      text = text.replacingOccurrences(
        of: "\"basePriceCR\" = 64.0",
        with: "\"basePriceCR\" = -1.0")
    default:
      text = text.replacingOccurrences(
        of: "\"priceCR\" = 180.0",
        with: "\"priceCR\" = -1.0")
    }
    #expect(throws: (any Error).self) {
      try OriginalWorldCatalogue.decode(
        catalogue: bytes.catalogue, authoring: Data(text.utf8),
        provenance: bytes.provenance)
    }
  }

  @Test(arguments: ["ringed", "bounds", "schema"])
  func changedProvenanceStatisticsCannotPublishAContradictoryCatalogue(change: String) throws {
    let bytes = try originalWorldResourceBytes()
    var root = try #require(JSONSerialization.jsonObject(with: bytes.provenance) as? [String: Any])
    if change == "schema" {
      root["schemaVersion"] = 2
    } else {
      var statistics = try #require(root["statistics"] as? [String: Any])
      if change == "ringed" {
        statistics["ringed"] = 0
      } else {
        var bounds = try #require(statistics["coordinateBoundsByGalaxy"] as? [[String: Any]])
        bounds[0]["maximumXLY"] = 100
        statistics["coordinateBoundsByGalaxy"] = bounds
      }
      root["statistics"] = statistics
    }
    let malformed = try JSONSerialization.data(withJSONObject: root)
    #expect(throws: OriginalWorldCatalogueError.self) {
      try OriginalWorldCatalogue.decode(
        catalogue: bytes.catalogue, authoring: bytes.authoring,
        provenance: malformed)
    }
  }

  @Test func missingOrModifiedBundledInputsFailTheSameExactByteGate() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try OriginalWorldCatalogue.resourceDirectory()
    for name in OriginalWorldCatalogue.approvedFingerprints.keys {
      try FileManager.default.copyItem(
        at: source.appendingPathComponent(name),
        to: directory.appendingPathComponent(name))
    }
    try Data("{}".utf8).write(to: directory.appendingPathComponent("catalogue.json"))
    #expect(throws: OriginalWorldCatalogueError.fingerprintMismatch("catalogue.json")) {
      try OriginalWorldCatalogue.load(from: directory)
    }
    try FileManager.default.removeItem(at: directory.appendingPathComponent("catalogue.json"))
    #expect(throws: OriginalWorldCatalogueError.missingResource("catalogue.json")) {
      try OriginalWorldCatalogue.load(from: directory)
    }
  }
}
