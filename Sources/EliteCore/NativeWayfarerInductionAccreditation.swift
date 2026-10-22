import Foundation

/// The single Senn transaction is also the continuing service entitlement.
struct NativeInductionAccreditation: Codable, Sendable, Equatable {
  static let rewardNative = 76000
  let operation: UUID
  let sequence: UInt64
  let publicationRevision: UInt64
  let certification: UUID
  let policy: NativeInductionCharterPolicy
  let entitlement: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let creditsBefore: Int
  let creditsAfter: Int

  static func entitlement(parent: UUID, owner: UUID, certification: UUID) -> UUID {
    ScriptIdentity.uuid(
      "induction-owning-service-accreditation-v1:\(parent):\(owner):\(certification)")
  }
  static func identity(
    sequence: UInt64, revision: UInt64, certification: UUID, policy: NativeInductionCharterPolicy,
    entitlement: UUID, dock: NativeMainStationDockReceipt, carrier: UUID, fit: UInt64, time: Double,
    clock: Double, before: Int, after: Int
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-senn-terminal-v1:\(sequence):\(revision):\(certification):\(policy.rawValue):\(entitlement):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(time.bitPattern):\(clock.bitPattern):\(before):\(after)"
    )
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard let certificate = parent.networkCertification, certification == certificate.operation,
      policy == parent.charterChoice?.policy,
      entitlement
        == Self.entitlement(
          parent: parent.permission.mission, owner: parent.permission.owner,
          certification: certification),
      sequence > certificate.sequence, sequence < UInt64(Int64.max),
      publicationRevision > 0, publicationRevision < UInt64(Int64.max),
      dock.valid, dock.station == certificate.dock.station,
      dock.commanderOwner == parent.permission.owner,
      dock.sequence >= certificate.dock.sequence, dock.actor.visit >= certificate.dock.actor.visit,
      dock.calendarSeconds >= certificate.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (certificate.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (certificate.flightSeconds...1e12).contains(flightSeconds),
      (0...(4_294_967_295 - Self.rewardNative)).contains(creditsBefore),
      creditsAfter == creditsBefore + Self.rewardNative
    else { return false }
    return operation
      == (try? Self.identity(
        sequence: sequence, revision: publicationRevision, certification: certification,
        policy: policy, entitlement: entitlement, dock: dock, carrier: carrier,
        fit: inventoryRevision, time: physicalTime, clock: flightSeconds, before: creditsBefore,
        after: creditsAfter))
  }
}

extension ScriptInstance {
  /// Completed induction keeps its original operators' continuing obligations alive.
  func hasInductionServiceAuthority(in engine: borrowing ScriptEngineState) -> Bool {
    guard definition == NativeWayfarerInduction.stateID, version == NativeWayfarerInduction.version,
      digest == NativeWayfarerInduction.digest, let parent = savedWayfarerInduction, parent.valid
    else { return false }
    if outcome == .active { return parent.accreditation == nil }
    guard outcome == .complete, parent.accreditation != nil, let receipt = completionReceipt else {
      return false
    }
    return receipt.valid(for: self, engine: engine)
  }
}

extension NativeWayfarerInductionState {
  func accrediting(_ receipt: NativeInductionAccreditation) throws -> NativeWayfarerInductionState {
    guard valid, accreditation == nil, receipt.valid(parent: self) else {
      throw SaveError.invalidCommander
    }
    let next = auditCopy(
      capacity: charterCapacity, clinic: charterClinicSource, workshop: charterWorkshopSource,
      seed: charterSeedSource, audit: charterAudit, certification: networkCertification,
      accreditation: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
