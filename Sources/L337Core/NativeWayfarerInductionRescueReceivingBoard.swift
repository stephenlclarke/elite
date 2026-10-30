import Foundation

extension Game {
  func inductionRescueReceivingIssues() -> [String] {
    guard let parent = wayfarerInductionMission, parent.suspension == nil,
      parent.outcome == .active,
      let leaf = parent.savedWayfarerInduction, leaf.rescueReception == nil,
      leaf.crewLog != nil, leaf.crewLogLoss == nil,
      leaf.payloads == [NativeWayfarerInduction.crewLogPayload: 1],
      let child = inductionCrewLogChild, child.suspension == nil,
      let state = child.savedNativeCrewLog, state.rescueReception == nil,
      state.livingCrew == state.authorization.manifest.crew, state.livingCrew.count == 2,
      state.rescueFuel?.closure == nil, let flight = state.flight,
      let contact = flight.dockedContact,
      contact.station.system == NativeInductionCrewLogSource.receiver,
      NativeRescueFlightSave.allHopsReceived(flight, engine: commander.scriptState),
      let actor = child.ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["launch"],
      actor.presence == .unloaded, actor.body.energy > 0,
      actor.body.physical?.identity == contact.arkActor
    else {
      return [
        "The same original launch must complete every actual hop and berth at Enmadan with both original crew alive and the original recorder still held."
      ]
    }
    guard NativeInductionCrewLogSave.validateClaims(commander),
      NativeInductionArkSave.supplierClaimsValid(commander),
      let dock = commander.nativeStations?.currentMainDock, nativeMainStationDockEvidenceIsCurrent,
      dock.station == contact.station,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == contact.station, facility.observation.actor == dock.actor,
      leaf.crewLogCarrier == commander.hullInstanceID
    else {
      return [
        "Dock the actual original-recorder carrier at the same living Enmadan main orbital and review again."
      ]
    }
    return []
  }

  mutating func confirmInductionRescueReceiving(
    dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64
  ) throws {
    guard inductionRescueReceivingIssues().isEmpty, nativeMainStationDockEvidenceIsCurrent,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let original = leaf.crewLog, var child = inductionCrewLogChild,
      var state = child.savedNativeCrewLog, let flight = state.flight,
      let contact = flight.dockedContact, let bank = state.rescueFuel,
      parent.revision < UInt64(Int64.max) - 1, child.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let sequence = commander.scriptState.nextEvent + 1
    let operation = try NativeInductionRescueReception.identity(
      registration: state.authorization.operation, flight: flight.authorization.operation,
      capture: original.operation, launchDock: contact, playerDock: dock, carrier: carrier,
      revision: revision, physicalTime: time, flightSeconds: clock, crew: state.livingCrew)
    let receipt = NativeInductionRescueReception(
      operation: operation, sequence: sequence,
      owner: state.authorization.manifest.owner, parent: parent.id, job: child.id,
      registration: state.authorization.operation, flight: flight.authorization.operation,
      capture: original.operation, launch: state.authorization.manifest.launch,
      recorder: original.original, target: NativeInductionRescueReception.receivingTarget,
      crew: state.livingCrew, launchDock: contact, playerDock: dock, carrier: carrier,
      inventoryRevision: revision, physicalTime: time, flightSeconds: clock)
    let nextParent = try leaf.receivingOriginalRescue(receipt)
    state.rescueFuel = try bank.closing(at: receipt)
    state.rescueReception = receipt
    state.flight?.serviceWait = nil
    guard state.shapeValid(parent: nextParent) else { throw SaveError.invalidCommander }
    parent.savedWayfarerInduction = nextParent
    parent.payloads = nextParent.payloads
    parent.milestones = nextParent.milestones
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.journal.append(
      "Enmadan received the same two original living crew and their original custody recorder from the actually berthed launch/carrier. Stage9 only; no payment, clue or accreditation. Later utility-route work remains unavailable."
    )
    child.savedNativeCrewLog = state
    child.milestones.insert(1)
    child.revision += 1
    child.acknowledge(sequence)
    child.journal.append(
      "Original people and recorder received at Enmadan. The original launch remains in facility custody; unused rescue fuel escrow returned once to its Cevilis custodian, never player cash. No replacement people, recorder or launch issue."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    notify("ORIGINAL SURVIVORS RECEIVED - CUSTODY RECORDER RETURNED")
  }
}
