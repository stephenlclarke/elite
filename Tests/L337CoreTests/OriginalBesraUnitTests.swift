import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct OriginalBesraUnitTests {
  private func retained(_ id: String = "SH108") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH108"))
    let model = try OriginalFleetShowroomModels.model(for: "SH108")
    let contract = try OriginalHullPhysicalContract.besra.get()
    #expect(OriginalBesraActivation.supports(definition))
    let unavailable = OriginalFleetDefinition(
      id: definition.id, name: definition.name, family: definition.family, role: definition.role,
      playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
      authored: definition.authored, sourcePath: definition.sourcePath,
      sourceSHA256: definition.sourceSHA256, nativePerformance: nil,
      approvedMeshAvailable: definition.approvedMeshAvailable,
      integrationBlockers: definition.integrationBlockers)
    #expect(!OriginalBesraActivation.supports(unavailable))
    for (id, name, family, available) in [
      ("SH068", "Besra", "besra", true), ("SH108", "Badger", "besra", true),
      ("SH108", "Besra", "badger", true), ("SH108", "Besra", "besra", false),
    ] {
      let changed = OriginalFleetDefinition(
        id: id, name: name, family: family, role: definition.role,
        playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
        authored: definition.authored, sourcePath: definition.sourcePath,
        sourceSHA256: definition.sourceSHA256, nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: available, integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalBesraActivation.supports(changed))
    }
    for (role, policy, flyable, hash) in [
      ("trader", "blueprintFabrication", true, definition.sourceSHA256),
      ("military", "blueprintFabrication", true, definition.sourceSHA256),
      ("pirate", "blueprintFabrication", true, definition.sourceSHA256),
      ("transporter", "blueprintFabrication", true, definition.sourceSHA256),
      ("bountyHunter", "never", true, definition.sourceSHA256),
      ("bountyHunter", "blueprintFabrication", false, definition.sourceSHA256),
      ("bountyHunter", "blueprintFabrication", true, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetDefinition(
        id: definition.id, name: definition.name, family: definition.family, role: role,
        playerFlyable: flyable, purchasePolicy: policy, authored: definition.authored,
        sourcePath: definition.sourcePath, sourceSHA256: hash,
        nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: definition.approvedMeshAvailable,
        integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalBesraActivation.supports(changed))
      if hash != definition.sourceSHA256 {
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: changed, model: model)
        }
      }
    }
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-11.124, -4.6, -22.09))
    #expect(contract.envelope.maximum == .init(11.124, 6.124, 14))
    #expect(contract.nativeTriangles == 208)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(
      id: String = "SH108", units: String? = "metres", path: String? = nil,
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
    for id in ["SH005", "SH006", "SH104", "SH105", "SH106", "SH107"] {
      let foreign = try retained(id)
      let foreignDefinition = try #require(foreign.originalDefinition)
      #expect(
        !OriginalBesraActivation.supports(foreignDefinition)
          && !foreignDefinition.runtimeReady)
      #expect(try OriginalBesraActivation.resolve(foreign) == foreign)
      #expect(try OriginalPlayerHullActivation.resolve(foreign) == foreign)
      #expect(ShipCatalogue.ship(id) == foreign)
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(
          foreign, definition: foreignDefinition, physical: contract)
      }
    }
  }

  @Test func originalBountyHunterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH108"))
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == "Skeet" && ship.name == "Besra")
    #expect(old.model == "ROC-SH108" && ship.model == "L337-SH108")
    #expect(ship.game == definition.nativePerformance)
    #expect(ship.game?.cargo == 20 && ship.game?.speed == 49.3 && ship.game?.acceleration == 15.0)
    #expect(ship.game?.energy == 330 && ship.game?.shield == 270 && ship.game?.recharge == 4.26)
    #expect(ship.game?.fuel == 130 && ship.game?.jump == 9 && ship.game?.price == 258000)
    #expect(ship.game?.cargoExpansion == 10 && ship.game?.shieldRecharge == 1.9)
    #expect(ship.game?.roll == 1.26 && ship.game?.pitch == 1.11 && ship.game?.yaw == 1.03)
    #expect(ship.game?.spool == 12 && ship.game?.missiles == 5 && ship.game?.facings == 15)
    #expect(ship.game?.valid == true)
    #expect(definition.sourceSHA256 == OriginalBesraActivation.specificationSHA256)
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
      "SH031", "SH032", "SH033", "SH035", "SH061", "SH103", "SH108",
    ]
    .contains(
      other.id)
    {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH108"))
    let physical = try OriginalHullPhysicalContract.besra.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 122 && mesh.faces.count == 208)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && mesh.faceTextures.count == 208)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign && ship.design == ship.nativeDesign)
    #expect(ship.nativeDesign?.textures?.count == 3)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [22.248, 10.724, 36.09]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    let preview = try #require(ship.previewMesh)
    #expect(preview.vertices != source.vertices)
    for id in ["SH025", "SH103"] {
      let earlier = try #require(ShipCatalogue.ship(id))
      let native = try #require(earlier.nativeDesign).rawMesh
      var existing = Commander()
      existing.shipID = id
      #expect(existing.playerMesh.vertices == native.vertices)
      #expect(existing.playerMesh.faces == native.faces)
      #expect(existing.playerMesh.details == native.details)
      #expect(existing.playerMesh.materials == native.materials)
      #expect(existing.playerMesh.faceMaterials == native.faceMaterials)
      #expect(existing.playerMesh.faceTextures == native.faceTextures)
    }
  }

  @Test func bountyHunterPolicyKeepsAccessAndPlacementWithoutChangingActorAuthorityOrEarlierRoles()
    throws
  {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH108"))
    let policy = ship.catalogue
    #expect(
      policy.family == "besra" && policy.primaryRole == .bountyHunter
        && policy.primaryType == .bountyHunter)
    #expect(policy.roleWeights == [.init(role: .bountyHunter, weight: 1)])
    #expect(policy.purchasePolicy == .blueprintFabrication && policy.minimumBuildTechLevel == 8)
    #expect(!policy.isCapital && policy.capitalSubtype == nil)
    #expect(policy.access == .normal && policy.collectionMilestone == .blueprintAndFabrication)
    #expect(policy.placementStatus == .declared && policy.encounterMode == .natural)
    #expect(
      policy.galaxies == [2, 3, 4] && policy.regions == old.catalogue.regions
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
      ("SH007", .leisure, .leisure), ("SH012", .leisure, .leisure),
      ("SH018", .trader, .trader), ("SH019", .leisure, .leisure),
      ("SH027", .trader, .trader), ("SH030", .bountyHunter, .bountyHunter),
      ("SH031", .military, .military), ("SH032", .leisure, .leisure),
      ("SH033", .military, .military), ("SH035", .leisure, .leisure),
      ("SH103", .bountyHunter, .bountyHunter),
    ] {
      let earlier = try #require(ShipCatalogue.ship(id))
      #expect(earlier.catalogue.primaryRole == role && earlier.catalogue.primaryType == type)
    }
    #expect(
      OriginalFleetDefinitionData.staged.filter(\.runtimeReady).map(\.id)
        == [
          "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
          "SH031", "SH032", "SH033", "SH035", "SH061", "SH103", "SH108",
        ])
    var game = Game(executive: false)
    game.docked = false
    game.screen = .front
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    game.speed = 0
    game.bodies = []
    var npc = NPCState(
      role: .escort, origin: game.systemIdentity, destination: .init(galaxy: 1, system: 0))
    npc.hasFuelScoops = false
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
    #expect(body.physical?.npc?.hasFuelScoops == false && npc.hasFuelScoops == false)
    #expect(
      body.physical?.npc?.legal == npc.legal && body.physical?.npc?.intention == npc.intention)
    #expect(body.physical?.npc?.legalProvenance == npc.legalProvenance)
    #expect(body.physical?.npc?.cargoProvenance == npc.cargoProvenance)
    #expect(body.physical?.npc?.routeProvenance == npc.routeProvenance)
    #expect(body.physical?.npc?.resources?.energyCapacity == 330)
    #expect(body.physical?.npc?.resources?.frontCapacity == 270)
    #expect(body.physical?.npc?.resources?.fuelCapacity == 130)
  }

  @Test func originalHoldCrewWeaponLimitsAndRetainedInputValidationGrantNoFreeFittings() throws {
    let ship = try #require(ShipCatalogue.ship("SH108"))
    let performance = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 20 && number("usable_cargo_after_fit") == 20)
    #expect(number("cargo_expansion_tonnes") == 10 && number("missile_capacity") == 5)
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
      #expect(historical.fields.first { $0.key == key }?.number == 6)
      let live = try #require(fit.fields.first { $0.key == key })
      #expect(
        live.number == 1 && live.status == "original-fleet design estimate"
          && live.basis.contains("E01"))
    }
    let budget = try #require(fit.fields.first { $0.key == "equipment_capacity_units" })
    #expect(budget == historical.fields.first { $0.key == "equipment_capacity_units" })
    #expect(performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    let inventory = commander.equipmentInventory
    let people = commander.savedNativePeopleCustody
    let cargo = commander.cargo
    let equipment = commander.equipment
    commander.shipID = ship.id
    #expect(commander.standardCargoCapacity == 20 && commander.missileCapacity == 5)
    #expect(commander.fuelCapacity == 130)
    #expect(commander.cargo == cargo && commander.equipment == equipment)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 30)
    #expect(
      commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people
        && commander.cargo == cargo)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH108.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH108.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == ship.name)
    let invalid = source.replacingOccurrences(
      of: "name = \"Skeet\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH020")
    #expect(try OriginalBesraActivation.resolve(foreign) == foreign)
    #expect(!OriginalBesraActivation.supports(try #require(foreign.originalDefinition)))
  }
}
