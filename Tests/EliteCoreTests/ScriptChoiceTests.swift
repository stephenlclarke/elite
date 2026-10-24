import Foundation
import Testing

@testable import EliteCore

private struct ChoiceFixture {
  let root: URL
  let parent: ScriptPack
  let patrol: ScriptPack
  let courier: ScriptPack
  var container: URL { root.appendingPathComponent("save") }
  var save: URL { container.appendingPathComponent("commander.json") }
  init(source: String? = nil, edits: [(String, String)] = [], plain: Bool = false) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-choice-" + UUID().uuidString)
    let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let folder = root.appendingPathComponent("parent")
    try FileManager.default.copyItem(
      at: examples.appendingPathComponent("branch-choice"), to: folder)
    let manifest = folder.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
    if plain {
      text = text.replacingOccurrences(
        of: "(?s)choices = \\[.*?\\]", with: "",
        options: .regularExpression)
      text = text.replacingOccurrences(
        of: "requiredChoiceGroups = [\"assignment\"]", with: "requiredChoiceGroups = []")
    }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    if let source {
      try source.write(
        to: folder.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    }
    parent = try ScriptPackLibrary.read(folder)
    patrol = try ScriptPackLibrary.read(examples.appendingPathComponent("branch-patrol"))
    courier = try ScriptPackLibrary.read(examples.appendingPathComponent("branch-courier"))
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [parent, patrol, courier]
    return game
  }
  func open(_ runtime: GameRuntime) async throws -> UUID {
    await runtime.key("contacts-open")
    await runtime.key("return")
    let id = try #require(
      await runtime.snapshot().commander.scriptState.instances.values.first {
        $0.definition == parent.manifest.stateID
      }?.id)
    await runtime.key("contacts-open")
    #expect(await runtime.snapshot().scriptOffer == id)
    return id
  }
}

@Test func actualStationChoiceUnlocksOnlyItsMatchingFollowupAndSurvivesReload() async throws {
  let fixture = try ChoiceFixture()
  defer { fixture.clean() }
  #expect(fixture.patrol.manifest.receiptRequirements?.first?.digest == fixture.parent.digest)
  #expect(fixture.courier.manifest.receiptRequirements?.first?.digest == fixture.parent.digest)
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  let before = await runtime.snapshot()
  await runtime.key("down")
  let selecting = await runtime.snapshot()
  #expect(selecting.selectedScriptChoice?.id == "courier")
  #expect(selecting.commander == before.commander)
  await runtime.key("escape")
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.choiceReceipts.isEmpty == true)
  await runtime.key("contacts-open")
  await runtime.key("down")
  await runtime.key("return")
  let chosen = await runtime.snapshot()
  let receipt = try #require(
    chosen.commander.scriptState.instances[id]?.choiceReceipts["assignment"])
  #expect(receipt.choice == "courier" && receipt.committed.mainStation)
  #expect(
    chosen.commander.scriptState.instances[id]?.completionReceipt?.choices?["assignment"] == receipt
  )
  #expect(chosen.commander.credits == before.commander.credits)
  var attempt = chosen
  #expect(throws: MissionPackError.self) { try attempt.acceptScriptMission(fixture.patrol) }
  let restored = GameRuntime(game: fixture.game())
  try await restored.load(from: fixture.save)
  await restored.key("contacts-open")
  #expect(await restored.snapshot().scriptAvailablePackDigest == fixture.courier.digest)
  await restored.key("return")
  let working = await restored.snapshot()
  let child = try #require(
    working.commander.scriptState.instances.values.first {
      $0.definition == fixture.courier.manifest.stateID
    })
  #expect(child.receiptJoins?["chosen-assignment"] == [id] && working.commander.cargoTonnes == 1)
  #expect(working.commander.scriptState.instances[id]?.choiceReceipts["assignment"] == receipt)
  #expect(working.commander.valid)
}

@Test func failedChoicePublicationRetainsTheUncommittedSelectionForOneRealRetry() async throws {
  let fixture = try ChoiceFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  await runtime.key("down")
  let before = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.save)
  let backup = fixture.root.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: fixture.container, to: backup)
  try Data("blocked".utf8).write(to: fixture.container)
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.selectedScriptChoice?.id == "courier")
  #expect(denied.commander.scriptState.instances[id]?.choiceReceipts.isEmpty == true)
  try FileManager.default.removeItem(at: fixture.container)
  try FileManager.default.moveItem(at: backup, to: fixture.container)
  #expect(try Data(contentsOf: fixture.save) == pointer)
  await runtime.key("return")
  let chosen = await runtime.snapshot()
  #expect(
    chosen.commander.scriptState.instances[id]?.choiceReceipts["assignment"]?.choice == "courier")
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(disk == chosen.commander)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == chosen.commander)
}

@Test func nativeChoiceButtonsAndBackOnlyBrowseUntilExplicitConfirmation() async throws {
  let fixture = try ChoiceFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game())
  let id = try await fixture.open(runtime)
  let before = await runtime.snapshot()
  await runtime.blackjackHandoffClick(
    x: before.viewportWidth * 0.75, y: before.viewportHeight - 120)
  #expect(await runtime.snapshot().selectedScriptChoice?.id == "courier")
  await runtime.blackjackHandoffClick(
    x: before.viewportWidth * 0.25, y: before.viewportHeight - 120)
  #expect(await runtime.snapshot().selectedScriptChoice?.id == "patrol")
  await runtime.key("up")
  #expect(await runtime.snapshot().selectedScriptChoice?.id == "courier")
  await runtime.key("k")
  let help = await runtime.snapshot()
  #expect(PlayerHelp.pages(for: help).flatMap(\.rows).contains("UP / DOWN - BROWSE CHOICES"))
  #expect(
    PlayerHelp.pages(for: help).flatMap(\.rows).contains("LEFT / RIGHT - CHOOSE CONFIRM / BACK"))
  #expect(
    PlayerHelp.pages(for: help).flatMap(\.rows).contains("READING / BACK DOES NOT CHOOSE A BRANCH"))
  await runtime.key("escape")
  #expect(await runtime.snapshot().selectedScriptChoice?.id == "courier")
  await runtime.key("left")
  await runtime.key("return")
  #expect(await runtime.snapshot().screen != .handoff)
  #expect(await runtime.snapshot().commander == before.commander)
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.choiceReceipts.isEmpty == true)
}

private let counterfeitChoice = """
  return {
    accepted=function(e,w,d) return {data=d,commands={}} end,
    contact=function(e,w,d) return {data=d,commands={{op='dialogue.offer',id='assignment'}}} end,
    confirm=function(e,w,d)
      d.claimed='patrol'
      return {data=d,commands={{op='credits',id='fake-pay',amount=500},
        {op='dialogue.commit',id='assignment',token=e.token,choice_id='patrol'},
        {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}}
    end
  }
  """

@Test(arguments: [false, true])
func aScriptCannotReplaceThePlayersConfirmedBranchOrKeepAnEarlierProposedReward(plain: Bool)
  async throws
{
  let fixture = try ChoiceFixture(
    source: counterfeitChoice,
    edits: [
      ("capabilities = [", "capabilities = [\"economy-v2\", ")
    ], plain: plain)
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  let dialogue = await runtime.snapshot()
  let helpRows = PlayerHelp.pages(for: dialogue).flatMap(\.rows)
  #expect(
    helpRows.contains(
      plain ? "ARROWS - CHOOSE CONFIRM / BACK" : "UP / DOWN - BROWSE CHOICES"))
  #expect(helpRows.contains("UP / DOWN - BROWSE CHOICES") == !plain)
  if !plain { await runtime.key("down") }
  let balance = await runtime.snapshot().commander.credits
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander.scriptState.instances[id]?.suspension != nil)
  #expect(denied.commander.scriptState.instances[id]?.choiceReceipts.isEmpty == true)
  #expect(denied.commander.scriptState.instances[id]?.completionReceipt == nil)
  #expect(denied.commander.scriptState.instances[id]?.data["claimed"] == nil)
  #expect(denied.commander.credits == balance && denied.commander.valid)
}

@Test func narrativeFlagsCannotSatisfyADeclaredNativeChoiceCompletionGate() throws {
  let source = """
    return {
      accepted=function(e,w,d) return {data={chosen='courier'},commands={
        {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}} end,
      contact=function(e,w,d) return {data=d,commands={}} end,
      confirm=function(e,w,d) return {data=d,commands={}} end
    }
    """
  let fixture = try ChoiceFixture(source: source)
  defer { fixture.clean() }
  var game = fixture.game()
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.parent) }
  #expect(game.commander == before)
}

@Test func anActiveChoiceRemainsExclusiveAndEmitsOneNativeChosenFact() async throws {
  let source = """
    return {
      accepted=function(e,w,d) return {data={facts=0},commands={}} end,
      contact=function(e,w,d) return {data=d,commands={{op='dialogue.offer',id='assignment'}}} end,
      confirm=function(e,w,d) return {data=d,commands={
        {op='dialogue.commit',id='assignment',token=e.token,choice_id=e.choice_id}}} end,
      chosen=function(e,w,d)
        assert(w.choices.assignment.choice_id==e.choice_id)
        d.facts=d.facts+1
        return {data=d,commands={}}
      end
    }
    """
  let fixture = try ChoiceFixture(
    source: source,
    edits: [
      ("[[dialogs]]", "[[handlers]]\nevent='dialogue.chosen'\nfunction='chosen'\n\n[[dialogs]]")
    ])
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  await runtime.key("return")
  _ = await runtime.advance(delta: 0.1)
  let chosen = await runtime.snapshot()
  let receipt = try #require(
    chosen.commander.scriptState.instances[id]?.choiceReceipts["assignment"])
  #expect(
    receipt.choice == "patrol"
      && chosen.commander.scriptState.instances[id]?.data["facts"] == .integer(1))
  await runtime.key("contacts-open")
  let denied = await runtime.snapshot()
  #expect(denied.commander.scriptState.instances[id]?.suspension != nil)
  #expect(denied.commander.scriptState.instances[id]?.choiceReceipts["assignment"] == receipt)
  #expect(denied.commander.valid)
}

@Test func malformedChoiceDeclarationsCannotInstallOrWeakenReceiptFilters() throws {
  let fixture = try ChoiceFixture()
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("parent")
  let manifest = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  for (before, after) in [
    ("id=\"courier\"", "id=\"patrol\""),
    ("group=\"assignment\"}", "group=\"other\"}"),
    ("requiredChoiceGroups = [\"assignment\"]", "requiredChoiceGroups = [\"invented\"]"),
    ("\"exclusive-choices-v2\", ", ""),
    ("group=\"assignment\"", "group=\"assignment\", invented=1"),
    ("label=\"Patrol: defeat the two assigned raiders near Lave\"", "label=\"\""),
  ] {
    try original.replacingOccurrences(of: before, with: after)
      .write(to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
  let child = fixture.root.appendingPathComponent("child")
  let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs")
  try FileManager.default.copyItem(at: examples.appendingPathComponent("branch-courier"), to: child)
  let childManifest = child.appendingPathComponent("manifest.toml")
  let text = try String(contentsOf: childManifest, encoding: .utf8)
  try text.replacingOccurrences(of: "choice = \"courier\"", with: "")
    .write(to: childManifest, atomically: true, encoding: .utf8)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(child) }
}

@Test func missingNativeChoiceProvenanceCannotReplaceAnActiveBranchReceipt() async throws {
  let source = """
    return {
      accepted=function(e,w,d) return {data=d,commands={}} end,
      contact=function(e,w,d) return {data=d,commands={{op='dialogue.offer',id='assignment'}}} end,
      confirm=function(e,w,d) return {data=d,commands={
        {op='dialogue.commit',id='assignment',token=e.token,choice_id=e.choice_id}}} end
    }
    """
  let fixture = try ChoiceFixture(source: source)
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  await runtime.key("return")
  let original = await runtime.snapshot()
  let receipt = try #require(
    original.commander.scriptState.instances[id]?.choiceReceipts["assignment"])
  var fields = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
  fields.removeValue(forKey: "cause")
  let unknown = try JSONDecoder().decode(
    ScriptChoiceReceipt.self, from: JSONSerialization.data(withJSONObject: fields))
  var changed = original
  changed.commander.scriptState.instances[id]?.choiceReceipts["assignment"] = unknown
  let pointer = try Data(contentsOf: fixture.save)
  #expect(!changed.commander.valid)
  #expect(throws: SaveError.self) {
    try ScriptSaveStore.write(
      commander: changed.commander, world: changed.scriptWorldSave, to: fixture.save)
  }
  #expect(try Data(contentsOf: fixture.save) == pointer)
}
