import Foundation

extension Game {
  var hasWayfarerAccreditation: Bool {
    guard let mission = wayfarerInductionMission, mission.outcome == .complete,
      mission.savedWayfarerInduction?.accreditation != nil,
      NativeWayfarerInductionSave.validateClaims(commander),
      NativeInductionCrewLogSave.validateClaims(commander),
      ScriptClueVersionedSave.validateClaims(commander, trust: .production)
    else { return false }
    return true
  }
  var inductionAccreditationRows: [ContractBoardRow] {
    guard systemIdentity == NativeWayfarerInduction.source,
      let parent = wayfarerInductionMission?.savedWayfarerInduction,
      parent.networkCertification != nil, parent.accreditation == nil
    else { return [] }
    let action = NativeWayfarerInductionAction.accredit
    return [
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: inductionAccreditationIssues().first, wayfarerInduction: action)
    ]
  }
  func inductionAccreditationIssues() -> [String] {
    guard let mission = wayfarerInductionMission, mission.outcome == .active,
      mission.suspension == nil,
      let parent = mission.savedWayfarerInduction, parent.networkCertification != nil,
      parent.accreditation == nil, NativeWayfarerInductionSave.validateClaims(commander),
      NativeInductionCrewLogSave.validateClaims(commander),
      ScriptClueVersionedSave.validateClaims(commander, trust: .production)
    else {
      return [
        "Senn needs Veil's actual certification and all original native receipts; completed accreditation cannot be paid again."
      ]
    }
    guard !paused, docked, energy > 0, nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock,
      dock.station.system == NativeWayfarerInduction.source,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else { return ["Use Senn's actual living Avenor main-orbital receiving desk."] }
    guard
      (0...(4_294_967_295 - NativeInductionAccreditation.rewardNative)).contains(commander.credits)
    else {
      return [
        "Receiving the full7600CR must not overflow credits; no partial payment or accreditation."
      ]
    }
    return []
  }

  /// The enclosing native Confirm candidate publishes payment, completion, clue and entitlement together.
  mutating func confirmInductionAccreditation(
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    guard inductionAccreditationIssues().isEmpty, var mission = wayfarerInductionMission,
      let parent = mission.savedWayfarerInduction, let certificate = parent.networkCertification,
      let policy = parent.charterChoice?.policy,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let previous = mission
    let cause = scriptEventContext(mission)
    let sequence = commander.scriptState.nextEvent + 1
    let publishedRevision = mission.revision + 1
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let before = commander.credits
    let after = before + NativeInductionAccreditation.rewardNative
    let entitlement = NativeInductionAccreditation.entitlement(
      parent: mission.id, owner: parent.permission.owner, certification: certificate.operation)
    let receipt = NativeInductionAccreditation(
      operation: try NativeInductionAccreditation.identity(
        sequence: sequence, revision: publishedRevision, certification: certificate.operation,
        policy: policy, entitlement: entitlement, dock: dock, carrier: carrier, fit: revision,
        time: time, clock: clock, before: before, after: after), sequence: sequence,
      publicationRevision: publishedRevision, certification: certificate.operation, policy: policy,
      entitlement: entitlement, dock: dock, carrier: carrier, inventoryRevision: revision,
      physicalTime: time, flightSeconds: clock, creditsBefore: before, creditsAfter: after)
    let next = try parent.accrediting(receipt)
    mission.savedWayfarerInduction = next
    mission.outcome = .complete
    mission.milestones = next.milestones
    mission.revision = publishedRevision
    mission.acknowledge(sequence)
    mission.journal.append(
      "Senn received the certified original network, paid7600CR once and accredited this commander under the selected "
        + policy.rawValue
        + " charter. The same owning terminal grants advanced-service eligibility and the unique Exchange completion clue. Existing original service contracts keep their stock/window/custody obligations and shared three-active limit."
    )
    commander.credits = after
    commander.scriptState.nextEvent = sequence
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition, version: mission.version,
      digest: mission.digest, outcome: .complete, sequence: sequence,
      causeKind: "mission.receipted", cause: cause, committed: scriptEventContext(mission),
      revision: publishedRevision, milestones: mission.milestones.sorted(), destroyedEncounters: [],
      deliveredParties: [], returnedEquipment: [], settlementAmount: nil, choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: previous, next: mission, trust: .production)
    if let completion = mission.completionReceipt { try enqueueScriptCompletion(completion) }
    guard NativeWayfarerInductionSave.validateClaims(commander),
      NativeInductionCrewLogSave.validateClaims(commander),
      ScriptClueVersionedSave.validateClaims(commander, trust: .production)
    else { throw SaveError.invalidCommander }
    notify("RIGHT-ON COMMANDER - EXCHANGE ACCREDITATION / 7600 CR")
  }
  var inductionAccreditationDetail: [String] {
    [
      "SENN / FINAL EXCHANGE ACCREDITATION",
      "After Veil's actual certification, Confirm pays the full7600CR once, completes the original induction, retains the chosen charter, grants advanced-service eligibility and records its one unique completion clue in the same transaction.",
      "Your current commander, hull, cargo and equipment remain yours. Existing service obligations and protected windows remain intact; accreditation does not bypass the shared three-active limit or create stock.",
      "Basic W01-W05 services remain available. Advanced offered variants use this same verified entitlement; W06 convoy work remains separately unavailable.",
      "Back/Escape changes no cash, entitlement, clue or completion. Cash overflow, stale native contact or missing original proof refuses the whole transaction.",
    ] + (contractBoard.wayfarerInductionQuote?.issues ?? [])
  }
}
