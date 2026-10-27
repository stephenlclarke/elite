import Foundation
import TOMLDecoder
import Testing

@testable import EliteCore

struct OriginalJaguarUnitTests {
  private func retained(_ id: String = "SH081") throws -> CatalogueShip {
    try TOMLDecoder().decode(
      CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml")))
  }

  @Test func exactCapitalAuthenticationRejectsForeignDefinitionModelAndUnits() throws {
    let definition = try #require(OriginalFleetDefinitionData.definition(for: "SH081"))
    let model = try OriginalFleetShowroomModels.model(for: "SH081")
    let physical = try OriginalHullPhysicalContract.jaguar.get()
    #expect(OriginalJaguarActivation.supports(definition) && definition.runtimeReady)
    #expect(
      definition.sourceSHA256 == "5e326c8f2b7f67e55a3575a3144043de71b7a6c07e3939342a047a02c9efb82e")
    #expect(physical.metresPerSourceUnit == 1 && model.coordinateUnits == "metres")
    #expect(physical.envelope.minimum == .init(-25, -12.72, -47))
    #expect(physical.envelope.maximum == .init(25, 17.79, 47))
    #expect(physical.nativeTriangles == 432)
    for (id, units, path, hash) in [
      ("SH043", "metres", model.sourcePath, model.sourceSHA256),
      ("SH081", "centimetres", model.sourcePath, model.sourceSHA256),
      ("SH081", "", model.sourcePath, model.sourceSHA256),
      (
        "SH081", "metres", "fleet-completion-20261019/batch-02-native-lod/SH043-design.toml",
        model.sourceSHA256
      ),
      ("SH081", "metres", model.sourcePath, String(repeating: "0", count: 64)),
    ] {
      let changed = OriginalFleetShowroomModel(
        id: id, sourcePath: path, sourceSHA256: hash,
        coordinateUnits: units.isEmpty ? nil : units, nativeDesign: model.nativeDesign)
      #expect(throws: (any Error).self) {
        try OriginalHullPhysicalContract(definition: definition, model: changed)
      }
    }
    for (id, name, family, role, policy, flyable, available, hash) in [
      ("SH043", "Jaguar", "jaguar", "military", "never", true, true, definition.sourceSHA256),
      (
        "SH081", "Eagle Cruiser", "jaguar", "military", "never", true, true, definition.sourceSHA256
      ),
      ("SH081", "Jaguar", "eagle", "military", "never", true, true, definition.sourceSHA256),
      ("SH081", "Jaguar", "jaguar", "trader", "never", true, true, definition.sourceSHA256),
      (
        "SH081", "Jaguar", "jaguar", "military", "blueprintFabrication", true, true,
        definition.sourceSHA256
      ),
      ("SH081", "Jaguar", "jaguar", "military", "never", false, true, definition.sourceSHA256),
      ("SH081", "Jaguar", "jaguar", "military", "never", true, false, definition.sourceSHA256),
      (
        "SH081", "Jaguar", "jaguar", "military", "never", true, true,
        String(repeating: "0", count: 64)
      ),
    ] {
      let changed = OriginalFleetDefinition(
        id: id, name: name, family: family, role: role, playerFlyable: flyable,
        purchasePolicy: policy, authored: definition.authored, sourcePath: definition.sourcePath,
        sourceSHA256: hash, nativePerformance: definition.nativePerformance,
        approvedMeshAvailable: available, integrationBlockers: definition.integrationBlockers)
      #expect(!OriginalJaguarActivation.supports(changed))
    }
    func replacingPerformance(_ performance: ShipPerformance?) -> OriginalFleetDefinition {
      .init(
        id: definition.id, name: definition.name, family: definition.family, role: definition.role,
        playerFlyable: definition.playerFlyable, purchasePolicy: definition.purchasePolicy,
        authored: definition.authored, sourcePath: definition.sourcePath,
        sourceSHA256: definition.sourceSHA256, nativePerformance: performance,
        approvedMeshAvailable: definition.approvedMeshAvailable,
        integrationBlockers: definition.integrationBlockers)
    }
    #expect(!OriginalJaguarActivation.supports(replacingPerformance(nil)))
    let native = try #require(definition.nativePerformance)
    let fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(native)) as? [String: Any])
    for (key, value) in [("energy", 0), ("price", 1)] {
      var changed = fields
      changed[key] = value
      let performance = try JSONDecoder().decode(
        ShipPerformance.self, from: JSONSerialization.data(withJSONObject: changed))
      #expect(!OriginalJaguarActivation.supports(replacingPerformance(performance)))
    }
    let eagle = try #require(OriginalFleetDefinitionData.definition(for: "SH043"))
    #expect(
      OriginalEagleCruiserActivation.supports(eagle) && !OriginalJaguarActivation.supports(eagle))
    #expect(throws: (any Error).self) {
      try OriginalHullPhysicalContract(
        definition: definition, model: OriginalFleetShowroomModels.model(for: "SH043"))
    }
  }

  @Test func originalCapitalMechanicsPreserveFullHistoryAndOtherHullBindings() throws {
    let old = try retained()
    let ship = try #require(ShipCatalogue.ship("SH081"))
    let definition = try #require(ship.originalDefinition)
    let p = try #require(ship.game)
    #expect(old.name == "Majestic-class Interdictor" && ship.name == "Jaguar")
    #expect(p == definition.nativePerformance)
    #expect(p.cargo == 144 && p.cargoExpansion == 60 && p.speed == 23.3 && p.acceleration == 5.4)
    #expect(p.energy == 1480 && p.recharge == 11.47 && p.shield == 620 && p.shieldRecharge == 2)
    #expect(p.roll == 0.43 && p.pitch == 0.38 && p.yaw == 0.35)
    #expect(p.fuel == 140 && p.jump == 7 && p.spool == 18 && p.missiles == 10 && p.facings == 15)
    #expect(p.price == 0 && !p.valid && p.valid(purchasePolicy: .never))
    #expect(!p.valid(purchasePolicy: .blueprintFabrication) && p.workTools == nil)
    #expect(NPCResources.stock(p) == nil)
    let stock = try #require(NPCResources.stock(for: ship))
    #expect(stock.valid && stock.profile == .nativeHull)
    #expect(stock.energyCapacity == 1480 && stock.energyRecharge == 11.47)
    #expect(stock.frontCapacity == 620 && stock.rearCapacity == 620 && stock.shieldRecharge == 2)
    for profile in old.profiles {
      let preserved = try #require(ship.profiles.first { $0.id == profile.id })
      #expect(preserved.fields == profile.fields)
      #expect(
        preserved.group
          == (profile.group == "project-refit-v1" ? "historical-project-refit-v1" : profile.group))
    }
    for other in ShipCatalogue.all
    where ![
      "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
      "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
      "SH046", "SH047", "SH054", "SH055", "SH056", "SH057", "SH059", "SH061", "SH062", "SH064",
      "SH065",
      "SH068", "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079", "SH080", "SH081",
      "SH083", "SH084", "SH085",
    ].contains(other.id) {
      #expect(other == (try retained(other.id)))
    }
    let eagle = try #require(ShipCatalogue.ship("SH043"))
    #expect(eagle.name == "Eagle Cruiser" && eagle.game?.cargo == 172)
    #expect(
      eagle.physicalSourceContract?.specificationSHA256
        == OriginalEagleCruiserActivation.specificationSHA256)
    let metadata = ship.catalogue
    #expect(
      metadata.family == "jaguar" && metadata.primaryRole == .military
        && metadata.primaryType == .military)
    #expect(metadata.roleWeights == [.init(role: .military, weight: 1)])
    #expect(metadata.isCapital && metadata.capitalSubtype == .vessel && metadata.playerFlyable)
    #expect(
      metadata.purchasePolicy == .never && !metadata.normalPurchaseEligible
        && metadata.minimumBuildTechLevel == nil)
    #expect(metadata.collectionMilestone == .destruction && metadata.damagePolicy == .destructible)
    #expect(
      metadata.access == .normal && metadata.placementStatus == .declared
        && metadata.encounterMode == .natural)
    #expect(
      metadata.rarity == .rare && metadata.galaxies == [6]
        && metadata.regions == old.catalogue.regions)
    #expect(
      metadata.authoredSystems == old.catalogue.authoredSystems
        && metadata.habitat == old.catalogue.habitat)
    #expect(metadata.valid(shipID: ship.id, performance: p, nativeCombat: ship.nativeCombat))
  }

  @Test func rawPhysicalPlayerAndMilitaryCapitalSalvageKeepCompleteApprovedGeometry() throws {
    let ship = try #require(ShipCatalogue.ship("SH081"))
    let physical = try OriginalHullPhysicalContract.jaguar.get()
    let source = physical.model.displayMesh
    var commander = Commander()
    commander.shipID = ship.id
    for mesh in [commander.playerMesh, try #require(ShipCatalogue.rawMesh(ship.id))] {
      #expect(mesh.vertices == source.vertices && mesh.faces == source.faces)
      #expect(mesh.vertices.count == 254 && mesh.faces.count == 432)
      #expect(mesh.materials == source.materials && mesh.materials.count == 8)
      #expect(mesh.faceMaterials == source.faceMaterials && mesh.details == source.details)
      #expect(mesh.faceTextures == source.faceTextures && mesh.faceTextures.count == 432)
      #expect(mesh.vertices.allSatisfy { $0.length <= physical.envelope.clearanceRadius })
    }
    #expect(ship.nativeDesign == physical.model.nativeDesign && ship.design == ship.nativeDesign)
    let dimensions = try #require(ship.dimensions)
    #expect(dimensions.count == 3)
    for (actual, expected) in zip(dimensions, [50.0, 30.51, 94]) {
      #expect(abs(actual - expected) < 1e-9)
    }
    #expect(
      ship.physicalSourceContract?.id == ship.id && ship.previewMesh?.vertices != source.vertices)
    #expect(ship.sourceProfilesIncludingPhysical.last?.group == "original-physical-metres")
    let salvage = try #require(SalvageCatalogue.profile(catalogueShipID: ship.id))
    #expect(salvage.name == "Jaguar" && salvage.role == .capitalWarship)
    #expect(salvage.sourceRoles == [.militaryCapital] && salvage.physicalScale == 1)
    #expect(salvage.mesh.vertices == source.vertices && salvage.mesh.faces == source.faces)
    #expect(
      salvage.mesh.materials == source.materials
        && salvage.mesh.faceMaterials == source.faceMaterials)
    #expect(salvage.mesh.faceTextures == source.faceTextures)
    #expect(
      salvage.minimum == physical.envelope.minimum && salvage.maximum == physical.envelope.maximum)
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

  @Test func liveAccommodationAndHoldMountTankLimitsIssueNoPeopleOrFittings() throws {
    let ship = try #require(ShipCatalogue.ship("SH081"))
    let p = try #require(ship.game)
    let fits = ship.profiles.filter { $0.group == "project-refit-v1" }
    #expect(fits.count == 1)
    let fit = try #require(fits.first)
    func number(_ key: String) -> Double? { fit.fields.first { $0.key == key }?.number }
    #expect(number("cargo_tonnes") == 144 && number("usable_cargo_after_fit") == 144)
    #expect(
      number("cargo_expansion_tonnes") == 60 && number("missile_capacity") == 10
        && number("laser_facing_mask") == 15)
    #expect(
      number("equipment_capacity_units") == 37 && number("required_crew_including_commander") == 6)
    #expect(
      number("reserved_crew_accommodation") == 6 && number("initial_charter_passenger_berths") == 0)
    for key in [
      "fitted_passenger_berths", "passengers_aboard", "free_passenger_places",
      "hold_used_by_cabins",
    ] {
      #expect(number(key) == 0)
    }
    let accommodation = try ShipAccommodationProfile(ship: ship)
    #expect(accommodation.equipmentUnits == 37 && accommodation.operatingCrew == 6)
    #expect(accommodation.intrinsicCrewQuarters == 6 && accommodation.initialCharterBerths == 0)
    let historical = try #require(ship.profiles.first { $0.group == "historical-project-refit-v1" })
    #expect(historical.fields.first { $0.key == "equipment_capacity_units" }?.number == 1208)
    for key in ["required_crew_including_commander", "reserved_crew_accommodation"] {
      #expect(historical.fields.first { $0.key == key }?.number == 52)
      let live = try #require(fit.fields.first { $0.key == key })
      #expect(
        live.number == 6 && live.status == "original-fleet design estimate"
          && live.basis.contains("SH081 E01"))
    }
    let budget = try #require(fit.fields.first { $0.key == "equipment_capacity_units" })
    #expect(
      budget.text == "37 equipment-budget units"
        && budget.status == "original-fleet design estimate")
    #expect(
      budget.basis.contains("SH081 E01") && p.workTools == nil
        && LaserMount.allCases.allSatisfy(p.supports))
    #expect(ship.catalogue.validEffectiveCargo(performance: p, profiles: ship.profiles))
    var commander = Commander()
    let inventory = commander.equipmentInventory
    let people = commander.savedNativePeopleCustody
    let cargo = commander.cargo
    let equipment = commander.equipment
    commander.shipID = ship.id
    #expect(
      commander.standardCargoCapacity == 144 && commander.missileCapacity == 10
        && commander.fuelCapacity == 140)
    #expect(commander.cargo == cargo && commander.equipment == equipment)
    #expect(
      commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people)
    commander.equipment.insert("Large Cargo Bay")
    #expect(commander.standardCargoCapacity == 204 && commander.cargo == cargo)
    #expect(
      commander.equipmentInventory == inventory && commander.savedNativePeopleCustody == people)
  }

  @Test func neverPurchaseCapitalRefusesActualExchangeDespitePositiveBalance() throws {
    let ship = try #require(ShipCatalogue.ship("SH081"))
    #expect(ship.availability == "Not for sale" && ship.catalogue.purchasePolicy == .never)
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

  private func proof(_ ship: String, owner: UUID, time: Double, playerKill: Bool = true)
    -> FleetDiscoveryEvidence
  {
    let system = SystemIdentity(galaxy: 6, system: 7)
    let player = ActorIdentity(system: system, visit: 2, entity: 0)
    let actor = ActorIdentity(system: system, visit: 2, entity: 2)
    return .init(
      owner: owner, ship: ship, kind: .playerDestruction, actor: actor, player: player,
      physicalTime: time,
      death: .init(
        victim: actor, owner: playerKill ? player : .init(system: system, visit: 2, entity: 3),
        lawful: true, bountyTenths: 0),
      mainDock: nil, secondaryDock: nil)
  }

  @Test func destructionRecordsOnlyCapitalMilestoneAndKeepsBlueprintsIndependent() throws {
    let owner = UUID()
    var discovery = NativeFleetDiscovery(owner: owner)
    #expect(
      discovery.readout(for: "SH081") == ["Collection: unknown; no native encounter recorded"])
    try discovery.record(proof("SH029", owner: owner, time: 10))
    #expect(discovery.entries["SH029"]?.blueprintEarned == true)
    let before = discovery
    #expect(throws: (any Error).self) {
      try discovery.record(proof("SH081", owner: owner, time: 11, playerKill: false))
    }
    #expect(discovery == before)
    try discovery.record(proof("SH081", owner: owner, time: 12))
    #expect(discovery.valid && discovery.entries["SH081"]?.blueprintEarned == false)
    #expect(discovery.entries["SH081"]?.milestone?.kind == .playerDestruction)
    #expect(discovery.entries["SH081"]?.status == "Collection milestone recorded")
    #expect(discovery.entries["SH029"] == before.entries["SH029"])
    let recorded = discovery
    try discovery.record(proof("SH081", owner: owner, time: 13))
    #expect(discovery == recorded)
  }

  @Test func invalidCapitalPolicyAndMalformedLoaderCannotSilentlyActivate() throws {
    let old = try retained()
    let definition = try #require(old.originalDefinition)
    let physical = try OriginalHullPhysicalContract.jaguar.get()
    let fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
    for (field, value) in [
      ("isCapital", false as Any), ("normalPurchaseEligible", true as Any),
      ("purchasePolicy", "blueprintFabrication" as Any), ("capitalSubtype", "station" as Any),
      ("collectionMilestone", "blueprintAndFabrication" as Any),
      ("damagePolicy", "activeStationIndestructible" as Any),
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
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = try String(
      contentsOf: ShipCatalogue.folder.appendingPathComponent("SH081.toml"), encoding: .utf8)
    let target = directory.appendingPathComponent("SH081.toml")
    try source.write(to: target, atomically: true, encoding: .utf8)
    #expect(try ShipCatalogue.load(from: directory).first?.name == "Jaguar")
    let malformed = source.replacingOccurrences(
      of: "name = \"Majestic-class Interdictor\"", with: "name = \"\"")
    try #require(malformed != source)
    try malformed.write(to: target, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
    let foreign = try retained("SH029")
    #expect(try OriginalJaguarActivation.resolve(foreign) == foreign)
    #expect(!OriginalJaguarActivation.supports(try #require(foreign.originalDefinition)))
  }
}
