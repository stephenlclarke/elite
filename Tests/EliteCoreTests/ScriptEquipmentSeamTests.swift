import Foundation
import Testing

@testable import EliteCore

private func legacyIssueFixture(
  loan: Bool = true, status: ScriptGearStatus = .issued, consumed: Bool = false,
  present: Bool = true, remaining: Bool = false
) -> (LegacyOwnedEquipmentInventory, ScriptEngineState) {
  let mission = UUID(uuidString: "31000000-0000-0000-0000-000000000001")!
  let itemID = UUID(uuidString: "32000000-0000-0000-0000-000000000001")!
  var instance = ScriptInstance(
    id: mission, definition: "fixture.legacy/gear", version: "1.0.0",
    digest: String(repeating: "0", count: 64))
  instance.gearIssues["original"] = .init(
    resource: "original", kind: .missile, items: [itemID], loan: loan,
    returnRemaining: remaining, status: status, consumed: consumed ? [itemID] : [])
  var engine = ScriptEngineState()
  engine.instances[mission] = instance
  var inventory = LegacyOwnedEquipmentInventory()
  if present {
    var item = OwnedGear(id: itemID, kind: .missile, slot: .pylon(0))
    item.fittedSlot = nil
    item.issuedBy = mission
    item.sourceResource = "original"
    item.loanOwner = loan && status == .issued ? mission : nil
    inventory.items = [item]
  }
  return (inventory, engine)
}

struct ScriptEquipmentSeamTests {
  @Test(arguments: ["personal", "issuer", "resource", "loan", "kind"])
  func presentOriginalCannotBeSubstitutedByPersonalOrMismatchedLegacyGear(field: String) throws {
    let fixture = legacyIssueFixture()
    var inventory = fixture.0
    let engine = fixture.1
    switch field {
    case "personal":
      inventory.items[0].issuedBy = nil
      inventory.items[0].sourceResource = nil
      inventory.items[0].loanOwner = nil
    case "issuer":
      inventory.items[0].issuedBy = UUID(uuidString: "31000000-0000-0000-0000-000000000002")!
    case "resource": inventory.items[0].sourceResource = "different"
    case "loan": inventory.items[0].loanOwner = nil
    default:
      let original = inventory.items[0]
      var changed = OwnedGear(id: original.id, kind: .laser(.beam), slot: .laser(.front))
      changed.fittedSlot = nil
      changed.issuedBy = original.issuedBy
      changed.sourceResource = original.sourceResource
      changed.loanOwner = original.loanOwner
      inventory.items[0] = changed
    }
    // Each candidate passes the old bag's structural rules; its issue join must still refuse.
    #expect(inventory.valid)
    let before = inventory
    #expect(throws: EquipmentMigrationError.obligationMismatch) {
      try inventory.validateIssues(in: engine)
    }
    #expect(inventory == before)
  }

  @Test func validIssuedAndReleasedOriginalsAndAbsentNonloanHistoryRemainValid() throws {
    for loan in [false, true] {
      let (inventory, engine) = legacyIssueFixture(loan: loan)
      try inventory.validateIssues(in: engine)
    }
    let (released, releasedEngine) = legacyIssueFixture(status: .released)
    try released.validateIssues(in: releasedEngine)
    #expect(released.items[0].loanOwner == nil && released.items[0].issuedBy != nil)
    let (missing, missingEngine) = legacyIssueFixture(loan: false, present: false)
    try missing.validateIssues(in: missingEngine)
    #expect(missing.items.isEmpty)
    #expect(missingEngine.instances.values.first?.gearIssues["original"]?.consumed.isEmpty == true)
  }

  @Test func consumedAndReturnedRecordsRequireAbsenceWhileAnActiveLoanRequiresItsOriginal() throws {
    for (status, consumed, remaining) in [
      (ScriptGearStatus.issued, true, false), (.returned, false, false), (.returned, true, true),
    ] {
      let (absent, engine) = legacyIssueFixture(
        status: status, consumed: consumed, present: false, remaining: remaining)
      try absent.validateIssues(in: engine)
      let (present, _) = legacyIssueFixture(
        status: status, consumed: consumed, remaining: remaining)
      #expect(throws: EquipmentMigrationError.obligationMismatch) {
        try present.validateIssues(in: engine)
      }
    }
    let (missingLoan, engine) = legacyIssueFixture(present: false)
    #expect(throws: EquipmentMigrationError.obligationMismatch) {
      try missingLoan.validateIssues(in: engine)
    }
  }

  @Test func heldLoanRetainsHistoricalConditionAndModificationsThroughLegacyDecode() throws {
    let fixture = legacyIssueFixture()
    var inventory = fixture.0
    let engine = fixture.1
    inventory.items[0].condition = 7300
    inventory.items[0].modifications = ["historical-adjustment": -25]
    let restored = try JSONDecoder().decode(
      LegacyOwnedEquipmentInventory.self, from: JSONEncoder().encode(inventory))
    try restored.validateIssues(in: engine)
    #expect(restored == inventory && restored.items[0].fittedSlot == nil)
  }

  @Test(arguments: [false, true])
  func actualSharedRoundConsumptionStagesOnlyItsOriginalLoanAndVirtualUseChangesNothing(
    unlimited: Bool
  ) throws {
    let legacy = legacyIssueFixture()
    var engine = legacy.1
    let mission = try #require(engine.instances.keys.first)
    let original = try #require(engine.instances[mission]?.gearIssues["original"])
    let source = EquipmentIssueSource(
      mission: mission, resource: "original", packDigest: String(repeating: "0", count: 64))
    let record = ScriptGearIssue(
      resource: original.resource, kind: original.kind, items: original.items, loan: true,
      returnRemaining: true, savedGearVersion: 2, source: source,
      node: EquipmentRuntimeCatalog.standardMissile, displacements: [])
    engine.instances[mission]?.gearIssues["original"] = record
    let owner = UUID(uuidString: "33000000-0000-0000-0000-000000000001")!
    let hull = UUID(uuidString: "34000000-0000-0000-0000-000000000001")!
    let round = OwnedEquipmentItem(
      id: original.items[0], node: EquipmentRuntimeCatalog.standardMissile,
      provenance: .missionIssue(
        mission: mission, resource: "original", index: 0,
        packDigest: source.packDigest),
      location: .init(hullInstanceID: hull, slot: .missilePylon(0)))
    let inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [round])
    let context = EquipmentRuntimeCatalog.context(
      owner: owner, hull: hull, performance: Commander().nativePerformance)
    let obligations = [try #require(record.obligation)]
    let quote = try StandardAmmunitionTransactions.quoteConsumption(
      unlimited: unlimited, inventory: inventory, context: context, obligations: obligations)
    let applied = try StandardAmmunitionTransactions.applyConsumption(
      quote: quote, inventory: inventory, context: context, obligations: obligations)
    if unlimited {
      #expect(applied.source == .virtualUnlimited && applied.removedItem == nil)
      #expect(
        applied.inventory == inventory
          && engine.instances[mission]?.gearIssues["original"] == record)
    } else {
      let removed = try #require(applied.removedItem)
      #expect(removed == round && applied.source == .physical(item: round.id))
      #expect(
        applied.inventory.items.isEmpty && applied.inventory.revision == inventory.revision + 1)
      let delta = try #require(engine.gearConsumptionDelta(for: removed))
      #expect(delta.eventKind == "gear.consumed")
      #expect(delta.values == ["item": .string(round.id.uuidString), "name": .string("Missile")])
      let staged = try engine.applying(delta)
      #expect(engine.instances[mission]?.gearIssues["original"] == record)
      var expected = record
      expected.consumed = [round.id]
      #expect(staged.instances[mission]?.gearIssues["original"] == expected)
      #expect(staged.instances[mission]?.receipts == engine.instances[mission]?.receipts)
      #expect(throws: EquipmentIssueError.staleObligation) { try staged.applying(delta) }
    }
  }

  @Test func missingMissionRightsRefuseConsumptionRatherThanBecomingPersonalUse() throws {
    let item = UUID(uuidString: "35000000-0000-0000-0000-000000000001")!
    let mission = UUID(uuidString: "36000000-0000-0000-0000-000000000001")!
    let engine = ScriptEngineState()
    let personal = OwnedEquipmentItem(
      id: item, node: EquipmentRuntimeCatalog.standardMissile, provenance: .standard)
    #expect(try engine.gearConsumptionDelta(for: personal) == nil)
    let orphan = OwnedEquipmentItem(
      id: item, node: EquipmentRuntimeCatalog.standardMissile,
      provenance: .missionIssue(
        mission: mission, resource: "missing", index: 0,
        packDigest: String(repeating: "0", count: 64)))
    #expect(throws: EquipmentMigrationError.obligationMismatch) {
      try engine.gearConsumptionDelta(for: orphan)
    }
    #expect(engine.instances.isEmpty)
  }
}
