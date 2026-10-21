import Foundation

/// A route quote over the actual original catalogue, never departure, refuelling or arrival proof.
struct NativeArkRoutePlan: Sendable {
  enum Failure: Error { case unavailable }
  let ark: UUID
  let catalogueRevision: String
  let worldKeys: [String]
  let legDistancesLY: [Double]
  let driveReachLY: Double
  let initialFuelLY: Double
  var totalDistanceLY: Double { legDistancesLY.reduce(0, +) }
  var minimumAdditionalFuelLY: Double { max(0, totalDistanceLY - initialFuelLY) }

  init(source: NativeInductionArkSource) throws {
    let catalogue = Universe.originalWorlds
    guard source.valid, let drive = source.definition.drive,
      let origin = catalogue.worlds.first(where: {
        $0.galaxy == source.source.galaxy && $0.system == source.source.system
      }),
      let destination = catalogue.worlds.first(where: {
        $0.galaxy == source.destination.galaxy && $0.system == source.destination.system
      }),
      let revision = OriginalWorldCatalogue.approvedFingerprints["catalogue.json"]
    else { throw Failure.unavailable }
    let reach = min(drive.rangeLightYears, source.definition.fuel)
    let worlds = Set(catalogue.worlds.filter { $0.galaxy == origin.galaxy }.map(\.key))
    let routes = try OriginalWorldNavigation(catalogue: catalogue).alternatives(
      from: origin.key, to: destination.key, visibleWorldKeys: worlds,
      firstLegReachLY: reach, fullTankReachLY: reach)
    guard let route = routes.first(where: { $0.labels.contains(.fewestJumps) }),
      route.worldKeys.count >= 2
    else { throw Failure.unavailable }
    ark = source.actor
    catalogueRevision = revision
    worldKeys = route.worldKeys
    driveReachLY = drive.rangeLightYears
    initialFuelLY = source.definition.fuel
    legDistancesLY = try zip(worldKeys, worldKeys.dropFirst()).map {
      try catalogue.distanceLY(from: $0, to: $1)
    }
    guard matches(source: source) else { throw Failure.unavailable }
  }

  func matches(source: NativeInductionArkSource) -> Bool {
    guard source.valid, source.actor == ark,
      catalogueRevision == OriginalWorldCatalogue.approvedFingerprints["catalogue.json"],
      (2...256).contains(worldKeys.count), Set(worldKeys).count == worldKeys.count,
      legDistancesLY.count == worldKeys.count - 1,
      driveReachLY == source.definition.drive?.rangeLightYears,
      initialFuelLY == source.definition.fuel
    else { return false }
    let catalogue = Universe.originalWorlds
    guard let first = try? catalogue.world(key: worldKeys[0]),
      first.galaxy == source.source.galaxy && first.system == source.source.system,
      let last = try? catalogue.world(key: worldKeys[worldKeys.count - 1]),
      last.galaxy == source.destination.galaxy && last.system == source.destination.system
    else { return false }
    for index in legDistancesLY.indices {
      guard
        let measured = try? catalogue.distanceLY(
          from: worldKeys[index], to: worldKeys[index + 1]),
        measured == legDistancesLY[index], measured > 0, measured <= driveReachLY,
        measured <= initialFuelLY,
        (try? catalogue.world(key: worldKeys[index + 1]).galaxy) == first.galaxy
      else { return false }
    }
    return true
  }
}
