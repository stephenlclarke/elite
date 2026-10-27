import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalAplomadoUnitTests {
  private func retained(_ id: String = "SH056") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH056"))
    let model = try OriginalFleetShowroomModels.model(for: "SH056")
    let contract = try OriginalHullPhysicalContract.aplomado.get()
    #expect(OriginalAplomadoActivation.supports(definition))
    for (role, policy, flyable, hash) in [
      ("trader", "blueprintFabrication", true, definition.sourceSHA256),
      ("leisure", "blueprintFabrication", true, definition.sourceSHA256),
      ("pirate", "blueprintFabrication", true, definition.sourceSHA256),
      ("transporter", "blueprintFabrication", true, definition.sourceSHA256),
      ("bountyHunter", "blueprintFabrication", true, definition.sourceSHA256),
      ("miner", "blueprintFabrication", true, definition.sourceSHA256),
      ("military", "never", true, definition.sourceSHA256),
      ("military", "blueprintFabrication", false, definition.sourceSHA256),
      ("military", "blueprintFabrication", true, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetDefinition(
        id: definition.id, name: definition.name, family: definition.family, role: role,
        playerFlyable: flyable, purchasePolicy: policy, authored: definition.authored,
        sourcePath: definition.sourcePath, sourceSHA256: hash,
        nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: definition.approvedMeshAvailable,
        integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalAplomadoActivation.supports(changed))
      if hash != definition.sourceSHA256 {
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: changed, model: model)
        }
      }
    }
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-8.5, -3.124, -23.69))
    #expect(contract.envelope.maximum == .init(8.5, 4.5, 23.5))
    #expect(contract.nativeTriangles == 120)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(
      id: String = "SH056", units: String? = "metres", path: String? = nil,
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
    for id in ["SH005", "SH006", "SH028", "SH086", "SH058", "SH076", "SH082"] {
      let foreign = try retained(id)
      let foreignDefinition = try #require(foreign.originalDefinition)
      #expect(
        !OriginalAplomadoActivation.supports(foreignDefinition)
          && !foreignDefinition.runtimeReady)
      #expect(try OriginalAplomadoActivation.resolve(foreign) == foreign)
      #expect(try OriginalPlayerHullActivation.resolve(foreign) == foreign)
      #expect(ShipCatalogue.ship(id) == foreign)
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(
          foreign, definition: foreignDefinition, physical: contract)
      }
    }
  }

  @Test func originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH056"))
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == "Harrier" && ship.name == "Aplomado Interceptor")
    #expect(ship.game == definition.nativePerformance)
    #expect(ship.game?.cargo == 18 && ship.game?.speed == 42.3 && ship.game?.acceleration == 13.4)
    #expect(ship.game?.energy == 360 && ship.game?.shield == 300 && ship.game?.recharge == 5.66)
    #expect(ship.game?.fuel == 120 && ship.game?.jump == 8 && ship.game?.price == 262000)
    #expect(definition.sourceSHA256 == OriginalAplomadoActivation.specificationSHA256)
    let sibling = try #require(ShipCatalogue.ship("SH057"))
    #expect(sibling.name == "Falconet" && sibling.game == ship.game)
    #expect(sibling.nativeDesign != ship.nativeDesign)
    #expect(sibling.physicalSourceContract?.id == "SH057")
    #expect(!OriginalAplomadoActivation.supports(try #require(sibling.originalDefinition)))
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
      "SH046", "SH047", "SH054", "SH055", "SH056", "SH057", "SH059", "SH061", "SH062", "SH064",
      "SH065",
      "SH068", "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079", "SH080", "SH081",
      "SH083", "SH084", "SH085", "SH091", "SH093", "SH101",
    ]
    .contains(
      other.id)
    {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH056"))
    let physical = try OriginalHullPhysicalContract.aplomado.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 76 && mesh.faces.count == 120)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign && ship.design == ship.nativeDesign)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [17.0, 7.624, 47.19]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.vertices)
    let rawHarrier = try retained()
    let c01 = try NativeC01SurveyorGeometry.harrier.get()
    #expect(throws: (any Error).self) {
      try NativeC01SurveyorGeometry.historicalHarrier(ship)
    }
    #expect(rawHarrier.name == "Harrier" && rawHarrier.model == "ROC-SH056")
    #expect(c01.design.vertices.count == 1426 && c01.design.faces.count == 1065)
    #expect(c01.design.faces == rawHarrier.design.faces && c01.design != ship.nativeDesign)
    #expect(
      abs(try OriginalHullEnvelope(vertices: c01.design.rawMesh.vertices).dimensions.z - 65) < 1e-9)
    let c01Hash = "18708f6f3b4f6078bf28c1db9bc30c07f3fc32df76b4beabd6df06d3fa10515a"
    #expect(try ScriptPackLibrary.hash(ScriptPackLibrary.canonicalGeometry(c01.design)) == c01Hash)
    #expect(try NativeC01Surveyor.modelHashes.get()["asset:c01-harrier-65m"] == c01Hash)
  }

  @Test func militaryPolicyKeepsAccessAndPlacementWithoutChangingActorAuthorityOrEarlierRoles()
    throws
  {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH056"))
    let policy = ship.catalogue
    #expect(
      policy.family == "aplomado" && policy.primaryRole == .military
        && policy.primaryType == .military)
    #expect(policy.roleWeights == [.init(role: .military, weight: 1)])
    #expect(policy.purchasePolicy == .blueprintFabrication && policy.minimumBuildTechLevel == 7)
    #expect(!policy.isCapital && policy.capitalSubtype == nil)
    #expect(policy.minimumStandardCargoTonnes == 0)
    #expect(policy.access == .normal && policy.collectionMilestone == .blueprintAndFabrication)
    #expect(policy.placementStatus == .declared && policy.encounterMode == .natural)
    #expect(
      policy.galaxies == [0, 1, 2] && policy.regions == old.catalogue.regions
        && policy.authoredSystems == old.catalogue.authoredSystems)
    #expect(policy.rarity == .uncommon && policy.habitat == old.catalogue.habitat)
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
      ("SH079", .transporter, .transporter), ("SH080", .transporter, .transporter),
      ("SH081", .military, .military), ("SH083", .leisure, .leisure),
      ("SH084", .trader, .trader), ("SH085", .bountyHunter, .bountyHunter),
    ] {
      let earlier = try #require(ShipCatalogue.ship(id))
      #expect(earlier.catalogue.primaryRole == role && earlier.catalogue.primaryType == type)
    }
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id)
        == [
          "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
          "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
          "SH046", "SH047", "SH054", "SH055", "SH056", "SH057", "SH059", "SH061", "SH062", "SH064",
          "SH065",
          "SH068", "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079", "SH080", "SH081",
          "SH083", "SH084", "SH085", "SH091", "SH093", "SH101",
        ])
    var game = Game(executive: false)
    game.docked = false
    game.screen = .front
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    game.speed = 0
    game.bodies = []
    var npc = NPCState(
      role: .escort, origin: game.systemIdentity, destination: .init(galaxy: 1, system: 0))
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
    #expect(body.physical?.npc?.role == .escort && body.physical?.population == .civilian)
    #expect(
      body.physical?.npc?.legal == npc.legal && body.physical?.npc?.intention == npc.intention)
    #expect(body.physical?.npc?.resources?.energyCapacity == 360)
    #expect(body.physical?.npc?.resources?.frontCapacity == 300)
    #expect(body.physical?.npc?.resources?.fuelCapacity == 120)
  }

  @Test func originalHoldCrewWeaponLimitsAndRetainedInputValidationGrantNoFreeFittings() throws {
    let ship = try #require(ShipCatalogue.ship("SH056"))
    let performance = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 18 && number("usable_cargo_after_fit") == 18)
    #expect(number("cargo_expansion_tonnes") == 5 && number("missile_capacity") == 7)
    #expect(number("laser_facing_mask") == 15 && number("hold_used_by_cabins") == 0)
    #expect(
      number("fitted_passenger_berths") == 0 && number("required_crew_including_commander") == 1)
    let accommodation = try ShipAccommodationProfile(ship: ship)
    #expect(accommodation.equipmentUnits == 12 && accommodation.operatingCrew == 1)
    #expect(accommodation.intrinsicCrewQuarters == 1 && accommodation.initialCharterBerths == 0)
    #expect(number("equipment_capacity_units") == 12 && number("reserved_crew_accommodation") == 1)
    let historical = try #require(ship.profiles.first { $0.group == "historical-project-refit-v1" })
    #expect(historical.fields.first { $0.key == "equipment_capacity_units" }?.number == 12)
    for key in ["required_crew_including_commander", "reserved_crew_accommodation"] {
      #expect(historical.fields.first { $0.key == key }?.number == 2)
      let live = try #require(fit.fields.first { $0.key == key })
      #expect(live.number == 1 && live.status == "original-fleet design estimate")
      #expect(live.basis.contains("E01"))
    }
    let budget = try #require(fit.fields.first { $0.key == "equipment_capacity_units" })
    #expect(budget.number == 12)
    #expect(budget == historical.fields.first { $0.key == "equipment_capacity_units" })
    #expect(performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = ship.id
    let inventory = commander.equipmentInventory
    let people = commander.savedNativePeopleCustody
    #expect(commander.standardCargoCapacity == 18 && commander.missileCapacity == 7)
    #expect(commander.fuelCapacity == 120 && commander.fittedMiningWorkTool == nil)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 23)
    #expect(
      commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH056.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH056.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == ship.name)
    let invalid = source.replacingOccurrences(
      of: "name = \"Harrier\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH020")
    #expect(try OriginalAplomadoActivation.resolve(foreign) == foreign)
    #expect(!OriginalAplomadoActivation.supports(try #require(foreign.originalDefinition)))
  }
}
