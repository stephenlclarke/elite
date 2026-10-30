import Foundation
import Testing

@testable import L337Core

@Suite struct SalvageSitesTests {
  @Test func inventoryIsSeededSparseAndIndependentOfPhysicalVisit() throws {
    let anchors = ecologyContext().anchors
    var empty = 0
    var occupied = 0
    var kinds: Set<SalvageSiteKind> = []
    for seed in 1...100 {
      let sites = SalvageSites.generate(anchors: anchors, seed: UInt64(seed))
      #expect(sites == SalvageSites.generate(anchors: anchors, seed: UInt64(seed)))
      #expect(sites.count <= 2)
      if sites.isEmpty { empty += 1 } else { occupied += 1 }
      for site in sites {
        kinds.insert(site.kind)
        #expect(site.identity.system == anchors.system && site.ownership == .abandoned)
        #expect(
          SalvageCatalogue.eligibility(
            catalogueShipID: site.catalogueShipID, ownership: site.ownership) == .allowed)
        #expect(site.metadata?.wreck == site.identity && site.metadata?.category == .wreck)
        let encoded = try JSONEncoder().encode(site)
        #expect(try JSONDecoder().decode(SalvageSite.self, from: encoded) == site)
      }
    }
    #expect(empty > 20 && occupied > 20)
    #expect(kinds == [.deepSpace, .battleSite, .miningRegion])
    let station = anchors.station
    let anotherVisit = StationAnchor(
      identity: .init(system: anchors.system, visit: 99, entity: 400),
      position: station.position, orientation: station.orientation,
      exitPosition: station.exitPosition, exitDirection: station.exitDirection)
    let revisited = SystemAnchors(
      system: anchors.system, station: anotherVisit, arrival: anchors.arrival,
      planet: anchors.planet, sun: anchors.sun)
    #expect(
      SalvageSites.generate(anchors: anchors, seed: 12)
        == SalvageSites.generate(anchors: revisited, seed: 12))
  }

  @Test func sitesClearFullSweptHullAndBoundDriftAndRotation() throws {
    let anchors = ecologyContext().anchors
    for seed in 1...100 {
      let sites = SalvageSites.generate(anchors: anchors, seed: UInt64(seed))
      for site in sites {
        let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
        let radius = profile.bounds.radius + profile.bounds.center.length
        #expect((site.position - anchors.station.position).length > 1200 + radius)
        #expect((site.position - anchors.arrival).length > 1500 + radius)
        #expect(
          (site.position - anchors.planet.position).length > anchors.planet.radius * 3 + radius)
        #expect((site.position - anchors.sun.position).length > anchors.sun.radius * 4 + radius)
        #expect(site.velocity.length >= 2 - 1e-8 && site.velocity.length <= 8 + 1e-8)
        #expect(site.angularVelocity.length > 0 && site.angularVelocity.length <= 0.02 + 1e-8)
        #expect(site.angularVelocity.length * radius <= 8 + 1e-8)
        #expect(abs(site.orientation.x.length - 1) < 1e-8)
        #expect(abs(site.orientation.y.length - 1) < 1e-8)
        #expect(abs(site.orientation.z.length - 1) < 1e-8)
      }
      #expect(Set(sites.map(\.identity)).count == sites.count)
    }
  }
}
