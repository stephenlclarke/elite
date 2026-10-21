import Foundation

public enum ScriptOutcome: String, Codable, Sendable { case active, complete, failed, abandoned }
public enum ScriptClockDomain: String, Codable, Sendable {
  case flight, local, calendar, transit, missionCalendar
}
public enum ScriptTimerPolicy: String, Codable, Sendable { case once, skip, delay }
public struct ScriptTimer: Codable, Sendable, Equatable {
  public var id: String
  public var domain: ScriptClockDomain
  public var due: Double
  public var interval: Double
  public var policy: ScriptTimerPolicy
  public var pulses = 0
  public var clockExhausted: Bool?
  public var lastDue: Double?
  public var lastFiredAt: Double?
  public var savedCounters: [String: ScriptPulseCounter]?
  public var counters: [String: ScriptPulseCounter] {
    get { savedCounters ?? [:] }
    set { savedCounters = newValue.isEmpty ? nil : newValue }
  }
}
extension ScriptTimer {
  var valid: Bool {
    domain != .missionCalendar && PackValidation.localID(id) && due.isFinite
      && (0...1e12).contains(due)
      && interval.isFinite && (0...1e9).contains(interval)
      && (0...1_000_000_000).contains(pulses) && counters.count <= 16
      && counters.allSatisfy {
        PackValidation.localID($0.key) && $0.value.valid
          && $0.value.value <= Int64(pulses)
      }
      && ((lastDue == nil && lastFiredAt == nil)
        || (lastDue.map { $0.isFinite && (0...1e12).contains($0) } == true
          && lastFiredAt.map { $0.isFinite && (0...1e12).contains($0) } == true
          && lastDue! <= lastFiredAt!))
      && (clockExhausted != true || due == 1e12)
      && (policy == .once || interval > 0)
  }
}

public struct ScriptDialogue: Codable, Sendable, Equatable {
  public var collectionQuote: ScriptCollectionQuote?
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
  public var savedCollections: [String: ScriptCollection]?
  public var savedCampaignChildren: [String: ScriptChildBinding]?
  public var campaignParent: ScriptChildBinding?
  public var savedCampaignReceiptScopes: [String: String]?
  public var savedConversationReceipts: [UInt64: ScriptChoiceReceipt]?
  public var savedChoiceReceipts: [String: ScriptChoiceReceipt]?
  public var choiceReceipts: [String: ScriptChoiceReceipt] {
    get { savedChoiceReceipts ?? [:] }
    set { savedChoiceReceipts = newValue.isEmpty ? nil : newValue }
  }
  public var completionReceipt: ScriptCompletionReceipt?
  var savedProviderContract: ScriptProviderContractState?
  public var courier: ScriptCourierCustody?
  public var pledgeReceiptID: UUID?
  public var receiptJoins: [String: [UUID]]?
  public var outcome: ScriptOutcome = .active
  public var suspension: String?
  public var revision: UInt64 = 0
  public var acknowledgedEvents: Set<UInt64> = []
  public var acknowledgedThrough: UInt64?
  public var receipts: Set<String> = []
  public var milestones: Set<Int> = []
  public var payloads: [String: Int] = [:]
  public var timers: [String: ScriptTimer] = [:]
  public var dialogue: ScriptDialogue?
  public var journal: [String] = []
  public var contract: ScriptContractJob?
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
  var financeLedger: ScriptFinanceLedger?
  public var missionCalendar: ScriptMissionCalendar?
  public var pledgeLedger: ScriptPledgeLedger?
  public var savedBooks: [String: ScriptBookRecord]?
  public var savedWorldJobs: [UUID: ScriptWorldJob]?
  public var worldJobs: [UUID: ScriptWorldJob] {
    get { savedWorldJobs ?? [:] }
    set { savedWorldJobs = newValue.isEmpty ? nil : newValue }
  }
  public var savedStationResources: [String: ScriptStationResource]?
  public var stationResources: [String: ScriptStationResource] {
    get { savedStationResources ?? [:] }
    set { savedStationResources = newValue.isEmpty ? nil : newValue }
  }
  public var calendarLedger: ScriptCalendarLedger?
  public var savedProjectiles: [UUID: ScriptProjectileRecord]?
  public var projectiles: [UUID: ScriptProjectileRecord] {
    get { savedProjectiles ?? [:] }
    set { savedProjectiles = newValue.isEmpty ? nil : newValue }
  }
  public var savedGeometry: [String: ShipDesign]?
  public var geometry: [String: ShipDesign] {
    get { savedGeometry ?? [:] }
    set { savedGeometry = newValue.isEmpty ? nil : newValue }
  }
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
    case .missionCalendar: missionCalendar?.seconds ?? 0
    case .transit: transitSeconds
    }
  }
  var valid: Bool {
    guard worldJobsValid, booksValid, financeLedger?.valid(engine: self) ?? true,
      missionCalendar.map({
        $0.valid && $0.seconds <= calendarSeconds
          && $0.lastNativeOperation <= (calendarLedger?.operation ?? 0)
          && $0.seconds <= 1e12 - (calendarLedger?.pendingJourney?.seconds ?? 0)
      }) ?? true,
      pledgeLedger?.valid(engine: self)
        ?? instances.values.allSatisfy({ $0.pledgeReceiptID == nil })
    else {
      return false
    }
    guard
      calendarLedger.map({
        $0.valid
          && ($0.lastAdjustment.map { $0.after <= calendarSeconds } ?? true)
          && ($0.pendingJourney.map { calendarSeconds <= 1e12 - $0.seconds } ?? true)
      }) ?? true
    else { return false }
    guard geometry.count <= 128,
      geometry.allSatisfy({ key, value in
        ScriptPackLibrary.scriptGeometryValid(value)
          && (try? ScriptPackLibrary.canonicalGeometry(value)).map(ScriptPackLibrary.hash) == key
      })
    else { return false }
    guard projectiles.count <= 1024,
      projectiles.allSatisfy({ key, value in
        key == value.body.scriptShot?.identity && value.valid && projectileArchiveValid(value)
      })
    else { return false }
    let identities = instances.values.flatMap {
      $0.ownedEncounters.values.flatMap { $0.actors.values.map(\.identity) }
    }
    let componentIdentities = instances.values.flatMap {
      $0.ownedEncounters.values.flatMap {
        $0.actors.values.flatMap {
          $0.body.scriptNPC?.components.values.map(\.identity) ?? []
        }
      }
    }
    let physicalIdentities = identities + componentIdentities + Array(projectiles.keys)
    guard Set(physicalIdentities).count == physicalIdentities.count else { return false }
    let gearIdentities = instances.values.flatMap { $0.gearIssues.values.flatMap(\.items) }
    let choiceSequences = instances.values.flatMap {
      $0.choiceReceipts.values.map(\.sequence) + Array($0.conversationReceipts.keys)
    }
    let completionSequences = instances.values.compactMap { $0.completionReceipt?.sequence }
    return campaignsValid && Set(identities).count == identities.count && instances.count <= 128
      && Set(choiceSequences).count == choiceSequences.count
      && Set(completionSequences).count == completionSequences.count
      && Set(gearIdentities).count == gearIdentities.count
      && pendingEvents.count <= 4096 && nextEvent < UInt64(Int64.max)
      && pendingEvents.map(\.sequence) == pendingEvents.map(\.sequence).sorted()
      && pendingEvents.allSatisfy { event in
        event.sequence > 0 && event.sequence <= nextEvent
          && instances[event.instance].map { instance in
            event.context.map { $0.valid && $0.revision <= instance.revision } ?? true
          } == true
      }
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
          && (instance.courier.map { $0.valid(state: instance, engine: self) }
            ?? (instance.contract?.offer.courier == nil))
          && (instance.savedProviderContract.map { $0.valid(instance: instance) } ?? true)
          && instance.collectionsValid(engine: self)
          && instance.conversationReceipts.count <= 1024
          && instance.conversationReceipts.allSatisfy {
            $0.key == $0.value.sequence && $0.value.group == nil
              && $0.value.valid(for: instance, engine: self)
          }
          && instance.choiceReceipts.count <= 64
          && instance.choiceReceipts.allSatisfy {
            $0.key == $0.value.group && $0.value.valid(for: instance, engine: self)
          }
          && (instance.completionReceipt.map { $0.valid(for: instance, engine: self) } ?? true)
          && (instance.receiptJoins.map { joins in
            joins.count <= 32
              && joins.allSatisfy { key, children in
                PackValidation.localID(key) && (1...128).contains(children.count)
                  && Set(children).count == children.count
                  && children.allSatisfy { child in
                    child != instance.id
                      && instances[child]?.completionReceipt.map { receipt in
                        instance.completionReceipt.map { receipt.sequence < $0.sequence } ?? true
                      } == true
                  }
              }
          } ?? true)
          && instance.revision < UInt64(Int64.max) && instance.acknowledgedEvents.count <= 4096
          && instance.acknowledgedEvents.allSatisfy { $0 > 0 && $0 <= nextEvent }
          && (instance.acknowledgedThrough.map { $0 <= nextEvent } ?? true)
          && instance.receipts.count <= 4096 && instance.receipts.allSatisfy(PackValidation.localID)
          && instance.ownedEncounters.count <= 64
          && instance.ownedEncounters.allSatisfy {
            $0.key == $0.value.id && $0.value.valid
              && ($0.value.legacyProvenance?.matches(owner: instance, encounter: $0.value) ?? true)
              && $0.value.actors.values.allSatisfy { $0.body.missionInstanceID == instance.id }
              && $0.value.actors.values.allSatisfy { actor in
                actor.body.scriptNPC?.fit.models.values.allSatisfy { geometry[$0] != nil } ?? true
              }
          }
          && instance.ownedEncounters.values.reduce(0, { $0 + $1.actors.count }) <= 128
          && instance.gearIssues.count <= 64
          && instance.gearIssues.allSatisfy {
            $0.key == $0.value.resource && $0.value.valid(for: instance)
          }
          && Set(instance.gearIssues.values.flatMap(\.items)).count
            == instance.gearIssues.values.reduce(0) { $0 + $1.items.count }
          && instance.payloads.count <= 128
          && instance.payloads.keys.allSatisfy(PackValidation.localID)
          && instance.payloads.values.allSatisfy { (0...1_000_000).contains($0) }
          && instance.milestones.count <= 64
          && instance.milestones.allSatisfy { (0..<64).contains($0) }
          && instance.timers.count <= 128
          && instance.timers.allSatisfy { $0.key == $0.value.id && $0.value.valid }
          && instance.journal.count <= 512 && instance.journal.allSatisfy { $0.utf8.count <= 12000 }
          && instance.data.object != nil
          && (try? ScriptWire.encode([instance.data], limit: 262144)) != nil
      }
  }
}
