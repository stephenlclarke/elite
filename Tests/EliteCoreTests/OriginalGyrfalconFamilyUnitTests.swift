import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalGyrfalconFamilyUnitTests {
  private func retained(_ id: String) throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test(arguments: ["SH003", "SH004"])
  func eachApprovedMetreContractRejectsForeignMissingUnitsAndChangedSource(id: String) throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: id))
    let registration = try #require(OriginalGyrfalconFamilyActivation.registration(for: id))
    let model = try OriginalFleetShowroomModels.model(for: id)
    let contract = try OriginalHullPhysicalContract(definition: definition, model: model)
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(definition.sourceSHA256 == registration.specificationSHA256)
    #expect(
      model.sourceSHA256 == registration.modelSHA256 && model.sourcePath == registration.modelPath)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    #expect(contract.envelope.minimum == .init(-11.445, -3.289, -14.016))
    #expect(contract.envelope.maximum == .init(11.445, 5.16, 14.1))
    func changed(units: String? = "metres", hash: String? = nil, path: String? = nil)
      -> OriginalFleetShowroomModel
    {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(units: nil), changed(units: "showroom"),
      changed(hash: String(repeating: "0", count: 64)), changed(path: "other.toml"),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let otherID = id == "SH003" ? "SH004" : "SH003"
    let foreign = try OriginalFleetShowroomModels.model(for: otherID)
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: definition, model: foreign)
    }
    #expect(model.sourceSHA256 != foreign.sourceSHA256)
    #expect(model.nativeDesign != foreign.nativeDesign)
    #expect(OriginalGyrfalconFamilyActivation.registration(for: "SH005") == nil)
  }

  @Test(arguments: ["SH003", "SH004"])
  func originalMechanicsAndMilitaryFabricationPolicyPreserveEachLegacyProfile(id: String) throws {
    let ship = try #require(ShipCatalogue.ship(id))
    let old = try retained(id)
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == (id == "SH003" ? "Alliance Chieftain" : "Alliance Crusader"))
    #expect(ship.name == (id == "SH003" ? "Gyrfalcon Command" : "Gyrfalcon Patrol"))
    #expect(ship.game == definition.nativePerformance)
    #expect(ship.game?.speed == 45.9 && ship.game?.cargo == 16 && ship.game?.price == 259000)
    #expect(ship.game?.fuel == 120 && ship.game?.jump == 8)
    #expect(ship.catalogue.family == "gyrfalcon" && ship.catalogue.primaryRole == .military)
    #expect(ship.catalogue.primaryType == .military)
    #expect(ship.catalogue.roleWeights == [.init(role: .military, weight: 1)])
    #expect(
      ship.catalogue.purchasePolicy == .blueprintFabrication && ship.catalogue.access == .normal)
    #expect(ship.catalogue.minimumBuildTechLevel == (id == "SH003" ? 11 : 12))
    #expect(ship.catalogue.collectionMilestone == .blueprintAndFabrication)
    #expect(
      ship.catalogue.galaxies == old.catalogue.galaxies
        && ship.catalogue.regions == old.catalogue.regions)
    #expect(
      ship.catalogue.rarity == old.catalogue.rarity
        && ship.catalogue.habitat == old.catalogue.habitat)
    for profile in old.profiles {
      let historical = try #require(ship.profiles.first { $0.id == profile.id })
      #expect(historical.fields == profile.fields)
      #expect(
        historical.group
          == (profile.group == "project-refit-v1"
            ? "historical-project-refit-v1" : profile.group))
    }
    #expect(
      NativeFleetDiscovery(owner: UUID()).readout(for: id)
        == ["Collection: unknown; no native encounter recorded"])
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id)
        == [
          "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
          "SH031", "SH032", "SH033", "SH035", "SH036", "SH043", "SH061",
        ])
  }

  @Test(arguments: ["SH003", "SH004"])
  func completePhysicalPlayerGeometryAndAppearanceUseOnlyThatVariantsApprovedMetres(id: String)
    throws
  {
    let ship = try #require(ShipCatalogue.ship(id))
    let contract = try #require(ship.physicalSourceContract)
    let source = try OriginalFleetShowroomModels.model(for: id)
    #expect(ship.design == source.nativeDesign && ship.nativeDesign == source.nativeDesign)
    var commander = Commander()
    commander.shipID = id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(id))] {
      #expect(
        mesh.vertices == contract.physicalMesh.vertices && mesh.faces == source.displayMesh.faces)
      #expect(mesh.vertices.count == (id == "SH003" ? 214 : 152))
      #expect(mesh.faces.count == (id == "SH003" ? 364 : 252))
      #expect(mesh.materials.count == 8 && mesh.materials == source.displayMesh.materials)
      #expect(mesh.faceMaterials == source.displayMesh.faceMaterials)
      #expect(mesh.faceTextures == source.displayMesh.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.details == source.displayMesh.details)
      #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    }
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [22.89, 8.449, 28.116]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.displayMesh.vertices)
  }

  @Test(arguments: ["SH003", "SH004"])
  func standardFitAndInputValidationKeepEachVariantsLimitsWithoutGrantingEquipment(id: String)
    throws
  {
    let ship = try #require(ShipCatalogue.ship(id))
    let performance = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 16 && number("usable_cargo_after_fit") == 16)
    #expect(number("cargo_expansion_tonnes") == 5 && number("missile_capacity") == 7)
    #expect(number("laser_facing_mask") == 15 && number("hold_used_by_cabins") == 0)
    #expect(
      number("fitted_passenger_berths") == 0 && number("required_crew_including_commander") == 1)
    #expect(performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = id
    #expect(commander.standardCargoCapacity == 16 && commander.missileCapacity == 7)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 21)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"), encoding: .utf8)
    let target = directory.appendingPathComponent(id + ".toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == ship.name)
    let old = try retained(id)
    let invalid = source.replacingOccurrences(
      of: "name = \"" + old.name + "\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH005")
    #expect(try OriginalGyrfalconFamilyActivation.resolve(foreign) == foreign)
    #expect(!OriginalGyrfalconFamilyActivation.supports(try #require(foreign.originalDefinition)))
  }
}
