import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalPantherFamilyUnitTests {
  private struct Facts: Sendable {
    let name: String
    let legacy: String
    let role: ShipCatalogueRole
    let type: ShipCatalogueType
    let vertices: Int
    let faces: Int
    let cargo: Int
    let expansion: Int
    let speed: Double
    let acceleration: Double
    let energy: Double
    let shield: Double
    let fuel: Int
    let jump: Double
    let missiles: Int
    let price: Int
    let technology: Int
  }

  private static let facts: [String: Facts] = [
    "SH032": .init(
      name: "Panther Explorer", legacy: "Diamondback Explorer", role: .leisure,
      type: .leisure, vertices: 206, faces: 352, cargo: 28, expansion: 10, speed: 46.2,
      acceleration: 12.5, energy: 190, shield: 200, fuel: 140, jump: 10, missiles: 5,
      price: 205000, technology: 10),
    "SH033": .init(
      name: "Panther Scout", legacy: "Diamondback Scout", role: .military,
      type: .military, vertices: 188, faces: 320, cargo: 16, expansion: 5, speed: 49.5,
      acceleration: 14.6, energy: 310, shield: 270, fuel: 120, jump: 8, missiles: 7,
      price: 257000, technology: 8),
  ]

  private func retained(_ id: String) throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test(arguments: ["SH032", "SH033"])
  func exactMetreContractsRefuseSwappedModelsWrongRolesAndChangedSources(id: String) throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: id))
    let approved = try #require(OriginalPantherFamilyActivation.registration(for: id))
    let model = try OriginalFleetShowroomModels.model(for: id)
    let contract = try OriginalHullPhysicalContract(definition: definition, model: model)
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(
      definition.role == approved.role.rawValue
        && definition.sourceSHA256 == approved.specificationSHA256)
    #expect(model.sourcePath == approved.modelPath && model.sourceSHA256 == approved.modelSHA256)
    #expect(contract.envelope.minimum == .init(-9.829, -6.2, -20.09))
    #expect(contract.envelope.maximum == .init(9.829, 7.48, 17))
    func changed(units: String? = "metres", path: String? = nil, hash: String? = nil)
      -> OriginalFleetShowroomModel
    {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(units: nil), changed(units: "showroom"), changed(path: "other.toml"),
      changed(hash: String(repeating: "0", count: 64)),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let otherID = id == "SH032" ? "SH033" : "SH032"
    let other = try #require(OriginalFleetDefinitionData.definition(for: otherID))
    let otherModel = try OriginalFleetShowroomModels.model(for: otherID)
    #expect(
      model.nativeDesign != otherModel.nativeDesign && model.sourceSHA256 != otherModel.sourceSHA256
    )
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: definition, model: otherModel)
    }
    let wrongRole = OriginalFleetDefinition(
      id: definition.id, name: definition.name, family: definition.family, role: other.role,
      playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
      authored: definition.authored, sourcePath: definition.sourcePath,
      sourceSHA256: definition.sourceSHA256,
      nativePerformance: definition.nativePerformance,
      approvedMeshAvailable: definition.approvedMeshAvailable,
      integrationBlockers: definition.integrationBlockers)
    #expect(!OriginalPantherFamilyActivation.supports(wrongRole))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: wrongRole, model: model)
    }
    #expect(OriginalPantherFamilyActivation.registration(for: "SH034") == nil)
  }

  @Test(arguments: ["SH032", "SH033"])
  func originalVariantMechanicsRolesBlueprintsAndHistoricalFieldsRemainDistinct(id: String) throws {
    let expected = try #require(Self.facts[id])
    let old = try retained(id)
    let ship = try #require(ShipCatalogue.ship(id))
    let definition = try #require(ship.originalDefinition)
    let performance = try #require(ship.game)
    #expect(old.name == expected.legacy && ship.name == expected.name)
    #expect(performance == definition.nativePerformance)
    #expect(performance.cargo == expected.cargo && performance.cargoExpansion == expected.expansion)
    #expect(
      performance.speed == expected.speed && performance.acceleration == expected.acceleration)
    #expect(performance.energy == expected.energy && performance.shield == expected.shield)
    #expect(performance.fuel == expected.fuel && performance.jump == expected.jump)
    #expect(performance.missiles == expected.missiles && performance.price == expected.price)
    #expect(ship.catalogue.family == "panther" && ship.catalogue.primaryRole == expected.role)
    #expect(ship.catalogue.primaryType == expected.type)
    #expect(ship.catalogue.roleWeights == [.init(role: expected.role, weight: 1)])
    #expect(
      ship.catalogue.purchasePolicy == .blueprintFabrication && ship.catalogue.access == .normal)
    #expect(ship.catalogue.minimumBuildTechLevel == expected.technology)
    #expect(ship.catalogue.collectionMilestone == .blueprintAndFabrication)
    #expect(
      ship.catalogue.galaxies == [2, 3, 4] && ship.catalogue.regions == old.catalogue.regions)
    #expect(ship.catalogue.placementStatus == .declared && ship.catalogue.encounterMode == .natural)
    #expect(ship.catalogue.rarity == .uncommon && ship.catalogue.habitat == old.catalogue.habitat)
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
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id) == [
        "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029",
        "SH030", "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044",
        "SH046", "SH047", "SH061",
      ])
  }

  @Test(arguments: ["SH032", "SH033"])
  func everyPhysicalPlayerVertexAndAppearanceAssignmentUsesItsOwnApprovedSource(id: String) throws {
    let expected = try #require(Self.facts[id])
    let ship = try #require(ShipCatalogue.ship(id))
    let contract = try #require(ship.physicalSourceContract)
    let source = try OriginalFleetShowroomModels.model(for: id)
    #expect(ship.design == source.nativeDesign && ship.nativeDesign == source.nativeDesign)
    var commander = Commander()
    commander.shipID = id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(id))] {
      #expect(
        mesh.vertices == contract.physicalMesh.vertices && mesh.faces == source.displayMesh.faces)
      #expect(mesh.vertices.count == expected.vertices && mesh.faces.count == expected.faces)
      #expect(mesh.materials == source.displayMesh.materials && mesh.materials.count == 8)
      #expect(
        mesh.faceMaterials == source.displayMesh.faceMaterials
          && mesh.details == source.displayMesh.details)
      #expect(mesh.faceTextures == source.displayMesh.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= contract.envelope.clearanceRadius })
    }
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [19.658, 13.68, 37.09]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.previewMesh?.vertices != source.displayMesh.vertices)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
  }

  @Test(arguments: ["SH032", "SH033"])
  func eachStandardFitKeepsOwnCargoFuelAndWeaponLimitsAndRejectsMalformedRetainedInput(id: String)
    throws
  {
    let expected = try #require(Self.facts[id])
    let ship = try #require(ShipCatalogue.ship(id))
    let performance = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(
      number("cargo_tonnes") == Double(expected.cargo)
        && number("usable_cargo_after_fit") == Double(expected.cargo))
    #expect(number("cargo_expansion_tonnes") == Double(expected.expansion))
    #expect(
      number("missile_capacity") == Double(expected.missiles) && number("laser_facing_mask") == 15)
    #expect(
      number("fuel_capacity_tenths_ly") == Double(expected.fuel)
        && number("hyperspace_range_ly") == expected.jump)
    #expect(
      number("required_crew_including_commander") == 1 && number("fitted_passenger_berths") == 0)
    #expect(number("hold_used_by_cabins") == 0 && performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = id
    #expect(
      commander.standardCargoCapacity == expected.cargo
        && commander.missileCapacity == expected.missiles)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == expected.cargo + expected.expansion)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"), encoding: .utf8)
    let target = directory.appendingPathComponent(id + ".toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == expected.name)
    let invalid = source.replacingOccurrences(
      of: "name = \"" + expected.legacy + "\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH034")
    #expect(try OriginalPantherFamilyActivation.resolve(foreign) == foreign)
    #expect(!OriginalPantherFamilyActivation.supports(try #require(foreign.originalDefinition)))
  }
}
