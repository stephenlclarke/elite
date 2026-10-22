import Foundation
import Testing

@testable import EliteCore

/// The existing equipment issue boundary, not a native Lerr authorization or fabricated receipt.
private func programmerIssueFixture() throws -> (Game, ScriptInstance) {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  let parent = ScriptInstance(
    id: UUID(), definition: "fixture/programmer-issue", version: "1.0.0",
    digest: String(repeating: "a", count: 64))
  game.commander.scriptState.instances[parent.id] = parent
  return (game, parent)
}

private func issueProgrammer(_ game: inout Game, parent: inout ScriptInstance) throws {
  var candidate = game.commander
  _ = try game.issueScriptGear(
    NativeIsolationProgrammerDefinition.gear, fields: ["fit": .bool(false)],
    command: UUID(), state: &parent, candidate: &candidate)
  candidate.scriptState.instances[parent.id] = parent
  game.commander = candidate
}

struct NativeIsolationProgrammerUnitTests {
  @Test func actualCanonicalLoanOccupiesOneTonneAndReturnRemovesOnlyTheOriginal() throws {
    var (game, parent) = try programmerIssueFixture()
    let before = game.commander
    let originalItems = try #require(before.equipmentInventory?.items)
    let mass = before.cargoTonnes
    try issueProgrammer(&game, parent: &parent)
    let record = try #require(parent.gearIssues[NativeIsolationProgrammerDefinition.resource])
    let serial = NativeIsolationProgrammerDefinition.serial(parent: parent.id)
    #expect(record.items == [serial] && record.loan && !record.returnRemaining)
    #expect(record.obligation?.status == .issued && record.consumed.isEmpty)
    #expect(game.commander.cargoTonnes == mass + 1)
    #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
    let item = try #require(game.commander.equipmentInventory?.items.first { $0.id == serial })
    #expect(item.node == NativeIsolationProgrammerDefinition.node && item.location == nil)
    #expect(item.component == nil)
    let binding = try NativeIsolationProgrammerCustody.resolve(
      parent: parent, commander: game.commander)
    #expect(binding.serial == serial && binding.owner == before.equipmentOwnerID)
    #expect(binding.hull == before.hullInstanceID)
    #expect(NativeIsolationProgrammerCustody.hasIssuedOriginal(in: game.commander))
    let restored = try JSONDecoder().decode(
      Commander.self, from: JSONEncoder().encode(game.commander))
    #expect(
      try NativeIsolationProgrammerCustody.resolve(parent: parent, commander: restored) == binding)
    let issued = game.commander
    try issueProgrammer(&game, parent: &parent)
    #expect(game.commander == issued)
    var candidate = game.commander
    _ = try game.settleScriptGear(
      record, release: false, command: UUID(), state: &parent, candidate: &candidate)
    candidate.scriptState.instances[parent.id] = parent
    #expect(candidate.cargoTonnes == mass && candidate.equipmentInventory?.items == originalItems)
    #expect(parent.gearIssues[NativeIsolationProgrammerDefinition.resource]?.status == .returned)
    #expect(candidate.credits == before.credits && candidate.cargo == before.cargo)
    #expect(candidate.valid)
    #expect(NativeIsolationProgrammerCustody.hasIssuedOriginal(in: candidate))
    #expect(throws: NativeIsolationProgrammerError.unavailableOriginal) {
      _ = try NativeIsolationProgrammerCustody.resolve(parent: parent, commander: candidate)
    }
  }

  @Test func fullRealHoldRefusesBeforeCreatingProgrammerOrObligation() throws {
    var (game, parent) = try programmerIssueFixture()
    game.commander.cargo[0] = game.commander.standardCargoCapacity
    let before = game.commander
    #expect(throws: (any Error).self) { try issueProgrammer(&game, parent: &parent) }
    #expect(game.commander == before && parent.gearIssues.isEmpty)
  }

  @Test func matchingLabelForeignSerialOrChangedSourceCannotSupplyOriginalCustody() throws {
    var (game, parent) = try programmerIssueFixture()
    try issueProgrammer(&game, parent: &parent)
    let before = game.commander
    let inventory = try #require(before.equipmentInventory)
    let serial = NativeIsolationProgrammerDefinition.serial(parent: parent.id)
    let original = try #require(inventory.items.first { $0.id == serial })
    let substitute = OwnedEquipmentItem(
      id: UUID(), node: original.node, provenance: original.provenance)
    var changed = before
    changed.savedEquipmentInventory = try .init(
      owner: inventory.owner, activeHull: inventory.activeHull,
      revision: inventory.revision,
      items: inventory.items.map { $0.id == serial ? substitute : $0 })
    #expect(changed.cargoTonnes == before.cargoTonnes)
    #expect(throws: NativeIsolationProgrammerError.unavailableOriginal) {
      _ = try NativeIsolationProgrammerCustody.resolve(parent: parent, commander: changed)
    }
    var foreign = ScriptInstance(
      id: parent.id, definition: parent.definition, version: parent.version,
      digest: String(repeating: "b", count: 64))
    foreign.gearIssues = parent.gearIssues
    #expect(throws: NativeIsolationProgrammerError.unavailableOriginal) {
      _ = try NativeIsolationProgrammerCustody.resolve(parent: foreign, commander: before)
    }
    #expect(game.commander == before)
  }

  @Test func acquisitionOnlyDefinitionHasNoFittingOrShopOffer() throws {
    let definition = NativeIsolationProgrammerDefinition.gear
    #expect(definition.valid && definition.quantity == 1 && definition.loan)
    #expect(definition.returnPolicy == "all" && definition.mount == nil)
    #expect(NativeIsolationProgrammerDefinition.purchaseNode.policy == .acquisitionOnly)
    #expect(EquipmentRuntimeCatalog.slot(for: NativeIsolationProgrammerDefinition.node) == nil)
    #expect(!Equipment.all.contains { $0.name == definition.name })
    #expect(!Equipment.maximumHardware.contains(definition.name))
    #expect(NativeIsolationProgrammerDefinition.location == .init(galaxy: 0, system: 7))
    let fixture = try GearScriptFixture(
      name: definition.name,
      accepted: "{op='gear.issue',id='forged-programmer',gear='kit',fit=false}")
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [fixture.pack]
    let before = game.commander
    #expect(throws: MissionPackError.self) { _ = try game.acceptScriptMission(fixture.pack) }
    #expect(game.commander == before)
    #expect(
      NativeIsolationProgrammerDefinition.occupiedTonnes(in: game.commander.equipmentInventory) == 0
    )
    let owner = UUID()
    #expect(
      NativeIsolationProgrammerDefinition.issuer(owner: owner)
        == NativeIsolationProgrammerDefinition.issuer(owner: owner))
    #expect(
      NativeIsolationProgrammerDefinition.issuer(owner: owner)
        != NativeIsolationProgrammerDefinition.issuer(owner: UUID()))
  }
}
