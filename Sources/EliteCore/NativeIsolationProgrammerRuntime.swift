import Foundation

extension Game {
  /// Stages one native accepted parent and the actual issue in the caller's unpublished candidate.
  /// The caller must stage the provider authorization before publishing this candidate.
  mutating func stageIsolationParent(
    arrival: NativeMainStationArrivalContext, expectedInventoryRevision: UInt64
  ) throws -> NativeIsolationWorkParentPrimitive {
    guard acceptsNativeMainStationArrivalContext(arrival), !isMissionTrial,
      arrival.receipt.station.system == SystemIdentity(galaxy: 0, system: 7),
      let owner = commander.equipmentOwnerID, let inventory = commander.equipmentInventory,
      inventory.revision == expectedInventoryRevision,
      inventory.owner == owner, arrival.receipt.commanderOwner == owner,
      scriptPacks.contains(where: NativeIsolationWorkParent.matches),
      scriptPacks.contains(where: NativeIsolationWorkPack.matches),
      !NativeIsolationProgrammerCustody.hasIssuedOriginal(in: commander),
      !commander.scriptState.instances.values.contains(where: NativeIsolationWorkParent.marked),
      commander.scriptState.instances.count < 127,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else {
      throw MissionPackError(
        "Lerr's actual berth, consent or original stock changed; review again.")
    }
    guard isolationWorkParentRouteIssue == nil else {
      throw MissionPackError(isolationWorkParentRouteIssue!)
    }
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    let job = NativeIsolationWorkParent.job(
      owner: owner, acceptedAt: commander.scriptState.calendarSeconds)
    let parentID = Self.contractJobIdentity(job.offer.id)
    let sequence = commander.scriptState.nextEvent + 1
    var parent = ScriptInstance(
      id: parentID, definition: NativeIsolationWorkParent.stateID,
      version: NativeIsolationWorkParent.version, digest: NativeIsolationWorkParent.digest)
    parent.contract = job
    var staged = commander
    let beforeCash = staged.credits
    guard
      let result = try issueScriptGearWithReceipt(
        NativeIsolationProgrammerDefinition.gear, fields: ["fit": .bool(false)], command: UUID(),
        state: &parent, candidate: &staged)
    else { throw EquipmentIssueError.staleObligation }
    let receipt = result.receipt
    guard receipt.operation == .issued,
      receipt.source
        == EquipmentIssueSource(
          mission: parentID, resource: NativeIsolationProgrammerDefinition.resource,
          packDigest: parent.digest),
      receipt.originalItems == [NativeIsolationProgrammerDefinition.serial(parent: parentID)],
      receipt.affectedItems == receipt.originalItems, receipt.consumedItems.isEmpty,
      receipt.displacements.isEmpty, staged.credits == beforeCash
    else { throw EquipmentIssueError.identityMismatch }
    parent.savedIsolationWorkParent = .init(
      parent: parentID, digest: parent.digest, owner: owner,
      source: NativeIsolationWorkParent.source(owner: owner),
      issuer: NativeIsolationProgrammerDefinition.issuer(owner: owner),
      authorization: try NativeIsolationWorkParent.authorization(
        parent: parentID, owner: owner, dock: arrival.receipt, sequence: sequence,
        issueOperation: receipt.command, carrier: inventory.activeHull,
        inventoryRevision: inventory.revision, physicalTime: staged.flightSimulation.physicalTime,
        terms: try NativeFlightReception.hash(job)),
      acceptance: arrival.receipt, carrier: inventory.activeHull,
      inventoryRevision: inventory.revision, sequence: sequence,
      physicalTime: staged.flightSimulation.physicalTime,
      terms: try NativeFlightReception.hash(job),
      issue: .init(
        operation: receipt.command, source: receipt.source, original: receipt.originalItems[0]))
    parent.milestones = [0]
    parent.acknowledge(sequence)
    staged.scriptState.nextEvent = sequence
    staged.scriptState.instances[parentID] = parent
    let primitive = try NativeIsolationWorkParent.primitive(parent: parent, commander: staged)
    _ = try NativeIsolationProgrammerCustody.resolve(parent: parent, commander: staged)
    commander = staged
    return primitive
  }

  /// Returns only the canonical original. Terminal/payment decisions belong to the outer caller.
  mutating func stageIsolationProgrammerReturn(
    parentID: UUID, arrival: NativeMainStationArrivalContext
  ) throws -> EquipmentIssueReceipt {
    guard acceptsNativeMainStationArrivalContext(arrival), !isMissionTrial,
      var parent = commander.scriptState.instances[parentID],
      var state = parent.savedIsolationWorkParent,
      arrival.receipt.station == state.acceptance.station,
      state.cutoff == nil, commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else {
      throw MissionPackError("Use Lerr's current actual Avenor berth and original programmer.")
    }
    _ = try NativeIsolationWorkParent.primitive(parent: parent, commander: commander)
    _ = try NativeIsolationProgrammerCustody.resolve(parent: parent, commander: commander)
    guard let issue = parent.gearIssues[NativeIsolationProgrammerDefinition.resource] else {
      throw EquipmentIssueError.staleObligation
    }
    var staged = commander
    let beforeCash = staged.credits
    let result = try settleScriptGearWithReceipt(
      issue, release: false, command: UUID(), state: &parent, candidate: &staged)
    guard result.receipt.operation == .returned, result.receipt.source == state.issue.source,
      result.receipt.originalItems == [state.issue.original],
      result.receipt.affectedItems == [state.issue.original], staged.credits == beforeCash
    else { throw EquipmentIssueError.identityMismatch }
    let sequence = staged.scriptState.nextEvent + 1
    state.cutoff = .init(
      operation: result.receipt.command, dock: arrival.receipt, sequence: sequence,
      physicalTime: staged.flightSimulation.physicalTime)
    parent.savedIsolationWorkParent = state
    parent.acknowledge(sequence)
    staged.scriptState.nextEvent = sequence
    staged.scriptState.instances[parentID] = parent
    _ = try NativeIsolationWorkParent.primitive(parent: parent, commander: staged)
    commander = staged
    return result.receipt
  }
}
