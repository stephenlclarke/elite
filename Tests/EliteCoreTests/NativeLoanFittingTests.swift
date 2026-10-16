import Foundation
import Testing

@testable import EliteCore

struct NativeLoanFittingTests {
  private func heldIssue(_ kind: OwnedGearKind, slot: ComponentFittingSlot) throws -> (
    Game, UUID, UUID
  ) {
    var game = Game(executive: false)
    game.screen = .inventory
    try game.commander.prepareEquipment(legacy: false)
    var instance = ScriptInstance(
      id: UUID(), definition: "fixture/loan", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    let id = UUID()
    let node = try #require(kind.canonicalNode)
    let source = EquipmentIssueSource(
      mission: instance.id, resource: "hardware", packDigest: instance.digest)
    instance.gearIssues["hardware"] = .init(
      resource: "hardware", kind: kind, items: [id], loan: true,
      returnRemaining: true, savedGearVersion: 2, source: source, node: node, displacements: [])
    let item = OwnedEquipmentItem(
      id: id, node: node,
      provenance: .missionIssue(
        mission: instance.id, resource: "hardware", index: 0, packDigest: instance.digest),
      component: EquipmentRuntimeCatalog.stockComponent(for: node, id: id), preferredSlot: slot)
    var inventory = try #require(game.commander.equipmentInventory)
    try inventory.admit(
      item, expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.nativePerformance))
    game.commander.savedEquipmentInventory = inventory
    game.commander.scriptState.instances[instance.id] = instance
    #expect(game.commander.valid)
    return (game, instance.id, id)
  }

  @Test func nativeHeldLoanRoundFitsAndStoresThroughItsOwnReceiptWithoutChangingRights() throws {
    var (game, mission, id) = try heldIssue(.missile, slot: .missilePylon(3))
    let original = game.commander
    let item = try #require(game.commander.equipmentInventory?.items.first { $0.id == id })
    let revision = try #require(game.commander.equipmentInventory?.revision)
    try game.fitEquipment(item, at: .missilePylon(3), expectedRevision: revision)
    let fitted = try #require(game.commander.fittedEquipment(at: .missilePylon(3)))
    #expect(fitted.id == id && game.commander.missiles == 4 && game.commander.valid)
    try game.storeEquipment(fitted, expectedRevision: revision + 1)
    #expect(game.commander.equipmentInventory?.revision == revision + 2)
    #expect(game.commander.equipmentInventory?.items.first { $0.id == id } == item)
    #expect(
      game.commander.scriptState.instances[mission]?.gearIssues["hardware"]?.status == .issued)
    #expect(
      game.commander.scriptState.instances[mission]?.gearIssues["hardware"]?.consumed.isEmpty
        == true)
    #expect(
      game.commander.credits == original.credits
        && game.commander.equipmentPurchaseHistory == original.equipmentPurchaseHistory)
    #expect(game.commander.valid)
  }

  @Test func nativeLoanLaserReceiptRestoresTheExactDisplacedPersonalLaserOnReturn() throws {
    var (game, mission, id) = try heldIssue(.laser(.beam), slot: .laser(.front))
    let old = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    let item = try #require(game.commander.equipmentInventory?.items.first { $0.id == id })
    try game.fitEquipment(
      item, at: .laser(.front), expectedRevision: game.commander.equipmentInventory!.revision)
    let record = try #require(game.commander.scriptState.instances[mission]?.gearIssues["hardware"])
    #expect(record.displacements?.map(\.item) == [old.id])
    let inventory = try #require(game.commander.equipmentInventory)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull,
      performance: game.commander.nativePerformance)
    let obligations = try game.commander.equipmentIssueObligations()
    let obligation = try #require(record.obligation)
    let projected = try EquipmentIssueTransactions.projectSettlement(
      operation: .returnOriginals,
      obligation: obligation, inventory: inventory, context: context, obligations: obligations)
    let budget = try game.commander.equipmentFitBudget(projectedItems: projected.items)
    let quote = try EquipmentIssueTransactions.quoteSettlement(
      command: UUID(), operation: .returnOriginals,
      obligation: obligation, inventory: inventory, context: context, obligations: obligations,
      budget: budget)
    let applied = try EquipmentIssueTransactions.applySettlement(
      quote: quote, inventory: inventory,
      context: context, obligations: obligations, budget: budget)
    game.commander.savedEquipmentInventory = applied.inventory
    game.commander.scriptState = try game.commander.scriptState.applying(applied.receipt)
    game.commander.mirrorFittedEquipment()
    #expect(game.commander.fittedEquipment(at: .laser(.front)) == old)
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == id } == false)
    #expect(
      game.commander.scriptState.instances[mission]?.gearIssues["hardware"]?.status == .returned)
    #expect(game.commander.valid)
  }

  @Test func nativePersonalReplacementGrantAndGenericRemovalCannotTakeAnActiveLoan() throws {
    var (game, _, id) = try heldIssue(.laser(.beam), slot: .laser(.front))
    let old = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    let item = try #require(game.commander.equipmentInventory?.items.first { $0.id == id })
    try game.fitEquipment(
      item, at: .laser(.front), expectedRevision: game.commander.equipmentInventory!.revision)
    let before = game.commander
    let personal = try #require(game.commander.equipmentInventory?.items.first { $0.id == old.id })
    #expect(throws: EquipmentIssueError.foreignLoan(id)) {
      try game.fitEquipment(
        personal, at: .laser(.front), expectedRevision: game.commander.equipmentInventory!.revision)
    }
    #expect(throws: EquipmentIssueError.foreignLoan(id)) {
      try game.commander.grantEquipment(
        Equipment.navalLaser, at: .laser(.front), provenance: .xyzzy)
    }
    #expect(throws: EquipmentIssueError.foreignLoan(id)) {
      try game.commander.removeFittedEquipment(LaserKind.beam.equipmentName)
    }
    #expect(game.commander == before)
  }

  @Test func actualCommanderHullTransferKeepsHistoricalLoanEvidenceAndReturnsTheSamePersonalLaser()
    throws
  {
    var (game, mission, id) = try heldIssue(.laser(.beam), slot: .laser(.front))
    let personal = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    let loan = try #require(game.commander.equipmentInventory?.items.first { $0.id == id })
    try game.fitEquipment(
      loan, at: .laser(.front), expectedRevision: game.commander.equipmentInventory!.revision)
    let originalRecord = try #require(
      game.commander.scriptState.instances[mission]?.gearIssues["hardware"])
    let originalInventory = try #require(game.commander.equipmentInventory)
    let history = game.commander.equipmentPurchaseHistory
    let newHull = UUID()
    try game.commander.transferEquipment(to: "SH043", hullID: newHull)
    #expect(game.commander.equipmentInventory?.activeHull == newHull)
    #expect(game.commander.equipmentInventory?.revision == originalInventory.revision + 1)
    #expect(game.commander.scriptState.instances[mission]?.gearIssues["hardware"] == originalRecord)
    #expect(game.commander.fittedEquipment(at: .laser(.front))?.id == loan.id)
    #expect(game.commander.valid)

    var instance = try #require(game.commander.scriptState.instances[mission])
    var candidate = game.commander
    let event = try game.settleScriptGear(
      originalRecord, release: false, command: UUID(), state: &instance, candidate: &candidate)
    candidate.scriptState.instances[mission] = instance
    let restored = try #require(candidate.fittedEquipment(at: .laser(.front)))
    #expect(event.0 == "equipment.returned")
    #expect(restored.id == personal.id && restored.component == personal.component)
    #expect(restored.provenance == personal.provenance)
    #expect(restored.preferredSlot == personal.preferredSlot)
    #expect(restored.retainedLegacyState == personal.retainedLegacyState)
    #expect(restored.location == .init(hullInstanceID: newHull, slot: .laser(.front)))
    #expect(candidate.equipmentInventory?.items.contains { $0.id == loan.id } == false)
    #expect(candidate.scriptState.instances[mission]?.gearIssues["hardware"]?.status == .returned)
    #expect(
      candidate.scriptState.instances[mission]?.gearIssues["hardware"]?.displacements
        == originalRecord.displacements)
    #expect(candidate.equipmentPurchaseHistory == history && candidate.valid)
  }

  @Test func repeatedNativeLoanPreviewsPreserveAllCommanderAndContextState() throws {
    let (game, _, _) = try heldIssue(.missile, slot: .missilePylon(3))
    let commander = game.commander
    let epoch = game.inventoryContextEpoch
    let rows = game.inventoryInformationRows(width: 512)
    for _ in 0..<5 {
      let next = game.inventoryInformationRows(width: 512)
      #expect(next.map(\.text) == rows.map(\.text) && next.map(\.preview) == rows.map(\.preview))
      #expect(game.commander == commander && game.inventoryContextEpoch == epoch)
    }
  }
}
