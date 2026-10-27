import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalHarpyFamilyUnitTests {
  private struct Variant: Sendable {
    let id: String
    let name: String
    let historicalName: String
    let technology: Int
    let historicalBudget: Int
    let vertices: Int
    let faces: Int
    let minimum: Vector3
    let maximum: Vector3
    let specificationSHA256: String
    let modelSHA256: String
  }

  private static let variants: [Variant] = [
    .init(
      id: "SH044", name: "Harpy Assault", historicalName: "Federal Assault Ship",
      technology: 11, historicalBudget: 14, vertices: 146, faces: 248,
      minimum: .init(-12, -4, -17.29), maximum: .init(12, 5.212, 16),
      specificationSHA256: "573f32a6b6f32e1b6152572725264d4e044d524c423d9ab1b83cc24d4ab3ac69",
      modelSHA256: "6221e902c9893e7c3e9b9557e7f3331dc95da26282b76c1edfdbeba8f9f94f25"),
    .init(
      id: "SH046", name: "Harpy Dropship", historicalName: "Federal Dropship",
      technology: 10, historicalBudget: 19, vertices: 144, faces: 240,
      minimum: .init(-12, -7.4, -17.29), maximum: .init(12, 5.212, 16),
      specificationSHA256: "22887ffdc80bcc21897d2a14ca65f7c4db2e3a862208e9050f1a1d32cef93f9d",
      modelSHA256: "2619b8ca62cad610226c8f3862882d17de9b6b83186c192eb0e099dc66eb1c4f"),
    .init(
      id: "SH047", name: "Harpy Gunship", historicalName: "Federal Gunship",
      technology: 12, historicalBudget: 11, vertices: 148, faces: 244,
      minimum: .init(-12, -4.9, -17.29), maximum: .init(12, 5.212, 16),
      specificationSHA256: "4186c90ac3c6e695df1f27ff02bc3b37f53ac608d9c323490dd3dc015cdfbca2",
      modelSHA256: "7cb0dad60b3f677c8710677403cba2213ffd5bfb1a7ee1a2d2b012cacc381dd7"),
  ]

  private static let activeIDs = [
    "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
    "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
    "SH046",
    "SH047", "SH054", "SH055", "SH056", "SH057", "SH059", "SH061", "SH062", "SH064", "SH065",
    "SH068",
    "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079", "SH080", "SH081", "SH083",
    "SH084", "SH085", "SH091", "SH093", "SH101",
  ]

  private func retained(_ id: String) throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func perVariantPhysicalContractsRefuseForeignIdentityUnitsPathsAndFingerprints() throws {
    for variant in Self.variants {
      let definition = try #require(OriginalFleetDefinitionData.definition(for: variant.id))
      let model = try OriginalFleetShowroomModels.model(for: variant.id)
      let ship = try #require(ShipCatalogue.ship(variant.id))
      let physical = try #require(ship.physicalSourceContract)
      #expect(OriginalHarpyFamilyActivation.supports(definition))
      #expect(definition.sourceSHA256 == variant.specificationSHA256)
      #expect(model.sourceSHA256 == variant.modelSHA256)
      #expect(physical.id == variant.id && physical.metresPerSourceUnit == 1)
      #expect(model.coordinateUnits == "metres" && physical.nativeTriangles == variant.faces)
      #expect(
        physical.envelope.minimum == variant.minimum && physical.envelope.maximum == variant.maximum
      )
      for (id, units, path, hash) in [
        ("SH045", "metres", model.sourcePath, model.sourceSHA256),
        (variant.id, "", model.sourcePath, model.sourceSHA256),
        (variant.id, "centimetres", model.sourcePath, model.sourceSHA256),
        (variant.id, "metres", "other.toml", model.sourceSHA256),
        (variant.id, "metres", model.sourcePath, String(repeating: "0", count: 64)),
      ] {
        let invalid = OriginalFleetShowroomModel(
          id: id, sourcePath: path, sourceSHA256: hash,
          coordinateUnits: units.isEmpty ? nil : units, nativeDesign: model.nativeDesign)
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: definition, model: invalid)
        }
      }
      let sibling = try #require(Self.variants.first { $0.id != variant.id })
      let otherModel = try OriginalFleetShowroomModels.model(for: sibling.id)
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: otherModel)
      }
    }
  }

  @Test func originalMechanicsPreserveHistoricalFieldsAndEveryUnrelatedHullBinding() throws {
    let expected = ShipPerformance(
      cargo: 16,
      speed: 43.6,
      acceleration: 14.0,
      energy: 350,
      recharge: 4.8,
      roll: 1.15,
      pitch: 1.01,
      yaw: 0.94,
      shield: 290,
      shieldRecharge: 2.0,
      fuel: 140,
      jump: 10,
      spool: 12,
      missiles: 7,
      facings: 15,
      cargoExpansion: 5,
      price: 265000,
      workTools: nil)
    for variant in Self.variants {
      let old = try retained(variant.id)
      let ship = try #require(ShipCatalogue.ship(variant.id))
      #expect(old.name == variant.historicalName && ship.name == variant.name)
      #expect(ship.game == expected && ship.originalDefinition?.nativePerformance == expected)
      for profile in old.profiles {
        let preserved = try #require(ship.profiles.first { $0.id == profile.id })
        #expect(preserved.fields == profile.fields)
        #expect(
          preserved.group
            == (profile.group == "project-refit-v1" ? "historical-project-refit-v1" : profile.group)
        )
      }
    }
    for other in ShipCatalogue.all where !Self.activeIDs.contains(other.id) {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func playerAndPhysicalMeshesKeepEveryApprovedVertexFaceMaterialAndTextureAssignment() throws
  {
    for variant in Self.variants {
      let ship = try #require(ShipCatalogue.ship(variant.id))
      let physical = try #require(ship.physicalSourceContract)
      let source = physical.model.displayMesh
      var commander = Commander()
      commander.shipID = variant.id
      for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(variant.id))] {
        #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
        #expect(mesh.vertices.count == variant.vertices && mesh.faces.count == variant.faces)
        #expect(mesh.materials == source.materials && mesh.materials.count == 8)
        #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
        #expect(
          mesh.faceTextures == source.faceTextures && mesh.faceTextures.count == variant.faces)
        #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
      }
      #expect(ship.design == physical.model.nativeDesign && ship.nativeDesign == ship.design)
      let dimensions = try #require(ship.dimensions)
      let delta = variant.maximum - variant.minimum
      #expect(dimensions.count == 3)
      for (actual, expected) in zip(dimensions, [delta.x, delta.y, delta.z]) {
        #expect(abs(actual - expected) < 1e-9)
      }
      #expect(ship.previewMesh?.vertices != source.vertices)
      #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    }
  }

  @Test func perVariantMilitaryBlueprintTechnologyAndPlacementGrantNoDiscovery() throws {
    for variant in Self.variants {
      let old = try retained(variant.id)
      let ship = try #require(ShipCatalogue.ship(variant.id))
      let policy = ship.catalogue
      #expect(
        policy.family == "harpy" && policy.primaryRole == .military
          && policy.primaryType == .military)
      #expect(policy.roleWeights == [.init(role: .military, weight: 1)])
      #expect(
        policy.purchasePolicy == .blueprintFabrication
          && policy.minimumBuildTechLevel == variant.technology)
      #expect(policy.access == .normal && policy.collectionMilestone == .blueprintAndFabrication)
      #expect(!policy.isCapital && policy.normalPurchaseEligible)
      #expect(
        policy.encounterMode == .natural && policy.placementStatus == .declared
          && policy.rarity == .uncommon)
      #expect(policy.galaxies == [0, 6, 7] && policy.regions == old.catalogue.regions)
      #expect(
        policy.authoredSystems == old.catalogue.authoredSystems
          && policy.habitat == old.catalogue.habitat)
      #expect(
        policy.valid(shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat))
      #expect(
        NativeFleetDiscovery(owner: UUID()).readout(for: ship.id) == [
          "Collection: unknown; no native encounter recorded"
        ])
    }
    #expect(OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id) == Self.activeIDs)
    let zebu = try #require(ShipCatalogue.ship("SH036"))
    #expect(try ShipAccommodationProfile(ship: zebu).equipmentUnits == 20)
    let eagle = try #require(ShipCatalogue.ship("SH043"))
    #expect(
      eagle.catalogue.purchasePolicy == .never
        && eagle.catalogue.collectionMilestone == .destruction)
  }

  @Test func e01ActualAccommodationUsesTwelveWithoutRewritingHistoryOrGrantingFittings() throws {
    for variant in Self.variants {
      let ship = try #require(ShipCatalogue.ship(variant.id))
      let performance = try #require(ship.game)
      let fit = try #require(ship.profiles.first { $0.group == "project-refit-v1" })
      func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
      let accommodation = try ShipAccommodationProfile(ship: ship)
      #expect(accommodation.equipmentUnits == 12 && accommodation.operatingCrew == 1)
      #expect(accommodation.intrinsicCrewQuarters == 1 && accommodation.initialCharterBerths == 0)
      let budget = try #require(fit.fields.first { $0.key == "equipment_capacity_units" })
      #expect(budget.number == 12 && budget.text == "12 equipment-budget units")
      #expect(budget.status == "original-fleet design estimate" && budget.basis.contains("E01"))
      let historical = try #require(
        ship.profiles.first { $0.group == "historical-project-refit-v1" })
      #expect(
        historical.fields.first { $0.key == "equipment_capacity_units" }?.number
          == Double(variant.historicalBudget))
      #expect(number("cargo_tonnes") == 16 && number("usable_cargo_after_fit") == 16)
      #expect(number("cargo_expansion_tonnes") == 5 && number("missile_capacity") == 7)
      #expect(number("laser_facing_mask") == 15 && number("hold_used_by_cabins") == 0)
      #expect(number("fitted_passenger_berths") == 0 && performance.workTools == nil)
      #expect(LaserMount.allCases.allSatisfy(performance.supports))
      #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
      var commander = Commander()
      commander.shipID = variant.id
      let inventory = commander.equipmentInventory
      let people = commander.savedNativePeopleCustody
      #expect(commander.standardCargoCapacity == 16 && commander.missileCapacity == 7)
      #expect(commander.fuelCapacity == 140)
      commander.equipment.insert("Large Cargo Bay")
      #expect(commander.standardCargoCapacity == 21)
      #expect(
        commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people)
    }
  }

  @Test func malformedRetainedInputsAndChangedDefinitionIdentityCannotActivateFamilyByName() throws
  {
    for variant in Self.variants {
      let definition = try #require(OriginalFleetDefinitionData.definition(for: variant.id))
      for (name, family, role, policy, flyable, hash) in [
        ("Other", "harpy", "military", "blueprintFabrication", true, definition.sourceSHA256),
        (variant.name, "other", "military", "blueprintFabrication", true, definition.sourceSHA256),
        (variant.name, "harpy", "trader", "blueprintFabrication", true, definition.sourceSHA256),
        (variant.name, "harpy", "military", "never", true, definition.sourceSHA256),
        (variant.name, "harpy", "military", "blueprintFabrication", false, definition.sourceSHA256),
        (
          variant.name, "harpy", "military", "blueprintFabrication", true,
          String(repeating: "0", count: 64)
        ),
      ] {
        let changed = OriginalFleetDefinition(
          id: definition.id, name: name, family: family, role: role, playerFlyable: flyable,
          purchasePolicy: policy, authored: definition.authored, sourcePath: definition.sourcePath,
          sourceSHA256: hash, nativePerformance: definition.nativePerformance,
          approvedMeshAvailable: definition.approvedMeshAvailable,
          integrationBlockers: definition.integrationBlockers)
        #expect(!OriginalHarpyFamilyActivation.supports(changed))
      }
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: folder) }
      let source = try String(
        contentsOf: ShipCatalogue.folder.appendingPathComponent(variant.id + ".toml"),
        encoding: .utf8)
      let file = folder.appendingPathComponent(variant.id + ".toml")
      try source.write(to: file, atomically: true, encoding: .utf8)
      #expect(try ShipCatalogue.load(from: folder).first?.name == variant.name)
      let invalid = source.replacingOccurrences(
        of: "name = \"" + variant.historicalName + "\"", with: "name = \"\"")
      try #require(invalid != source)
      try invalid.write(to: file, atomically: true, encoding: .utf8)
      #expect(throws: (any Error).self) { try ShipCatalogue.load(from: folder) }
    }
    for id in ["SH045", "SH042"] {
      let foreign = try retained(id)
      #expect(OriginalHarpyFamilyActivation.registration(for: id) == nil)
      #expect(try OriginalHarpyFamilyActivation.resolve(foreign) == foreign)
      let definition = try #require(foreign.originalDefinition)
      #expect(!OriginalHarpyFamilyActivation.supports(definition))
    }
  }
}
