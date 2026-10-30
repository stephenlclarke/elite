import Foundation

/// Actual-catalogue route preparation. It never fills a tank, departs a ship or proves arrival.
struct NativeRescueRoutePlan: Codable, Sendable, Equatable {
  let launch: UUID
  let catalogueRevision: String
  let worldKeys: [String]
  let distancesLY: [Double]
  let routingReachLY: Double
  let driveReachLY: Double
  let tankCapacityLY: Double
  var totalDistanceLY: Double { distancesLY.reduce(0, +) }
  var fuelBeyondOneFullTankLY: Double { max(0, totalDistanceLY - tankCapacityLY) }

  init(source: NativeInductionCrewLogSource, escortReachLY: Double) throws {
    guard escortReachLY.isFinite, escortReachLY > 0, let drive = source.ship.drive,
      let revision = OriginalWorldCatalogue.approvedFingerprints["catalogue.json"]
    else { throw SaveError.invalidCommander }
    let reach = min(escortReachLY, drive.rangeLightYears, source.ship.fuel)
    let catalogue = Universe.originalWorlds
    guard let origin = catalogue.worlds.first(where: { $0.galaxy == 0 && $0.system == 211 }),
      let destination = catalogue.worlds.first(where: { $0.galaxy == 0 && $0.system == 0 })
    else { throw SaveError.invalidCommander }
    let worlds = Set(catalogue.worlds.filter { $0.galaxy == 0 }.map(\.key))
    let candidates = try OriginalWorldNavigation(catalogue: catalogue).alternatives(
      from: origin.key, to: destination.key, visibleWorldKeys: worlds,
      firstLegReachLY: reach, fullTankReachLY: reach)
    guard let route = candidates.first(where: { $0.labels.contains(.fewestJumps) }),
      route.worldKeys.count >= 2
    else { throw SaveError.invalidCommander }
    launch = source.manifest.launch
    catalogueRevision = revision
    worldKeys = route.worldKeys
    routingReachLY = reach
    driveReachLY = drive.rangeLightYears
    tankCapacityLY = source.ship.fuel
    distancesLY = try zip(worldKeys, worldKeys.dropFirst()).map {
      try catalogue.distanceLY(from: $0, to: $1)
    }
    guard matches(source: source) else { throw SaveError.invalidCommander }
  }
  func matches(source: NativeInductionCrewLogSource) -> Bool {
    guard launch == source.manifest.launch,
      catalogueRevision == OriginalWorldCatalogue.approvedFingerprints["catalogue.json"],
      (2...256).contains(worldKeys.count), Set(worldKeys).count == worldKeys.count,
      distancesLY.count == worldKeys.count - 1,
      worldKeys.first == "G01-S211", worldKeys.last == "G01-S000",
      driveReachLY == source.ship.drive?.rangeLightYears, tankCapacityLY == source.ship.fuel,
      routingReachLY.isFinite, routingReachLY > 0,
      routingReachLY <= driveReachLY, routingReachLY <= tankCapacityLY
    else { return false }
    let catalogue = Universe.originalWorlds
    for index in distancesLY.indices {
      guard
        let measured = try? catalogue.distanceLY(from: worldKeys[index], to: worldKeys[index + 1]),
        measured == distancesLY[index], measured > 0, measured <= routingReachLY,
        (try? catalogue.world(key: worldKeys[index]).galaxy) == 0,
        (try? catalogue.world(key: worldKeys[index + 1]).galaxy) == 0
      else { return false }
    }
    return true
  }
}
