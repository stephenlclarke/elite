import Foundation
import Testing

@testable import L337Core

struct SalvageSectionCycleTests {
  private var profile: SalvageSectionProfile {
    .init(
      index: 1, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)
  }

  @Test func actualProducerRequiresANewFullBudgetAfterEachEightLotBatch() throws {
    var fixture = try AlienLegacyFixture.make(
      definition: nil, roles: [.militaryCapital], manifest: [.init(commodity: .food, quantity: 60)])
    let original = fixture.ledger.pendingLots
    #expect(original.count == 8)
    #expect(fixture.ledger.progress(fixture.plan.section) == 0)
    #expect(!fixture.ledger.isDepleted(fixture.plan.section))
    let partial = advance(&fixture.ledger, plan: fixture.plan, elapsed: 0.25, operation: 1)
    #expect(partial == .progress(seconds: 0.25, required: 1))
    #expect(fixture.ledger.pendingLots == original)
    let completed = advance(&fixture.ledger, plan: fixture.plan, elapsed: 0.75, operation: 2)
    guard case .released(let second) = completed else {
      Issue.record("Second batch must require and consume its own complete work budget")
      return
    }
    #expect(!second.isEmpty && second.count <= 8)
    #expect(second.first?.identity.lot == 8)
    #expect(fixture.ledger.progress(fixture.plan.section) == 0)
    #expect(fixture.ledger.isDepleted(fixture.plan.section))
    let food = fixture.ledger.pendingLots.compactMap { lot -> Int? in
      if case .commodity(let amount) = lot.content, amount.commodity == .food {
        return amount.quantity
      }
      return nil
    }
    #expect(food == Array(repeating: 5, count: 12))
    #expect(
      Set(fixture.ledger.pendingLots.map(\.identity)).count == fixture.ledger.pendingLots.count)
  }

  @Test func batchAdmissionRefusalDoesNotLoseProgressOrAdvanceTheOriginalCursor() throws {
    let fixture = try AlienLegacyFixture.make(
      definition: nil, roles: [.militaryCapital], manifest: [.init(commodity: .food, quantity: 60)],
      batches: 0)
    let progress = try fixture.section().progress
    let blocked = SalvageSectionCycle.advance(
      plan: fixture.plan, progress: progress, destroyed: false, partialWork: 0.75,
      damagedTechnology: false, section: profile, pose: ShipPose(), velocity: .init(0, 0, 0),
      angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0.25, availableEmissionSlots: 7)
    #expect(blocked == .capacityRefused)
    let accepted = SalvageSectionCycle.advance(
      plan: fixture.plan, progress: progress, destroyed: false, partialWork: 0.75,
      damagedTechnology: false, section: profile, pose: ShipPose(), velocity: .init(0, 0, 0),
      angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0.25, availableEmissionSlots: nil)
    guard case .released(let next, let lots, let depleted) = accepted else {
      Issue.record("Uncapped native history still uses the original bounded release batch")
      return
    }
    #expect(lots.count == 8 && next.nextLot == 8 && !depleted)
    #expect(lots.first?.identity.lot == 0 && lots.last?.identity.lot == 7)
    #expect(progress.nextLot == 0)
  }

  @Test func actualMiningDamageCannotReappearAsTechnologyOnLaterCutterWork() throws {
    var fixture = try AlienLegacyFixture.make(elapsed: 0.25, tool: .miningLaser)
    let partial = try fixture.ledger.exportNativeSection(fixture.plan.section)
    #expect(partial.progress.discarded.contains(true) && partial.partialWork == 0.25)
    let result = advance(&fixture.ledger, plan: fixture.plan, elapsed: 0.75, operation: 1)
    guard case .released(let lots) = result else {
      Issue.record("Structural material remains recoverable after technology damage")
      return
    }
    #expect(lots.count == 1)
    #expect(
      lots.allSatisfy {
        if case .commodity(let amount) = $0.content { return amount.commodity == .minerals }
        return false
      })
    let completed = try fixture.ledger.exportNativeSection(fixture.plan.section)
    #expect(completed.progress.discarded == partial.progress.discarded)
    #expect(completed.partialWork == nil && completed.progress.nextLot == 1)
  }

  private func advance(
    _ ledger: inout SalvageLedger, plan: SalvageLootPlan, elapsed: Double, operation: UInt64
  ) -> SalvageWorkResult {
    ledger.advance(
      wreck: plan.section.wreck, section: profile, pose: ShipPose(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
      elapsed: elapsed, operation: operation,
      conditions: .init(
        toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
        resourcesAvailable: true, ownershipAuthorized: true), source: plan.source)
  }
}
