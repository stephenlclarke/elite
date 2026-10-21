import Foundation

public enum ScriptWorldJobOwner: String, Codable, Sendable { case station, actor }
public struct ScriptWorldJobDefinition: Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let handler: String
  public let owner: ScriptWorldJobOwner
  public let galaxy: Int
  public let system: Int
  public let encounter: String?
  public let actor: String?
  public let firstDue: Double
  public let interval: Double
  public let policy: ScriptTimerPolicy
  public let counters: [String]?
  public let controlledEncounters: [String]?
  var valid: Bool {
    PackValidation.localID(id) && (1...160).contains(title.utf8.count)
      && handler.range(of: "^[A-Za-z_][A-Za-z0-9_]{0,79}$", options: .regularExpression) != nil
      && (0..<8).contains(galaxy) && (0...256).contains(system)
      && firstDue.isFinite && (0...1e9).contains(firstDue)
      && interval.isFinite && (0...1e9).contains(interval)
      && (policy == .once || interval >= 0.001)
      && (owner == .station
        ? encounter == nil && actor == nil
        : encounter.map(PackValidation.localID) == true
          && actor.map(PackValidation.localID) == true)
      && (counters ?? []).count <= 16 && (counters ?? []).allSatisfy(PackValidation.localID)
      && Set(counters ?? []).count == (counters ?? []).count
      && (controlledEncounters ?? []).count <= 64
      && Set(controlledEncounters ?? []).count == (controlledEncounters ?? []).count
      && (controlledEncounters ?? []).allSatisfy(PackValidation.localID)
  }
}
public struct ScriptStationResource: Codable, Sendable, Equatable {
  public let identity: UUID
  public let galaxy: Int
  public let system: Int
  public var energy = 100.0
  public var destroyed = false
  public var key: String { "main-orbital:\(galaxy):\(system)" }
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system)
      && energy.isFinite && (0...1e12).contains(energy) && (!destroyed || energy == 0)
  }
}
public enum ScriptWorldJobStatus: String, Codable, Sendable { case active, complete, cancelled }
public struct ScriptWorldJobPulse: Codable, Sendable, Equatable {
  public let sequence: UInt64
  public let due: Double
  public let firedAt: Double
  public let pulse: Int
  public let counters: [String: Int64]
  var valid: Bool {
    sequence > 0 && sequence < UInt64(Int64.max) && (1...1_000_000_000).contains(pulse)
      && due.isFinite && firedAt.isFinite && (0...1e12).contains(due)
      && (due...1e12).contains(firedAt) && counters.count <= 16
      && counters.allSatisfy {
        PackValidation.localID($0.key) && (0...Int64(pulse)).contains($0.value)
      }
  }
}
/// The resource owns the job. Origin identifies immutable content and controlled assets,
/// and grants no right to change the originating mission's outcome, balance or cargo.
public struct ScriptWorldJob: Codable, Sendable, Equatable {
  public let identity: UUID
  public let origin: UUID
  public let definition: ScriptWorldJobDefinition
  public let resource: UUID
  public var status: ScriptWorldJobStatus = .active
  public var suspension: String?
  public var elapsed = 0.0
  public var timer: ScriptTimer
  public var data: ScriptValue = .object([:])
  public var pending: ScriptWorldJobPulse?
  public var acknowledgedThrough: UInt64 = 0
  public var receipts: Set<String> = []
  public var journal: [String] = []
  public var cancellationReason: String?
  var valid: Bool {
    definition.valid && elapsed.isFinite && (0...1e12).contains(elapsed)
      && timer.id == definition.id && timer.domain == .local && timer.valid
      && timer.interval == definition.interval && timer.policy == definition.policy
      && Set(timer.counters.keys) == Set(definition.counters ?? [])
      && acknowledgedThrough < UInt64(Int64.max)
      && (pending.map {
        $0.valid && $0.sequence > acknowledgedThrough && $0.pulse == timer.pulses
          && $0.due == timer.lastDue && $0.firedAt == timer.lastFiredAt
          && $0.counters == timer.counters.mapValues(\.value)
      } ?? true)
      && receipts.count <= 4096 && receipts.allSatisfy(PackValidation.localID)
      && journal.count <= 512 && journal.allSatisfy { (1...12000).contains($0.utf8.count) }
      && data.object != nil && (try? ScriptWire.encode([data], limit: 262144)) != nil
      && (suspension.map { (1...1024).contains($0.utf8.count) } ?? true)
      && (status == .cancelled ? cancellationReason != nil : cancellationReason == nil)
      && (cancellationReason.map { (1...256).contains($0.utf8.count) } ?? true)
      && (status == .active || pending == nil)
  }
}

extension ScriptEngineState {
  var worldJobsValid: Bool {
    guard stationResources.count <= NativeMainStationIdentity.maximumCount, worldJobs.count <= 64,
      Set(stationResources.values.map(\.identity)).count == stationResources.count,
      stationResources.allSatisfy({
        $0.key == $0.value.key && $0.value.valid
          && $0.value.identity == Game.worldResourceIdentity("main-station-v1:\($0.key)")
      })
    else { return false }
    let pending =
      worldJobs.values.compactMap { $0.pending?.sequence } + pendingEvents.map(\.sequence)
    guard Set(pending).count == pending.count else { return false }
    return worldJobs.allSatisfy { id, job in
      guard id == job.identity, job.valid, instances[job.origin] != nil,
        job.identity
          == Game.worldResourceIdentity("world-job-v1:\(job.origin):\(job.definition.id)"),
        job.acknowledgedThrough <= nextEvent,
        job.pending.map({ $0.sequence <= nextEvent }) ?? true
      else { return false }
      if job.definition.owner == .station {
        let key = "main-orbital:\(job.definition.galaxy):\(job.definition.system)"
        guard let station = stationResources[key], station.identity == job.resource,
          job.status != .active || !station.destroyed
        else { return false }
      } else {
        guard let encounterID = job.definition.encounter, let alias = job.definition.actor,
          let encounter = instances[job.origin]?.ownedEncounters[encounterID], encounter.admitted,
          encounter.galaxy == job.definition.galaxy, encounter.system == job.definition.system,
          let actor = encounter.actors[alias], actor.identity == job.resource,
          job.status != .active || actor.presence != .destroyed
        else { return false }
      }
      return true
    }
  }
}
