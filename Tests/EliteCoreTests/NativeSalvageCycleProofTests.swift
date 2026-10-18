import Foundation
import Testing

@testable import EliteCore

struct NativeSalvageCycleProofTests {
  private let section = SalvageSectionProfile(
    index: 1, kind: .cargo, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1),
    radius: 10, workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)

  @Test func exactOriginalBatchesRequireEightThenEightThenTheActualShortFinalBudget() throws {
    let fixture = try AlienLegacyFixture.make(
      definition: nil, roles: [.militaryCapital], manifest: [.init(commodity: .food, quantity: 90)],
      batches: 0)
    let baseline = try fixture.ledger.exportNativeSection(fixture.plan.section)
    var ledger = fixture.ledger
    var cycle = initial(baseline)
    var counts: [Int] = []
    for operation in UInt64(1)...3 {
      let before = cycle
      let actual = ledger.advance(
        wreck: fixture.plan.section.wreck, section: section, pose: .init(),
        velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: operation,
        conditions: NativePagedSalvageFixture.permitted, source: fixture.plan.source)
      guard case .released(let lots) = actual else { throw SaveError.invalidCommander }
      let exported = try ledger.exportNativeSection(fixture.plan.section)
      let ready = cycle.observing(
        at: Double(operation), progress: cycle.progress,
        seconds: 1, damaged: false, operation: operation)
      cycle = try ready.releasing(
        at: Double(operation), progress: exported.progress,
        operation: operation, requiredWorkSeconds: 1, depleted: exported.depleted)
      try validate(cycle, baseline: baseline)
      try cycle.preserve(before, plan: baseline.plan, section: section)
      counts.append(lots.count)
      #expect(cycle.currentWorkSeconds == 0 && cycle.releases == operation)
    }
    #expect(counts[0] == 8 && counts[1] == 8 && counts[2] > 0 && counts[2] < 8)
    #expect(cycle.depleted)
    let replay = cycle.observing(
      at: 4, progress: cycle.progress, seconds: 1, damaged: false, operation: 4)
    #expect(throws: (any Error).self) {
      try replay.preserve(cycle, plan: baseline.plan, section: section)
    }
  }

  @Test(arguments: ["phantom", "inflated", "sixteen"])
  func malformedPostAdoptionCycleCountsAndOneReleaseOverEightAreRejected(change: String) throws {
    let fixture = try AlienLegacyFixture.make(
      definition: nil, roles: [.militaryCapital],
      manifest: [.init(commodity: .food, quantity: 120)], batches: 0)
    let baseline = try fixture.ledger.exportNativeSection(fixture.plan.section)
    var ledger = fixture.ledger
    var prefixes: [AlienStorageWorldProgress] = []
    for operation in UInt64(1)...3 {
      guard
        case .released = ledger.advance(
          wreck: baseline.section.wreck, section: section, pose: .init(), velocity: .init(0, 0, 0),
          angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: operation,
          conditions: NativePagedSalvageFixture.permitted, source: baseline.plan.source)
      else { throw SaveError.invalidCommander }
      prefixes.append(try ledger.exportNativeSection(baseline.section).progress)
    }
    let first = try initial(baseline).observing(
      at: 1, progress: baseline.progress,
      seconds: 1, damaged: false, operation: 1
    ).releasing(
      at: 1, progress: prefixes[0],
      operation: 1, requiredWorkSeconds: 1, depleted: false)
    try validate(first, baseline: baseline)
    let progress = change == "sixteen" ? prefixes[2] : prefixes[0]
    let malformed = NativeSalvageWorkCycle(
      id: first.id, owner: first.owner, version: 1, inspection: first.inspection,
      beganAt: 0, observedAt: 2, progress: progress, currentWorkSeconds: 0,
      damagedTechnology: false, releases: change == "inflated" ? 99 : 2,
      lastRelease: .init(operation: 100, at: 2, creditedWorkSeconds: 1), lastOperation: 100,
      depleted: false, destroyedAt: nil)
    #expect(throws: (any Error).self) { try validate(malformed, baseline: baseline) }
    #expect(throws: (any Error).self) {
      try malformed.preserve(first, plan: baseline.plan, section: section)
    }
  }

  @Test func unchangedUnknownMaterialAndOldPartialAreAllowedOnlyAsTheExactAdoptedBaseline() throws {
    let fixture = try AlienLegacyFixture.make(batches: 0)
    let original = try fixture.ledger.exportNativeSection(fixture.plan.section)
    let raw = initial(original, seconds: 0.25, damage: true)
    try raw.validate(
      seed: original.seed, plan: original.plan, requiredWorkSeconds: 1,
      originalProgress: original.progress, section: section, baselineWork: 0.25,
      baselineDamage: true, baselineDepleted: false, baselineOperation: nil)
    #expect(raw.progress.materialKind == nil)
    let fabricated = raw.observing(
      at: 1, progress: original.progress, seconds: 0.5, damaged: true, operation: 4)
    #expect(throws: (any Error).self) {
      try fabricated.validate(
        seed: original.seed, plan: original.plan, requiredWorkSeconds: 1,
        originalProgress: original.progress, section: section, baselineWork: 0.25,
        baselineDamage: true, baselineDepleted: false, baselineOperation: nil)
    }
    guard
      case .progress(let observed, _) = SalvageSectionCycle.advance(
        plan: original.plan, progress: original.progress, destroyed: false, partialWork: 0,
        damagedTechnology: true, section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0, availableEmissionSlots: nil)
    else { throw SaveError.invalidCommander }
    let actual = raw.observing(at: 1, progress: observed, seconds: 0.5, damaged: true, operation: 4)
    try actual.validate(
      seed: original.seed, plan: original.plan, requiredWorkSeconds: 1,
      originalProgress: original.progress, section: section, baselineWork: 0.25,
      baselineDamage: true, baselineDepleted: false, baselineOperation: nil)
    #expect(actual.progress.materialKind == .alloys && actual.progress.discarded.contains(true))
    #expect(original.progress.materialKind == nil)
  }

  @Test func originalEmptyRequiresExactlyOneFullTerminalBudget() throws {
    let emptySection = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: false, technologyDefinitionIDs: [], sourceFaceIndex: 0
    )
    let identity = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 30, lineage: 9)
    let source = SalvageLootSource(
      roles: [], legalValue: 0, economy: 3, technology: 10, ownership: .abandoned)
    var ledger = SalvageLedger(seed: 9)
    let observedInspection = ledger.inspectLoot(
      wreck: identity, section: emptySection, source: source)
    let plan = try #require(observedInspection)
    let baseline = try ledger.exportNativeSection(plan.section)
    #expect(plan.emptyReason == .unsupportedSource && plan.items.isEmpty)
    let observedWorkResult = ledger.advance(
      wreck: identity, section: emptySection, pose: .init(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
      elapsed: 1, operation: 1, conditions: NativePagedSalvageFixture.permitted, source: source)
    #expect(
      observedWorkResult
        == .destroyed)
    let terminal = try ledger.exportNativeSection(plan.section)
    let complete = try initial(baseline).observing(
      at: 1, progress: baseline.progress, seconds: 1,
      damaged: false, operation: 1
    ).releasing(
      at: 1, progress: terminal.progress,
      operation: 1, requiredWorkSeconds: 1, depleted: true)
    try complete.validate(
      seed: baseline.seed, plan: plan, requiredWorkSeconds: 1,
      originalProgress: baseline.progress, section: emptySection, baselineWork: 0,
      baselineDamage: false, baselineDepleted: false, baselineOperation: nil)
    #expect(
      complete.releases == 1 && complete.progress.nextLot == 0 && complete.currentWorkSeconds == 0)
  }

  @Test func genuineFinalZeroLotBudgetAfterEightAndADeathWithoutReleaseRemainDistinct() throws {
    let fixture = try AlienLegacyFixture.make(
      definition: "computer-core", roles: [.militaryCapital],
      manifest: [.init(commodity: .food, quantity: 40)], batches: 0)
    let cargo = SalvageSectionProfile(
      index: 1, kind: .cargo, localPosition: .init(0, 0, 0),
      normal: .init(0, 0, 1), radius: 10, workSeconds: 1, structural: false,
      technologyDefinitionIDs: [], sourceFaceIndex: 0)
    var ledger = SalvageLedger(seed: fixture.seed)
    _ = ledger.inspectLoot(
      wreck: fixture.plan.section.wreck, section: cargo, source: fixture.plan.source)
    let baseline = try ledger.exportNativeSection(fixture.plan.section)
    guard
      case .released(let firstLots) = ledger.advance(
        wreck: baseline.section.wreck, section: cargo,
        pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
        elapsed: 1, operation: 1, conditions: NativePagedSalvageFixture.permitted,
        source: baseline.plan.source)
    else { throw SaveError.invalidCommander }
    #expect(firstLots.count == 8)
    let firstProgress = try ledger.exportNativeSection(baseline.section).progress
    let first = try initial(baseline).observing(
      at: 1, progress: baseline.progress, seconds: 1,
      damaged: false, operation: 1
    ).releasing(
      at: 1, progress: firstProgress,
      operation: 1, requiredWorkSeconds: 1, depleted: false)
    let observedWorkResult2 = ledger.advance(
      wreck: baseline.section.wreck, section: cargo, pose: .init(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .miningLaser,
      elapsed: 0.25, operation: 2, conditions: NativePagedSalvageFixture.permitted,
      source: baseline.plan.source)
    #expect(
      observedWorkResult2 == .progress(seconds: 0.25, required: 1))
    let damagedProgress = try ledger.exportNativeSection(baseline.section).progress
    let partial = first.observing(
      at: 2, progress: damagedProgress, seconds: 0.25, damaged: true, operation: 2)
    try partial.validate(
      seed: baseline.seed, plan: baseline.plan, requiredWorkSeconds: 1,
      originalProgress: baseline.progress, section: cargo, baselineWork: 0,
      baselineDamage: false, baselineDepleted: false, baselineOperation: nil)
    let death = NativeSalvageWorkCycle(
      id: partial.id, owner: partial.owner, version: 1,
      inspection: partial.inspection, beganAt: partial.beganAt, observedAt: 2,
      progress: partial.progress,
      currentWorkSeconds: partial.currentWorkSeconds, damagedTechnology: partial.damagedTechnology,
      releases: 1, lastRelease: partial.lastRelease, lastOperation: 2, depleted: true,
      destroyedAt: 2)
    try death.validate(
      seed: baseline.seed, plan: baseline.plan, requiredWorkSeconds: 1,
      originalProgress: baseline.progress, section: cargo, baselineWork: 0,
      baselineDamage: false, baselineDepleted: false, baselineOperation: nil)
    try death.preserve(partial, plan: baseline.plan, section: cargo)
    #expect(death.releases == 1 && death.progress.nextLot == 8)
    let observedWorkResult3 = ledger.advance(
      wreck: baseline.section.wreck, section: cargo, pose: .init(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
      elapsed: 0.75, operation: 3, conditions: NativePagedSalvageFixture.permitted,
      source: baseline.plan.source)
    #expect(
      observedWorkResult3 == .destroyed)
    let zeroFinal = try partial.observing(
      at: 3, progress: partial.progress, seconds: 1,
      damaged: true, operation: 3
    ).releasing(
      at: 3,
      progress: ledger.exportNativeSection(baseline.section).progress,
      operation: 3, requiredWorkSeconds: 1, depleted: true)
    try zeroFinal.validate(
      seed: baseline.seed, plan: baseline.plan, requiredWorkSeconds: 1,
      originalProgress: baseline.progress, section: cargo, baselineWork: 0,
      baselineDamage: false, baselineDepleted: false, baselineOperation: nil)
    try zeroFinal.preserve(partial, plan: baseline.plan, section: cargo)
    #expect(
      zeroFinal.releases == 2 && zeroFinal.progress.nextLot == 8
        && zeroFinal.currentWorkSeconds == 0)
  }

  private func initial(
    _ baseline: SalvageNativeSectionExport, seconds: Double = 0, damage: Bool = false,
    operation: UInt64? = nil
  ) -> NativeSalvageWorkCycle {
    .init(
      id: UUID(), owner: UUID(), version: 1, inspection: .legacy(UUID()), beganAt: 0,
      observedAt: 0, progress: baseline.progress, currentWorkSeconds: seconds,
      damagedTechnology: damage, releases: 0, lastRelease: nil, lastOperation: operation,
      depleted: false, destroyedAt: nil)
  }

  private func validate(_ cycle: NativeSalvageWorkCycle, baseline: SalvageNativeSectionExport)
    throws
  {
    try cycle.validate(
      seed: baseline.seed, plan: baseline.plan, requiredWorkSeconds: 1,
      originalProgress: baseline.progress, section: section, baselineWork: 0,
      baselineDamage: false, baselineDepleted: false, baselineOperation: nil)
  }
}
