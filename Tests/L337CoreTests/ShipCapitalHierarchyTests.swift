import Foundation
import Testing

@testable import L337Core

struct ShipCapitalHierarchyTests {
  @Test func stationsAreCapitalChildrenWithoutBecomingDestructionTargets() throws {
    let stationIDs = Set(["SH028", "SH034", "SH102", "SH141", "SH156", "SH161", "SH164"])
    let capitals = ShipCatalogue.all.filter { $0.catalogue.isCapital }
    #expect(capitals.count == 10)
    #expect(
      Set(capitals.filter { $0.catalogue.capitalSubtype == .station }.map(\.id)) == stationIDs)
    #expect(
      Set(capitals.filter { $0.catalogue.capitalSubtype == .vessel }.map(\.id))
        == Set(["SH043", "SH081", "SH123"]))
    for id in stationIDs {
      let ship = try #require(ShipCatalogue.ship(id))
      let metadata = ship.catalogue
      #expect(metadata.isCapital && metadata.capitalSubtype == .station)
      #expect(metadata.objectKind == .station || metadata.objectKind == .platform)
      #expect(
        metadata.collectionMilestone == .docking
          && metadata.damagePolicy == .activeStationIndestructible)
      #expect(metadata.purchasePolicy == .never && metadata.minimumBuildTechLevel == nil)
      #expect(metadata.valid(shipID: id, performance: ship.game, nativeCombat: ship.nativeCombat))
    }
    #expect(ShipCatalogue.ship("SH156")?.catalogue.objectKind == .platform)
    #expect(ShipCatalogue.ship("SH161")?.catalogue.objectKind == .station)
  }

  @Test func hierarchyDoesNotAddDuplicateCollectionEntriesOrAnotherDisplayedType() throws {
    let ships = ShipCatalogue.all
    #expect(ships.count == 171 && Set(ships.map(\.id)).count == ships.count)
    let eligible = ships.filter { $0.catalogue.discoveryEligible }
    #expect(eligible.count == 168 && Set(eligible.map(\.id)).count == eligible.count)
    #expect(ShipCatalogueType.allCases.count == 8 && ShipCatalogueRole.allCases.count == 7)
    for ship in ships where !ship.catalogue.isCapital {
      #expect(ship.catalogue.capitalSubtype == nil)
    }
    for id in ["SH005", "SH078", "SH079", "SH155"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(!metadata.isCapital && metadata.purchasePolicy == .blueprintFabrication)
    }
    let liberator = try #require(ShipCatalogue.ship("SH171"))
    #expect(!liberator.catalogue.isCapital && liberator.catalogue.capitalSubtype == nil)
    #expect(
      liberator.catalogue.primaryType == .alien && liberator.catalogue.purchasePolicy == .xyzzyOnly)
  }

  @Test func parentCapitalNeverOverridesTheStationMilestone() throws {
    for (id, key, value) in [
      ("SH028", "isCapital", false as Any),
      ("SH028", "capitalSubtype", "vessel" as Any),
      ("SH043", "capitalSubtype", "station" as Any),
      ("SH028", "collectionMilestone", "destruction" as Any),
      ("SH028", "damagePolicy", "destructible" as Any),
    ] {
      let ship = try #require(ShipCatalogue.ship(id))
      let data = try JSONEncoder().encode(ship.catalogue)
      var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      object[key] = value
      let changed = try JSONDecoder().decode(
        ShipCatalogueMetadata.self,
        from: JSONSerialization.data(withJSONObject: object))
      #expect(!changed.valid(shipID: id, performance: ship.game, nativeCombat: ship.nativeCombat))
    }
  }
}
