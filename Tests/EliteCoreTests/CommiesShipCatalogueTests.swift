import Foundation
import Testing

@testable import EliteCore

@Suite struct CommiesShipCatalogueTests {
  @Test(arguments: ["SH168", "SH169", "SH170"])
  func selectedSourceHullsKeepDistinctIDsAndCalibratedPerformance(_ id: String) throws {
    let ship = try #require(ShipCatalogue.ship(id))
    let game = try #require(ship.game)
    #expect(game.valid && ship.refit && ship.nativeHull == nil)
    #expect(ShipCatalogue.all.filter { $0.id == id }.count == 1)
    #expect(game.fuel == 70 && game.jump == 7 && game.spool == 15)
    #expect(game.shield == 255 && game.shieldRecharge == 1 && game.facings == 1)
    #expect(game.supports(.front) && !game.supports(.rear) && !game.supports(.left))
    switch id {
    case "SH168":
      #expect(ship.name == "Convict Miner Minnow")
      #expect(game.cargo == 0 && game.cargoExpansion == 0 && game.missiles == 1)
      #expect(game.speed == 21.943 && game.acceleration == 4.5)
      #expect(game.energy == 25 && game.recharge == 0.5 && game.price == 65_000)
      #expect(game.roll == 0.5 && game.pitch == 0.5 && game.yaw == 0.5)
    case "SH169":
      #expect(ship.name == "Ray Mk I")
      #expect(game.cargo == 10 && game.cargoExpansion == 0 && game.missiles == 1)
      #expect(game.speed == 35.657 && game.acceleration == 18.75)
      #expect(game.energy == 300 && game.recharge == 1.75 && game.price == 137_000)
      #expect(game.roll == 1.4 && game.pitch == 2.1 && game.yaw == 2.1)
    default:
      #expect(ship.name == "Military Stingray (Ray Mk II)")
      #expect(game.cargo == 15 && game.cargoExpansion == 15 && game.missiles == 3)
      #expect(game.speed == 39.314 && game.acceleration == 5.625)
      #expect(game.energy == 275 && game.recharge == 3 && game.price == 153_000)
      #expect(game.roll == 1.4 && game.pitch == 2.1 && game.yaw == 2.1)
    }
  }

  @Test(arguments: ["SH168", "SH169", "SH170"])
  func selectedDATGeometryAndSourceAppearanceRemainDistinct(_ id: String) throws {
    let ship = try #require(ShipCatalogue.ship(id))
    let expected: (String, Int, Int, [Double])
    switch id {
    case "SH168": expected = ("commies_comminer.dat", 52, 100, [7.8576, 5.6, 23.41789])
    case "SH169": expected = ("commies_ray.dat", 383, 171, [43.1004, 7.3, 52.05])
    default: expected = ("commies_rayii.dat", 424, 180, [51.23331, 9.21302, 70.05798])
    }
    #expect(ship.model == "Commies2.20-" + expected.0)
    #expect(ship.design.valid && ship.design.license == "CC-BY-NC-SA-3.0")
    #expect(ship.design.vertices.count == expected.1 && ship.design.faces.count == expected.2)
    let dimensions = try #require(ship.dimensions)
    for axis in 0..<3 {
      let values = ship.design.vertices.map { $0[axis] }
      let low = try #require(values.min())
      let high = try #require(values.max())
      #expect(abs(high - low - expected.3[axis]) < 0.000_001)
      #expect(abs(dimensions[axis] - expected.3[axis]) < 0.000_001)
    }
    #expect(ship.design.sourceFaceColours?.count == expected.2)
    #expect(ship.design.sourceFaceTextures?.count == expected.2)
    #expect(ship.design.faceMaterials?.count == expected.2)
    #expect(ship.design.appearanceLicense == "MIT")
    let notice = try field(ship, profile: "COMMIES-2.20-NOTICES-" + id, key: "attribution")
    #expect(notice.text.contains("Dr. Nil") && notice.text.contains("GearsNSuch"))
    let change = try field(ship, profile: "COMMIES-2.20-NOTICES-" + id, key: "adaptation")
    #expect(change.text.contains("Z reflected") && change.text.contains("no source texture pixels"))
  }

  @Test func sourceRoleVariantsDoNotBecomePlayerStatsOrDuplicateHulls() throws {
    let minnow = try #require(ShipCatalogue.ship("SH168"))
    let ray = try #require(ShipCatalogue.ship("SH169"))
    let stingray = try #require(ShipCatalogue.ship("SH170"))
    let variants = [minnow, ray, stingray].flatMap {
      $0.profiles.filter { $0.group == "source-native-variant" }
    }
    #expect(variants.count == 13 && Set(variants.map(\.id)).count == 13)
    #expect(try field(minnow, profile: "COMMIES-2.20-comminer", key: "missiles").number == 0)
    #expect(
      try field(minnow, profile: "COMMIES-2.20-rrs_astrominer_commies", key: "hyperspace_motor")
        .number == 0)
    #expect(try field(ray, profile: "COMMIES-2.20-comminer2", key: "max_cargo").number == 16)
    #expect(try field(ray, profile: "COMMIES-2.20-comviper", key: "max_cargo").number == 4)
    #expect(try field(ray, profile: "PROJECT-PLAYER-SH169", key: "cargo_tonnes").number == 10)
    #expect(try field(stingray, profile: "COMMIES-2.20-commilray", key: "fuel").number == 160)
    #expect(stingray.game?.fuel == 70 && stingray.game?.jump == 7)
    #expect(
      try field(stingray, profile: "COMMIES-2.20-commilray", key: "forward_weapon_type").text
        == "Military Laser")
    #expect(
      try field(stingray, profile: "PROJECT-PLAYER-SH170", key: "forward_laser").text
        == "Beam Laser")
  }

  @Test func sourceBerthCrewAndEmitterFactsStayExplicitReferenceProfiles() throws {
    let ray = try #require(ShipCatalogue.ship("SH169"))
    let stingray = try #require(ShipCatalogue.ship("SH170"))
    let crew = try field(
      ray, profile: "PROJECT-PLAYER-SH169", key: "required_crew_including_commander")
    #expect(crew.number == 1 && crew.status == "estimated")
    #expect(
      try field(ray, profile: "PROJECT-CREW-SH169", key: "first_acquisition_fitted_berth_count")
        .number == 1)
    #expect(
      try field(ray, profile: "PROJECT-CREW-SH169", key: "first_acquisition_remaining_hold_tonnes")
        .number == 5)
    #expect(ray.game?.cargo == 10)
    #expect(
      try field(stingray, profile: "PROJECT-PLAYER-SH170", key: "forward_weapon_emitter_count")
        .number == 2)
    #expect(
      try field(stingray, profile: "PROJECT-PLAYER-SH170", key: "weapon_mount_mode").text
        == "multiply")
    #expect(stingray.game?.facings == 1)
    let outfit = try field(ray, profile: "PROJECT-PLAYER-SH169", key: "source_standard_equipment")
    #expect(outfit.status == "source reference / not an installed native outfit")
    #expect(outfit.text.contains("EQ_PASSENGER_BERTH"))
  }

  @Test func transporterCargoCorrectionDrivesActualHoldAndCurrentReference() throws {
    var commander = Commander()
    commander.shipID = "SH128"
    commander.missiles = 1
    commander.cargo[0] = 12
    #expect(commander.standardCargoCapacity == 12 && commander.capacity == 12)
    #expect(commander.cargoTonnes == 12 && commander.valid)
    commander.cargo[0] = 13
    #expect(commander.cargoTonnes == 13 && !commander.valid)
    let ship = commander.ship
    #expect(ship.game?.price == 65_000 && ship.game?.cargoExpansion == 0)
    for key in ["cargo_tonnes", "usable_cargo_after_fit"] {
      let cargo = try field(ship, profile: "PROJECT-PLAYER-SH128", key: key)
      #expect(cargo.number == 12)
      #expect(cargo.status == "borrowed native NPC capacity for player adaptation")
    }
    let historical = try #require(
      ship.profiles.flatMap(\.fields).first { $0.key == "player_cargo_capacity_tonnes" })
    #expect(historical.number == 0 && historical.status == "estimated - low confidence")
  }

  private func field(_ ship: CatalogueShip, profile: String, key: String) throws -> ShipSpec {
    let source = try #require(ship.profiles.first { $0.id == profile })
    return try #require(source.fields.first { $0.key == key })
  }
}
