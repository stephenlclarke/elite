import Foundation

public enum ScriptOutcome: String, Codable, Sendable { case active, complete, failed, abandoned }
public enum ScriptClockDomain: String, Codable, Sendable { case flight, local, calendar, transit }
public enum ScriptTimerPolicy: String, Codable, Sendable { case once, skip, delay }
public struct ScriptTimer: Codable, Sendable, Equatable {
  public var id: String
  public var domain: ScriptClockDomain
  public var due: Double
  public var interval: Double
  public var policy: ScriptTimerPolicy
  public var pulses = 0
}
public struct ScriptDialogue: Codable, Sendable, Equatable {
  public var id: String
  public var token: String
  public var galaxy: Int
  public var system: Int
  public var revision: UInt64
}
public struct ScriptInstance: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let definition: String
  public let version: String
  public let digest: String
  public init(id: UUID, definition: String, version: String, digest: String) {
    self.id = id
    self.definition = definition
    self.version = version
    self.digest = digest
  }
  public var data: ScriptValue = .object([:])
  public var outcome: ScriptOutcome = .active
  public var suspension: String?
  public var revision: UInt64 = 0
  public var acknowledgedEvents: Set<UInt64> = []
  public var receipts: Set<String> = []
  public var milestones: Set<Int> = []
  public var payloads: [String: Int] = [:]
  public var timers: [String: ScriptTimer] = [:]
  public var dialogue: ScriptDialogue?
  public var journal: [String] = []
  private var savedGearIssues: [String: ScriptGearIssue]?
  public var gearIssues: [String: ScriptGearIssue] {
    get { savedGearIssues ?? [:] }
    set { savedGearIssues = newValue }
  }
  private var savedOwnedEncounters: [String: ScriptOwnedEncounter]?
  public var ownedEncounters: [String: ScriptOwnedEncounter] {
    get { savedOwnedEncounters ?? [:] }
    set { savedOwnedEncounters = newValue }
  }
  public var randomState: UInt64 = 0x45_4c49_5445
}
public struct ScriptEngineState: Codable, Sendable, Equatable {
  public var instances: [UUID: ScriptInstance] = [:]
  var pendingEvents: [ScriptEvent] = []
  public var nextEvent: UInt64 = 0
  public var flightSeconds = 0.0
  public var localSeconds = 0.0
  public var calendarSeconds = 0.0
  public var transitSeconds = 0.0
  public init() {}
  public var payloadTonnes: Int {
    var total = 0
    for instance in instances.values {
      for quantity in instance.payloads.values {
        guard (0...1_000_000).contains(quantity) else { return Int.max / 17 }
        let (next, overflow) = total.addingReportingOverflow(quantity)
        guard !overflow, next < Int.max / 17 else { return Int.max / 17 }
        total = next
      }
    }
    return total
  }
  func clock(_ domain: ScriptClockDomain) -> Double {
    switch domain {
    case .flight: flightSeconds
    case .local: localSeconds
    case .calendar: calendarSeconds
    case .transit: transitSeconds
    }
  }
  var valid: Bool {
    let identities = instances.values.flatMap {
      $0.ownedEncounters.values.flatMap { $0.actors.values.map(\.identity) }
    }
    let gearIdentities = instances.values.flatMap { $0.gearIssues.values.flatMap(\.items) }
    return Set(identities).count == identities.count && instances.count <= 128
      && Set(gearIdentities).count == gearIdentities.count
      && pendingEvents.count <= 4096 && nextEvent < UInt64(Int64.max)
      && pendingEvents.allSatisfy { $0.sequence <= nextEvent && instances[$0.instance] != nil }
      && [flightSeconds, localSeconds, calendarSeconds, transitSeconds].allSatisfy {
        $0.isFinite && (0...1e12).contains($0)
      }
      && instances.allSatisfy { key, instance in
        key == instance.id && instance.definition.split(separator: "/").count == 2
          && PackValidation.version(instance.version)
          && instance.digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
          && (instance.dialogue.map { dialogue in
            PackValidation.localID(dialogue.id) && dialogue.token.utf8.count <= 256
              && dialogue.revision <= instance.revision && (0..<8).contains(dialogue.galaxy)
              && (0...256).contains(dialogue.system)
          } ?? true)
          && instance.revision < UInt64.max - 1 && instance.acknowledgedEvents.count <= 4096
          && instance.receipts.count <= 4096 && instance.receipts.allSatisfy(PackValidation.localID)
          && instance.ownedEncounters.count <= 64
          && instance.ownedEncounters.allSatisfy {
            $0.key == $0.value.id && $0.value.valid
              && $0.value.actors.values.allSatisfy { $0.body.missionInstanceID == instance.id }
          }
          && instance.ownedEncounters.values.reduce(0, { $0 + $1.actors.count }) <= 128
          && instance.gearIssues.count <= 64
          && instance.gearIssues.allSatisfy { $0.key == $0.value.resource && $0.value.valid }
          && Set(instance.gearIssues.values.flatMap(\.items)).count
            == instance.gearIssues.values.reduce(0) { $0 + $1.items.count }
          && instance.payloads.count <= 128
          && instance.payloads.keys.allSatisfy(PackValidation.localID)
          && instance.payloads.values.allSatisfy { (0...1_000_000).contains($0) }
          && instance.milestones.count <= 64
          && instance.milestones.allSatisfy { (0..<64).contains($0) }
          && instance.timers.count <= 128
          && instance.timers.allSatisfy { key, timer in
            key == timer.id && PackValidation.localID(key) && timer.due.isFinite
              && (0...1e12).contains(timer.due)
              && timer.interval.isFinite && (0...1e9).contains(timer.interval) && timer.pulses >= 0
              && (timer.policy == .once || timer.interval > 0)
          }
          && instance.journal.count <= 512 && instance.journal.allSatisfy { $0.utf8.count <= 12000 }
          && instance.data.object != nil
          && (try? ScriptWire.encode([instance.data], limit: 262144)) != nil
      }
  }
}
