import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalHaflingerActivationUnitTests {
  private func retained(_ id: String = "SH061") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func haflingerUsesOriginalMechanicsAndKeepsEveryLegacyIguanaProfileField() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH061"))
    let original = try #require(ship.originalDefinition)
    #expect(old.name == "Iguana" && ship.name == "Haflinger")
    #expect(ship.game == original.nativePerformance)
    #expect(ship.game?.cargo == 78 && ship.game?.speed == 34 && ship.game?.acceleration == 9.2)
    #expect(ship.game?.fuel == 130 && ship.game?.jump == 9 && ship.game?.price == 216000)
    #expect(original.sourceSHA256 == OriginalHaflingerActivation.specificationSHA256)
    for profile in old.profiles {
      let historical = try #require(ship.profiles.first { $0.id == profile.id })
      #expect(historical.fields == profile.fields)
      #expect(
        historical.group
          == (profile.group == "project-refit-v1"
            ? "historical-project-refit-v1" : profile.group))
    }
    #expect(ship.profiles.filter { $0.group == "project-refit-v1" }.count == 1)
    for other in ShipCatalogue.all
    where ![
      "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
      "SH031", "SH032", "SH033", "SH035", "SH036", "SH043", "SH061",
    ]
    .contains(
      other.id)
    {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func calibratedPhysicalAndPlayerGeometryNeverChangesTheRawSourceOrItsAppearance() throws {
    let source = try OriginalFleetShowroomModels.model(for: "SH061")
    let contract = try OriginalHullPhysicalContract.haflinger.get()
    let ship = try #require(ShipCatalogue.ship("SH061"))
    var commander = Commander()
    commander.shipID = ship.id
    #expect(source.coordinateUnits == nil && contract.metresPerSourceUnit == 20)
    #expect(ship.design == source.nativeDesign && ship.nativeDesign == source.nativeDesign)
    let raw = source.displayMesh
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices.count == 912 && mesh.faces.count == 1720)
      for (physical, original) in zip(mesh.vertices, raw.vertices) {
        #expect((physical - original * 20).length < 1e-12)
        #expect(physical.length <= contract.envelope.clearanceRadius)
      }
      #expect(mesh.vertices == contract.physicalMesh.vertices)
      #expect(mesh.faces == raw.faces && mesh.details == raw.details)
      #expect(mesh.materials == raw.materials && mesh.materials.count == 10)
      #expect(mesh.faceMaterials == raw.faceMaterials && mesh.faceTextures == raw.faceTextures)
    }
    #expect(ship.geometryContext.contains("20 metres per SH061 source unit"))
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [41.536, 35.7, 80]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.previewMesh?.vertices != contract.physicalMesh.vertices)
    #expect(source.displayMesh.vertices == raw.vertices)
  }

  @Test func originalHoldWeaponAndCrewLimitsDriveTheStandardFitWithoutGrantingFittings() throws {
    let ship = try #require(ShipCatalogue.ship("SH061"))
    let performance = try #require(ship.game)
    let fit = try #require(ship.profiles.first { $0.group == "project-refit-v1" })
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 78 && number("usable_cargo_after_fit") == 78)
    #expect(number("cargo_expansion_tonnes") == 30 && number("hold_used_by_cabins") == 0)
    #expect(number("missile_capacity") == 5 && number("new_refit_initial_missiles") == 1)
    #expect(
      number("fitted_passenger_berths") == 0 && number("required_crew_including_commander") == 1)
    #expect(number("laser_facing_mask") == 15 && performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = ship.id
    #expect(commander.standardCargoCapacity == 78 && commander.missileCapacity == 5)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 108)
  }

  @Test func traderFabricationStaysGatedAndInvalidRetainedInputsCannotBeSilentlyActivated() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH061"))
    let metadata = ship.catalogue
    #expect(metadata.family == "haflinger" && metadata.primaryRole == .trader)
    #expect(metadata.purchasePolicy == .blueprintFabrication && metadata.minimumBuildTechLevel == 5)
    #expect(metadata.collectionMilestone == .blueprintAndFabrication && metadata.access == .normal)
    #expect(
      metadata.galaxies == old.catalogue.galaxies && metadata.regions == old.catalogue.regions)
    #expect(metadata.rarity == old.catalogue.rarity && metadata.habitat == old.catalogue.habitat)
    #expect(
      NativeFleetDiscovery(owner: UUID()).readout(for: ship.id)
        == ["Collection: unknown; no native encounter recorded"])
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id) == [
        "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
        "SH031", "SH032", "SH033", "SH035", "SH036", "SH043", "SH061",
      ])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH061.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH061.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == "Haflinger")
    let invalid = source.replacingOccurrences(of: "name = \"Iguana\"", with: "name = \"\"")
    #expect(source != invalid)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH030")
    #expect(try OriginalHaflingerActivation.resolve(foreign) == foreign)
    #expect(!OriginalHaflingerActivation.supports(try #require(foreign.originalDefinition)))
    #expect(throws: (any Error).self) {
      try OriginalPlayerHullActivation.resolve(
        foreign, definition: #require(ship.originalDefinition),
        physical: OriginalHullPhysicalContract.haflinger.get())
    }
  }
}
