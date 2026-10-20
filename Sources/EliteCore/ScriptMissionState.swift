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
  var savedOwnedCargo: ScriptOwnedCargoState?
  var savedNavigationTrade: ScriptNavigationTradeState?
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
  var savedClueJournal: ScriptClueJournal?
  var financeLedger: ScriptFinanceLedger?
  var wormholeTransit: NativeWormholeTransitState?
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
    guard savedClueJournal?.valid(engine: self) ?? true, worldJobsValid, booksValid,
      financeLedger?.valid(engine: self) ?? true, nativeWormholeStateValid,
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
      && instancesValid()
  }

  // Keep dictionary element tuples out of the nested encounter/NPC validation call chain.
  @inline(never)
  private func instancesValid() -> Bool {
    for index in instances.indices {
      guard instanceValid(instances.values[index], key: instances.keys[index]) else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceValid(_ instance: borrowing ScriptInstance, key: UUID) -> Bool {
    guard instancePrefixValid(instance, key: key), ownedEncountersValid(for: instance) else {
      return false
    }
    return instanceSuffixValid(instance)
  }

  // Optional contract/receipt storage must return before nested encounter/NPC validation starts.
  @inline(never)
  private func instancePrefixValid(_ instance: borrowing ScriptInstance, key: UUID) -> Bool {
    guard key == instance.id, instance.definition.split(separator: "/").count == 2,
      PackValidation.version(instance.version),
      instance.digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    else { return false }
    if let dialogue = instance.dialogue {
      guard PackValidation.localID(dialogue.id), dialogue.token.utf8.count <= 256,
        dialogue.revision <= instance.revision, (0..<8).contains(dialogue.galaxy),
        (0...256).contains(dialogue.system)
      else { return false }
    }
    if let courier = instance.courier {
      guard courier.valid(state: instance, engine: self) else { return false }
    } else {
      guard instance.contract?.offer.courier == nil else { return false }
    }
    if let contract = instance.savedProviderContract {
      guard contract.valid(instance: instance) else { return false }
    }
    if let cargo = instance.savedOwnedCargo {
      guard cargo.valid(state: instance, engine: self) else { return false }
    } else {
      guard instance.contract?.offer.freightPlan == nil else { return false }
    }
    if let trade = instance.savedNavigationTrade {
      guard trade.valid(instance: instance, engine: self) else { return false }
    }
    guard instance.collectionsValid(engine: self), instance.conversationReceipts.count <= 1024
    else {
      return false
    }
    for receipt in instance.conversationReceipts {
      guard receipt.key == receipt.value.sequence, receipt.value.group == nil,
        receipt.value.valid(for: instance, engine: self)
      else { return false }
    }
    guard instance.choiceReceipts.count <= 64 else { return false }
    for receipt in instance.choiceReceipts {
      guard receipt.key == receipt.value.group, receipt.value.valid(for: instance, engine: self)
      else {
        return false
      }
    }
    if let receipt = instance.completionReceipt {
      guard receipt.valid(for: instance, engine: self) else { return false }
    }
    if let joins = instance.receiptJoins {
      let ownerID = instance.id
      let completionSequence = instance.completionReceipt?.sequence
      guard joins.count <= 32,
        joins.allSatisfy({ key, children in
          PackValidation.localID(key) && (1...128).contains(children.count)
            && Set(children).count == children.count
            && children.allSatisfy { child in
              child != ownerID
                && instances[child]?.completionReceipt.map { receipt in
                  completionSequence.map { receipt.sequence < $0 } ?? true
                } == true
            }
        })
      else { return false }
    }
    guard instance.revision < UInt64(Int64.max), instance.acknowledgedEvents.count <= 4096,
      instance.acknowledgedEvents.allSatisfy({ $0 > 0 && $0 <= nextEvent }),
      instance.acknowledgedThrough.map({ $0 <= nextEvent }) ?? true,
      instance.receipts.count <= 4096, instance.receipts.allSatisfy(PackValidation.localID),
      instance.ownedEncounters.count <= 64
    else { return false }
    return true
  }

  @inline(never)
  private func instanceSuffixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard instance.ownedEncounters.values.reduce(0, { $0 + $1.actors.count }) <= 128,
      instance.gearIssues.count <= 64
    else { return false }
    for issue in instance.gearIssues {
      guard issue.key == issue.value.resource, issue.value.valid(for: instance) else {
        return false
      }
    }
    guard
      Set(instance.gearIssues.values.flatMap(\.items)).count
        == instance.gearIssues.values.reduce(0, { $0 + $1.items.count }),
      instance.payloads.count <= 128, instance.payloads.keys.allSatisfy(PackValidation.localID),
      instance.payloads.values.allSatisfy({ (0...1_000_000).contains($0) }),
      instance.milestones.count <= 64, instance.milestones.allSatisfy({ (0..<64).contains($0) }),
      instance.timers.count <= 128,
      instance.timers.allSatisfy({ $0.key == $0.value.id && $0.value.valid }),
      instance.journal.count <= 512, instance.journal.allSatisfy({ $0.utf8.count <= 12000 }),
      instance.data.object != nil, (try? ScriptWire.encode([instance.data], limit: 262144)) != nil
    else { return false }
    return true
  }

  @inline(never)
  private func ownedEncountersValid(for instance: borrowing ScriptInstance) -> Bool {
    let encounters = instance.ownedEncounters
    for index in encounters.indices {
      guard
        ownedEncounterValid(encounters.values[index], key: encounters.keys[index], owner: instance)
      else { return false }
    }
    return true
  }

  @inline(never)
  private func ownedEncounterValid(
    _ encounter: borrowing ScriptOwnedEncounter, key: String, owner: borrowing ScriptInstance
  ) -> Bool {
    guard key == encounter.id, encounter.valid else { return false }
    if let provenance = encounter.legacyProvenance {
      guard provenance.matches(owner: owner, encounter: encounter) else { return false }
    }
    for index in encounter.actors.indices {
      guard encounter.actors.values[index].body.missionInstanceID == owner.id else { return false }
    }
    for index in encounter.actors.indices {
      guard actorModelsValid(encounter.actors.values[index]) else { return false }
    }
    return true
  }

  @inline(never)
  private func actorModelsValid(_ actor: borrowing ScriptOwnedActor) -> Bool {
    actor.body.scriptNPC?.fit.models.values.allSatisfy { geometry[$0] != nil } ?? true
  }
}
