import Foundation

/// Closed Original G13 content. The existing native pledge receipt remains the authority.
enum OriginalMutualContribution {
  static let stateID = "l337.contract/mutual-contribution"
  static let profile = "original-mutual-contribution"
  static let provider = "l337.contract"
  static let recipient = "Cedamar Orbital Relief Reserve"
  static let amount = 5000
  static let station = ContractStationIdentity(galaxy: 0, system: 85, stationClass: "main-orbital")
  static let definition = ScriptPledgeDefinition(
    profile: profile, provider: provider, title: recipient,
    creditAmounts: [amount], foodTonnes: [])
  // Exact executable content; native CLI verification is required before qualification.
  static let digest = "d4691b29ad9bc6f2fae1fa07345a96b38068857d427eb1977d7ced498ff698bf"

  static func matches(_ declaration: ScriptPledgeDefinition) -> Bool {
    declaration == definition
  }

  static func validManifest(_ manifest: ScriptManifest) -> Bool {
    manifest.stateID == stateID && manifest.pledge == definition
      && manifest.board?.id == "mutual-relief" && manifest.board?.clock == .local
      && manifest.board?.period == 3600
  }

  static func acceptedPin(_ pin: ScriptClueExecutionPin) -> Bool {
    pin.sourceID == stateID && pin.definition == stateID && pin.version == "1.0.0"
      && pin.digest == digest && pin.terminalEvents == ["mission.accepted"]
  }

  static var cluePin: ScriptClueExecutionPin {
    .init(
      sourceID: stateID, definition: stateID, version: "1.0.0", digest: digest,
      terminalEvents: ["mission.accepted"])
  }

  /// No recursion into receipt validity: these are the extra closed G13 recipient facts.
  static func receiptTermsMatch(_ receipt: ScriptPledgeReceipt) -> Bool {
    guard receipt.declaration.profile == profile else { return true }
    guard receipt.declaration == definition, receipt.difficulty == 1,
      receipt.variant == .credits, receipt.amount == amount, receipt.unit == "decicredits",
      receipt.origin == station, receipt.donatedAt == station, receipt.creditedAt == station,
      let source = receipt.cause.nativeMainDock, let committed = receipt.committed.nativeMainDock,
      source.valid, source == committed,
      source.station.system == SystemIdentity(galaxy: 0, system: 85),
      source.station.key == "main-orbital:0:85"
    else { return false }
    return true
  }

  /// Used at both award and retained-journal validation; acceptance alone is never success.
  static func validCompletion(
    _ completion: ScriptCompletionReceipt, engine: ScriptEngineState, owner: UUID
  )
    -> Bool
  {
    guard completion.definition == stateID, completion.version == "1.0.0",
      completion.digest == digest, completion.causeKind == "mission.accepted",
      completion.outcome == .complete, completion.settlementAmount == 0,
      let state = engine.instances[completion.instance], state.completionReceipt == completion,
      let receipt = engine.pledgeLedger?.receipt(instance: completion.instance),
      receipt.declaration == definition, receipt.digest == digest,
      receipt.cause.nativeMainDock?.commanderOwner == owner,
      receipt.committed.nativeMainDock?.commanderOwner == owner,
      receipt.before.cash >= amount, receipt.after.cash == receipt.before.cash - amount,
      receiptTermsMatch(receipt), receipt.valid(engine: engine)
    else { return false }
    return true
  }
}
