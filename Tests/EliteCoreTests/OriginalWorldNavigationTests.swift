import Foundation
import Testing

@testable import EliteCore

struct OriginalWorldNavigationTests {
  private func mustRefuse(_ operation: () throws -> Void) {
    do {
      try operation()
      Issue.record("Invalid original route request accepted")
    } catch {}
  }

  @Test func exactCartesianDistanceAndIdenticalAlternativesDeduplicate() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    let a = try catalogue.world(galaxy: 0, system: 0)
    let b = try catalogue.world(galaxy: 0, system: 1)
    let distance = hypot(a.xLY - b.xLY, a.yLY - b.yLY)
    let navigation = OriginalWorldNavigation(catalogue: catalogue)
    let result = try navigation.alternatives(
      from: a.key, to: b.key, visibleWorldKeys: [a.key, b.key],
      firstLegReachLY: distance + 1, fullTankReachLY: distance + 1)
    let optionalRoute = result.first
    let route = try #require(optionalRoute)
    #expect(result.count == 1 && route.labels == [.fewestJumps, .safer])
    #expect(route.worldKeys == [a.key, b.key])
    #expect(route.distanceLY == distance && route.firstLegDistanceLY == distance)
    #expect(route.arrivalHostileFractionSum == b.hostileFraction)
    #expect(!route.assumesRefuellingForLaterLegs)
  }

  @Test func actualVisibleWorldsRespectFirstFuelAndDeclaredLaterRefuelling() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    let a = try catalogue.world(galaxy: 0, system: 0)
    let points: [(world: OriginalWorldRecord, distance: Double)] = try (1..<16).map {
      let world = try catalogue.world(galaxy: 0, system: $0)
      return (world, try catalogue.distanceLY(from: a.key, to: world.key))
    }
    let optionalNear = points.min { $0.distance < $1.distance }
    let optionalFar = points.max { $0.distance < $1.distance }
    let near = try #require(optionalNear)
    let far = try #require(optionalFar)
    let laterDistance = try catalogue.distanceLY(from: near.world.key, to: far.world.key)
    #expect(near.distance > 0 && near.distance < far.distance && laterDistance > 0)
    let scope: Set<String> = [a.key, near.world.key, far.world.key]
    let navigation = OriginalWorldNavigation(catalogue: catalogue)
    let result = try navigation.alternatives(
      from: a.key, to: far.world.key, visibleWorldKeys: scope,
      firstLegReachLY: near.distance, fullTankReachLY: laterDistance)
    let optionalRoute = result.first
    let route = try #require(optionalRoute)
    #expect(route.worldKeys == [a.key, near.world.key, far.world.key])
    #expect(route.assumesRefuellingForLaterLegs)
    let unreachable = try navigation.alternatives(
      from: a.key, to: far.world.key, visibleWorldKeys: scope,
      firstLegReachLY: near.distance / 2, fullTankReachLY: laterDistance)
    #expect(unreachable.isEmpty)
    let hiddenMiddle = try navigation.alternatives(
      from: a.key, to: far.world.key, visibleWorldKeys: [a.key, far.world.key],
      firstLegReachLY: near.distance, fullTankReachLY: laterDistance)
    #expect(hiddenMiddle.isEmpty)
  }

  @Test func actualHostileFractionsChangeSafetyWhileEqualHopTiesStayStable() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    let a = try catalogue.world(galaxy: 0, system: 0)
    let points: [(world: OriginalWorldRecord, distance: Double)] = try (1..<64).map {
      let world = try catalogue.world(galaxy: 0, system: $0)
      return (world, try catalogue.distanceLY(from: a.key, to: world.key))
    }
    let optionalFar = points.max { $0.distance < $1.distance }
    let far = try #require(optionalFar)
    let eligible = points.filter { $0.distance < far.distance }.map(\.world).sorted {
      $0.system < $1.system
    }
    var pair: (OriginalWorldRecord, OriginalWorldRecord)?
    for b in eligible {
      if let c = eligible.first(where: {
        $0.system > b.system && $0.hostileFraction < b.hostileFraction
      }) {
        pair = (b, c)
        break
      }
    }
    let chosen = try #require(pair)
    let firstReach = max(
      try catalogue.distanceLY(from: a.key, to: chosen.0.key),
      try catalogue.distanceLY(from: a.key, to: chosen.1.key))
    let laterReach = max(
      try catalogue.distanceLY(from: chosen.0.key, to: far.world.key),
      try catalogue.distanceLY(from: chosen.1.key, to: far.world.key))
    let navigation = OriginalWorldNavigation(catalogue: catalogue)
    let routes = try navigation.alternatives(
      from: a.key, to: far.world.key,
      visibleWorldKeys: [a.key, chosen.0.key, chosen.1.key, far.world.key],
      firstLegReachLY: firstReach, fullTankReachLY: laterReach)
    let optionalFewest = routes.first { $0.labels.contains(.fewestJumps) }
    let optionalSafer = routes.first { $0.labels.contains(.safer) }
    let fewest = try #require(optionalFewest)
    let safer = try #require(optionalSafer)
    #expect(fewest.worldKeys == [a.key, chosen.0.key, far.world.key])
    #expect(safer.worldKeys == [a.key, chosen.1.key, far.world.key])
    #expect(safer.arrivalHostileFractionSum < fewest.arrivalHostileFractionSum)
  }

  @Test func unknownCrossGalaxyInvisibleAndInvalidReachAreExplicitErrors() throws {
    let catalogue = try OriginalWorldCatalogue.loadBundled()
    let a = try catalogue.world(galaxy: 0, system: 0)
    let b = try catalogue.world(galaxy: 0, system: 1)
    let otherGalaxy = try catalogue.world(galaxy: 1, system: 0)
    let navigation = OriginalWorldNavigation(catalogue: catalogue)
    mustRefuse {
      _ = try navigation.alternatives(
        from: a.name, to: b.key, visibleWorldKeys: [a.key, b.key],
        firstLegReachLY: 7, fullTankReachLY: 7)
    }
    mustRefuse {
      _ = try navigation.alternatives(
        from: a.key, to: otherGalaxy.key, visibleWorldKeys: [a.key, otherGalaxy.key],
        firstLegReachLY: 100, fullTankReachLY: 100)
    }
    mustRefuse {
      _ = try navigation.alternatives(
        from: a.key, to: b.key, visibleWorldKeys: [a.key],
        firstLegReachLY: 7, fullTankReachLY: 7)
    }
    for reach in [0.0, -1, Double.nan, .infinity] {
      mustRefuse {
        _ = try navigation.alternatives(
          from: a.key, to: b.key, visibleWorldKeys: [a.key, b.key],
          firstLegReachLY: reach, fullTankReachLY: 7)
      }
    }
  }
}
