import Foundation

extension Game {
  func inductionUtilityReceivingIssues() -> [String] {
    guard let parent = wayfarerInductionMission, parent.outcome == .active,
      parent.suspension == nil, let leaf = parent.savedWayfarerInduction,
      leaf.rescueReception != nil, leaf.utilityReception == nil,
      let child = inductionUtilityChild, child.suspension == nil,
      let state = child.savedNativeInductionUtility, state.receiving == nil,
      state.modules.allSatisfy({
        $0.availableKits == 0 && $0.fault == $0.role.workingFault && $0.work?.repair != nil
      }),
      let group = child.ownedEncounters[NativeInductionUtilityPack.encounter], group.admitted,
      NativeInductionUtilityRole.allCases.allSatisfy({ role in
        guard let actor = group.actors[role.rawValue] else { return false }
        return [.present, .unloaded].contains(actor.presence) && actor.body.energy > 0
          && actor.body.missionActorID
            == NativeInductionUtilityPack.actor(job: child.id, role: role)
      }), NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "Repair all three original Enron handoffs with their own local kits. Lost modules, scans and admission alone cannot complete this route."
      ]
    }
    guard let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationDockEvidenceIsCurrent,
      systemIdentity == NativeInductionUtilitySource.location,
      dock.station == state.authorization.dock.station,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else {
      return [
        "Return to the actual living Enron main orbital and review the utility crew's receiving record."
      ]
    }
    return []
  }

  mutating func confirmInductionUtilityReceiving(
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    guard inductionUtilityReceivingIssues().isEmpty,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let rescue = leaf.rescueReception, var child = inductionUtilityChild,
      var state = child.savedNativeInductionUtility,
      parent.revision < UInt64(Int64.max) - 1, child.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let source = try NativeInductionUtilitySource(parent: leaf)
    let repairs = state.modules.compactMap { $0.work?.repair?.operation }
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let sequence = commander.scriptState.nextEvent + 1
    let operation = try NativeInductionUtilityReception.identity(
      authorization: state.authorization.operation, repairs: repairs, dock: dock,
      carrier: carrier, revision: revision, time: time, flightSeconds: clock, sequence: sequence)
    let receipt = NativeInductionUtilityReception(
      operation: operation, sequence: sequence, owner: source.owner, parent: parent.id,
      job: child.id, issue: source.issue, authorization: state.authorization.operation,
      rescue: rescue.operation, operatorID: source.operatorID,
      targets: NativeInductionUtilityRole.allCases.map(\.target),
      modules: state.modules.map(\.module), kits: state.modules.map(\.kit), repairs: repairs,
      dock: dock, carrier: carrier, inventoryRevision: revision, physicalTime: time,
      flightSeconds: clock)
    let next = try leaf.receivingUtilityRoute(receipt)
    state.receiving = receipt
    guard state.shapeValid(parent: next) else { throw SaveError.invalidCommander }
    parent.savedWayfarerInduction = next
    parent.milestones = next.milestones
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.journal.append(
      "Enron's living utility crew received all three original handoffs after separate actual twenty-second repairs. Each original local kit was consumed with its own repaired control. Stage10 only; no payment, equipment, clue or accreditation."
    )
    child.savedNativeInductionUtility = state
    child.milestones.insert(0)
    child.revision += 1
    child.acknowledge(sequence)
    child.journal.append(
      "Original inlet and return valves OPEN; original buffer relay CONNECTED. All three original kits spent once. Live Enron receiving recorded; modules remain crew property."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    interruptInductionUtilityWork()
    inductionUtilityWorkRuntime.contact = nil
    notify("ENRON RECEIVED ALL THREE REPAIRED HANDOFFS - STAGE10 COMPLETE")
  }
}
