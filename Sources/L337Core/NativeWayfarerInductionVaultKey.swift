import Foundation

/// The one-tonne key stays seed-custodian property. It is not player equipment or a seed load.
struct NativeInductionVaultKeyLoan: Codable, Sendable, Equatable {
  let operation: UUID
  let consentOperation: UUID
  let serviceReturnOperation: UUID
  let unit: UUID
  let source: EquipmentIssueSource
  let status: EquipmentIssueStatus
  let loan: Bool
  let returnRemaining: Bool
  let receiver: SystemIdentity
  let receivingTarget: String
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  func valid(service: NativeInductionCassetteService, permission: NativeInductionPermission) -> Bool
  {
    guard serviceReturnOperation == service.returnOperation,
      unit == NativeWayfarerInduction.vaultKeyUnit(owner: permission.owner),
      source.valid, source.mission == permission.mission,
      source.resource == NativeWayfarerInduction.keyItem,
      source.packDigest == NativeWayfarerInduction.digest,
      status == .issued, loan, returnRemaining,
      receiver == NativeWayfarerInduction.seedReceiver,
      receivingTarget == NativeWayfarerInduction.seedReceivingTarget,
      dock.valid, dock.commanderOwner == permission.owner, dock.station.world == permission.owner,
      dock.station.system == NativeWayfarerInduction.seedSource,
      dock.sequence > service.dock.sequence, dock.actor.visit > service.dock.actor.visit,
      dock.calendarSeconds >= service.dock.calendarSeconds,
      physicalTime.isFinite, physicalTime >= service.physicalTime, physicalTime <= 1e12,
      flightSeconds.isFinite, flightSeconds >= service.flightSeconds, flightSeconds <= 1e12,
      consentOperation
        == (try? NativeWayfarerInduction.continuationOperation(
          target: NativeWayfarerInduction.seedConsentTarget, previous: service.returnOperation,
          dock: dock, carrier: carrier, revision: inventoryRevision, flightSeconds: flightSeconds))
    else { return false }
    return operation
      == NativeWayfarerInduction.vaultKeyLoanOperation(
        consent: consentOperation, unit: unit)
  }
}

extension NativeWayfarerInduction {
  static let keyItem = "seed-vault-key"
  static let keyPayload = "induction-seed-vault-key"
  static let seedConsentTarget = "enlirin-seed-consent"
  static let seedReceivingTarget = "lareria-seed-ark-received"
  static let seedSource = SystemIdentity(galaxy: 0, system: 162)
  static let seedReceiver = SystemIdentity(galaxy: 0, system: 91)
  static func vaultKeyUnit(owner: UUID) -> UUID {
    ScriptIdentity.uuid("induction-original-vault-key-v1:\(keyItem):\(owner):0:162:0")
  }
  static func vaultKeyLoanOperation(consent: UUID, unit: UUID) -> UUID {
    ScriptIdentity.uuid("induction-vault-key-loan-v1:\(consent):\(unit)")
  }
}

extension NativeWayfarerInductionState {
  func borrowingVaultKey(_ original: NativeInductionVaultKeyLoan, freeTonnes: Int) throws -> Self {
    guard valid, cassetteService != nil, seedKey == nil, freeTonnes >= 1 else {
      throw SaveError.invalidCommander
    }
    let next = Self(
      permission: permission, crate: crate, reception: reception, cassette: cassette,
      cassetteService: cassetteService, seedKey: original)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
  var seedKeyValid: Bool {
    if let seedKey {
      guard let cassetteService,
        seedKey.valid(service: cassetteService, permission: permission)
      else { return false }
      if let seedKeyLoss {
        guard seedKeyLoss.facts.valid, seedKeyLoss.physicalTime.isFinite,
          seedKeyLoss.physicalTime >= seedKey.physicalTime, seedKeyLoss.physicalTime <= 1e12,
          seedKeyLoss.facts.visit >= seedKey.dock.actor.visit,
          seedKeyLoss.facts.context.flightSeconds >= seedKey.flightSeconds
        else { return false }
      }
    } else if seedKeyLoss != nil {
      return false
    }
    return true
  }
}

extension Game {
  func inductionVaultKeyLoan(
    _ state: NativeWayfarerInductionState, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, physicalTime: Double, flightSeconds: Double
  ) throws -> NativeWayfarerInductionState {
    guard let service = state.cassetteService,
      nativeMainStationDockEvidenceIsCurrent, commander.nativeStations?.currentMainDock == dock,
      systemIdentity == NativeWayfarerInduction.seedSource, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision
    else { throw SaveError.invalidCommander }
    let consent = try NativeWayfarerInduction.continuationOperation(
      target: NativeWayfarerInduction.seedConsentTarget, previous: service.returnOperation,
      dock: dock, carrier: carrier, revision: revision, flightSeconds: flightSeconds)
    let unit = NativeWayfarerInduction.vaultKeyUnit(owner: state.permission.owner)
    let receipt = NativeInductionVaultKeyLoan(
      operation: NativeWayfarerInduction.vaultKeyLoanOperation(consent: consent, unit: unit),
      consentOperation: consent, serviceReturnOperation: service.returnOperation, unit: unit,
      source: .init(
        mission: state.permission.mission, resource: NativeWayfarerInduction.keyItem,
        packDigest: NativeWayfarerInduction.digest), status: .issued, loan: true,
      returnRemaining: true, receiver: NativeWayfarerInduction.seedReceiver,
      receivingTarget: NativeWayfarerInduction.seedReceivingTarget,
      dock: dock, carrier: carrier, inventoryRevision: revision,
      physicalTime: physicalTime, flightSeconds: flightSeconds)
    return try state.borrowingVaultKey(
      receipt, freeTonnes: commander.tradeCargoCapacity - commander.cargoTonnes)
  }
}
