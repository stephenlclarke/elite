import Foundation

/// The actual original receiving/work records, not the later operator consignments.
struct NativeInductionNetworkProofs: Codable, Sendable, Equatable {
  let clinic: UUID
  let cassetteReturn: UUID
  let seedReception: UUID
  let keyReturn: UUID
  let rescue: UUID
  let utility: UUID
  let charter: UUID
  init(parent: NativeWayfarerInductionState) throws {
    guard let clinic = parent.reception, clinic.remaining > 0, parent.loss == nil,
      let cassette = parent.cassetteService, parent.cassetteLoss == nil,
      let seed = parent.seedReception, parent.seedKeyLoss == nil,
      seed.seeds.count == 40, seed.crew.count == 6,
      let rescue = parent.rescueReception, parent.crewLogLoss == nil, rescue.crew.count == 2,
      let utility = parent.utilityReception, utility.repairs.count == 3,
      let charter = parent.charterAudit
    else { throw SaveError.invalidCommander }
    self.clinic = clinic.operation
    cassetteReturn = cassette.returnOperation
    seedReception = seed.operation
    keyReturn = seed.loanOperation
    self.rescue = rescue.operation
    self.utility = utility.operation
    self.charter = charter.operation
  }
}

struct NativeInductionNetworkCertification: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let proofs: NativeInductionNetworkProofs
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  static func identity(
    sequence: UInt64, proofs: NativeInductionNetworkProofs, dock: NativeMainStationDockReceipt,
    carrier: UUID, fit: UInt64, time: Double, clock: Double
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-veil-original-network-certification-v1:\(sequence):\(try NativeFlightReception.hash(proofs)):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(time.bitPattern):\(clock.bitPattern)"
    )
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard let audit = parent.charterAudit,
      proofs == (try? NativeInductionNetworkProofs(parent: parent)),
      sequence > audit.sequence, sequence < UInt64(Int64.max),
      dock.valid, dock.commanderOwner == parent.permission.owner,
      dock.station == audit.candidate.dock.station,
      dock.sequence >= audit.candidate.dock.sequence,
      dock.actor.visit >= audit.candidate.dock.actor.visit,
      dock.calendarSeconds >= audit.candidate.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (audit.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (audit.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        sequence: sequence, proofs: proofs, dock: dock, carrier: carrier, fit: inventoryRevision,
        time: physicalTime, clock: flightSeconds))
  }
}

extension NativeWayfarerInductionState {
  func certifyingNetwork(_ receipt: NativeInductionNetworkCertification) throws
    -> NativeWayfarerInductionState
  {
    guard valid, networkCertification == nil, receipt.valid(parent: self) else {
      throw SaveError.invalidCommander
    }
    let next = auditCopy(
      capacity: charterCapacity, clinic: charterClinicSource, workshop: charterWorkshopSource,
      seed: charterSeedSource, audit: charterAudit, certification: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}

enum NativeInductionNetworkCertificationSave {
  static func claimsValid(
    _ receipt: NativeInductionNetworkCertification, mission: ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard receipt.sequence <= commander.scriptState.nextEvent,
      mission.hasAcknowledged(receipt.sequence),
      receipt.physicalTime <= commander.flightSimulation.physicalTime,
      receipt.flightSeconds <= commander.scriptState.flightSeconds,
      receipt.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      receipt.dock.actor.visit <= commander.flightSimulation.visit,
      receipt.dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
      commander.nativeStations?.mainStations.contains(receipt.dock.station) == true
    else { return false }
    return true
  }
}
