import Foundation

extension Game {
  static func worldResourceIdentity(_ name: String) -> UUID {
    ScriptIdentity.uuid(name)
  }
  mutating func ensureScriptWorldJob(
    _ command: ScriptValue, pack: ScriptPack,
    state: ScriptInstance
  ) throws {
    guard command.object.map({ Set($0.keys) == ["op", "id"] }) == true,
      let id = command["id"]?.string, state.outcome == .active,
      pack.manifest.capabilities.contains("world-resource-jobs-v2"),
      let definition = pack.manifest.worldJobs?.first(where: { $0.id == id })
    else {
      throw MissionPackError("World jobs require a declared resource owner and definition.")
    }
    let identity = Self.worldResourceIdentity("world-job-v1:\(state.id):\(id)")
    if commander.scriptState.worldJobs[identity] != nil { return }
    guard commander.scriptState.worldJobs.count < 64,
      commander.galaxy == definition.galaxy, commander.system == definition.system
    else {
      throw MissionPackError(
        "The world job requires its actual loaded owner and available job capacity.")
    }
    let resource: UUID
    if definition.owner == .station {
      let key = contractStation.key
      if let previous = commander.scriptState.stationResources[key], previous.destroyed {
        throw MissionPackError("The original station was destroyed; maintenance cannot rebuild it.")
      }
      guard docked && dockedAtMainStation || scriptAnchor.map({ $0.energy > 0 }) == true else {
        throw MissionPackError("The actual main station must exist before it can own a job.")
      }
      resource = Self.worldResourceIdentity("main-station-v1:\(key)")
      if commander.scriptState.stationResources[key] == nil {
        var station = ScriptStationResource(
          identity: resource, galaxy: commander.galaxy, system: commander.system)
        station.energy = scriptAnchor?.energy ?? 100
        commander.scriptState.stationResources[key] = station
      }
    } else {
      guard let encounter = definition.encounter, let alias = definition.actor,
        let cohort = state.ownedEncounters[encounter], cohort.admitted,
        cohort.galaxy == definition.galaxy, cohort.system == definition.system,
        let actor = cohort.actors[alias], actor.presence == .present,
        actor.body.energy > 0,
        bodies.contains(where: { $0.missionActorID == actor.identity && $0.energy > 0 })
      else {
        throw MissionPackError("A prepared, foreign or absent actor cannot own this job.")
      }
      resource = actor.identity
    }
    var timer = ScriptTimer(
      id: id, domain: .local, due: definition.firstDue,
      interval: definition.interval, policy: definition.policy)
    for name in definition.counters ?? [] { timer.counters[name] = .init() }
    commander.scriptState.worldJobs[identity] = .init(
      identity: identity,
      origin: state.id, definition: definition, resource: resource, timer: timer)
  }
  func worldJobOwnerAlive(_ job: ScriptWorldJob) -> Bool {
    if job.definition.owner == .station {
      return commander.scriptState.stationResources.values.contains {
        $0.identity == job.resource && !$0.destroyed
      }
    }
    return commander.scriptState.instances[job.origin]?.ownedEncounters.values.contains { cohort in
      cohort.admitted
        && cohort.actors.values.contains {
          $0.identity == job.resource && $0.presence != .destroyed && $0.body.energy > 0
        }
    } == true
  }
  var worldJobLocalActive: Bool {
    !paused && ![Screen.title, .demo, .gameOver].contains(screen)
  }
  mutating func recordScriptWorldResourceLoss(_ body: SpaceBody) {
    var identity = body.missionActorID
    if body.id == 0 && body.hull == .station {
      let key = contractStation.key
      if var station = commander.scriptState.stationResources[key] {
        station.energy = 0
        station.destroyed = true
        commander.scriptState.stationResources[key] = station
        identity = station.identity
        scriptReferenceFrame?.station.energy = 0
      }
    }
    guard let identity else { return }
    for id in commander.scriptState.worldJobs.keys {
      guard var job = commander.scriptState.worldJobs[id], job.resource == identity,
        job.status == .active
      else { continue }
      job.status = .cancelled
      job.cancellationReason = "Actual owner destroyed."
      job.pending = nil
      job.suspension = nil
      commander.scriptState.worldJobs[id] = job
    }
  }
  mutating func applyScriptStationResources() {
    guard let station = commander.scriptState.stationResources[contractStation.key] else { return }
    if station.destroyed {
      bodies.removeAll { $0.id == 0 && $0.hull == .station }
      scriptReferenceFrame = nil
    } else if let index = bodies.firstIndex(where: { $0.id == 0 && $0.hull == .station }) {
      bodies[index].energy = station.energy
    }
  }
  func worldJobPack(_ job: ScriptWorldJob) -> ScriptPack? {
    guard let origin = commander.scriptState.instances[job.origin],
      let pack = scriptPack(for: origin),
      scriptUnavailable(pack) == nil,
      pack.manifest.worldJobs?.contains(job.definition) == true
    else { return nil }
    return pack
  }
  mutating func suspendUnavailableWorldJobs() {
    for id in commander.scriptState.worldJobs.keys {
      guard let job = commander.scriptState.worldJobs[id], job.status == .active,
        job.suspension == nil, worldJobPack(job) == nil
      else { continue }
      commander.scriptState.worldJobs[id]?.suspension =
        "Restore the exact saved world-job content and requirements."
    }
  }
  mutating func advanceScriptWorldJobs(delta: Double, publish: ScriptPublisher? = nil) {
    guard worldJobLocalActive, delta.isFinite, delta > 0 else { return }
    for id in commander.scriptState.worldJobs.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard var job = commander.scriptState.worldJobs[id], job.status == .active,
        job.suspension == nil
      else { continue }
      guard worldJobOwnerAlive(job) else {
        job.status = .cancelled
        job.cancellationReason = "Actual owner destroyed."
        job.pending = nil
        commander.scriptState.worldJobs[id] = job
        continue
      }
      guard job.definition.galaxy == commander.galaxy,
        job.definition.system == commander.system
      else { continue }
      guard let pack = worldJobPack(job) else {
        recordWorldJobFailure(
          id,
          error: MissionPackError("Restore the exact saved world-job content and requirements."),
          publish: publish)
        continue
      }
      if job.pending == nil {
        guard job.elapsed < 1e12 else {
          recordWorldJobFailure(
            id, error: MissionPackError("World job clock limit reached."), publish: publish)
          continue
        }
        job.elapsed = min(1e12, job.elapsed + min(delta, 0.1))
        if job.timer.due <= job.elapsed && (job.timer.policy != .once || job.timer.pulses == 0) {
          guard job.timer.pulses < 1_000_000_000,
            commander.scriptState.nextEvent < UInt64(Int64.max) - 1
          else {
            recordWorldJobFailure(
              id, error: MissionPackError("World job pulse/event limit reached."), publish: publish)
            continue
          }
          let due = job.timer.due
          job.timer.pulses += 1
          job.timer.lastDue = due
          job.timer.lastFiredAt = job.elapsed
          for name in job.timer.counters.keys.sorted() { _ = job.timer.counters[name]?.fire() }
          commander.scriptState.nextEvent += 1
          job.pending = .init(
            sequence: commander.scriptState.nextEvent, due: due,
            firedAt: job.elapsed, pulse: job.timer.pulses,
            counters: job.timer.counters.mapValues(\.value))
          if job.timer.policy != .once {
            job.timer.due =
              job.timer.policy == .delay
              ? job.elapsed + job.timer.interval
              : due + (floor((job.elapsed - due) / job.timer.interval) + 1) * job.timer.interval
            job.timer.due = min(1e12, job.timer.due)
          }
        }
        commander.scriptState.worldJobs[id] = job
      }
      if job.pending != nil { dispatchScriptWorldJob(id, pack: pack, publish: publish) }
    }
  }
  mutating func recordWorldJobFailure(_ id: UUID, error: any Error, publish: ScriptPublisher?) {
    commander.scriptState.worldJobs[id]?.suspension = String(
      error.localizedDescription.prefix(1024))
    notify("WORLD JOB SUSPENDED - SEE MISSION GALLERY")
    guard error is MissionPackError, let publish else { return }
    var candidate = self
    do {
      try publish(&candidate)
      self = candidate
    } catch { return }
  }
}

extension ScriptPackLibrary {
  static func validateWorldJobs(_ manifest: ScriptManifest) throws {
    let jobs = manifest.worldJobs ?? []
    guard jobs.count <= 32, Set(jobs.map(\.id)).count == jobs.count,
      jobs.isEmpty || manifest.capabilities.contains("world-resource-jobs-v2"),
      jobs.isEmpty || manifest.capabilities.contains("pulse-counters-v2"),
      jobs.allSatisfy(\.valid)
    else { throw MissionPackError("Invalid or unsupported world-job definitions.") }
    for job in jobs {
      if job.owner == .actor {
        guard let cohort = manifest.encounters?.first(where: { $0.id == job.encounter }),
          cohort.galaxy == job.galaxy, cohort.system == job.system,
          cohort.actors.contains(where: { $0.id == job.actor })
        else {
          throw MissionPackError(
            "World-job actor owners must belong to the declared native encounter and world.")
        }
      }
      for id in job.controlledEncounters ?? [] {
        guard let cohort = manifest.encounters?.first(where: { $0.id == id }),
          cohort.galaxy == job.galaxy, cohort.system == job.system
        else {
          throw MissionPackError(
            "Controlled encounters must exist in the job owner's declared world.")
        }
      }
    }
  }
}

extension Game {
  func hasSuspendedWorldJobs(origin: UUID) -> Bool {
    commander.scriptState.worldJobs.values.contains {
      $0.origin == origin && $0.status == .active && $0.suspension != nil
    }
  }
  func worldJobSuspension(origin: UUID) -> String? {
    commander.scriptState.worldJobs.values.sorted {
      $0.identity.uuidString < $1.identity.uuidString
    }
    .first { $0.origin == origin && $0.status == .active && $0.suspension != nil }?.suspension
  }
  mutating func retryPendingWorldJobs(origin: UUID, publish: ScriptPublisher?) {
    for id in commander.scriptState.worldJobs.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let job = commander.scriptState.worldJobs[id], job.origin == origin,
        job.status == .active, job.suspension == nil, job.pending != nil,
        let pack = worldJobPack(job)
      else { continue }
      dispatchScriptWorldJob(id, pack: pack, publish: publish)
    }
  }
  func worldJobGallerySummary(origin: UUID?) -> String {
    guard let origin else { return "" }
    let jobs = commander.scriptState.worldJobs.values.filter { $0.origin == origin }
      .sorted { $0.definition.id < $1.definition.id }
    guard !jobs.isEmpty else { return "" }
    return "\n\nOngoing services:\n"
      + jobs.map {
        $0.definition.title + ": "
          + ($0.suspension.map { "Suspended - " + $0 }
            ?? $0.cancellationReason ?? $0.status.rawValue.capitalized)
          + ($0.journal.last.map { "\n" + $0 } ?? "")
      }.joined(separator: "\n")
  }
}
