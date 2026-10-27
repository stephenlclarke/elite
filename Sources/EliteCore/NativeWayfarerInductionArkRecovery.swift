import Foundation

/// A real custodian source transaction consumes the single reserve after a measured hull loss.
struct NativeArkRecoveryReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let reserveIssue: UUID
  let retired: NativeInductionArkLink
  let replacement: NativeInductionArkLink
  let priorLoss: NativeArkHullLoss
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  static func identity(
    reserve: NativeInductionArkReserve, retired: NativeInductionArkLink,
    loss: NativeArkHullLoss, dock: NativeMainStationDockReceipt, carrier: UUID,
    revision: UInt64, physicalTime: Double
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "native-ark-reserve-launch-v1:\(reserve.issue):\(retired.operation):\(try NativeFlightReception.hash(loss)):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(physicalTime.bitPattern)"
    )
  }

  func valid(
    reserve: NativeInductionArkReserve, key: NativeInductionVaultKeyLoan,
    permission: NativeInductionPermission
  ) -> Bool {
    guard reserve.valid(permission: permission), reserveIssue == reserve.issue,
      sequence > 0, sequence < UInt64(Int64.max), retired.valid, replacement.valid,
      retired.loanOperation == key.operation, replacement.loanOperation == key.operation,
      retired.registeredArk
        == NativeInductionArkSource.actorIdentity(mission: permission.mission, loan: key.operation),
      replacement.registeredArk
        == NativeInductionArkSource.actorIdentity(
          mission: permission.mission, loan: key.operation, issue: .reserve),
      retired.job != replacement.job, priorLoss.actor.visit > 0,
      priorLoss.actor.visit < UInt64(Int64.max), priorLoss.actor.entity > 1,
      priorLoss.actor.entity < UInt64(Int64.max),
      (0..<8).contains(priorLoss.actor.system.galaxy),
      (0..<256).contains(priorLoss.actor.system.system),
      priorLoss.observedPhysicalTime.isFinite,
      priorLoss.observedPhysicalTime >= permission.physicalTime,
      dock.valid, dock.commanderOwner == permission.owner,
      dock.station.world == permission.owner,
      dock.station.system == NativeWayfarerInduction.seedSource,
      dock.sequence >= key.dock.sequence, dock.actor.visit >= priorLoss.actor.visit,
      dock.calendarSeconds >= key.dock.calendarSeconds, inventoryRevision < UInt64(Int64.max),
      physicalTime.isFinite, physicalTime >= priorLoss.observedPhysicalTime, physicalTime <= 1e12,
      flightSeconds.isFinite, flightSeconds >= key.flightSeconds, flightSeconds <= 1e12,
      reserve.legacyRebriefDock == nil || reserve.legacyRebriefDock == dock
    else { return false }
    return operation
      == (try? Self.identity(
        reserve: reserve, retired: retired,
        loss: priorLoss, dock: dock, carrier: carrier, revision: inventoryRevision,
        physicalTime: physicalTime))
  }
}

extension NativeWayfarerInductionState {
  func replacingDestroyedArk(
    _ receipt: NativeArkRecoveryReceipt,
    reserve: NativeInductionArkReserve
  ) throws -> NativeWayfarerInductionState {
    guard valid, seedReception == nil, seedKeyLoss == nil, let key = seedKey,
      ark == receipt.retired, receipt.valid(reserve: reserve, key: key, permission: permission)
    else { throw SaveError.invalidCommander }
    let next = NativeWayfarerInductionState(
      permission: permission, crate: crate, loss: loss,
      reception: reception, cassette: cassette, cassetteLoss: cassetteLoss,
      cassetteService: cassetteService, seedKey: seedKey, seedKeyLoss: seedKeyLoss,
      ark: receipt.replacement)
    guard next.valid, next.payloads == payloads, next.milestones == milestones else {
      throw SaveError.invalidCommander
    }
    return next
  }
}
