import Foundation

struct WayfarerFieldReliefDefinition: Codable, Sendable, Equatable {
  let sourceSystem: Int
  let targetSystem: Int
  let tonnes: Int
  let maximumActive: Int
  let hazardTier: Int
  let baseReward: Int
  let perLegReward: Int
  var valid: Bool {
    sourceSystem == 7 && targetSystem == 237 && tonnes == 4 && maximumActive == 3
      && hazardTier == 0 && baseReward == 6100 && perLegReward == 1100
  }
}

/// The native ledger owns property. This immutable leaf binds one actual mission to its chain.
final class WayfarerFieldReliefCustody: Codable, Sendable, Equatable {
  let owner: UUID
  let job: NativeUtilityConsignment
  let acceptanceSequence: UInt64
  let accepted: ScriptEventContext
  let terminalReason: String?
  init(
    owner: UUID, job: NativeUtilityConsignment, acceptanceSequence: UInt64,
    accepted: ScriptEventContext, terminalReason: String? = nil
  ) {
    self.owner = owner
    self.job = job
    self.acceptanceSequence = acceptanceSequence
    self.accepted = accepted
    self.terminalReason = terminalReason
  }
  private enum CodingKeys: String, CodingKey {
    case owner, job, acceptanceSequence, accepted, terminalReason
  }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(
      decoder, ["owner", "job", "acceptanceSequence", "accepted"], optional: ["terminalReason"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    owner = try c.decode(UUID.self, forKey: .owner)
    job = try c.decode(NativeUtilityConsignment.self, forKey: .job)
    acceptanceSequence = try c.decode(UInt64.self, forKey: .acceptanceSequence)
    accepted = try c.decode(ScriptEventContext.self, forKey: .accepted)
    terminalReason = c.contains(.terminalReason)
      ? try c.decode(String.self, forKey: .terminalReason) : nil
    guard job.originalUnits.count == 4, Set(job.originalUnits).count == 4,
      (2...256).contains(job.route.count), accepted.valid, accepted.nativeMainDock != nil,
      accepted.revision == 0, acceptanceSequence > 0, acceptanceSequence < UInt64(Int64.max),
      terminalReason.map({
        ["received", "returned", "escape", "shipDestroyed", "targetDestroyed"].contains($0)
      }) ?? true
    else { throw SaveError.invalidCommander }
  }

  func replacing(_ job: NativeUtilityConsignment, reason: String? = nil)
    -> WayfarerFieldReliefCustody
  {
    .init(
      owner: owner, job: job, acceptanceSequence: acceptanceSequence, accepted: accepted,
      terminalReason: reason)
  }
  static func == (a: WayfarerFieldReliefCustody, b: WayfarerFieldReliefCustody) -> Bool {
    a.owner == b.owner && a.job == b.job && a.acceptanceSequence == b.acceptanceSequence
      && a.accepted == b.accepted && a.terminalReason == b.terminalReason
  }
}

enum WayfarerFieldRelief {
  static let stateID = "l337.wayfarer-service/field-relief"
  static let boardID = "field-relief"
  static let capability = "native-field-relief-v1"
  // Generated from the frozen production manifest and entry bytes, not descriptive source IDs.
  static let digest = "59a1b1caf304c747f0e983a422b13f25e01801f6834ce26ca71bb1621b5d408b"
  static func instance(_ consignment: UUID) -> UUID {
    Game.contractJobIdentity(offer(consignment))
  }
  static func offer(_ consignment: UUID) -> UUID {
    ScriptIdentity.uuid("field-relief-offer-v1:\(consignment)")
  }
  static var source: ContractStationIdentity {
    .init(galaxy: 0, system: 7, stationClass: "main-orbital")
  }
  static var boardKey: String { digest + "/" + boardID + "/" + source.key }
  static func marked(_ state: borrowing ScriptInstance) -> Bool {
    state.definition == stateID || state.digest == digest || state.savedFieldRelief != nil
  }
  static func matches(_ pack: ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == "1.0.0"
      && pack.digest == digest && pack.manifest.fieldRelief?.valid == true
  }
}

extension Game {
  var fieldReliefPack: ScriptPack? { scriptPacks.first(where: WayfarerFieldRelief.matches) }
  var fieldReliefPageFacts: [String] {
    var facts = [
      fieldReliefPack?.digest ?? "field-relief-content-unavailable",
      String(OriginalServiceReservationPolicy.activeCount(commander.scriptState)),
      commander.equipmentOwnerID?.uuidString ?? "unowned",
      commander.hullInstanceID?.uuidString ?? "no-carrier",
      String(commander.equipmentInventory?.revision ?? 0), nativeStationRuntimeEpoch.uuidString,
    ]
    if let source = commander.nativeStations?.currentMainDock {
      facts += [String(source.sequence), String(source.actor.visit)]
    }
    if let target = commander.nativeStations?.ledger.currentDock {
      facts += [
        String(target.sequence), String(target.lifecycleRevision),
        String(target.dockingBinding.actor.visit), String(target.dockingBinding.actor.entity),
        String(target.dockingBinding.bodyID),
      ]
    }
    if let utility = commander.nativeUtility {
      facts.append(String(utility.revision))
      for job in utility.consignments {
        let mission = commander.scriptState.instances[WayfarerFieldRelief.instance(job.id)]
        facts += [
          job.id.uuidString, job.phase.rawValue, String(job.rewardTenths),
          job.installation?.operation.uuidString ?? "uninstalled",
          job.reception?.operation.uuidString ?? "unreceived",
          mission?.outcome.rawValue ?? "unbound", String(mission?.revision ?? 0),
        ]
      }
    }
    return facts
  }
}
