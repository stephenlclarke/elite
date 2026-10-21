import Foundation
import Testing

@testable import EliteCore

struct AlienStorageValidatedStateTests {
  private let base = AlienAttachmentBase(
    energyCapacity: 512, energyRecharge: 4,
    frontShieldCapacity: 255, rearShieldCapacity: 200, frontShieldRecharge: 2, rearShieldRecharge: 3
  )

  @Test func onlyActualFittedPhysicalInstancesContributeAndUpgradeDoesNotAddAModule() throws {
    var fixture = AlienStorageTestFixture()
    let first = try fixture.acquire(kind: .energyCapacity)
    let second = try fixture.acquire(kind: .energyCapacity)
    let recharge = try fixture.acquire(kind: .energyRecharge)
    let stored = try fixture.acquire(kind: .shieldCapacity)
    let retired = try fixture.acquire(kind: .shieldRecharge)
    try fixture.fit(first)
    try fixture.fit(second)
    try fixture.fit(recharge)
    try fixture.fit(retired)
    try fixture.retire(retired)
    let upgrade = try fixture.acquire(kind: .energyCapacity, upgrade: true)
    try fixture.apply(upgrade, to: first)
    let state = try AlienStorageValidatedState(validating: fixture.snapshot)
    let effects = try resolve(state)
    let firstValue = try #require(state.snapshot.attachments.first { $0.id == first })
    let expectedBonus =
      firstValue.contributionBasisPoints + AlienModuleDefinition.baseBonusBasisPoints
    #expect(effects.summaries[.energyCapacity]?.count == 2)
    #expect(effects.summaries[.energyCapacity]?.bonusBasisPoints == expectedBonus)
    #expect(effects.energyModuleCount == 3)
    #expect(
      effects.effective.energyCapacity == base.energyCapacity * (1 + Double(expectedBonus) / 10000))
    #expect(effects.effective.energyRecharge == base.energyRecharge * 1.1)
    #expect(effects.effective.frontShieldCapacity == base.frontShieldCapacity)
    #expect(effects.effective.rearShieldRecharge == base.rearShieldRecharge)
    #expect(state.snapshot.attachments.contains { $0.id == stored && $0.disposition == .stored })
    #expect(try resolve(state) == effects)
    let unrelated = try AlienAttachmentEffects.resolve(
      validated: state, owner: state.owner,
      activeHull: UUID(), normalBase: base)
    #expect(unrelated.energyModuleCount == 0 && unrelated.effective == base)
    #expect(throws: (any Error).self) {
      try AlienAttachmentEffects.resolve(
        validated: state, owner: UUID(),
        activeHull: AlienStorageTestFixture.hull, normalBase: self.base)
    }
  }

  @Test func immutableWitnessRetainsFullSemanticEqualityAcrossOrderAndChanges() throws {
    var fixture = AlienStorageTestFixture()
    let energy = try fixture.acquire(kind: .energyCapacity)
    try fixture.fit(energy)
    let old = try AlienStorageValidatedState(validating: fixture.snapshot)
    let a = fixture.snapshot
    let reordered = AlienStorageSnapshot(
      owner: a.owner, revision: a.revision, worldRevision: a.worldRevision,
      world: a.world.reversed(), sources: a.sources.reversed(),
      attachments: a.attachments.reversed(),
      upgrades: a.upgrades.reversed(), receipts: a.receipts.reversed(),
      commands: a.commands.reversed())
    let same = try AlienStorageValidatedState(validating: reordered)
    #expect(old == same)
    let upgrade = try fixture.acquire(kind: .energyCapacity, upgrade: true)
    try fixture.apply(upgrade, to: energy)
    let changed = try AlienStorageValidatedState(validating: fixture.snapshot)
    #expect(old != changed && changed.revision > old.revision)
    #expect(try resolve(old).summaries[.energyCapacity]?.bonusBasisPoints == 1000)
    #expect(try resolve(changed).summaries[.energyCapacity]!.bonusBasisPoints > 1000)
    let malformed = AlienStorageSnapshot(
      owner: a.owner, revision: a.revision, worldRevision: a.worldRevision,
      world: [], sources: a.sources, attachments: a.attachments, upgrades: a.upgrades,
      receipts: a.receipts, commands: a.commands)
    #expect(throws: (any Error).self) { try AlienStorageValidatedState(validating: malformed) }
  }

  @Test func actualTransferRebuildsCurrentHullSummariesWithoutChangingOlderWitness() throws {
    var fixture = AlienStorageTestFixture()
    let energy = try fixture.acquire(kind: .energyCapacity)
    try fixture.fit(energy)
    let old = try AlienStorageValidatedState(validating: fixture.snapshot)
    let nextHull = AlienStorageTestFixture.uuid(9000)
    fixture.transfer(to: nextHull)
    let next = try AlienStorageValidatedState(validating: fixture.snapshot)
    #expect(try resolve(old).energyModuleCount == 1)
    #expect(try resolve(next).energyModuleCount == 0)
    let moved = try AlienAttachmentEffects.resolve(
      validated: next, owner: next.owner,
      activeHull: nextHull, normalBase: base)
    #expect(
      moved.energyModuleCount == 1 && moved.effective.energyCapacity == base.energyCapacity * 1.1)
  }

  @Test func checkedSendableWitnessSupportsConcurrentReadOnlyEffects() async throws {
    var fixture = AlienStorageTestFixture()
    let energy = try fixture.acquire(kind: .energyCapacity)
    try fixture.fit(energy)
    let state = try AlienStorageValidatedState(validating: fixture.snapshot)
    let base = self.base
    let values = try await withThrowingTaskGroup(of: AlienAttachmentEffects.self) { group in
      for _ in 0..<16 {
        group.addTask {
          try AlienAttachmentEffects.resolve(
            validated: state, owner: state.owner,
            activeHull: AlienStorageTestFixture.hull, normalBase: base)
        }
      }
      var results: [AlienAttachmentEffects] = []
      for try await result in group { results.append(result) }
      return results
    }
    #expect(values.count == 16 && values.allSatisfy { $0 == values.first })
    #expect(state.snapshot == fixture.snapshot)
  }

  private func resolve(_ state: AlienStorageValidatedState) throws -> AlienAttachmentEffects {
    try AlienAttachmentEffects.resolve(
      validated: state, owner: AlienStorageTestFixture.owner,
      activeHull: AlienStorageTestFixture.hull, normalBase: base)
  }
}
