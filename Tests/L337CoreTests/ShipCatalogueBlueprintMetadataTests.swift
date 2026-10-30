import Foundation
import Testing

@testable import L337Core

struct ShipCatalogueBlueprintMetadataTests {
  @Test func eightDisplayTypesKeepAlienSeparateFromFunctionalRoles() throws {
    #expect(ShipCatalogueType.allCases.count == 8)
    #expect(ShipCatalogueRole.allCases.count == 7)
    let expected = Set((112...125).map { String(format: "SH%03d", $0) } + ["SH171"])
    let alien = ShipCatalogue.all.filter { $0.catalogue.primaryType == .alien }
    #expect(Set(alien.map(\.id)) == expected)
    #expect(alien.allSatisfy { $0.catalogue.primaryRole == .military })
    let liberator = try #require(ShipCatalogue.ship("SH171"))
    #expect(
      liberator.catalogue.access == .xyzzyOnly && liberator.catalogue.purchasePolicy == .xyzzyOnly)
    #expect(
      liberator.catalogue.collectionMilestone == .none && !liberator.catalogue.discoveryEligible)
  }

  @Test func everyFabricationTierIsDisplayedAndHasAReachableSourceSystem() throws {
    let systems = Universe.galaxy(number: 0)
    var reachable: Set<Int> = [7]
    var pending = [7]
    while let current = pending.popLast() {
      for next in systems where !reachable.contains(next.id) {
        let distance = systems[current].distance(to: next)
        if distance > 0 && distance <= 7 {
          reachable.insert(next.id)
          pending.append(next.id)
        }
      }
    }
    for ship in ShipCatalogue.all {
      let metadata = ship.catalogue
      if metadata.purchasePolicy == .blueprintFabrication
        || metadata.purchasePolicy == .pendingFabrication
      {
        let level = try #require(metadata.minimumBuildTechLevel)
        #expect((1...15).contains(level))
        #expect(systems.contains { reachable.contains($0.id) && $0.technology + 1 >= level })
      } else {
        #expect(metadata.minimumBuildTechLevel == nil)
      }
    }
    // Source-system reachability does not prove a native docking/fabrication receipt.
    let widow = try #require(ShipCatalogue.ship("SH163"))
    #expect(
      widow.catalogue.purchasePolicy == .pendingFabrication && widow.catalogue.discoveryEligible)
    #expect(widow.game == nil && widow.catalogue.mechanicsStatus == .pending)
  }

  @Test func ionicsHabitatNeverActsAsAFabricationLicence() throws {
    for id in ["SH152", "SH153", "SH154", "SH155"] {
      let ship = try #require(ShipCatalogue.ship(id))
      let metadata = ship.catalogue
      let habitat = try #require(metadata.habitat)
      #expect(metadata.primaryType == .military && metadata.primaryRole == .military)
      #expect(habitat.governments == [7] && habitat.minimumDisplayedTechLevel == 12)
      #expect(!habitat.permits(government: 7, displayedTechLevel: 11))
      #expect(!habitat.permits(government: 6, displayedTechLevel: 15))
      #expect(habitat.permits(government: 7, displayedTechLevel: 12))
      for galaxy in metadata.galaxies {
        #expect(
          Universe.galaxy(number: galaxy).contains { $0.government == 7 && $0.technology + 1 >= 12 }
        )
      }
    }
    let redback = try #require(ShipCatalogue.ship("SH153"))
    #expect(redback.catalogue.minimumBuildTechLevel == 13)
    #expect(redback.catalogue.habitat?.permits(government: 7, displayedTechLevel: 12) == true)
    for id in ["SH157", "SH158", "SH159", "SH160", "SH161", "SH170"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(metadata.primaryRole == .military && metadata.habitat == nil)
      #expect(Set(metadata.galaxies) == Set(0..<8))
    }
  }

  @Test func reviewedCapitalsAndStationsKeepCollectionSeparateFromPurchase() throws {
    for id in ["SH043", "SH081", "SH123"] {
      let ship = try #require(ShipCatalogue.ship(id))
      #expect(
        ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .vessel
          && ship.catalogue.purchasePolicy == .never)
      #expect(!ship.catalogue.normalPurchaseEligible && ship.catalogue.discoveryEligible)
      #expect(
        ship.catalogue.collectionMilestone == .destruction
          && ship.catalogue.damagePolicy == .destructible)
      #expect(ship.game != nil && ship.catalogue.playerFlyable)
    }
    for id in ["SH028", "SH034", "SH102", "SH141", "SH156", "SH161", "SH164"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(metadata.isCapital && metadata.capitalSubtype == .station)
      #expect(metadata.purchasePolicy == .never && metadata.discoveryEligible)
      #expect(
        metadata.collectionMilestone == .docking
          && metadata.damagePolicy == .activeStationIndestructible)
      #expect(metadata.placementStatus == .pending)
    }
    // Active station policy does not turn an abandoned SH156 wreck into a live station.
    for id in ["SH005", "SH006", "SH045", "SH078", "SH079", "SH080", "SH096", "SH097", "SH155"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(!metadata.isCapital && metadata.purchasePolicy == .blueprintFabrication)
    }
    for id in ["SH040", "SH162"] {
      let metadata = try #require(ShipCatalogue.ship(id)?.catalogue)
      #expect(metadata.collectionMilestone == ShipCatalogueCollectionMilestone.none)
    }
  }
  @Test func contradictoryCapabilitiesAreRejectedWithoutGrantingKnowledge() throws {
    func changed(_ id: String, key: String, value: Any) throws -> (
      CatalogueShip, ShipCatalogueMetadata
    ) {
      let ship = try #require(ShipCatalogue.ship(id))
      let data = try JSONEncoder().encode(ship.catalogue)
      var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      object[key] = value
      let modified = try JSONDecoder().decode(
        ShipCatalogueMetadata.self,
        from: JSONSerialization.data(withJSONObject: object))
      return (ship, modified)
    }
    for (id, key, value) in [
      ("SH043", "normalPurchaseEligible", true as Any),
      ("SH028", "damagePolicy", "destructible" as Any),
      ("SH023", "minimumBuildTechLevel", 0 as Any),
      ("SH023", "minimumBuildTechLevel", 16 as Any),
      ("SH163", "collectionMilestone", "none" as Any),
    ] {
      let (ship, metadata) = try changed(id, key: key, value: value)
      #expect(
        !metadata.valid(shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat))
    }
  }

}
