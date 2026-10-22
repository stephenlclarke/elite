import Foundation

struct ScriptEvent: Codable, Sendable, Equatable {
  let sequence: UInt64
  let kind: String
  let instance: UUID
  let values: [String: ScriptValue]
  var context: ScriptEventContext? = nil
  var value: ScriptValue {
    .object(
      values.merging([
        "kind": .string(kind), "sequence": .integer(Int64(sequence)),
        "instance_id": .string(instance.uuidString), "context": context?.value ?? .null,
      ]) { _, native in
        native
      })
  }
}

// Synchronous attempt-local owners. These intentionally are not Sendable, stored state,
// validation authority or callback captures; only their original value fields enter publication.
private final class ScriptEventBatchScratch {
  let events: ArraySlice<ScriptEvent>
  init(_ events: consuming ArraySlice<ScriptEvent>) { self.events = consume events }
}

private final class ScriptEventSelectionScratch {
  let event: ScriptEvent
  let instance: ScriptInstance
  let pack: ScriptPack
  let function: String
  init(
    event: consuming ScriptEvent, instance: consuming ScriptInstance,
    pack: consuming ScriptPack, function: String
  ) {
    self.event = consume event
    self.instance = consume instance
    self.pack = consume pack
    self.function = function
  }
}

private final class ScriptEventAttemptScratch {
  let selected: ScriptEventSelectionScratch
  let commands: [ScriptValue]
  var candidate: Game
  var derivedEvents: [(String, [String: ScriptValue])]
  var next: ScriptInstance
  init(selected: ScriptEventSelectionScratch, result: ScriptEvaluation, original: borrowing Game) {
    self.selected = selected
    commands = result.commands
    candidate = copy original
    derivedEvents = []
    next = selected.instance
    next.data = result.data
  }
}

private final class ScriptAcceptanceInstanceScratch {
  let id: UUID
  let instance: ScriptInstance
  let supplyDelta: OriginalConsentedFreightSupplyDelta?
  init(
    _ instance: consuming ScriptInstance, supplyDelta: OriginalConsentedFreightSupplyDelta? = nil
  ) {
    self.supplyDelta = supplyDelta
    id = instance.id
    self.instance = consume instance
  }
}

private final class ScriptAcceptanceAttemptScratch {
  let prepared: ScriptAcceptanceInstanceScratch
  var candidate: Game
  @inline(never)
  init(_ prepared: ScriptAcceptanceInstanceScratch, original: borrowing Game) {
    self.prepared = prepared
    candidate = copy original
  }
}

private struct ScriptGalleryEntryValues {
  let id: UUID
  let suspension: String?
  let outcome: ScriptOutcome
  let contract: ScriptContractJob?
  let journalLast: String?
  let milestones: Set<Int>
  let hasCampaignParent: Bool

  init(_ state: borrowing ScriptInstance) {
    id = state.id
    suspension = state.suspension
    outcome = state.outcome
    contract = state.contract
    journalLast = state.journal.last
    milestones = state.milestones
    hasCampaignParent = state.campaignParent != nil
  }
}

extension Game {
  var orderedScriptInstances: [UUID] {
    let priorities = Dictionary(
      scriptPacks.map { ($0.manifest.stateID + "@" + $0.digest, $0.manifest.priority) },
      uniquingKeysWith: { first, _ in first })
    let order = commander.scriptState.instances.map { id, instance in
      (
        id: id, priority: priorities[instance.definition + "@" + instance.digest] ?? 1001,
        definition: instance.definition, identity: id.uuidString
      )
    }
    return order.sorted { left, right in
      (left.priority, left.definition, left.identity)
        < (right.priority, right.definition, right.identity)
    }.map { $0.id }
  }
  mutating func observeScriptLocation(wasDocked: Bool, galaxy: Int, system: Int) {
    if galaxy != commander.galaxy || system != commander.system {
      emitScriptEvent("system.entered")
    }
    if wasDocked != docked { emitScriptEvent(docked ? "station.docked" : "station.undocked") }
  }
  func scriptPack(for instance: ScriptInstance) -> ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == instance.definition && $0.manifest.version == instance.version
        && $0.digest == instance.digest
    }
  }
  mutating func suspendUnavailableScriptContent(
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) {
    suspendUnavailableWorldJobs()
    for id in orderedScriptInstances {
      guard let instance = commander.scriptState.instances[id], instance.outcome == .active,
        instance.suspension == nil
      else { continue }
      if let reason = campaignExecutionIssue(instance) {
        commander.scriptState.instances[id]?.suspension = reason
      } else if let pack = scriptPack(for: instance),
        scriptUnavailable(pack, navigationBinding: navigationBinding) == nil
      {
        if let reason = campaignContentIssue(instance, pack: pack)
          ?? procurementContentIssue(instance, pack: pack)
          ?? freightContentIssue(instance, pack: pack)
        {
          commander.scriptState.instances[id]?.suspension = reason
        }
      } else {
        commander.scriptState.instances[id]?.suspension =
          "Restore the exact saved mission version and its requirements."
      }
    }
  }
  func scriptUnavailable(
    _ pack: ScriptPack, navigationBinding: ScriptNavigationTradeBinding? = nil
  ) -> String? {
    if pack.manifest.stateID == NativeInductionClinicPack.stateID
      || pack.digest == NativeInductionClinicPack.digest
    {
      guard NativeInductionClinicPack.matches(pack) else {
        return "Restore the original Renas clinic family content."
      }
      guard
        commander.scriptState.instances.values.contains(where: {
          $0.definition == NativeInductionClinicPack.stateID && $0.digest == pack.digest
            && $0.savedNativeInductionClinic != nil
        })
      else { return "Use the original clinic owner's actual Renas booking review." }
    }
    if pack.manifest.stateID == NativeInductionUtilityPack.stateID
      || pack.digest == NativeInductionUtilityPack.digest
    {
      guard NativeInductionUtilityPack.matches(pack) else {
        return "Restore the original Enron utility source."
      }
      guard
        commander.scriptState.instances.values.contains(where: {
          $0.definition == NativeInductionUtilityPack.stateID && $0.digest == pack.digest
            && $0.savedNativeInductionUtility != nil
        })
      else { return "Use the actual Exchange utility authorization at Enron." }
    }
    if pack.manifest.stateID == NativeInductionCrewLogPack.stateID
      || pack.digest == NativeInductionCrewLogPack.digest
    {
      guard NativeInductionCrewLogPack.matches(pack) else {
        return "Restore the original Cevilis custody source."
      }
      guard
        commander.scriptState.instances.values.contains(where: {
          $0.definition == NativeInductionCrewLogPack.stateID && $0.digest == pack.digest
            && $0.savedNativeCrewLog != nil
        })
      else { return "Continue the actual Exchange induction at Cevilis." }
    }
    if pack.manifest.stateID == NativeInductionArkPack.stateID
      || pack.digest == NativeInductionArkPack.digest
    {
      guard NativeInductionArkPack.matches(pack) else {
        return "Restore the registered original seed-ark service."
      }
      guard
        commander.scriptState.instances.values.contains(where: {
          $0.definition == NativeInductionArkPack.stateID && $0.digest == pack.digest
            && $0.savedNativeArk != nil
        })
      else { return "Use the original custodian launch review at Enlirin." }
    }
    if pack.manifest.wayfarerInduction != nil
      || pack.manifest.stateID == NativeWayfarerInduction.stateID
    {
      guard pack.digest == NativeWayfarerInduction.digest,
        pack.manifest.wayfarerInduction?.valid == true
      else { return "Restore the approved Wayfarer Exchange opening." }
      if !commander.scriptState.instances.values.contains(where: {
        $0.definition == NativeWayfarerInduction.stateID && $0.digest == pack.digest
      }) {
        return "Use Station Contracts at Avenor for Senn's induction commission."
      }
    }
    if pack.manifest.glassMeridian != nil || pack.manifest.stateID == NativeGlassMeridian.stateID {
      if let reason = NativeGlassMeridian.availability(
        pack,
        accepted: commander.scriptState.instances.values.contains(where: {
          $0.definition == NativeGlassMeridian.stateID && $0.digest == pack.digest
        }))
      {
        return reason
      }
    }
    if pack.manifest.flightReception != nil
      || pack.manifest.stateID == NativeFlightReception.stateID
    {
      guard pack.digest == NativeFlightReception.digest,
        pack.manifest.flightReception?.valid == true
      else {
        return "Restore the approved flight and reception practice."
      }
      if !commander.scriptState.instances.values.contains(where: {
        $0.definition == NativeFlightReception.stateID && $0.digest == pack.digest
      }) {
        return "Use Station Contracts at an actual original main training berth."
      }
    }
    if pack.manifest.fieldRelief != nil || pack.manifest.stateID == WayfarerFieldRelief.stateID {
      guard WayfarerFieldRelief.matches(pack) else {
        return "Restore the original field-relief mission content."
      }
      if !commander.scriptState.instances.values.contains(where: {
        $0.definition == WayfarerFieldRelief.stateID && $0.digest == pack.digest
      }) {
        return "Use Station Contracts at the actual Avenor source for native field relief."
      }
    }
    // Unrelated missions do not use a navigation binding; decide that before resolving one.
    if pack.manifest.capabilities.contains(ScriptNavigationTradeContent.capability)
      || pack.manifest.stateID == ScriptNavigationTradeContent.sourceID
    {
      if let reason = navigationTradeUnavailable(
        pack, binding: navigationBinding ?? ScriptNavigationTradeBinding.production(in: self))
      {
        return reason
      }
    }
    if !pack.missingCapabilities.isEmpty {
      return "Not available in this build: "
        + Set(pack.missingCapabilities.map(ScriptCapabilities.playerFeatureName)).sorted().joined(
          separator: ", ")
    }
    if pack.manifest.capabilities.contains("durable-commands-v2"), !scriptDurabilityAvailable {
      return "Choose a commander save before running this mission."
    }
    let versions = Set(scriptPacks.map { $0.manifest.id + "@" + $0.manifest.version })
      .union(missionPacks.entries.map { $0.pack.id + "@" + $0.pack.version })
    let missing = Set(pack.manifest.dependencies ?? []).subtracting(versions)
    return missing.isEmpty ? nil : "Requires: " + missing.sorted().joined(separator: ", ")
  }
  var scriptSnapshot: ScriptValue {
    // Read commander fields in their own borrowed-self frame. Expanding every
    // expression through Game.commander keeps many complete Commander temporaries
    // alive in this synchronous mission-dispatch stack under debug sanitizers.
    var fields = commander.scriptBaseSnapshotFields
    fields["docked"] = .bool(docked)
    fields["main_station"] = .bool(docked && dockedAtMainStation)
    fields["station_id"] = docked && dockedAtMainStation ? .string(contractStation.key) : .null
    fields["durable_commands"] = .bool(scriptDurabilityAvailable)
    fields["commander"] = scriptCommanderQuery
    fields["library"] = .array(referenceBooks.map(\.header))
    fields["calendar_day"] = .integer(calendarDay)
    return .object(fields)
  }
  func scopedScriptSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    var fields = scriptSnapshot.object ?? [:]
    fields["navigation_trade"] = navigationTradeQuery(instance)
    fields["provider"] = providerMissionQuery(instance)
    fields["children"] = campaignChildrenQuery(instance)
    fields["collections"] = collectionQuery(instance)
    fields["finance"] = financeQuery(instance)
    fields["transit"] = nativeTransitQuery(instance)
    fields["encounters"] = scriptEncounterSnapshot(instance)
    fields["passengers"] = scriptPassengerSnapshot(instance)
    fields["issued_equipment"] = scriptEquipmentSnapshot(instance)
    fields["choices"] = .object(instance.choiceReceipts.mapValues(\.value))
    fields["answers"] = scriptAnswersSnapshot(instance)
    fields["last_answer"] =
      instance.conversationReceipts.values.max { $0.sequence < $1.sequence }?.value ?? .null
    fields["contract"] = contractSnapshot(instance)
    fields["pledge"] = pledgeQuery(instance)
    if let terms = instance.contract?.offer.courier {
      fields["courier"] = .object([
        "item": instance.courier.map { .string($0.item.uuidString) } ?? .null,
        "difficulty": .integer(Int64(terms.difficulty)), "variant": .string(terms.variant.rawValue),
        "clock": .number(commander.scriptState.clock(.missionCalendar)),
      ])
    }
    if let pack = scriptPack(for: instance) {
      fields["receipt_requirements"] = scriptReceiptQuery(pack, state: instance)
    }
    fields["timers"] = .object(
      instance.timers.mapValues { timer in
        .object([
          "due": .number(timer.due), "domain": .string(timer.domain.rawValue),
          "pulse": .integer(Int64(timer.pulses)), "has_been_run": .bool(timer.pulses > 0),
          "clock_exhausted": .bool(timer.clockExhausted == true),
          "last_due": timer.lastDue.map(ScriptValue.number) ?? .null,
          "last_fired_at": timer.lastFiredAt.map(ScriptValue.number) ?? .null,
          "counters": .object(
            timer.counters.mapValues { counter in
              .object([
                "value": .integer(counter.value), "enabled": .bool(counter.enabled),
                "reset_pending": .bool(counter.resetOnNextPulse),
              ])
            }),
        ])
      })
    if let anchor = scriptAnchor {
      let position = anchor.orientation.inverse(anchor.position * -1)
      let velocity = anchor.orientation.inverse(autoPilot.velocity + Vector3(0, 0, speed * 18))
      fields["player"] = .object([
        "position": position.scriptVector,
        "velocity": velocity.scriptVector, "ship": .string(commander.shipID),
        "energy": .number(energy), "front_shield": .number(frontShield),
        "rear_shield": .number(rearShield), "laser_heat": .number(laserHeat),
      ])
    }
    fields["free_passenger_places"] = .integer(
      Int64(commander.passengerFit?.freeCompatiblePlaces ?? 0))
    return .object(fields)
  }
  mutating func acceptScriptMission(
    _ pack: ScriptPack, instanceID: UUID = UUID(), randomSeed: UInt64 = 0x45_4c49_5445,
    contract: ScriptContractJob? = nil, campaignParent: ScriptChildBinding? = nil,
    drainAccepted: Bool = true, freightAdmission: ScriptFreightIssueAdmission? = nil,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> UUID {
    let instance = try prepareScriptMissionAcceptance(
      pack, instanceID: instanceID, randomSeed: randomSeed,
      contract: contract, campaignParent: campaignParent, freightAdmission: freightAdmission,
      navigationBinding: navigationBinding)
    return try installScriptMissionAcceptance(
      pack, instance: instance, drainAccepted: drainAccepted)
  }
  mutating func acceptProviderMission(
    _ pack: ScriptPack, facts: NativeProviderMissionFacts,
    instanceID: UUID = UUID()
  ) throws -> UUID {
    let instance = try prepareProviderMissionAcceptance(pack, facts: facts, instanceID: instanceID)
    return try installScriptMissionAcceptance(pack, instance: instance, drainAccepted: true)
  }

  @inline(never)
  private mutating func prepareProviderMissionAcceptance(
    _ pack: ScriptPack, facts: NativeProviderMissionFacts, instanceID: UUID
  ) throws -> ScriptAcceptanceInstanceScratch {
    let state = try providerContractAcceptanceState(pack, facts: facts, instance: instanceID)
    return try prepareScriptMissionAcceptance(
      pack, instanceID: instanceID,
      randomSeed: 0x45_4c49_5445, contract: nil, campaignParent: nil, providerState: state)
  }
  // Preparation borrows self through a mutating receiver but does not change the game.
  @inline(never)
  private mutating func prepareScriptMissionAcceptance(
    _ pack: ScriptPack, instanceID: UUID, randomSeed: UInt64,
    contract: ScriptContractJob?, campaignParent: ScriptChildBinding?,
    providerState: ScriptProviderContractState? = nil,
    freightAdmission: ScriptFreightIssueAdmission? = nil,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> ScriptAcceptanceInstanceScratch {
    try validateScriptMissionAcceptance(
      pack, instanceID: instanceID, contract: contract, campaignParent: campaignParent,
      providerState: providerState, navigationBinding: navigationBinding)
    return try constructScriptMissionAcceptance(
      pack, instanceID: instanceID, randomSeed: randomSeed, contract: contract,
      campaignParent: campaignParent, providerState: providerState,
      freightAdmission: freightAdmission)
  }

  // Early acceptance values retire before full instance/native-contract construction begins.
  @inline(never)
  private mutating func validateScriptMissionAcceptance(
    _ pack: ScriptPack, instanceID: UUID,
    contract: ScriptContractJob?, campaignParent: ScriptChildBinding?,
    providerState: ScriptProviderContractState?, navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    guard pack.manifest.stateID != NativeInductionClinicPack.stateID,
      pack.digest != NativeInductionClinicPack.digest
    else {
      throw MissionPackError(
        "Use the actual original clinic rebrief; generic consignment acceptance is refused.")
    }
    guard pack.manifest.stateID != NativeInductionUtilityPack.stateID,
      pack.digest != NativeInductionUtilityPack.digest
    else { throw MissionPackError("Use the actual utility authorization at Enron.") }
    guard pack.manifest.stateID != NativeInductionCrewLogPack.stateID,
      pack.digest != NativeInductionCrewLogPack.digest
    else { throw MissionPackError("Continue the actual Exchange induction at Cevilis.") }
    guard pack.manifest.stateID != NativeInductionArkPack.stateID,
      pack.digest != NativeInductionArkPack.digest
    else { throw MissionPackError("Use the original custodian launch review at Enlirin.") }
    guard pack.manifest.wayfarerInduction == nil,
      pack.manifest.stateID != NativeWayfarerInduction.stateID
    else { throw MissionPackError("Use Senn's actual induction commission review.") }
    guard pack.manifest.glassMeridian == nil, pack.manifest.stateID != NativeGlassMeridian.stateID
    else { throw MissionPackError("Use the actual Venn commission review.") }
    guard pack.manifest.flightReception == nil,
      pack.manifest.stateID != NativeFlightReception.stateID
    else { throw MissionPackError("Use the actual native training berth practice.") }
    guard pack.manifest.fieldRelief == nil,
      pack.manifest.stateID != WayfarerFieldRelief.stateID
    else { throw MissionPackError("Use the actual native field-relief collection.") }
    guard scriptUnavailable(pack, navigationBinding: navigationBinding) == nil,
      commander.scriptState.instances.count < 128,
      commander.scriptState.instances[instanceID] == nil,
      pack.manifest.mission.parentOnly != true || campaignParent != nil,
      campaignParent == nil || contract == nil,
      campaignParent.map({ binding in
        binding.child == instanceID && binding.definition.definition == pack.manifest.stateID
          && binding.definition.version == pack.manifest.version
          && binding.definition.digest == pack.digest
          && commander.scriptState.instances[binding.parent]?.campaignChildren[
            binding.definition.id]
            == binding
      }) ?? true,
      pack.manifest.board != nil || campaignParent != nil
        || !commander.scriptState.instances.values.contains(where: {
          $0.definition == pack.manifest.stateID
            && !(ScriptNavigationTradeContent.matches(pack) && $0.outcome != .active)
        }), (pack.manifest.board == nil) == (contract == nil)
    else {
      throw MissionPackError(
        "Mission unavailable, already accepted or saved under another version.")
    }
    guard (pack.manifest.providerContract == nil) == (providerState == nil) else {
      throw MissionPackError("Ordinary provider acceptance requires fresh native authority.")
    }
    try ScriptPackLibrary.validateCourier(pack.manifest)
    try ScriptPackLibrary.validateProcurement(pack.manifest)
    if pack.manifest.courier != nil, scriptCourierAdmission == nil {
      throw MissionPackError("Courier requires its native board confirmation.")
    }
    if let reason = scriptAcceptanceIssue(pack) { throw MissionPackError(reason) }
  }

  @inline(never)
  private mutating func constructScriptMissionAcceptance(
    _ pack: ScriptPack, instanceID: UUID, randomSeed: UInt64,
    contract: ScriptContractJob?, campaignParent: ScriptChildBinding?,
    providerState: ScriptProviderContractState?, freightAdmission: ScriptFreightIssueAdmission?
  ) throws -> ScriptAcceptanceInstanceScratch {
    var instance = ScriptInstance(
      id: instanceID, definition: pack.manifest.stateID,
      version: pack.manifest.version, digest: pack.digest)
    instance.receiptJoins = try scriptReceiptJoins(pack, stage: .acceptance, existing: [:])
    instance.savedProviderContract = providerState
    if let providerState { instance.payloads[providerState.terms.payload] = 1 }
    instance.randomState = randomSeed
    instance.contract = contract
    var supplyDelta: OriginalConsentedFreightSupplyDelta?
    if pack.manifest.freight != nil {
      guard let freightAdmission, contract?.offer.freightPlan?.matches(pack) == true else {
        throw MissionPackError("Supplied freight requires native issue admission.")
      }
      supplyDelta = try freightAdmission.issue(into: &instance, game: self)
    } else if freightAdmission != nil {
      throw SaveError.invalidCommander
    }
    instance.campaignParent = campaignParent
    let scopes = Dictionary(
      uniqueKeysWithValues: (pack.manifest.receiptRequirements ?? []).compactMap { requirement in
        requirement.child.map { (requirement.id, $0) }
      })
    instance.savedCampaignReceiptScopes = scopes.isEmpty ? nil : scopes
    if pack.manifest.procurement != nil {
      guard let contract, let plan = ScriptProcurementPlan.read(contract.offer.parameters),
        ScriptProcurementGeneration.valid(contract), plan.matches(pack),
        instanceID == Self.contractJobIdentity(contract.offer.id),
        commander.contracts.boards[contract.boardKey]?.offers.first(where: {
          $0.id == contract.offer.id
        })?.status == .accepted(instanceID),
        let definition = plan.collection
      else {
        throw MissionPackError("Procurement requires its original native board acceptance.")
      }
      try requireProcurementResources(plan)
      instance.collections[definition.id] = .init(definition: definition)
    }
    if let contract, let due = contract.deadline, contract.offer.courier == nil,
      pack.manifest.procurement == nil, pack.manifest.freight == nil
    {
      instance.timers["contract-deadline"] = .init(
        id: "contract-deadline", domain: contract.clock, due: due, interval: 0, policy: .once)
    }
    return ScriptAcceptanceInstanceScratch(instance, supplyDelta: supplyDelta)
  }
  private mutating func installScriptMissionAcceptance(
    _ pack: ScriptPack, instance: ScriptAcceptanceInstanceScratch, drainAccepted: Bool
  ) throws -> UUID {
    let attempt = ScriptAcceptanceAttemptScratch(instance, original: self)
    try Self.prepareScriptAcceptanceCandidate(attempt, pack: pack)
    Self.emitScriptAcceptance(attempt, drainAccepted: drainAccepted)
    try Self.validateScriptAcceptance(attempt)
    publishScriptMissionAcceptance(attempt)
    return instance.id
  }

  @inline(never)
  private static func prepareScriptAcceptanceCandidate(
    _ attempt: ScriptAcceptanceAttemptScratch, pack: ScriptPack
  ) throws {
    attempt.candidate.ensureScriptCalendar(origin: .newCommander)
    if pack.manifest.capabilities.contains("owned-equipment-v2") {
      try attempt.candidate.commander.prepareEquipment()
    }
    try attempt.prepared.supplyDelta?.install(into: &attempt.candidate.commander.scriptState)
    attempt.candidate.commander.scriptState.instances[attempt.prepared.id] =
      attempt.prepared.instance
  }

  @inline(never)
  private static func emitScriptAcceptance(
    _ attempt: ScriptAcceptanceAttemptScratch, drainAccepted: Bool
  ) {
    attempt.candidate.emitScriptEvent(
      "mission.accepted", only: attempt.prepared.id, drain: drainAccepted)
  }

  @inline(never)
  private static func validateScriptAcceptance(_ attempt: ScriptAcceptanceAttemptScratch) throws {
    if let reason = attempt.candidate.commander.scriptState.instances[attempt.prepared.id]?
      .suspension
    {
      throw MissionPackError(reason)
    }
  }
  @inline(never)
  private mutating func publishScriptMissionAcceptance(_ attempt: ScriptAcceptanceAttemptScratch) {
    self = attempt.candidate
  }
  mutating func emitScriptEvent(
    _ kind: String, values: [String: ScriptValue] = [:], only: UUID? = nil, drain: Bool = true
  ) {
    enqueueScriptEvent(kind, values: values, only: only)
    if drain { drainScriptEvents() }
  }
  private mutating func enqueueScriptEvent(
    _ kind: String, values: [String: ScriptValue], only: UUID?
  ) {
    for id in orderedScriptInstances
    where only == nil || only == id {
      guard let instance = commander.scriptState.instances[id], instance.outcome == .active else {
        continue
      }
      guard commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
        commander.scriptState.pendingEvents.count < 4096
      else {
        commander.scriptState.instances[id]?.suspension =
          "Mission event capacity reached; save and restore supported content."
        continue
      }
      commander.scriptState.nextEvent += 1
      commander.scriptState.pendingEvents.append(
        ScriptEvent(
          sequence: commander.scriptState.nextEvent, kind: kind, instance: id, values: values,
          context: scriptEventContext(instance)))
    }
  }
  mutating func drainScriptEvents(
    publish: ScriptPublisher? = nil, clueTrust: ScriptClueTrustCatalog = .production,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) {
    guard !scriptDispatching, !scriptEventsDeferred else { return }
    scriptDispatching = true
    defer { scriptDispatching = false }
    // The same bounded prefix is retained independently of removals and derived emissions.
    let batch = scriptEventBatch()
    for index in batch.events.indices {
      drainScriptEvent(
        batch, index: index, publish: publish, clueTrust: clueTrust,
        navigationBinding: navigationBinding)
    }
  }

  @inline(never)
  private mutating func scriptEventBatch() -> ScriptEventBatchScratch {
    .init(commander.scriptState.pendingEvents.prefix(64))
  }

  @inline(never)
  private mutating func selectScriptEvent(
    _ batch: ScriptEventBatchScratch, index: Int,
    navigationBinding: ScriptNavigationTradeBinding?
  ) -> ScriptEventSelectionScratch? {
    let event = batch.events[index]
    guard let instance = commander.scriptState.instances[event.instance],
      instance.suspension == nil
    else { return nil }
    guard let pack = scriptPack(for: instance),
      scriptUnavailable(pack, navigationBinding: navigationBinding) == nil
    else {
      commander.scriptState.instances[event.instance]?.suspension =
        "Restore the exact saved mission version and its requirements."
      return nil
    }
    if instance.outcome != .active || instance.hasAcknowledged(event.sequence) {
      commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
      return nil
    }
    if let reason = campaignExecutionIssue(instance) ?? campaignContentIssue(instance, pack: pack)
      ?? procurementContentIssue(instance, pack: pack)
      ?? freightContentIssue(instance, pack: pack)
    {
      commander.scriptState.instances[event.instance]?.suspension = reason
      return nil
    }
    guard let handler = pack.manifest.handlers.first(where: { $0.event == event.kind }) else {
      commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
      return nil
    }
    return .init(
      event: consume event, instance: consume instance, pack: consume pack,
      function: handler.function)
  }

  @inline(never)
  private mutating func drainScriptEvent(
    _ batch: ScriptEventBatchScratch, index: Int, publish: ScriptPublisher?,
    clueTrust: ScriptClueTrustCatalog, navigationBinding: ScriptNavigationTradeBinding?
  ) {
    guard
      let selected = selectScriptEvent(batch, index: index, navigationBinding: navigationBinding)
    else { return }
    do {
      let attempt = try Self.executeScriptEventAttempt(
        original: self, selected: selected, navigationBinding: navigationBinding,
        publish: publish, clueTrust: clueTrust)
      commitScriptEventAttempt(attempt)
    } catch let refusal as ScriptNavigationTradeRefusal {
      refuseScriptEvent(selected, refusal: refusal)
    } catch {
      failScriptEvent(selected, error: error, publish: publish)
    }
  }

  /// Borrow one original value across the pipeline instead of staging three mutating-receiver reads.
  @inline(never)
  private static func executeScriptEventAttempt(
    original: borrowing Game, selected: ScriptEventSelectionScratch,
    navigationBinding: ScriptNavigationTradeBinding?, publish: ScriptPublisher?,
    clueTrust: ScriptClueTrustCatalog
  ) throws -> ScriptEventAttemptScratch {
    let attempt = try makeScriptEventAttempt(original: original, selected: selected)
    try runScriptEventAttempt(
      original: original, attempt: attempt, navigationBinding: navigationBinding)
    try finishScriptEventAttempt(
      original: original, attempt: attempt, publish: publish, clueTrust: clueTrust)
    return attempt
  }

  @inline(never)
  private static func makeScriptEventAttempt(
    original: borrowing Game, selected: ScriptEventSelectionScratch
  ) throws -> ScriptEventAttemptScratch {
    let result = try ScriptEvaluator.evaluate(
      source: selected.pack.source, handler: selected.function,
      event: selected.event.value, snapshot: original.scopedScriptSnapshot(selected.instance),
      state: selected.instance.data)
    return .init(selected: selected, result: result, original: original)
  }

  @inline(never)
  private static func runScriptEventAttempt(
    original: borrowing Game, attempt: ScriptEventAttemptScratch,
    navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    for index in attempt.commands.indices {
      try dispatchScriptEventCommand(
        original: original, attempt: attempt, index: index, navigationBinding: navigationBinding)
    }
  }

  @inline(never)
  private static func finishScriptEventAttempt(
    original: borrowing Game, attempt: ScriptEventAttemptScratch,
    publish: ScriptPublisher?, clueTrust: ScriptClueTrustCatalog
  ) throws {
    try finishScriptEventCandidate(
      original: original, candidate: &attempt.candidate, instance: attempt.selected.instance,
      next: &attempt.next, event: attempt.selected.event, pack: attempt.selected.pack,
      derivedEvents: &attempt.derivedEvents, publish: publish, clueTrust: clueTrust)
  }

  @inline(never)
  private mutating func commitScriptEventAttempt(_ attempt: ScriptEventAttemptScratch) {
    self = attempt.candidate
  }

  @inline(never)
  private mutating func refuseScriptEvent(
    _ selected: ScriptEventSelectionScratch, refusal: ScriptNavigationTradeRefusal
  ) {
    // A refused user confirmation commits no proposal effects and cannot replay later.
    commander.scriptState.pendingEvents.removeAll { $0.sequence == selected.event.sequence }
    commander.scriptState.instances[selected.event.instance]?.acknowledge(selected.event.sequence)
    commander.scriptState.instances[selected.event.instance]?.dialogue = nil
    notify(refusal.message)
  }

  @inline(never)
  private mutating func failScriptEvent(
    _ selected: ScriptEventSelectionScratch, error: any Error, publish: ScriptPublisher?
  ) {
    recordScriptFailure(selected.event.instance, error: error, publish: publish)
  }

  @inline(never)
  private static func dispatchScriptEventCommand(
    original: borrowing Game, attempt: ScriptEventAttemptScratch, index: Int,
    navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    let command = attempt.commands[index]
    if try scriptCommandIsTraining(command, attempt: attempt) {
      try dispatchTrainingCommand(
        command, original: original, attempt: attempt, navigationBinding: navigationBinding)
      return
    }
    if ["courier.issue", "courier.deliver", "courier.abandon"].contains(command["op"]?.string ?? "")
    {
      try dispatchCourierCommand(command, attempt: attempt)
    } else if command["op"]?.string == "pledge.commit" {
      try dispatchPledgeCommand(command, attempt: attempt)
    } else if command["op"]?.string == "child.ensure" {
      try dispatchCampaignChildCommand(command, attempt: attempt)
    } else if command["op"]?.string == "finance.offer" {
      try dispatchFinanceCommand(command, attempt: attempt)
    } else if ["collection.ensure", "collection.deliver"].contains(command["op"]?.string ?? "") {
      try dispatchCollectionCommand(command, attempt: attempt)
    } else if command["op"]?.string == "book.unlock" {
      try dispatchBookCommand(command, attempt: attempt)
    } else if command["op"]?.string == "world.job.ensure" {
      try dispatchWorldJobCommand(command, attempt: attempt)
    } else if command["op"]?.string == "encounter.ensure" {
      try dispatchEncounterCommand(command, attempt: attempt)
    } else if command["op"]?.string == "actor.intent" {
      try dispatchActorIntentCommand(command, attempt: attempt)
    } else if ["actor.transit", "actor.transit.retry"].contains(command["op"]?.string ?? "") {
      if let event = try attempt.candidate.requestScriptNPCTransit(
        command, pack: attempt.selected.pack, state: attempt.next)
      {
        attempt.derivedEvents.append(event)
      }
    } else if ["gear.issue", "gear.return", "gear.release", "gear.store", "gear.refit"]
      .contains(command["op"]?.string ?? "")
    {
      try dispatchGearCommand(command, attempt: attempt)
    } else if ["passengers.board", "passengers.deliver"].contains(command["op"]?.string ?? "") {
      try dispatchPassengerCommand(command, attempt: attempt)
    } else {
      try dispatchStandardCommand(command, original: original, attempt: attempt)
    }
    notifyScriptProviderCommand(command, attempt: attempt)
  }

  @inline(never)
  private static func scriptCommandIsTraining(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws -> Bool {
    if attempt.selected.pack.manifest.capabilities.contains(ScriptNavigationTradeContent.capability)
    {
      let allowed: Set<String> = [
        "journal.append", "dialogue.offer", "dialogue.commit",
        "milestone.ensure", "mission.finish", "training.trade.begin",
        "training.trade.receive",
        "training.trade.cancel", "training.trade.acknowledge-loss",
      ]
      guard allowed.contains(command["op"]?.string ?? "") else {
        throw MissionPackError("Training scripts cannot invent cargo or economic settlement.")
      }
    }
    if command["op"]?.string?.hasPrefix("training.trade.") == true { return true }
    if attempt.selected.pack.manifest.freight != nil,
      !["journal.append", "dialogue.offer"].contains(command["op"]?.string ?? "")
    {
      throw MissionPackError("Freight scripts may present native contacts only.")
    }
    if attempt.selected.pack.manifest.procurement != nil,
      !["journal.append", "dialogue.offer", "collection.ensure", "collection.deliver"]
        .contains(command["op"]?.string ?? "")
    {
      throw MissionPackError(
        "Procurement scripts may present contacts and request real material lots only.")
    }
    if attempt.selected.pack.manifest.providerContract != nil,
      !["journal.append", "dialogue.offer"].contains(command["op"]?.string ?? "")
    {
      throw MissionPackError("Provider scripts may present finite native transitions only.")
    }
    if attempt.selected.pack.manifest.courier != nil,
      ![
        "milestone.ensure", "journal.append", "dialogue.offer", "courier.issue",
        "courier.deliver", "courier.abandon",
      ].contains(command["op"]?.string ?? "")
    {
      throw MissionPackError("Courier handlers require closed native custody commands.")
    }
    if attempt.selected.pack.manifest.pledge != nil,
      !["milestone.ensure", "journal.append", "pledge.commit"].contains(
        command["op"]?.string ?? "")
    {
      throw MissionPackError(
        "A pledge handler may only record its objective and commit the native donation.")
    }
    if attempt.selected.pack.manifest.pledge != nil, attempt.next.outcome != .active {
      throw MissionPackError("A completed pledge cannot issue another command.")
    }
    return false
  }

  @inline(never)
  private static func dispatchTrainingCommand(
    _ command: ScriptValue, original: borrowing Game, attempt: ScriptEventAttemptScratch,
    navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    let binding: ScriptNavigationTradeBinding?
    if let navigationBinding {
      binding = navigationBinding
    } else if let record = attempt.next.savedNavigationTrade {
      binding = ScriptNavigationTradeBinding.production(for: record)
    } else {
      binding = ScriptNavigationTradeBinding.selectedRoute(in: original)
    }
    try original.applyNavigationTradeCommand(
      command, event: attempt.selected.event, pack: attempt.selected.pack, state: &attempt.next,
      binding: binding)
  }

  @inline(never)
  private static func dispatchCampaignChildCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    if let result = try attempt.candidate.ensureCampaignChild(
      command, pack: attempt.selected.pack, state: &attempt.next, event: attempt.selected.event)
    {
      attempt.derivedEvents.append(result)
    }
  }

  @inline(never)
  private static func dispatchFinanceCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    try attempt.candidate.registerFinanceOffer(
      command, event: attempt.selected.event, pack: attempt.selected.pack, state: attempt.next)
  }

  @inline(never)
  private static func dispatchBookCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    if let result = try attempt.candidate.unlockScriptBook(
      command, pack: attempt.selected.pack, state: attempt.next, event: attempt.selected.event)
    {
      attempt.derivedEvents.append(result)
    }
  }

  @inline(never)
  private static func dispatchWorldJobCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    try attempt.candidate.ensureScriptWorldJob(
      command, pack: attempt.selected.pack, state: attempt.next)
  }

  @inline(never)
  private static func dispatchEncounterCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    guard let fields = command.object, Set(fields.keys) == ["op", "id"],
      let id = command["id"]?.string
    else {
      throw MissionPackError("Encounter request requires only op and declared id.")
    }
    attempt.derivedEvents.append(
      try attempt.candidate.ensureScriptEncounter(
        id, pack: attempt.selected.pack, state: &attempt.next))
    // Later native commands must join bodies to their already staged private owner.
    attempt.candidate.commander.scriptState.instances[attempt.next.id] = attempt.next
  }

  @inline(never)
  private static func dispatchActorIntentCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    if let result = try attempt.candidate.applyScriptNPCIntent(
      command, pack: attempt.selected.pack, state: &attempt.next)
    {
      attempt.derivedEvents.append(result)
    }
  }

  @inline(never)
  private static func notifyScriptProviderCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) {
    if attempt.selected.pack.manifest.providerContract != nil,
      command["op"]?.string == "journal.append",
      let text = command["text"]?.string
    {
      attempt.candidate.notify(text)
    }
  }

  /// Finalization and native publication stay synchronous in the same actor turn.
  private static func finishScriptEventCandidate(
    original: borrowing Game, candidate: inout Game,
    instance: ScriptInstance, next: inout ScriptInstance,
    event: ScriptEvent, pack: ScriptPack,
    derivedEvents: inout [(String, [String: ScriptValue])], publish: ScriptPublisher?,
    clueTrust: ScriptClueTrustCatalog
  ) throws {
    try prepareScriptEventCandidateForPublication(
      original: original, candidate: &candidate, instance: instance, next: &next,
      event: event, pack: pack, derivedEvents: &derivedEvents, clueTrust: clueTrust)
    try publish?(&candidate)
  }
  /// Return before entering the deeper native save, releasing Commander/encoding temporaries.
  @inline(never)
  private static func prepareScriptEventCandidateForPublication(
    original: borrowing Game, candidate: inout Game,
    instance: ScriptInstance, next: inout ScriptInstance,
    event: ScriptEvent, pack: ScriptPack,
    derivedEvents: inout [(String, [String: ScriptValue])], clueTrust: ScriptClueTrustCatalog
  ) throws {
    try prepareScriptEventReceiptsAndClue(
      candidate: &candidate, instance: instance, next: &next, event: event, pack: pack,
      derivedEvents: &derivedEvents, clueTrust: clueTrust)
    reconcileScriptEventCandidateResources(original: original, candidate: &candidate)
    candidate.suspendTerminalCampaignChildren(next)
    try prepareScriptEventResultQueue(
      candidate: &candidate, next: next, event: event, derivedEvents: derivedEvents)
    try validateScriptEventCandidateSaveBudget(candidate)
  }

  @inline(never)
  private static func prepareScriptEventReceiptsAndClue(
    candidate: inout Game, instance: ScriptInstance, next: inout ScriptInstance,
    event: ScriptEvent, pack: ScriptPack, derivedEvents: inout [(String, [String: ScriptValue])],
    clueTrust: ScriptClueTrustCatalog
  ) throws {
    for group in next.choiceReceipts.keys.sorted() where instance.choiceReceipts[group] == nil {
      let choice = next.choiceReceipts[group]!
      derivedEvents.append(
        (
          "dialogue.chosen",
          [
            "group": .string(group), "choice_id": .string(choice.choice),
            "dialogue_id": .string(choice.dialogue),
          ]
        ))
    }
    for sequence in next.conversationReceipts.keys.sorted()
    where instance.conversationReceipts[sequence] == nil {
      let answer = next.conversationReceipts[sequence]!
      derivedEvents.append(
        (
          "dialogue.chosen",
          [
            "group": .null, "choice_id": .string(answer.choice),
            "dialogue_id": .string(answer.dialogue),
            "answer_sequence": .integer(Int64(sequence)),
          ]
        ))
    }
    next.revision += 1
    next.acknowledge(event.sequence)
    if next.outcome != .active {
      next.completionReceipt = candidate.completionReceipt(next, event: event, pack: pack)
    }
    candidate.commander.scriptState.instances[next.id] = next
    try candidate.awardScriptClue(previous: instance, next: next, trust: clueTrust)
  }

  @inline(never)
  private static func reconcileScriptEventCandidateResources(
    original: borrowing Game, candidate: inout Game
  ) {
    let oldEnergy = original.commander.performance.energy
    let newEnergy = candidate.commander.performance.energy
    if oldEnergy != newEnergy {
      candidate.energy = Self.equipmentResourceLevel(
        candidate.energy, from: oldEnergy, to: newEnergy)
    }
    let oldFront = original.commander.shieldCapacity
    let newFront = candidate.commander.shieldCapacity
    if oldFront != newFront {
      candidate.frontShield = Self.equipmentResourceLevel(
        candidate.frontShield, from: oldFront, to: newFront)
    }
    let oldRear = original.commander.rearShieldCapacity
    let newRear = candidate.commander.rearShieldCapacity
    if oldRear != newRear {
      candidate.rearShield = Self.equipmentResourceLevel(
        candidate.rearShield, from: oldRear, to: newRear)
    }
  }

  @inline(never)
  private static func prepareScriptEventResultQueue(
    candidate: inout Game, next: ScriptInstance, event: ScriptEvent,
    derivedEvents: [(String, [String: ScriptValue])]
  ) throws {
    candidate.commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
    if let receipt = next.completionReceipt { try candidate.enqueueScriptCompletion(receipt) }
    try validateScriptEventCommander(candidate)
    try emitScriptEventResultQueue(candidate: &candidate, next: next, derivedEvents: derivedEvents)
  }

  @inline(never)
  private static func validateScriptEventCommander(_ candidate: borrowing Game) throws {
    guard scriptEventCommanderIsValid(candidate.commander) else {
      throw MissionPackError(scriptEventCommanderFitIssue(candidate))
    }
  }

  @inline(never)
  private static func scriptEventCommanderIsValid(_ commander: borrowing Commander) -> Bool {
    commander.valid
  }

  @inline(never)
  private static func scriptEventCommanderFitIssue(_ candidate: borrowing Game) -> String {
    candidate.commander.passengerFit?.issues.first
      ?? "Mission transfer cannot fit the commander or saved state."
  }

  @inline(never)
  private static func emitScriptEventResultQueue(
    candidate: inout Game, next: ScriptInstance, derivedEvents: [(String, [String: ScriptValue])]
  ) throws {
    guard candidate.commander.scriptState.pendingEvents.count + derivedEvents.count <= 4096,
      candidate.commander.scriptState.nextEvent <= UInt64(Int64.max) - 1
        - UInt64(derivedEvents.count)
    else { throw MissionPackError("The native result queue cannot fit this whole proposal.") }
    // Admission/result envelopes belong to the same durable generation as their cause.
    for (kind, values) in derivedEvents {
      candidate.emitScriptEvent(kind, values: values, only: next.id, drain: false)
    }
  }

  /// Release the computed Commander receiver before entering the generic encoder.
  @inline(never)
  private static func scriptEventCandidateStateForEncoding(
    _ candidate: borrowing Game
  ) -> ScriptEngineState {
    candidate.commander.scriptState
  }

  @inline(never)
  private static func validateScriptEventCandidateSaveBudget(
    _ candidate: borrowing Game
  ) throws {
    let savedBytes = try JSONEncoder().encode(scriptEventCandidateStateForEncoding(candidate))
    guard savedBytes.count <= 33_554_432 else {
      throw MissionPackError("Mission save budget exceeded; proposal was not committed.")
    }
  }
  // Separate branch frames keep commander-borrow receiver copies out of encounter admission.
  @inline(never)
  private static func dispatchCourierCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    try attempt.candidate.applyCourierCommand(
      command, event: attempt.selected.event, pack: attempt.selected.pack, state: &attempt.next,
      candidate: &attempt.candidate.commander)
  }
  @inline(never)
  private static func dispatchPledgeCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    try attempt.candidate.applyPledgeCommand(
      command, event: attempt.selected.event, pack: attempt.selected.pack, state: &attempt.next,
      candidate: &attempt.candidate.commander)
  }
  @inline(never)
  private static func dispatchCollectionCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    if let result = try attempt.candidate.applyCollectionCommand(
      command, event: attempt.selected.event, pack: attempt.selected.pack, state: &attempt.next,
      candidate: &attempt.candidate.commander)
    {
      attempt.derivedEvents.append(result)
    }
  }
  @inline(never)
  private static func dispatchGearCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    if let result = try attempt.candidate.applyScriptGearCommand(
      command, event: attempt.selected.event, pack: attempt.selected.pack, state: &attempt.next,
      candidate: &attempt.candidate.commander)
    {
      attempt.derivedEvents.append(result)
    }
  }
  @inline(never)
  private static func dispatchPassengerCommand(
    _ command: ScriptValue, attempt: ScriptEventAttemptScratch
  ) throws {
    try attempt.candidate.applyPassengerCommand(
      command, pack: attempt.selected.pack, state: &attempt.next,
      candidate: &attempt.candidate.commander)
  }
  @inline(never)
  private static func dispatchStandardCommand(
    _ command: ScriptValue, original: borrowing Game, attempt: ScriptEventAttemptScratch
  ) throws {
    // Standard commands intentionally query the original event transaction snapshot.
    try original.applyScriptCommand(
      command, event: attempt.selected.event, pack: attempt.selected.pack, state: &attempt.next,
      candidate: &attempt.candidate.commander)
  }
  mutating func advanceScriptClocks(
    delta: Double, flight: Bool, local: Bool, calendar: Bool = false,
    publish: ScriptPublisher? = nil
  ) {
    guard advanceScriptClockValues(delta: delta, flight: flight, local: local, calendar: calendar)
    else { return }
    fireDueScriptTimers(flight: flight, local: local, calendar: calendar, publish: publish)
  }
  mutating func advanceScriptClockValues(
    delta: Double, flight: Bool, local: Bool, calendar: Bool,
    missionCalendar: Bool = false
  )
    -> Bool
  {
    let scripted = !commander.scriptState.instances.isEmpty || !commander.contracts.boards.isEmpty
    guard scripted || calendar,
      delta.isFinite, delta > 0, !paused,
      flight || local || calendar
    else {
      return false
    }
    let dt = min(delta, 0.1)
    if scripted && local {
      commander.scriptState.localSeconds = min(1e12, commander.scriptState.localSeconds + dt)
    }
    if scripted && flight {
      commander.scriptState.flightSeconds = min(1e12, commander.scriptState.flightSeconds + dt)
    }
    if calendar {
      ensureScriptCalendar(origin: .newCommander)
      let reserved = commander.scriptState.calendarLedger?.pendingJourney?.seconds ?? 0
      commander.scriptState.calendarSeconds = min(
        1e12 - reserved, commander.scriptState.calendarSeconds + dt)
    }
    if missionCalendar, var clock = commander.scriptState.missionCalendar {
      let reserved = commander.scriptState.calendarLedger?.pendingJourney?.seconds ?? 0
      clock.seconds = min(1e12 - reserved, clock.seconds + dt)
      commander.scriptState.missionCalendar = clock
    }
    return true
  }
  mutating func fireDueScriptTimers(
    flight: Bool, local: Bool, calendar: Bool, transit: Bool = false,
    publish: ScriptPublisher? = nil
  ) {
    guard !paused, flight || local || calendar || transit else { return }
    for id in orderedScriptInstances {
      guard let instance = commander.scriptState.instances[id], instance.outcome == .active,
        instance.suspension == nil, campaignExecutionIssue(instance) == nil
      else { continue }
      for key in instance.timers.keys.sorted() {
        guard commander.scriptState.instances[id]?.suspension == nil,
          var timer = commander.scriptState.instances[id]?.timers[key],
          (timer.domain == .flight && flight) || (timer.domain == .local && local)
            || (timer.domain == .calendar && calendar) || (timer.domain == .transit && transit),
          timer.clockExhausted != true, timer.due <= commander.scriptState.clock(timer.domain)
        else { continue }
        let firedAt = commander.scriptState.clock(timer.domain)
        let due = timer.due
        guard timer.pulses < 1_000_000_000 else {
          commander.scriptState.instances[id]?.suspension = "Native timer pulse limit reached."
          continue
        }
        timer.pulses += 1
        timer.lastDue = due
        timer.lastFiredAt = firedAt
        var resets: [ScriptValue] = []
        for name in timer.counters.keys.sorted() {
          var counter = timer.counters[name]!
          if counter.fire() { resets.append(.string(name)) }
          timer.counters[name] = counter
        }
        if timer.policy == .once {
          commander.scriptState.instances[id]?.timers.removeValue(forKey: key)
        } else {
          timer.due =
            timer.policy == .delay
            ? firedAt + timer.interval
            : due + (floor((firedAt - due) / timer.interval) + 1) * timer.interval
          if timer.due > 1e12 {
            timer.due = 1e12
            timer.clockExhausted = true
          }
          commander.scriptState.instances[id]?.timers[key] = timer
        }
        emitScriptEvent(
          "timer.fired",
          values: [
            "timer_id": .string(key), "pulse": .integer(Int64(timer.pulses)),
            "due": .number(due), "fired_at": .number(firedAt),
            "has_been_run": .bool(true), "clock_exhausted": .bool(timer.clockExhausted == true),
            "counters": .object(timer.counters.mapValues { .integer($0.value) }),
            "reset_counters": .array(resets),
          ], only: id, drain: false)
        // Process each callback before deciding whether another due timer still exists.
        drainScriptEvents(publish: publish)
      }
    }
    drainScriptEvents(publish: publish)
  }
  mutating func showScriptDialogue(only: UUID? = nil) -> Bool {
    guard docked, dockedAtMainStation, scriptOffer == nil else { return false }
    for id in orderedScriptInstances where only == nil || only == id {
      guard let state = commander.scriptState.instances[id], state.outcome == .active,
        state.suspension == nil,
        let dialogue = state.dialogue, dialogue.galaxy == commander.galaxy,
        dialogue.system == commander.system,
        let pack = scriptPack(for: state),
        pack.manifest.dialogs?.contains(where: { $0.id == dialogue.id }) == true
      else { continue }
      scriptOffer = id
      scriptPresentedDialogue = dialogue
      scriptConfirmSelected =
        state.contract?.offer.courier == nil && state.contract?.offer.freightPlan == nil
        && state.contract.map({ !ScriptProcurementPlan.isMarked($0.offer.parameters) }) != false
      scriptChoiceSelection = 0
      blackjackReturn = screen
      packDialogScroll = 0
      screen = .handoff
      return true
    }
    return false
  }
  mutating func confirmScriptDialogue() {
    resolveCourierTerminals()
    resolveFreightTerminals()
    guard !paused else {
      notify("RESUME TO CONFIRM MISSION CONTACT")
      return
    }
    guard let id = scriptOffer, let state = commander.scriptState.instances[id],
      let dialogue = state.dialogue,
      dialogue == scriptPresentedDialogue,
      docked, dockedAtMainStation, dialogue.galaxy == commander.galaxy,
      dialogue.system == commander.system,
      dialogue.revision == state.revision, state.suspension == nil,
      collectionQuoteFresh(dialogue, state: state)
    else {
      notify("CONTACT CHANGED - OPEN THE CONTACT AGAIN")
      closeBlackjackHandoff()
      return
    }
    if state.contract?.offer.freightPlan != nil {
      do {
        try confirmFreightDialogue(id, dialogue: dialogue, choice: selectedScriptChoice?.id)
        closeBlackjackHandoff()
        _ = showScriptDialogue(only: id)
      } catch { notify(String(error.localizedDescription.prefix(512))) }
      return
    }
    if state.contract?.offer.courier != nil {
      do {
        try confirmCourierDialogue(id, dialogue: dialogue)
        closeBlackjackHandoff()
      } catch { notify(String(error.localizedDescription.prefix(512))) }
      return
    }
    if let job = state.contract, ScriptProcurementPlan.isMarked(job.offer.parameters) {
      guard let plan = ScriptProcurementPlan.read(job.offer.parameters) else { return }
      if dialogue.id == plan.abandonContact {
        do {
          try confirmProcurementAbandon(id, dialogue: dialogue)
          closeBlackjackHandoff()
        } catch { notify(String(error.localizedDescription.prefix(512))) }
        return
      }
    }
    if dialogue.collectionQuote?.positive == false {
      notify("NO REQUESTED UNRESERVED MATERIALS AVAILABLE")
      return
    }
    var values: [String: ScriptValue] = [
      "dialogue_id": .string(dialogue.id), "token": .string(dialogue.token),
    ]
    if let choice = selectedScriptChoice { values["choice_id"] = .string(choice.id) }
    emitScriptEvent("dialogue.confirmed", values: values, only: id)
    closeBlackjackHandoff()
    if let next = commander.scriptState.instances[id], next.suspension == nil,
      next.outcome == .active, let offered = next.dialogue, offered.token != dialogue.token
    {
      // A bounded second pass settles the answer observers before presenting the next question.
      // The protected interpreter invocation has already returned; this is not recursive dispatch.
      drainScriptEvents()
      if let settled = commander.scriptState.instances[id], settled.suspension == nil,
        settled.outcome == .active, let offered = settled.dialogue, offered.token != dialogue.token
      {
        _ = showScriptDialogue(only: id)
      }
    }
  }
  mutating func offerAvailableScriptMission() -> Bool {
    guard docked, dockedAtMainStation, screen != .handoff else { return false }
    let accepted = Set(
      commander.scriptState.instances.values.filter {
        $0.definition != ScriptNavigationTradeContent.sourceID || $0.outcome == .active
      }.map(\.definition))
    guard
      let pack = scriptPacks.sorted(by: {
        ($0.manifest.priority, $0.manifest.id) < ($1.manifest.priority, $1.manifest.id)
      })
      .first(where: {
        $0.manifest.board == nil && $0.manifest.mission.parentOnly != true
          && !accepted.contains($0.manifest.stateID)
          && scriptUnavailable($0) == nil && scriptAcceptanceIssue($0) == nil
      })
    else { return false }
    scriptAvailablePackDigest = pack.digest
    scriptConfirmSelected = true
    blackjackReturn = screen
    screen = .handoff
    return true
  }
  var offeredScriptTitle: String? {
    if let digest = scriptAvailablePackDigest {
      return scriptPacks.first { $0.digest == digest }?.manifest.mission.title
    }
    guard let id = scriptOffer, let instance = commander.scriptState.instances[id] else {
      return nil
    }
    return scriptPack(for: instance)?.manifest.mission.title
  }
  var offeredScriptText: String? {
    if let digest = scriptAvailablePackDigest,
      let pack = scriptPacks.first(where: { $0.digest == digest })
    {
      return pack.manifest.mission.briefing + "\n\nDestination: "
        + pack.manifest.mission.destination + "\nReward: " + pack.manifest.mission.reward
    }
    guard let id = scriptOffer, let instance = commander.scriptState.instances[id],
      let dialogue = scriptPresentedDialogue
    else { return nil }
    let text = scriptPack(for: instance)?.manifest.dialogs?.first { $0.id == dialogue.id }?.text
    return text.map {
      $0 + (offeredCollectionText.map { "\n\n" + $0 } ?? "")
        + (navigationTradeContactText(instance).map { "\n\n" + $0 } ?? "")
    }
  }
  private func scriptGalleryEntry(_ pack: ScriptPack, stateID: UUID?) -> GalleryMission {
    if pack.manifest.providerContract != nil {
      return providerScriptGalleryEntry(pack, stateID: stateID)
    }
    let state = scriptGalleryEntryValues(stateID)
    let reason = scriptGalleryEntryReason(pack, stateID: stateID)
    let openingIssue: String?
    if pack.manifest.stateID == NativeWayfarerInduction.stateID,
      state?.milestones.contains(5) == true
    {
      openingIssue = NativeWayfarerInduction.laterStages
    } else if pack.manifest.stateID == NativeGlassMeridian.stateID,
      state?.milestones.contains(1) == true
    {
      openingIssue = NativeGlassMeridian.laterStages
    } else {
      openingIssue = nil
    }
    let suspension = state?.suspension ?? reason ?? openingIssue
    let status: GalleryStatus =
      suspension != nil
      ? .locked
      : state.map {
        switch $0.outcome {
        case .active: .active
        case .complete: .complete
        case .failed, .abandoned: .failed
        }
      } ?? .available
    let job = state?.contract
    let destination =
      job.map {
        "Galaxy \($0.offer.destinationGalaxy + 1), "
          + Universe.systemsIncludingPlugh(number: $0.offer.destinationGalaxy)[
            $0.offer.destinationSystem
          ].name
      } ?? pack.manifest.mission.destination
    let briefing: String
    let objective: String
    let displayedDestination: String
    if pack.manifest.stateID == NativeWayfarerInduction.stateID {
      briefing = NativeWayfarerInduction.currentBriefing
      objective = suspension ?? wayfarerInductionObjective
      displayedDestination = wayfarerInductionDestination
    } else {
      briefing = job?.offer.briefing ?? pack.manifest.mission.briefing
      objective = suspension ?? state?.journalLast ?? briefing
      displayedDestination = destination
    }
    return GalleryMission(
      name: job?.offer.title ?? pack.manifest.mission.title, status: status,
      objective: objective,
      briefing: briefing + scriptGalleryEntrySummary(stateID),
      destination: displayedDestination,
      reward: job.map { String(format: "%.1f CR", Double($0.offer.reward) / 10) }
        ?? pack.manifest.mission.reward,
      prerequisites: (reason ?? openingIssue).map { [$0] } ?? [],
      completed: state?.milestones.count ?? 0,
      milestones: pack.manifest.mission.milestones.enumerated().map { i, title in
        MissionMilestone(
          title: title,
          state: state?.milestones.contains(i) == true
            ? "Complete"
            : openingIssue != nil && i >= 2 ? "Locked" : "Upcoming")
      }, trialDigest: job == nil && state?.hasCampaignParent != true ? pack.digest : nil,
      savedInstance: state?.id)
  }

  @inline(never)
  private func scriptGalleryEntryValues(_ id: UUID?) -> ScriptGalleryEntryValues? {
    guard let id, let state = commander.scriptState.instances[id] else { return nil }
    return ScriptGalleryEntryValues(state)
  }

  @inline(never)
  private func scriptGalleryEntryReason(_ pack: ScriptPack, stateID: UUID?) -> String? {
    if let reason = scriptUnavailable(pack) { return reason }
    if stateID == nil && pack.manifest.mission.parentOnly == true {
      return "Start this child through its owning campaign."
    }
    if stateID == nil { return scriptAcceptanceIssue(pack) }
    guard let id = stateID, let state = commander.scriptState.instances[id] else { return nil }
    return campaignExecutionIssue(state)
  }

  @inline(never)
  private func scriptGalleryEntrySummary(_ id: UUID?) -> String {
    let state = id.flatMap { commander.scriptState.instances[$0] }
    return worldJobGallerySummary(origin: state?.id) + campaignGallerySummary(state)
      + pledgeGallerySummary(state) + courierGallerySummary(state)
  }

  @inline(never)
  private func providerScriptGalleryEntry(_ pack: ScriptPack, stateID: UUID?) -> GalleryMission {
    providerGalleryEntry(pack, state: stateID.flatMap { commander.scriptState.instances[$0] })
  }

  var scriptGallery: [GalleryMission] {
    var entries: [GalleryMission] = []
    for pack in scriptPacks.sorted(by: {
      ($0.manifest.priority, $0.manifest.id, $0.digest) < (
        $1.manifest.priority, $1.manifest.id, $1.digest
      )
    }) {
      if pack.manifest.stateID == NativeInductionClinicPack.stateID
        || pack.digest == NativeInductionClinicPack.digest
      {
        continue
      }
      if pack.manifest.stateID == NativeInductionUtilityPack.stateID
        || pack.digest == NativeInductionUtilityPack.digest
      {
        continue
      }
      if pack.manifest.stateID == NativeInductionCrewLogPack.stateID
        || pack.digest == NativeInductionCrewLogPack.digest
      {
        continue
      }
      if pack.manifest.stateID == NativeInductionArkPack.stateID
        || pack.digest == NativeInductionArkPack.digest
      {
        continue
      }
      let instances = commander.scriptState.instances.compactMap {
        key, state -> (key: UUID, id: UUID)? in
        state.definition == pack.manifest.stateID && state.digest == pack.digest
          ? (key, state.id) : nil
      }.sorted { $0.id.uuidString < $1.id.uuidString }
      if pack.manifest.board != nil {
        entries.append(scriptGalleryEntry(pack, stateID: nil))
        entries += instances.map { scriptGalleryEntry(pack, stateID: $0.key) }
      } else if instances.isEmpty {
        entries.append(scriptGalleryEntry(pack, stateID: nil))
      } else {
        entries += instances.map { scriptGalleryEntry(pack, stateID: $0.key) }
      }
    }
    let saved = commander.scriptState.instances.map { key, state in (key: key, id: state.id) }
      .sorted { $0.id.uuidString < $1.id.uuidString }
    for entry in saved {
      if let mission = missingScriptGalleryEntry(entry.key) { entries.append(mission) }
    }
    return entries
  }

  @inline(never)
  private func missingScriptGalleryEntry(_ id: UUID) -> GalleryMission? {
    guard let state = commander.scriptState.instances[id], scriptPack(for: state) == nil else {
      return nil
    }
    let pledged = commander.scriptState.pledgeLedger?.receipt(instance: state.id) != nil
    let courierTerminal = state.courier?.terminal
    return GalleryMission(
      name: state.contract?.offer.title ?? state.definition,
      status: pledged
        ? .complete
        : courierTerminal.map { $0.cause == .delivered ? .complete : .failed } ?? .locked,
      objective: pledged
        ? "Donation complete. Restore exact content for new offers."
        : "Restore the exact saved mission pack.",
      briefing: "Saved state and cargo remain intact." + campaignGallerySummary(state)
        + pledgeGallerySummary(state) + courierGallerySummary(state),
      destination: "Pack missing",
      reward: pledged ? "Local standing recorded once" : "Suspended", prerequisites: [],
      completed: state.milestones.count, milestones: [],
      savedInstance: state.id)
  }
}

extension Commander {
  /// Same public query fields; this helper introduces no owner, cache or callback.
  fileprivate var scriptBaseSnapshotFields: [String: ScriptValue] {
    [
      "galaxy": .integer(Int64(galaxy)), "system": .integer(Int64(system)),
      "jump_range_ly": .number(maximumJumpDistance),
      "fitted_equipment": ownedGearCounts(fitted: true),
      "stored_equipment": ownedGearCounts(fitted: false),
      "free_equipment_units": .integer(Int64(passengerFit?.freeEquipmentUnits ?? 0)),
      "credits": .integer(Int64(credits)),
      "free_tonnes": .integer(Int64(tradeCargoCapacity - cargoTonnes)),
      "flight_seconds": .number(scriptState.flightSeconds),
      "local_seconds": .number(scriptState.localSeconds),
      "calendar_seconds": .number(scriptState.calendarSeconds),
      "calendar_profile": scriptState.calendarLedger.map { .string($0.profile) } ?? .null,
      "transit_seconds": .number(scriptState.transitSeconds),
    ]
  }
}
