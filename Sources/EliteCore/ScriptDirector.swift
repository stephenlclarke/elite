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
    if let reason = navigationTradeUnavailable(
      pack, binding: navigationBinding ?? ScriptNavigationTradeBinding.production(in: self))
    {
      return reason
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
    let state = try providerContractAcceptanceState(pack, facts: facts, instance: instanceID)
    let instance = try prepareScriptMissionAcceptance(
      pack, instanceID: instanceID,
      randomSeed: 0x45_4c49_5445, contract: nil, campaignParent: nil, providerState: state)
    return try installScriptMissionAcceptance(pack, instance: instance, drainAccepted: true)
  }
  // Preparation borrows self through a mutating receiver but does not change the game.
  private mutating func prepareScriptMissionAcceptance(
    _ pack: ScriptPack, instanceID: UUID, randomSeed: UInt64,
    contract: ScriptContractJob?, campaignParent: ScriptChildBinding?,
    providerState: ScriptProviderContractState? = nil,
    freightAdmission: ScriptFreightIssueAdmission? = nil,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> ScriptInstance {
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
    var instance = ScriptInstance(
      id: instanceID, definition: pack.manifest.stateID,
      version: pack.manifest.version, digest: pack.digest)
    instance.receiptJoins = try scriptReceiptJoins(pack, stage: .acceptance, existing: [:])
    instance.savedProviderContract = providerState
    if let providerState { instance.payloads[providerState.terms.payload] = 1 }
    instance.randomState = randomSeed
    instance.contract = contract
    if pack.manifest.freight != nil {
      guard let freightAdmission, contract?.offer.freightPlan?.matches(pack) == true else {
        throw MissionPackError("Supplied freight requires native issue admission.")
      }
      try freightAdmission.issue(into: &instance, game: self)
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
    return instance
  }
  private mutating func installScriptMissionAcceptance(
    _ pack: ScriptPack, instance: ScriptInstance, drainAccepted: Bool
  ) throws -> UUID {
    var candidate = self
    candidate.ensureScriptCalendar(origin: .newCommander)
    if pack.manifest.capabilities.contains("owned-equipment-v2") {
      try candidate.commander.prepareEquipment()
    }
    candidate.commander.scriptState.instances[instance.id] = instance
    candidate.emitScriptEvent("mission.accepted", only: instance.id, drain: drainAccepted)
    if let reason = candidate.commander.scriptState.instances[instance.id]?.suspension {
      throw MissionPackError(reason)
    }
    publishScriptMissionAcceptance(&candidate)
    return instance.id
  }
  private mutating func publishScriptMissionAcceptance(_ candidate: inout Game) {
    self = candidate
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
    // Work is bounded per actor turn; suspended facts remain saved for explicit recovery.
    let events = commander.scriptState.pendingEvents.prefix(64)
    for event in events {
      guard let instance = commander.scriptState.instances[event.instance],
        instance.suspension == nil
      else { continue }
      guard let pack = scriptPack(for: instance),
        scriptUnavailable(pack, navigationBinding: navigationBinding) == nil
      else {
        commander.scriptState.instances[event.instance]?.suspension =
          "Restore the exact saved mission version and its requirements."
        continue
      }
      if instance.outcome != .active || instance.hasAcknowledged(event.sequence) {
        commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
        continue
      }
      if let reason = campaignExecutionIssue(instance) ?? campaignContentIssue(instance, pack: pack)
        ?? procurementContentIssue(instance, pack: pack)
        ?? freightContentIssue(instance, pack: pack)
      {
        commander.scriptState.instances[event.instance]?.suspension = reason
        continue
      }
      guard let handler = pack.manifest.handlers.first(where: { $0.event == event.kind }) else {
        commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
        continue
      }
      do {
        let result = try ScriptEvaluator.evaluate(
          source: pack.source, handler: handler.function,
          event: event.value, snapshot: scopedScriptSnapshot(instance), state: instance.data)
        var candidate = self
        var derivedEvents: [(String, [String: ScriptValue])] = []
        var next = instance
        next.data = result.data
        for command in result.commands {
          if pack.manifest.capabilities.contains(ScriptNavigationTradeContent.capability) {
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
          if command["op"]?.string?.hasPrefix("training.trade.") == true {
            try applyNavigationTradeCommand(
              command, event: event, pack: pack, state: &next,
              binding: navigationBinding ?? ScriptNavigationTradeBinding.production(in: self))
            continue
          }
          if pack.manifest.freight != nil,
            !["journal.append", "dialogue.offer"].contains(command["op"]?.string ?? "")
          {
            throw MissionPackError("Freight scripts may present native contacts only.")
          }
          if pack.manifest.procurement != nil,
            !["journal.append", "dialogue.offer", "collection.ensure", "collection.deliver"]
              .contains(command["op"]?.string ?? "")
          {
            throw MissionPackError(
              "Procurement scripts may present contacts and request real material lots only.")
          }
          if pack.manifest.providerContract != nil,
            !["journal.append", "dialogue.offer"].contains(command["op"]?.string ?? "")
          {
            throw MissionPackError("Provider scripts may present finite native transitions only.")
          }
          if pack.manifest.courier != nil,
            ![
              "milestone.ensure", "journal.append", "dialogue.offer", "courier.issue",
              "courier.deliver", "courier.abandon",
            ].contains(command["op"]?.string ?? "")
          {
            throw MissionPackError("Courier handlers require closed native custody commands.")
          }
          if pack.manifest.pledge != nil,
            !["milestone.ensure", "journal.append", "pledge.commit"].contains(
              command["op"]?.string ?? "")
          {
            throw MissionPackError(
              "A pledge handler may only record its objective and commit the native donation.")
          }
          if pack.manifest.pledge != nil, next.outcome != .active {
            throw MissionPackError("A completed pledge cannot issue another command.")
          }
          if ["courier.issue", "courier.deliver", "courier.abandon"].contains(
            command["op"]?.string ?? "")
          {
            try Self.dispatchCourierCommand(
              command, event: event, pack: pack, state: &next, candidate: &candidate)
          } else if command["op"]?.string == "pledge.commit" {
            try Self.dispatchPledgeCommand(
              command, event: event, pack: pack, state: &next, candidate: &candidate)
          } else if command["op"]?.string == "child.ensure" {
            if let result = try candidate.ensureCampaignChild(
              command, pack: pack, state: &next, event: event)
            {
              derivedEvents.append(result)
            }
          } else if command["op"]?.string == "finance.offer" {
            try candidate.registerFinanceOffer(command, event: event, pack: pack, state: next)
          } else if ["collection.ensure", "collection.deliver"].contains(
            command["op"]?.string ?? "")
          {
            if let result = try Self.dispatchCollectionCommand(
              command, event: event, pack: pack, state: &next, candidate: &candidate)
            {
              derivedEvents.append(result)
            }
          } else if command["op"]?.string == "book.unlock" {
            if let result = try candidate.unlockScriptBook(
              command, pack: pack, state: next, event: event)
            {
              derivedEvents.append(result)
            }
          } else if command["op"]?.string == "world.job.ensure" {
            try candidate.ensureScriptWorldJob(command, pack: pack, state: next)
          } else if command["op"]?.string == "encounter.ensure" {
            guard let fields = command.object, Set(fields.keys) == ["op", "id"],
              let id = command["id"]?.string
            else {
              throw MissionPackError("Encounter request requires only op and declared id.")
            }
            derivedEvents.append(try candidate.ensureScriptEncounter(id, pack: pack, state: &next))
            // Later native commands must join bodies to their already staged private owner.
            candidate.commander.scriptState.instances[next.id] = next
          } else if command["op"]?.string == "actor.intent" {
            if let result = try candidate.applyScriptNPCIntent(command, pack: pack, state: &next) {
              derivedEvents.append(result)
            }
          } else if ["gear.issue", "gear.return", "gear.release", "gear.store", "gear.refit"]
            .contains(command["op"]?.string ?? "")
          {
            if let result = try Self.dispatchGearCommand(
              command, event: event, pack: pack, state: &next, candidate: &candidate)
            {
              derivedEvents.append(result)
            }
          } else if ["passengers.board", "passengers.deliver"].contains(command["op"]?.string ?? "")
          {
            try Self.dispatchPassengerCommand(
              command, pack: pack, state: &next, candidate: &candidate)
          } else {
            try Self.dispatchStandardCommand(
              command, event: event, pack: pack, state: &next,
              original: self, candidate: &candidate)
          }
          if pack.manifest.providerContract != nil, command["op"]?.string == "journal.append",
            let text = command["text"]?.string
          {
            candidate.notify(text)
          }
        }
        try Self.finishScriptEventCandidate(
          original: self, candidate: &candidate, instance: instance, next: &next,
          event: event, pack: pack, derivedEvents: &derivedEvents, publish: publish,
          clueTrust: clueTrust)
        self = candidate
      } catch let refusal as ScriptNavigationTradeRefusal {
        // A refused user confirmation commits no proposal effects and cannot replay later.
        commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
        commander.scriptState.instances[event.instance]?.acknowledge(event.sequence)
        commander.scriptState.instances[event.instance]?.dialogue = nil
        notify(refusal.message)
      } catch {
        recordScriptFailure(event.instance, error: error, publish: publish)
      }
    }
  }
  /// Finalization runs after command admission returns, so its resource/save temporaries
  /// do not share the nested actor-admission stack. Publication stays in this actor turn.
  private static func finishScriptEventCandidate(
    original: borrowing Game, candidate: inout Game,
    instance: ScriptInstance, next: inout ScriptInstance,
    event: ScriptEvent, pack: ScriptPack,
    derivedEvents: inout [(String, [String: ScriptValue])], publish: ScriptPublisher?,
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
    candidate.suspendTerminalCampaignChildren(next)
    candidate.commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
    if let receipt = next.completionReceipt { try candidate.enqueueScriptCompletion(receipt) }
    guard candidate.commander.valid else {
      throw MissionPackError(
        candidate.commander.passengerFit?.issues.first
          ?? "Mission transfer cannot fit the commander or saved state.")
    }
    guard candidate.commander.scriptState.pendingEvents.count + derivedEvents.count <= 4096,
      candidate.commander.scriptState.nextEvent <= UInt64(Int64.max) - 1
        - UInt64(derivedEvents.count)
    else { throw MissionPackError("The native result queue cannot fit this whole proposal.") }
    // Admission/result envelopes belong to the same durable generation as their cause.
    for (kind, values) in derivedEvents {
      candidate.emitScriptEvent(kind, values: values, only: next.id, drain: false)
    }
    let savedBytes = try JSONEncoder().encode(candidate.commander.scriptState)
    guard savedBytes.count <= 33_554_432 else {
      throw MissionPackError("Mission save budget exceeded; proposal was not committed.")
    }
    try publish?(&candidate)
  }
  // Separate branch frames keep commander-borrow receiver copies out of encounter admission.
  private static func dispatchCourierCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Game
  ) throws {
    try candidate.applyCourierCommand(
      command, event: event, pack: pack, state: &state, candidate: &candidate.commander)
  }
  private static func dispatchPledgeCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Game
  ) throws {
    try candidate.applyPledgeCommand(
      command, event: event, pack: pack, state: &state, candidate: &candidate.commander)
  }
  private static func dispatchCollectionCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Game
  ) throws -> (String, [String: ScriptValue])? {
    try candidate.applyCollectionCommand(
      command, event: event, pack: pack, state: &state, candidate: &candidate.commander)
  }
  private static func dispatchGearCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Game
  ) throws -> (String, [String: ScriptValue])? {
    try candidate.applyScriptGearCommand(
      command, event: event, pack: pack, state: &state, candidate: &candidate.commander)
  }
  private static func dispatchPassengerCommand(
    _ command: ScriptValue, pack: ScriptPack, state: inout ScriptInstance, candidate: inout Game
  ) throws {
    try candidate.applyPassengerCommand(
      command, pack: pack, state: &state, candidate: &candidate.commander)
  }
  private static func dispatchStandardCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, original: Game, candidate: inout Game
  ) throws {
    // Standard commands intentionally query the original event transaction snapshot.
    try original.applyScriptCommand(
      command, event: event, pack: pack, state: &state, candidate: &candidate.commander)
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
    flight: Bool, local: Bool, calendar: Bool, publish: ScriptPublisher? = nil
  ) {
    guard !paused, flight || local || calendar else { return }
    // Transit still requires a real admitted native wormhole journey.
    for id in orderedScriptInstances {
      guard let instance = commander.scriptState.instances[id], instance.outcome == .active,
        instance.suspension == nil, campaignExecutionIssue(instance) == nil
      else { continue }
      for key in instance.timers.keys.sorted() {
        guard commander.scriptState.instances[id]?.suspension == nil,
          var timer = commander.scriptState.instances[id]?.timers[key],
          (timer.domain == .flight && flight) || (timer.domain == .local && local)
            || (timer.domain == .calendar && calendar),
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
  private func scriptGalleryEntry(_ pack: ScriptPack, state: ScriptInstance?) -> GalleryMission {
    if pack.manifest.providerContract != nil { return providerGalleryEntry(pack, state: state) }
    let reason =
      scriptUnavailable(pack)
      ?? (state == nil && pack.manifest.mission.parentOnly == true
        ? "Start this child through its owning campaign." : nil)
      ?? (state == nil ? scriptAcceptanceIssue(pack) : nil)
      ?? state.flatMap { campaignExecutionIssue($0) }
    let suspension = state?.suspension ?? reason
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
    return GalleryMission(
      name: job?.offer.title ?? pack.manifest.mission.title, status: status,
      objective: suspension ?? state?.journal.last ?? pack.manifest.mission.briefing,
      briefing: (job?.offer.briefing ?? pack.manifest.mission.briefing)
        + worldJobGallerySummary(origin: state?.id) + campaignGallerySummary(state)
        + pledgeGallerySummary(state) + courierGallerySummary(state),
      destination: destination,
      reward: job.map { String(format: "%.1f CR", Double($0.offer.reward) / 10) }
        ?? pack.manifest.mission.reward,
      prerequisites: reason.map { [$0] } ?? [], completed: state?.milestones.count ?? 0,
      milestones: pack.manifest.mission.milestones.enumerated().map { i, title in
        MissionMilestone(
          title: title, state: state?.milestones.contains(i) == true ? "Complete" : "Upcoming")
      }, trialDigest: job == nil && state?.campaignParent == nil ? pack.digest : nil,
      savedInstance: state?.id)
  }

  var scriptGallery: [GalleryMission] {
    var entries: [GalleryMission] = []
    for pack in scriptPacks.sorted(by: {
      ($0.manifest.priority, $0.manifest.id, $0.digest) < (
        $1.manifest.priority, $1.manifest.id, $1.digest
      )
    }) {
      let instances = commander.scriptState.instances.values.filter {
        $0.definition == pack.manifest.stateID && $0.digest == pack.digest
      }.sorted { $0.id.uuidString < $1.id.uuidString }
      if pack.manifest.board != nil {
        entries.append(scriptGalleryEntry(pack, state: nil))
        entries += instances.map { scriptGalleryEntry(pack, state: $0) }
      } else if instances.isEmpty {
        entries.append(scriptGalleryEntry(pack, state: nil))
      } else {
        entries += instances.map { scriptGalleryEntry(pack, state: $0) }
      }
    }
    for state in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) where scriptPack(for: state) == nil {
      let pledged = commander.scriptState.pledgeLedger?.receipt(instance: state.id) != nil
      let courierTerminal = state.courier?.terminal
      entries.append(
        GalleryMission(
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
      )
    }
    return entries
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
