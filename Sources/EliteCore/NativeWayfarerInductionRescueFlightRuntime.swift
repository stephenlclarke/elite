import Foundation

private final class NativeRescueFlightAttempt {
  var game: Game
  init(_ game: borrowing Game) { self.game = copy game }
}

extension Game {
  /// Only the ordinary native producer can depart/admit this same launch. This requests one real hop.
  mutating func advanceInductionRescueFlight(
    from sample: NativeWormholeMotionSample?, publish: ScriptPublisher?
  ) {
    observeInductionRescueDock(from: sample)
    guard let publish, !paused, !isMissionTrial,
      let child = inductionCrewLogChild, child.suspension == nil,
      child.savedNativeCrewLog?.flight != nil
    else { return }
    let attempt = NativeRescueFlightAttempt(self)
    do {
      let changed = try attempt.game.prepareInductionRescueFlight()
      guard changed || inductionRescueDockPublicationPending else { return }
      attempt.game.inductionRescueDockPublicationPending = false
      attempt.game.persistScriptActors()
      guard attempt.game.commander.valid else { throw SaveError.invalidCommander }
      try publish(&attempt.game)
      self = attempt.game
    } catch { return }
  }

  private mutating func prepareInductionRescueFlight() throws -> Bool {
    guard var child = inductionCrewLogChild, var state = child.savedNativeCrewLog,
      var flight = state.flight, child.revision < UInt64(Int64.max) - 1,
      let actor = child.ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["launch"]
    else { return false }
    if !state.losses.contains(where: { $0.role == "launch" }),
      actor.presence == .destroyed, actor.body.energy == 0,
      let native = actor.body.physical?.identity
    {
      state.losses.append(
        .init(role: "launch", actor: native, physicalTime: commander.flightSimulation.physicalTime))
      child.savedNativeCrewLog = state
      child.revision += 1
      child.journal.append(
        "The original rescue launch was actually destroyed. Its original crew remain lost without actual supported surviving-person custody; no replacement people, receiving or payment is granted."
      )
      commander.scriptState.instances[child.id] = child
      return true
    }
    if flight.dockedContact != nil { return try serviceInductionRescue(child.id) }
    guard !docked, screen.isFlight,
      wayfarerInductionMission?.savedWayfarerInduction?.crewLogLoss == nil,
      state.livingCrew.count == 2, actor.presence == .present,
      let hop = nextInductionRescueHop(flight),
      let body = bodies.first(where: { $0.missionActorID == flight.authorization.actor }),
      body.energy > 0, body.scriptNPC?.fuel ?? 0 >= flight.authorization.route.distancesLY[hop.hop],
      currentSystem.original?.key == flight.authorization.route.worldKeys[hop.hop],
      let pack = nativeInductionCrewLogPack
    else { return false }
    _ = try requestScriptNPCTransit(
      .object([
        "op": .string("actor.transit"), "id": .string(hop.request),
        "encounter": .string(NativeInductionCrewLogPack.encounter), "actor": .string("launch"),
        "destination": .string(flight.authorization.route.worldKeys[hop.hop + 1]),
      ]), pack: pack, state: child)
    flight.legs.append(hop)
    state.flight = flight
    child.savedNativeCrewLog = state
    child.revision += 1
    commander.scriptState.instances[child.id] = child
    return true
  }

  func nextInductionRescueHop(_ flight: NativeRescueFlightState) -> NativeRescueHopReference? {
    let hop: Int
    let attempt: Int
    if let previous = flight.legs.last,
      let leg = commander.scriptState.wormholeTransit?.legs[previous.leg]
    {
      if leg.phase == .arrived {
        hop = previous.hop + 1
        attempt = 0
      } else if leg.phase == .cancelled {
        hop = previous.hop
        attempt = previous.attempt + 1
      } else {
        return nil
      }
    } else if flight.legs.isEmpty {
      hop = 0
      attempt = 0
    } else {
      return nil
    }
    guard flight.authorization.route.distancesLY.indices.contains(hop), attempt < 128 else {
      return nil
    }
    let request = "native-rescue-hop-\(hop)-\(attempt)"
    return .init(
      hop: hop, attempt: attempt,
      leg: NativeWormholeLeg.identity(
        instance: flight.authorization.job, actor: flight.authorization.actor, request: request))
  }
}
