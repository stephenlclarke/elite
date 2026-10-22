import Foundation

struct NativeInductionCharterSignature: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let choice: UUID
  let allocation: UUID
  let epoch: UUID
  let policy: NativeInductionCharterPolicy
  let parent: UUID
  let commanderOwner: UUID
  let operatorID: NativeInductionCapacityOperator
  let operatorOwner: UUID
  let target: String
  let units: String
  let capacityRevision: UInt64
  let capacityFingerprint: String
  let protectedMinimum: Int
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  static func target(
    _ operatorID: NativeInductionCapacityOperator, policy: NativeInductionCharterPolicy
  ) -> String {
    operatorID.rawValue + (policy == .pooledWindows ? "-pooled-signature" : "-reserved-signature")
  }
  static func identity(
    choice: UUID, allocation: UUID, operatorID: NativeInductionCapacityOperator,
    revision: UInt64, fingerprint: String, dock: NativeMainStationDockReceipt, carrier: UUID,
    fit: UInt64, time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-actual-operator-charter-consent-v1:\(choice):\(allocation):\(operatorID.rawValue):\(revision):\(fingerprint):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(choice: NativeInductionCharterChoice, capacity: NativeInductionCapacityState) -> Bool {
    let source = capacity.allocation
    guard self.choice == choice.operation, allocation == source.operation, epoch == source.epoch,
      policy == source.policy, parent == choice.parent, commanderOwner == choice.owner,
      operatorOwner == operatorID.owner(epoch: epoch),
      target == Self.target(operatorID, policy: policy),
      protectedMinimum == choice.terms.protectedMinimum,
      units
        == (try? NativeFlightReception.hash(capacity.units.filter { $0.operatorID == operatorID })),
      let snapshot = try? capacity.snapshot(at: capacityRevision),
      capacityFingerprint == (try? snapshot.fingerprint),
      snapshot.events.allSatisfy({ event in
        guard case .released(let release) = event else { return true }
        return release.sequence < sequence && release.physicalTime <= physicalTime
          && release.flightSeconds <= flightSeconds
      }),
      sequence > source.sequence, sequence < UInt64(Int64.max),
      dock.valid, dock.commanderOwner == commanderOwner, dock.station.world == commanderOwner,
      dock.station.system == operatorID.station,
      dock.sequence > source.dock.sequence, dock.actor.visit > source.dock.actor.visit,
      dock.calendarSeconds >= source.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (source.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (source.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        choice: self.choice, allocation: allocation,
        operatorID: operatorID, revision: capacityRevision, fingerprint: capacityFingerprint,
        dock: dock, carrier: carrier, fit: inventoryRevision, time: physicalTime,
        flightSeconds: flightSeconds, sequence: sequence))
  }
}

extension NativeInductionCapacityState {
  func snapshot(at revision: UInt64) throws -> Self {
    guard revision <= self.revision else { throw SaveError.invalidCommander }
    return Self(allocation: allocation, events: Array(events.prefix(Int(revision))))
  }
}

extension NativeWayfarerInductionState {
  func recordingCharterConsent(_ signature: NativeInductionCharterSignature) throws -> Self {
    guard valid, let charterChoice, let charterCapacity,
      signature.valid(choice: charterChoice, capacity: charterCapacity),
      !(charterSignatures ?? []).contains(where: { $0.operatorID == signature.operatorID })
    else { throw SaveError.invalidCommander }
    var signatures = charterSignatures ?? []
    signatures.append(signature)
    signatures.sort { $0.operatorID.rawValue < $1.operatorID.rawValue }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception,
      charterChoice: charterChoice,
      charterCapacity: charterCapacity, charterSignatures: signatures,
      charterClinicSource: charterClinicSource, charterWorkshopSource: charterWorkshopSource,
      charterSeedSource: charterSeedSource, charterAudit: charterAudit)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
  func releasingCharterUnit(_ receipt: NativeInductionCapacityRelease) throws -> Self {
    guard valid, let charterCapacity,
      let consent = charterSignatures?.first(where: { $0.operatorID == receipt.operatorID }),
      receipt.consent == consent.operation, receipt.sequence > consent.sequence,
      receipt.dock.sequence >= consent.dock.sequence, receipt.physicalTime >= consent.physicalTime,
      receipt.flightSeconds >= consent.flightSeconds
    else { throw SaveError.invalidCommander }
    let capacity = try charterCapacity.releasing(receipt)
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception,
      charterChoice: charterChoice,
      charterCapacity: capacity, charterSignatures: charterSignatures,
      charterClinicSource: charterClinicSource, charterWorkshopSource: charterWorkshopSource,
      charterSeedSource: charterSeedSource, charterAudit: charterAudit)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
