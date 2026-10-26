import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalZebuUnitTests {
  private func retained(_ id: String = "SH036") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH036"))
    let model = try OriginalFleetShowroomModels.model(for: "SH036")
    let contract = try OriginalHullPhysicalContract.zebu.get()
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-12.8, -5, -21.09))
    #expect(contract.envelope.maximum == .init(12.8, 11.656, 25.5))
    #expect(contract.nativeTriangles == 192)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(
      id: String = "SH036", units: String? = "metres", path: String? = nil,
      hash: String? = nil
    ) -> OriginalFleetShowroomModel {
      .init(
        id: id, sourcePath: path ?? model.sourcePath, sourceSHA256: hash ?? model.sourceSHA256,
        coordinateUnits: units, nativeDesign: model.nativeDesign)
    }
    for invalid in [
      changed(id: "SH020"), changed(units: nil), changed(units: "showroom"),
      changed(path: "other.toml"), changed(hash: String(repeating: "0", count: 64)),
    ] {
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: invalid)
      }
    }
    let other = try #require(OriginalFleetDefinitionData.definition(for: "SH020"))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: other, model: model)
    }
  }

  @Test func originalTraderMechanicsRetainAllHistoricalFieldsAndOtherHullBindings() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH036"))
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == "Drake" && ship.name == "Zebu")
    #expect(ship.game == definition.nativePerformance)
    #expect(ship.game?.cargo == 58 && ship.game?.speed == 35.9 && ship.game?.acceleration == 10)
    #expect(ship.game?.energy == 260 && ship.game?.shield == 230 && ship.game?.recharge == 3.2)
    #expect(ship.game?.fuel == 150 && ship.game?.jump == 11 && ship.game?.price == 217000)
    #expect(definition.sourceSHA256 == OriginalZebuActivation.specificationSHA256)
    for profile in old.profiles {
      let historical = try #require(ship.profiles.first { $0.id == profile.id })
      #expect(historical.fields == profile.fields)
      #expect(
        historical.group
          == (profile.group == "project-refit-v1"
            ? "historical-project-refit-v1" : profile.group))
    }
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

  @Test func physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH036"))
    let physical = try OriginalHullPhysicalContract.zebu.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 114 && mesh.faces.count == 192)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign && ship.design == ship.nativeDesign)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [25.6, 16.656, 46.59]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.vertices)
  }

  @Test func traderPolicyKeepsNaturalPlacementAndBlueprintWithoutChangingEarlierRoles()
    throws
  {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH036"))
    let policy = ship.catalogue
    #expect(
      policy.family == "zebu" && policy.primaryRole == .trader
        && policy.primaryType == .trader)
    #expect(policy.roleWeights == [.init(role: .trader, weight: 1)])
    #expect(policy.purchasePolicy == .blueprintFabrication && policy.minimumBuildTechLevel == 6)
    #expect(policy.access == .normal && policy.collectionMilestone == .blueprintAndFabrication)
    #expect(policy.placementStatus == .declared && policy.encounterMode == .natural)
    #expect(
      policy.galaxies == Array(0..<8) && policy.regions == old.catalogue.regions
        && policy.authoredSystems == old.catalogue.authoredSystems)
    #expect(policy.rarity == .common && policy.habitat == old.catalogue.habitat)
    #expect(policy.valid(shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat))
    #expect(
      NativeFleetDiscovery(owner: UUID()).readout(for: ship.id)
        == ["Collection: unknown; no native encounter recorded"])
    for (id, role, type) in [
      ("SH029", ShipCatalogueRole.trader, ShipCatalogueType.trader),
      ("SH061", .trader, .trader), ("SH002", .military, .military),
      ("SH003", .military, .military), ("SH004", .military, .military),
      ("SH007", .leisure, .leisure),
    ] {
      let earlier = try #require(ShipCatalogue.ship(id))
      #expect(earlier.catalogue.primaryRole == role && earlier.catalogue.primaryType == type)
    }
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id)
        == [
          "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
          "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
          "SH046",
          "SH047", "SH054", "SH055", "SH061",
        ])
  }

  @Test func originalHoldCrewWeaponLimitsAndRetainedInputValidationGrantNoFreeFittings() throws {
    let ship = try #require(ShipCatalogue.ship("SH036"))
    let performance = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 58 && number("usable_cargo_after_fit") == 58)
    #expect(number("cargo_expansion_tonnes") == 25 && number("missile_capacity") == 5)
    #expect(number("laser_facing_mask") == 15 && number("hold_used_by_cabins") == 0)
    #expect(
      number("fitted_passenger_berths") == 0 && number("required_crew_including_commander") == 1)
    let budget = try #require(fit.fields.first { $0.key == "equipment_capacity_units" })
    #expect(budget.number == 20 && budget.text == "20 equipment-budget units")
    #expect(budget.status == "original-fleet design estimate" && budget.basis.contains("E01"))
    #expect(number("reserved_crew_accommodation") == 1)
    let accommodation = try ShipAccommodationProfile(ship: ship)
    #expect(accommodation.equipmentUnits == 20 && accommodation.operatingCrew == 1)
    #expect(accommodation.intrinsicCrewQuarters == 1 && accommodation.initialCharterBerths == 0)
    let historical = try #require(ship.profiles.first { $0.group == "historical-project-refit-v1" })
    #expect(historical.fields.first { $0.key == "equipment_capacity_units" }?.number == 12)
    #expect(performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = ship.id
    let inventory = commander.equipmentInventory
    let people = commander.savedNativePeopleCustody
    #expect(commander.standardCargoCapacity == 58 && commander.missileCapacity == 5)
    #expect(commander.fuelCapacity == 150)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 83)
    #expect(
      commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH036.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH036.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == ship.name)
    let invalid = source.replacingOccurrences(of: "name = \"Drake\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH020")
    #expect(try OriginalZebuActivation.resolve(foreign) == foreign)
    #expect(!OriginalZebuActivation.supports(try #require(foreign.originalDefinition)))
  }
}
