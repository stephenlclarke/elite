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
    var (inventory, engine) = legacyIssueFixture()
    switch field {
    case "personal":
      inventory.items[0].issuedBy = nil
      inventory.items[0].sourceResource = nil
      inventory.items[0].loanOwner = nil
    case "issuer": inventory.items[0].issuedBy = UUID()
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
    var (inventory, engine) = legacyIssueFixture()
    inventory.items[0].condition = 7300
    inventory.items[0].modifications = ["historical-adjustment": -25]
    let restored = try JSONDecoder().decode(
      LegacyOwnedEquipmentInventory.self, from: JSONEncoder().encode(inventory))
    try restored.validateIssues(in: engine)
    #expect(restored == inventory && restored.items[0].fittedSlot == nil)
  }
}
