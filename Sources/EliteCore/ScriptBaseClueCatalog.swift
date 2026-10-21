import Foundation

public struct ScriptBaseClueSource: Sendable, Equatable {
  public let sourceID: String
  public let clueID: String
  public var receiptID: String { "l337.unwritten-route/clue/" + clueID }
}

/// Exact approved design identities, not executable-content authorization or runnable packs.
public enum ScriptBaseClueCatalog {
  public static let id = "l337.base-missions"
  public static let sources: [ScriptBaseClueSource] = [
    .init(sourceID: "l337.glass-meridian", clueID: "meridian-offset"),
    .init(sourceID: "l337.quiet-choir", clueID: "choir-silent-voice"),
    .init(sourceID: "l337.hollow-manifest", clueID: "manifest-hidden-imprint"),
    .init(sourceID: "l337.guiding-light", clueID: "lantern-extra-echo"),
    .init(sourceID: "l337.courier", clueID: "courier-empty-destination"),
    .init(sourceID: "l337.borrowed-voice", clueID: "voice-unclaimed-channel"),
    .init(sourceID: "l337.shattered-wake", clueID: "wake-before-impact"),
    .init(sourceID: "l337.tithe-of-worlds", clueID: "tithe-unclaimed-reserve"),
    .init(sourceID: "l337.still-current", clueID: "current-resting-arc"),
    .init(sourceID: "l337.wayfarer-exchange", clueID: "exchange-unbooked-window"),
    .init(sourceID: "l337.quiet-nursery", clueID: "quiet-nursery-trace"),
    .init(sourceID: "l337.borrowed-dawn", clueID: "borrowed-dawn-trace"),
    .init(sourceID: "l337.open-shadow", clueID: "open-shadow-trace"),
    .init(sourceID: "l337.harbour-without-orders", clueID: "harbour-without-orders-trace"),
    .init(sourceID: "l337.false-colours", clueID: "false-colours-trace"),
    .init(sourceID: "l337.rubble-covenant", clueID: "rubble-covenant-trace"),
    .init(sourceID: "l337.garden-in-transit", clueID: "garden-in-transit-trace"),
    .init(sourceID: "l337.warrant-ledger", clueID: "warrant-ledger-trace"),
    .init(sourceID: "l337.measure-of-care", clueID: "measure-of-care-trace"),
    .init(sourceID: "l337.long-return", clueID: "long-return-trace"),
    .init(sourceID: "l337.unfinished-map", clueID: "unfinished-map-trace"),
    .init(sourceID: "l337.blue-reservoir", clueID: "blue-reservoir-trace"),
    .init(sourceID: "l337.mutual-shelter", clueID: "mutual-shelter-trace"),
    .init(sourceID: "l337.listening-frontier", clueID: "listening-frontier-trace"),
    .init(sourceID: "l337.assembly-of-orbits", clueID: "assembly-of-orbits-trace"),
    .init(sourceID: "l337.under-tow", clueID: "under-tow-trace"),
    .init(sourceID: "l337.memory-atlas", clueID: "memory-atlas-trace"),
    .init(sourceID: "l337.fleet-of-neighbours", clueID: "fleet-of-neighbours-trace"),
    .init(sourceID: "l337.uncounted-names", clueID: "uncounted-names-trace"),
    .init(sourceID: "l337.honest-circuit", clueID: "honest-circuit-trace"),
    .init(sourceID: "l337.small-lights", clueID: "small-lights-trace"),
    .init(sourceID: "l337.passengers-horizon", clueID: "passengers-horizon-trace"),
    .init(sourceID: "l337.kind-distance", clueID: "kind-distance-trace"),
    .init(sourceID: "l337.cold-reserve", clueID: "cold-reserve-trace"),
    .init(sourceID: "l337.magnetic-orchard", clueID: "magnetic-orchard-trace"),
    .init(sourceID: "l337.open-measure", clueID: "open-measure-trace"),
    .init(sourceID: "l337.shared-pulse", clueID: "shared-pulse-trace"),
    .init(sourceID: "l337.witness-window", clueID: "witness-window-trace"),
    .init(sourceID: "l337.public-record", clueID: "public-record-trace"),
    .init(sourceID: "l337.contract/sealed-dispatch", clueID: "sealed-dispatch-family-trace"),
    .init(sourceID: "l337.contract/consented-freight", clueID: "consented-freight-family-trace"),
    .init(sourceID: "l337.contract/bonded-freight", clueID: "bonded-freight-family-trace"),
    .init(sourceID: "l337.contract/cabin-journey", clueID: "cabin-journey-family-trace"),
    .init(sourceID: "l337.contract/orbital-outlook", clueID: "orbital-outlook-family-trace"),
    .init(sourceID: "l337.contract/verified-warrant", clueID: "verified-warrant-family-trace"),
    .init(sourceID: "l337.contract/corridor-defence", clueID: "corridor-defence-family-trace"),
    .init(sourceID: "l337.contract/custody-rescue", clueID: "custody-rescue-family-trace"),
    .init(sourceID: "l337.contract/identified-salvage", clueID: "identified-salvage-family-trace"),
    .init(sourceID: "l337.contract/consented-survey", clueID: "consented-survey-family-trace"),
    .init(sourceID: "l337.contract/isolation-work", clueID: "isolation-work-family-trace"),
    .init(
      sourceID: "l337.contract/measured-extraction", clueID: "measured-extraction-family-trace"),
    .init(
      sourceID: "l337.contract/mutual-contribution", clueID: "mutual-contribution-family-trace"),
    .init(sourceID: "l337.contract/orbital-evacuation", clueID: "orbital-evacuation-family-trace"),
    .init(
      sourceID: "l337.contract/hostile-larvaal-defence",
      clueID: "hostile-larvaal-defence-family-trace"),
    .init(sourceID: "l337.training/flight-reception", clueID: "flight-reception-family-trace"),
    .init(sourceID: "l337.training/safe-gunnery", clueID: "safe-gunnery-family-trace"),
    .init(sourceID: "l337.training/defensive-flight", clueID: "defensive-flight-family-trace"),
    .init(sourceID: "l337.training/navigation-trade", clueID: "navigation-trade-family-trace"),
    .init(sourceID: "l337.wayfarer-service/cold-chain", clueID: "exchange-service-cold-chain"),
    .init(sourceID: "l337.wayfarer-service/repair-loop", clueID: "exchange-service-repair-loop"),
    .init(
      sourceID: "l337.wayfarer-service/seed-transfer", clueID: "exchange-service-seed-transfer"),
    .init(sourceID: "l337.wayfarer-service/field-relief", clueID: "exchange-service-field-relief"),
    .init(
      sourceID: "l337.wayfarer-service/record-recovery", clueID: "exchange-service-record-recovery"),
    .init(sourceID: "l337.wayfarer-service/convoy-watch", clueID: "exchange-service-convoy-watch"),
  ]
  static let bySource = Dictionary(uniqueKeysWithValues: sources.map { ($0.sourceID, $0) })
  static let requiredClueIDs = Set(sources.map(\.clueID))
}

/// Compiled native approval of exact executable content; never decoded or read from a manifest.
struct ScriptClueExecutionPin: Sendable, Equatable {
  let sourceID: String
  let definition: String
  let version: String
  let digest: String
  let terminalEvents: Set<String>

  var valid: Bool {
    ScriptBaseClueCatalog.bySource[sourceID] != nil
      && definition.split(separator: "/", omittingEmptySubsequences: false).count == 2
      && definition.split(separator: "/").allSatisfy { PackValidation.identifier(String($0)) }
      && PackValidation.version(version) && ScriptCompletionReceipt.validDigest(digest)
      && !terminalEvents.isEmpty && terminalEvents.isSubset(of: ScriptCapabilities.events)
      && terminalEvents.isDisjoint(with: ["mission.abandoned"])
      && (!terminalEvents.contains("mission.accepted")
        || OriginalMutualContribution.acceptedPin(self))
  }
  func matches(_ receipt: ScriptCompletionReceipt) -> Bool {
    receipt.definition == definition && receipt.version == version && receipt.digest == digest
      && terminalEvents.contains(receipt.causeKind)
  }
}

/// Native value-scoped trust. Only exact translated runtime content is approved.
/// Test fixtures can supply an isolated catalog to internal transactions without changing this one.
struct ScriptClueTrustCatalog: Sendable {
  private let pins: [ScriptClueExecutionPin]
  static let production = ScriptClueTrustCatalog(approvedPins: [
    .init(
      sourceID: NativeFlightReception.stateID, definition: NativeFlightReception.stateID,
      version: NativeFlightReception.version, digest: NativeFlightReception.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: NativeMeasuredExtraction.stateID, definition: NativeMeasuredExtraction.stateID,
      version: "1.0.0", digest: NativeMeasuredExtraction.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: NativeOriginalEvacuation.stateID, definition: NativeOriginalEvacuation.stateID,
      version: "1.0.0", digest: NativeOriginalEvacuation.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: NativeOriginalRescueJourney.stateID,
      definition: NativeOriginalRescueJourney.stateID,
      version: "1.0.0", digest: NativeOriginalRescueJourney.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: WayfarerRecordRecovery.stateID, definition: WayfarerRecordRecovery.stateID,
      version: "1.0.0", digest: WayfarerRecordRecovery.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: NativeIdentifiedSalvage.stateID, definition: NativeIdentifiedSalvage.stateID,
      version: "1.0.0", digest: NativeIdentifiedSalvage.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: NativeOriginalSurvey.stateID,
      definition: NativeOriginalSurvey.stateID,
      version: "1.0.0", digest: NativeOriginalSurvey.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: NativeOrbitalOutlookJourney.stateID,
      definition: NativeOrbitalOutlookJourney.stateID,
      version: "1.0.0", digest: NativeOrbitalOutlookJourney.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: NativeStationPassengerJourney.stateID,
      definition: NativeStationPassengerJourney.stateID,
      version: "1.0.0", digest: NativeStationPassengerJourney.digest,
      terminalEvents: ["mission.receipted"]),
    .init(
      sourceID: OriginalConsentedFreightSupply.stateID,
      definition: OriginalConsentedFreightSupply.stateID,
      version: "1.0.0", digest: OriginalConsentedFreightSupply.digest,
      terminalEvents: ["dialogue.confirmed"]),
    .init(
      sourceID: WayfarerFieldRelief.stateID, definition: WayfarerFieldRelief.stateID,
      version: "1.0.0", digest: WayfarerFieldRelief.digest,
      terminalEvents: ["dialogue.confirmed"]),
    ScriptNavigationTradeContent.cluePin,
    OriginalMutualContribution.cluePin,
    .init(
      sourceID: OriginalCorridorDefence.stateID, definition: OriginalCorridorDefence.stateID,
      version: "1.0.0", digest: OriginalCorridorDefence.digest,
      terminalEvents: ["dialogue.confirmed"]),
    .init(
      sourceID: OriginalVerifiedWarrant.stateID, definition: OriginalVerifiedWarrant.stateID,
      version: "1.0.0", digest: OriginalVerifiedWarrant.digest,
      terminalEvents: ["dialogue.confirmed"]),
    .init(
      sourceID: "l337.contract/sealed-dispatch", definition: "l337.contract/sealed-dispatch",
      version: "1.0.0",
      digest: "93289d5daf873d0cf878b37fa55178e4ab91cf6fa1947f379a54c3bc04267ae7",
      terminalEvents: ["dialogue.confirmed"]),
    .init(
      sourceID: "l337.wayfarer-service/seed-transfer",
      definition: "l337.wayfarer-service/seed-transfer",
      version: "1.0.0", digest: "feadc6cc8bed2b59a608dc0667afd11a5d7c1e790e2466e3b8c44974f9f03d54",
      terminalEvents: ["dialogue.confirmed"]),
    .init(
      sourceID: "l337.wayfarer-service/repair-loop",
      definition: "l337.wayfarer-service/repair-loop",
      version: "1.0.0", digest: "c0b674ac2eca0221890412446f423c5f7ada4520b38669dbfbef5289049c199f",
      terminalEvents: ["dialogue.confirmed"]),
    .init(
      sourceID: "l337.wayfarer-service/cold-chain", definition: "l337.wayfarer-service/cold-chain",
      version: "1.0.0", digest: "28d0072262956e974bc2033f8b0e984e1b35780a98b6861a1a81b4ca43c7487f",
      terminalEvents: ["dialogue.confirmed"]),
    .init(
      sourceID: "l337.contract/bonded-freight", definition: "l337.contract/bonded-freight",
      version: "1.0.0",
      digest: "08dfba917d8f630b0fb39a4458ec1fa06245eb1347352a172a7576c0967682ca",
      terminalEvents: ["dialogue.confirmed"]),
  ])

  private init(approvedPins: [ScriptClueExecutionPin]) { pins = approvedPins }
  init(pins: [ScriptClueExecutionPin]) throws {
    let identities = pins.map { $0.definition + "@" + $0.version + ":" + $0.digest }
    guard pins.count <= 1024, pins.allSatisfy(\.valid), Set(identities).count == pins.count else {
      throw SaveError.invalidCommander
    }
    self.pins = pins
  }
  func pin(for receipt: ScriptCompletionReceipt) -> ScriptClueExecutionPin? {
    pins.first { $0.matches(receipt) }
  }
}
