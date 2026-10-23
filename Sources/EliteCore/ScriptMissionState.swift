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
  // The payload never escapes. Distinct instance values share only read access; every
  // mutable projection detaches before yielding. Actor ownership still serializes simulation.
  private final class Storage: @unchecked Sendable {
    let id: UUID
    let definition: String
    let version: String
    let digest: String
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
    var savedArkReserve: NativeInductionArkReserve?
    var savedArkRecovery: NativeArkRecoveryReceipt?
    var savedNativeArk: NativeInductionArkState?
    var savedNativeCrewLog: NativeInductionCrewLogState?
    var savedNativeInductionUtility: NativeInductionUtilityState?
    var savedNativeInductionClinic: NativeInductionClinicContract?
    var savedNativeInductionWorkshop: NativeInductionWorkshopContract?
    var savedNativeInductionSeed: NativeInductionSeedContract?
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

    init(id: UUID, definition: String, version: String, digest: String) {
      self.id = id
      self.definition = definition
      self.version = version
      self.digest = digest
    }

    // Allocate the destination first, then copy one field per returned helper frame.
    @inline(never)
    convenience init(copying source: Storage) {
      self.init(
        id: source.id, definition: source.definition, version: source.version, digest: source.digest
      )
      copyData(from: source)
      copySavedCollections(from: source)
      copySavedCampaignChildren(from: source)
      copyCampaignParent(from: source)
      copySavedCampaignReceiptScopes(from: source)
      copySavedConversationReceipts(from: source)
      copySavedChoiceReceipts(from: source)
      copyCompletionReceipt(from: source)
      copySavedProviderContract(from: source)
      copySavedOwnedCargo(from: source)
      copySavedWayfarerColdChain(from: source)
      copySavedWayfarerRepairLoop(from: source)
      copySavedFieldRelief(from: source)
      copySavedNavigationTrade(from: source)
      copySavedOriginalSurvey(from: source)
      copySavedGlassMeridian(from: source)
      copySavedArkReserve(from: source)
      copySavedArkRecovery(from: source)
      copySavedNativeArk(from: source)
      copySavedNativeCrewLog(from: source)
      copySavedNativeInductionUtility(from: source)
      copySavedNativeInductionClinic(from: source)
      copySavedNativeInductionWorkshop(from: source)
      copySavedNativeInductionSeed(from: source)
      copySavedWayfarerInduction(from: source)
      copySavedFlightReception(from: source)
      copySavedMeasuredExtraction(from: source)
      copySavedRecordRecovery(from: source)
      copySavedIdentifiedSalvage(from: source)
      copyCourier(from: source)
      copyPledgeReceiptID(from: source)
      copyReceiptJoins(from: source)
      copyOutcome(from: source)
      copySuspension(from: source)
      copyRevision(from: source)
      copyAcknowledgedEvents(from: source)
      copyAcknowledgedThrough(from: source)
      copyReceipts(from: source)
      copyMilestones(from: source)
      copyPayloads(from: source)
      copyTimers(from: source)
      copyDialogue(from: source)
      copyJournal(from: source)
      copyContract(from: source)
      copySavedGearIssues(from: source)
      copySavedOwnedEncounters(from: source)
      copyRandomState(from: source)
    }

    @inline(never)
    private func copyData(from source: Storage) {
      data = source.data
    }

    @inline(never)
    private func copySavedCollections(from source: Storage) {
      savedCollections = source.savedCollections
    }

    @inline(never)
    private func copySavedCampaignChildren(from source: Storage) {
      savedCampaignChildren = source.savedCampaignChildren
    }

    @inline(never)
    private func copyCampaignParent(from source: Storage) {
      campaignParent = source.campaignParent
    }

    @inline(never)
    private func copySavedCampaignReceiptScopes(from source: Storage) {
      savedCampaignReceiptScopes = source.savedCampaignReceiptScopes
    }

    @inline(never)
    private func copySavedConversationReceipts(from source: Storage) {
      savedConversationReceipts = source.savedConversationReceipts
    }

    @inline(never)
    private func copySavedChoiceReceipts(from source: Storage) {
      savedChoiceReceipts = source.savedChoiceReceipts
    }

    @inline(never)
    private func copyCompletionReceipt(from source: Storage) {
      completionReceipt = source.completionReceipt
    }

    @inline(never)
    private func copySavedProviderContract(from source: Storage) {
      savedProviderContract = source.savedProviderContract
    }

    @inline(never)
    private func copySavedOwnedCargo(from source: Storage) {
      savedOwnedCargo = source.savedOwnedCargo
    }

    @inline(never)
    private func copySavedWayfarerColdChain(from source: Storage) {
      savedWayfarerColdChain = source.savedWayfarerColdChain
    }

    @inline(never)
    private func copySavedWayfarerRepairLoop(from source: Storage) {
      savedWayfarerRepairLoop = source.savedWayfarerRepairLoop
    }

    @inline(never)
    private func copySavedFieldRelief(from source: Storage) {
      savedFieldRelief = source.savedFieldRelief
    }

    @inline(never)
    private func copySavedNavigationTrade(from source: Storage) {
      savedNavigationTrade = source.savedNavigationTrade
    }

    @inline(never)
    private func copySavedOriginalSurvey(from source: Storage) {
      savedOriginalSurvey = source.savedOriginalSurvey
    }

    @inline(never)
    private func copySavedGlassMeridian(from source: Storage) {
      savedGlassMeridian = source.savedGlassMeridian
    }

    @inline(never)
    private func copySavedArkReserve(from source: Storage) {
      savedArkReserve = source.savedArkReserve
    }

    @inline(never)
    private func copySavedArkRecovery(from source: Storage) {
      savedArkRecovery = source.savedArkRecovery
    }

    @inline(never)
    private func copySavedNativeArk(from source: Storage) {
      savedNativeArk = source.savedNativeArk
    }

    @inline(never)
    private func copySavedNativeCrewLog(from source: Storage) {
      savedNativeCrewLog = source.savedNativeCrewLog
    }

    @inline(never)
    private func copySavedNativeInductionUtility(from source: Storage) {
      savedNativeInductionUtility = source.savedNativeInductionUtility
    }

    @inline(never)
    private func copySavedNativeInductionClinic(from source: Storage) {
      savedNativeInductionClinic = source.savedNativeInductionClinic
    }

    @inline(never)
    private func copySavedNativeInductionWorkshop(from source: Storage) {
      savedNativeInductionWorkshop = source.savedNativeInductionWorkshop
    }

    @inline(never)
    private func copySavedNativeInductionSeed(from source: Storage) {
      savedNativeInductionSeed = source.savedNativeInductionSeed
    }

    @inline(never)
    private func copySavedWayfarerInduction(from source: Storage) {
      savedWayfarerInduction = source.savedWayfarerInduction
    }

    @inline(never)
    private func copySavedFlightReception(from source: Storage) {
      savedFlightReception = source.savedFlightReception
    }

    @inline(never)
    private func copySavedMeasuredExtraction(from source: Storage) {
      savedMeasuredExtraction = source.savedMeasuredExtraction
    }

    @inline(never)
    private func copySavedRecordRecovery(from source: Storage) {
      savedRecordRecovery = source.savedRecordRecovery
    }

    @inline(never)
    private func copySavedIdentifiedSalvage(from source: Storage) {
      savedIdentifiedSalvage = source.savedIdentifiedSalvage
    }

    @inline(never)
    private func copyCourier(from source: Storage) {
      courier = source.courier
    }

    @inline(never)
    private func copyPledgeReceiptID(from source: Storage) {
      pledgeReceiptID = source.pledgeReceiptID
    }

    @inline(never)
    private func copyReceiptJoins(from source: Storage) {
      receiptJoins = source.receiptJoins
    }

    @inline(never)
    private func copyOutcome(from source: Storage) {
      outcome = source.outcome
    }

    @inline(never)
    private func copySuspension(from source: Storage) {
      suspension = source.suspension
    }

    @inline(never)
    private func copyRevision(from source: Storage) {
      revision = source.revision
    }

    @inline(never)
    private func copyAcknowledgedEvents(from source: Storage) {
      acknowledgedEvents = source.acknowledgedEvents
    }

    @inline(never)
    private func copyAcknowledgedThrough(from source: Storage) {
      acknowledgedThrough = source.acknowledgedThrough
    }

    @inline(never)
    private func copyReceipts(from source: Storage) {
      receipts = source.receipts
    }

    @inline(never)
    private func copyMilestones(from source: Storage) {
      milestones = source.milestones
    }

    @inline(never)
    private func copyPayloads(from source: Storage) {
      payloads = source.payloads
    }

    @inline(never)
    private func copyTimers(from source: Storage) {
      timers = source.timers
    }

    @inline(never)
    private func copyDialogue(from source: Storage) {
      dialogue = source.dialogue
    }

    @inline(never)
    private func copyJournal(from source: Storage) {
      journal = source.journal
    }

    @inline(never)
    private func copyContract(from source: Storage) {
      contract = source.contract
    }

    @inline(never)
    private func copySavedGearIssues(from source: Storage) {
      savedGearIssues = source.savedGearIssues
    }

    @inline(never)
    private func copySavedOwnedEncounters(from source: Storage) {
      savedOwnedEncounters = source.savedOwnedEncounters
    }

    @inline(never)
    private func copyRandomState(from source: Storage) {
      randomState = source.randomState
    }

    init(from decoder: any Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      id = try values.decode(UUID.self, forKey: .id)
      definition = try values.decode(String.self, forKey: .definition)
      version = try values.decode(String.self, forKey: .version)
      digest = try values.decode(String.self, forKey: .digest)
      try decodeData(from: values)
      try decodeSavedCollections(from: values)
      try decodeSavedCampaignChildren(from: values)
      try decodeCampaignParent(from: values)
      try decodeSavedCampaignReceiptScopes(from: values)
      try decodeSavedConversationReceipts(from: values)
      try decodeSavedChoiceReceipts(from: values)
      try decodeCompletionReceipt(from: values)
      try decodeSavedProviderContract(from: values)
      try decodeSavedOwnedCargo(from: values)
      try decodeSavedWayfarerColdChain(from: values)
      try decodeSavedWayfarerRepairLoop(from: values)
      try decodeSavedFieldRelief(from: values)
      try decodeSavedNavigationTrade(from: values)
      try decodeSavedOriginalSurvey(from: values)
      try decodeSavedGlassMeridian(from: values)
      try decodeSavedArkReserve(from: values)
      try decodeSavedArkRecovery(from: values)
      try decodeSavedNativeArk(from: values)
      try decodeSavedNativeCrewLog(from: values)
      try decodeSavedNativeInductionUtility(from: values)
      try decodeSavedNativeInductionClinic(from: values)
      try decodeSavedNativeInductionWorkshop(from: values)
      try decodeSavedNativeInductionSeed(from: values)
      try decodeSavedWayfarerInduction(from: values)
      try decodeSavedFlightReception(from: values)
      try decodeSavedMeasuredExtraction(from: values)
      try decodeSavedRecordRecovery(from: values)
      try decodeSavedIdentifiedSalvage(from: values)
      try decodeCourier(from: values)
      try decodePledgeReceiptID(from: values)
      try decodeReceiptJoins(from: values)
      try decodeOutcome(from: values)
      try decodeSuspension(from: values)
      try decodeRevision(from: values)
      try decodeAcknowledgedEvents(from: values)
      try decodeAcknowledgedThrough(from: values)
      try decodeReceipts(from: values)
      try decodeMilestones(from: values)
      try decodePayloads(from: values)
      try decodeTimers(from: values)
      try decodeDialogue(from: values)
      try decodeJournal(from: values)
      try decodeContract(from: values)
      try decodeSavedGearIssues(from: values)
      try decodeSavedOwnedEncounters(from: values)
      try decodeRandomState(from: values)
    }

    @inline(never)
    private func decodeData(from values: KeyedDecodingContainer<CodingKeys>) throws {
      data = try values.decode(ScriptValue.self, forKey: .data)
    }

    @inline(never)
    private func decodeSavedCollections(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedCollections = try values.decodeIfPresent(
        [String: ScriptCollection].self, forKey: .savedCollections)
    }

    @inline(never)
    private func decodeSavedCampaignChildren(from values: KeyedDecodingContainer<CodingKeys>) throws
    {
      savedCampaignChildren = try values.decodeIfPresent(
        [String: ScriptChildBinding].self, forKey: .savedCampaignChildren)
    }

    @inline(never)
    private func decodeCampaignParent(from values: KeyedDecodingContainer<CodingKeys>) throws {
      campaignParent = try values.decodeIfPresent(ScriptChildBinding.self, forKey: .campaignParent)
    }

    @inline(never)
    private func decodeSavedCampaignReceiptScopes(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedCampaignReceiptScopes = try values.decodeIfPresent(
        [String: String].self, forKey: .savedCampaignReceiptScopes)
    }

    @inline(never)
    private func decodeSavedConversationReceipts(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedConversationReceipts = try values.decodeIfPresent(
        [UInt64: ScriptChoiceReceipt].self, forKey: .savedConversationReceipts)
    }

    @inline(never)
    private func decodeSavedChoiceReceipts(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedChoiceReceipts = try values.decodeIfPresent(
        [String: ScriptChoiceReceipt].self, forKey: .savedChoiceReceipts)
    }

    @inline(never)
    private func decodeCompletionReceipt(from values: KeyedDecodingContainer<CodingKeys>) throws {
      completionReceipt = try values.decodeIfPresent(
        ScriptCompletionReceipt.self, forKey: .completionReceipt)
    }

    @inline(never)
    private func decodeSavedProviderContract(from values: KeyedDecodingContainer<CodingKeys>) throws
    {
      savedProviderContract = try values.decodeIfPresent(
        ScriptProviderContractState.self, forKey: .savedProviderContract)
    }

    @inline(never)
    private func decodeSavedOwnedCargo(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedOwnedCargo = try values.decodeIfPresent(
        ScriptOwnedCargoState.self, forKey: .savedOwnedCargo)
    }

    @inline(never)
    private func decodeSavedWayfarerColdChain(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedWayfarerColdChain = try values.decodeIfPresent(
        WayfarerColdChainCustody.self, forKey: .savedWayfarerColdChain)
    }

    @inline(never)
    private func decodeSavedWayfarerRepairLoop(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedWayfarerRepairLoop = try values.decodeIfPresent(
        WayfarerRepairLoopCustody.self, forKey: .savedWayfarerRepairLoop)
    }

    @inline(never)
    private func decodeSavedFieldRelief(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedFieldRelief = try values.decodeIfPresent(
        WayfarerFieldReliefCustody.self, forKey: .savedFieldRelief)
    }

    @inline(never)
    private func decodeSavedNavigationTrade(from values: KeyedDecodingContainer<CodingKeys>) throws
    {
      savedNavigationTrade = try values.decodeIfPresent(
        ScriptNavigationTradeState.self, forKey: .savedNavigationTrade)
    }

    @inline(never)
    private func decodeSavedOriginalSurvey(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedOriginalSurvey = try values.decodeIfPresent(
        NativeOriginalSurveyState.self, forKey: .savedOriginalSurvey)
    }

    @inline(never)
    private func decodeSavedGlassMeridian(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedGlassMeridian = try values.decodeIfPresent(
        NativeGlassMeridianState.self, forKey: .savedGlassMeridian)
    }

    @inline(never)
    private func decodeSavedArkReserve(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedArkReserve = try values.decodeIfPresent(
        NativeInductionArkReserve.self, forKey: .savedArkReserve)
    }

    @inline(never)
    private func decodeSavedArkRecovery(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedArkRecovery = try values.decodeIfPresent(
        NativeArkRecoveryReceipt.self, forKey: .savedArkRecovery)
    }

    @inline(never)
    private func decodeSavedNativeArk(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedNativeArk = try values.decodeIfPresent(
        NativeInductionArkState.self, forKey: .savedNativeArk)
    }

    @inline(never)
    private func decodeSavedNativeCrewLog(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedNativeCrewLog = try values.decodeIfPresent(
        NativeInductionCrewLogState.self, forKey: .savedNativeCrewLog)
    }

    @inline(never)
    private func decodeSavedNativeInductionUtility(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedNativeInductionUtility = try values.decodeIfPresent(
        NativeInductionUtilityState.self, forKey: .savedNativeInductionUtility)
    }

    @inline(never)
    private func decodeSavedNativeInductionClinic(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedNativeInductionClinic = try values.decodeIfPresent(
        NativeInductionClinicContract.self, forKey: .savedNativeInductionClinic)
    }

    @inline(never)
    private func decodeSavedNativeInductionWorkshop(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedNativeInductionWorkshop = try values.decodeIfPresent(
        NativeInductionWorkshopContract.self, forKey: .savedNativeInductionWorkshop)
    }

    @inline(never)
    private func decodeSavedNativeInductionSeed(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedNativeInductionSeed = try values.decodeIfPresent(
        NativeInductionSeedContract.self, forKey: .savedNativeInductionSeed)
    }

    @inline(never)
    private func decodeSavedWayfarerInduction(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedWayfarerInduction = try values.decodeIfPresent(
        NativeWayfarerInductionState.self, forKey: .savedWayfarerInduction)
    }

    @inline(never)
    private func decodeSavedFlightReception(from values: KeyedDecodingContainer<CodingKeys>) throws
    {
      savedFlightReception = try values.decodeIfPresent(
        NativeFlightReceptionState.self, forKey: .savedFlightReception)
    }

    @inline(never)
    private func decodeSavedMeasuredExtraction(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedMeasuredExtraction = try values.decodeIfPresent(
        NativeMeasuredExtractionState.self, forKey: .savedMeasuredExtraction)
    }

    @inline(never)
    private func decodeSavedRecordRecovery(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedRecordRecovery = try values.decodeIfPresent(
        WayfarerRecordRecoveryState.self, forKey: .savedRecordRecovery)
    }

    @inline(never)
    private func decodeSavedIdentifiedSalvage(from values: KeyedDecodingContainer<CodingKeys>)
      throws
    {
      savedIdentifiedSalvage = try values.decodeIfPresent(
        NativeIdentifiedSalvageState.self, forKey: .savedIdentifiedSalvage)
    }

    @inline(never)
    private func decodeCourier(from values: KeyedDecodingContainer<CodingKeys>) throws {
      courier = try values.decodeIfPresent(ScriptCourierCustody.self, forKey: .courier)
    }

    @inline(never)
    private func decodePledgeReceiptID(from values: KeyedDecodingContainer<CodingKeys>) throws {
      pledgeReceiptID = try values.decodeIfPresent(UUID.self, forKey: .pledgeReceiptID)
    }

    @inline(never)
    private func decodeReceiptJoins(from values: KeyedDecodingContainer<CodingKeys>) throws {
      receiptJoins = try values.decodeIfPresent([String: [UUID]].self, forKey: .receiptJoins)
    }

    @inline(never)
    private func decodeOutcome(from values: KeyedDecodingContainer<CodingKeys>) throws {
      outcome = try values.decode(ScriptOutcome.self, forKey: .outcome)
    }

    @inline(never)
    private func decodeSuspension(from values: KeyedDecodingContainer<CodingKeys>) throws {
      suspension = try values.decodeIfPresent(String.self, forKey: .suspension)
    }

    @inline(never)
    private func decodeRevision(from values: KeyedDecodingContainer<CodingKeys>) throws {
      revision = try values.decode(UInt64.self, forKey: .revision)
    }

    @inline(never)
    private func decodeAcknowledgedEvents(from values: KeyedDecodingContainer<CodingKeys>) throws {
      acknowledgedEvents = try values.decode(Set<UInt64>.self, forKey: .acknowledgedEvents)
    }

    @inline(never)
    private func decodeAcknowledgedThrough(from values: KeyedDecodingContainer<CodingKeys>) throws {
      acknowledgedThrough = try values.decodeIfPresent(UInt64.self, forKey: .acknowledgedThrough)
    }

    @inline(never)
    private func decodeReceipts(from values: KeyedDecodingContainer<CodingKeys>) throws {
      receipts = try values.decode(Set<String>.self, forKey: .receipts)
    }

    @inline(never)
    private func decodeMilestones(from values: KeyedDecodingContainer<CodingKeys>) throws {
      milestones = try values.decode(Set<Int>.self, forKey: .milestones)
    }

    @inline(never)
    private func decodePayloads(from values: KeyedDecodingContainer<CodingKeys>) throws {
      payloads = try values.decode([String: Int].self, forKey: .payloads)
    }

    @inline(never)
    private func decodeTimers(from values: KeyedDecodingContainer<CodingKeys>) throws {
      timers = try values.decode([String: ScriptTimer].self, forKey: .timers)
    }

    @inline(never)
    private func decodeDialogue(from values: KeyedDecodingContainer<CodingKeys>) throws {
      dialogue = try values.decodeIfPresent(ScriptDialogue.self, forKey: .dialogue)
    }

    @inline(never)
    private func decodeJournal(from values: KeyedDecodingContainer<CodingKeys>) throws {
      journal = try values.decode([String].self, forKey: .journal)
    }

    @inline(never)
    private func decodeContract(from values: KeyedDecodingContainer<CodingKeys>) throws {
      contract = try values.decodeIfPresent(ScriptContractJob.self, forKey: .contract)
    }

    @inline(never)
    private func decodeSavedGearIssues(from values: KeyedDecodingContainer<CodingKeys>) throws {
      savedGearIssues = try values.decodeIfPresent(
        [String: ScriptGearIssue].self, forKey: .savedGearIssues)
    }

    @inline(never)
    private func decodeSavedOwnedEncounters(from values: KeyedDecodingContainer<CodingKeys>) throws
    {
      savedOwnedEncounters = try values.decodeIfPresent(
        [String: ScriptOwnedEncounter].self, forKey: .savedOwnedEncounters)
    }

    @inline(never)
    private func decodeRandomState(from values: KeyedDecodingContainer<CodingKeys>) throws {
      randomState = try values.decode(UInt64.self, forKey: .randomState)
    }

    func encode(to encoder: any Encoder) throws {
      var values = encoder.container(keyedBy: CodingKeys.self)
      try encodeId(to: &values)
      try encodeDefinition(to: &values)
      try encodeVersion(to: &values)
      try encodeDigest(to: &values)
      try encodeData(to: &values)
      try encodeSavedCollections(to: &values)
      try encodeSavedCampaignChildren(to: &values)
      try encodeCampaignParent(to: &values)
      try encodeSavedCampaignReceiptScopes(to: &values)
      try encodeSavedConversationReceipts(to: &values)
      try encodeSavedChoiceReceipts(to: &values)
      try encodeCompletionReceipt(to: &values)
      try encodeSavedProviderContract(to: &values)
      try encodeSavedOwnedCargo(to: &values)
      try encodeSavedWayfarerColdChain(to: &values)
      try encodeSavedWayfarerRepairLoop(to: &values)
      try encodeSavedFieldRelief(to: &values)
      try encodeSavedNavigationTrade(to: &values)
      try encodeSavedOriginalSurvey(to: &values)
      try encodeSavedGlassMeridian(to: &values)
      try encodeSavedArkReserve(to: &values)
      try encodeSavedArkRecovery(to: &values)
      try encodeSavedNativeArk(to: &values)
      try encodeSavedNativeCrewLog(to: &values)
      try encodeSavedNativeInductionUtility(to: &values)
      try encodeSavedNativeInductionClinic(to: &values)
      try encodeSavedNativeInductionWorkshop(to: &values)
      try encodeSavedNativeInductionSeed(to: &values)
      try encodeSavedWayfarerInduction(to: &values)
      try encodeSavedFlightReception(to: &values)
      try encodeSavedMeasuredExtraction(to: &values)
      try encodeSavedRecordRecovery(to: &values)
      try encodeSavedIdentifiedSalvage(to: &values)
      try encodeCourier(to: &values)
      try encodePledgeReceiptID(to: &values)
      try encodeReceiptJoins(to: &values)
      try encodeOutcome(to: &values)
      try encodeSuspension(to: &values)
      try encodeRevision(to: &values)
      try encodeAcknowledgedEvents(to: &values)
      try encodeAcknowledgedThrough(to: &values)
      try encodeReceipts(to: &values)
      try encodeMilestones(to: &values)
      try encodePayloads(to: &values)
      try encodeTimers(to: &values)
      try encodeDialogue(to: &values)
      try encodeJournal(to: &values)
      try encodeContract(to: &values)
      try encodeSavedGearIssues(to: &values)
      try encodeSavedOwnedEncounters(to: &values)
      try encodeRandomState(to: &values)
    }

    @inline(never)
    private func encodeId(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(id, forKey: .id)
    }

    @inline(never)
    private func encodeDefinition(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(definition, forKey: .definition)
    }

    @inline(never)
    private func encodeVersion(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(version, forKey: .version)
    }

    @inline(never)
    private func encodeDigest(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(digest, forKey: .digest)
    }

    @inline(never)
    private func encodeData(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(data, forKey: .data)
    }

    @inline(never)
    private func encodeSavedCollections(to values: inout KeyedEncodingContainer<CodingKeys>) throws
    {
      try values.encodeIfPresent(savedCollections, forKey: .savedCollections)
    }

    @inline(never)
    private func encodeSavedCampaignChildren(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedCampaignChildren, forKey: .savedCampaignChildren)
    }

    @inline(never)
    private func encodeCampaignParent(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(campaignParent, forKey: .campaignParent)
    }

    @inline(never)
    private func encodeSavedCampaignReceiptScopes(
      to values: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
      try values.encodeIfPresent(savedCampaignReceiptScopes, forKey: .savedCampaignReceiptScopes)
    }

    @inline(never)
    private func encodeSavedConversationReceipts(
      to values: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
      try values.encodeIfPresent(savedConversationReceipts, forKey: .savedConversationReceipts)
    }

    @inline(never)
    private func encodeSavedChoiceReceipts(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedChoiceReceipts, forKey: .savedChoiceReceipts)
    }

    @inline(never)
    private func encodeCompletionReceipt(to values: inout KeyedEncodingContainer<CodingKeys>) throws
    {
      try values.encodeIfPresent(completionReceipt, forKey: .completionReceipt)
    }

    @inline(never)
    private func encodeSavedProviderContract(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedProviderContract, forKey: .savedProviderContract)
    }

    @inline(never)
    private func encodeSavedOwnedCargo(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(savedOwnedCargo, forKey: .savedOwnedCargo)
    }

    @inline(never)
    private func encodeSavedWayfarerColdChain(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedWayfarerColdChain, forKey: .savedWayfarerColdChain)
    }

    @inline(never)
    private func encodeSavedWayfarerRepairLoop(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedWayfarerRepairLoop, forKey: .savedWayfarerRepairLoop)
    }

    @inline(never)
    private func encodeSavedFieldRelief(to values: inout KeyedEncodingContainer<CodingKeys>) throws
    {
      try values.encodeIfPresent(savedFieldRelief, forKey: .savedFieldRelief)
    }

    @inline(never)
    private func encodeSavedNavigationTrade(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedNavigationTrade, forKey: .savedNavigationTrade)
    }

    @inline(never)
    private func encodeSavedOriginalSurvey(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedOriginalSurvey, forKey: .savedOriginalSurvey)
    }

    @inline(never)
    private func encodeSavedGlassMeridian(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedGlassMeridian, forKey: .savedGlassMeridian)
    }

    @inline(never)
    private func encodeSavedArkReserve(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(savedArkReserve, forKey: .savedArkReserve)
    }

    @inline(never)
    private func encodeSavedArkRecovery(to values: inout KeyedEncodingContainer<CodingKeys>) throws
    {
      try values.encodeIfPresent(savedArkRecovery, forKey: .savedArkRecovery)
    }

    @inline(never)
    private func encodeSavedNativeArk(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(savedNativeArk, forKey: .savedNativeArk)
    }

    @inline(never)
    private func encodeSavedNativeCrewLog(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedNativeCrewLog, forKey: .savedNativeCrewLog)
    }

    @inline(never)
    private func encodeSavedNativeInductionUtility(
      to values: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
      try values.encodeIfPresent(savedNativeInductionUtility, forKey: .savedNativeInductionUtility)
    }

    @inline(never)
    private func encodeSavedNativeInductionClinic(
      to values: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
      try values.encodeIfPresent(savedNativeInductionClinic, forKey: .savedNativeInductionClinic)
    }

    @inline(never)
    private func encodeSavedNativeInductionWorkshop(
      to values: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
      try values.encodeIfPresent(
        savedNativeInductionWorkshop, forKey: .savedNativeInductionWorkshop)
    }

    @inline(never)
    private func encodeSavedNativeInductionSeed(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedNativeInductionSeed, forKey: .savedNativeInductionSeed)
    }

    @inline(never)
    private func encodeSavedWayfarerInduction(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedWayfarerInduction, forKey: .savedWayfarerInduction)
    }

    @inline(never)
    private func encodeSavedFlightReception(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedFlightReception, forKey: .savedFlightReception)
    }

    @inline(never)
    private func encodeSavedMeasuredExtraction(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedMeasuredExtraction, forKey: .savedMeasuredExtraction)
    }

    @inline(never)
    private func encodeSavedRecordRecovery(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedRecordRecovery, forKey: .savedRecordRecovery)
    }

    @inline(never)
    private func encodeSavedIdentifiedSalvage(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedIdentifiedSalvage, forKey: .savedIdentifiedSalvage)
    }

    @inline(never)
    private func encodeCourier(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(courier, forKey: .courier)
    }

    @inline(never)
    private func encodePledgeReceiptID(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(pledgeReceiptID, forKey: .pledgeReceiptID)
    }

    @inline(never)
    private func encodeReceiptJoins(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(receiptJoins, forKey: .receiptJoins)
    }

    @inline(never)
    private func encodeOutcome(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(outcome, forKey: .outcome)
    }

    @inline(never)
    private func encodeSuspension(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(suspension, forKey: .suspension)
    }

    @inline(never)
    private func encodeRevision(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(revision, forKey: .revision)
    }

    @inline(never)
    private func encodeAcknowledgedEvents(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encode(acknowledgedEvents, forKey: .acknowledgedEvents)
    }

    @inline(never)
    private func encodeAcknowledgedThrough(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(acknowledgedThrough, forKey: .acknowledgedThrough)
    }

    @inline(never)
    private func encodeReceipts(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(receipts, forKey: .receipts)
    }

    @inline(never)
    private func encodeMilestones(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(milestones, forKey: .milestones)
    }

    @inline(never)
    private func encodePayloads(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(payloads, forKey: .payloads)
    }

    @inline(never)
    private func encodeTimers(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(timers, forKey: .timers)
    }

    @inline(never)
    private func encodeDialogue(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(dialogue, forKey: .dialogue)
    }

    @inline(never)
    private func encodeJournal(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(journal, forKey: .journal)
    }

    @inline(never)
    private func encodeContract(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(contract, forKey: .contract)
    }

    @inline(never)
    private func encodeSavedGearIssues(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encodeIfPresent(savedGearIssues, forKey: .savedGearIssues)
    }

    @inline(never)
    private func encodeSavedOwnedEncounters(to values: inout KeyedEncodingContainer<CodingKeys>)
      throws
    {
      try values.encodeIfPresent(savedOwnedEncounters, forKey: .savedOwnedEncounters)
    }

    @inline(never)
    private func encodeRandomState(to values: inout KeyedEncodingContainer<CodingKeys>) throws {
      try values.encode(randomState, forKey: .randomState)
    }
  }

  private var payload: Storage

  init(id: UUID, definition: String, version: String, digest: String) {
    payload = Storage(id: id, definition: definition, version: version, digest: digest)
  }

  @inline(never)
  private mutating func ensureUniqueStorage() {
    if !isKnownUniquelyReferenced(&payload) { payload = Storage(copying: payload) }
  }

  var id: UUID {
    _read { yield payload.id }
  }

  var definition: String {
    _read { yield payload.definition }
  }

  var version: String {
    _read { yield payload.version }
  }

  var digest: String {
    _read { yield payload.digest }
  }

  var data: ScriptValue {
    _read { yield payload.data }
    set {
      ensureUniqueStorage()
      payload.data = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.data
    }
  }

  var savedCollections: [String: ScriptCollection]? {
    _read { yield payload.savedCollections }
    set {
      ensureUniqueStorage()
      payload.savedCollections = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedCollections
    }
  }

  var savedCampaignChildren: [String: ScriptChildBinding]? {
    _read { yield payload.savedCampaignChildren }
    set {
      ensureUniqueStorage()
      payload.savedCampaignChildren = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedCampaignChildren
    }
  }

  var campaignParent: ScriptChildBinding? {
    _read { yield payload.campaignParent }
    set {
      ensureUniqueStorage()
      payload.campaignParent = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.campaignParent
    }
  }

  var savedCampaignReceiptScopes: [String: String]? {
    _read { yield payload.savedCampaignReceiptScopes }
    set {
      ensureUniqueStorage()
      payload.savedCampaignReceiptScopes = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedCampaignReceiptScopes
    }
  }

  var savedConversationReceipts: [UInt64: ScriptChoiceReceipt]? {
    _read { yield payload.savedConversationReceipts }
    set {
      ensureUniqueStorage()
      payload.savedConversationReceipts = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedConversationReceipts
    }
  }

  var savedChoiceReceipts: [String: ScriptChoiceReceipt]? {
    _read { yield payload.savedChoiceReceipts }
    set {
      ensureUniqueStorage()
      payload.savedChoiceReceipts = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedChoiceReceipts
    }
  }

  var completionReceipt: ScriptCompletionReceipt? {
    _read { yield payload.completionReceipt }
    set {
      ensureUniqueStorage()
      payload.completionReceipt = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.completionReceipt
    }
  }

  var savedProviderContract: ScriptProviderContractState? {
    _read { yield payload.savedProviderContract }
    set {
      ensureUniqueStorage()
      payload.savedProviderContract = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedProviderContract
    }
  }

  var savedOwnedCargo: ScriptOwnedCargoState? {
    _read { yield payload.savedOwnedCargo }
    set {
      ensureUniqueStorage()
      payload.savedOwnedCargo = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedOwnedCargo
    }
  }

  var savedWayfarerColdChain: WayfarerColdChainCustody? {
    _read { yield payload.savedWayfarerColdChain }
    set {
      ensureUniqueStorage()
      payload.savedWayfarerColdChain = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedWayfarerColdChain
    }
  }

  var savedWayfarerRepairLoop: WayfarerRepairLoopCustody? {
    _read { yield payload.savedWayfarerRepairLoop }
    set {
      ensureUniqueStorage()
      payload.savedWayfarerRepairLoop = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedWayfarerRepairLoop
    }
  }

  var savedFieldRelief: WayfarerFieldReliefCustody? {
    _read { yield payload.savedFieldRelief }
    set {
      ensureUniqueStorage()
      payload.savedFieldRelief = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedFieldRelief
    }
  }

  var savedNavigationTrade: ScriptNavigationTradeState? {
    _read { yield payload.savedNavigationTrade }
    set {
      ensureUniqueStorage()
      payload.savedNavigationTrade = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedNavigationTrade
    }
  }

  var savedOriginalSurvey: NativeOriginalSurveyState? {
    _read { yield payload.savedOriginalSurvey }
    set {
      ensureUniqueStorage()
      payload.savedOriginalSurvey = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedOriginalSurvey
    }
  }

  var savedGlassMeridian: NativeGlassMeridianState? {
    _read { yield payload.savedGlassMeridian }
    set {
      ensureUniqueStorage()
      payload.savedGlassMeridian = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedGlassMeridian
    }
  }

  var savedArkReserve: NativeInductionArkReserve? {
    _read { yield payload.savedArkReserve }
    set {
      ensureUniqueStorage()
      payload.savedArkReserve = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedArkReserve
    }
  }

  var savedArkRecovery: NativeArkRecoveryReceipt? {
    _read { yield payload.savedArkRecovery }
    set {
      ensureUniqueStorage()
      payload.savedArkRecovery = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedArkRecovery
    }
  }

  var savedNativeArk: NativeInductionArkState? {
    _read { yield payload.savedNativeArk }
    set {
      ensureUniqueStorage()
      payload.savedNativeArk = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedNativeArk
    }
  }

  var savedNativeCrewLog: NativeInductionCrewLogState? {
    _read { yield payload.savedNativeCrewLog }
    set {
      ensureUniqueStorage()
      payload.savedNativeCrewLog = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedNativeCrewLog
    }
  }

  var savedNativeInductionUtility: NativeInductionUtilityState? {
    _read { yield payload.savedNativeInductionUtility }
    set {
      ensureUniqueStorage()
      payload.savedNativeInductionUtility = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedNativeInductionUtility
    }
  }

  var savedNativeInductionClinic: NativeInductionClinicContract? {
    _read { yield payload.savedNativeInductionClinic }
    set {
      ensureUniqueStorage()
      payload.savedNativeInductionClinic = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedNativeInductionClinic
    }
  }

  var savedNativeInductionWorkshop: NativeInductionWorkshopContract? {
    _read { yield payload.savedNativeInductionWorkshop }
    set {
      ensureUniqueStorage()
      payload.savedNativeInductionWorkshop = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedNativeInductionWorkshop
    }
  }

  var savedNativeInductionSeed: NativeInductionSeedContract? {
    _read { yield payload.savedNativeInductionSeed }
    set {
      ensureUniqueStorage()
      payload.savedNativeInductionSeed = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedNativeInductionSeed
    }
  }

  var savedWayfarerInduction: NativeWayfarerInductionState? {
    _read { yield payload.savedWayfarerInduction }
    set {
      ensureUniqueStorage()
      payload.savedWayfarerInduction = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedWayfarerInduction
    }
  }

  var savedFlightReception: NativeFlightReceptionState? {
    _read { yield payload.savedFlightReception }
    set {
      ensureUniqueStorage()
      payload.savedFlightReception = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedFlightReception
    }
  }

  var savedMeasuredExtraction: NativeMeasuredExtractionState? {
    _read { yield payload.savedMeasuredExtraction }
    set {
      ensureUniqueStorage()
      payload.savedMeasuredExtraction = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedMeasuredExtraction
    }
  }

  var savedRecordRecovery: WayfarerRecordRecoveryState? {
    _read { yield payload.savedRecordRecovery }
    set {
      ensureUniqueStorage()
      payload.savedRecordRecovery = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedRecordRecovery
    }
  }

  var savedIdentifiedSalvage: NativeIdentifiedSalvageState? {
    _read { yield payload.savedIdentifiedSalvage }
    set {
      ensureUniqueStorage()
      payload.savedIdentifiedSalvage = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedIdentifiedSalvage
    }
  }

  var courier: ScriptCourierCustody? {
    _read { yield payload.courier }
    set {
      ensureUniqueStorage()
      payload.courier = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.courier
    }
  }

  var pledgeReceiptID: UUID? {
    _read { yield payload.pledgeReceiptID }
    set {
      ensureUniqueStorage()
      payload.pledgeReceiptID = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.pledgeReceiptID
    }
  }

  var receiptJoins: [String: [UUID]]? {
    _read { yield payload.receiptJoins }
    set {
      ensureUniqueStorage()
      payload.receiptJoins = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.receiptJoins
    }
  }

  var outcome: ScriptOutcome {
    _read { yield payload.outcome }
    set {
      ensureUniqueStorage()
      payload.outcome = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.outcome
    }
  }

  var suspension: String? {
    _read { yield payload.suspension }
    set {
      ensureUniqueStorage()
      payload.suspension = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.suspension
    }
  }

  var revision: UInt64 {
    _read { yield payload.revision }
    set {
      ensureUniqueStorage()
      payload.revision = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.revision
    }
  }

  var acknowledgedEvents: Set<UInt64> {
    _read { yield payload.acknowledgedEvents }
    set {
      ensureUniqueStorage()
      payload.acknowledgedEvents = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.acknowledgedEvents
    }
  }

  var acknowledgedThrough: UInt64? {
    _read { yield payload.acknowledgedThrough }
    set {
      ensureUniqueStorage()
      payload.acknowledgedThrough = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.acknowledgedThrough
    }
  }

  var receipts: Set<String> {
    _read { yield payload.receipts }
    set {
      ensureUniqueStorage()
      payload.receipts = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.receipts
    }
  }

  var milestones: Set<Int> {
    _read { yield payload.milestones }
    set {
      ensureUniqueStorage()
      payload.milestones = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.milestones
    }
  }

  var payloads: [String: Int] {
    _read { yield payload.payloads }
    set {
      ensureUniqueStorage()
      payload.payloads = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.payloads
    }
  }

  var timers: [String: ScriptTimer] {
    _read { yield payload.timers }
    set {
      ensureUniqueStorage()
      payload.timers = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.timers
    }
  }

  var dialogue: ScriptDialogue? {
    _read { yield payload.dialogue }
    set {
      ensureUniqueStorage()
      payload.dialogue = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.dialogue
    }
  }

  var journal: [String] {
    _read { yield payload.journal }
    set {
      ensureUniqueStorage()
      payload.journal = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.journal
    }
  }

  var contract: ScriptContractJob? {
    _read { yield payload.contract }
    set {
      ensureUniqueStorage()
      payload.contract = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.contract
    }
  }

  var savedGearIssues: [String: ScriptGearIssue]? {
    _read { yield payload.savedGearIssues }
    set {
      ensureUniqueStorage()
      payload.savedGearIssues = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedGearIssues
    }
  }

  var savedOwnedEncounters: [String: ScriptOwnedEncounter]? {
    _read { yield payload.savedOwnedEncounters }
    set {
      ensureUniqueStorage()
      payload.savedOwnedEncounters = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.savedOwnedEncounters
    }
  }

  var randomState: UInt64 {
    _read { yield payload.randomState }
    set {
      ensureUniqueStorage()
      payload.randomState = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &payload.randomState
    }
  }

  // Compare every stored field in declaration order without retaining later field temporaries.
  @inline(never)
  static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    guard equalId(lhs.payload, rhs.payload) else { return false }
    guard equalDefinition(lhs.payload, rhs.payload) else { return false }
    guard equalVersion(lhs.payload, rhs.payload) else { return false }
    guard equalDigest(lhs.payload, rhs.payload) else { return false }
    guard equalData(lhs.payload, rhs.payload) else { return false }
    guard equalSavedCollections(lhs.payload, rhs.payload) else { return false }
    guard equalSavedCampaignChildren(lhs.payload, rhs.payload) else { return false }
    guard equalCampaignParent(lhs.payload, rhs.payload) else { return false }
    guard equalSavedCampaignReceiptScopes(lhs.payload, rhs.payload) else { return false }
    guard equalSavedConversationReceipts(lhs.payload, rhs.payload) else { return false }
    guard equalSavedChoiceReceipts(lhs.payload, rhs.payload) else { return false }
    guard equalCompletionReceipt(lhs.payload, rhs.payload) else { return false }
    guard equalSavedProviderContract(lhs.payload, rhs.payload) else { return false }
    guard equalSavedOwnedCargo(lhs.payload, rhs.payload) else { return false }
    guard equalSavedWayfarerColdChain(lhs.payload, rhs.payload) else { return false }
    guard equalSavedWayfarerRepairLoop(lhs.payload, rhs.payload) else { return false }
    guard equalSavedFieldRelief(lhs.payload, rhs.payload) else { return false }
    guard equalSavedNavigationTrade(lhs.payload, rhs.payload) else { return false }
    guard equalSavedOriginalSurvey(lhs.payload, rhs.payload) else { return false }
    guard equalSavedGlassMeridian(lhs.payload, rhs.payload) else { return false }
    guard equalSavedArkReserve(lhs.payload, rhs.payload) else { return false }
    guard equalSavedArkRecovery(lhs.payload, rhs.payload) else { return false }
    guard equalSavedNativeArk(lhs.payload, rhs.payload) else { return false }
    guard equalSavedNativeCrewLog(lhs.payload, rhs.payload) else { return false }
    guard equalSavedNativeInductionUtility(lhs.payload, rhs.payload) else { return false }
    guard equalSavedNativeInductionClinic(lhs.payload, rhs.payload) else { return false }
    guard equalSavedNativeInductionWorkshop(lhs.payload, rhs.payload) else { return false }
    guard equalSavedNativeInductionSeed(lhs.payload, rhs.payload) else { return false }
    guard equalSavedWayfarerInduction(lhs.payload, rhs.payload) else { return false }
    guard equalSavedFlightReception(lhs.payload, rhs.payload) else { return false }
    guard equalSavedMeasuredExtraction(lhs.payload, rhs.payload) else { return false }
    guard equalSavedRecordRecovery(lhs.payload, rhs.payload) else { return false }
    guard equalSavedIdentifiedSalvage(lhs.payload, rhs.payload) else { return false }
    guard equalCourier(lhs.payload, rhs.payload) else { return false }
    guard equalPledgeReceiptID(lhs.payload, rhs.payload) else { return false }
    guard equalReceiptJoins(lhs.payload, rhs.payload) else { return false }
    guard equalOutcome(lhs.payload, rhs.payload) else { return false }
    guard equalSuspension(lhs.payload, rhs.payload) else { return false }
    guard equalRevision(lhs.payload, rhs.payload) else { return false }
    guard equalAcknowledgedEvents(lhs.payload, rhs.payload) else { return false }
    guard equalAcknowledgedThrough(lhs.payload, rhs.payload) else { return false }
    guard equalReceipts(lhs.payload, rhs.payload) else { return false }
    guard equalMilestones(lhs.payload, rhs.payload) else { return false }
    guard equalPayloads(lhs.payload, rhs.payload) else { return false }
    guard equalTimers(lhs.payload, rhs.payload) else { return false }
    guard equalDialogue(lhs.payload, rhs.payload) else { return false }
    guard equalJournal(lhs.payload, rhs.payload) else { return false }
    guard equalContract(lhs.payload, rhs.payload) else { return false }
    guard equalSavedGearIssues(lhs.payload, rhs.payload) else { return false }
    guard equalSavedOwnedEncounters(lhs.payload, rhs.payload) else { return false }
    guard equalRandomState(lhs.payload, rhs.payload) else { return false }
    return true
  }

  @inline(never)
  private static func equalId(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.id == rhs.id
  }

  @inline(never)
  private static func equalDefinition(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.definition == rhs.definition
  }

  @inline(never)
  private static func equalVersion(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.version == rhs.version
  }

  @inline(never)
  private static func equalDigest(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.digest == rhs.digest
  }

  @inline(never)
  private static func equalData(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.data == rhs.data
  }

  @inline(never)
  private static func equalSavedCollections(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedCollections == rhs.savedCollections
  }

  @inline(never)
  private static func equalSavedCampaignChildren(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedCampaignChildren == rhs.savedCampaignChildren
  }

  @inline(never)
  private static func equalCampaignParent(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.campaignParent == rhs.campaignParent
  }

  @inline(never)
  private static func equalSavedCampaignReceiptScopes(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedCampaignReceiptScopes == rhs.savedCampaignReceiptScopes
  }

  @inline(never)
  private static func equalSavedConversationReceipts(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedConversationReceipts == rhs.savedConversationReceipts
  }

  @inline(never)
  private static func equalSavedChoiceReceipts(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedChoiceReceipts == rhs.savedChoiceReceipts
  }

  @inline(never)
  private static func equalCompletionReceipt(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.completionReceipt == rhs.completionReceipt
  }

  @inline(never)
  private static func equalSavedProviderContract(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedProviderContract == rhs.savedProviderContract
  }

  @inline(never)
  private static func equalSavedOwnedCargo(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedOwnedCargo == rhs.savedOwnedCargo
  }

  @inline(never)
  private static func equalSavedWayfarerColdChain(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedWayfarerColdChain == rhs.savedWayfarerColdChain
  }

  @inline(never)
  private static func equalSavedWayfarerRepairLoop(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedWayfarerRepairLoop == rhs.savedWayfarerRepairLoop
  }

  @inline(never)
  private static func equalSavedFieldRelief(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedFieldRelief == rhs.savedFieldRelief
  }

  @inline(never)
  private static func equalSavedNavigationTrade(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedNavigationTrade == rhs.savedNavigationTrade
  }

  @inline(never)
  private static func equalSavedOriginalSurvey(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedOriginalSurvey == rhs.savedOriginalSurvey
  }

  @inline(never)
  private static func equalSavedGlassMeridian(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedGlassMeridian == rhs.savedGlassMeridian
  }

  @inline(never)
  private static func equalSavedArkReserve(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedArkReserve == rhs.savedArkReserve
  }

  @inline(never)
  private static func equalSavedArkRecovery(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedArkRecovery == rhs.savedArkRecovery
  }

  @inline(never)
  private static func equalSavedNativeArk(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedNativeArk == rhs.savedNativeArk
  }

  @inline(never)
  private static func equalSavedNativeCrewLog(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedNativeCrewLog == rhs.savedNativeCrewLog
  }

  @inline(never)
  private static func equalSavedNativeInductionUtility(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedNativeInductionUtility == rhs.savedNativeInductionUtility
  }

  @inline(never)
  private static func equalSavedNativeInductionClinic(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedNativeInductionClinic == rhs.savedNativeInductionClinic
  }

  @inline(never)
  private static func equalSavedNativeInductionWorkshop(
    _ lhs: Storage, _ rhs: Storage
  ) -> Bool {
    lhs.savedNativeInductionWorkshop == rhs.savedNativeInductionWorkshop
  }

  @inline(never)
  private static func equalSavedNativeInductionSeed(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedNativeInductionSeed == rhs.savedNativeInductionSeed
  }

  @inline(never)
  private static func equalSavedWayfarerInduction(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedWayfarerInduction == rhs.savedWayfarerInduction
  }

  @inline(never)
  private static func equalSavedFlightReception(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedFlightReception == rhs.savedFlightReception
  }

  @inline(never)
  private static func equalSavedMeasuredExtraction(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedMeasuredExtraction == rhs.savedMeasuredExtraction
  }

  @inline(never)
  private static func equalSavedRecordRecovery(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedRecordRecovery == rhs.savedRecordRecovery
  }

  @inline(never)
  private static func equalSavedIdentifiedSalvage(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedIdentifiedSalvage == rhs.savedIdentifiedSalvage
  }

  @inline(never)
  private static func equalCourier(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.courier == rhs.courier
  }

  @inline(never)
  private static func equalPledgeReceiptID(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.pledgeReceiptID == rhs.pledgeReceiptID
  }

  @inline(never)
  private static func equalReceiptJoins(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.receiptJoins == rhs.receiptJoins
  }

  @inline(never)
  private static func equalOutcome(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.outcome == rhs.outcome
  }

  @inline(never)
  private static func equalSuspension(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.suspension == rhs.suspension
  }

  @inline(never)
  private static func equalRevision(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.revision == rhs.revision
  }

  @inline(never)
  private static func equalAcknowledgedEvents(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.acknowledgedEvents == rhs.acknowledgedEvents
  }

  @inline(never)
  private static func equalAcknowledgedThrough(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.acknowledgedThrough == rhs.acknowledgedThrough
  }

  @inline(never)
  private static func equalReceipts(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.receipts == rhs.receipts
  }

  @inline(never)
  private static func equalMilestones(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.milestones == rhs.milestones
  }

  @inline(never)
  private static func equalPayloads(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.payloads == rhs.payloads
  }

  @inline(never)
  private static func equalTimers(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.timers == rhs.timers
  }

  @inline(never)
  private static func equalDialogue(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.dialogue == rhs.dialogue
  }

  @inline(never)
  private static func equalJournal(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.journal == rhs.journal
  }

  @inline(never)
  private static func equalContract(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.contract == rhs.contract
  }

  @inline(never)
  private static func equalSavedGearIssues(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.savedGearIssues == rhs.savedGearIssues
  }

  @inline(never)
  private static func equalSavedOwnedEncounters(_ lhs: Storage, _ rhs: Storage)
    -> Bool
  {
    lhs.savedOwnedEncounters == rhs.savedOwnedEncounters
  }

  @inline(never)
  private static func equalRandomState(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.randomState == rhs.randomState
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case definition
    case version
    case digest
    case data
    case savedCollections
    case savedCampaignChildren
    case campaignParent
    case savedCampaignReceiptScopes
    case savedConversationReceipts
    case savedChoiceReceipts
    case completionReceipt
    case savedProviderContract
    case savedOwnedCargo
    case savedWayfarerColdChain
    case savedWayfarerRepairLoop
    case savedFieldRelief
    case savedNavigationTrade
    case savedOriginalSurvey
    case savedGlassMeridian
    case savedArkReserve
    case savedArkRecovery
    case savedNativeArk
    case savedNativeCrewLog
    case savedNativeInductionUtility
    case savedNativeInductionClinic
    case savedNativeInductionWorkshop
    case savedNativeInductionSeed
    case savedWayfarerInduction
    case savedFlightReception
    case savedMeasuredExtraction
    case savedRecordRecovery
    case savedIdentifiedSalvage
    case courier
    case pledgeReceiptID
    case receiptJoins
    case outcome
    case suspension
    case revision
    case acknowledgedEvents
    case acknowledgedThrough
    case receipts
    case milestones
    case payloads
    case timers
    case dialogue
    case journal
    case contract
    case savedGearIssues
    case savedOwnedEncounters
    case randomState
  }

  init(from decoder: any Decoder) throws {
    payload = try Storage(from: decoder)
  }

  func encode(to encoder: any Encoder) throws {
    try payload.encode(to: encoder)
  }
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
  @inline(never)
  var hasHeldGlassMeridianRecorder: Bool {
    storage[0].savedGlassMeridian?.surveyor?.held == true
  }

  @inline(never)
  var hasAwaitingBuyNavigationTrade: Bool {
    storage[0].savedNavigationTrade?.stage == .awaitingBuy
  }

  @inline(never)
  var reservedSeedCargoTonnes: Int {
    storage[0].savedNativeInductionSeed?.reservedCargoTonnes ?? 0
  }

  @inline(never)
  var reservedWorkshopCargoTonnes: Int {
    storage[0].savedNativeInductionWorkshop?.reservedCargoTonnes ?? 0
  }

  @inline(never)
  var reservedClinicCargoTonnes: Int {
    storage[0].savedNativeInductionClinic?.reservedCargoTonnes ?? 0
  }

  @inline(never)
  var retainedCargoPayloads: [String: Int] {
    storage[0].payloads
  }

  @inline(never)
  var retainedSettlementJob: ScriptContractJob? {
    storage[0].contract
  }

  @inline(never)
  var retainedSettlementDefinition: String {
    storage[0].definition
  }

  @inline(never)
  var retainedSettlementCourierTerminalClock: Double? {
    storage[0].courier?.terminal?.proof.clock
  }

  var savedArkReserve: NativeInductionArkReserve? {
    _read { yield storage[0].savedArkReserve }
    _modify { yield &storage[0].savedArkReserve }
  }
  var savedArkRecovery: NativeArkRecoveryReceipt? {
    _read { yield storage[0].savedArkRecovery }
    _modify { yield &storage[0].savedArkRecovery }
  }
  var savedNativeArk: NativeInductionArkState? {
    _read { yield storage[0].savedNativeArk }
    _modify { yield &storage[0].savedNativeArk }
  }
  var savedNativeCrewLog: NativeInductionCrewLogState? {
    _read { yield storage[0].savedNativeCrewLog }
    _modify { yield &storage[0].savedNativeCrewLog }
  }
  var savedNativeInductionSeed: NativeInductionSeedContract? {
    _read { yield storage[0].savedNativeInductionSeed }
    _modify { yield &storage[0].savedNativeInductionSeed }
  }
  var savedNativeInductionWorkshop: NativeInductionWorkshopContract? {
    _read { yield storage[0].savedNativeInductionWorkshop }
    _modify { yield &storage[0].savedNativeInductionWorkshop }
  }
  var savedNativeInductionClinic: NativeInductionClinicContract? {
    _read { yield storage[0].savedNativeInductionClinic }
    _modify { yield &storage[0].savedNativeInductionClinic }
  }
  var savedNativeInductionUtility: NativeInductionUtilityState? {
    _read { yield storage[0].savedNativeInductionUtility }
    _modify { yield &storage[0].savedNativeInductionUtility }
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
  // Retire each field comparison before entering the next nested value graph.
  @inline(never)
  public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    guard equalSavedMeasuredExtractionSource(lhs, rhs) else { return false }
    guard equalSavedRecordRecoverySource(lhs, rhs) else { return false }
    guard equalSavedIdentifiedSalvageSource(lhs, rhs) else { return false }
    guard equalSavedOriginalConsentedFreightSupply(lhs, rhs) else { return false }
    guard equalSavedWayfarerColdChainStock(lhs, rhs) else { return false }
    guard equalSavedWayfarerRepairLoopStock(lhs, rhs) else { return false }
    guard equalSavedFleetDiscovery(lhs, rhs) else { return false }
    guard equalFirstNativeCommoditySale(lhs, rhs) else { return false }
    guard equalSavedClueJournal(lhs, rhs) else { return false }
    guard equalFinanceLedger(lhs, rhs) else { return false }
    guard equalWormholeTransit(lhs, rhs) else { return false }
    guard equalMissionCalendar(lhs, rhs) else { return false }
    guard equalPledgeLedger(lhs, rhs) else { return false }
    guard equalSavedBooks(lhs, rhs) else { return false }
    guard equalSavedWorldJobs(lhs, rhs) else { return false }
    guard equalSavedStationResources(lhs, rhs) else { return false }
    guard equalCalendarLedger(lhs, rhs) else { return false }
    guard equalSavedProjectiles(lhs, rhs) else { return false }
    guard equalSavedGeometry(lhs, rhs) else { return false }
    guard equalInstances(lhs, rhs) else { return false }
    guard equalPendingEvents(lhs, rhs) else { return false }
    guard equalNextEvent(lhs, rhs) else { return false }
    guard equalFlightSeconds(lhs, rhs) else { return false }
    guard equalLocalSeconds(lhs, rhs) else { return false }
    guard equalCalendarSeconds(lhs, rhs) else { return false }
    guard equalTransitSeconds(lhs, rhs) else { return false }
    return true
  }

  @inline(never)
  private static func equalSavedMeasuredExtractionSource(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    lhs.savedMeasuredExtractionSource == rhs.savedMeasuredExtractionSource
  }

  @inline(never)
  private static func equalSavedRecordRecoverySource(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedRecordRecoverySource == rhs.savedRecordRecoverySource
  }

  @inline(never)
  private static func equalSavedIdentifiedSalvageSource(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    lhs.savedIdentifiedSalvageSource == rhs.savedIdentifiedSalvageSource
  }

  @inline(never)
  private static func equalSavedOriginalConsentedFreightSupply(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    lhs.savedOriginalConsentedFreightSupply == rhs.savedOriginalConsentedFreightSupply
  }

  @inline(never)
  private static func equalSavedWayfarerColdChainStock(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedWayfarerColdChainStock == rhs.savedWayfarerColdChainStock
  }

  @inline(never)
  private static func equalSavedWayfarerRepairLoopStock(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    lhs.savedWayfarerRepairLoopStock == rhs.savedWayfarerRepairLoopStock
  }

  @inline(never)
  private static func equalSavedFleetDiscovery(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
  {
    lhs.savedFleetDiscovery == rhs.savedFleetDiscovery
  }

  @inline(never)
  private static func equalFirstNativeCommoditySale(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.firstNativeCommoditySale == rhs.firstNativeCommoditySale
  }

  @inline(never)
  private static func equalSavedClueJournal(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedClueJournal == rhs.savedClueJournal
  }

  @inline(never)
  private static func equalFinanceLedger(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.financeLedger == rhs.financeLedger
  }

  @inline(never)
  private static func equalWormholeTransit(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.wormholeTransit == rhs.wormholeTransit
  }

  @inline(never)
  private static func equalMissionCalendar(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.missionCalendar == rhs.missionCalendar
  }

  @inline(never)
  private static func equalPledgeLedger(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.pledgeLedger == rhs.pledgeLedger
  }

  @inline(never)
  private static func equalSavedBooks(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedBooks == rhs.savedBooks
  }

  @inline(never)
  private static func equalSavedWorldJobs(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedWorldJobs == rhs.savedWorldJobs
  }

  @inline(never)
  private static func equalSavedStationResources(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedStationResources == rhs.savedStationResources
  }

  @inline(never)
  private static func equalCalendarLedger(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.calendarLedger == rhs.calendarLedger
  }

  @inline(never)
  private static func equalSavedProjectiles(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedProjectiles == rhs.savedProjectiles
  }

  @inline(never)
  private static func equalSavedGeometry(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedGeometry == rhs.savedGeometry
  }

  @inline(never)
  private static func equalInstances(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.instances == rhs.instances
  }

  @inline(never)
  private static func equalPendingEvents(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.pendingEvents == rhs.pendingEvents
  }

  @inline(never)
  private static func equalNextEvent(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.nextEvent == rhs.nextEvent
  }

  @inline(never)
  private static func equalFlightSeconds(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.flightSeconds == rhs.flightSeconds
  }

  @inline(never)
  private static func equalLocalSeconds(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.localSeconds == rhs.localSeconds
  }

  @inline(never)
  private static func equalCalendarSeconds(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.calendarSeconds == rhs.calendarSeconds
  }

  @inline(never)
  private static func equalTransitSeconds(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.transitSeconds == rhs.transitSeconds
  }

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
    guard instanceDialoguePrefixValid(instance) else { return false }
    guard instanceCourierPrefixValid(instance) else { return false }
    guard instanceProviderPrefixValid(instance) else { return false }
    guard instanceCargoPrefixValid(instance) else { return false }
    guard instanceArkRecoveryPrefixValid(instance) else { return false }
    guard instanceSeedPrefixValid(instance) else { return false }
    guard instanceWorkshopPrefixValid(instance) else { return false }
    guard instanceClinicPrefixValid(instance) else { return false }
    guard instanceUtilityPrefixValid(instance) else { return false }
    guard instanceCrewLogPrefixValid(instance) else { return false }
    guard instanceArkPrefixValid(instance) else { return false }
    guard instanceInductionPrefixValid(instance) else { return false }
    guard instanceMeridianPrefixValid(instance) else { return false }
    guard instanceReceptionPrefixValid(instance) else { return false }
    guard instanceExtractionPrefixValid(instance) else { return false }
    guard instanceRecordRecoveryPrefixValid(instance) else { return false }
    guard instanceSalvagePrefixValid(instance) else { return false }
    guard instanceSurveyPrefixValid(instance) else { return false }
    guard instanceTradePrefixValid(instance) else { return false }
    guard instanceConversationsPrefixValid(instance) else { return false }
    guard instanceChoicesPrefixValid(instance) else { return false }
    guard instanceCompletionPrefixValid(instance) else { return false }
    guard instanceJoinsPrefixValid(instance) else { return false }
    guard instanceAcknowledgementsPrefixValid(instance) else { return false }
    return true
  }

  @inline(never)
  private func instanceDialoguePrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if let dialogue = instance.dialogue {
      guard PackValidation.localID(dialogue.id), dialogue.token.utf8.count <= 256,
        dialogue.revision <= instance.revision, (0..<8).contains(dialogue.galaxy),
        (0...256).contains(dialogue.system)
      else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceCourierPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if let courier = instance.courier {
      guard courier.valid(state: instance, engine: self) else { return false }
    } else {
      guard instance.contract?.offer.courier == nil else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceProviderPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if let contract = instance.savedProviderContract {
      guard contract.valid(instance: instance) else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceCargoPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if let cargo = instance.savedOwnedCargo {
      guard cargo.valid(state: instance, engine: self) else { return false }
    } else {
      guard instance.contract?.offer.freightPlan == nil else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceArkRecoveryPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.savedArkReserve != nil || instance.savedArkRecovery != nil {
      guard instance.definition == NativeWayfarerInduction.stateID,
        instance.digest == NativeWayfarerInduction.digest,
        let state = instance.savedWayfarerInduction, let reserve = instance.savedArkReserve,
        reserve.valid(permission: state.permission)
      else { return false }
      if let recovery = instance.savedArkRecovery {
        guard let key = state.seedKey,
          recovery.valid(reserve: reserve, key: key, permission: state.permission),
          state.ark == recovery.replacement
        else { return false }
      }
    }
    return true
  }

  @inline(never)
  private func instanceSeedPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if NativeInductionSeedPack.marked(instance) || instance.savedNativeInductionSeed != nil {
      guard NativeInductionSeedSave.shapeValid(instance) else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceWorkshopPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if NativeInductionWorkshopPack.marked(instance) || instance.savedNativeInductionWorkshop != nil
    {
      guard NativeInductionWorkshopSave.shapeValid(instance) else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceClinicPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if NativeInductionClinicPack.marked(instance) || instance.savedNativeInductionClinic != nil {
      guard NativeInductionClinicSave.shapeValid(instance) else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceUtilityPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if NativeInductionUtilityPack.marked(instance) {
      guard instance.definition == NativeInductionUtilityPack.stateID,
        instance.digest == NativeInductionUtilityPack.digest,
        instance.version == NativeInductionUtilityPack.version,
        let utility = instance.savedNativeInductionUtility,
        utility.authorization.job == instance.id,
        instance.payloads.isEmpty
      else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceCrewLogPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if NativeInductionCrewLogPack.marked(instance) {
      guard instance.definition == NativeInductionCrewLogPack.stateID,
        instance.digest == NativeInductionCrewLogPack.digest,
        instance.version == NativeInductionCrewLogPack.version,
        let source = instance.savedNativeCrewLog, source.authorization.job == instance.id,
        instance.payloads.isEmpty
      else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceArkPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if NativeInductionArkPack.marked(instance) {
      guard instance.definition == NativeInductionArkPack.stateID,
        instance.digest == NativeInductionArkPack.digest,
        instance.version == NativeInductionArkPack.version,
        let ark = instance.savedNativeArk, ark.authorization.job == instance.id,
        instance.payloads.isEmpty
      else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceInductionPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == NativeWayfarerInduction.stateID {
      guard let opening = instance.savedWayfarerInduction, opening.valid,
        opening.permission.mission == instance.id, instance.payloads == opening.payloads
      else { return false }
    } else if instance.savedWayfarerInduction != nil {
      return false
    }
    return true
  }

  @inline(never)
  private func instanceMeridianPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == NativeGlassMeridian.stateID {
      return instanceMeridianBodyValid(instance)
    }
    return instanceHasNoMeridianState(instance)
  }

  @inline(never)
  private func instanceMeridianBodyValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard let opening = instance.savedGlassMeridian,
      opening.permission.mission == instance.id, instance.payloads.isEmpty,
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening),
      NativeC01Surveyor.shapeValid(opening)
    else { return false }
    return true
  }

  @inline(never)
  private func instanceHasNoMeridianState(_ instance: borrowing ScriptInstance) -> Bool {
    instance.savedGlassMeridian == nil
  }

  @inline(never)
  private func instanceReceptionPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == NativeFlightReception.stateID {
      guard let practice = instance.savedFlightReception,
        practice.permission.mission == instance.id, instance.payloads.isEmpty
      else { return false }
    } else if instance.savedFlightReception != nil {
      return false
    }
    return true
  }

  @inline(never)
  private func instanceExtractionPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
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
    return true
  }

  @inline(never)
  private func instanceRecordRecoveryPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
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
    return true
  }

  @inline(never)
  private func instanceSalvagePrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
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
    return true
  }

  @inline(never)
  private func instanceSurveyPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if instance.definition == NativeOriginalSurvey.stateID {
      guard let survey = instance.savedOriginalSurvey, survey.definition.valid,
        survey.version == instance.version, survey.digest == instance.digest,
        survey.permission?.mission == instance.id,
        survey.readings.count <= 3, survey.authorities.count == survey.readings.count
      else { return false }
    } else if instance.savedOriginalSurvey != nil {
      return false
    }
    return true
  }

  @inline(never)
  private func instanceTradePrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if let trade = instance.savedNavigationTrade {
      guard trade.valid(instance: instance, engine: self) else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceConversationsPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard instance.collectionsValid(engine: self), instance.conversationReceipts.count <= 1024
    else {
      return false
    }
    for receipt in instance.conversationReceipts {
      guard receipt.key == receipt.value.sequence, receipt.value.group == nil,
        receipt.value.valid(for: instance, engine: self)
      else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceChoicesPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard instance.choiceReceipts.count <= 64 else { return false }
    for receipt in instance.choiceReceipts {
      guard receipt.key == receipt.value.group, receipt.value.valid(for: instance, engine: self)
      else {
        return false
      }
    }
    return true
  }

  @inline(never)
  private func instanceCompletionPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    if let receipt = instance.completionReceipt {
      guard receipt.valid(for: instance, engine: self) else { return false }
    }
    return true
  }

  @inline(never)
  private func instanceJoinsPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
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
    return true
  }

  @inline(never)
  private func instanceAcknowledgementsPrefixValid(_ instance: borrowing ScriptInstance) -> Bool {
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
