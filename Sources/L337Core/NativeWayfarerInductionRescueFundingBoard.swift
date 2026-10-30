import Foundation

extension Game {
  func inductionRescueFundingIssues() -> [String] {
    guard let parent = wayfarerInductionMission?.savedWayfarerInduction,
      parent.crewLog != nil, parent.crewLogLoss == nil,
      let child = inductionCrewLogChild, child.suspension == nil,
      let source = child.savedNativeCrewLog, source.rescueFuel == nil,
      source.rescueReserve == nil, source.livingCrew.count == 2,
      !source.losses.contains(where: { $0.role == "launch" }),
      let original = child.ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["launch"],
      original.presence != .destroyed, original.body.energy > 0,
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "The same original living rescue launch and held recorder need an unissued fuel allocation."
      ]
    }
    return []
  }

  mutating func confirmInductionRescueFunding(dock: NativeMainStationDockReceipt) throws {
    guard inductionRescueFundingIssues().isEmpty,
      nativeMainStationDockEvidenceIsCurrent, commander.nativeStations?.currentMainDock == dock,
      systemIdentity == NativeInductionCrewLogSource.location,
      dock.station.world == commander.equipmentOwnerID,
      var child = inductionCrewLogChild, var source = child.savedNativeCrewLog,
      var parent = wayfarerInductionMission,
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let funding = NativeRescueFuelFunding(
      authorization: source.authorization, sequence: sequence,
      physicalTime: commander.flightSimulation.physicalTime,
      flightSeconds: commander.scriptState.flightSeconds, legacyRebriefDock: dock)
    guard funding.valid(authorization: source.authorization) else {
      throw SaveError.invalidCommander
    }
    source.rescueFuel = try .init(funding: funding)
    source.rescueReserve = .init(authorization: source.authorization)
    guard let leaf = parent.savedWayfarerInduction, source.shapeValid(parent: leaf) else {
      throw SaveError.invalidCommander
    }
    child.savedNativeCrewLog = source
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.journal.append(
      "Cevilis's custodian confirmed the original rescue launch's still-unissued1000CR fuel escrow and one planned uncrewed Burro reserve with a separate future1000CR issue. No player cash, station fuel, hull, equipment, people, recorder or stage progress was granted."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    notify("ORIGINAL RESCUE FUEL ESCROW ISSUED - 1000 CR / NPC ONLY")
  }
}
