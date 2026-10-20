import Foundation
import Testing

@testable import EliteCore

private struct EMPArchiveTimerFixture {
  let root: URL
  let pack: ScriptPack
  var container: URL { root.appendingPathComponent("save") }
  var url: URL { container.appendingPathComponent("commander.json") }
  init(example: String = "scripted-courier", source: String? = nil, edits: [(String, String)] = [])
    throws
  {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "durable-script-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/" + example)
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    if let source {
      try source.write(
        to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    }
    pack = try ScriptPackLibrary.read(directory)
  }
  func game(accepted: Bool = true, destination: Bool = true, archive: Bool = false) throws -> Game {
    var game = archive ? try empFixture() : Game(executive: false)
    if archive {
      let released = try releaseDamagedEMPBoundary(&game)
      try #require(released)
      let captured = game.persistEMPState()
      try #require(captured)
      let stations = try #require(game.commander.nativeStations)
      try #require(
        stations.sceneIsConsistent(
          bodies: game.bodies, docked: game.docked, mainStation: game.dockedAtMainStation,
          system: game.systemIdentity, flight: game.commander.flightSimulation))
    }
    game.screen = .status
    game.scriptPacks = [pack]
    if accepted { _ = try game.acceptScriptMission(pack) }
    if destination && !archive { game.commander.system = 129 }
    return game
  }
  func breakWriter() throws {
    try FileManager.default.moveItem(at: container, to: root.appendingPathComponent("backup"))
    try Data("blocked directory".utf8).write(to: container)
  }
  func restoreWriter() throws {
    try FileManager.default.removeItem(at: container)
    try FileManager.default.moveItem(at: root.appendingPathComponent("backup"), to: container)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}
private let empArchiveTimers = """
  return {
   accepted=function(e,w,d) return {data=d,commands={
    {op='timer.ensure',id='a',domain='local',after=0.05,interval=0,policy='once'},
    {op='timer.ensure',id='b',domain='local',after=0.05,interval=0,policy='once'}}} end,
   contact=function(e,w,d) return {data=d,commands={}} end,
   confirm=function(e,w,d) return {data=d,commands={}} end,
   timer=function(e,w,d)
    if e.timer_id=='a' then return {data=d,commands={
     {op='credits',id='first-pay',amount=25},{op='timer.cancel',id='b'}}} end
    return {data=d,commands={{op='credits',id='wrong-pay',amount=5000}}} end
  }
  """
private func empArchiveTimerFixture() throws -> EMPArchiveTimerFixture {
  try EMPArchiveTimerFixture(
    source: empArchiveTimers,
    edits: [
      ("\"cargo-v2\"]", "\"cargo-v2\", \"local-flight-clocks-v2\"]"),
      ("[[dialogs]]", "[[handlers]]\nevent = 'timer.fired'\nfunction = 'timer'\n\n[[dialogs]]"),
    ])
}

@Test(arguments: [false, true])
func empArchiveNestedTimerSavePublishesAndReplaysOnce(archive: Bool) async throws {
  let fixture = try empArchiveTimerFixture()
  defer { fixture.clean() }
  let game = try fixture.game(archive: archive)
  let startingCredits = game.commander.credits
  #expect((game.commander.savedEMPState != nil) == archive)
  let runtime = GameRuntime(game: game, saveURL: fixture.url)
  _ = await runtime.advance(delta: 0.05)
  let after = await runtime.snapshot()
  #expect(after.commander.credits == startingCredits + 25)
  let id = try #require(after.commander.scriptState.instances.keys.first)
  #expect(after.commander.scriptState.instances[id]?.timers.isEmpty == true)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.url), from: fixture.url)
  #expect(saved.valid && saved.savedEMPState == after.commander.savedEMPState)
  #expect((saved.savedEMPState != nil) == archive)
  let restored = GameRuntime(game: try fixture.game(accepted: false))
  try await restored.load(from: fixture.url)
  _ = await restored.advance(delta: 0.1)
  #expect(await restored.snapshot().commander.credits == startingCredits + 25)
}

// Observe only after this regression's actual first save fails. Preparation is replayed on an
// isolated value to identify its existing refusal; it writes no file or runtime state.
@inline(never)
private func empArchiveFirstSaveRefusal(_ failed: Game, archive: Bool) -> String {
  let diagnostics = ScriptRefusalDiagnostic()
  do {
    let prepared = try GameRuntime.prepareNativeSaveState(
      failed, diagnostics: diagnostics, diagnosticBoundary: .resolver)
    let world = prepared.game.scriptWorldSave
    let scene = world.consistent(with: prepared.commander, diagnostics: diagnostics)
    let checks = ScriptRefusalObservation.storeChecks(
      prepared.commander, world: world, scope: "commander")
    return "EMP first save refused: archive=\(archive),nativePreparation=passed,"
      + "worldValid=\(world.valid),scene=\(scene),storeChecks=\(checks),"
      + (diagnostics.detail() ?? "no observed native or scene refusal")
  } catch {
    return "EMP first save refused: archive=\(archive),nativePreparation=refused,"
      + (diagnostics.detail() ?? "no observed native refusal")
  }
}

@Test(arguments: [false, true])
func empArchiveNestedTimerWriterFailureRetainsArchiveAndRetries(archive: Bool) async throws {
  let fixture = try empArchiveTimerFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: try fixture.game(archive: archive), saveURL: fixture.url)
  let startingCredits = await runtime.snapshot().commander.credits
  do {
    try await runtime.save(to: fixture.url)
  } catch {
    let failed = await runtime.snapshot()
    Issue.record(Comment(rawValue: empArchiveFirstSaveRefusal(failed, archive: archive)))
    throw error
  }
  let bytes = try Data(contentsOf: fixture.url)
  try fixture.breakWriter()
  let denied = await runtime.advance(delta: 0.05)
  let id = try #require(denied.commander.scriptState.instances.keys.first)
  let state = try #require(denied.commander.scriptState.instances[id])
  #expect(denied.commander.credits == startingCredits && state.suspension != nil)
  #expect(state.timers["a"] == nil && state.timers["b"] != nil)
  #expect((denied.commander.savedEMPState != nil) == archive)
  #expect(
    denied.commander.scriptState.pendingEvents.contains {
      $0.kind == "timer.fired" && $0.values["timer_id"] == .string("a")
    })
  try fixture.restoreWriter()
  #expect(try Data(contentsOf: fixture.url) == bytes)
  try await runtime.resumeScriptMission(id)
  _ = await runtime.advance(delta: 0.1)
  let after = await runtime.snapshot()
  #expect(after.commander.credits == startingCredits + 25)
  #expect(after.commander.scriptState.instances[id]?.timers.isEmpty == true)
  #expect((after.commander.savedEMPState != nil) == archive)
}

@Test func empArchiveNilGuardRejectsRetainedEMPActors() throws {
  var game = try empFixture()
  let released = try releaseDamagedEMPBoundary(&game)
  try #require(released)
  try #require(game.commander.savedEMPState != nil)
  game.commander.savedEMPState = nil
  let captured = game.persistEMPState()
  #expect(!captured)
  #expect(game.commander.savedEMPState == nil)
}

@Test func empArchiveInvalidCandidateDoesNotPublish() throws {
  var game = try empFixture()
  let released = try releaseDamagedEMPBoundary(&game)
  try #require(released)
  let source = try #require(game.commander.savedEMPState?.records.keys.first)
  game.commander.savedEMPState?.records[source]?.lostCrewCount = -1
  let before = game.commander.savedEMPState
  let captured = game.persistEMPState()
  #expect(!captured)
  #expect(game.commander.savedEMPState == before)
}
