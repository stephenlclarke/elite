import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalCarabaoCarrierUnitTests {
  private func retained(_ id: String = "SH079") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH079"))
    let model = try OriginalFleetShowroomModels.model(for: "SH079")
    let contract = try OriginalHullPhysicalContract.carabaoCarrier.get()
    #expect(OriginalCarabaoCarrierActivation.supports(definition))
    for (role, policy, flyable, hash) in [
      ("trader", "blueprintFabrication", true, definition.sourceSHA256),
      ("military", "blueprintFabrication", true, definition.sourceSHA256),
      ("pirate", "blueprintFabrication", true, definition.sourceSHA256),
      ("leisure", "blueprintFabrication", true, definition.sourceSHA256),
      ("transporter", "never", true, definition.sourceSHA256),
      ("transporter", "blueprintFabrication", false, definition.sourceSHA256),
      ("transporter", "blueprintFabrication", true, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetDefinition(
        id: definition.id, name: definition.name, family: definition.family, role: role,
        playerFlyable: flyable, purchasePolicy: policy, authored: definition.authored,
        sourcePath: definition.sourcePath, sourceSHA256: hash,
        nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: definition.approvedMeshAvailable,
        integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalCarabaoCarrierActivation.supports(changed))
      if hash != definition.sourceSHA256 {
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: changed, model: model)
        }
      }
    }
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-18, -7.72, -41.09))
    #expect(contract.envelope.maximum == .init(18, 15.48, 36.5))
    #expect(contract.nativeTriangles == 204)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(
      id: String = "SH079", units: String? = "metres", path: String? = nil,
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
    for id in ["SH005", "SH006", "SH028", "SH056", "SH058", "SH076"] {
      let foreign = try retained(id)
      let foreignDefinition = try #require(foreign.originalDefinition)
      #expect(
        !OriginalCarabaoCarrierActivation.supports(foreignDefinition)
          && !foreignDefinition.runtimeReady)
      #expect(try OriginalCarabaoCarrierActivation.resolve(foreign) == foreign)
      #expect(try OriginalPlayerHullActivation.resolve(foreign) == foreign)
      #expect(ShipCatalogue.ship(id) == foreign)
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(
          foreign, definition: foreignDefinition, physical: contract)
      }
    }
  }

  @Test func originalTransporterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH079"))
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == "Lynx Bulk Carrier" && ship.name == "Carabao Carrier")
    #expect(ship.game == definition.nativePerformance)
    #expect(ship.game?.cargo == 786 && ship.game?.speed == 19.6 && ship.game?.acceleration == 4.8)
    #expect(ship.game?.energy == 970 && ship.game?.shield == 550 && ship.game?.recharge == 6.44)
    #expect(ship.game?.fuel == 130 && ship.game?.jump == 7 && ship.game?.price == 580000)
    #expect(definition.sourceSHA256 == OriginalCarabaoCarrierActivation.specificationSHA256)
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
      "SH046", "SH047", "SH054", "SH055", "SH057", "SH059", "SH061", "SH062", "SH064", "SH065",
      "SH068", "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079",
    ]
    .contains(
      other.id)
    {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func physicalPlayerAndSalvageConsumersKeepCompleteApprovedGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH079"))
    let physical = try OriginalHullPhysicalContract.carabaoCarrier.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 132 && mesh.faces.count == 204)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign && ship.design == ship.nativeDesign)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [36.0, 23.2, 77.59]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.vertices)
    let salvage = try #require(SalvageCatalogue.profile(catalogueShipID: ship.id))
    #expect(salvage.name == ship.name && salvage.role == .carrier)
    #expect(salvage.sourceRoles == [.commercialCarrier] && salvage.physicalScale == 1)
    #expect(salvage.mesh.vertices == source.vertices && salvage.mesh.faces == source.faces)
    #expect(
      salvage.mesh.materials == source.materials
        && salvage.mesh.faceMaterials == source.faceMaterials)
    #expect(salvage.mesh.faceTextures == source.faceTextures)
    #expect(
      salvage.minimum == physical.envelope.minimum && salvage.maximum == physical.envelope.maximum)
    #expect(
      salvage.mesh.vertices.allSatisfy {
        ($0 - salvage.bounds.center).length <= salvage.bounds.radius
      })
    #expect(salvage.sections.count == SalvageSectionKind.allCases.count)
    #expect(salvage.sections.allSatisfy { salvage.mesh.faces.indices.contains($0.sourceFaceIndex) })
    #expect(
      SalvageCatalogue.eligibility(catalogueShipID: ship.id, ownership: .abandoned) == .allowed)
    #expect(
      SalvageCatalogue.eligibility(catalogueShipID: ship.id, ownership: .occupied) == .occupied)
    #expect(SalvageCatalogue.eligibility(catalogueShipID: ship.id, ownership: .claimed) == .claimed)
    #expect(
      SalvageCatalogue.eligibility(
        catalogueShipID: ship.id, ownership: .abandoned, missionProtected: true)
        == .missionProtected)
    #expect(
      SalvageCatalogue.eligibility(
        catalogueShipID: ship.id, ownership: .abandoned, activeStation: true) == .activeStation)
  }

  @Test func transporterPolicyKeepsAccessAndPlacementWithoutChangingActorAuthorityOrEarlierRoles()
    throws
  {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH079"))
    let policy = ship.catalogue
    #expect(
      policy.family == "carabao" && policy.primaryRole == .transporter
        && policy.primaryType == .transporter)
    #expect(policy.roleWeights == [.init(role: .transporter, weight: 1)])
    #expect(policy.purchasePolicy == .blueprintFabrication && policy.minimumBuildTechLevel == 12)
    #expect(!policy.isCapital && policy.capitalSubtype == nil)
    #expect(policy.access == .normal && policy.collectionMilestone == .blueprintAndFabrication)
    #expect(policy.placementStatus == .declared && policy.encounterMode == .natural)
    #expect(
      policy.galaxies == [3] && policy.regions == old.catalogue.regions
        && policy.authoredSystems == old.catalogue.authoredSystems)
    #expect(policy.rarity == .rare && policy.habitat == old.catalogue.habitat)
    #expect(policy.valid(shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat))
    #expect(
      NativeFleetDiscovery(owner: UUID()).readout(for: ship.id)
        == ["Collection: unknown; no native encounter recorded"])
    for (id, role, type) in [
      ("SH029", ShipCatalogueRole.trader, ShipCatalogueType.trader),
      ("SH061", .trader, .trader), ("SH002", .military, .military),
      ("SH003", .military, .military), ("SH004", .military, .military),
      ("SH007", .leisure, .leisure), ("SH012", .leisure, .leisure), ("SH018", .trader, .trader),
      ("SH030", .bountyHunter, .bountyHunter), ("SH054", .military, .military),
      ("SH055", .pirate, .pirate), ("SH062", .transporter, .transporter),
      ("SH064", .transporter, .transporter),
      ("SH065", .pirate, .pirate), ("SH068", .miner, .miner),
      ("SH069", .military, .military), ("SH070", .bountyHunter, .bountyHunter),
      ("SH074", .transporter, .transporter), ("SH075", .transporter, .transporter),
      ("SH077", .transporter, .transporter), ("SH078", .leisure, .leisure),
    ] {
      let earlier = try #require(ShipCatalogue.ship(id))
      #expect(earlier.catalogue.primaryRole == role && earlier.catalogue.primaryType == type)
    }
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id)
        == [
          "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
          "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
          "SH046", "SH047", "SH054", "SH055", "SH057", "SH059", "SH061", "SH062", "SH064", "SH065",
          "SH068", "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079",
        ])
    var game = Game(executive: false)
    game.docked = false
    game.screen = .front
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    game.speed = 0
    game.bodies = []
    var npc = NPCState(
      role: .trader, origin: game.systemIdentity, destination: .init(galaxy: 1, system: 0))
    npc.legal.value = 7
    npc.legal.bountyTenths = 30
    npc.legalProvenance = .recorded
    npc.cargoProvenance = .recorded
    npc.routeProvenance = .generated
    npc.intention = .navigate(
      position: game.commander.flightSimulation.pose.systemPoint(.init(3000, 0, 3000)),
      speedUnitsPerSecond: 0)
    var request = SpawnRequest(
      identity: .init(
        system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
        sequence: 2, member: 0), population: .civilian, hull: .cobra,
      position: game.commander.flightSimulation.pose.systemPoint(.init(1000, 0, 1000)),
      orientation: Basis3(), velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil,
      priority: .ordinary)
    request.catalogueShipID = ship.id
    let plan = EncounterPlan(
      system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
      revision: game.gameplayRevision, batches: [.init(requests: [request], atomic: false)],
      intents: [])
    let receipt = try #require(game.admitEncounterPlan(plan).first)
    #expect(receipt.refusal == nil && receipt.actor != nil)
    let body = try #require(game.bodies.first)
    #expect(body.physical?.catalogueShipID == ship.id && !body.hostile)
    #expect(body.physical?.npc?.role == .trader && body.physical?.population == .civilian)
    #expect(
      body.physical?.npc?.legal == npc.legal && body.physical?.npc?.intention == npc.intention)
    #expect(body.physical?.npc?.resources?.energyCapacity == 970)
    #expect(body.physical?.npc?.resources?.frontCapacity == 550)
    #expect(body.physical?.npc?.resources?.fuelCapacity == 130)
  }

  @Test func originalHoldCrewWeaponLimitsAndRetainedInputValidationGrantNoFreeFittings() throws {
    let ship = try #require(ShipCatalogue.ship("SH079"))
    let performance = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 786 && number("usable_cargo_after_fit") == 786)
    #expect(number("cargo_expansion_tonnes") == 315 && number("missile_capacity") == 7)
    #expect(number("laser_facing_mask") == 15 && number("hold_used_by_cabins") == 0)
    #expect(
      number("fitted_passenger_berths") == 0 && number("required_crew_including_commander") == 9)
    let accommodation = try ShipAccommodationProfile(ship: ship)
    #expect(accommodation.equipmentUnits == 166 && accommodation.operatingCrew == 9)
    #expect(accommodation.intrinsicCrewQuarters == 9 && accommodation.initialCharterBerths == 0)
    #expect(number("equipment_capacity_units") == 166 && number("reserved_crew_accommodation") == 9)
    let historical = try #require(ship.profiles.first { $0.group == "historical-project-refit-v1" })
    #expect(historical.fields.first { $0.key == "equipment_capacity_units" }?.number == 608)
    for key in ["required_crew_including_commander", "reserved_crew_accommodation"] {
      #expect(historical.fields.first { $0.key == key }?.number == 20)
      let live = try #require(fit.fields.first { $0.key == key })
      #expect(live.number == 9 && live.status == "original-fleet design estimate")
      #expect(live.basis.contains("E01"))
    }
    let budget = try #require(fit.fields.first { $0.key == "equipment_capacity_units" })
    #expect(budget.text == "166 equipment-budget units" && budget.basis.contains("E01"))
    #expect(budget.status == "original-fleet design estimate")
    #expect(performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = ship.id
    let inventory = commander.equipmentInventory
    let people = commander.savedNativePeopleCustody
    #expect(commander.standardCargoCapacity == 786 && commander.missileCapacity == 7)
    #expect(commander.fuelCapacity == 130)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 1101)
    #expect(
      commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH079.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH079.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == ship.name)
    let invalid = source.replacingOccurrences(
      of: "name = \"Lynx Bulk Carrier\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH020")
    #expect(try OriginalCarabaoCarrierActivation.resolve(foreign) == foreign)
    #expect(!OriginalCarabaoCarrierActivation.supports(try #require(foreign.originalDefinition)))
  }
}
