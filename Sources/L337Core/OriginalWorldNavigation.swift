import Foundation

public enum OriginalWorldNavigationError: Error, Sendable, Equatable {
  case invalidReach
  case crossGalaxy
  case outsideVisibleScope(String)
  case excessiveScope
  case invalidDistance
}

public enum OriginalWorldRouteKind: String, Sendable, CaseIterable {
  case fewestJumps
  case safer

  public var label: String {
    switch self {
    case .fewestJumps: "Fewest jumps"
    case .safer: "Safer (hops + hostile exposure)"
    }
  }
}

public struct OriginalWorldRouteAlternative: Sendable {
  public let labels: [OriginalWorldRouteKind]
  public let galaxy: Int
  public let worldKeys: [String]
  public let distanceLY: Double
  public let firstLegDistanceLY: Double
  public let arrivalHostileFractionSum: Double
  public let assumesRefuellingForLaterLegs: Bool
  public var refuellingAssumption: String {
    "Later legs, if any, assume the supplied full-tank reach after refuelling. Station stock, payment and launch are not guaranteed."
  }
}

/// Pure original-world route input over the existing catalogue and the one shared search kernel.
/// Visibility/range policy and installing or flying a route belong to the caller.
public struct OriginalWorldNavigation: Sendable {
  private let catalogue: OriginalWorldCatalogue

  public init(catalogue: OriginalWorldCatalogue) {
    self.catalogue = catalogue
  }

  public func alternatives(
    from originKey: String, to destinationKey: String, visibleWorldKeys: Set<String>,
    firstLegReachLY: Double, fullTankReachLY: Double
  ) throws -> [OriginalWorldRouteAlternative] {
    guard firstLegReachLY.isFinite, fullTankReachLY.isFinite,
      firstLegReachLY > 0, fullTankReachLY > 0
    else { throw OriginalWorldNavigationError.invalidReach }
    guard visibleWorldKeys.count <= 256 else { throw OriginalWorldNavigationError.excessiveScope }
    let origin = try catalogue.world(key: originKey)
    let destination = try catalogue.world(key: destinationKey)
    guard origin.galaxy == destination.galaxy else {
      throw OriginalWorldNavigationError.crossGalaxy
    }
    guard visibleWorldKeys.contains(originKey) else {
      throw OriginalWorldNavigationError.outsideVisibleScope(originKey)
    }
    guard visibleWorldKeys.contains(destinationKey) else {
      throw OriginalWorldNavigationError.outsideVisibleScope(destinationKey)
    }
    let worlds = try visibleWorldKeys.map { try catalogue.world(key: $0) }.sorted {
      $0.system < $1.system
    }
    guard worlds.allSatisfy({ $0.galaxy == origin.galaxy }) else {
      throw OriginalWorldNavigationError.crossGalaxy
    }
    guard let source = worlds.firstIndex(where: { $0.key == originKey }),
      let target = worlds.firstIndex(where: { $0.key == destinationKey })
    else { throw OriginalWorldNavigationError.outsideVisibleScope(destinationKey) }
    let distances: [[Double]] = try worlds.map { a in
      try worlds.map { b in try catalogue.distanceLY(from: a.key, to: b.key) }
    }
    guard distances.allSatisfy({ $0.allSatisfy { $0.isFinite && $0 >= 0 } }) else {
      throw OriginalWorldNavigationError.invalidDistance
    }
    let maximumReach = max(firstLegReachLY, fullTankReachLY)
    let adjacency: [[Int]] = worlds.indices.map { a in
      worlds.indices.filter { b in a != b && distances[a][b] <= maximumReach }
    }
    var candidates: [(path: [Int], labels: [OriginalWorldRouteKind])] = []
    for kind in OriginalWorldRouteKind.allCases {
      let path = NavigationRouteSearch.path(adjacency: adjacency, from: source, to: target) {
        a, b, firstLeg in
        guard distances[a][b] <= (firstLeg ? firstLegReachLY : fullTankReachLY) else { return nil }
        switch kind {
        case .fewestJumps: return 1
        case .safer: return 1 + worlds[b].hostileFraction
        }
      }
      guard let path else { continue }
      if let index = candidates.firstIndex(where: { $0.path == path }) {
        candidates[index].labels.append(kind)
      } else {
        candidates.append((path, [kind]))
      }
    }
    return try candidates.map { candidate in
      let legs = Array(zip(candidate.path, candidate.path.dropFirst()))
      let distance = legs.reduce(0.0) { $0 + distances[$1.0][$1.1] }
      let exposure = candidate.path.dropFirst().reduce(0.0) { $0 + worlds[$1].hostileFraction }
      guard distance.isFinite, exposure.isFinite else {
        throw OriginalWorldNavigationError.invalidDistance
      }
      let firstDistance = legs.first.map { distances[$0.0][$0.1] } ?? 0
      return OriginalWorldRouteAlternative(
        labels: candidate.labels, galaxy: origin.galaxy,
        worldKeys: candidate.path.map { worlds[$0].key }, distanceLY: distance,
        firstLegDistanceLY: firstDistance, arrivalHostileFractionSum: exposure,
        assumesRefuellingForLaterLegs: legs.count > 1)
    }
  }
}
