import Foundation

extension Game {
  mutating func dispatchScriptWorldJob(_ id: UUID, pack: ScriptPack, publish: ScriptPublisher?) {
    guard let job = commander.scriptState.worldJobs[id], job.status == .active,
      job.suspension == nil, let pulse = job.pending, worldJobOwnerAlive(job),
      let origin = commander.scriptState.instances[job.origin]
    else { return }
    var world = scopedScriptSnapshot(origin).object ?? [:]
    world["parent_outcome"] = .string(origin.outcome.rawValue)
    world["job"] = .object([
      "id": .string(job.definition.id),
      "identity": .string(job.identity.uuidString), "resource_id": .string(job.resource.uuidString),
      "elapsed": .number(job.elapsed), "status": .string(job.status.rawValue),
    ])
    let event: ScriptValue = .object([
      "kind": .string("world.job.pulse"),
      "sequence": .integer(Int64(pulse.sequence)), "job_id": .string(job.definition.id),
      "resource_id": .string(job.resource.uuidString), "due": .number(pulse.due),
      "fired_at": .number(pulse.firedAt), "pulse": .integer(Int64(pulse.pulse)),
      "counters": .object(pulse.counters.mapValues(ScriptValue.integer)),
    ])
    do {
      let result = try ScriptEvaluator.evaluate(
        source: pack.source,
        handler: job.definition.handler, event: event, snapshot: .object(world), state: job.data)
      var candidate = self
      var next = job
      next.data = result.data
      var owner = origin
      var derived: [(String, [String: ScriptValue])] = []
      for command in result.commands {
        guard next.status == .active else {
          throw MissionPackError("A terminal world job cannot issue further actions.")
        }
        switch command["op"]?.string {
        case "encounter.ensure":
          guard command.object.map({ Set($0.keys) == ["op", "id"] }) == true,
            let encounter = command["id"]?.string,
            next.definition.controlledEncounters?.contains(encounter) == true
          else {
            throw MissionPackError("This job has no declared right to deploy that encounter.")
          }
          derived.append(
            try candidate.ensureScriptEncounter(
              encounter, pack: pack,
              state: &owner, worldJobID: id, worldJobPulse: pulse.sequence))
        case "actor.repair":
          try candidate.applyWorldJobRepair(command, job: &next, origin: &owner)
        case "job.finish":
          guard command.object.map({ Set($0.keys) == ["op"] }) == true else {
            throw MissionPackError("Job completion accepts only op; it cannot finish a mission.")
          }
          next.status = .complete
        case "job.journal.append":
          guard command.object.map({ Set($0.keys) == ["op", "text"] }) == true,
            let text = command["text"]?.string, (1...12000).contains(text.utf8.count),
            next.journal.count < 512
          else { throw MissionPackError("Invalid world-job journal entry.") }
          next.journal.append(text)
        case "job.counter.reset", "job.counter.enable":
          try Self.applyWorldJobCounter(command, job: &next)
        default:
          throw MissionPackError(
            "World jobs cannot change mission outcomes, rewards, cargo, people or equipment.")
        }
      }
      next.acknowledgedThrough = pulse.sequence
      next.pending = nil
      candidate.commander.scriptState.worldJobs[id] = next
      candidate.commander.scriptState.instances[origin.id] = owner
      for (kind, values) in derived {
        candidate.emitScriptEvent(kind, values: values, only: origin.id, drain: false)
      }
      guard candidate.commander.valid else {
        throw MissionPackError("The world job's entire proposal failed native validation.")
      }
      try publish?(&candidate)
      self = candidate
    } catch { recordWorldJobFailure(id, error: error, publish: publish) }
  }
  private mutating func applyWorldJobRepair(
    _ command: ScriptValue, job: inout ScriptWorldJob,
    origin: inout ScriptInstance
  ) throws {
    guard
      command.object.map({ Set($0.keys) == ["op", "id", "encounter", "actor", "amount"] }) == true,
      let receipt = command["id"]?.string, PackValidation.localID(receipt),
      let encounterID = command["encounter"]?.string, let alias = command["actor"]?.string,
      let amount = command["amount"]?.double, amount.isFinite, (0.001...1_000_000).contains(amount),
      var encounter = origin.ownedEncounters[encounterID], encounter.admitted,
      encounter.galaxy == job.definition.galaxy, encounter.system == job.definition.system,
      var actor = encounter.actors[alias], actor.presence != .destroyed, actor.body.energy > 0,
      let fit = actor.body.scriptNPC?.fit,
      actor.identity == job.resource
        || job.definition.controlledEncounters?.contains(encounterID) == true
    else {
      throw MissionPackError(
        "Repair requires a living, owned measured NPC in this job's declared world.")
    }
    if job.receipts.contains(receipt) { return }
    guard job.receipts.count < 4096 else {
      throw MissionPackError("World-job repair receipt limit reached.")
    }
    actor.body.energy = max(
      actor.body.energy, min(fit.definition.energy, actor.body.energy + amount))
    encounter.actors[alias] = actor
    origin.ownedEncounters[encounterID] = encounter
    if let index = bodies.firstIndex(where: { $0.missionActorID == actor.identity }) {
      guard bodies[index].energy > 0 else {
        throw MissionPackError("Fatal damage cannot be repaired.")
      }
      bodies[index].energy = actor.body.energy
    }
    job.receipts.insert(receipt)
  }
  private static func applyWorldJobCounter(_ command: ScriptValue, job: inout ScriptWorldJob) throws
  {
    let enable = command["op"]?.string == "job.counter.enable"
    guard
      command.object.map({ Set($0.keys) == (enable ? ["op", "name", "enabled"] : ["op", "name"]) })
        == true,
      let name = command["name"]?.string, var counter = job.timer.counters[name]
    else {
      throw MissionPackError("World-job counter commands require a declared native counter.")
    }
    if enable {
      guard case .bool(let value) = command["enabled"] else {
        throw MissionPackError("World-job counter enable requires a Boolean.")
      }
      counter.enabled = value
    } else {
      counter.enabled = true
      counter.resetOnNextPulse = true
    }
    job.timer.counters[name] = counter
  }
}
