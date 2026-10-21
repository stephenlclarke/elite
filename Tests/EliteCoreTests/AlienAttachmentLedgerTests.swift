import Foundation
import Testing

@testable import EliteCore

private func attachmentLot(
  _ index: UInt16, kind: AlienModuleKind = .energyCapacity, upgrade: Bool = false,
  quality: SalvageQuality = .i, provenance: SalvageProvenance = .alien, section: UInt16 = 1
) -> SalvageLot {
  let identity = SalvageLotIdentity(
    section: .init(
      wreck: .init(system: .init(galaxy: 0, system: 7), site: 1, lineage: 42), section: section),
    lot: index)
  let id = upgrade ? kind.upgradeDefinitionID : kind.definitionID
  let content = SalvageLotContent.technology(
    definitionID: id, quality: quality, conditionPercent: 75)
  let loot = SalvageLootItem(
    identity: identity,
    content: .technology(
      definitionID: id, quality: quality, conditionPercent: 75, axis: upgrade ? kind.axes[0] : nil),
    effect: .scalar(axes: kind.axes), bonusBasisPoints: upgrade ? quality.bonusBasisPoints : 1000,
    massKg: 8, halfExtents: .init(2, 2, 2), provenance: provenance, saleValueTenths: 1000,
    legality: .init(
      commodityIllegal: false, sourceLegalValue: 0, ownership: .abandoned, stolenProvenance: false),
    requiresChunking: false)
  return .init(
    identity: identity, content: content, position: .init(1, 2, 3), velocity: .init(0, 0, 0),
    halfExtents: .init(2, 2, 2), massKg: 8, loot: loot)
}

private let attachmentBase = AlienAttachmentBase(
  energyCapacity: 200, energyRecharge: 20, frontShieldCapacity: 100, rearShieldCapacity: 150,
  frontShieldRecharge: 10, rearShieldRecharge: 12)

struct AlienAttachmentLedgerTests {
  @Test func moreThanOldInventoryAndSettlementPoolsFitWithoutAHiddenAttachmentCap() throws {
    let owner = UUID()
    let hull = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    for index in 0..<2050 {
      let item = try ledger.admitRecovered(
        lot: attachmentLot(UInt16(index)), command: UUID(), owner: owner,
        expectedRevision: ledger.revision)
      try ledger.relocate(
        item: item, toHull: hull, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    }
    let base = AlienAttachmentBase(
      energyCapacity: 1000, energyRecharge: 20, frontShieldCapacity: 100, rearShieldCapacity: 150,
      frontShieldRecharge: 10, rearShieldRecharge: 12)
    let effects = try AlienAttachmentEffects.resolve(
      ledger: ledger, owner: owner, activeHull: hull, normalBase: base)
    #expect(ledger.items.count == 2050 && ledger.fitted(to: hull).count == 2050)
    #expect(effects.summaries[.energyCapacity]?.count == 2050)
    #expect(effects.summaries[.energyCapacity]?.percent == 20500)
    #expect(effects.energyModuleCount == 2050 && effects.effective.energyCapacity == 206000)
    let restored = try JSONDecoder().decode(
      AlienAttachmentLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored == ledger)
    #expect(
      try AlienAttachmentEffects.resolve(
        ledger: restored, owner: owner, activeHull: hull, normalBase: base) == effects)
  }

  @Test func allFourTypesStackIndependentlyAndStoredOrInactiveHullsContributeNothing() throws {
    let owner = UUID()
    let hull = UUID()
    let otherHull = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    var index: UInt16 = 0
    for kind in AlienModuleKind.allCases {
      for _ in 0..<(kind.isEnergyModule ? 2 : 3) {
        let item = try ledger.admitRecovered(
          lot: attachmentLot(index, kind: kind), command: UUID(), owner: owner,
          expectedRevision: ledger.revision)
        try ledger.relocate(
          item: item, toHull: hull, command: UUID(), owner: owner, expectedRevision: ledger.revision
        )
        index += 1
      }
    }
    let stored = try ledger.admitRecovered(
      lot: attachmentLot(index), command: UUID(), owner: owner, expectedRevision: ledger.revision)
    index += 1
    let inactive = try ledger.admitRecovered(
      lot: attachmentLot(index), command: UUID(), owner: owner, expectedRevision: ledger.revision)
    try ledger.relocate(
      item: inactive, toHull: otherHull, command: UUID(), owner: owner,
      expectedRevision: ledger.revision)
    let effects = try AlienAttachmentEffects.resolve(
      ledger: ledger, owner: owner, activeHull: hull, normalBase: attachmentBase)
    #expect(effects.energyModuleCount == 4)
    #expect(
      effects.summaries[.energyCapacity]?.percent == 20
        && effects.summaries[.energyRecharge]?.percent == 20)
    #expect(
      effects.summaries[.shieldCapacity]?.percent == 30
        && effects.summaries[.shieldRecharge]?.percent == 30)
    #expect(effects.effective.energyCapacity == 240 && effects.effective.energyRecharge == 24)
    #expect(
      effects.effective.frontShieldCapacity == 130 && effects.effective.rearShieldCapacity == 195)
    #expect(
      effects.effective.frontShieldRecharge == 13
        && abs(effects.effective.rearShieldRecharge - 15.6) < 1e-10)
    #expect(ledger.item(stored)?.disposition == .stored)
    let unused = try AlienAttachmentEffects.resolve(
      ledger: ledger, owner: owner, activeHull: UUID(), normalBase: attachmentBase)
    #expect(unused.effective == attachmentBase && unused.energyModuleCount == 0)
    // Normal base improvement remains independent: retained attachments are folded onto the new base once.
    let improved = AlienAttachmentBase(
      energyCapacity: 400, energyRecharge: 40, frontShieldCapacity: 200,
      rearShieldCapacity: 300, frontShieldRecharge: 20, rearShieldRecharge: 24)
    let upgrade = try AlienAttachmentEffects.resolve(
      ledger: ledger, owner: owner, activeHull: hull, normalBase: improved)
    #expect(upgrade.effective.energyCapacity == 480 && upgrade.effective.frontShieldCapacity == 260)
    #expect(
      upgrade.summaries == effects.summaries
        && upgrade.energyModuleCount == effects.energyModuleCount)
  }

  @Test func upgradesRemainOnTheSamePhysicalItemThroughStorageTransferRetirementAndReload() throws {
    let owner = UUID()
    let hull = UUID()
    let replacementHull = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    let source = attachmentLot(0)
    let item = try ledger.admitRecovered(
      lot: source, command: UUID(), owner: owner, expectedRevision: 0)
    for (index, quality) in SalvageQuality.allCases.enumerated() {
      try ledger.upgrade(
        item: item, lot: attachmentLot(UInt16(index + 1), upgrade: true, quality: quality),
        command: UUID(), owner: owner, expectedRevision: ledger.revision)
    }
    #expect(ledger.item(item)?.contributionBasisPoints == 4000)
    try ledger.relocate(
      item: item, toHull: hull, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    let before = try #require(ledger.item(item))
    try ledger.transferHull(
      from: hull, to: replacementHull, command: UUID(), owner: owner,
      expectedRevision: ledger.revision)
    let transferred = try #require(ledger.item(item))
    #expect(
      transferred.id == before.id && transferred.source == before.source
        && transferred.upgrades == before.upgrades)
    #expect(transferred.contributionBasisPoints == 4000)
    let beforeReplay = ledger
    #expect(throws: AlienAttachmentError.replayedSource) {
      _ = try ledger.admitRecovered(
        lot: source, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    }
    #expect(ledger == beforeReplay)
    #expect(transferred.disposition == .fitted(.init(hull: replacementHull, attachment: item)))
    let effects = try AlienAttachmentEffects.resolve(
      ledger: ledger, owner: owner, activeHull: replacementHull, normalBase: attachmentBase)
    #expect(effects.summaries[.energyCapacity]?.percent == 40 && effects.energyModuleCount == 1)
    try ledger.relocate(
      item: item, toHull: nil, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    ledger = try JSONDecoder().decode(
      AlienAttachmentLedger.self, from: JSONEncoder().encode(ledger))
    #expect(
      ledger.item(item)?.contributionBasisPoints == 4000
        && ledger.item(item)?.disposition == .stored)
    try ledger.retire(
      item: item, reason: .sold, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    let terminal = ledger
    #expect(throws: AlienAttachmentError.replayedSource) {
      _ = try ledger.admitRecovered(
        lot: source, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    }
    #expect(throws: AlienAttachmentError.retiredItem) {
      try ledger.relocate(
        item: item, toHull: hull, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    }
    #expect(ledger == terminal && ledger.sourceWasClaimed(source.identity))
    let other = try ledger.admitRecovered(
      lot: attachmentLot(4), command: UUID(), owner: owner, expectedRevision: ledger.revision)
    let beforeUpgradeReplay = ledger
    #expect(throws: AlienAttachmentError.replayedSource) {
      try ledger.upgrade(
        item: other, lot: attachmentLot(1, upgrade: true), command: UUID(), owner: owner,
        expectedRevision: ledger.revision)
    }
    #expect(ledger == beforeUpgradeReplay)
    for index in 1...3 {
      #expect(ledger.sourceWasClaimed(attachmentLot(UInt16(index), upgrade: true).identity))
    }
    #expect(
      try JSONDecoder().decode(AlienAttachmentLedger.self, from: JSONEncoder().encode(ledger))
        == ledger)
  }

  @Test func wrongOwnerStaleCommandWrongAxisAndHumanOrLegacySourcesNeverMutateLedger() throws {
    let owner = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    let command = UUID()
    let item = try ledger.admitRecovered(
      lot: attachmentLot(0), command: command, owner: owner, expectedRevision: 0)
    let before = ledger
    #expect(throws: AlienAttachmentError.wrongOwner) {
      try ledger.relocate(
        item: item, toHull: UUID(), command: UUID(), owner: UUID(),
        expectedRevision: ledger.revision)
    }
    #expect(throws: AlienAttachmentError.staleRevision) {
      try ledger.relocate(
        item: item, toHull: UUID(), command: UUID(), owner: owner, expectedRevision: 0)
    }
    #expect(throws: AlienAttachmentError.replayedCommand) {
      try ledger.relocate(
        item: item, toHull: UUID(), command: command, owner: owner,
        expectedRevision: ledger.revision)
    }
    #expect(throws: AlienAttachmentError.invalidSource) {
      try ledger.upgrade(
        item: item, lot: attachmentLot(1, kind: .shieldCapacity, upgrade: true), command: UUID(),
        owner: owner, expectedRevision: ledger.revision)
    }
    #expect(throws: AlienAttachmentError.invalidSource) {
      _ = try ledger.admitRecovered(
        lot: attachmentLot(2, provenance: .human), command: UUID(), owner: owner,
        expectedRevision: ledger.revision)
    }
    let template = attachmentLot(3)
    let artefact = SalvageLot(
      identity: template.identity,
      content: .technology(definitionID: "alien-artefact", quality: .i, conditionPercent: 75),
      position: template.position, velocity: template.velocity, halfExtents: template.halfExtents,
      massKg: template.massKg, loot: template.loot)
    #expect(throws: AlienAttachmentError.invalidSource) {
      _ = try ledger.admitRecovered(
        lot: artefact, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    }
    #expect(ledger == before)
  }

  @Test func duplicatePhysicalKeysRejectBeforePoisonPayloadAndSavedDowngradesFail() throws {
    let owner = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    let item = try ledger.admitRecovered(
      lot: attachmentLot(0), command: UUID(), owner: owner, expectedRevision: 0)
    let bytes = try JSONEncoder().encode(ledger)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var duplicate = object
    var records = try #require(object["records"] as? [Any])
    records += [item.uuidString, NSNull()]
    duplicate["records"] = records
    #expect(throws: AlienAttachmentError.invalidState) {
      _ = try JSONDecoder().decode(
        AlienAttachmentLedger.self, from: JSONSerialization.data(withJSONObject: duplicate))
    }
    var unknownVersion = object
    unknownVersion["version"] = 2
    #expect(throws: AlienAttachmentError.invalidState) {
      _ = try JSONDecoder().decode(
        AlienAttachmentLedger.self, from: JSONSerialization.data(withJSONObject: unknownVersion))
    }
    var missingProof = object
    missingProof["records"] = []
    #expect(throws: AlienAttachmentError.invalidState) {
      _ = try JSONDecoder().decode(
        AlienAttachmentLedger.self, from: JSONSerialization.data(withJSONObject: missingProof))
    }
    var forged = object
    var entries = try #require(forged["records"] as? [Any])
    var physical = try #require(entries[1] as? [String: Any])
    physical["contributionBasisPoints"] = 999
    entries[1] = physical
    forged["records"] = entries
    #expect(throws: AlienAttachmentError.invalidState) {
      _ = try JSONDecoder().decode(
        AlienAttachmentLedger.self, from: JSONSerialization.data(withJSONObject: forged))
    }
    var duplicateCommand = object
    var commands = try #require(object["commands"] as? [Any])
    commands += [commands[0], NSNull()]
    duplicateCommand["commands"] = commands
    #expect(throws: AlienAttachmentError.invalidState) {
      _ = try JSONDecoder().decode(
        AlienAttachmentLedger.self, from: JSONSerialization.data(withJSONObject: duplicateCommand))
    }
  }

  @Test(arguments: [UInt16(64), UInt16.max])
  func invalidSalvageSectionNeverBecomesAnAttachmentOrUpgrade(section: UInt16) throws {
    let owner = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    let item = try ledger.admitRecovered(
      lot: attachmentLot(0), command: UUID(), owner: owner, expectedRevision: 0)
    let original = ledger
    let invalid = attachmentLot(1, section: section)
    #expect(throws: AlienAttachmentError.invalidSource) {
      _ = try ledger.admitRecovered(
        lot: invalid, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    }
    #expect(throws: AlienAttachmentError.invalidSource) {
      try ledger.upgrade(
        item: item, lot: attachmentLot(2, upgrade: true, section: section), command: UUID(),
        owner: owner, expectedRevision: ledger.revision)
    }
    #expect(ledger == original)
    // Change all redundant identity evidence consistently; only the source-section guard can reject it.
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
    var records = try #require(object["records"] as? [Any])
    var physical = try #require(records[1] as? [String: Any])
    physical["source"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(invalid))
    records[1] = physical
    object["records"] = records
    var commands = try #require(object["commands"] as? [Any])
    var action = try #require(commands[1] as? [String: Any])
    var acquire = try #require(action["acquire"] as? [String: Any])
    acquire["source"] = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(invalid.identity))
    action["acquire"] = acquire
    commands[1] = action
    object["commands"] = commands
    #expect(throws: AlienAttachmentError.invalidSource) {
      _ = try JSONDecoder().decode(
        AlienAttachmentLedger.self, from: JSONSerialization.data(withJSONObject: object))
    }
  }

  @Test func manyUpgradesOnOneItemRoundTripAndOrphanUpgradeCommandsStillRefuse() throws {
    let owner = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    let item = try ledger.admitRecovered(
      lot: attachmentLot(0), command: UUID(), owner: owner, expectedRevision: 0)
    for index in 1...1025 {
      try ledger.upgrade(
        item: item, lot: attachmentLot(UInt16(index), upgrade: true), command: UUID(), owner: owner,
        expectedRevision: ledger.revision)
    }
    #expect(ledger.item(item)?.upgrades.count == 1025)
    #expect(
      try JSONDecoder().decode(AlienAttachmentLedger.self, from: JSONEncoder().encode(ledger))
        == ledger)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
    var commands = try #require(object["commands"] as? [Any])
    let source = attachmentLot(2000, upgrade: true).identity
    commands += [
      UUID().uuidString,
      [
        "upgrade": [
          "item": item.uuidString,
          "source": try JSONSerialization.jsonObject(with: JSONEncoder().encode(source)),
        ]
      ],
    ]
    object["commands"] = commands
    object["revision"] = ledger.revision + 1
    #expect(throws: AlienAttachmentError.invalidState) {
      _ = try JSONDecoder().decode(
        AlienAttachmentLedger.self, from: JSONSerialization.data(withJSONObject: object))
    }
  }

  @Test func numericOverflowRefusesInsteadOfClampingTheInstalledBonus() throws {
    let owner = UUID()
    let hull = UUID()
    var ledger = AlienAttachmentLedger(owner: owner)
    let item = try ledger.admitRecovered(
      lot: attachmentLot(0), command: UUID(), owner: owner, expectedRevision: 0)
    try ledger.relocate(
      item: item, toHull: hull, command: UUID(), owner: owner, expectedRevision: ledger.revision)
    let impossible = AlienAttachmentBase(
      energyCapacity: .greatestFiniteMagnitude, energyRecharge: 1,
      frontShieldCapacity: 1, rearShieldCapacity: 1, frontShieldRecharge: 1, rearShieldRecharge: 1)
    #expect(throws: AlienAttachmentError.arithmeticOverflow) {
      _ = try AlienAttachmentEffects.resolve(
        ledger: ledger, owner: owner, activeHull: hull, normalBase: impossible)
    }
    let effects = try AlienAttachmentEffects.resolve(
      ledger: ledger, owner: owner, activeHull: hull, normalBase: attachmentBase)
    #expect(
      effects.summaries[.energyCapacity]?.count == 1
        && effects.summaries[.energyCapacity]?.percent == 10)
  }
}
