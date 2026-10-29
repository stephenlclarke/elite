import Foundation
import Testing

@testable import EliteCore

private var scriptedCourier: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/scripted-courier")
}
private func scriptFolder() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "script-test-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}
private func scriptPack(_ edits: [(String, String)] = [], source: String? = nil) throws -> (
  ScriptPack, URL
) {
  let directory = try scriptFolder()
  try FileManager.default.copyItem(
    at: scriptedCourier, to: directory.appendingPathComponent("pack"))
  let pack = directory.appendingPathComponent("pack")
  let manifest = pack.appendingPathComponent("manifest.toml")
  var text = try String(contentsOf: manifest, encoding: .utf8)
  for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
  try text.write(to: manifest, atomically: true, encoding: .utf8)
  if let source {
    try source.write(
      to: pack.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
  }
  do { return (try ScriptPackLibrary.read(pack), directory) } catch {
    try? FileManager.default.removeItem(at: directory)
    throw error
  }
}

@Test func scriptPackLoadingInstallationAndUnsupportedCapabilities() throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  #expect(pack.missingCapabilities.isEmpty)
  let directory = try scriptFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let destination = try ScriptPackLibrary.install(pack, directory: directory)
  #expect(try ScriptPackLibrary.read(destination).digest == pack.digest)
  #expect(try ScriptPackLibrary.install(pack, directory: directory) == destination)
  let (unsupported, folder) = try scriptPack([
    ("\"cargo-v2\"]", "\"cargo-v2\", \"world-actors-v1\"]")
  ])
  defer { try? FileManager.default.removeItem(at: folder) }
  #expect(unsupported.missingCapabilities == ["world-actors-v1"])
  var game = Game(executive: false)
  game.scriptPacks = [unsupported]
  #expect(game.scriptGallery.first?.status == .locked)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(unsupported) }
}

@Test func scriptPackRejectsScopePathsTyposBadSyntaxAndLinks() throws {
  for edit in [
    ("schemaVersion = 2", "schemaVersion = 1"),
    ("priority = 500", "priority = 500\nexecutable = 'oops'"),
    ("\"space\", \"orbital-station\"", "\"surface\""),
    ("scripts/main.lua", "../escape.lua"), ("scripts/main.lua", "/tmp/escape.lua"),
    ("function = \"accepted\"", "function = 'bad-handler'"),
    ("event = \"mission.accepted\"", "event = 'fake.death'"),
  ] { #expect(throws: (any Error).self) { try scriptPack([edit]) } }
  #expect(throws: (any Error).self) { try scriptPack(source: "syntax error") }
  #expect(throws: (any Error).self) { try scriptPack(source: "while true do end") }
  let (_, folder) = try scriptPack()
  defer { try? FileManager.default.removeItem(at: folder) }
  let source = folder.appendingPathComponent("pack/scripts/main.lua")
  try FileManager.default.removeItem(at: source)
  try FileManager.default.createSymbolicLink(
    at: source, withDestinationURL: scriptedCourier.appendingPathComponent("scripts/main.lua"))
  #expect(throws: (any Error).self) {
    try ScriptPackLibrary.read(folder.appendingPathComponent("pack"))
  }
}

@Test func scriptedCourierUsesAtomicCustodyConfirmAndNeverReplaysReward() throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.commander.credits = 1000
  game.screen = .status
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  #expect(game.commander.scriptState.instances[id]?.suspension == nil)
  #expect(game.commander.cargoTonnes == 1 && game.commander.credits == 1000)
  game.emitScriptEvent("contact.requested")
  #expect({ !game.showScriptDialogue() }())
  game.commander.system = 129
  game.emitScriptEvent("contact.requested")
  #expect({ game.showScriptDialogue() }())
  let before = game.commander
  game.closeBlackjackHandoff()
  #expect(game.commander == before)
  #expect({ game.showScriptDialogue() }())
  game.confirmScriptDialogue()
  #expect(game.commander.credits == 1500 && game.commander.cargoTonnes == 0)
  #expect(game.commander.scriptState.instances[id]?.outcome == .complete)
  game.emitScriptEvent("contact.requested")
  game.emitScriptEvent("dialogue.confirmed", values: ["dialogue_id": .string("delivery")])
  #expect(game.commander.credits == 1500)
  #expect(game.scriptGallery.first?.status == .complete)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(pack) }
}

@Test func scriptTransactionsRollbackAllEffectsOnFitErrorUnknownCommandsAndScriptFaults() throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var full = Game(executive: false)
  full.commander.credits = 1000
  full.scriptPacks = [pack]
  full.commander.cargo[0] = full.commander.capacity
  let original = full.commander
  #expect(throws: MissionPackError.self) { try full.acceptScriptMission(pack) }
  #expect(full.commander == original)
  for command in [
    "{op='credits',id='pay',amount=100},{op='unimplemented'}",
    "{op='credits',id='pay',amount=-10000}", "{op='credits',id='pay',amount=100,typo=true}",
  ] {
    let (bad, folder) = try scriptPack(
      source: "return {accepted=function(e,w,d) d.changed=true return {data=d,commands={" + command
        + "}} end, contact=function(e,w,d) return {data=d,commands={}} end, confirm=function(e,w,d) return {data=d,commands={}} end}"
    )
    defer { try? FileManager.default.removeItem(at: folder) }
    var game = Game(executive: false)
    game.commander.credits = 1000
    game.scriptPacks = [bad]
    #expect(throws: MissionPackError.self) { try game.acceptScriptMission(bad) }
    #expect(game.commander.credits == 1000 && game.commander.scriptState.instances.isEmpty)
  }
}

@Test func scriptsKeepOldSavesAndMissingPackCargoIntact() throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  _ = try game.acceptScriptMission(pack)
  let bytes = try JSONEncoder().encode(game.commander)
  let restored = try JSONDecoder().decode(Commander.self, from: bytes)
  #expect(restored == game.commander && restored.valid)
  var missing = Game(executive: false)
  #expect({ missing.load(restored) }())
  missing.emitScriptEvent("contact.requested")
  #expect(missing.commander.cargoTonnes == 1)
  #expect(missing.scriptGallery.first?.status == .locked)
  #expect(
    try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(Commander())).scriptState
      .instances.isEmpty)
}

@Test func scriptGalleryTrialAndMenuAcceptAreIndependent() async throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let runtime = GameRuntime(game: game)
  let trial = try await runtime.scriptGalleryTrial(packDigest: pack.digest)
  let namespace = try #require(await trial.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  #expect(await trial.snapshot().commander.cargoTonnes == 1)
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().screen == .handoff)
  await runtime.key("escape")
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  await runtime.key("contacts-open")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.cargoTonnes == 1)
}

@Test func scriptClocksSkipMissedPulsesPauseAndPreserveDockedLocalTime() throws {
  let source = """
    return {accepted=function(e,w,d)
      return {data={count=0},commands={{op='timer.ensure',id='pulse',domain='local',after=0,interval=1,policy='skip'}}}
    end, contact=function(e,w,d) return {data=d,commands={}} end,
    confirm=function(e,w,d) d.count=d.count+1 return {data=d,commands={}} end}
    """
  let (pack, directory) = try scriptPack(
    [
      ("\"cargo-v2\"]", "\"cargo-v2\", \"local-flight-clocks-v2\"]"),
      ("event = \"dialogue.confirmed\"", "event = \"timer.fired\""),
    ], source: source)
  defer { try? FileManager.default.removeItem(at: directory) }
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  #expect(game.commander.scriptState.instances[id]?.data["count"] == .integer(1))
  game.commander.scriptState.localSeconds = 50
  game.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  #expect(game.commander.scriptState.instances[id]?.data["count"] == .integer(2))
  #expect(game.commander.scriptState.instances[id]?.timers["pulse"]?.due == 51)
  #expect(game.commander.scriptState.flightSeconds == 0)
  let before = game.commander
  game.paused = true
  game.advanceScriptClocks(delta: 1, flight: true, local: true)
  #expect(game.commander == before)
}

@Test func staleDialogueAndUndeclaredCapabilitiesCannotTransferProperty() throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.commander.credits = 1000
  game.scriptPacks = [pack]
  game.screen = .status
  let id = try game.acceptScriptMission(pack)
  game.commander.system = 129
  game.emitScriptEvent("contact.requested")
  _ = game.showScriptDialogue()
  game.commander.system = 7
  game.confirmScriptDialogue()
  #expect(game.commander.credits == 1000 && game.commander.cargoTonnes == 1)
  #expect(game.commander.scriptState.instances[id]?.outcome == .active)
  let (noCargo, directory) = try scriptPack([(", \"cargo-v2\"", "")])
  defer { try? FileManager.default.removeItem(at: directory) }
  var other = Game(executive: false)
  other.scriptPacks = [noCargo]
  #expect(throws: MissionPackError.self) { try other.acceptScriptMission(noCargo) }
  #expect(other.commander.scriptState.instances.isEmpty)
}

@Test func scriptGenerationSavesRestoreOwnedStateAndRejectCorruptionAtomically() async throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.screen = .front
  game.docked = false
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.bodies = [SpaceBody(id: 10, hull: .sidewinder, position: .init(25, 50, 2000), hostile: true)]
  game.nextBodyID = 11
  game.energy = 120
  let runtime = GameRuntime(game: game)
  let directory = try scriptFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let save = directory.appendingPathComponent("commander.json")
  try await runtime.save(to: save)
  let firstPointer = try Data(contentsOf: save)
  let firstSaved = await runtime.snapshot().commander
  let destination = GameRuntime()
  try await destination.load(from: save)
  let restored = await destination.snapshot()
  #expect(restored.commander.scriptState.instances[id]?.payloads == ["supplies": 1])
  #expect(restored.bodies == game.bodies && restored.energy == 120 && !restored.docked)
  try await runtime.save(to: save)
  let secondPointer = try Data(contentsOf: save)
  #expect(firstPointer != secondPointer)
  #expect(try ScriptSaveStore.read(firstPointer, from: save).0 == firstSaved)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: secondPointer)
  let missions = save.appendingPathExtension("missions").appendingPathComponent(pointer.generation)
    .appendingPathComponent("missions.json")
  try Data("corrupted".utf8).write(to: missions)
  let before = await destination.snapshot().commander
  await #expect(throws: (any Error).self) { try await destination.load(from: save) }
  #expect(await destination.snapshot().commander == before)
}

@Test func scriptSaveWriteFailureKeepsPreviousGenerationAndRuntime() async throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  _ = try game.acceptScriptMission(pack)
  let directory = try scriptFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let save = directory.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  let original = try Data(contentsOf: save)
  let before = await runtime.snapshot().commander
  let blocked = directory.appendingPathComponent("blocked")
  try Data().write(to: blocked)
  await #expect(throws: (any Error).self) {
    try await runtime.save(to: blocked.appendingPathComponent("save.json"))
  }
  #expect(try Data(contentsOf: save) == original)
  #expect(await runtime.snapshot().commander == before)
}

@Test func scriptRuntimeInstallationRecoveryAndDependencyGates() async throws {
  let directory = try scriptFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let runtime = GameRuntime(game: Game(executive: false))
  try await runtime.installScriptPack(from: scriptedCourier, destination: directory)
  try await runtime.installScriptPack(from: scriptedCourier, destination: directory)
  #expect(await runtime.snapshot().scriptPacks.count == 1)
  let loader = GameRuntime()
  await loader.loadScriptPacks(directory: directory)
  let pack = try #require(await loader.snapshot().scriptPacks.first)
  #expect(pack.digest == (try ScriptPackLibrary.read(scriptedCourier)).digest)
  await #expect(throws: MissionPackError.self) { try await loader.resumeScriptMission(UUID()) }
  await #expect(throws: MissionPackError.self) {
    try await loader.scriptGalleryTrial(packDigest: "missing")
  }
  let (dependent, folder) = try scriptPack([
    ("priority = 500", "priority = 500\ndependencies = ['absent.pack@1.0.0']")
  ])
  defer { try? FileManager.default.removeItem(at: folder) }
  var blocked = Game(executive: false)
  blocked.scriptPacks = [dependent]
  #expect(blocked.scriptGallery.first?.status == .locked)
  #expect(throws: MissionPackError.self) { try blocked.acceptScriptMission(dependent) }
  try Data().write(to: directory.appendingPathComponent("broken"))
  await loader.loadScriptPacks(directory: directory)
  #expect(await loader.snapshot().message.contains("broken"))
}

@Test func scriptRuntimeResumeRevalidatesPendingTransactionWithoutDoublePayment() async throws {
  let source = """
    return {
      accepted=function(e,w,d) return {data={attempts=0},commands={}} end,
      contact=function(e,w,d)
        d.attempts=d.attempts+1
        return {data=d,commands={{op='credits',id='pay',amount=100},{op='payload.add',id='issue',key='part',amount=1}}}
      end,
      confirm=function(e,w,d) return {data=d,commands={}} end
    }
    """
  let (pack, folder) = try scriptPack(source: source)
  defer { try? FileManager.default.removeItem(at: folder) }
  var game = Game(executive: false)
  // Fixed rollback budget for this transaction fixture, independent of starter cash.
  game.commander.credits = 1000
  game.screen = .sell
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.commander.cargo[0] = game.commander.capacity
  game.emitScriptEvent("contact.requested")
  #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  #expect(game.commander.credits == 1000)
  // The player genuinely sells one tonne through the existing trade action before retrying.
  let runtime = GameRuntime(game: game)
  await runtime.key("return")
  let balance = await runtime.snapshot().commander.credits
  try await runtime.resumeScriptMission(id)
  let resumed = await runtime.snapshot()
  #expect(resumed.commander.scriptState.instances[id]?.suspension == nil)
  #expect(resumed.commander.scriptState.pendingEvents.isEmpty)
  #expect(resumed.commander.scriptState.instances[id]?.data["attempts"] == .integer(1))
  #expect(resumed.commander.credits == balance + 100)
  #expect(resumed.commander.scriptState.instances[id]?.payloads == ["part": 1])
  try await runtime.resumeScriptMission(id)
  #expect(await runtime.snapshot().commander.credits == balance + 100)
}

@Test func scriptedHandoffRendersNativeTextAndBackAtDifferentWindowSizes() async throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let runtime = GameRuntime(game: game)
  await runtime.key("contacts-open")
  let offer = await runtime.snapshot()
  for width in [512.0, 768, 1512] {
    let frame = Display.presentation(offer, width: width, height: 768)
    #expect(frame.labels.contains { $0.text == pack.manifest.mission.title.uppercased() })
    #expect(frame.labels.contains { $0.text.contains("Confirm / Continue") })
    #expect(frame.labels.contains { $0.text.contains("Back") })
  }
  await runtime.key("right")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
}

@Test func scriptContactShortcutRespectsTextInputPauseAndNestedScreens() async throws {
  let pack = try ScriptPackLibrary.read(scriptedCourier)
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  game.screen = .chart
  game.mapSearch.active = true
  let runtime = GameRuntime(game: game)
  await runtime.key("b")
  #expect(await runtime.snapshot().screen == .chart)
  #expect(await runtime.snapshot().commander.scriptState.instances.isEmpty)
  var paused = Game(executive: false)
  paused.scriptPacks = [pack]
  paused.screen = .status
  paused.paused = true
  let pausedRuntime = GameRuntime(game: paused)
  await pausedRuntime.key("contacts-open")
  #expect(await pausedRuntime.snapshot().scriptAvailablePackDigest == nil)
  #expect(await pausedRuntime.snapshot().commander.scriptState.instances.isEmpty)
}

@Test func dueScriptTimersWaitForAnActiveDomainAndNeverAdvanceInTheGallery() throws {
  let source = """
    return {accepted=function(e,w,d)
      return {data={count=0},commands={
        {op='timer.ensure',id='local',domain='local',after=0,interval=0,policy='once'},
        {op='timer.ensure',id='flight',domain='flight',after=0,interval=0,policy='once'}}}
    end,contact=function(e,w,d) return {data=d,commands={}} end,
    confirm=function(e,w,d) d.count=d.count+1 return {data=d,commands={}} end}
    """
  let (pack, folder) = try scriptPack(
    [
      ("\"cargo-v2\"]", "\"cargo-v2\", \"local-flight-clocks-v2\"]"),
      ("event = \"dialogue.confirmed\"", "event = \"timer.fired\""),
    ], source: source)
  defer { try? FileManager.default.removeItem(at: folder) }
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  let unchanged = game.commander.scriptState
  game.advanceScriptClocks(delta: 0.1, flight: false, local: false)
  #expect(game.commander.scriptState == unchanged)
  game.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  #expect(game.commander.scriptState.instances[id]?.data["count"] == .integer(1))
  #expect(game.commander.scriptState.instances[id]?.timers["flight"] != nil)
  game.advanceScriptClocks(delta: 0.1, flight: false, local: true)
  #expect(game.commander.scriptState.instances[id]?.data["count"] == .integer(1))
  game.advanceScriptClocks(delta: 0.1, flight: true, local: true)
  #expect(game.commander.scriptState.instances[id]?.data["count"] == .integer(2))
}
