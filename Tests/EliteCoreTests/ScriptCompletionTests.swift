import Foundation
import Testing

@testable import EliteCore

private struct CompletionFixture {
  let root: URL
  let child: ScriptPack
  let parent: ScriptPack
  init(
    stage: String = "completion", digest: String? = nil, outcome: String = "complete",
    allowedOutcomes: [String]? = nil, childID: String? = nil, failedChild: Bool = false
  ) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-completion-" + UUID().uuidString)
    let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    var childFolder = examples.appendingPathComponent("scripted-patrol")
    if childID != nil || failedChild {
      let local = root.appendingPathComponent("child")
      try FileManager.default.copyItem(at: childFolder, to: local)
      if let childID {
        let file = local.appendingPathComponent("manifest.toml")
        let text = try String(contentsOf: file, encoding: .utf8)
        try text.replacingOccurrences(of: "example.scripted-patrol", with: childID)
          .write(to: file, atomically: true, encoding: .utf8)
      }
      if failedChild {
        let file = local.appendingPathComponent("scripts/main.lua")
        let text = try String(contentsOf: file, encoding: .utf8)
        try text.replacingOccurrences(of: "outcome='complete'", with: "outcome='failed'")
          .replacingOccurrences(of: "amount=1000", with: "amount=0")
          .replacingOccurrences(
            of: "Paid 100 credits.", with: "Recorded failed report without payment."
          )
          .write(to: file, atomically: true, encoding: .utf8)
      }
      childFolder = local
    }
    child = try ScriptPackLibrary.read(childFolder)
    let outcomeRule =
      allowedOutcomes.map {
        "outcomes=[" + $0.map { "\"" + $0 + "\"" }.joined(separator: ",") + "]"
      } ?? "outcome=\"\(outcome)\""
    let folder = root.appendingPathComponent("parent")
    try FileManager.default.copyItem(
      at: examples.appendingPathComponent("scripted-courier"), to: folder)
    try """
    schemaVersion=2
    missionAPI=2
    id="test.receipt-parent"
    version="1.0.0"
    minimumEngine="2.0.0"
    capabilities=["script-lua-v1","story-v2","economy-v2","completion-receipts-v2"\(allowedOutcomes == nil ? "" : ",\"compound-receipts-v2\"")]
    priority=700
    source="Original linked mission test."
    license="MIT"
    environments=["space","orbital-station"]
    module="scripts/main.lua"
    [mission]
    id="report"
    title="Linked patrol report"
    briefing="Report after the actual patrol is complete."
    destination="Lave orbital station"
    reward="10 credits"
    milestones=["Report"]
    [[receiptRequirements]]
    id="patrol"
    stage="\(stage)"
    definition="\(child.manifest.stateID)"
    version="\(child.manifest.version)"
    digest="\(digest ?? child.digest)"
    \(outcomeRule)
    minimumCount=1
    [[handlers]]
    event="mission.accepted"
    function="accepted"
    [[handlers]]
    event="contact.requested"
    function="contact"
    [[handlers]]
    event="mission.receipted"
    function="receipted"
    """.write(to: folder.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
    try """
    return {
      accepted=function(e,w,d) return {data={notifications=0},commands={}} end,
      contact=function(e,w,d)
        d.attempted=true
        return {data=d,commands={{op='credits',id='pay',amount=100},
          {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}}
      end,
      receipted=function(e,w,d)
        d.notifications=d.notifications+1
        d.child=e.receipt_instance_id
        d.proof=w.receipt_requirements.patrol.satisfied
        return {data=d,commands={}}
      end
    }
    """.write(
      to: folder.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    parent = try ScriptPackLibrary.read(folder)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.installTargetingComputer(.docking)
    game.scriptPacks = [child, parent]
    return game
  }
  func completePatrol(_ game: inout Game, report: Bool = true, expected: ScriptOutcome = .complete)
    throws -> UUID
  {
    game.commander.installTargetingComputer(.docking)
    let id = try game.acceptScriptMission(child)
    game.launch()
    game.emitScriptEvent("station.undocked")
    var firing = Controls()
    firing.fire = true
    for _ in 0..<200 {
      game.tick(delta: 0.1, controls: firing)
      if game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == true {
        break
      }
    }
    #expect(game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == true)
    for _ in 0..<8 {
      game.key("r")
      if game.autoPilot.targetID == 0 { break }
    }
    for _ in 0..<5000 where !game.docked { game.tick(delta: 0.02) }
    #expect(game.docked && game.dockedAtMainStation)
    if !report { return id }
    game.emitScriptEvent("contact.requested", only: id)
    let offered = game.showScriptDialogue()
    #expect(offered && game.scriptOffer == id)
    game.confirmScriptDialogue()
    #expect(game.commander.scriptState.instances[id]?.outcome == expected)
    return id
  }
}

@Test func actualPatrolCompletionJoinsParentOnceAcrossNativeSaveAndReload() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parent)
  let child = try fixture.completePatrol(&game)
  game.drainScriptEvents()
  let proof = try #require(game.commander.scriptState.instances[child]?.completionReceipt)
  #expect(proof.destroyedEncounters == ["raiders"] && proof.causeKind == "dialogue.confirmed")
  #expect(proof.committed.mainStation && proof.committed.system == 7)
  #expect(proof.outcome == .complete && proof.milestones == [0, 1, 2])
  #expect(game.commander.scriptState.instances[parent]?.data["notifications"] == .integer(1))
  #expect(game.commander.scriptState.instances[parent]?.data["proof"] == .bool(true))
  let balance = game.commander.credits
  let runtime = GameRuntime(game: game)
  let save = fixture.root.appendingPathComponent("save/commander.json")
  try await runtime.save(to: save)
  let loaded = GameRuntime(game: fixture.game())
  try await loaded.load(from: save)
  await loaded.key("contacts-open")
  let finished = await loaded.snapshot()
  #expect(finished.commander.scriptState.instances[parent]?.outcome == .complete)
  #expect(finished.commander.scriptState.instances[parent]?.receiptJoins?["patrol"] == [child])
  #expect(finished.commander.credits == balance + 100)
  #expect(finished.commander.scriptState.instances[child]?.completionReceipt == proof)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
  #expect(disk == finished.commander)
  await loaded.key("contacts-open")
  #expect(await loaded.snapshot().commander.credits == balance + 100)
}

@Test func installedChildFlagsAndCounterfeitDeathEventsCannotMintCompletionProof() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parent)
  let child = try game.acceptScriptMission(fixture.child)
  game.commander.scriptState.instances[child]?.data = .object(["complete": .bool(true)])
  game.emitScriptEvent("actor.destroyed", values: ["encounter_id": .string("raiders")], only: child)
  let balance = game.commander.credits
  game.emitScriptEvent("contact.requested", only: parent)
  let state = try #require(game.commander.scriptState.instances[parent])
  #expect(state.outcome == .active && state.suspension != nil && state.completionReceipt == nil)
  #expect(state.data["attempted"] == nil && state.milestones.isEmpty && state.receipts.isEmpty)
  #expect(game.commander.credits == balance && game.commander.valid)
}

@Test func exactContentAndOutcomeReceiptGatesBlockAcceptanceEvenWhenInstalled() throws {
  let fixture = try CompletionFixture(stage: "acceptance")
  let otherDigest = try CompletionFixture(
    stage: "acceptance", digest: String(repeating: "a", count: 64))
  let wrongOutcome = try CompletionFixture(stage: "acceptance", outcome: "failed")
  defer {
    fixture.clean()
    otherDigest.clean()
    wrongOutcome.clean()
  }
  var game = fixture.game()
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.parent) }
  #expect(game.commander == before)
  let child = try fixture.completePatrol(&game)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(otherDigest.parent) }
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(wrongOutcome.parent) }
  let parent = try game.acceptScriptMission(fixture.parent)
  #expect(game.commander.scriptState.instances[parent]?.receiptJoins?["patrol"] == [child])
  game.emitScriptEvent("contact.requested", only: parent)
  #expect(game.commander.scriptState.instances[parent]?.outcome == .complete)
  #expect(game.commander.scriptState.instances[parent]?.receiptJoins?["patrol"] == [child])
  #expect(game.commander.valid)
}

@Test func terminalLegacyFlagsAreNeverMigratedIntoNativeReceipts() throws {
  let fixture = try CompletionFixture(stage: "acceptance")
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try game.acceptScriptMission(fixture.child)
  game.commander.scriptState.instances[child]?.outcome = .complete
  game.commander.scriptState.instances[child]?.milestones = [0, 1, 2]
  let data = try ScriptValueStorage.encoder().encode(game.commander.scriptState)
  game.commander.scriptState = try ScriptValueStorage.decoder(typed: true).decode(
    ScriptEngineState.self, from: data)
  #expect(game.commander.scriptState.instances[child]?.completionReceipt == nil)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.parent) }
}

@Test func failedNativeReportPublicationCreatesNeitherPaymentNorChildReceipt() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game, report: false)
  let container = fixture.root.appendingPathComponent("save")
  let save = container.appendingPathComponent("commander.json")
  let backup = fixture.root.appendingPathComponent("backup")
  let runtime = GameRuntime(game: game, saveURL: save)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot()
  let pointer = try Data(contentsOf: save)
  try FileManager.default.moveItem(at: container, to: backup)
  try Data("blocked".utf8).write(to: container)
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.scriptOffer == child)
  #expect(denied.commander.scriptState.instances[child]?.completionReceipt == nil)
  try FileManager.default.removeItem(at: container)
  try FileManager.default.moveItem(at: backup, to: container)
  #expect(try Data(contentsOf: save) == pointer)
  await runtime.key("return")
  let completed = await runtime.snapshot()
  #expect(completed.commander.scriptState.instances[child]?.completionReceipt != nil)
  #expect(completed.commander.credits == before.commander.credits + 1000)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
  #expect(disk == completed.commander)
}

@Test func delayedNativeReportRetainsCauseTimeSeparatelyFromCompletionCommitTime() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game, report: false)
  game.emitScriptEvent("contact.requested", only: child)
  let offered = game.showScriptDialogue()
  #expect(offered)
  game.scriptEventsDeferred = true
  game.confirmScriptDialogue()
  let event = try #require(
    game.commander.scriptState.pendingEvents.first {
      $0.instance == child && $0.kind == "dialogue.confirmed"
    })
  let cause = try #require(event.context)
  for _ in 0..<100 {
    let advanced = game.advanceScriptClockValues(
      delta: 0.1, flight: false, local: true, calendar: true)
    #expect(advanced)
  }
  game.scriptEventsDeferred = false
  game.drainScriptEvents()
  let receipt = try #require(game.commander.scriptState.instances[child]?.completionReceipt)
  #expect(receipt.cause == cause && receipt.sequence == event.sequence)
  #expect(abs(receipt.committed.localSeconds - cause.localSeconds - 10) < 1e-8)
  #expect(abs(receipt.committed.calendarSeconds - cause.calendarSeconds - 10) < 1e-8)
  #expect(game.commander.valid)
}

@Test func inconsistentCompletionProofAndSelfJoinsCannotReplaceThePriorSave() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game)
  let save = fixture.root.appendingPathComponent("save/commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  let pointer = try Data(contentsOf: save)
  let receipt = try #require(game.commander.scriptState.instances[child]?.completionReceipt)
  let original = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
  for (key, value) in [
    ("digest", String(repeating: "a", count: 64) as Any),
    ("outcome", "failed" as Any), ("sequence", 0 as Any), ("revision", 0 as Any),
    ("causeKind", "invented.death" as Any), ("destroyedEncounters", ["invented"] as Any),
  ] {
    var fields = original
    fields[key] = value
    let invalid = try JSONDecoder().decode(
      ScriptCompletionReceipt.self, from: JSONSerialization.data(withJSONObject: fields))
    var candidate = game
    candidate.commander.scriptState.instances[child]?.completionReceipt = invalid
    #expect(!candidate.commander.valid)
    #expect(throws: SaveError.self) {
      try ScriptSaveStore.write(
        commander: candidate.commander, world: candidate.scriptWorldSave, to: save)
    }
    #expect(try Data(contentsOf: save) == pointer)
  }
  game.commander.scriptState.instances[child]?.receiptJoins = ["self": [child]]
  #expect(!game.commander.valid)
}

@Test func optionalLinkedPatrolExampleUsesActualReceiptsInAnIsolatedGalleryTrial() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/linked-patrol")
  let parent = try ScriptPackLibrary.read(example)
  #expect(parent.missingCapabilities.isEmpty)
  #expect(parent.manifest.receiptRequirements?.first?.digest == fixture.child.digest)
  var live = fixture.game()
  live.scriptPacks = [fixture.child, parent]
  let owner = GameRuntime(game: live)
  let original = await owner.snapshot()
  let trial = try await owner.scriptGalleryTrial(packDigest: parent.digest)
  let directory = try #require(await trial.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: directory) }
  let initial = await trial.snapshot()
  let parentID = try #require(initial.commander.scriptState.instances.keys.first)
  #expect(initial.commander.scriptState.instances[parentID]?.completionReceipt == nil)
  // Test hardware setup; every objective still goes through actual player controls and physics.
  await trial.nativeCommand { $0.commander.installTargetingComputer(.docking) }
  await trial.key("contacts-open")
  await trial.key("return")
  let child = try #require(
    await trial.snapshot().commander.scriptState.instances.values.first {
      $0.definition == fixture.child.manifest.stateID
    }?.id)
  await trial.key("0")
  var firing = Controls()
  firing.fire = true
  await trial.setControls(firing)
  for _ in 0..<200 {
    let battle = await trial.advance(delta: 0.1)
    if battle.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed == true
    {
      break
    }
  }
  #expect(
    await trial.snapshot().commander.scriptState.instances[child]?.ownedEncounters["raiders"]?
      .destroyed == true)
  await trial.setControls(Controls())
  for _ in 0..<8 {
    await trial.key("r")
    if await trial.snapshot().autoPilot.targetID == 0 { break }
  }
  var actual = await trial.snapshot()
  for _ in 0..<5000 where !actual.docked { actual = await trial.advance(delta: 0.02) }
  #expect(actual.docked && actual.dockedAtMainStation)
  await trial.key("contacts-open")
  #expect(await trial.snapshot().scriptOffer == child)
  await trial.key("return")
  #expect(await trial.snapshot().commander.scriptState.instances[child]?.completionReceipt != nil)
  await trial.key("contacts-open")
  #expect(await trial.snapshot().scriptOffer == parentID)
  let balance = await trial.snapshot().commander.credits
  await trial.key("return")
  actual = await trial.snapshot()
  #expect(
    actual.commander.scriptState.instances[parentID]?.receiptJoins?["patrol-report"] == [child])
  #expect(actual.commander.scriptState.instances[parentID]?.outcome == .complete)
  #expect(actual.commander.credits == balance && actual.isMissionTrial)
  let saved = directory.appendingPathComponent("commander.json")
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: saved), from: saved)
  #expect(disk == actual.commander)
  #expect(await owner.snapshot().commander == original.commander)
  #expect(await owner.snapshot().bodies == original.bodies && actual.commander.valid)
}

@Test func nativeReceiptCountsDoNotTreatOneCompletedInstanceAsTwoChildren() throws {
  let fixture = try CompletionFixture(stage: "acceptance")
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game)
  let manifest = fixture.root.appendingPathComponent("parent/manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  try original.replacingOccurrences(of: "minimumCount=1", with: "minimumCount=2")
    .write(to: manifest, atomically: true, encoding: .utf8)
  let parent = try ScriptPackLibrary.read(manifest.deletingLastPathComponent())
  game.scriptPacks = [fixture.child, parent]
  game.emitScriptEvent("contact.requested", only: child)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(parent) }
  #expect(game.commander.scriptState.instances.count == 1 && game.commander.valid)
}

@Test func declaredFailureCreatesItsOwnNativeReceiptWithoutClaimingChildSuccess() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("parent")
  let file = folder.appendingPathComponent("scripts/main.lua")
  let source = try String(contentsOf: file, encoding: .utf8)
  try source.replacingOccurrences(of: "outcome='complete'", with: "outcome='failed'")
    .write(to: file, atomically: true, encoding: .utf8)
  let pack = try ScriptPackLibrary.read(folder)
  var game = fixture.game()
  game.scriptPacks = [fixture.child, pack]
  let id = try game.acceptScriptMission(pack)
  game.emitScriptEvent("contact.requested", only: id)
  let state = try #require(game.commander.scriptState.instances[id])
  #expect(state.outcome == .failed && state.completionReceipt?.outcome == .failed)
  #expect(state.receiptJoins?.isEmpty == true && game.commander.valid)
  #expect(
    game.matchingScriptReceipts(try #require(pack.manifest.receiptRequirements?.first)).isEmpty)
}

@Test func malformedReceiptRequirementsFailPackValidationBeforeInstallation() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("parent")
  let manifest = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  for (before, after) in [
    ("minimumCount=1", "minimumCount=0"),
    ("minimumCount=1", "minimumCount=129"),
    ("stage=\"completion\"", "stage=\"installed\""),
    ("outcome=\"complete\"", "outcome=\"active\""),
    (fixture.child.digest, "not-a-digest"),
    (fixture.child.manifest.stateID, "test.receipt-parent/report"),
    ("minimumCount=1", "minimumCount=1\ninvented=1"),
    (",\"completion-receipts-v2\"", ""),
  ] {
    try original.replacingOccurrences(of: before, with: after)
      .write(to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
}

@Test func fourActualPatrolReportsJoinWithOnlyTheExplicitlyAllowedFailedOutcome() async throws {
  let fixtures = try (0..<4).map { index in
    try CompletionFixture(
      allowedOutcomes: ["complete", "failed"], childID: "test.strand-\(index)",
      failedChild: index == 3)
  }
  defer { fixtures.forEach { $0.clean() } }
  let manifest = fixtures[0].root.appendingPathComponent("parent/manifest.toml")
  var text = try String(contentsOf: manifest, encoding: .utf8)
  text = text.replacingOccurrences(
    of: "outcomes=[\"complete\",\"failed\"]", with: "outcome=\"complete\"")
  for index in 1..<4 {
    let child = fixtures[index].child
    text += """

      [[receiptRequirements]]
      id="patrol\(index)"
      stage="completion"
      definition="\(child.manifest.stateID)"
      version="\(child.manifest.version)"
      digest="\(child.digest)"
      \(index == 3 ? "outcomes=[\"complete\",\"failed\"]" : "outcome=\"complete\"")
      minimumCount=1
      """
  }
  try text.write(to: manifest, atomically: true, encoding: .utf8)
  let parent = try ScriptPackLibrary.read(manifest.deletingLastPathComponent())
  var game = fixtures[0].game()
  game.scriptPacks = fixtures.map(\.child) + [parent]
  let parentID = try game.acceptScriptMission(parent)
  var children: [UUID] = []
  for index in 0..<4 {
    children.append(
      try fixtures[index].completePatrol(&game, expected: index == 3 ? .failed : .complete))
    #expect(game.commander.scriptState.instances[parentID]?.outcome == .active)
  }
  game.drainScriptEvents()
  #expect(game.commander.kills == 8)
  let balance = game.commander.credits
  game.emitScriptEvent("contact.requested", only: parentID)
  let state = try #require(game.commander.scriptState.instances[parentID])
  #expect(state.outcome == .complete && state.receiptJoins?.count == 4)
  #expect(state.data["notifications"] == .integer(4))
  #expect(Set(state.receiptJoins?.values.flatMap { $0 } ?? []) == Set(children))
  #expect(game.commander.scriptState.instances[children[3]]?.completionReceipt?.outcome == .failed)
  #expect(game.commander.credits == balance + 100 && game.commander.valid)
  let save = fixtures[0].root.appendingPathComponent("save/commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  let loaded = GameRuntime(game: fixtures[0].game())
  try await loaded.load(from: save)
  #expect(
    await loaded.snapshot().commander.scriptState.instances[parentID]?.receiptJoins
      == state.receiptJoins)
  #expect(
    await loaded.snapshot().commander.scriptState.instances[children[3]]?.completionReceipt?.outcome
      == .failed)
}

@Test func aFailedNativeChildDoesNotMatchASuccessOnlyCompoundRequirement() throws {
  let fixture = try CompletionFixture(allowedOutcomes: ["complete"], failedChild: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parent)
  _ = try fixture.completePatrol(&game, expected: .failed)
  game.drainScriptEvents()
  let balance = game.commander.credits
  game.emitScriptEvent("contact.requested", only: parent)
  #expect(game.commander.scriptState.instances[parent]?.outcome == .active)
  #expect(game.commander.scriptState.instances[parent]?.completionReceipt == nil)
  #expect(game.commander.credits == balance && game.commander.valid)
}

@Test func ambiguousActiveDuplicateAndUnsupportedCompoundOutcomesCannotInstall() throws {
  let fixture = try CompletionFixture(allowedOutcomes: ["complete", "failed"])
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("parent")
  let file = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: file, encoding: .utf8)
  for replacement in [
    "outcomes=[]", "outcomes=[\"active\"]", "outcomes=[\"complete\",\"complete\"]",
    "outcomes=[\"complete\",\"unknown\"]", "outcome=\"complete\"\noutcomes=[\"failed\"]",
  ] {
    try original.replacingOccurrences(of: "outcomes=[\"complete\",\"failed\"]", with: replacement)
      .write(to: file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
  try original.replacingOccurrences(of: ",\"compound-receipts-v2\"", with: "")
    .write(to: file, atomically: true, encoding: .utf8)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
}
