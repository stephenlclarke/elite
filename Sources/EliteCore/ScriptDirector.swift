import Foundation

struct ScriptEvent: Codable, Sendable, Equatable {
  let sequence: UInt64
  let kind: String
  let instance: UUID
  let values: [String: ScriptValue]
  var value: ScriptValue {
    .object(
      values.merging(["kind": .string(kind), "sequence": .integer(Int64(sequence))]) { _, native in
        native
      })
  }
}

extension Game {
  var orderedScriptInstances: [UUID] {
    let priorities = Dictionary(
      scriptPacks.map { ($0.manifest.stateID + "@" + $0.digest, $0.manifest.priority) },
      uniquingKeysWith: { first, _ in first })
    return commander.scriptState.instances.keys.sorted { a, b in
      let left = commander.scriptState.instances[a]!
      let right = commander.scriptState.instances[b]!
      return (
        priorities[left.definition + "@" + left.digest] ?? 1001, left.definition, a.uuidString
      )
        < (
          priorities[right.definition + "@" + right.digest] ?? 1001, right.definition, b.uuidString
        )
    }
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
  mutating func suspendUnavailableScriptContent() {
    for id in orderedScriptInstances {
      guard let instance = commander.scriptState.instances[id], instance.outcome == .active,
        instance.suspension == nil
      else { continue }
      if let pack = scriptPack(for: instance), scriptUnavailable(pack) == nil { continue }
      commander.scriptState.instances[id]?.suspension =
        "Restore the exact saved mission version and its requirements."
    }
  }
  func scriptUnavailable(_ pack: ScriptPack) -> String? {
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
    .object([
      "galaxy": .integer(Int64(commander.galaxy)), "system": .integer(Int64(commander.system)),
      "docked": .bool(docked), "main_station": .bool(docked && dockedAtMainStation),
      "station_id": docked && dockedAtMainStation ? .string(contractStation.key) : .null,
      "durable_commands": .bool(scriptDurabilityAvailable),
      "jump_range_ly": .number(commander.maximumJumpDistance),
      "fitted_equipment": commander.ownedGearCounts(fitted: true),
      "stored_equipment": commander.ownedGearCounts(fitted: false),
      "free_equipment_units": .integer(Int64(commander.passengerFit?.freeEquipmentUnits ?? 0)),
      "credits": .integer(Int64(commander.credits)),
      "free_tonnes": .integer(Int64(commander.tradeCargoCapacity - commander.cargoTonnes)),
      "flight_seconds": .number(commander.scriptState.flightSeconds),
      "local_seconds": .number(commander.scriptState.localSeconds),
      "calendar_seconds": .number(commander.scriptState.calendarSeconds),
      "calendar_day": .integer(calendarDay),
      "calendar_profile": commander.scriptState.calendarLedger.map { .string($0.profile) } ?? .null,
      "transit_seconds": .number(commander.scriptState.transitSeconds),
    ])
  }
  func scopedScriptSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    var fields = scriptSnapshot.object ?? [:]
    fields["encounters"] = scriptEncounterSnapshot(instance)
    fields["passengers"] = scriptPassengerSnapshot(instance)
    fields["issued_equipment"] = scriptEquipmentSnapshot(instance)
    fields["contract"] = contractSnapshot(instance)
    fields["timers"] = .object(
      instance.timers.mapValues { timer in
        .object([
          "due": .number(timer.due), "domain": .string(timer.domain.rawValue),
          "pulse": .integer(Int64(timer.pulses)), "has_been_run": .bool(timer.pulses > 0),
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
    contract: ScriptContractJob? = nil
  ) throws -> UUID {
    guard scriptUnavailable(pack) == nil, commander.scriptState.instances.count < 128,
      commander.scriptState.instances[instanceID] == nil,
      pack.manifest.board != nil
        || !commander.scriptState.instances.values.contains(where: {
          $0.definition == pack.manifest.stateID
        }), (pack.manifest.board == nil) == (contract == nil)
    else {
      throw MissionPackError(
        "Mission unavailable, already accepted or saved under another version.")
    }
    var instance = ScriptInstance(
      id: instanceID, definition: pack.manifest.stateID,
      version: pack.manifest.version, digest: pack.digest)
    instance.randomState = randomSeed
    instance.contract = contract
    if let contract, let due = contract.deadline {
      instance.timers["contract-deadline"] = .init(
        id: "contract-deadline", domain: contract.clock, due: due, interval: 0, policy: .once)
    }
    var candidate = self
    candidate.ensureScriptCalendar(origin: .newCommander)
    if pack.manifest.capabilities.contains("owned-equipment-v2") {
      candidate.commander.synchronizeEquipmentInventory(force: true)
    }
    candidate.commander.scriptState.instances[instance.id] = instance
    candidate.emitScriptEvent("mission.accepted", only: instance.id)
    if let reason = candidate.commander.scriptState.instances[instance.id]?.suspension {
      throw MissionPackError(reason)
    }
    self = candidate
    return instance.id
  }
  mutating func emitScriptEvent(
    _ kind: String, values: [String: ScriptValue] = [:], only: UUID? = nil, drain: Bool = true
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
          sequence: commander.scriptState.nextEvent, kind: kind, instance: id, values: values))
    }
    if drain { drainScriptEvents() }
  }
  mutating func drainScriptEvents(publish: ScriptPublisher? = nil) {
    guard !scriptDispatching, !scriptEventsDeferred else { return }
    scriptDispatching = true
    defer { scriptDispatching = false }
    // Work is bounded per actor turn; suspended facts remain saved for explicit recovery.
    let events = commander.scriptState.pendingEvents.prefix(64)
    for event in events {
      guard let instance = commander.scriptState.instances[event.instance],
        instance.suspension == nil
      else { continue }
      guard let pack = scriptPack(for: instance), scriptUnavailable(pack) == nil else {
        commander.scriptState.instances[event.instance]?.suspension =
          "Restore the exact saved mission version and its requirements."
        continue
      }
      if instance.outcome != .active || instance.acknowledgedEvents.contains(event.sequence) {
        commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
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
          if command["op"]?.string == "encounter.ensure" {
            guard let fields = command.object, Set(fields.keys) == ["op", "id"],
              let id = command["id"]?.string
            else {
              throw MissionPackError("Encounter request requires only op and declared id.")
            }
            derivedEvents.append(try candidate.ensureScriptEncounter(id, pack: pack, state: &next))
          } else if command["op"]?.string == "actor.intent" {
            if let result = try candidate.applyScriptNPCIntent(command, pack: pack, state: &next) {
              derivedEvents.append(result)
            }
          } else if ["gear.issue", "gear.return", "gear.release", "gear.store", "gear.refit"]
            .contains(command["op"]?.string ?? "")
          {
            if let result = try candidate.applyScriptGearCommand(
              command, pack: pack, state: &next, candidate: &candidate.commander)
            {
              derivedEvents.append(result)
            }
          } else if ["passengers.board", "passengers.deliver"].contains(command["op"]?.string ?? "")
          {
            try candidate.applyPassengerCommand(
              command, pack: pack, state: &next, candidate: &candidate.commander)
          } else {
            try applyScriptCommand(
              command, event: event, pack: pack, state: &next, candidate: &candidate.commander)
          }
        }
        next.revision += 1
        next.acknowledgedEvents.insert(event.sequence)
        candidate.commander.scriptState.instances[next.id] = next
        candidate.commander.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
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
        self = candidate
      } catch {
        recordScriptFailure(event.instance, error: error, publish: publish)
      }
    }
  }
  mutating func advanceScriptClocks(
    delta: Double, flight: Bool, local: Bool, calendar: Bool = false,
    publish: ScriptPublisher? = nil
  ) {
    guard advanceScriptClockValues(delta: delta, flight: flight, local: local, calendar: calendar)
    else { return }
    fireDueScriptTimers(flight: flight, local: local, calendar: calendar, publish: publish)
  }
  mutating func advanceScriptClockValues(delta: Double, flight: Bool, local: Bool, calendar: Bool)
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
    return true
  }
  mutating func fireDueScriptTimers(
    flight: Bool, local: Bool, calendar: Bool, publish: ScriptPublisher? = nil
  ) {
    guard !paused, flight || local || calendar else { return }
    // Transit still requires a real admitted native wormhole journey.
    for id in orderedScriptInstances {
      guard let instance = commander.scriptState.instances[id], instance.outcome == .active,
        instance.suspension == nil
      else { continue }
      for key in instance.timers.keys.sorted() {
        guard commander.scriptState.instances[id]?.suspension == nil,
          var timer = commander.scriptState.instances[id]?.timers[key],
          (timer.domain == .flight && flight) || (timer.domain == .local && local)
            || (timer.domain == .calendar && calendar),
          timer.due <= commander.scriptState.clock(timer.domain)
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
          commander.scriptState.instances[id]?.timers[key] = timer
        }
        emitScriptEvent(
          "timer.fired",
          values: [
            "timer_id": .string(key), "pulse": .integer(Int64(timer.pulses)),
            "due": .number(due), "fired_at": .number(firedAt),
            "has_been_run": .bool(true),
            "counters": .object(timer.counters.mapValues { .integer($0.value) }),
            "reset_counters": .array(resets),
          ], only: id, drain: false)
        // Process each callback before deciding whether another due timer still exists.
        drainScriptEvents(publish: publish)
      }
    }
    drainScriptEvents(publish: publish)
  }
  mutating func showScriptDialogue() -> Bool {
    guard docked, dockedAtMainStation, scriptOffer == nil else { return false }
    for id in orderedScriptInstances {
      guard let state = commander.scriptState.instances[id], state.outcome == .active,
        state.suspension == nil,
        let dialogue = state.dialogue, dialogue.galaxy == commander.galaxy,
        dialogue.system == commander.system,
        let pack = scriptPack(for: state),
        pack.manifest.dialogs?.contains(where: { $0.id == dialogue.id }) == true
      else { continue }
      scriptOffer = id
      scriptConfirmSelected = true
      blackjackReturn = screen
      packDialogScroll = 0
      screen = .handoff
      return true
    }
    return false
  }
  mutating func confirmScriptDialogue() {
    guard !paused else {
      notify("RESUME TO CONFIRM MISSION CONTACT")
      return
    }
    guard let id = scriptOffer, let state = commander.scriptState.instances[id],
      let dialogue = state.dialogue,
      docked, dockedAtMainStation, dialogue.galaxy == commander.galaxy,
      dialogue.system == commander.system,
      dialogue.revision == state.revision, state.suspension == nil
    else {
      notify("CONTACT CHANGED - OPEN THE CONTACT AGAIN")
      closeBlackjackHandoff()
      return
    }
    emitScriptEvent(
      "dialogue.confirmed",
      values: ["dialogue_id": .string(dialogue.id), "token": .string(dialogue.token)], only: id)
    closeBlackjackHandoff()
  }
  mutating func offerAvailableScriptMission() -> Bool {
    guard docked, dockedAtMainStation, screen != .handoff else { return false }
    let accepted = Set(commander.scriptState.instances.values.map(\.definition))
    guard
      let pack = scriptPacks.sorted(by: {
        ($0.manifest.priority, $0.manifest.id) < ($1.manifest.priority, $1.manifest.id)
      })
      .first(where: {
        $0.manifest.board == nil && !accepted.contains($0.manifest.stateID)
          && scriptUnavailable($0) == nil
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
      let dialogue = instance.dialogue
    else { return nil }
    return scriptPack(for: instance)?.manifest.dialogs?.first { $0.id == dialogue.id }?.text
  }
  private func scriptGalleryEntry(_ pack: ScriptPack, state: ScriptInstance?) -> GalleryMission {
    let reason = scriptUnavailable(pack)
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
      briefing: job?.offer.briefing ?? pack.manifest.mission.briefing, destination: destination,
      reward: job.map { String(format: "%.1f CR", Double($0.offer.reward) / 10) }
        ?? pack.manifest.mission.reward,
      prerequisites: reason.map { [$0] } ?? [], completed: state?.milestones.count ?? 0,
      milestones: pack.manifest.mission.milestones.enumerated().map { i, title in
        MissionMilestone(
          title: title, state: state?.milestones.contains(i) == true ? "Complete" : "Upcoming")
      }, trialDigest: job == nil ? pack.digest : nil, savedInstance: state?.id)
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
      } else {
        entries.append(scriptGalleryEntry(pack, state: instances.first))
      }
    }
    for state in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) where scriptPack(for: state) == nil {
      entries.append(
        GalleryMission(
          name: state.contract?.offer.title ?? state.definition, status: .locked,
          objective: "Restore the exact saved mission pack.",
          briefing: "Saved state and cargo remain intact.", destination: "Pack missing",
          reward: "Suspended", prerequisites: [], completed: state.milestones.count, milestones: [])
      )
    }
    return entries
  }
}
