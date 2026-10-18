import Foundation
import Testing

@testable import EliteCore

struct NativeSalvageAuthorityTests {
  @Test(arguments: ["owner", "hull", "epoch", "actor", "section", "source", "cycle"])
  func staleHotAuthorityRefusesWorkAndEveryColdFlushWithoutChangingCustody(change: String) throws {
    var (game, _) = try NativePagedSalvageFixture.game()
    let observedCutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    let original = try #require(game.nativeSalvageWork)
    let body = try #require(game.bodies.first { $0.physical?.identity == original.actor })
    let source = original.plan.source
    var cycle = original.cycle
    if change == "owner" {
      cycle = .init(
        id: cycle.id, owner: UUID(), version: cycle.version, inspection: cycle.inspection,
        beganAt: cycle.beganAt, observedAt: cycle.observedAt, progress: cycle.progress,
        currentWorkSeconds: cycle.currentWorkSeconds, damagedTechnology: cycle.damagedTechnology,
        releases: cycle.releases, lastRelease: cycle.lastRelease,
        lastOperation: cycle.lastOperation,
        depleted: cycle.depleted, destroyedAt: cycle.destroyedAt)
    }
    var section = original.section
    if change == "section" {
      section = .init(
        index: section.index, kind: section.kind, localPosition: section.localPosition,
        normal: section.normal, radius: section.radius, workSeconds: section.workSeconds + 1,
        structural: section.structural, technologyDefinitionIDs: section.technologyDefinitionIDs,
        sourceFaceIndex: section.sourceFaceIndex)
    }
    let stale = NativeSalvageHotWork(
      section: section, seed: original.seed, plan: original.plan,
      actor: change == "actor"
        ? .init(
          system: original.actor.system, visit: original.actor.visit,
          entity: original.actor.entity + 1)
        : original.actor,
      hull: change == "hull" ? UUID() : original.hull,
      epoch: change == "epoch" ? UUID() : original.epoch,
      wreckRecord: change == "source" ? UUID() : original.wreckRecord,
      wreckSource: original.wreckSource, catalogueShipID: original.catalogueShipID,
      originalCycle: change == "cycle"
        ? original.originalCycle.observing(
          at: original.cycle.observedAt,
          progress: original.originalCycle.progress, seconds: 0.01, damaged: false, operation: 999)
        : original.originalCycle,
      cycle: cycle)
    game.nativeSalvageWork = stale
    #expect(!game.nativeSalvageHotWorkIsCurrent(stale))
    let commander = game.commander
    let energy = game.energy
    let heat = game.laserHeat
    let observedWorkBegin = game.beginNativeSalvageWork(
      body: body, section: original.section, source: source)
    #expect(!observedWorkBegin)
    let observedWorkFlush = game.flushNativeSalvageWork()
    #expect(!observedWorkFlush)
    let observedWreck = game.observeNativeSalvageWreck(body)
    #expect(observedWreck)
    let observedWreckFlush = game.flushNativeSalvageWrecks()
    #expect(!observedWreckFlush)
    #expect(game.commander == commander && game.energy == energy && game.laserHeat == heat)
    #expect(game.nativeSalvageWork?.cycle == stale.cycle)
    game.nativeSalvageWork = original
    let observedWorkFlush2 = game.flushNativeSalvageWork()
    #expect(observedWorkFlush2)
  }

  @Test func freshFactorySealsTheWholeOriginalLedgerAndNeverClampsExcessOldPartial() throws {
    let (game, site) = try NativePagedSalvageFixture.game()
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    let section = try #require(profile.sections.first)
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
      technology: game.currentSystem.technology, ownership: .abandoned)
    let original = game.commander.salvageLedger
    let facts = try #require(
      original.freshNativeInspection(
        wreck: site.identity, section: section, source: source))
    #expect(facts.matches(original))
    var changed = original
    let observedWreckUpdate = changed.updateWreck(
      identity: site.identity,
      motion: .init(
        pose: .init(position: .init(1, 0, 0)), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), energy: 100))
    #expect(
      observedWreckUpdate)
    #expect(!facts.matches(changed))
    let shorter = SalvageSectionProfile(
      index: section.index, kind: section.kind, localPosition: section.localPosition,
      normal: section.normal, radius: section.radius, workSeconds: 0.1,
      structural: section.structural, technologyDefinitionIDs: section.technologyDefinitionIDs,
      sourceFaceIndex: section.sourceFaceIndex)
    var partial = original
    let observedWorkResult = partial.advance(
      wreck: site.identity, section: section, pose: .init(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
      elapsed: 0.25, operation: 1, conditions: NativePagedSalvageFixture.permitted)
    #expect(
      observedWorkResult
        == .progress(seconds: 0.25, required: section.workSeconds))
    let before = partial
    #expect(
      partial.freshNativeInspection(wreck: site.identity, section: shorter, source: source) == nil)
    #expect(
      partial == before
        && partial.progress(.init(wreck: site.identity, section: section.index)) == 0.25)
  }
}
