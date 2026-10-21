import Foundation
import Testing

@testable import EliteCore

struct SalvageNativeExportTests {
  @Test func nativeExportRetainsOriginalSeedAndMissingHistory() throws {
    let fixture = try AlienLegacyFixture.make()
    let export = try fixture.ledger.exportNativeSection(fixture.plan.section)
    let previous = try fixture.section()
    #expect(export.matches(fixture.ledger))
    #expect(export.seed == fixture.seed && export.plan == fixture.plan)
    #expect(export.progress == previous.progress)
    #expect(export.partialWork == nil && export.lastOperation == 0)
    let evidence = try fixture.evidence
    #expect(export.evidence == evidence)
    #expect(export.depleted == previous.sectionDepleted)
  }

  @Test func poseChangeWithoutRevisionInvalidatesWholeLedgerSeal() throws {
    var fixture = try AlienLegacyFixture.make()
    let export = try fixture.ledger.exportNativeSection(fixture.plan.section)
    let lot = try #require(fixture.ledger.pendingLots.first)
    let revision = fixture.ledger.revision
    fixture.ledger.updateLot(lot.identity, position: .init(20, 30, 40), velocity: .init(1, 2, 3))
    #expect(fixture.ledger.revision == revision)
    #expect(!export.matches(fixture.ledger))
    let before = fixture.ledger
    #expect(throws: AlienStorageError.historyChanged) {
      try fixture.ledger.transferNativeSection(export)
    }
    #expect(fixture.ledger == before)
    let current = try fixture.ledger.exportNativeSection(fixture.plan.section)
    let updated = fixture.ledger.updateWreck(
      identity: fixture.plan.section.wreck,
      motion: .init(pose: ShipPose(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0)))
    #expect(updated && fixture.ledger.revision == revision)
    #expect(!current.matches(fixture.ledger))
  }

  @Test func transferRetainsAuditAndOrdinaryStorageAndCannotReplay() throws {
    var reserved = try AlienLegacyFixture.make()
    let module = try #require(
      reserved.ledger.pendingLots.first {
        if case .technology(let id, _, _) = $0.content {
          return AlienModuleDefinition.isAttachmentDefinition(id)
        }
        return false
      })
    try reserved.collect(module)
    let export = try reserved.ledger.exportNativeSection(reserved.plan.section)
    let original = try reserved.saved()
    try reserved.ledger.transferNativeSection(export)
    #expect(reserved.ledger.pendingLots.isEmpty && reserved.ledger.inventory.isEmpty)
    #expect(reserved.ledger.isNativeTransferred(reserved.plan.section))
    let transferred = try reserved.saved()
    #expect(Set(transferred.plans.keys) == Set(original.plans.keys))
    for (identity, previous) in original.plans {
      let current = try #require(transferred.plans[identity])
      #expect(current.plan == previous.plan && current.progress == previous.progress)
      #expect(current.destroyed == previous.destroyed)
    }
    #expect(try reserved.saved().settlements == original.settlements)
    let after = reserved.ledger
    #expect(throws: AlienStorageError.historyChanged) {
      try reserved.ledger.transferNativeSection(export)
    }
    #expect(reserved.ledger == after)
    let restored = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(after))
    #expect(restored == after && restored.isNativeTransferred(reserved.plan.section))
    #expect(throws: AlienStorageError.invalidJoin) {
      try restored.exportNativeSection(reserved.plan.section)
    }
    let ordinaryID = "feature-salvage-cutter"
    var ordinary = try AlienLegacyFixture.make(definition: ordinaryID, roles: [.militaryCapital])
    let ordinaryLot = try #require(
      ordinary.ledger.pendingLots.first {
        if case .technology(let id, _, _) = $0.content { return id == ordinaryID }
        return false
      })
    try ordinary.collect(ordinaryLot)
    let ordinaryExport = try ordinary.ledger.exportNativeSection(ordinary.plan.section)
    try ordinary.ledger.transferNativeSection(ordinaryExport)
    #expect(ordinary.ledger.inventory == [ordinaryLot])
  }

  @Test func uninspectedSectionsCannotInventTypedOriginalLoot() throws {
    let fixture = try AlienLegacyFixture.make(batches: 0)
    let empty = SalvageLedger(seed: fixture.seed)
    #expect(throws: AlienStorageError.invalidJoin) {
      try empty.exportNativeSection(fixture.plan.section)
    }
    let unavailable = try AlienLegacyFixture.make(definition: nil, roles: [.asteroid], batches: 0)
    let export = try unavailable.ledger.exportNativeSection(unavailable.plan.section)
    #expect(export.plan.items.isEmpty && export.progress.nextLot == 0)
    #expect(export.evidence.pending.isEmpty && export.partialWork == nil)
  }
}
