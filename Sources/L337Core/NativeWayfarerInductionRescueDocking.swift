import Foundation

extension Game {
  func inductionRescueDockGuidance(
    _ body: SpaceBody, profile: ScriptNPCDefinition,
    delta: Double
  ) -> NativeArkDockGuidance? {
    guard let child = inductionCrewLogChild, let state = child.savedNativeCrewLog,
      let flight = state.flight, state.livingCrew.count == 2, flight.dockedContact == nil,
      body.missionInstanceID == child.id, body.missionActorID == flight.authorization.actor,
      delta.isFinite, delta > 0, delta <= 0.1,
      let station = bodies.first(where: { $0.id == 0 && $0.hull == .station && $0.energy > 0 }),
      case .living = nativeOriginalMainStationDestination,
      needsInductionRescueDock(flight, body: body),
      let physical = try? OriginalHullPhysicalContract.burro.get()
    else { return nil }
    return nativeCustodianDockGuidance(
      body, profile: profile, delta: delta,
      station: station, physical: physical)
  }

  private func needsInductionRescueDock(_ flight: NativeRescueFlightState, body: SpaceBody) -> Bool
  {
    if let hop = nextInductionRescueHop(flight), let fuel = body.scriptNPC?.fuel {
      return fuel < flight.authorization.route.distancesLY[hop.hop]
    }
    guard let last = flight.legs.last,
      commander.scriptState.wormholeTransit?.legs[last.leg]?.phase == .arrived
    else { return false }
    return last.hop == flight.authorization.route.distancesLY.count - 1
      && systemIdentity == NativeInductionCrewLogSource.receiver
  }
}
