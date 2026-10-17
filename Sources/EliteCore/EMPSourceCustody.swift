import Foundation

struct EMPSourceCustody: Equatable, Codable, Sendable {
  enum Kind: String, Codable, Sendable { case ordinary, police }
  let kind: Kind
  let logical: ActorIdentity
  let original: EMPStoredObject
  let traffic: NPCPersistenceSnapshot?
  let assignment: PoliceAssignment?

  var valid: Bool {
    guard original.valid, original.body.energy > 0,
      let physical = original.body.physical, let npc = physical.npc,
      physical.empSource == nil, physical.empCrewPod == nil, physical.salvage == nil,
      physical.identity.system == logical.system, physical.identity.visit >= logical.visit,
      logical.entity > 1, logical.visit > 0, npc.role != .mission
    else { return false }
    if kind == .police {
      guard npc.role == .police, physical.population == .police,
        assignment == nil || assignment?.actor == physical.identity
      else { return false }
    } else {
      guard npc.role != .police, !physical.blocksNavalEncounter, traffic != nil, assignment == nil
      else { return false }
    }
    if let traffic {
      guard traffic.valid, traffic.actor == physical.identity, traffic.npc == npc,
        traffic.hull == original.body.hull, traffic.position == original.body.position,
        traffic.energy == original.body.energy, traffic.velocity == physical.velocity,
        traffic.angularVelocity == physical.angularVelocity
      else { return false }
    }
    return true
  }
}

extension Game {
  /// Police bookkeeping is not mission immunity. Actual traffic custody is retired only when it exists.
  mutating func claimEMPSource(bodyID: Int) -> EMPSourceCustody? {
    guard let body = bodies.first(where: { $0.id == bodyID }), let physical = body.physical,
      let npc = physical.npc, let context = gameplayContext(),
      !context.protection.protectedActors.contains(physical.identity)
    else { return nil }
    if !physical.blocksNavalEncounter {
      guard !persistNPCStates().contains(bodyID) else { return nil }
    } else if npc.role != .police || physical.population != .police {
      return nil
    }
    let logical =
      commander.npcPersistence.logicalIdentity(for: physical.identity)
      ?? commander.savedEMPState?.records.first(where: {
        $0.value.isRecovered && $0.value.savedOrdinaryTerminal == nil
          && $0.value.hull.binding == physical.identity
      })?.key ?? physical.identity
    let traffic = commander.npcPersistence.snapshot(for: logical)
    let evidence = EMPSourceCustody(
      kind: npc.role == .police ? .police : .ordinary,
      logical: logical,
      original: .init(
        body: body, pose: commander.flightSimulation.pose,
        time: context.physicalTime), traffic: traffic,
      assignment: commander.stationSecurity.assignments.first(where: {
        $0.actor == physical.identity
      }))
    guard evidence.valid else { return nil }
    if traffic != nil {
      guard commander.npcPersistence.terminal(actor: physical.identity, reason: .empTransferred)
      else {
        return nil
      }
    }
    return evidence
  }
}

extension Commander {
  var empCustodyStateValid: Bool {
    guard let state = savedEMPState else { return npcPersistence.empTransfers.isEmpty }
    guard state.valid,
      npcPersistence.empTransfers.allSatisfy({ source, snapshot in
        state.records[source]?.isRecovered == false
          && state.records[source]?.activeTrafficTransfer == snapshot
      })
    else { return false }
    return state.records.values.allSatisfy { record in
      let incident = record.disableIncident
      guard record.weaponOwner == equipmentOwnerID,
        record.crewEpisodeTimelineValid(flight: flightSimulation),
        salvageLedger.empSourceIsConsistent(record),
        record.source.entity < flightSimulation.nextActor,
        record.source.visit <= flightSimulation.visit,
        incident.id < flightSimulation.nextIncident,
        incident.origin.emissionID < flightSimulation.nextEmission,
        incident.physicalTime <= flightSimulation.physicalTime,
        ([record.hull] + record.pods).allSatisfy({ object in
          guard let actor = object.body.physical?.identity else { return false }
          return actor.system == record.source.system && actor.visit > 0
            && actor.visit <= flightSimulation.visit && actor.entity > 1
            && actor.entity < flightSimulation.nextActor
            && object.physicalTime <= flightSimulation.physicalTime
        })
      else { return false }
      if record.isRecovered {
        guard record.savedRecoveredAt.map({ $0 <= flightSimulation.physicalTime }) == true,
          npcPersistence.terminalReason(for: record.source) != .empTransferred
        else { return false }
      } else if let traffic = record.activeTrafficTransfer,
        let retained = npcPersistence.snapshot(for: record.source)
      {
        return retained == traffic
          && npcPersistence.terminalReason(for: record.source) == .empTransferred
      }
      return true
    }
  }
}
