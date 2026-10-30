import Foundation

struct NativeInductionWorkshopProfile: Codable, Sendable, Equatable {
  let profile: String
  let source: WayfarerRepairLoopSite
  let workshop: WayfarerRepairLoopSite
  let receiver: WayfarerRepairLoopSite
  let stockUnits: Int
  let tonnes: Int
  let maximumActive: Int
  let hazardTier: Int
  let baseRewardNative: Int
  let perLegRewardNative: Int
  static let original = Self(
    profile: "native-c08-original-workshop-v1",
    source: .init(galaxy: 0, system: 0, resourceKey: "main-orbital:0:0"),
    workshop: .init(galaxy: 0, system: 185, resourceKey: "main-orbital:0:185"),
    receiver: .init(galaxy: 0, system: 0, resourceKey: "main-orbital:0:0"),
    stockUnits: 6, tonnes: 2, maximumActive: 3, hazardTier: 0,
    baseRewardNative: 4300, perLegRewardNative: 900)
  var valid: Bool { self == Self.original }
  func reward(route: NativeInductionWorkshopRoute) throws -> Int {
    guard valid, route.valid else { throw SaveError.invalidCommander }
    return baseRewardNative + perLegRewardNative * route.distancesLY.count
  }
}

/// An immutable price itinerary. It supplies no fuel, departures, service or compulsory hops.
struct NativeInductionWorkshopRoute: Codable, Sendable, Equatable {
  let catalogueRevision: String
  let outward: [String]
  let returning: [String]
  let distancesLY: [Double]
  let firstReachLY: Double
  let fullReachLY: Double
  var worldKeys: [String] { outward + returning.dropFirst() }
  init(firstReachLY: Double, fullReachLY: Double) throws {
    guard firstReachLY.isFinite, firstReachLY > 0, fullReachLY.isFinite,
      fullReachLY >= firstReachLY,
      let revision = OriginalWorldCatalogue.approvedFingerprints["catalogue.json"]
    else { throw SaveError.invalidCommander }
    let catalogue = Universe.originalWorlds
    let visible = Set(
      catalogue.worlds.filter { $0.galaxy == 0 && (0..<256).contains($0.system) }.map(\.key))
    let navigation = OriginalWorldNavigation(catalogue: catalogue)
    let out = try navigation.alternatives(
      from: "G01-S000", to: "G01-S185", visibleWorldKeys: visible,
      firstLegReachLY: firstReachLY, fullTankReachLY: fullReachLY)
    let back = try navigation.alternatives(
      from: "G01-S185", to: "G01-S000", visibleWorldKeys: visible,
      firstLegReachLY: fullReachLY, fullTankReachLY: fullReachLY)
    guard let outward = out.first(where: { $0.labels.contains(.fewestJumps) }),
      let returning = back.first(where: { $0.labels.contains(.fewestJumps) })
    else { throw SaveError.invalidCommander }
    self.outward = outward.worldKeys
    self.returning = returning.worldKeys
    catalogueRevision = revision
    self.firstReachLY = firstReachLY
    self.fullReachLY = fullReachLY
    let keys = outward.worldKeys + returning.worldKeys.dropFirst()
    distancesLY = try zip(keys, keys.dropFirst()).map { try catalogue.distanceLY(from: $0, to: $1) }
    guard valid else { throw SaveError.invalidCommander }
  }
  var valid: Bool {
    guard catalogueRevision == OriginalWorldCatalogue.approvedFingerprints["catalogue.json"],
      outward.first == "G01-S000", outward.last == "G01-S185",
      returning.first == "G01-S185", returning.last == "G01-S000",
      [outward, returning].allSatisfy({ (2...256).contains($0.count) && Set($0).count == $0.count }
      ),
      distancesLY.count == worldKeys.count - 1,
      firstReachLY.isFinite, firstReachLY > 0, fullReachLY.isFinite, fullReachLY >= firstReachLY
    else { return false }
    let catalogue = Universe.originalWorlds
    for (index, pair) in zip(worldKeys, worldKeys.dropFirst()).enumerated() {
      guard let first = try? catalogue.world(key: pair.0),
        let second = try? catalogue.world(key: pair.1),
        first.galaxy == 0, second.galaxy == 0, (0..<256).contains(first.system),
        (0..<256).contains(second.system),
        let distance = try? catalogue.distanceLY(from: pair.0, to: pair.1),
        distancesLY[index] == distance, distance > 0,
        distance <= (index == 0 ? firstReachLY : fullReachLY)
      else { return false }
    }
    return true
  }
}
