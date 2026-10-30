import Foundation
import Testing

@testable import L337Core

struct SalvageSectionEmissionViewTests {
  private let section = WreckSectionIdentity(
    wreck: .init(system: .init(galaxy: 0, system: 7), site: 1, lineage: 123), section: 1)

  private func cargoPlan() -> SalvageLootPlan {
    SalvageLootProfiles.plan(
      section: section, seed: 42,
      source: .init(
        roles: [.commercialTrader], legalValue: 0, economy: 3, technology: 12,
        ownership: .abandoned,
        manifest: [
          .init(commodity: .food, quantity: 12), .init(commodity: .gold, quantity: 1001),
          .init(commodity: .gemstones, quantity: 1_000_001),
        ]))
  }

  @Test func exactOriginalStructuralAndMixedUnitChunksKeepOneSerialCursor() throws {
    let plan = cargoPlan()
    #expect(plan.items.count == 3)
    let structural = SalvageLotEmission.structuralUnits(seed: 42, section: section)
    #expect(structural == 5)
    let progress = AlienStorageWorldProgress(
      issued: [12, 1001, 1_000_001], discarded: [false, false, false],
      structuralUnits: structural, issuedStructural: structural,
      materialKind: .alloys, nextLot: 8)
    let view = SalvageSectionEmissionView(seed: 42, plan: plan, progress: progress)
    try view.validate()
    let emitted = try view.emissions()
    #expect(emitted.count == 8)
    #expect(emitted[.structural]?.identity.lot == 0)
    #expect(emitted[.structural]?.content == .commodity(.init(commodity: .alloys, quantity: 5)))
    let expected: [(UInt16, UInt16, UInt16, CommodityIdentity, Int)] = [
      (0, 0, 1, .food, 5), (0, 1, 2, .food, 5), (0, 2, 3, .food, 2),
      (1, 0, 4, .gold, 1000), (1, 1, 5, .gold, 1),
      (2, 0, 6, .gemstones, 1_000_000), (2, 1, 7, .gemstones, 1),
    ]
    for (index, ordinal, serial, commodity, quantity) in expected {
      let item = try #require(emitted[.planned(itemIndex: index, chunkOrdinal: ordinal)])
      #expect(item.identity == .init(section: section, lot: serial))
      #expect(item.content == .commodity(.init(commodity: commodity, quantity: quantity)))
      #expect(!item.requiresChunking)
    }
  }

  @Test func timingFreePartialEmissionProofDoesNotInventACompletedWorkBudget() throws {
    let plan = cargoPlan()
    let progress = AlienStorageWorldProgress(
      issued: [5, 0, 0], discarded: [false, false, false], structuralUnits: 0,
      issuedStructural: 0, materialKind: .alloys, nextLot: 1)
    let view = SalvageSectionEmissionView(seed: 42, plan: plan, progress: progress)
    try view.validate()
    #expect(try view.emissions().count == 1)
    // An old batch can have no saved current work. Native timing retains its
    // separate strict requirements; the legacy proof supplies no fake times.
    let native = AlienStorageWorldPlan(
      id: UUID(), owner: UUID(), seed: 42, plan: plan, inspectedAt: 0,
      requiredWorkSeconds: 1, workSeconds: 0, damagedTechnology: false,
      depleted: false, destroyed: false, lastOperation: 1, progress: progress)
    #expect(throws: AlienStorageError.self) { try progress.validate(plan: native) }
    #expect(throws: AlienStorageError.self) { try progress.emissions(plan: native) }
  }

  @Test func discardedTechnologyAndOriginalEmptyInspectionIssueNoSerialOrProperty() throws {
    let (seed, plan, _) = try AlienStorageTestFixture.plan(
      site: 17, definition: AlienModuleKind.energyCapacity.definitionID)
    let discarded = AlienStorageWorldProgress(
      issued: [1], discarded: [true], structuralUnits: 0, issuedStructural: 0,
      materialKind: .minerals, nextLot: 0)
    let view = SalvageSectionEmissionView(seed: seed, plan: plan, progress: discarded)
    #expect(try view.emissions().isEmpty)
    let source = SalvageLootSource(
      roles: [], legalValue: 0, economy: 3, technology: 12, ownership: .abandoned)
    let empty = SalvageLootProfiles.plan(section: section, seed: 42, source: source)
    #expect(empty.items.isEmpty && empty.emptyReason != nil)
    let progress = AlienStorageWorldProgress(
      issued: [], discarded: [], structuralUnits: 0, issuedStructural: 0,
      materialKind: nil, nextLot: 0)
    #expect(
      try SalvageSectionEmissionView(seed: 42, plan: empty, progress: progress).emissions().isEmpty)
  }

  @Test func wrongOriginalSeedStructuralCountPrefixAndCursorAreRefused() throws {
    let plan = cargoPlan()
    let valid = AlienStorageWorldProgress(
      issued: [5, 0, 0], discarded: [false, false, false], structuralUnits: 0,
      issuedStructural: 0, materialKind: .alloys, nextLot: 1)
    // Use an actual seeded technology outcome to prove original seed matching.
    let (seed, technology, _) = try AlienStorageTestFixture.plan(
      site: 18, definition: AlienModuleKind.shieldCapacity.definitionID)
    let technologyProgress = AlienStorageWorldProgress(
      issued: [1], discarded: [false], structuralUnits: 0, issuedStructural: 0,
      materialKind: .alloys, nextLot: 1)
    let wrongSeed = try #require(
      (seed + 1..<seed + 100).first {
        SalvageLootProfiles.plan(section: technology.section, seed: $0, source: technology.source)
          != technology
      })
    #expect(throws: AlienStorageError.self) {
      try SalvageSectionEmissionView(
        seed: wrongSeed, plan: technology, progress: technologyProgress
      )
      .emissions()
    }
    for bad in [
      AlienStorageWorldProgress(
        issued: [5, 0, 0], discarded: [false, false, false], structuralUnits: 0,
        issuedStructural: 0, materialKind: .alloys, nextLot: 2),
      .init(
        issued: [5, 1000, 0], discarded: [false, false, false], structuralUnits: 0,
        issuedStructural: 0, materialKind: .alloys, nextLot: 2),
      .init(
        issued: [5, 0, 0], discarded: [false, false, false], structuralUnits: 1,
        issuedStructural: 1, materialKind: .alloys, nextLot: 2),
      .init(
        issued: [4, 0, 0], discarded: [false, false, false], structuralUnits: 0,
        issuedStructural: 0, materialKind: .alloys, nextLot: 1),
    ] {
      #expect(throws: AlienStorageError.self) {
        try SalvageSectionEmissionView(seed: 42, plan: plan, progress: bad).emissions()
      }
    }
    #expect(
      try SalvageSectionEmissionView(seed: 42, plan: plan, progress: valid).emissions().count == 1)
  }
}
