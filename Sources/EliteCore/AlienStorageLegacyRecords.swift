import Foundation

/// Immutable import evidence. Missing old work and times remain missing.
/// These values do not authorize a native import or a custody transaction.
struct AlienStorageLegacySection: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let importOperation: UUID
  let importedAt: Double
  let ledgerRevision: UInt64
  let seed: UInt64
  let plan: SalvageLootPlan
  let progress: AlienStorageWorldProgress
  let savedPartialWorkSeconds: Double?
  let savedDamagedTechnology: Bool
  let sectionDepleted: Bool
  let sectionDestroyed: Bool
  let wreckDestroyed: Bool
  /// This cursor belongs to the entire original ledger, not a dated section event.
  let savedLedgerLastOperation: UInt64?
}

/// One permanent claim per actual original emitted identity, including unknown outcomes.
/// Later physical updates and consumption belong to linked current records, not this evidence.
struct AlienStorageLegacyLot: Codable, Sendable, Equatable {
  enum State: Codable, Sendable, Equatable {
    case pending(lot: SalvageLot, offer: SpawnIdentity?, binding: ActorIdentity?)
    case storedReserved(lot: SalvageLot, migrationOperation: UUID, source: UUID)
    case retainedOrdinaryStored(lot: SalvageLot)
    case legacySettled(settlement: UUID, item: UUID)
    case legacyUnavailable
  }
  let id: UUID
  let owner: UUID
  let section: UUID
  let origin: AlienStorageEmissionOrigin
  let identity: SalvageLotIdentity
  let state: State
}

/// Transient projection from G1's sealed original ledger export, never encoded authority.
/// Pending/stored entries are section-local; proposals retain their complete original item set.
struct AlienStorageLegacyCustodyEvidence: Sendable, Equatable {
  let pending: [SalvageLot]
  let stored: [SalvageLot]
  let offers: [SpawnIdentity: SalvageLotIdentity]
  let bindings: [SalvageLotIdentity: ActorIdentity]
  let settlements: [SalvageSettlementProposal]
}

/// Pure join view of an actual explicit stored-property migration, not a scoop receipt.
/// G1 must join this to the real command, source and property in the whole candidate.
struct AlienStorageLegacyStoredMigration: Sendable, Equatable {
  enum Kind: Sendable, Equatable {
    case attachment(AlienModuleKind)
    case upgrade(AlienModuleKind)
  }
  let operation: UUID
  let owner: UUID
  let section: UUID
  let identity: SalvageLotIdentity
  let lot: SalvageLot
  let source: UUID
  let property: UUID
  let kind: Kind
}
