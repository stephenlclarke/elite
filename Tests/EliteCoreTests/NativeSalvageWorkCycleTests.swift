import Foundation
import Testing

@testable import EliteCore

struct NativeSalvageWorkCycleTests {
  @Test func oldSingleBudgetIssuanceCannotPayForASecondEightLotBatch() throws {
    let fixture = try AlienLegacyFixture.make(
      definition: nil, roles: [.militaryCapital], manifest: [.init(commodity: .food, quantity: 60)],
      batches: 0)
    let section = SalvageSectionProfile(
      index: 1, kind: .cargo, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
    var ledger = SalvageLedger(seed: fixture.seed)
    #expect(
      ledger.inspectLoot(
        wreck: fixture.plan.section.wreck, section: section, source: fixture.plan.source)
        == fixture.plan)
    guard
      case .released(let originalLots) = ledger.advance(
        wreck: fixture.plan.section.wreck, section: section, pose: .init(),
        velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
        elapsed: 1, operation: 1, conditions: NativePagedSalvageFixture.permitted,
        source: fixture.plan.source)
    else { throw SaveError.invalidCommander }
    let export = try ledger.exportNativeSection(fixture.plan.section)
    #expect(originalLots.count == 8 && !export.depleted && export.partialWork == nil)
    let id = UUID()
    let owner = UUID()
    let old = AlienStorageWorldPlan(
      id: id, owner: owner, seed: export.seed, plan: export.plan, inspectedAt: 0,
      requiredWorkSeconds: 1, workSeconds: 1, damagedTechnology: false,
      depleted: false, destroyed: false, lastOperation: 1, progress: export.progress)
    let adopted = NativeSalvageWorkCycle(
      id: UUID(), owner: owner, version: 1, inspection: .nativeSingleBudget(id),
      beganAt: 2, observedAt: 2, progress: export.progress, currentWorkSeconds: 0,
      damagedTechnology: false, releases: 0, lastRelease: nil, lastOperation: 1,
      depleted: false, destroyedAt: nil)
    // Storage-only physical source evidence; the Commander deterministic-site census
    // would still reject this fixture as a native actor or acquisition permission.
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: "SH043"))
    let current = try #require(profile.sections.first { $0.index == old.plan.section.section })
    let site = SalvageSite(
      identity: old.plan.section.wreck, catalogueShipID: profile.catalogueShipID,
      kind: .deepSpace, position: .init(0, 0, 0), orientation: .init(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), ownership: .abandoned)
    let wreck = NativeSalvageWreck(
      id: UUID(), owner: owner, identity: site.identity, catalogueShipID: site.catalogueShipID,
      seed: old.seed, source: .generated(site), bornAt: 0, observedAt: 2, binding: nil,
      motion: .init(
        pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), energy: 100),
      destroyedAt: nil)
    let view = try NativeSalvagePlanView([.nativeWreck(wreck), .plan(old), .nativeWork(adopted)])
    #expect(view.plans[id]?.workSeconds == current.workSeconds)
    #expect(view.works[id]?.currentWorkSeconds == 0 && view.works[id]?.releases == 0)
    let partial = SalvageSectionCycle.advance(
      plan: old.plan, progress: adopted.progress, destroyed: false,
      partialWork: adopted.currentWorkSeconds, damagedTechnology: false, section: current,
      pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0),
      tool: .cutter, elapsed: 0.25, availableEmissionSlots: nil)
    guard case .progress(let progress, let seconds) = partial else {
      throw SaveError.invalidCommander
    }
    #expect(seconds == 0.25 && progress.nextLot == 8)
    let completed = adopted.observing(
      at: 3, progress: progress, seconds: current.workSeconds, damaged: false, operation: 2)
    guard
      case .released(let next, let lots, let depleted) = SalvageSectionCycle.advance(
        plan: old.plan, progress: completed.progress, destroyed: false,
        partialWork: current.workSeconds,
        damagedTechnology: false, section: current, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0, availableEmissionSlots: nil)
    else { throw SaveError.invalidCommander }
    let released = try completed.releasing(
      at: 3, progress: next, operation: 2, requiredWorkSeconds: current.workSeconds,
      depleted: depleted)
    try released.preserve(adopted)
    #expect(
      released.currentWorkSeconds == 0 && released.releases == 1 && !released.damagedTechnology)
    #expect(lots.first?.identity.lot == 8 && !lots.isEmpty && lots.count <= 8)
    #expect(ledger.pendingLots == originalLots)
  }

  @Test func aWorkCycleCannotAdvanceIssuedSerialsWithoutAReleaseOrReuseACompletedBudget() throws {
    var (game, _) = try NativePagedSalvageFixture.game()
    #expect(game.fireSalvageCutter(delta: 0.1))
    let hot = try #require(game.nativeSalvageWork)
    let malformed = NativeSalvageWorkCycle(
      id: hot.cycle.id, owner: hot.cycle.owner, version: 1, inspection: hot.cycle.inspection,
      beganAt: hot.cycle.beganAt, observedAt: hot.cycle.observedAt,
      progress: .init(
        issued: hot.cycle.progress.issued, discarded: hot.cycle.progress.discarded,
        structuralUnits: hot.cycle.progress.structuralUnits,
        issuedStructural: hot.cycle.progress.issuedStructural,
        materialKind: hot.cycle.progress.materialKind, nextLot: hot.cycle.progress.nextLot + 1),
      currentWorkSeconds: hot.cycle.currentWorkSeconds, damagedTechnology: false,
      releases: 0, lastRelease: nil, lastOperation: hot.cycle.lastOperation,
      depleted: false, destroyedAt: nil)
    let original = try #require(game.commander.alienStorageState?.current.snapshot)
    let world = original.world.map {
      $0.id == malformed.id ? AlienStorageWorldRecord.nativeWork(malformed) : $0
    }
    #expect(throws: (any Error).self) { try original.replacingNativeWorld(world).validate() }
    #expect(game.commander.alienStorageState?.current.snapshot == original)
    #expect(throws: (any Error).self) {
      _ = try hot.cycle.releasing(
        at: hot.cycle.observedAt, progress: hot.cycle.progress, operation: 2,
        requiredWorkSeconds: hot.section.workSeconds, depleted: false)
    }
  }
}
