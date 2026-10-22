import Foundation

extension Game {
  func inductionCapacityAllocationIssues() -> [String] {
    guard let mission = wayfarerInductionMission, mission.outcome == .active,
      mission.suspension == nil, let state = mission.savedWayfarerInduction,
      state.charterChoice != nil, state.charterCapacity == nil,
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return ["Choose one charter first; its original capacity allocation cannot be issued twice."]
    }
    guard let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationDockEvidenceIsCurrent, systemIdentity == NativeWayfarerInduction.source,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else {
      return [
        "Return to the actual living Avenor main orbital for the still-unissued original capacity allocation."
      ]
    }
    return []
  }
  mutating func confirmInductionCapacityAllocation(
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    guard inductionCapacityAllocationIssues().isEmpty,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      let choice = state.charterChoice, mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let source = try NativeInductionCapacityAllocation(
      choice: choice, dock: dock,
      carrier: carrier, revision: revision, time: commander.flightSimulation.physicalTime,
      flightSeconds: commander.scriptState.flightSeconds, sequence: sequence)
    let next = try state.allocatingCharterCapacity(.init(allocation: source))
    mission.savedWayfarerInduction = next
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "Actual Avenor rebrief issued this charter epoch's still-unissued original eighteen service-window units: six each for clinic, workshop and seed owners, with protected minimum two each. No stock reset, operator signature, booking or stage12 receipt."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify("ORIGINAL CHARTER CAPACITY RECORDED - OWNER CONSENT REMAINS SEPARATE")
  }
}
