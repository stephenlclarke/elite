import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalBurroActivationUnitTests {
  private func retained(_ id: String = "SH029") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func originalMechanicsReplaceOnlyTheBurroRuntimeAndKeepHistoricalFields() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH029"))
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == "Corsair" && ship.name == "Burro")
    #expect(ship.game == definition.nativePerformance)
    #expect(ship.game?.cargo == 52 && ship.game?.speed == 39.6)
    #expect(ship.game?.fuel == 130 && ship.game?.jump == 9 && ship.game?.price == 220000)
    #expect(ship.game?.missiles == 5 && ship.game?.cargoExpansion == 20)
    for profile in old.profiles {
      let historical = try #require(ship.profiles.first { $0.id == profile.id })
      #expect(historical.fields == profile.fields)
      #expect(
        historical.group
          == (profile.group == "project-refit-v1"
            ? "historical-project-refit-v1" : profile.group))
    }
    #expect(definition.authored["name"] == .string("Burro"))
    #expect(definition.sourceSHA256 == OriginalBurroActivation.specificationSHA256)
    for other in ShipCatalogue.all
    where ![
      "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
      "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
      "SH046",
      "SH047", "SH054", "SH055", "SH061",
    ]
    .contains(
      other.id)
    {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func playerAndPhysicalMeshesKeepEveryApprovedMetreVertexMaterialAndTexture() throws {
    let contract = try OriginalHullPhysicalContract.burro.get()
    let ship = try #require(ShipCatalogue.ship("SH029"))
    let physical = contract.physicalMesh
    var commander = Commander()
    commander.shipID = "SH029"
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh("SH029"))] {
      #expect(mesh.vertices == physical.vertices && mesh.faces == physical.faces)
      #expect(mesh.details == physical.details && mesh.materials == physical.materials)
      #expect(
        mesh.faceMaterials == physical.faceMaterials && mesh.faceTextures == physical.faceTextures)
      #expect(mesh.vertices.count == 76 && mesh.faces.count == 120)
      #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    }
    #expect(
      ship.nativeDesign == contract.model.nativeDesign && ship.design == contract.model.nativeDesign
    )
    #expect(zip(ship.dimensions ?? [], [20.0, 10.04, 34.09]).allSatisfy { abs($0 - $1) < 1e-9 })
    #expect(ship.dimensions?.count == 3)
    #expect(ship.previewMesh?.vertices != physical.vertices)
    #expect(physical.materials.count == 8 && !physical.faceTextures.isEmpty)
  }

  @Test func standardFitUsesOriginalLimitsWithoutAddingEquipmentOrWorkTools() throws {
    let ship = try #require(ShipCatalogue.ship("SH029"))
    let performance = try #require(ship.game)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(performance.workTools == nil)
    let profiles = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(profiles.count == 1)
    let fit = try #require(profiles.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 52 && number("usable_cargo_after_fit") == 52)
    #expect(number("hold_used_by_cabins") == 0 && number("fitted_passenger_berths") == 0)
    #expect(number("missile_capacity") == 5 && number("new_refit_initial_missiles") == 1)
    #expect(number("laser_facing_mask") == 15 && number("cargo_expansion_tonnes") == 20)
    #expect(number("required_crew_including_commander") == 1)
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = ship.id
    #expect(commander.standardCargoCapacity == 52 && commander.missileCapacity == 5)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 72)
  }

  @Test func originalTraderPolicyKeepsBlueprintFabricationAndExistingPlacementRequirements() throws
  {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH029"))
    let metadata = ship.catalogue
    #expect(metadata.family == "burro" && metadata.primaryRole == .trader)
    #expect(metadata.roleWeights == [.init(role: .trader, weight: 1)])
    #expect(metadata.access == .normal && metadata.playerFlyable && metadata.discoveryEligible)
    #expect(metadata.purchasePolicy == .blueprintFabrication)
    #expect(metadata.collectionMilestone == .blueprintAndFabrication)
    #expect(metadata.minimumBuildTechLevel == 7 && !metadata.isCapital)
    #expect(
      metadata.galaxies == old.catalogue.galaxies && metadata.regions == old.catalogue.regions)
    #expect(metadata.rarity == old.catalogue.rarity && metadata.habitat == old.catalogue.habitat)
    #expect(
      metadata.valid(shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat))
    #expect(
      NativeFleetDiscovery(owner: UUID()).readout(for: ship.id)
        == ["Collection: unknown; no native encounter recorded"])
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id) == [
        "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
        "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
        "SH046",
        "SH047", "SH054", "SH055", "SH061",
      ])
  }

  @Test func invalidRetainedInputsCannotBeRepairedSilentlyByTheActivationAdapter() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH029.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH029.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == "Burro")
    let invalid = source.replacingOccurrences(of: "name = \"Corsair\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let other = try retained("SH030")
    #expect(try OriginalBurroActivation.resolve(other) == other)
    #expect(!OriginalBurroActivation.supports(try #require(other.originalDefinition)))
  }
}
