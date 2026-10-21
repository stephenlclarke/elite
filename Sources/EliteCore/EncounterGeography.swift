import Foundation

public enum EncounterRegion: String, Codable, Sendable, CaseIterable {
  case stationSecurity, tradeLane, miningBand, deepSpace
}

/// Canonical system coordinates; these rules do not depend on cockpit orientation.
public enum EncounterGeography {
  public static func distanceToSegment(_ point: Vector3, from start: Vector3, to end: Vector3)
    -> Double
  {
    let segment = end - start
    let squaredLength = segment.dot(segment)
    guard squaredLength > 0 else { return (point - start).length }
    let fraction = max(0, min(1, (point - start).dot(segment) / squaredLength))
    return (point - (start + segment * fraction)).length
  }

  public static func region(at position: Vector3, anchors: SystemAnchors) -> EncounterRegion {
    if (position - anchors.station.position).length <= 1200 { return .stationSecurity }
    if distanceToSegment(position, from: anchors.arrival, to: anchors.station.position) <= 1200
      || distanceToSegment(position, from: anchors.station.position, to: anchors.planet.position)
        <= 1200
    {
      return .tradeLane
    }
    let bandStart = anchors.planet.position + (anchors.sun.position - anchors.planet.position) * 0.2
    let bandEnd = anchors.planet.position + (anchors.sun.position - anchors.planet.position) * 0.6
    if distanceToSegment(position, from: bandStart, to: bandEnd) <= 1800,
      (position - anchors.planet.position).length > anchors.planet.radius * 3,
      (position - anchors.sun.position).length > anchors.sun.radius * 4
    {
      return .miningBand
    }
    return .deepSpace
  }

  public static func piratePressure(government: Int, region: EncounterRegion) -> Double {
    let governments = [1.0, 0.85, 0.65, 0.45, 0.3, 0.2, 0.12, 0.08]
    let multiplier: Double
    switch region {
    case .stationSecurity: multiplier = 0.05
    case .tradeLane: multiplier = 1
    case .miningBand: multiplier = 0.6
    case .deepSpace: multiplier = 0.35
    }
    return governments[max(0, min(7, government))] * multiplier
  }

  static func safe(_ position: Vector3, context: EncounterContext, civilianEntry: Bool) -> Bool {
    guard position.x.isFinite, position.y.isFinite, position.z.isFinite,
      (position - context.anchors.planet.position).length > context.anchors.planet.radius * 3,
      (position - context.anchors.sun.position).length > context.anchors.sun.radius * 4,
      (position - context.player.position).length
        > (civilianEntry ? 200 : max(200, context.perceptionRadius)),
      !context.actors.contains(where: { ($0.position - position).length < 180 })
    else { return false }
    return civilianEntry || (position - context.anchors.station.position).length > 1200
  }
}
