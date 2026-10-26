import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalVultureRaiderUnitTests {
  private func retained(_ id: String = "SH065") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH065"))
    let model = try OriginalFleetShowroomModels.model(for: "SH065")
    let contract = try OriginalHullPhysicalContract.vultureRaider.get()
    #expect(OriginalVultureRaiderActivation.supports(definition))
    for (role, policy, flyable, hash) in [
      ("trader", "blueprintFabrication", true, definition.sourceSHA256),
      ("military", "blueprintFabrication", true, definition.sourceSHA256),
      ("transporter", "blueprintFabrication", true, definition.sourceSHA256),
      ("pirate", "never", true, definition.sourceSHA256),
      ("pirate", "blueprintFabrication", false, definition.sourceSHA256),
      ("pirate", "blueprintFabrication", true, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetDefinition(
        id: definition.id, name: definition.name, family: definition.family, role: role,
        playerFlyable: flyable, purchasePolicy: policy, authored: definition.authored,
        sourcePath: definition.sourcePath, sourceSHA256: hash,
        nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: definition.approvedMeshAvailable,
        integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalVultureRaiderActivation.supports(changed))
      if hash != definition.sourceSHA256 {
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: changed, model: model)
        }
      }
    }
    #expect(contract.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(contract.envelope.minimum == .init(-15.552, -6.01, -19.29))
    #expect(contract.envelope.maximum == .init(15.552, 7.93, 17.4))
    #expect(contract.nativeTriangles == 368)
    #expect(contract.physicalMesh.vertices == model.displayMesh.vertices)
    func changed(
      id: String = "SH065", units: String? = "metres", path: String? = nil,
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
    for id in ["SH005", "SH006", "SH028", "SH056", "SH058"] {
      let foreign = try retained(id)
      let foreignDefinition = try #require(foreign.originalDefinition)
      #expect(
        !OriginalVultureRaiderActivation.supports(foreignDefinition)
          && !foreignDefinition.runtimeReady)
      #expect(try OriginalVultureRaiderActivation.resolve(foreign) == foreign)
      #expect(try OriginalPlayerHullActivation.resolve(foreign) == foreign)
      #expect(ShipCatalogue.ship(id) == foreign)
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(
          foreign, definition: foreignDefinition, physical: contract)
      }
    }
  }

  @Test func originalPirateMechanicsRetainAllHistoricalFieldsAndOtherHullBindings() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH065"))
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == "Imperial Eagle" && ship.name == "Vulture Raider")
    #expect(ship.game == definition.nativePerformance)
    #expect(ship.game?.cargo == 14 && ship.game?.speed == 58.3 && ship.game?.acceleration == 19.1)
    #expect(ship.game?.energy == 140 && ship.game?.shield == 140 && ship.game?.recharge == 2.7)
    #expect(ship.game?.fuel == 110 && ship.game?.jump == 8 && ship.game?.price == 213000)
    #expect(definition.sourceSHA256 == OriginalVultureRaiderActivation.specificationSHA256)
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
      "SH047", "SH054", "SH055", "SH057", "SH059", "SH061", "SH062", "SH064", "SH065", "SH068",
      "SH069", "SH070",
    ]
    .contains(
      other.id)
    {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance() throws {
    let ship = try #require(ShipCatalogue.ship("SH065"))
    let physical = try OriginalHullPhysicalContract.vultureRaider.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 208 && mesh.faces.count == 368)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && !mesh.faceTextures.isEmpty)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign && ship.design == ship.nativeDesign)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [31.104, 13.94, 36.69]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(ship.physicalSourceContract?.id == ship.id)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    #expect(ship.previewMesh?.vertices != source.vertices)
  }

  @Test func piratePolicyKeepsAccessAndPlacementWithoutChangingActorAuthorityOrEarlierRoles()
    throws
  {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH065"))
    let policy = ship.catalogue
    #expect(
      policy.family == "vulture" && policy.primaryRole == .pirate
        && policy.primaryType == .pirate)
    #expect(policy.roleWeights == [.init(role: .pirate, weight: 8)])

    #expect(old.catalogue.roleWeights.first { $0.role == .pirate }?.weight == 8)
    let sidewinder = try #require(ShipCatalogue.ship("SH107"))
    #expect(policy.encounterWeight(for: .pirate) == 800)
    #expect(
      policy.encounterWeight(for: .pirate) > sidewinder.catalogue.encounterWeight(for: .pirate))
    #expect(sidewinder.catalogue == (try retained("SH107")).catalogue)
    #expect(ShipCatalogue.ship("SH055")?.catalogue.roleWeights == [.init(role: .pirate, weight: 1)])
    let definition = try #require(ship.originalDefinition)
    let baseline = try OriginalPlayerHullActivation.resolve(
      old, definition: definition, physical: OriginalHullPhysicalContract.vultureRaider.get()
    ).catalogue
    #expect(policy.schemaVersion == baseline.schemaVersion)
    #expect(policy.family == baseline.family)
    #expect(policy.aliases == baseline.aliases)
    #expect(policy.objectKind == baseline.objectKind)
    #expect(policy.origin == baseline.origin)
    #expect(policy.primaryType == baseline.primaryType)
    #expect(policy.primaryRole == baseline.primaryRole)
    #expect(policy.access == baseline.access)
    #expect(policy.playerFlyable == baseline.playerFlyable)
    #expect(policy.normalPurchaseEligible == baseline.normalPurchaseEligible)
    #expect(policy.purchasePolicy == baseline.purchasePolicy)
    #expect(policy.minimumBuildTechLevel == baseline.minimumBuildTechLevel)
    #expect(policy.isCapital == baseline.isCapital)
    #expect(policy.capitalSubtype == baseline.capitalSubtype)
    #expect(policy.collectionMilestone == baseline.collectionMilestone)
    #expect(policy.damagePolicy == baseline.damagePolicy)
    #expect(policy.habitat == baseline.habitat)
    #expect(policy.discoveryEligible == baseline.discoveryEligible)
    #expect(policy.encounterMode == baseline.encounterMode)
    #expect(policy.mechanicsStatus == baseline.mechanicsStatus)
    #expect(policy.placementStatus == baseline.placementStatus)
    #expect(policy.rarity == baseline.rarity)
    #expect(policy.galaxies == baseline.galaxies)
    #expect(policy.regions == baseline.regions)
    #expect(policy.authoredSystems == baseline.authoredSystems)
    #expect(policy.basis == baseline.basis)

    #expect(policy.purchasePolicy == .blueprintFabrication && policy.minimumBuildTechLevel == 8)
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
      ("SH007", .leisure, .leisure), ("SH012", .leisure, .leisure), ("SH018", .trader, .trader),
      ("SH030", .bountyHunter, .bountyHunter), ("SH054", .military, .military),
      ("SH055", .pirate, .pirate), ("SH062", .transporter, .transporter),
      ("SH064", .transporter, .transporter),
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
          "SH047", "SH054", "SH055", "SH057", "SH059", "SH061", "SH062", "SH064", "SH065", "SH068",
          "SH069", "SH070",
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
    #expect(body.physical?.npc?.resources?.energyCapacity == 140)
    #expect(body.physical?.npc?.resources?.frontCapacity == 140)
    #expect(body.physical?.npc?.resources?.fuelCapacity == 110)
  }

  @Test func originalHoldCrewWeaponLimitsAndRetainedInputValidationGrantNoFreeFittings() throws {
    let ship = try #require(ShipCatalogue.ship("SH065"))
    let performance = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 14 && number("usable_cargo_after_fit") == 14)
    #expect(number("cargo_expansion_tonnes") == 5 && number("missile_capacity") == 4)
    #expect(number("laser_facing_mask") == 15 && number("hold_used_by_cabins") == 0)
    #expect(
      number("fitted_passenger_berths") == 0 && number("required_crew_including_commander") == 1)
    let accommodation = try ShipAccommodationProfile(ship: ship)
    #expect(accommodation.equipmentUnits == 11 && accommodation.operatingCrew == 1)
    #expect(accommodation.intrinsicCrewQuarters == 1 && accommodation.initialCharterBerths == 0)
    #expect(number("equipment_capacity_units") == 11 && number("reserved_crew_accommodation") == 1)
    let historical = try #require(ship.profiles.first { $0.group == "historical-project-refit-v1" })
    #expect(historical.fields.first { $0.key == "equipment_capacity_units" }?.number == 8)
    for key in ["required_crew_including_commander", "reserved_crew_accommodation"] {
      #expect(historical.fields.first { $0.key == key }?.number == 1)
      let live = try #require(fit.fields.first { $0.key == key })
      #expect(live.number == 1 && live == historical.fields.first { $0.key == key })
    }
    let budget = try #require(fit.fields.first { $0.key == "equipment_capacity_units" })
    #expect(budget.text == "11 equipment-budget units" && budget.basis.contains("E01"))
    #expect(budget.status == "original-fleet design estimate")
    #expect(performance.workTools == nil)
    for mount in LaserMount.allCases { #expect(performance.supports(mount)) }
    #expect(ship.catalogue.validEffectiveCargo(performance: performance, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = ship.id
    let inventory = commander.equipmentInventory
    let people = commander.savedNativePeopleCustody
    #expect(commander.standardCargoCapacity == 14 && commander.missileCapacity == 4)
    #expect(commander.fuelCapacity == 110)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 19)
    #expect(
      commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH065.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH065.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == ship.name)
    let invalid = source.replacingOccurrences(
      of: "name = \"Imperial Eagle\"", with: "name = \"\"")
    #expect(invalid != source)
    try invalid.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH020")
    #expect(try OriginalVultureRaiderActivation.resolve(foreign) == foreign)
    #expect(!OriginalVultureRaiderActivation.supports(try #require(foreign.originalDefinition)))
  }
}
