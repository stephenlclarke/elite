import Foundation

extension Game {
  var isolationWorkFailure: NativeIsolationContractFailure? {
    guard let parent = isolationWorkParentMission, let proof = parent.savedIsolationWorkParent,
      proof.terminal == nil, let source = isolationWorkChild?.savedIsolationWork
    else { return nil }
    if case .lost(let loss)? = proof.cutoff { return .programmer(loss.operation) }
    if let loss = source.stationLoss { return .station(loss.station, sequence: loss.sequence) }
    for module in source.modules {
      if let loss = module.loss { return .module(module.role, sequence: loss.sequence) }
    }
    return nil
  }

  /// This query validates historical receipts. It never substitutes a fresh UI reading for them.
  func isolationWorkReceptionIssue(at arrival: NativeMainStationArrivalContext) -> String? {
    let time = commander.flightSimulation.physicalTime
    guard acceptsNativeMainStationArrivalContext(arrival), !isMissionTrial, !paused,
      scriptDurabilityAvailable, nativeIsolationWorkPack != nil,
      scriptPacks.contains(where: NativeIsolationWorkParent.matches),
      let parent = isolationWorkParentMission,
      parent.outcome == .active, let proof = parent.savedIsolationWorkParent,
      proof.terminal == nil, proof.cutoff == nil,
      (try? NativeIsolationWorkParent.primitive(parent: parent, commander: commander)) != nil,
      (try? NativeIsolationProgrammerCustody.resolve(parent: parent, commander: commander)) != nil,
      NativeIsolationWorkSave.validateClaims(commander),
      let source = isolationWorkChild?.savedIsolationWork,
      source.stationLoss == nil, source.modules.allSatisfy({ $0.loss == nil }),
      arrival.receipt.station == proof.acceptance.station,
      arrival.receipt.sequence > proof.acceptance.sequence,
      arrival.receipt.actor.visit > proof.acceptance.actor.visit
    else {
      return
        "Use a later actual Lerr/Avenor arrival with the same issued original and intact source."
    }
    guard source.modules.count == 2,
      source.modules.allSatisfy({
        guard let receipt = $0.verification else { return false }
        return receipt.authority.parent == parent.id
          && receipt.authority.issueOperation == proof.issue.operation
          && receipt.last.end <= time
      }), Set(source.modules.compactMap { $0.verification?.operation }).count == 2
    else { return "Both original feeders need their separate published zero-flow verifications." }
    return nil
  }

  /// Called inside one outer command candidate; return, payment, terminal and clue publish together.
  mutating func receiveIsolationWork(at arrival: NativeMainStationArrivalContext) throws {
    if isolationWorkParentMission?.savedIsolationWorkParent?.terminal?.facts.outcome == .complete {
      return
    }
    guard isolationWorkReceptionIssue(at: arrival) == nil,
      let source = isolationWorkChild?.savedIsolationWork
    else {
      throw MissionPackError(
        "The original source, later arrival or programmer return is not ready.")
    }
    let verifications = source.modules.compactMap { $0.verification?.operation }
    let returned = try stageIsolationProgrammerReturn(
      parentID: source.permission.parent, arrival: arrival)
    try finishIsolationContract(
      .complete, dock: arrival.receipt, returned: returned.command,
      verifications: verifications, failure: nil)
    notify("LERR RECEIVED BOTH ISOLATIONS AND ORIGINAL PROGRAMMER - 970 CR")
  }

  mutating func returnIsolationProgrammerUnpaid(at arrival: NativeMainStationArrivalContext) throws
  {
    guard let parent = isolationWorkParentMission, let proof = parent.savedIsolationWorkParent
    else { throw SaveError.invalidCommander }
    if case .returned? = proof.cutoff { return }
    let returned = try stageIsolationProgrammerReturn(parentID: parent.id, arrival: arrival)
    if proof.terminal == nil {
      try finishIsolationContract(
        .abandoned, dock: arrival.receipt, returned: returned.command, verifications: [],
        failure: nil)
    } else {
      // A later actual return settles property only. The original unpaid job terminal stays fixed.
      guard var terminalParent = isolationWorkParentMission,
        terminalParent.revision < UInt64(Int64.max) - 1
      else { throw SaveError.invalidCommander }
      terminalParent.revision += 1
      refreshIsolationContractReceipt(&terminalParent)
      commander.scriptState.instances[terminalParent.id] = terminalParent
    }
    interruptIsolationWork()
    notify("ORIGINAL PROGRAMMER RETURNED - NO REWARD OR CLUE")
  }

  mutating func abandonIsolationWork() throws {
    guard !isMissionTrial, scriptDurabilityAvailable,
      let parent = isolationWorkParentMission, parent.outcome == .active
    else { throw SaveError.invalidCommander }
    try finishIsolationContract(
      .abandoned, dock: nil, returned: nil, verifications: [], failure: nil)
    interruptIsolationWork()
    notify("ISOLATION JOB ENDED UNPAID - ORIGINAL PROGRAMMER STILL OWED UNTIL LERR RETURN")
  }

  mutating func failIsolationWorkIfNeeded() throws {
    guard let failure = isolationWorkFailure else { return }
    try finishIsolationContract(
      .failed, dock: nil, returned: nil, verifications: [], failure: failure)
    interruptIsolationWork()
    notify("ISOLATION SOURCE OR ORIGINAL LOST - JOB CLOSED UNPAID")
  }

  private mutating func finishIsolationContract(
    _ outcome: ScriptOutcome, dock: NativeMainStationDockReceipt?, returned: UUID?,
    verifications: [UUID], failure: NativeIsolationContractFailure?
  ) throws {
    guard let previous = isolationWorkParentMission, previous.outcome == .active,
      var proof = previous.savedIsolationWorkParent, proof.terminal == nil,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      previous.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    var parent = previous
    let sequence = commander.scriptState.nextEvent + 1
    let facts = NativeIsolationContractTerminalFacts(
      parent: parent.id, authorization: proof.authorization, issueOperation: proof.issue.operation,
      owner: proof.owner, source: proof.source, outcome: outcome, sequence: sequence,
      physicalTime: commander.flightSimulation.physicalTime, cause: scriptEventContext(parent),
      dock: dock, returnedCommand: returned, verifications: verifications, failure: failure)
    let terminal = NativeIsolationContractTerminal(
      operation: try NativeIsolationContractTerminal.identity(facts), facts: facts)
    guard terminal.shapeValid(proof: proof) else { throw SaveError.invalidCommander }
    var candidate = commander
    try settleContract(outcome, state: &parent, candidate: &candidate)
    parent.outcome = outcome
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.dialogue = nil
    parent.milestones = outcome == .complete ? [0, 1, 2] : [0]
    proof.terminal = terminal
    parent.savedIsolationWorkParent = proof
    candidate.scriptState.nextEvent = sequence
    commander = candidate
    refreshIsolationContractReceipt(&parent)
    commander.scriptState.instances[parent.id] = parent
    try awardScriptClue(previous: previous, next: parent, trust: .production)
    if let receipt = parent.completionReceipt { try enqueueScriptCompletion(receipt) }
  }

  /// Failed/abandoned jobs may later return the still-held original; successful receipts stay fixed.
  mutating func refreshIsolationContractReceipt(_ parent: inout ScriptInstance) {
    guard let terminal = parent.savedIsolationWorkParent?.terminal else { return }
    parent.completionReceipt = .init(
      instance: parent.id, definition: parent.definition, version: parent.version,
      digest: parent.digest,
      outcome: terminal.facts.outcome, sequence: terminal.facts.sequence,
      causeKind: "mission.receipted",
      cause: terminal.facts.cause, committed: scriptEventContext(parent), revision: parent.revision,
      milestones: parent.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: parent.gearIssues.values.filter { $0.status == .returned }.map(\.resource)
        .sorted(),
      settlementAmount: parent.contract?.settlementAmount, choices: nil)
  }
}
