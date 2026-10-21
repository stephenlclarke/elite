import Foundation

/// Cold validation of explicitly new cycles only. Old completed cycles and times stay
/// unknown. Replay is bounded by this one original UInt16 serial domain, never a frame.
enum NativeSalvageCycleProof {
  private struct Batch {
    let progress: AlienStorageWorldProgress
    let count: Int
    let depleted: Bool
  }

  static func validate(
    _ cycle: NativeSalvageWorkCycle, plan: SalvageLootPlan, section: SalvageSectionProfile,
    original: AlienStorageWorldProgress, baselineWork: Double, baselineDamage: Bool,
    baselineDepleted: Bool, baselineOperation: UInt64?
  ) throws {
    let emitted = cycle.progress.nextLot.subtractingReportingOverflow(original.nextLot)
    guard !emitted.overflow else { throw AlienStorageError.invalidJoin }
    let fullOrShort = UInt64(emitted.partialValue / 8 + (emitted.partialValue % 8 == 0 ? 0 : 1))
    let possibleEmptyFinal = fullOrShort.addingReportingOverflow(1)
    guard
      cycle.releases == fullOrShort
        || (!possibleEmptyFinal.overflow && cycle.releases == possibleEmptyFinal.partialValue
          && emitted.partialValue % 8 == 0 && cycle.depleted)
    else { throw AlienStorageError.invalidJoin }

    if cycle.releases == 0 {
      let untouchedBaseline =
        cycle.progress == original && cycle.currentWorkSeconds == baselineWork
        && cycle.damagedTechnology == baselineDamage
        && cycle.lastOperation == baselineOperation.flatMap { $0 > 0 ? $0 : nil }
      if untouchedBaseline {
        guard cycle.depleted == (baselineDepleted || cycle.destroyedAt != nil) else {
          throw AlienStorageError.invalidJoin
        }
        return
      }
      guard !baselineDepleted, cycle.currentWorkSeconds >= baselineWork,
        !baselineDamage || cycle.damagedTechnology,
        cycle.lastOperation.map { $0 > (baselineOperation ?? 0) } == true,
        try finish(cycle, from: original, releasedDepleted: false, plan: plan, section: section)
      else { throw AlienStorageError.invalidJoin }
      return
    }

    let minimumOperation = (baselineOperation ?? 0).addingReportingOverflow(cycle.releases)
    guard !baselineDepleted, let release = cycle.lastRelease, !minimumOperation.overflow,
      release.operation >= minimumOperation.partialValue
    else { throw AlienStorageError.invalidJoin }
    var progress = original
    for ordinal in 0..<cycle.releases {
      let normal = try batch(
        progress, damage: ordinal == 0 && baselineDamage, plan: plan, section: section)
      let final = ordinal + 1 == cycle.releases
      if final {
        var options = [normal]
        if !(ordinal == 0 && baselineDamage) {
          options.append(try batch(progress, damage: true, plan: plan, section: section))
        }
        for option in options {
          if isPrefix(option.progress, of: cycle.progress),
            try finish(
              cycle, from: option.progress, releasedDepleted: option.depleted, plan: plan,
              section: section)
          {
            return
          }
        }
        throw AlienStorageError.invalidJoin
      }
      // Delay damage until an ordinary batch would issue a finally discarded technology.
      // This preserves a genuine final zero-lot budget after earlier complete eight-lot batches.
      let forbidden = normal.progress.issued.indices.contains { index in
        cycle.progress.discarded[index] && !normal.progress.discarded[index]
          && normal.progress.issued[index] > progress.issued[index]
      }
      let next =
        forbidden ? try batch(progress, damage: true, plan: plan, section: section) : normal
      guard next.count == 8, !next.depleted, isPrefix(next.progress, of: cycle.progress) else {
        throw AlienStorageError.invalidJoin
      }
      progress = next.progress
    }
    throw AlienStorageError.invalidJoin
  }

  static func preserve(
    _ old: NativeSalvageWorkCycle, in current: NativeSalvageWorkCycle,
    plan: SalvageLootPlan, section: SalvageSectionProfile
  ) throws {
    if current.releases == old.releases {
      if current.progress == old.progress && current.currentWorkSeconds == old.currentWorkSeconds
        && current.damagedTechnology == old.damagedTechnology
      {
        return
      }
      guard !old.depleted,
        current.lastOperation.map { $0 > (old.lastOperation ?? 0) } == true,
        try finish(
          current, from: old.progress, releasedDepleted: false, plan: plan, section: section)
      else { throw AlienStorageError.historyChanged }
      return
    }
    let serials = current.progress.nextLot.subtractingReportingOverflow(old.progress.nextLot)
    guard !old.depleted, !serials.overflow, serials.partialValue <= 8 else {
      throw AlienStorageError.historyChanged
    }
    let discarded = current.progress.discarded != old.progress.discarded
    let expected = try batch(
      old.progress, damage: old.damagedTechnology || discarded, plan: plan, section: section)
    guard current.progress == expected.progress,
      current.depleted == (expected.depleted || current.destroyedAt != nil)
    else { throw AlienStorageError.historyChanged }
  }

  private static func batch(
    _ progress: AlienStorageWorldProgress, damage: Bool,
    plan: SalvageLootPlan, section: SalvageSectionProfile
  ) throws -> Batch {
    guard
      case .released(let next, let lots, let depleted) = SalvageSectionCycle.advance(
        plan: plan, progress: progress, destroyed: false, partialWork: section.workSeconds,
        damagedTechnology: damage, section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0, availableEmissionSlots: nil),
      lots.count <= 8
    else { throw AlienStorageError.invalidJoin }
    return .init(progress: next, count: lots.count, depleted: depleted)
  }

  private static func finish(
    _ cycle: NativeSalvageWorkCycle, from released: AlienStorageWorldProgress,
    releasedDepleted: Bool, plan: SalvageLootPlan, section: SalvageSectionProfile
  ) throws -> Bool {
    guard cycle.depleted == (releasedDepleted || cycle.destroyedAt != nil) else { return false }
    if releasedDepleted {
      return cycle.currentWorkSeconds == 0 && !cycle.damagedTechnology && cycle.progress == released
    }
    if cycle.currentWorkSeconds == 0 && !cycle.damagedTechnology {
      return cycle.progress == released
    }
    if cycle.releases > 0 {
      guard let operation = cycle.lastOperation, let release = cycle.lastRelease,
        operation > release.operation
      else { return false }
    }
    guard
      case .progress(let next, _) = SalvageSectionCycle.advance(
        plan: plan, progress: released, destroyed: false, partialWork: 0,
        damagedTechnology: cycle.damagedTechnology, section: section, pose: .init(),
        velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
        elapsed: 0, availableEmissionSlots: nil)
    else { throw AlienStorageError.invalidJoin }
    return next == cycle.progress
  }

  private static func isPrefix(
    _ prior: AlienStorageWorldProgress, of final: AlienStorageWorldProgress
  ) -> Bool {
    do {
      try final.preserve(prior)
      return true
    } catch { return false }
  }
}
