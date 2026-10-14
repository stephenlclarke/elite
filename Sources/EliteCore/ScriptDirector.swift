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
  func scriptUnavailable(_ pack: ScriptPack) -> String? {
    if !pack.missingCapabilities.isEmpty {
      return "Requires: " + pack.missingCapabilities.joined(separator: ", ")
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
      "credits": .integer(Int64(commander.credits)),
      "free_tonnes": .integer(Int64(commander.capacity - commander.cargoTonnes)),
      "flight_seconds": .number(commander.scriptState.flightSeconds),
      "local_seconds": .number(commander.scriptState.localSeconds),
      "calendar_seconds": .number(commander.scriptState.calendarSeconds),
      "transit_seconds": .number(commander.scriptState.transitSeconds),
    ])
  }
  mutating func acceptScriptMission(_ pack: ScriptPack, instanceID: UUID = UUID()) throws -> UUID {
    guard scriptUnavailable(pack) == nil, commander.scriptState.instances.count < 128,
      commander.scriptState.instances[instanceID] == nil,
      !commander.scriptState.instances.values.contains(where: {
        $0.definition == pack.manifest.stateID
      })
    else {
      throw MissionPackError(
        "Mission unavailable, already accepted or saved under another version.")
    }
    let instance = ScriptInstance(
      id: instanceID, definition: pack.manifest.stateID,
      version: pack.manifest.version, digest: pack.digest)
    var candidate = self
    candidate.commander.scriptState.instances[instance.id] = instance
    candidate.emitScriptEvent("mission.accepted", only: instance.id)
    if let reason = candidate.commander.scriptState.instances[instance.id]?.suspension {
      throw MissionPackError(reason)
    }
    self = candidate
    return instance.id
  }
  mutating func emitScriptEvent(
    _ kind: String, values: [String: ScriptValue] = [:], only: UUID? = nil
  ) {
    for id in commander.scriptState.instances.keys.sorted(by: { $0.uuidString < $1.uuidString })
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
    drainScriptEvents()
  }
  mutating func drainScriptEvents() {
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
          event: event.value, snapshot: scriptSnapshot, state: instance.data)
        var candidate = commander
        var next = instance
        next.data = result.data
        for command in result.commands {
          try applyScriptCommand(
            command, event: event, pack: pack, state: &next, candidate: &candidate)
        }
        next.revision += 1
        next.acknowledgedEvents.insert(event.sequence)
        candidate.scriptState.instances[next.id] = next
        candidate.scriptState.pendingEvents.removeAll { $0.sequence == event.sequence }
        guard candidate.valid else {
          throw MissionPackError("Mission transfer cannot fit the commander or saved state.")
        }
        commander = candidate
      } catch {
        commander.scriptState.instances[event.instance]?.suspension = error.localizedDescription
        notify("MISSION SUSPENDED - SEE MISSION GALLERY")
      }
    }
  }
  mutating func advanceScriptClocks(delta: Double, flight: Bool, local: Bool) {
    guard !commander.scriptState.instances.isEmpty, delta.isFinite, delta > 0, !paused else {
      return
    }
    let dt = min(delta, 0.1)
    if local { commander.scriptState.localSeconds += dt }
    if flight { commander.scriptState.flightSeconds += dt }
    // Calendar/transit require explicit native travel admission; no invented wall-time progression.
    for id in commander.scriptState.instances.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let instance = commander.scriptState.instances[id], instance.outcome == .active,
        instance.suspension == nil
      else { continue }
      for key in instance.timers.keys.sorted() {
        guard var timer = commander.scriptState.instances[id]?.timers[key],
          timer.due <= commander.scriptState.clock(timer.domain)
        else { continue }
        let firedAt = commander.scriptState.clock(timer.domain)
        let due = timer.due
        timer.pulses += 1
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
          ], only: id)
      }
    }
    drainScriptEvents()
  }
  mutating func showScriptDialogue() -> Bool {
    guard docked, dockedAtMainStation, scriptOffer == nil else { return false }
    for id in commander.scriptState.instances.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
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
      .first(where: { !accepted.contains($0.manifest.stateID) && scriptUnavailable($0) == nil })
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
  var scriptGallery: [GalleryMission] {
    var entries: [GalleryMission] = []
    for pack in scriptPacks.sorted(by: {
      ($0.manifest.priority, $0.manifest.id, $0.digest) < (
        $1.manifest.priority, $1.manifest.id, $1.digest
      )
    }) {
      let instances = commander.scriptState.instances.values.filter {
        $0.definition == pack.manifest.stateID && $0.digest == pack.digest
      }
      let reason = scriptUnavailable(pack)
      let state = instances.first
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
      entries.append(
        GalleryMission(
          name: pack.manifest.mission.title, status: status,
          objective: suspension ?? state?.journal.last ?? pack.manifest.mission.briefing,
          briefing: pack.manifest.mission.briefing, destination: pack.manifest.mission.destination,
          reward: pack.manifest.mission.reward, prerequisites: reason.map { [$0] } ?? [],
          completed: state?.milestones.count ?? 0,
          milestones: pack.manifest.mission.milestones.enumerated().map { i, title in
            MissionMilestone(
              title: title, state: state?.milestones.contains(i) == true ? "Complete" : "Upcoming")
          }))
    }
    for state in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) where scriptPack(for: state) == nil {
      entries.append(
        GalleryMission(
          name: state.definition, status: .locked,
          objective: "Restore the exact saved mission pack.",
          briefing: "Saved state and cargo remain intact.", destination: "Pack missing",
          reward: "Suspended", prerequisites: [], completed: state.milestones.count, milestones: [])
      )
    }
    return entries
  }
}
