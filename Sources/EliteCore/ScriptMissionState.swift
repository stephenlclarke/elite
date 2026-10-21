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
private struct ScriptInstanceValue: Codable, Sendable, Equatable {
  let id: UUID
  let definition: String
  let version: String
  let digest: String
  init(id: UUID, definition: String, version: String, digest: String) {
    self.id = id
    self.definition = definition
    self.version = version
    self.digest = digest
  }
  var data: ScriptValue = .object([:])
  var savedCollections: [String: ScriptCollection]?
  var savedCampaignChildren: [String: ScriptChildBinding]?
  var campaignParent: ScriptChildBinding?
  var savedCampaignReceiptScopes: [String: String]?
  var savedConversationReceipts: [UInt64: ScriptChoiceReceipt]?
  var savedChoiceReceipts: [String: ScriptChoiceReceipt]?

  var completionReceipt: ScriptCompletionReceipt?
  var savedProviderContract: ScriptProviderContractState?
  var savedOwnedCargo: ScriptOwnedCargoState?
  var savedWayfarerColdChain: WayfarerColdChainCustody?
  var savedWayfarerRepairLoop: WayfarerRepairLoopCustody?
  var savedFieldRelief: WayfarerFieldReliefCustody?
  var savedNavigationTrade: ScriptNavigationTradeState?
  var savedOriginalSurvey: NativeOriginalSurveyState?
  var savedGlassMeridian: NativeGlassMeridianState?
  var savedNativeArk: NativeInductionArkState?
  var savedWayfarerInduction: NativeWayfarerInductionState?
  var savedFlightReception: NativeFlightReceptionState?
  var savedMeasuredExtraction: NativeMeasuredExtractionState?
  var savedRecordRecovery: WayfarerRecordRecoveryState?
  var savedIdentifiedSalvage: NativeIdentifiedSalvageState?
  var courier: ScriptCourierCustody?
  var pledgeReceiptID: UUID?
  var receiptJoins: [String: [UUID]]?
  var outcome: ScriptOutcome = .active
  var suspension: String?
  var revision: UInt64 = 0
  var acknowledgedEvents: Set<UInt64> = []
  var acknowledgedThrough: UInt64?
  var receipts: Set<String> = []
  var milestones: Set<Int> = []
  var payloads: [String: Int] = [:]
  var timers: [String: ScriptTimer] = [:]
  var dialogue: ScriptDialogue?
  var journal: [String] = []
  var contract: ScriptContractJob?
  var savedGearIssues: [String: ScriptGearIssue]?

  var savedOwnedEncounters: [String: ScriptOwnedEncounter]?

  var randomState: UInt64 = 0x45_4c49_5445
}

/// One copy-on-write value; Codable forwards the original instance object without an envelope.
public struct ScriptInstance: Codable, Sendable, Equatable, Identifiable {
  private var storage: [ScriptInstanceValue]

  public init(id: UUID, definition: String, version: String, digest: String) {
    storage = [.init(id: id, definition: definition, version: version, digest: digest)]
  }

  public init(from decoder: any Decoder) throws {
    storage = [try ScriptInstanceValue(from: decoder)]
  }

  public func encode(to encoder: any Encoder) throws {
    try storage[0].encode(to: encoder)
  }

  public var id: UUID {
    _read { yield storage[0].id }
  }

  public var definition: String {
    _read { yield storage[0].definition }
  }

  public var version: String {
    _read { yield storage[0].version }
  }

  public var digest: String {
    _read { yield storage[0].digest }
  }

  public var data: ScriptValue {
    _read { yield storage[0].data }
    _modify { yield &storage[0].data }
  }

  public var savedCollections: [String: ScriptCollection]? {
    _read { yield storage[0].savedCollections }
    _modify { yield &storage[0].savedCollections }
  }

  public var savedCampaignChildren: [String: ScriptChildBinding]? {
    _read { yield storage[0].savedCampaignChildren }
    _modify { yield &storage[0].savedCampaignChildren }
  }

  public var campaignParent: ScriptChildBinding? {
    _read { yield storage[0].campaignParent }
    _modify { yield &storage[0].campaignParent }
  }

  public var savedCampaignReceiptScopes: [String: String]? {
    _read { yield storage[0].savedCampaignReceiptScopes }
    _modify { yield &storage[0].savedCampaignReceiptScopes }
  }

  public var savedConversationReceipts: [UInt64: ScriptChoiceReceipt]? {
    _read { yield storage[0].savedConversationReceipts }
    _modify { yield &storage[0].savedConversationReceipts }
  }

  public var savedChoiceReceipts: [String: ScriptChoiceReceipt]? {
    _read { yield storage[0].savedChoiceReceipts }
    _modify { yield &storage[0].savedChoiceReceipts }
  }

  public var completionReceipt: ScriptCompletionReceipt? {
    _read { yield storage[0].completionReceipt }
    _modify { yield &storage[0].completionReceipt }
  }

  var savedProviderContract: ScriptProviderContractState? {
    _read { yield storage[0].savedProviderContract }
    _modify { yield &storage[0].savedProviderContract }
  }

  var savedOwnedCargo: ScriptOwnedCargoState? {
    _read { yield storage[0].savedOwnedCargo }
    _modify { yield &storage[0].savedOwnedCargo }
  }

  var savedWayfarerColdChain: WayfarerColdChainCustody? {
    _read { yield storage[0].savedWayfarerColdChain }
    _modify { yield &storage[0].savedWayfarerColdChain }
  }

  var savedWayfarerRepairLoop: WayfarerRepairLoopCustody? {
    _read { yield storage[0].savedWayfarerRepairLoop }
    _modify { yield &storage[0].savedWayfarerRepairLoop }
  }

  var savedNavigationTrade: ScriptNavigationTradeState? {
    _read { yield storage[0].savedNavigationTrade }
    _modify { yield &storage[0].savedNavigationTrade }
  }
  var savedOriginalSurvey: NativeOriginalSurveyState? {
    _read { yield storage[0].savedOriginalSurvey }
    _modify { yield &storage[0].savedOriginalSurvey }
  }
  var savedFieldRelief: WayfarerFieldReliefCustody? {
    _read { yield storage[0].savedFieldRelief }
    _modify { yield &storage[0].savedFieldRelief }
  }
  var savedGlassMeridian: NativeGlassMeridianState? {
    _read { yield storage[0].savedGlassMeridian }
    _modify { yield &storage[0].savedGlassMeridian }
  }
  var savedNativeArk: NativeInductionArkState? {
    _read { yield storage[0].savedNativeArk }
    _modify { yield &storage[0].savedNativeArk }
  }
  var savedWayfarerInduction: NativeWayfarerInductionState? {
    _read { yield storage[0].savedWayfarerInduction }
    _modify { yield &storage[0].savedWayfarerInduction }
  }
  var savedFlightReception: NativeFlightReceptionState? {
    _read { yield storage[0].savedFlightReception }
    _modify { yield &storage[0].savedFlightReception }
  }
  var savedMeasuredExtraction: NativeMeasuredExtractionState? {
    _read { yield storage[0].savedMeasuredExtraction }
    _modify { yield &storage[0].savedMeasuredExtraction }
  }

  var savedRecordRecovery: WayfarerRecordRecoveryState? {
    _read { yield storage[0].savedRecordRecovery }
    _modify { yield &storage[0].savedRecordRecovery }
  }
  var savedIdentifiedSalvage: NativeIdentifiedSalvageState? {
    _read { yield storage[0].savedIdentifiedSalvage }
    _modify { yield &storage[0].savedIdentifiedSalvage }
  }

  public var courier: ScriptCourierCustody? {
    _read { yield storage[0].courier }
    _modify { yield &storage[0].courier }
  }

  public var pledgeReceiptID: UUID? {
    _read { yield storage[0].pledgeReceiptID }
    _modify { yield &storage[0].pledgeReceiptID }
  }

  public var receiptJoins: [String: [UUID]]? {
    _read { yield storage[0].receiptJoins }
    _modify { yield &storage[0].receiptJoins }
  }

  public var outcome: ScriptOutcome {
    _read { yield storage[0].outcome }
    _modify { yield &storage[0].outcome }
  }

  public var suspension: String? {
    _read { yield storage[0].suspension }
    _modify { yield &storage[0].suspension }
  }

  public var revision: UInt64 {
    _read { yield storage[0].revision }
    _modify { yield &storage[0].revision }
  }

  public var acknowledgedEvents: Set<UInt64> {
    _read { yield storage[0].acknowledgedEvents }
    _modify { yield &storage[0].acknowledgedEvents }
  }

  public var acknowledgedThrough: UInt64? {
    _read { yield storage[0].acknowledgedThrough }
    _modify { yield &storage[0].acknowledgedThrough }
  }

  public var receipts: Set<String> {
    _read { yield storage[0].receipts }
    _modify { yield &storage[0].receipts }
  }

  public var milestones: Set<Int> {
    _read { yield storage[0].milestones }
    _modify { yield &storage[0].milestones }
  }

  public var payloads: [String: Int] {
    _read { yield storage[0].payloads }
    _modify { yield &storage[0].payloads }
  }

  public var timers: [String: ScriptTimer] {
    _read { yield storage[0].timers }
    _modify { yield &storage[0].timers }
  }

  public var dialogue: ScriptDialogue? {
    _read { yield storage[0].dialogue }
    _modify { yield &storage[0].dialogue }
  }

  public var journal: [String] {
    _read { yield storage[0].journal }
    _modify { yield &storage[0].journal }
  }

  public var contract: ScriptContractJob? {
    _read { yield storage[0].contract }
    _modify { yield &storage[0].contract }
  }

  private var savedGearIssues: [String: ScriptGearIssue]? {
    _read { yield storage[0].savedGearIssues }
    _modify { yield &storage[0].savedGearIssues }
  }

  private var savedOwnedEncounters: [String: ScriptOwnedEncounter]? {
    _read { yield storage[0].savedOwnedEncounters }
    _modify { yield &storage[0].savedOwnedEncounters }
  }

  public var randomState: UInt64 {
    _read { yield storage[0].randomState }
    _modify { yield &storage[0].randomState }
  }

  public var choiceReceipts: [String: ScriptChoiceReceipt] {
    get { savedChoiceReceipts ?? [:] }
    set { savedChoiceReceipts = newValue.isEmpty ? nil : newValue }
  }
  public var gearIssues: [String: ScriptGearIssue] {
    get { savedGearIssues ?? [:] }
    set { savedGearIssues = newValue }
  }
  public var ownedEncounters: [String: ScriptOwnedEncounter] {
    get { savedOwnedEncounters ?? [:] }
    set { savedOwnedEncounters = newValue }
  }
}

public struct ScriptEngineState: Codable, Sendable, Equatable {
  var savedMeasuredExtractionSource: MeasuredSource?
  var savedRecordRecoverySource: WayfarerRecordRecoverySource?
  var savedIdentifiedSalvageSource: NativeIdentifiedSalvageSource?
  var savedOriginalConsentedFreightSupply: OriginalConsentedFreightSupplyStock?
  var savedWayfarerColdChainStock: WayfarerColdChainStockLedger?
  var savedWayfarerRepairLoopStock: WayfarerRepairLoopStockLedger?
  var savedFleetDiscovery: NativeFleetDiscovery?
  var firstNativeCommoditySale: NativeFirstCommoditySale?
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
    guard firstNativeCommoditySale?.valid ?? true, savedFleetDiscovery?.valid ?? true,
      WayfarerFieldReliefSave.engineValid(self),
      OriginalConsentedFreightSupply.engineValid(self),
      savedClueJournal?.valid(engine: self) ?? true, worldJobsValid, booksValid,
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
    return WayfarerRepairLoopSave.engineValid(self) && WayfarerColdChainSave.engineValid(self)
      && campaignsValid && Set(identities).count == identities.count && instances.count <= 128
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
    if NativeInductionArkPack.marked(instance) {
      guard instance.definition == NativeInductionArkPack.stateID,
        instance.digest == NativeInductionArkPack.digest,
        instance.version == NativeInductionArkPack.version,
        let ark = instance.savedNativeArk, ark.authorization.job == instance.id,
        instance.payloads.isEmpty
      else { return false }
    }
    if instance.definition == NativeWayfarerInduction.stateID {
      guard let opening = instance.savedWayfarerInduction, opening.valid,
        opening.permission.mission == instance.id, instance.payloads == opening.payloads
      else { return false }
    } else if instance.savedWayfarerInduction != nil {
      return false
    }
    if instance.definition == NativeGlassMeridian.stateID {
      guard let opening = instance.savedGlassMeridian,
        opening.permission.mission == instance.id, instance.payloads.isEmpty,
        NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening)
      else { return false }
    } else if instance.savedGlassMeridian != nil {
      return false
    }
    if instance.definition == NativeFlightReception.stateID {
      guard let practice = instance.savedFlightReception,
        practice.permission.mission == instance.id, instance.payloads.isEmpty
      else { return false }
    } else if instance.savedFlightReception != nil {
      return false
    }
    if instance.definition == NativeMeasuredExtraction.stateID {
      guard let extraction = instance.savedMeasuredExtraction, extraction.definition.valid,
        extraction.permission.mission == instance.id,
        let source = savedMeasuredExtractionSource, source.mission == instance.id,
        source.id == extraction.permission.source, source.originals.count == 12,
        extraction.captures.count <= 12, extraction.losses.count <= 24,
        instance.payloads
          == NativeMeasuredExtraction.payloads(source, state: extraction, outcome: instance.outcome)
      else { return false }
    } else if instance.savedMeasuredExtraction != nil {
      return false
    }
    if instance.definition == WayfarerRecordRecovery.stateID {
      guard let salvage = instance.savedRecordRecovery, salvage.definition.valid,
        salvage.permission.mission == instance.id,
        let source = savedRecordRecoverySource, source.allocatedMission == instance.id,
        source.id == salvage.source, source.originals.count == 1,
        salvage.captures.count <= 1, salvage.losses.count <= 1,
        instance.payloads
          == WayfarerRecordRecovery.payloads(
            salvage, outcome: instance.outcome, source: source)
      else { return false }
    } else if instance.savedRecordRecovery != nil {
      return false
    }
    if instance.definition == NativeIdentifiedSalvage.stateID {
      guard let salvage = instance.savedIdentifiedSalvage, salvage.definition.valid,
        salvage.permission.mission == instance.id,
        let source = savedIdentifiedSalvageSource, source.allocatedMission == instance.id,
        source.id == salvage.source, source.originals.count == 2,
        salvage.captures.count <= 2, salvage.losses.count <= 2,
        instance.payloads
          == NativeIdentifiedSalvage.payloads(
            salvage, outcome: instance.outcome, source: source)
      else { return false }
    } else if instance.savedIdentifiedSalvage != nil {
      return false
    }
    if instance.definition == NativeOriginalSurvey.stateID {
      guard let survey = instance.savedOriginalSurvey, survey.definition.valid,
        survey.version == instance.version, survey.digest == instance.digest,
        survey.permission?.mission == instance.id,
        survey.readings.count <= 3, survey.authorities.count == survey.readings.count
      else { return false }
    } else if instance.savedOriginalSurvey != nil {
      return false
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
