import Foundation

/// One current cycle links to the original inspection instead of rewriting its history.
struct NativeSalvageWorkCycle: Codable, Sendable, Equatable {
  enum Inspection: Codable, Sendable, Equatable {
    case fresh(UUID)
    case nativeSingleBudget(UUID)
    case legacy(UUID)

    var id: UUID {
      switch self {
      case .fresh(let id), .nativeSingleBudget(let id), .legacy(let id): id
      }
    }
  }

  struct Release: Codable, Sendable, Equatable {
    let operation: UInt64
    let at: Double
    let creditedWorkSeconds: Double
  }

  let id: UUID
  let owner: UUID
  let version: Int
  let inspection: Inspection
  let beganAt: Double
  let observedAt: Double
  let progress: AlienStorageWorldProgress
  let currentWorkSeconds: Double
  let damagedTechnology: Bool
  /// Counts only actual releases since this cycle record was created.
  /// An old issued cursor never manufactures historical completed cycles.
  let releases: UInt64
  let lastRelease: Release?
  let lastOperation: UInt64?
  let depleted: Bool
  let destroyedAt: Double?

  func validate(
    seed: UInt64, plan: SalvageLootPlan, requiredWorkSeconds: Double,
    originalProgress: AlienStorageWorldProgress, section: SalvageSectionProfile,
    baselineWork: Double, baselineDamage: Bool, baselineDepleted: Bool, baselineOperation: UInt64?
  ) throws {
    guard version == 1, beganAt.isFinite, beganAt >= 0,
      observedAt.isFinite, observedAt >= beganAt,
      requiredWorkSeconds.isFinite, requiredWorkSeconds > 0,
      currentWorkSeconds.isFinite, currentWorkSeconds >= 0,
      currentWorkSeconds <= requiredWorkSeconds,
      lastOperation.map({ $0 > 0 }) ?? (releases == 0),
      destroyedAt.map({ $0.isFinite && $0 >= beganAt && $0 <= observedAt && depleted }) ?? true
    else { throw AlienStorageError.invalidJoin }
    try SalvageSectionEmissionView(seed: seed, plan: plan, progress: progress).validate()
    try progress.preserve(originalProgress)
    let emitted = progress.nextLot.subtractingReportingOverflow(originalProgress.nextLot)
    let capacity = releases.multipliedReportingOverflow(by: 8)
    guard !emitted.overflow, !capacity.overflow,
      UInt64(emitted.partialValue) <= capacity.partialValue,
      !depleted || destroyedAt != nil
        || (progress.issuedStructural == progress.structuralUnits
          && zip(progress.issued, plan.items).allSatisfy { $0 == SalvageLotEmission.quantity($1) }),
      section.workSeconds == requiredWorkSeconds
    else { throw AlienStorageError.invalidJoin }
    if let lastRelease {
      guard releases > 0, lastRelease.operation > 0,
        lastOperation.map({ lastRelease.operation <= $0 }) == true,
        lastRelease.at.isFinite, lastRelease.at >= beganAt, lastRelease.at <= observedAt,
        lastRelease.creditedWorkSeconds == requiredWorkSeconds
      else { throw AlienStorageError.invalidJoin }
    } else if releases != 0 {
      throw AlienStorageError.invalidJoin
    }
    try NativeSalvageCycleProof.validate(
      self, plan: plan, section: section, original: originalProgress,
      baselineWork: baselineWork, baselineDamage: baselineDamage,
      baselineDepleted: baselineDepleted, baselineOperation: baselineOperation)
  }

  func preserve(_ old: Self, plan: SalvageLootPlan, section: SalvageSectionProfile) throws {
    guard id == old.id, owner == old.owner, version == old.version,
      inspection == old.inspection, beganAt == old.beganAt, observedAt >= old.observedAt,
      releases >= old.releases, !old.depleted || depleted,
      old.lastOperation.map({ previous in lastOperation.map { $0 >= previous } == true }) ?? true
    else { throw AlienStorageError.historyChanged }
    try progress.preserve(old.progress)
    if old.destroyedAt != nil {
      guard self == old else { throw AlienStorageError.historyChanged }
      return
    }
    if old.depleted {
      guard progress == old.progress, currentWorkSeconds == old.currentWorkSeconds,
        damagedTechnology == old.damagedTechnology, releases == old.releases,
        lastRelease == old.lastRelease, lastOperation == old.lastOperation
      else { throw AlienStorageError.historyChanged }
    }
    if releases == old.releases {
      guard progress.nextLot == old.progress.nextLot,
        progress.issuedStructural == old.progress.issuedStructural,
        currentWorkSeconds >= old.currentWorkSeconds,
        !old.damagedTechnology || damagedTechnology, lastRelease == old.lastRelease
      else { throw AlienStorageError.historyChanged }
      for index in progress.issued.indices where !progress.discarded[index] {
        guard progress.issued[index] == old.progress.issued[index] else {
          throw AlienStorageError.historyChanged
        }
      }
    } else {
      let next = old.releases.addingReportingOverflow(1)
      guard !next.overflow, releases == next.partialValue,
        currentWorkSeconds == 0, !damagedTechnology,
        let release = lastRelease, release.at >= old.observedAt,
        old.lastOperation.map({ release.operation > $0 }) ?? true
      else { throw AlienStorageError.historyChanged }
    }
    try NativeSalvageCycleProof.preserve(old, in: self, plan: plan, section: section)
  }
}
