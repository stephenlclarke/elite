import Foundation

extension Game {
  var hasUnsettledCargoDeaths: Bool {
    bodies.contains {
      $0.energy <= 0 && $0.hull.isTargetShip
        && $0.physical?.npc != nil && $0.physical?.npc?.role != .mission
    }
  }

  /// Commit manifests in destruction-event order before removing their source bodies.
  /// Refusal retains the dead body and its exact event for the next capacity retry.
  mutating func registerDestroyedCargo() -> Set<Int> {
    let eligible = bodies.indices.filter {
      bodies[$0].energy <= 0 && bodies[$0].hull.isTargetShip
        && bodies[$0].physical?.npc != nil && bodies[$0].physical?.npc?.role != .mission
    }
    guard !eligible.isEmpty else { return [] }
    return registerEligibleDestroyedCargo(eligible)
  }

  // Reserve settlement/context value storage only when the original eligibility pass found work.
  @inline(never)
  private mutating func registerEligibleDestroyedCargo(_ eligible: [Int]) -> Set<Int> {
    for index in eligible where bodies[index].physical?.deathIncidentID == nil {
      let incident = commander.flightSimulation.allocateIncident()
      bodies[index].physical?.deathIncidentID = incident
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

  /// Actor isolation makes this the current canonical snapshot, before any binding is culled.
  mutating func persistOrePoses() {
    persistAsteroidBreakupMotion()
    let pose = commander.flightSimulation.pose
    for body in bodies where body.energy > 0 {
      guard let physical = body.physical, let payload = physical.payload,
        case .ore(let rock, _) = payload, rock.system == systemIdentity,
        physical.identity.system == systemIdentity,
        physical.identity.visit == commander.flightSimulation.visit
      else { continue }
      _ = commander.miningLedger.updateOreMotion(
        payload: payload, actor: physical.identity,
        position: pose.systemPoint(body.position), velocity: physical.velocity,
        physicalTime: commander.flightSimulation.physicalTime)
    }
  }

  mutating func departOrdinarySimulation() throws {
    _ = persistNPCStates()
    _ = persistEMPState()
    persistOrePoses()
    if nativeCrimboLifecycleAvailable { try parkNativeCrimboBeforeDeparture() }
    commander.cargoDebrisLedger.depart(system: systemIdentity)
    commander.miningLedger.depart(system: systemIdentity)
    commander.npcPersistence.depart(system: systemIdentity)
    commander.resetWantedCareerBindings(system: systemIdentity)
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
