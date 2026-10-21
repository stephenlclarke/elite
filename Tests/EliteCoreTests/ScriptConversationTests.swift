import Foundation
import Testing

@testable import EliteCore

private struct ConversationFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(source: String? = nil, observe: Bool = false, replacement: Bool = false) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-conversation-" + UUID().uuidString)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/station-conversation")
    let folder = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: example, to: folder)
    let file = folder.appendingPathComponent("scripts/main.lua")
    if let source { try source.write(to: file, atomically: true, encoding: .utf8) }
    if observe {
      let manifest = folder.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: manifest, encoding: .utf8)
      text += "\n[[handlers]]\nevent='dialogue.chosen'\nfunction='observed'\n"
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      let source = try String(contentsOf: file, encoding: .utf8)
      try source.replacingOccurrences(
        of: "return M",
        with: """
          function M.observed(e,w,d)
            assert(w.last_answer.sequence==e.answer_sequence)
            assert(w.last_answer.exclusive==false)
            assert(w.answers.decision[e.choice_id].last_sequence==e.answer_sequence)
            d.observed=(d.observed or 0)+1
            return {data=d,commands={{op='dialogue.offer',id='decision'}}}
          end
          return M
          """
      ).write(to: file, atomically: true, encoding: .utf8)
    }
    if replacement {
      let manifest = folder.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: manifest, encoding: .utf8)
      text = text.replacingOccurrences(
        of: "capabilities = [", with: "capabilities = [\"local-flight-clocks-v2\", ")
      text += """

        [[handlers]]
        event='timer.fired'
        function='changed'
        [[dialogs]]
        id='changed'
        text='A different question has replaced the previous one.'
        choices=[{id='new',label='A different answer'}]
        """
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      let source = try String(contentsOf: file, encoding: .utf8)
      try source.replacingOccurrences(
        of: "return M",
        with: """
          local accepted=M.accepted
          function M.accepted(e,w,d)
            local result=accepted(e,w,d)
            result.commands[#result.commands+1]={op='timer.ensure',id='replace',domain='local',after=0.1,interval=0,policy='once'}
            return result
          end
          local contact=M.contact
          function M.contact(e,w,d)
            if d.replaced then return {data=d,commands={{op='dialogue.offer',id='changed'}}} end
            return contact(e,w,d)
          end
          function M.changed(e,w,d)
            d.replaced=true
            return {data=d,commands={{op='dialogue.offer',id='changed'}}}
          end
          return M
          """
      ).write(to: file, atomically: true, encoding: .utf8)
    }
    pack = try ScriptPackLibrary.read(folder)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    return game
  }
  func open(_ runtime: GameRuntime) async throws -> UUID {
    await runtime.key("contacts-open")
    await runtime.key("return")
    let id = try #require(await runtime.snapshot().commander.scriptState.instances.keys.first)
    await runtime.key("contacts-open")
    #expect(await runtime.snapshot().scriptOffer == id)
    return id
  }
}

@Test func nativeRepeatableAnswersCanDeferTwiceReloadAskDetailsAndThenProceed() async throws {
  let fixture = try ConversationFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  let resources = await runtime.snapshot().commander
  let firstToken = await runtime.snapshot().commander.scriptState.instances[id]?.dialogue?.token
  await runtime.key("return")
  let first = await runtime.snapshot()
  #expect(first.screen == .handoff && first.scriptOffer == id)
  #expect(first.commander.scriptState.instances[id]?.dialogue?.token != firstToken)
  await runtime.key("return")
  let deferred = await runtime.snapshot()
  let originalReceipts = try #require(
    deferred.commander.scriptState.instances[id]?.conversationReceipts)
  #expect(
    originalReceipts.count == 2
      && originalReceipts.values.allSatisfy { $0.choice == "defer" && $0.group == nil })
  #expect(deferred.commander.scriptState.instances[id]?.choiceReceipts.isEmpty == true)
  #expect(
    deferred.commander.credits == resources.credits && deferred.commander.cargo == resources.cargo)
  await runtime.key("escape")
  let restored = GameRuntime(game: fixture.game())
  try await restored.load(from: fixture.save)
  await restored.key("contacts-open")
  await restored.key("down")
  await restored.key("return")
  let informed = await restored.snapshot()
  let state = try #require(informed.commander.scriptState.instances[id])
  let summary = informed.scriptAnswersSnapshot(state)
  #expect(summary["decision"]?["defer"]?["count"] == .integer(2))
  #expect(summary["decision"]?["details"]?["count"] == .integer(1))
  #expect(originalReceipts.allSatisfy { state.conversationReceipts[$0.key] == $0.value })
  await restored.key("down")
  await restored.key("down")
  await restored.key("return")
  let complete = await restored.snapshot()
  #expect(complete.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(complete.commander.scriptState.instances[id]?.conversationReceipts.count == 4)
  #expect(
    complete.commander.credits == resources.credits && complete.commander.cargo == resources.cargo)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(disk == complete.commander && disk.valid)
}

@Test func browsingHelpAndBackDoNotCreateNativeAnswersOrFinishTheQuestionMission() async throws {
  let fixture = try ConversationFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game())
  let id = try await fixture.open(runtime)
  let before = await runtime.snapshot().commander
  await runtime.key("down")
  await runtime.key("k")
  #expect(
    PlayerHelp.pages(for: await runtime.snapshot()).flatMap(\.rows).contains(
      "READING / BACK DOES NOT ANSWER"))
  await runtime.key("escape")
  await runtime.key("escape")
  #expect(await runtime.snapshot().commander == before)
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.conversationReceipts.isEmpty
      == true)
}

@Test func aNativeAnswerObserverSeesCommittedProofAndCanRefreshTheNextQuestion() async throws {
  let fixture = try ConversationFixture(observe: true)
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  await runtime.key("return")
  _ = await runtime.advance(delta: 0.1)
  let observed = await runtime.snapshot()
  #expect(observed.commander.scriptState.instances[id]?.data["observed"] == .integer(1))
  #expect(observed.screen == .handoff && observed.scriptOffer == id)
  await runtime.key("return")
  _ = await runtime.advance(delta: 0.1)
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.conversationReceipts.count == 2)
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.data["observed"] == .integer(2))
  #expect(await runtime.snapshot().commander.valid)
}

@Test func narrativeQuestionFlagsCannotSatisfyNativeAnswerRequirements() throws {
  let fixture = try ConversationFixture(
    source: """
      return {
        accepted=function(e,w,d) return {data={details=true,proceed=true},commands={
          {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}} end,
        contact=function(e,w,d) return {data=d,commands={}} end,
        confirm=function(e,w,d) return {data=d,commands={}} end
      }
      """)
  defer { fixture.clean() }
  var game = fixture.game()
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
  #expect(game.commander == before)
}

@Test func aFailedRepeatAnswerPublicationKeepsEveryEarlierReceiptAndRetriesOnlyTheNewAnswer()
  async throws
{
  let fixture = try ConversationFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  await runtime.key("return")
  let before = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.save)
  let container = fixture.save.deletingLastPathComponent()
  let backup = fixture.root.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: container, to: backup)
  try Data("blocked".utf8).write(to: container)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before.commander)
  try FileManager.default.removeItem(at: container)
  try FileManager.default.moveItem(at: backup, to: container)
  #expect(try Data(contentsOf: fixture.save) == pointer)
  await runtime.key("return")
  let after = await runtime.snapshot()
  #expect(after.commander.scriptState.instances[id]?.conversationReceipts.count == 2)
  let old = try #require(before.commander.scriptState.instances[id]?.conversationReceipts)
  #expect(
    old.allSatisfy {
      after.commander.scriptState.instances[id]?.conversationReceipts[$0.key] == $0.value
    })
  #expect(after.commander.valid)
}

@Test func conversationQuotaRefusesTheWholeNewAnswerWithoutTruncatingSavedHistory() async throws {
  let fixture = try ConversationFixture()
  defer { fixture.clean() }
  let initial = GameRuntime(game: fixture.game())
  let id = try await fixture.open(initial)
  await initial.key("return")
  _ = await initial.advance(delta: 0.1)
  var game = await initial.snapshot()
  let first = try #require(
    game.commander.scriptState.instances[id]?.conversationReceipts.values.first)
  // Synthetic admitted-save boundary fixture; gameplay/ordering acceptance uses actual confirmations above.
  var records = [first.sequence: first]
  for index in 0..<1024 {
    let sequence = UInt64(index + 5)
    records[sequence] = ScriptChoiceReceipt(
      instance: first.instance, group: nil, choice: first.choice, label: first.label,
      dialogue: first.dialogue, sequence: sequence, revision: first.revision,
      cause: first.cause, committed: first.committed)
  }
  game.commander.scriptState.nextEvent = 1028
  game.commander.scriptState.instances[id]?.acknowledgedThrough = 1028
  game.commander.scriptState.instances[id]?.conversationReceipts = records
  #expect(!game.commander.valid)
  records.removeValue(forKey: 1028)
  game.commander.scriptState.instances[id]?.conversationReceipts = records
  #expect(game.commander.valid)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let pointer = try Data(contentsOf: fixture.save)
  var oversized = game
  oversized.commander.scriptState.instances[id]?.conversationReceipts[1028] = ScriptChoiceReceipt(
    instance: first.instance, group: nil, choice: first.choice, label: first.label,
    dialogue: first.dialogue, sequence: 1028, revision: first.revision,
    cause: first.cause, committed: first.committed)
  #expect(throws: SaveError.self) {
    try ScriptSaveStore.write(
      commander: oversized.commander, world: oversized.scriptWorldSave, to: fixture.save)
  }
  #expect(try Data(contentsOf: fixture.save) == pointer)
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander.scriptState.instances[id]?.suspension != nil)
  #expect(denied.commander.scriptState.instances[id]?.conversationReceipts == records)
  #expect(denied.commander.valid)
}

@Test func invalidConversationDeclarationsAndAnswerReferencesFailBeforeInstallation() throws {
  let fixture = try ConversationFixture()
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("pack")
  let file = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: file, encoding: .utf8)
  for (before, after) in [
    ("\"dialogue-choices-v2\", ", ""),
    ("minimumCount = 1", "minimumCount = 0"),
    ("minimumCount = 1", "minimumCount = 1025"),
    ("dialogue = \"decision\"", "dialogue = \"invented\""),
    ("choice = \"details\"", "choice = \"invented\""),
    ("minimumCount = 1", "minimumCount = 1\ninvented = 1"),
  ] {
    try original.replacingOccurrences(of: before, with: after).write(
      to: file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
}

@Test func anAutonomousReplacementCannotTurnTheDisplayedAnswerIntoADifferentConfirmation()
  async throws
{
  let fixture = try ConversationFixture(replacement: true)
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.open(runtime)
  let shown = await runtime.snapshot()
  #expect(shown.scriptPresentedDialogue?.id == "decision")
  let changed = await runtime.advance(delta: 0.1)
  #expect(changed.commander.scriptState.instances[id]?.dialogue?.id == "changed")
  #expect(
    changed.scriptPresentedDialogue == shown.scriptPresentedDialogue && changed.scriptDialogueStale)
  #expect(changed.selectedScriptChoice?.id == "defer")
  #expect(changed.offeredScriptText?.contains("Choose Defer") == true)
  #expect(
    Display.presentation(changed, width: 512, height: 518).labels.contains {
      $0.text.contains("Contact changed")
    })
  await runtime.key("return")
  let refused = await runtime.snapshot()
  #expect(refused.commander == changed.commander && refused.scriptOffer == nil)
  #expect(refused.commander.scriptState.instances[id]?.conversationReceipts.isEmpty == true)
  await runtime.key("contacts-open")
  let reopened = await runtime.snapshot()
  #expect(
    reopened.scriptPresentedDialogue?.id == "changed" && reopened.selectedScriptChoice?.id == "new")
  #expect(!reopened.scriptDialogueStale && reopened.commander.valid)
}
