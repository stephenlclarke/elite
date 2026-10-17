import Foundation
import Testing

@testable import EliteCore

private struct ActorCullJobFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }

  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "actor-job-cull-" + UUID().uuidString)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text = text.replacingOccurrences(
      of: "capabilities = [",
      with: "capabilities = [\"world-resource-jobs-v2\", \"pulse-counters-v2\", ")
    // Authored zero recharge keeps the cull fixture's remaining condition exact.
    text = text.replacingOccurrences(of: "recharge = 1.0", with: "recharge = 0.0")
    text += """

      [[handlers]]
      event='actor.removed'
      function='removed'
      [[worldJobs]]
      id='maintenance'
      title='Actor maintenance'
      handler='maintenance'
      owner='actor'
      galaxy=0
      system=7
      firstDue=0
      interval=1
      policy='skip'
      counters=['opening']
      controlledEncounters=['opponents']
      encounter='opponents'
      actor='lead'
      """
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let source = """
      local M={}
      function M.accepted(e,w,d)
        return {data={parent='active'},commands={{op='encounter.ensure',id='opponents'},
          {op='world.job.ensure',id='maintenance'}}}
      end
      function M.maintenance(e,w,d) error('retain this actual pending resource pulse') end
      function M.contact(e,w,d) return {data=d,commands={}} end
      function M.removed(e,w,d)
        d.removed=(d.removed or 0)+1; return {data=d,commands={}}
      end
      function M.destroyed(e,w,d)
        d.destroyed=(d.destroyed or 0)+1; d.destroyedActor=e.actor_id; return {data=d,commands={}}
      end
      M.confirm=M.contact; M.undocked=M.contact; M.admitted=M.contact
      return M
      """
    try source.write(
      to: directory.appendingPathComponent("scripts/skirmish.lua"), atomically: true,
      encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
  }

  func game() throws -> (Game, UUID, UUID, UUID) {
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.scriptPacks = [pack]
    game.launch()
    let origin = try game.acceptScriptMission(pack)
    game.drainScriptEvents()
    game.advanceScriptWorldJobs(delta: 0.1)
    let job = try #require(
      game.commander.scriptState.worldJobs.values.first { $0.origin == origin })
    try #require(job.status == .active && job.pending != nil && job.suspension != nil)
    try #require(game.commander.valid)
    return (game, origin, job.identity, job.resource)
  }

  func clean() { try? FileManager.default.removeItem(at: root) }
}

struct ScriptActorWorldJobCullTests {
  @Test func actualLivingDeparturePreservesActivePendingJobAndLatestConditionThroughSaveReload()
    async throws
  {
    let fixture = try ActorCullJobFixture()
    defer { fixture.clean() }
    var (game, origin, jobID, actorID) = try fixture.game()
    let index = try #require(game.bodies.firstIndex { $0.missionActorID == actorID })
    game.bodies[index].energy = 37
    game.bodies[index].scriptNPC?.components["turret"]?.energy = 17
    game.bodies[index].position = .init(45_000, 0, 2000)
    let pending = try #require(game.commander.scriptState.worldJobs[jobID])
    let runtime = GameRuntime(game: game, saveURL: fixture.save)
    let outside = await runtime.advance(delta: 0.1)
    let retained = try #require(
      outside.commander.scriptState.instances[origin]?.ownedEncounters["opponents"]?.actors["lead"])
    let job = try #require(outside.commander.scriptState.worldJobs[jobID])
    #expect(!outside.bodies.contains { $0.missionActorID == actorID })
    #expect(retained.presence == .outside && retained.body.energy == 37)
    #expect(retained.body.scriptNPC?.components["turret"]?.energy == 17)
    #expect(job.status == .active && job.pending == pending.pending)
    #expect(job.timer == pending.timer && job.elapsed == pending.elapsed)
    #expect(job.cancellationReason == nil && job.suspension == pending.suspension)
    #expect(outside.commander.scriptState.instances[origin]?.data["removed"] == .integer(1))
    #expect(outside.commander.scriptState.instances[origin]?.data["destroyed"] == nil)
    #expect(outside.commander.valid && outside.scriptWorldSave.consistent(with: outside.commander))
    try await runtime.save(to: fixture.save)
    let (saved, world) = try ScriptSaveStore.read(
      Data(contentsOf: fixture.save), from: fixture.save)
    #expect(saved.valid && world.valid && world.consistent(with: saved))
    #expect(saved.scriptState.worldJobs[jobID] == job)
    var host = Game(executive: false)
    host.scriptPacks = [fixture.pack]
    let restored = GameRuntime(game: host)
    try await restored.load(from: fixture.save)
    let loaded = await restored.snapshot()
    #expect(loaded.commander.scriptState.worldJobs[jobID] == job)
    #expect(
      loaded.commander.scriptState.instances[origin]?.ownedEncounters["opponents"]?.actors["lead"]
        == retained)
    #expect(loaded.commander.scriptState.instances[origin]?.data["destroyed"] == nil)
  }

  @Test func actualDeadOwnerCullCancelsItsPendingJobAndRecordsTerminalExactlyOnce() async throws {
    let fixture = try ActorCullJobFixture()
    defer { fixture.clean() }
    var (game, origin, jobID, actorID) = try fixture.game()
    let index = try #require(game.bodies.firstIndex { $0.missionActorID == actorID })
    game.bodies[index].energy = 0
    game.bodies[index].destroyedByPlayer = false
    // Settle this terminal-condition fixture through the real removal boundary before
    // handing it to the actor's retained-scene preflight. This is not a weapon-kill claim.
    game.resolveDestroyed()
    try #require(!game.bodies.contains { $0.missionActorID == actorID })
    let runtime = GameRuntime(game: game, saveURL: fixture.save)
    let dead = await runtime.advance(delta: 0.1)
    let job = try #require(dead.commander.scriptState.worldJobs[jobID])
    #expect(job.status == .cancelled && job.pending == nil && job.suspension == nil)
    #expect(job.cancellationReason == "Actual owner destroyed.")
    #expect(
      dead.commander.scriptState.instances[origin]?.ownedEncounters["opponents"]?.actors["lead"]?
        .presence == .destroyed)
    #expect(dead.commander.scriptState.instances[origin]?.data["destroyed"] == .integer(1))
    #expect(
      dead.commander.scriptState.instances[origin]?.data["destroyedActor"]
        == .string(actorID.uuidString))
    let again = await runtime.advance(delta: 0.1)
    #expect(again.commander.scriptState.worldJobs[jobID] == job)
    #expect(again.commander.scriptState.instances[origin]?.data["destroyed"] == .integer(1))
    #expect(again.commander.valid && again.scriptWorldSave.consistent(with: again.commander))
    try await runtime.save(to: fixture.save)
    let (saved, world) = try ScriptSaveStore.read(
      Data(contentsOf: fixture.save), from: fixture.save)
    #expect(saved.scriptState.worldJobs[jobID] == job && world.consistent(with: saved))
  }
}
