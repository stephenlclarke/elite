import Foundation

extension Game {
  var inductionNetworkRows: [ContractBoardRow] {
    guard systemIdentity == NativeWayfarerInduction.source,
      let parent = wayfarerInductionMission?.savedWayfarerInduction,
      parent.charterAudit != nil, parent.networkCertification == nil
    else { return [] }
    let action = NativeWayfarerInductionAction.certifyNetwork
    return [
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: inductionNetworkCertificationIssues().first, wayfarerInduction: action)
    ]
  }
  func inductionNetworkCertificationIssues() -> [String] {
    guard let mission = wayfarerInductionMission, mission.outcome == .active,
      mission.suspension == nil,
      let parent = mission.savedWayfarerInduction, parent.networkCertification == nil,
      parent.charterAudit != nil, (try? NativeInductionNetworkProofs(parent: parent)) != nil,
      NativeInductionCrewLogSave.validateClaims(commander),
      NativeWayfarerInductionSave.validateClaims(commander)
    else {
      return [
        "Veil needs the actual selected charter audit and original clinic quality, cassette return, seed/key return, living crew/recorder reception and all three utility repairs."
      ]
    }
    guard !paused, docked, energy > 0, nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock,
      dock.station.system == NativeWayfarerInduction.source,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else { return ["Use Veil's actual living Avenor main-orbital receiving desk."] }
    return []
  }
  mutating func confirmInductionNetworkCertification(
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    guard inductionNetworkCertificationIssues().isEmpty,
      var mission = wayfarerInductionMission, let parent = mission.savedWayfarerInduction,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let proofs = try NativeInductionNetworkProofs(parent: parent)
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let receipt = NativeInductionNetworkCertification(
      operation: try NativeInductionNetworkCertification.identity(
        sequence: sequence, proofs: proofs, dock: dock, carrier: carrier, fit: revision, time: time,
        clock: clock), sequence: sequence, proofs: proofs, dock: dock, carrier: carrier,
      inventoryRevision: revision, physicalTime: time, flightSeconds: clock)
    let next = try parent.certifyingNetwork(receipt)
    mission.savedWayfarerInduction = next
    mission.milestones = next.milestones
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "Veil certified the actual original clinic quality, cassette owner return, seed-ark/key return, two living crew and original recorder reception, all three repaired utility handoffs and matching selected charter audit. Stage13 only; Senn's payment, accreditation and clue require a separate terminal confirmation."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify("VEIL NETWORK CERTIFIED - REVIEW SENN'S FINAL RECEIVING")
  }
  var inductionNetworkDetail: [String] {
    [
      "VEIL / ORIGINAL NETWORK CERTIFICATION",
      "Confirm checks the original intact clinic reception, serviced cassette owner return, forty seed tonnes/six crew and original key return, both living rescue crew and original recorder, all three repaired utility handoffs and the selected charter audit.",
      "Later clinic/workshop/seed service jobs cannot substitute for these original induction records. Missing or mismatched native custody, receiving, clock or acknowledgement refuses.",
      "This records stage13 once. It pays nothing and grants no accreditation or clue. Senn's final review is separate. Back/Escape records nothing.",
    ] + (contractBoard.wayfarerInductionQuote?.issues ?? [])
  }
}
