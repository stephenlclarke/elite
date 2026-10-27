import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalEagleCruiserUnitTests {
  private func retained(_ id: String = "SH043") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactMetreContractRejectsForeignUnitsPathsAndFingerprints() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH043"))
    let model = try OriginalFleetShowroomModels.model(for: "SH043")
    let physical = try OriginalHullPhysicalContract.eagleCruiser.get()
    #expect(OriginalEagleCruiserActivation.supports(definition))
    #expect(physical.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(physical.envelope.minimum == .init(-29, -17.5, -62))
    #expect(physical.envelope.maximum == .init(29, 16.41, 50))
    #expect(physical.nativeTriangles == 248)
    for (id, units, path, hash) in [
      ("SH029", "metres", model.sourcePath, model.sourceSHA256),
      ("SH043", "centimetres", model.sourcePath, model.sourceSHA256),
      ("SH043", "", model.sourcePath, model.sourceSHA256),
      ("SH043", "metres", "other.toml", model.sourceSHA256),
      ("SH043", "metres", model.sourcePath, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetShowroomModel(
        id: id, sourcePath: path, sourceSHA256: hash,
        coordinateUnits: units.isEmpty ? nil : units, nativeDesign: model.nativeDesign)
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: changed)
      }
    }
    for (role, policy, flyable, hash) in [
      ("trader", "never", true, definition.sourceSHA256),
      ("military", "blueprintFabrication", true, definition.sourceSHA256),
      ("military", "never", false, definition.sourceSHA256),
      ("military", "never", true, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetDefinition(
        id: definition.id, name: definition.name, family: definition.family, role: role,
        playerFlyable: flyable, purchasePolicy: policy, authored: definition.authored,
        sourcePath: definition.sourcePath, sourceSHA256: hash,
        nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: definition.approvedMeshAvailable,
        integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalEagleCruiserActivation.supports(changed))
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(
          retained(), definition: changed, physical: physical)
      }
      if hash != definition.sourceSHA256 {
        #expect(throws: (any Error).self) {
          try OriginalHullPhysicalContract(definition: changed, model: model)
        }
      }
    }
    let foreign = try #require(OriginalFleetDefinitionData.definition(for: "SH029"))
    #expect(!OriginalEagleCruiserActivation.supports(foreign))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(definition: foreign, model: model)
    }
  }

  @Test func originalCapitalMechanicsPreserveAllHistoricalFieldsAndOtherHullBindings() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH043"))
    let definition = try #require(ship.originalDefinition)
    #expect(old.name == "Farragut-class Battle Cruiser" && ship.name == "Eagle Cruiser")
    #expect(ship.game == definition.nativePerformance)
    let p = try #require(ship.game)
    #expect(p.cargo == 172 && p.cargoExpansion == 70 && p.speed == 22.8 && p.acceleration == 5.2)
    #expect(p.energy == 1490 && p.shield == 600 && p.recharge == 9.72 && p.shieldRecharge == 2)
    #expect(p.fuel == 140 && p.jump == 7 && p.spool == 18 && p.missiles == 10)
    #expect(p.price == 0 && !p.valid && p.valid(purchasePolicy: .never))
    #expect(!p.valid(purchasePolicy: .blueprintFabrication))
    for profile in old.profiles {
      let preserved = try #require(ship.profiles.first { $0.id == profile.id })
      #expect(preserved.fields == profile.fields)
      #expect(
        preserved.group
          == (profile.group == "project-refit-v1"
            ? "historical-project-refit-v1" : profile.group))
    }
    for other in ShipCatalogue.all
    where ![
      "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
      "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
      "SH046",
      "SH047", "SH054", "SH055", "SH056", "SH057", "SH059", "SH061", "SH062", "SH064", "SH065",
      "SH068",
      "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079", "SH080", "SH081", "SH083",
      "SH084", "SH085", "SH091", "SH093", "SH101",
    ].contains(other.id) {
      #expect(other == (try retained(other.id)))
    }
  }

  @Test func everyPhysicalPlayerVertexAndAppearanceAssignmentKeepsAuthoredMetres() throws {
    let physical = try OriginalHullPhysicalContract.eagleCruiser.get()
    let source = physical.model.displayMesh
    let ship = try #require(ShipCatalogue.ship("SH043"))
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 148 && mesh.faces.count == 248)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.details == source.details && mesh.faceMaterials == source.faceMaterials)
      #expect(mesh.faceTextures == source.faceTextures && mesh.faceTextures.count == 248)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.design == physical.model.nativeDesign && ship.nativeDesign == ship.design)
    let dimensions = try #require(ship.dimensions)
    for (actual, expected) in zip(dimensions, [58.0, 33.91, 112]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(dimensions.count == 3 && ship.physicalSourceContract?.id == ship.id)
    #expect(ship.previewMesh?.vertices != source.vertices)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
  }

  @Test func standardFitRetainsCrewEstimateAndActualHoldMountAndTankLimitsWithoutGrants() throws {
    let ship = try #require(ShipCatalogue.ship("SH043"))
    let p = try #require(ship.game)
    let fit = try #require(ship.profiles.first { $0.group == "project-refit-v1" })
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 172 && number("usable_cargo_after_fit") == 172)
    #expect(number("cargo_expansion_tonnes") == 70 && number("missile_capacity") == 10)
    #expect(number("required_crew_including_commander") == 52)
    #expect(number("reserved_crew_accommodation") == 52)
    #expect(!fit.context.contains("one-commander"))
    #expect(number("laser_facing_mask") == 15 && p.workTools == nil)
    #expect(LaserMount.allCases.allSatisfy(p.supports))
    #expect(ship.catalogue.validEffectiveCargo(performance: p, profiles: ship.profiles))
    var commander = Commander()
    commander.shipID = ship.id
    let people = commander.savedNativePeopleCustody
    let inventory = commander.equipmentInventory
    #expect(commander.standardCargoCapacity == 172 && commander.missileCapacity == 10)
    #expect(commander.fuelCapacity == 140)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 242)
    #expect(
      commander.savedNativePeopleCustody == people && commander.equipmentInventory == inventory)
  }

  @Test func neverPurchaseCapitalRefusesActualExchangeDespitePositiveTradeInBalance() throws {
    let ship = try #require(ShipCatalogue.ship("SH043"))
    #expect(ship.catalogue.primaryRole == .military && ship.catalogue.isCapital)
    #expect(ship.catalogue.capitalSubtype == .vessel && !ship.catalogue.normalPurchaseEligible)
    #expect(ship.catalogue.purchasePolicy == .never && ship.catalogue.minimumBuildTechLevel == nil)
    #expect(
      ship.catalogue.collectionMilestone == .destruction && ship.availability == "Not for sale")
    var game = Game(executive: false)
    game.screen = .showroom
    game.showroom.selection = ship.id
    game.showroom.trading = true
    game.showroom.confirmTrade = true
    game.commander.credits = 1_000_000
    let before = game.commander
    let quote = try #require(game.shipTradeQuote)
    #expect(quote.selected.id == ship.id && quote.purchase == 0 && !quote.allowed)
    #expect(quote.net < 0 && quote.balance > before.credits)
    #expect(quote.issues.contains("This hull is unpriced and not for sale."))
    game.confirmShipTrade()
    #expect(game.commander == before && game.commander.shipID != ship.id)
  }

  @Test func catalogueStockAuthenticatesUnpricedCapitalWithoutWeakeningPerformanceOnlyGuard() throws
  {
    let ship = try #require(ShipCatalogue.ship("SH043"))
    let performance = try #require(ship.game)
    #expect(NPCResources.stock(performance) == nil)
    let stock = try #require(NPCResources.stock(for: ship))
    #expect(stock.valid && stock.profile == .nativeHull)
    #expect(stock.energyCapacity == 1490 && stock.energyRecharge == 9.72)
    #expect(stock.frontCapacity == 600 && stock.rearCapacity == 600)
    #expect(stock.frontShield == 600 && stock.rearShield == 600 && stock.shieldRecharge == 2)
    #expect(stock.fuel == 140 && stock.fuelCapacity == 140)
    #expect(stock.laserHeat == 0 && stock.heatCapacity == 240 && stock.heatCooling == 12)
    let ordinary = try #require(ShipCatalogue.ship("SH029"))
    #expect(NPCResources.stock(for: ordinary) == NPCResources.stock(try #require(ordinary.game)))
    let fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
    for (group, field, value) in [
      ("game", "energy", 0 as Any), ("game", "price", -1 as Any),
      ("catalogue", "purchasePolicy", "blueprintFabrication" as Any),
      ("catalogue", "isCapital", false as Any),
    ] {
      var changed = fields
      var values = try #require(changed[group] as? [String: Any])
      values[field] = value
      changed[group] = values
      let invalid = try JSONDecoder().decode(
        CatalogueShip.self, from: JSONSerialization.data(withJSONObject: changed))
      #expect(NPCResources.stock(for: invalid) == nil)
    }
  }

  @Test func actualAdmissionStocksCapitalAndPreservesSpentMissionAndNativeFallbackPolicies() throws
  {
    let ship = try #require(ShipCatalogue.ship("SH043"))
    let stock = try #require(NPCResources.stock(for: ship))
    let native = try #require(ShipCatalogue.nativeShip(.cobra))
    let nativeGame = try #require(native.game)
    let nativeStock = try #require(NPCResources.stock(nativeGame))
    let displayOnly = try #require(ShipCatalogue.all.first { $0.game == nil })
    var spent = stock
    spent.frontShield = 12
    spent.fuel = 3
    let scenarios:
      [(
        id: String, priority: AdmissionPriority, initial: NPCResources?, energy: Double?,
        expected: NPCResources?
      )] = [
        (ship.id, .ordinary, nil, nil, stock),
        (ship.id, .ordinary, spent, 7, spent),
        (ship.id, .mission, nil, 7, nil),
        (displayOnly.id, .ordinary, nil, nil, nativeStock),
        ("missing", .ordinary, nil, nil, nativeStock),
        (ship.id, .ordinary, nil, 7, stock),
      ]
    for scenario in scenarios {
      var game = Game(executive: false)
      game.docked = false
      game.screen = .front
      game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
      game.speed = 0
      game.bodies = []
      var npc = NPCState(
        role: .police, origin: game.systemIdentity, destination: .init(galaxy: 1, system: 0))
      npc.cargoProvenance = .recorded
      npc.routeProvenance = .generated
      npc.legalProvenance = .recorded
      npc.resources = scenario.initial
      var request = SpawnRequest(
        identity: .init(
          system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
          sequence: 2, member: 0), population: .police, hull: .cobra,
        position: game.commander.flightSimulation.pose.systemPoint(.init(1000, 0, 1000)),
        orientation: Basis3(), velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil,
        priority: scenario.priority)
      request.catalogueShipID = scenario.id
      request.energy = scenario.energy
      let plan = EncounterPlan(
        system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
        revision: game.gameplayRevision, batches: [.init(requests: [request], atomic: false)],
        intents: [])
      let receipt = try #require(game.admitEncounterPlan(plan).first)
      #expect(receipt.refusal == nil && receipt.actor != nil)
      let body = try #require(game.bodies.first)
      #expect(body.physical?.npc?.resources == scenario.expected)
      #expect(body.energy == (scenario.energy ?? scenario.expected?.energyCapacity))
      #expect(body.physical?.catalogueShipID == request.catalogueShipID)
      let before = game.bodies
      #expect(game.admitEncounterPlan(plan).first?.actor == receipt.actor)
      #expect(game.bodies == before)
    }
  }

  private func proof(_ ship: String, owner: UUID, time: Double, playerKill: Bool = true)
    -> FleetDiscoveryEvidence
  {
    let system = SystemIdentity(galaxy: 0, system: 7)
    let player = ActorIdentity(system: system, visit: 2, entity: 0)
    let actor = ActorIdentity(system: system, visit: 2, entity: 2)
    return .init(
      owner: owner, ship: ship, kind: .playerDestruction, actor: actor, player: player,
      physicalTime: time,
      death: .init(
        victim: actor, owner: playerKill ? player : .init(system: system, visit: 2, entity: 3),
        lawful: true, bountyTenths: 0), mainDock: nil, secondaryDock: nil)
  }

  @Test func capitalDestructionRecordsOnlyItsMilestoneAndKeepsOtherBlueprintsIndependent() throws {
    let owner = UUID()
    var discovery = NativeFleetDiscovery(owner: owner)
    try discovery.record(proof("SH029", owner: owner, time: 10))
    #expect(discovery.entries["SH029"]?.blueprintEarned == true)
    let before = discovery
    #expect(throws: (any Error).self) {
      try discovery.record(proof("SH043", owner: owner, time: 11, playerKill: false))
    }
    #expect(discovery == before)
    try discovery.record(proof("SH043", owner: owner, time: 12))
    #expect(discovery.valid && discovery.entries["SH043"]?.blueprintEarned == false)
    #expect(discovery.entries["SH043"]?.milestone?.kind == .playerDestruction)
    #expect(discovery.entries["SH043"]?.status == "Collection milestone recorded")
    #expect(discovery.entries["SH029"] == before.entries["SH029"])
    let recorded = discovery
    try discovery.record(proof("SH043", owner: owner, time: 13))
    #expect(discovery == recorded)
  }

  @Test func invalidRetainedCapitalPolicyAndMalformedCatalogueCannotBeSilentlyActivated() throws {
    let old = try retained()
    let definition = try #require(old.originalDefinition)
    let physical = try OriginalHullPhysicalContract.eagleCruiser.get()
    let fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
    for (field, value) in [
      ("isCapital", false as Any), ("normalPurchaseEligible", true as Any),
      ("purchasePolicy", "blueprintFabrication" as Any), ("capitalSubtype", "station" as Any),
      ("collectionMilestone", "blueprintAndFabrication" as Any),
    ] {
      var changed = fields
      var metadata = try #require(changed["catalogue"] as? [String: Any])
      metadata[field] = value
      changed["catalogue"] = metadata
      let input = try JSONDecoder().decode(
        CatalogueShip.self, from: JSONSerialization.data(withJSONObject: changed))
      #expect(throws: (any Error).self) {
        try OriginalPlayerHullActivation.resolve(input, definition: definition, physical: physical)
      }
    }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH043.toml"), encoding: .utf8)
    let file = folder.appendingPathComponent("SH043.toml")
    try source.write(to: file, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: folder).first?.name == "Eagle Cruiser")
    let malformed = source.replacingOccurrences(
      of: "name = \"Farragut-class Battle Cruiser\"", with: "name = \"\"")
    try #require(malformed != source)
    try malformed.write(to: file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: folder) }
    let foreign = try retained("SH029")
    #expect(try OriginalEagleCruiserActivation.resolve(foreign) == foreign)
  }
}
