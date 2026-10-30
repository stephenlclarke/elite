import Foundation
import Testing

@testable import L337Core

struct AlienStorageHistoryTests {
  @Test func deletedPermanentClaimsAndAlteredReceiptsAreRejected() throws {
    var fixture = AlienStorageTestFixture()
    let kind = AlienModuleKind.allCases[0]
    let physical = try fixture.acquire(kind: kind)
    let upgrade = try fixture.acquire(kind: kind, upgrade: true)
    try fixture.apply(upgrade, to: physical)
    try fixture.retire(physical)
    let original = fixture.snapshot
    try original.validate()
    let noSources = copy(original, sources: [])
    #expect(throws: (any Error).self) { try noSources.validateTransition(from: original) }
    let noReceipts = copy(original, receipts: [])
    #expect(throws: (any Error).self) { try noReceipts.validate() }
    let receipt = try #require(original.receipts.first)
    let changed = AlienStorageReceipt(
      id: receipt.id, owner: receipt.owner, operation: receipt.operation,
      effect: .upgrade(attachment: physical, upgrade: upgrade, basisPoints: 1))
    #expect(throws: (any Error).self) { try copy(original, receipts: [changed]).validate() }
    let old = try #require(original.attachments.first)
    let revived = AlienStorageAttachment(
      id: old.id, owner: old.owner, kind: old.kind, source: old.source,
      disposition: .stored, contributionBasisPoints: old.contributionBasisPoints)
    #expect(throws: (any Error).self) { try copy(original, attachments: [revived]).validate() }
    let duplicate = copy(original, upgrades: original.upgrades + original.upgrades)
    #expect(throws: (any Error).self) { try duplicate.validate() }
    let noWorld = copy(original, world: [])
    #expect(throws: (any Error).self) { try noWorld.validate() }
  }

  @Test func duplicateCommandRevisionsAndTransferMembersAreRejected() throws {
    var fixture = AlienStorageTestFixture()
    let physical = try fixture.acquire(kind: AlienModuleKind.allCases[0])
    try fixture.fit(physical)
    fixture.transfer(to: AlienStorageTestFixture.uuid(999))
    let original = fixture.snapshot
    let last = try #require(original.commands.last)
    var commands = original.commands
    commands[commands.count - 1] = .init(
      id: last.id, owner: last.owner, revision: 1, action: last.action)
    #expect(throws: (any Error).self) { try copy(original, commands: commands).validate() }
    let receipt = try #require(original.receipts.first)
    let repeated = AlienStorageReceipt(
      id: AlienStorageTestFixture.uuid(987), owner: receipt.owner,
      operation: receipt.operation, effect: receipt.effect)
    #expect(throws: (any Error).self) {
      try copy(original, receipts: original.receipts + [repeated]).validate()
    }
  }

  @Test func worldDeletionOriginalSourceRerollAndTerminalRewindAreRejected() throws {
    var fixture = AlienStorageTestFixture()
    _ = try fixture.acquire(kind: AlienModuleKind.allCases[0])
    let original = fixture.snapshot
    let worldPlan = try #require(
      original.world.compactMap { record -> AlienStorageWorldPlan? in
        if case .plan(let plan) = record { return plan }
        return nil
      }.first)
    let rerolled = AlienStorageWorldPlan(
      id: worldPlan.id, owner: worldPlan.owner,
      seed: worldPlan.seed + 1, plan: worldPlan.plan, inspectedAt: worldPlan.inspectedAt,
      requiredWorkSeconds: worldPlan.requiredWorkSeconds, workSeconds: worldPlan.workSeconds,
      damagedTechnology: worldPlan.damagedTechnology, depleted: worldPlan.depleted,
      destroyed: worldPlan.destroyed, lastOperation: worldPlan.lastOperation,
      progress: worldPlan.progress)
    let changed = original.world.map {
      $0.id == worldPlan.id ? AlienStorageWorldRecord.plan(rerolled) : $0
    }
    #expect(throws: (any Error).self) {
      try copy(original, world: changed).validateTransition(from: original)
    }
    #expect(throws: (any Error).self) {
      try AlienStorageWorldValidation.preserve(original.world, in: [])
    }
    let terminal = try #require(
      original.world.compactMap { record -> AlienStorageWorldLot? in
        if case .lot(let lot) = record { return lot }
        return nil
      }.first)
    let reset = AlienStorageWorldLot(
      id: terminal.id, owner: terminal.owner, plan: terminal.plan,
      itemIndex: terminal.itemIndex, issuedAt: nil, state: .unissued)
    let rewound = original.world.map {
      $0.id == terminal.id ? AlienStorageWorldRecord.lot(reset) : $0
    }
    #expect(throws: (any Error).self) {
      try AlienStorageWorldValidation.preserve(original.world, in: rewound)
    }
  }

  private func copy(
    _ value: AlienStorageSnapshot, world: [AlienStorageWorldRecord]? = nil,
    sources: [AlienStorageSource]? = nil, attachments: [AlienStorageAttachment]? = nil,
    upgrades: [AlienStorageUpgrade]? = nil, receipts: [AlienStorageReceipt]? = nil,
    commands: [AlienStorageCommand]? = nil
  ) -> AlienStorageSnapshot {
    .init(
      owner: value.owner, revision: value.revision, worldRevision: value.worldRevision,
      world: world ?? value.world, sources: sources ?? value.sources,
      attachments: attachments ?? value.attachments,
      upgrades: upgrades ?? value.upgrades, receipts: receipts ?? value.receipts,
      commands: commands ?? value.commands)
  }
}
