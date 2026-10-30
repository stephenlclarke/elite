import Foundation

/// Read-only route disclosure. This projection cannot authorize a jump or change NPC state.
enum TargetTransitRouteProjection {
  static func route(for body: SpaceBody, legs: [UUID: NativeWormholeLeg]) -> NativeWormholeRoute? {
    guard let instance = body.missionInstanceID, let actor = body.missionActorID,
      let native = body.physical?.identity,
      body.physical?.npc?.routeProvenance != .generated,
      body.physical?.npc?.routeProvenance != .recorded
    else { return nil }
    var found: NativeWormholeRoute?
    for (id, leg) in legs where leg.instance == instance && leg.actor == actor {
      guard id == leg.id,
        id == NativeWormholeLeg.identity(instance: instance, actor: actor, request: leg.request),
        let route = leg.route, route.valid,
        route.destination.worldID == leg.destinationWorld
      else { continue }
      let bound: Bool
      switch leg.phase {
      case .spooling:
        bound =
          leg.spoolActor == native && native.system == route.origin.location
          && leg.spooledAt != nil && leg.spoolPhysicalTime != nil
          && leg.driveComponent != nil && leg.driveTerms?.valid == true
          && leg.opening == nil && leg.departure == nil && leg.arrival == nil
      case .open:
        bound =
          leg.opening?.sourceActor == native && native.system == route.origin.location
          && leg.opening?.leg == id && leg.opening?.route == route
          && leg.opening?.valid == true && leg.departure == nil && leg.arrival == nil
      case .arrived:
        if let arrival = leg.arrival, let departure = leg.departure,
          let opening = leg.opening, let due = leg.dueAt
        {
          bound =
            arrival.nativeActor == native && native.system == route.destination.location
            && opening.route == route && opening.leg == id && opening.valid
            && departure.hole == opening.id && departure.nativeActor == opening.sourceActor
            && arrival.calendarSeconds.isFinite && due.isFinite && arrival.calendarSeconds >= due
        } else {
          bound = false
        }
      default:
        bound = false
      }
      guard bound else { continue }
      guard found == nil else { return nil }
      found = route
    }
    return found
  }
}
