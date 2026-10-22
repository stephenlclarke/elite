import Foundation

struct NativeInductionSeedIssue: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let parent: UUID
  let commanderOwner: UUID
  let operatorOwner: UUID
  let epoch: UUID
  let policy: NativeInductionCharterPolicy
  let consent: UUID
  let allocation: UUID
  let capacityRevision: UInt64
  let capacityFingerprint: String
  let family: String
  let familyVersion: String
  let familyDigest: String
  let profile: NativeInductionSeedProfile
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  static func identity(
    consent: UUID, allocation: UUID, revision: UInt64, fingerprint: String,
    dock: NativeMainStationDockReceipt, carrier: UUID, fit: UInt64,
    time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-original-seed-issue-v1:\(consent):\(allocation):\(revision):\(fingerprint):\(NativeInductionSeedPack.digest):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(parent state: NativeWayfarerInductionState) -> Bool {
    guard let choice = state.charterChoice, let capacity = state.charterCapacity,
      let signature = state.charterSignatures?.first(where: { $0.operatorID == .seed }),
      parent == choice.parent, commanderOwner == choice.owner,
      operatorOwner == NativeInductionCapacityOperator.seed.owner(epoch: choice.terms.epoch),
      epoch == choice.terms.epoch, policy == choice.policy, consent == signature.operation,
      allocation == capacity.allocation.operation, capacityRevision >= signature.capacityRevision,
      let snapshot = try? capacity.snapshot(at: capacityRevision),
      capacityFingerprint == (try? snapshot.fingerprint),
      snapshot.events.allSatisfy({ event in
        guard let clock = state.charterCapacityEventClock(event) else { return false }
        return clock.0 < sequence && clock.1 <= physicalTime && clock.2 <= flightSeconds
      }),
      family == NativeInductionSeedPack.stateID,
      familyVersion == NativeInductionSeedPack.version,
      familyDigest == NativeInductionSeedPack.digest, profile.valid,
      sequence > signature.sequence, sequence < UInt64(Int64.max),
      dock.valid, dock.commanderOwner == commanderOwner, dock.station == signature.dock.station,
      dock.station.system == NativeInductionCapacityOperator.seed.station,
      dock.sequence >= signature.dock.sequence, dock.actor.visit >= signature.dock.actor.visit,
      dock.calendarSeconds >= signature.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (signature.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (signature.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        consent: consent, allocation: allocation,
        revision: capacityRevision, fingerprint: capacityFingerprint, dock: dock, carrier: carrier,
        fit: inventoryRevision, time: physicalTime, flightSeconds: flightSeconds, sequence: sequence
      ))
  }
}

struct NativeInductionSeedAuditDelegation: Codable, Sendable, Equatable {
  let operation: UUID
  let issue: UUID
  let source: UUID
  let epoch: UUID
  let operatorOwner: UUID
  let auditor: NativeMainStationIdentity
  let units: [UUID]
  let scope: String
  static let readOnlyScope = "original-available-source-unit-quote-capacity-refusal-only"
  static func identity(issue: UUID, source: UUID, units: [UUID], auditor: NativeMainStationIdentity)
    throws -> UUID
  {
    ScriptIdentity.uuid(
      "induction-seed-avenor-read-only-delegation-v1:\(issue):\(source):\(try NativeFlightReception.hash(units)):\(try NativeFlightReception.hash(auditor)):\(readOnlyScope)"
    )
  }
}

/// Original operator stock. Its six source serials are independent of six capacity windows.
struct NativeInductionSeedSource: Codable, Sendable, Equatable {
  let identity: UUID
  let issue: NativeInductionSeedIssue
  let delegation: NativeInductionSeedAuditDelegation
  var units: [WayfarerColdChainStockUnit]
  var history: [NativeInductionSeedStockMutation]?
  var revision: UInt64 { UInt64(history?.count ?? 0) }
  static func identity(parent: UUID, epoch: UUID, owner: UUID) -> UUID {
    ScriptIdentity.uuid("induction-original-seed-batch-v1:\(parent):\(epoch):\(owner)")
  }
  init(issue: NativeInductionSeedIssue, parent: NativeWayfarerInductionState) throws {
    guard issue.valid(parent: parent), let choice = parent.charterChoice else {
      throw SaveError.invalidCommander
    }
    let sourceID = Self.identity(
      parent: issue.parent, epoch: issue.epoch, owner: issue.operatorOwner)
    identity = sourceID
    self.issue = issue
    units = (0..<issue.profile.stockUnits).map {
      WayfarerColdChainStockUnit(
        id: WayfarerColdChainStockSource.unitIdentity(source: sourceID, index: $0))
    }
    let operation = try NativeInductionSeedAuditDelegation.identity(
      issue: issue.operation,
      source: identity, units: units.map(\.id), auditor: choice.dock.station)
    delegation = .init(
      operation: operation, issue: issue.operation, source: identity,
      epoch: issue.epoch, operatorOwner: issue.operatorOwner, auditor: choice.dock.station,
      units: units.map(\.id), scope: NativeInductionSeedAuditDelegation.readOnlyScope)
    guard valid(parent: parent) else { throw SaveError.invalidCommander }
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard issue.valid(parent: parent), let choice = parent.charterChoice,
      identity
        == Self.identity(parent: issue.parent, epoch: issue.epoch, owner: issue.operatorOwner),
      units.count == issue.profile.stockUnits,
      units == (try? projectedUnits()),
      delegation.issue == issue.operation, delegation.source == identity,
      delegation.epoch == issue.epoch, delegation.operatorOwner == issue.operatorOwner,
      delegation.auditor == choice.dock.station, delegation.units == units.map(\.id),
      delegation.scope == NativeInductionSeedAuditDelegation.readOnlyScope
    else { return false }
    return delegation.operation
      == (try? NativeInductionSeedAuditDelegation.identity(
        issue: issue.operation, source: identity, units: units.map(\.id),
        auditor: delegation.auditor))
  }
}

extension NativeWayfarerInductionState {
  func issuingSeedBatch(_ source: NativeInductionSeedSource) throws -> Self {
    guard valid, charterSeedSource == nil, source.valid(parent: self) else {
      throw SaveError.invalidCommander
    }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception,
      charterChoice: charterChoice, charterCapacity: charterCapacity,
      charterSignatures: charterSignatures, charterClinicSource: charterClinicSource,
      charterWorkshopSource: charterWorkshopSource, charterSeedSource: source,
      charterAudit: charterAudit)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
