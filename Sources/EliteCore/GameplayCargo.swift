import Foundation

extension Game {
  /// Commit manifests in destruction-event order before removing their source bodies.
  /// Refusal retains the dead body and its exact event for the next capacity retry.
  mutating func registerDestroyedCargo() -> Set<Int> {
    let eligible = bodies.indices.filter {
      bodies[$0].energy <= 0 && bodies[$0].hull.isTargetShip
        && bodies[$0].physical?.npc != nil && bodies[$0].physical?.npc?.role != .mission
    }
    guard !eligible.isEmpty else { return [] }
    for index in eligible where bodies[index].physical?.deathIncidentID == nil {
      bodies[index].physical?.deathIncidentID = commander.flightSimulation.allocateIncident()
    }
    let ordered = eligible.sorted {
      (bodies[$0].physical?.deathIncidentID ?? UInt64.max)
        < (bodies[$1].physical?.deathIncidentID ?? UInt64.max)
    }
    guard let context = gameplayContext() else { return Set(eligible.map { bodies[$0].id }) }
    var deferred = Set<Int>()
    var blocked = false
    for index in ordered {
      let body = bodies[index]
      if let identity = body.physical?.identity,
        context.protection.protectedActors.contains(identity)
      {
        continue
      }
      guard !blocked, let identity = body.physical?.identity,
        let actor = context.actors.first(where: { $0.identity == identity }),
        let event = body.physical?.deathIncidentID
      else {
        deferred.insert(body.id)
        blocked = true
        continue
      }
      let result = commander.cargoDebrisLedger.registerDeath(
        actor: actor, manifest: actor.ordinaryCargo, settlementID: event,
        physicalTime: context.physicalTime, protection: context.protection)
      if case .refused(let reason) = result, reason != .protectedSource {
        deferred.insert(body.id)
        blocked = true
        let text = "CARGO SETTLEMENT DEFERRED: " + reason.rawValue.uppercased()
        if message != text || messageTime <= 0 { notify(text) }
      }
    }
    return deferred
  }

  mutating func admitPendingCargo() {
    guard let context = gameplayContext() else { return }
    let requests = commander.cargoDebrisLedger.pendingSpawnRequests(context: context)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: false)], intents: []))
    commander.cargoDebrisLedger.acknowledge(receipts: receipts)
  }

  mutating func persistCargoPoses() {
    guard let context = gameplayContext() else { return }
    for actor in context.actors where actor.payload != nil {
      _ = commander.cargoDebrisLedger.updatePhysicalPose(
        actor: actor.identity, position: actor.position, velocity: actor.velocity,
        physicalTime: context.physicalTime)
    }
  }

  mutating func departOrdinaryCargo() {
    commander.cargoDebrisLedger.depart(system: systemIdentity)
    commander.miningLedger.depart(system: systemIdentity)
  }

  mutating func collectOrdinaryPayload(
    payload: PayloadIdentity, into cargo: inout [Int], freeTonnes: Int,
    hasScoops: Bool, approachAllowed: Bool, protection: MissionProtection
  ) -> CargoCollectionReceipt {
    switch payload {
    case .ore:
      return commander.miningLedger.collect(
        payload: payload, into: &cargo, freeTonnes: freeTonnes,
        hasScoops: hasScoops, approachAllowed: approachAllowed, protection: protection)
    case .wreck:
      return commander.cargoDebrisLedger.collect(
        payload: payload, into: &cargo, freeTonnes: freeTonnes,
        hasScoops: hasScoops, approachAllowed: approachAllowed, protection: protection)
    case .mission, .salvage:
      return .refused(.protectedPayload)
    }
  }
}
