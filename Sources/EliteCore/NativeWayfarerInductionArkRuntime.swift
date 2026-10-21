import Foundation

private final class NativeArkProgressAttempt {
  var game: Game
  init(_ game: borrowing Game) { self.game = copy game }
}

extension Game {
  /// Observe native admissions and deaths, then ask the existing wormhole producer for one hop.
  /// Writer refusal leaves the already-attained physical world intact and retries observation.
  mutating func advanceInductionArk(
    from sample: NativeWormholeMotionSample?, publish: ScriptPublisher?
  ) {
    observeInductionArkDock(from: sample)
    guard let publish, !paused, !isMissionTrial,
      let id = wayfarerInductionMission?.savedWayfarerInduction?.ark?.job,
      let child = commander.scriptState.instances[id], child.suspension == nil,
      child.savedNativeArk != nil, nativeInductionArkPack != nil
    else { return }
    let attempt = NativeArkProgressAttempt(self)
    do {
      let changed = try attempt.game.prepareInductionArkProgress(id)
      guard changed || inductionArkDockPublicationPending else { return }
      attempt.game.inductionArkDockPublicationPending = false
      attempt.game.persistScriptActors()
      guard attempt.game.commander.valid else { throw SaveError.invalidCommander }
      try publish(&attempt.game)
      self = attempt.game
    } catch { return }
  }

  private mutating func prepareInductionArkProgress(_ id: UUID) throws -> Bool {
    guard var child = commander.scriptState.instances[id], let previous = child.savedNativeArk,
      child.revision < UInt64(Int64.max) - 1,
      let group = child.ownedEncounters[NativeInductionArkPack.encounter], group.admitted,
      let retained = group.actors[NativeInductionArkPack.alias],
      retained.identity == previous.authorization.actor
    else { return false }
    if previous.dockedContact != nil { return try serviceInductionArk(id) }
    var next = previous
    if previous.admission == nil {
      let body =
        bodies.first(where: {
          $0.missionInstanceID == id && $0.missionActorID == retained.identity
        }) ?? retained.body
      guard let physical = body.physical,
        physical.identity.system == NativeWayfarerInduction.seedSource,
        physical.population == .mission, physical.npc?.role == .mission
      else { return false }
      next = next.replacing(
        admission: .init(
          actor: physical.identity, physicalTime: commander.flightSimulation.physicalTime))
    }
    if next.loss == nil && retained.presence == .destroyed && retained.body.energy == 0 {
      guard let physical = retained.body.physical else { throw SaveError.invalidCommander }
      next = next.replacing(
        loss: .init(
          actor: physical.identity, observedPhysicalTime: commander.flightSimulation.physicalTime))
      child.journal.append(
        "The original ark was physically destroyed. Its original crew and seed stock are lost; no replacement, receiving receipt or payment is created."
      )
    }
    if !docked, screen != .gameOver, next.loss == nil && next.dockedContact == nil,
      let reference = nextInductionArkHop(next), retained.presence == .present,
      let npc = bodies.first(where: { $0.missionActorID == retained.identity })?.scriptNPC,
      npc.fuel >= next.authorization.route.legDistancesLY[reference.hop],
      let pack = nativeInductionArkPack
    {
      let destination = next.authorization.route.worldKeys[reference.hop + 1]
      guard currentSystem.original?.key == next.authorization.route.worldKeys[reference.hop]
      else { return try publishInductionArkObservation(next, previous: previous, child: child) }
      _ = try requestScriptNPCTransit(
        .object([
          "op": .string("actor.transit"), "id": .string(reference.request),
          "encounter": .string(NativeInductionArkPack.encounter),
          "actor": .string(NativeInductionArkPack.alias), "destination": .string(destination),
        ]), pack: pack, state: child)
      next = next.replacing(legs: next.legs + [reference])
    }
    return try publishInductionArkObservation(next, previous: previous, child: child)
  }

  private mutating func publishInductionArkObservation(
    _ next: NativeInductionArkState, previous: NativeInductionArkState,
    child original: ScriptInstance
  ) throws -> Bool {
    guard next != previous else { return false }
    var child = original
    child.savedNativeArk = next
    child.revision += 1
    commander.scriptState.instances[child.id] = child
    return true
  }

  func nextInductionArkHop(_ state: NativeInductionArkState) -> NativeArkHopReference? {
    let hop: Int
    let attempt: Int
    if let previous = state.legs.last,
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
    } else if state.legs.isEmpty {
      hop = 0
      attempt = 0
    } else {
      return nil
    }
    guard state.authorization.route.legDistancesLY.indices.contains(hop), attempt < 128 else {
      return nil
    }
    let request = "native-ark-hop-\(hop)-\(attempt)"
    return .init(
      hop: hop, attempt: attempt,
      leg: NativeWormholeLeg.identity(
        instance: state.authorization.job, actor: state.authorization.actor, request: request))
  }
}

extension Game {
  var inductionArkStatus: String? {
    guard let link = wayfarerInductionMission?.savedWayfarerInduction?.ark,
      let child = commander.scriptState.instances[link.job], let state = child.savedNativeArk
    else { return nil }
    if state.loss != nil {
      return "Original ark destroyed; original crew and seed lost. No receiving credit."
    }
    if let contact = state.dockedContact {
      return
        "Original ark berthed at G\(contact.station.system.galaxy + 1)-S\(contact.station.system.system)"
        + (state.serviceWait.map { " / " + $0.rawValue }
          ?? " / own fuel service or cradle receiving")
    }
    if state.admission == nil {
      return "Original ark registered; depart Enlirin for native admission."
    }
    if let reference = state.legs.last,
      let leg = commander.scriptState.wormholeTransit?.legs[reference.leg]
    {
      return
        "Original ark hop \(reference.hop + 1)/\(state.authorization.route.legDistancesLY.count): \(leg.phase.rawValue)"
        + (leg.refusal.map { " / " + $0 } ?? "")
    }
    return "Original ark admitted; awaiting its own drive/fuel and an available native hop."
  }
}

extension Game {
  var hasInductionArkMotionObserver: Bool {
    guard let id = wayfarerInductionMission?.savedWayfarerInduction?.ark?.job,
      let state = commander.scriptState.instances[id]?.savedNativeArk,
      state.admission != nil, state.loss == nil, state.dockedContact == nil
    else { return false }
    return bodies.contains { $0.missionActorID == state.authorization.actor }
  }
}
