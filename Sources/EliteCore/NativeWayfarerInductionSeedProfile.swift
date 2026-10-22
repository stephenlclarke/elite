import Foundation

/// Closed authored C08 seed terms; existing W01/seed declarations retain their own bindings.
struct NativeInductionSeedProfile: Codable, Sendable, Equatable {
  let profile: String
  let source: WayfarerColdChainSite
  let receiver: WayfarerColdChainSite
  let stockUnits: Int
  let tonnes: Int
  let maximumActive: Int
  let hazardTier: Int
  let flightAllowance: Double
  let baseRewardNative: Int
  let perLegRewardNative: Int
  static let original = Self(
    profile: "native-c08-original-seed-v1",
    source: .init(galaxy: 0, system: 162, resourceKey: "main-orbital:0:162"),
    receiver: .init(galaxy: 0, system: 91, resourceKey: "main-orbital:0:91"),
    stockUnits: 6, tonnes: 3, maximumActive: 3, hazardTier: 0, flightAllowance: 7200,
    baseRewardNative: 5100, perLegRewardNative: 950)
  var valid: Bool { self == Self.original }
  func terms(epoch: UUID, route: NativeInductionSeedRoute) throws -> NativeInductionSeedTerms {
    guard valid, route.valid else { throw SaveError.invalidCommander }
    let systems = try route.worldKeys.map { try Universe.originalWorlds.world(key: $0).system }
    let terms = NativeInductionSeedTerms(
      source: source, objective: receiver, receiver: receiver,
      batch: "c08-seed-" + epoch.uuidString.lowercased(), stockUnits: stockUnits, tonnes: tonnes,
      maximumActive: maximumActive, route: systems, hazardTier: hazardTier,
      flightAllowance: flightAllowance,
      rewardNative: baseRewardNative + perLegRewardNative * route.distancesLY.count)
    guard terms.valid else { throw SaveError.invalidCommander }
    return terms
  }
}

/// Current original-catalogue routing policy only; never departure, fuel refill or native arrival.
struct NativeInductionSeedRoute: Codable, Sendable, Equatable {
  let catalogueRevision: String
  let worldKeys: [String]
  let distancesLY: [Double]
  let firstReachLY: Double
  let fullReachLY: Double
  init(firstReachLY: Double, fullReachLY: Double) throws {
    guard firstReachLY.isFinite, firstReachLY > 0, fullReachLY.isFinite, fullReachLY > 0,
      firstReachLY <= fullReachLY,
      let revision = OriginalWorldCatalogue.approvedFingerprints["catalogue.json"]
    else { throw SaveError.invalidCommander }
    let catalogue = Universe.originalWorlds
    let visible = Set(
      catalogue.worlds.filter { $0.galaxy == 0 && (0..<256).contains($0.system) }.map(\.key))
    let candidates = try OriginalWorldNavigation(catalogue: catalogue).alternatives(
      from: "G01-S162", to: "G01-S091", visibleWorldKeys: visible,
      firstLegReachLY: firstReachLY, fullTankReachLY: fullReachLY)
    guard let route = candidates.first(where: { $0.labels.contains(.fewestJumps) }) else {
      throw SaveError.invalidCommander
    }
    catalogueRevision = revision
    worldKeys = route.worldKeys
    distancesLY = try zip(worldKeys, worldKeys.dropFirst()).map {
      try catalogue.distanceLY(from: $0, to: $1)
    }
    self.firstReachLY = firstReachLY
    self.fullReachLY = fullReachLY
    guard valid else { throw SaveError.invalidCommander }
  }
  var valid: Bool {
    guard catalogueRevision == OriginalWorldCatalogue.approvedFingerprints["catalogue.json"],
      worldKeys.first == "G01-S162", worldKeys.last == "G01-S091",
      (2...256).contains(worldKeys.count), Set(worldKeys).count == worldKeys.count,
      distancesLY.count == worldKeys.count - 1, firstReachLY.isFinite, firstReachLY > 0,
      fullReachLY.isFinite, fullReachLY >= firstReachLY
    else { return false }
    let catalogue = Universe.originalWorlds
    for index in distancesLY.indices {
      guard (try? catalogue.world(key: worldKeys[index]).galaxy) == 0,
        (try? catalogue.world(key: worldKeys[index + 1]).galaxy) == 0,
        let actual = try? catalogue.distanceLY(from: worldKeys[index], to: worldKeys[index + 1]),
        actual == distancesLY[index], actual > 0,
        actual <= (index == 0 ? firstReachLY : fullReachLY)
      else { return false }
    }
    return true
  }
}
