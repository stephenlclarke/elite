import Foundation
import Testing

@testable import EliteCore

private struct WorldJobFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(actor: Bool = false, maintenance: String? = nil, manifestEdit: String? = nil) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "world-jobs-" + UUID().uuidString)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/" + (actor ? "profiled-skirmish" : "scripted-courier"))
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: example, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text = text.replacingOccurrences(
      of: "capabilities = [",
      with: "capabilities = [\"world-resource-jobs-v2\", \"pulse-counters-v2\", ")
    text += """

      [[worldJobs]]
      id='maintenance'
      title='Station maintenance'
      handler='maintenance'
      owner='\(actor ? "actor" : "station")'
      galaxy=0
      system=7
      firstDue=0
      interval=1
      policy='skip'
      counters=['opening','reset']
      controlledEncounters=\(actor ? "['opponents']" : "[]")
      \(actor ? "encounter='opponents'\nactor='lead'" : "")
      """
    if let manifestEdit { text += manifestEdit }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let entry = actor ? "scripts/skirmish.lua" : "scripts/main.lua"
    let source = """
      local M={}
      function M.accepted(e,w,d)
        return {data={parent='unchanged'},commands={
          \(actor ? "{op='encounter.ensure',id='opponents'}," : "")
          {op='world.job.ensure',id='maintenance'},
          {op='milestone.ensure',index=0},
          \(actor ? "" : "{op='milestone.ensure',index=1},")
          {op='mission.finish',outcome='\(actor ? "abandoned" : "complete")'}}}
      end
      function M.maintenance(e,w,d)
        \(maintenance ?? "d.count=(d.count or 0)+1; d.parent=w.parent_outcome; d.pulse=e.pulse; return {data=d,commands={}}")
      end
      function M.contact(e,w,d) return {data=d,commands={}} end
      M.confirm=M.contact; M.undocked=M.contact; M.admitted=M.contact; M.destroyed=M.contact
      return M
      """
    try source.write(to: directory.appendingPathComponent(entry), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
  }
  func game(actor: Bool = false) throws -> (Game, UUID, UUID) {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    if actor { game.launch() }
    let origin = try game.acceptScriptMission(pack)
    let job = try #require(
      game.commander.scriptState.worldJobs.values.first { $0.origin == origin })
    return (game, origin, job.identity)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func resourceJobsContinueAfterMissionCompletionWithoutChangingItsOutcomeOrReward()
  async throws
{
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  let (game, origin, id) = try fixture.game()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let parent = game.commander.scriptState.instances[origin]
  #expect(parent?.outcome == .complete)
  for _ in 0..<25 { _ = await runtime.advance(delta: 0.1) }
  let result = await runtime.snapshot()
  #expect(result.commander.scriptState.worldJobs[id]?.data["count"] == .integer(3))
  #expect(result.commander.scriptState.worldJobs[id]?.data["parent"] == .string("complete"))
  #expect(result.commander.scriptState.instances[origin] == parent)
  #expect(result.commander.credits == game.commander.credits)
  #expect(result.commander.valid)
}

@Test func localResourceJobsContinueInReadOnlyPanelsButFreezeUnloadedPausedAndAtTheTitle() throws {
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  var (game, _, id) = try fixture.game()
  for screen in [Screen.help, .gallery, .contracts, .navigation, .handoff] {
    game.screen = screen
    game.advanceScriptWorldJobs(delta: 0.1)
  }
  let loaded = try #require(game.commander.scriptState.worldJobs[id])
  #expect(loaded.elapsed == 0.5 && loaded.timer.pulses == 1)
  game.commander.system = 1
  game.advanceScriptWorldJobs(delta: 1)
  #expect(game.commander.scriptState.worldJobs[id] == loaded)
  game.commander.system = 7
  game.paused = true
  game.advanceScriptWorldJobs(delta: 1)
  #expect(game.commander.scriptState.worldJobs[id] == loaded)
  game.paused = false
  game.screen = .title
  game.advanceScriptWorldJobs(delta: 1)
  #expect(game.commander.scriptState.worldJobs[id] == loaded)
  game.screen = .status
  game.advanceScriptWorldJobs(delta: 0.1)
  #expect(game.commander.scriptState.worldJobs[id]?.elapsed == 0.6)
}

@Test func stationLossCancelsItsJobAndCannotRebuildItByLaunchingOrReloading() async throws {
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  var (game, _, id) = try fixture.game()
  game.launch()
  let index = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
  game.bodies[index].energy = 0
  game.resolveDestroyed()
  #expect(game.commander.scriptState.worldJobs[id]?.status == .cancelled)
  #expect(game.commander.scriptState.stationResources[game.contractStation.key]?.destroyed == true)
  game.launch()
  #expect(!game.bodies.contains { $0.id == 0 && $0.hull == .station })
  #expect(game.scriptAnchor == nil)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.load(from: fixture.save)
  let saved = await restored.snapshot()
  #expect(saved.commander.scriptState.worldJobs[id]?.status == .cancelled)
  #expect(!saved.bodies.contains { $0.id == 0 && $0.hull == .station })
}

@Test func independentJobRepairsLivingOwnedNPCsAfterAbandonmentWithoutRestockingOrResurrection()
  throws
{
  let fixture = try WorldJobFixture(
    actor: true,
    maintenance: """
      return {data={seen=w.parent_outcome},commands={{op='actor.repair',id='repair-once',encounter='opponents',actor='lead',amount=20},{op='job.finish'}}}
      """)
  defer { fixture.clean() }
  var (game, origin, id) = try fixture.game(actor: true)
  let index = try #require(
    game.bodies.firstIndex {
      $0.missionActorID == game.commander.scriptState.worldJobs[id]?.resource
    })
  game.bodies[index].energy = 50
  game.bodies[index].missiles = 0
  game.persistScriptActors()
  let stock = game.bodies[index].scriptNPC
  game.advanceScriptWorldJobs(delta: 0.1)
  #expect(game.bodies[index].energy == 70 && game.bodies[index].missiles == 0)
  #expect(game.bodies[index].scriptNPC == stock)
  #expect(game.commander.scriptState.instances[origin]?.outcome == .abandoned)
  #expect(game.commander.scriptState.worldJobs[id]?.status == .complete)
  let once = game.bodies[index].energy
  game.advanceScriptWorldJobs(delta: 0.1)
  #expect(game.bodies[index].energy == once)
}

@Test func worldJobsCannotPayReviveOrPublishPartOfARejectedRepairBatch() throws {
  let fixture = try WorldJobFixture(
    actor: true,
    maintenance: """
      return {data={changed=true},commands={{op='actor.repair',id='repair',encounter='opponents',actor='lead',amount=20},{op='credits',id='forbidden',amount=100}}}
      """)
  defer { fixture.clean() }
  var (game, origin, id) = try fixture.game(actor: true)
  let index = try #require(
    game.bodies.firstIndex {
      $0.missionActorID == game.commander.scriptState.worldJobs[id]?.resource
    })
  game.bodies[index].energy = 50
  game.persistScriptActors()
  let parent = game.commander.scriptState.instances[origin]
  let credits = game.commander.credits
  game.advanceScriptWorldJobs(delta: 0.1)
  #expect(game.bodies[index].energy == 50)
  #expect(
    game.commander.credits == credits && game.commander.scriptState.instances[origin] == parent)
  #expect(game.commander.scriptState.worldJobs[id]?.data == .object([:]))
  #expect(game.commander.scriptState.worldJobs[id]?.pending?.pulse == 1)
  #expect(game.commander.scriptState.worldJobs[id]?.suspension != nil)
  #expect(game.commander.valid)
}

@Test func worldJobSkippedPulsesAndNextCallbackZeroResetSurviveSaveWithoutConstructorReplay()
  async throws
{
  let fixture = try WorldJobFixture(
    maintenance: """
      d.count=(d.count or 0)+1; d.value=e.counters.reset
      local c={}
      if d.count==1 then c={{op='job.counter.reset',name='reset'}} end
      return {data=d,commands=c}
      """)
  defer { fixture.clean() }
  var (game, origin, id) = try fixture.game()
  game.advanceScriptWorldJobs(delta: 0.1)
  #expect(
    game.commander.scriptState.worldJobs[id]?.timer.counters["reset"]?.resetOnNextPulse == true)
  game.commander.scriptState.worldJobs[id]?.elapsed = 30
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  _ = await loaded.advance(delta: 0.1)
  let after = await loaded.snapshot()
  let job = try #require(after.commander.scriptState.worldJobs[id])
  #expect(job.timer.pulses == 2 && job.data["count"] == .integer(2))
  #expect(job.timer.counters["reset"]?.value == 0 && job.timer.due == 31)
  #expect(job.timer.lastDue == 1 && job.timer.lastFiredAt == 30.1)
  #expect(
    after.commander.scriptState.instances[origin] == game.commander.scriptState.instances[origin])
  #expect(after.commander.scriptState.worldJobs.count == 1)
  #expect(after.commander.valid)
}

@Test func retryOfASuspendedWorldJobProcessesItsOriginalPulseWithoutRevivingTheCompletedMission()
  async throws
{
  let fixture = try WorldJobFixture(
    maintenance: """
      assert(w.docked,'Dock before maintenance can continue.')
      return {data={sequence=e.sequence,pulse=e.pulse},commands={{op='job.finish'}}}
      """)
  defer { fixture.clean() }
  var (game, origin, id) = try fixture.game()
  game.launch()
  game.advanceScriptWorldJobs(delta: 0.1)
  let pending = try #require(game.commander.scriptState.worldJobs[id]?.pending)
  let parent = game.commander.scriptState.instances[origin]
  #expect(game.commander.scriptState.worldJobs[id]?.suspension != nil)
  game.dock()
  game.screen = .gallery
  game.gallery.selection = try #require(
    game.missionCatalogue.firstIndex { $0.savedInstance == origin })
  #expect(game.canRetrySelectedMission)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  await runtime.key("r")
  let result = await runtime.snapshot()
  #expect(result.commander.scriptState.worldJobs[id]?.status == .complete)
  #expect(result.commander.scriptState.worldJobs[id]?.acknowledgedThrough == pending.sequence)
  #expect(result.commander.scriptState.worldJobs[id]?.timer.pulses == 1)
  #expect(result.commander.scriptState.instances[origin] == parent)
  #expect(result.commander.valid)
}

@Test func missingExactWorldJobContentSuspendsEvenWhenTheParentMissionIsAlreadyComplete()
  async throws
{
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  let (game, origin, id) = try fixture.game()
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.load(from: fixture.save)
  let missing = await restored.snapshot()
  #expect(missing.commander.scriptState.worldJobs[id]?.suspension != nil)
  #expect(missing.commander.scriptState.instances[origin]?.outcome == .complete)
  _ = await restored.advance(delta: 0.1)
  #expect(
    await restored.snapshot().commander.scriptState.worldJobs[id]
      == missing.commander.scriptState.worldJobs[id])
  await #expect(throws: MissionPackError.self) { try await restored.resumeScriptMission(origin) }
}

@Test func anUnadmittedActorCannotOwnAJobAndTheWholeInitialAcceptanceRollsBack() throws {
  let fixture = try WorldJobFixture(actor: true)
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.scriptPacks = [fixture.pack]
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
  #expect(game.commander == before && game.commander.scriptState.worldJobs.isEmpty)
  #expect(!game.bodies.contains { $0.missionActorID != nil })
}

@Test func fatalOwnerDamageCancelsTheJobWithoutRepairingOrClaimingAPlayerKill() throws {
  let fixture = try WorldJobFixture(actor: true)
  defer { fixture.clean() }
  var (game, _, id) = try fixture.game(actor: true)
  let resource = try #require(game.commander.scriptState.worldJobs[id]?.resource)
  let index = try #require(game.bodies.firstIndex { $0.missionActorID == resource })
  let credits = game.commander.credits
  let kills = game.commander.kills
  game.bodies[index].energy = 0
  game.resolveDestroyed()
  #expect(game.commander.scriptState.worldJobs[id]?.status == .cancelled)
  game.advanceScriptWorldJobs(delta: 0.1)
  #expect(!game.bodies.contains { $0.missionActorID == resource })
  #expect(game.commander.kills == kills && game.commander.credits == credits)
  #expect(game.commander.valid)
}

@Test func theAuthoredStationServiceDeploysActualShipsAfterItsAuthorizationMissionIsComplete()
  async throws
{
  let pack = try ScriptPackLibrary.read(
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/station-maintenance"))
  var parent = Game(executive: false)
  parent.screen = .gallery
  parent.scriptPacks = [pack]
  let parentCommander = parent.commander
  let runtime = try await GameRuntime(game: parent).scriptGalleryTrial(packDigest: pack.digest)
  for _ in 0..<45 { _ = await runtime.advance(delta: 0.1) }
  let waiting = await runtime.snapshot()
  let origin = try #require(waiting.commander.scriptState.instances.values.first)
  let prepared = try #require(origin.ownedEncounters["support"])
  #expect(origin.outcome == .complete && !prepared.admitted)
  #expect(!waiting.bodies.contains { $0.missionActorID != nil })
  let identities = Set(prepared.actors.values.map(\.identity))
  await runtime.key("0")
  for _ in 0..<25 { _ = await runtime.advance(delta: 0.1) }
  let deployed = await runtime.snapshot()
  let admitted = try #require(
    deployed.commander.scriptState.instances[origin.id]?.ownedEncounters["support"])
  #expect(admitted.admitted && Set(admitted.actors.values.map(\.identity)) == identities)
  #expect(Set(deployed.bodies.compactMap(\.missionActorID)) == identities)
  #expect(deployed.commander.scriptState.worldJobs.values.first?.status == .complete)
  #expect(deployed.commander.scriptState.instances[origin.id]?.outcome == .complete)
  #expect(deployed.commander.credits == 1000 && deployed.commander.kills == 0)
  let service = try #require(deployed.missionCatalogue.first { $0.savedInstance == origin.id })
  #expect(service.briefing.contains("Ongoing services:"))
  #expect(parent.commander == parentCommander)
  #expect(deployed.commander.valid)
}

@Test func trackedStationConditionSurvivesNativeDockLaunchWithoutHealingOrRestartingTheJob()
  throws
{
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  var (game, _, id) = try fixture.game()
  game.launch()
  let index = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
  game.bodies[index].energy = 30
  game.persistScriptActors()
  #expect(game.commander.scriptState.stationResources[game.contractStation.key]?.energy == 30)
  game.advanceScriptWorldJobs(delta: 0.1)
  let job = game.commander.scriptState.worldJobs[id]
  game.dock()
  game.launch()
  #expect(game.bodies.first { $0.id == 0 }?.energy == 30)
  #expect(game.commander.scriptState.worldJobs[id] == job)
  #expect(game.commander.valid)
}

@Test func invalidWorldJobOwnersCountersHandlersAndForeignEncountersAreRejectedBeforeInstallation()
  throws
{
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  let directory = fixture.root.appendingPathComponent("pack")
  let manifest = directory.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  let replacements = [
    ("handler='maintenance'", "handler='missing'"),
    ("firstDue=0", "firstDue=nan"),
    ("interval=1", "interval=0"),
    ("counters=['opening','reset']", "counters=['opening','opening']"),
    ("controlledEncounters=[]", "controlledEncounters=['foreign']"),
    ("owner='station'", "owner='alien-resource'"),
    ("owner='station'", "owner='actor'"),
    ("\"world-resource-jobs-v2\", ", ""),
    ("\"pulse-counters-v2\", ", ""),
    ("firstDue=0", "unknownField=true\nfirstDue=0"),
  ]
  for (before, after) in replacements {
    try original.replacingOccurrences(of: before, with: after)
      .write(to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(directory) }
  }
}

@Test func failedJobPublicationPreservesPhysicalDamageAndReplaysOnlyTheUncommittedRepair()
  async throws
{
  let fixture = try WorldJobFixture(
    actor: true,
    maintenance: """
      return {data={sequence=e.sequence},commands={
        {op='actor.repair',id='durable-repair',encounter='opponents',actor='lead',amount=20},
        {op='job.finish'}}}
      """)
  defer { fixture.clean() }
  var (game, origin, id) = try fixture.game(actor: true)
  let resource = try #require(game.commander.scriptState.worldJobs[id]?.resource)
  let index = try #require(game.bodies.firstIndex { $0.missionActorID == resource })
  game.bodies[index].energy = 50
  game.persistScriptActors()
  var physical = game
  physical.tick(delta: 0.1, controls: Controls())
  let nativeEnergy = try #require(physical.bodies.first { $0.missionActorID == resource }?.energy)
  let blocked = fixture.root.appendingPathComponent("blocked")
  try Data("blocking file".utf8).write(to: blocked)
  let target = blocked.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: game, saveURL: target)
  let failed = await runtime.advance(delta: 0.1)
  #expect(failed.bodies.first { $0.missionActorID == resource }?.energy == nativeEnergy)
  let pending = try #require(failed.commander.scriptState.worldJobs[id]?.pending)
  #expect(failed.commander.scriptState.worldJobs[id]?.suspension != nil)
  #expect(failed.commander.scriptState.worldJobs[id]?.receipts.isEmpty == true)
  #expect(failed.commander.scriptState.worldJobs[id]?.data == .object([:]))
  #expect(failed.commander.scriptState.instances[origin]?.outcome == .abandoned)
  #expect(failed.commander.credits == game.commander.credits)
  try FileManager.default.removeItem(at: blocked)
  try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
  try await runtime.resumeScriptMission(origin)
  let repaired = await runtime.snapshot()
  #expect(repaired.bodies.first { $0.missionActorID == resource }?.energy == nativeEnergy + 20)
  #expect(repaired.commander.scriptState.worldJobs[id]?.status == .complete)
  #expect(repaired.commander.scriptState.worldJobs[id]?.acknowledgedThrough == pending.sequence)
  let restored = GameRuntime(game: game)
  try await restored.load(from: target)
  #expect(await restored.snapshot().commander == repaired.commander)
  #expect(await restored.snapshot().bodies == repaired.bodies)
}

@Test func worldJobCounterEnableAndResetFollowActualCallbacksRatherThanElapsedSeconds() throws {
  let fixture = try WorldJobFixture(
    maintenance: """
      d.values=d.values or {}; d.values[#d.values+1]=e.counters.opening
      local c={}
      if #d.values==1 then c={{op='job.counter.enable',name='opening',enabled=false}} end
      if #d.values==2 then c={{op='job.counter.enable',name='opening',enabled=true},{op='job.counter.reset',name='opening'}} end
      if #d.values==4 then c={{op='job.finish'}} end
      return {data=d,commands=c}
      """)
  defer { fixture.clean() }
  var (game, _, id) = try fixture.game()
  for _ in 0..<35 { game.advanceScriptWorldJobs(delta: 0.1) }
  #expect(
    game.commander.scriptState.worldJobs[id]?.data["values"]
      == .array([.integer(1), .integer(1), .integer(0), .integer(1)]))
  #expect(game.commander.scriptState.worldJobs[id]?.status == .complete)
  #expect(game.commander.valid)
}

@Test func worldJobClockAndPulseLimitsSuspendWithoutOverflowOrConsumingAnotherPulse() throws {
  for limit in 0..<3 {
    let fixture = try WorldJobFixture()
    defer { fixture.clean() }
    var (game, _, id) = try fixture.game()
    if limit == 0 { game.commander.scriptState.worldJobs[id]?.elapsed = 1e12 }
    if limit == 1 { game.commander.scriptState.worldJobs[id]?.timer.pulses = 1_000_000_000 }
    if limit == 2 { game.commander.scriptState.nextEvent = UInt64(Int64.max) - 1 }
    let before = game.commander.scriptState.worldJobs[id]?.timer.pulses
    game.advanceScriptWorldJobs(delta: 0.1)
    #expect(game.commander.scriptState.worldJobs[id]?.timer.pulses == before)
    #expect(game.commander.scriptState.worldJobs[id]?.suspension?.contains("limit") == true)
    #expect(game.commander.valid)
  }
}

@Test func worldJobTerminalScopeForeignDeploymentAndMistypedCounterBatchesAreAtomic() throws {
  for commands in [
    "{op='job.finish'},{op='job.journal.append',text='too late'}",
    "{op='encounter.ensure',id='foreign'}",
    "{op='job.counter.enable',name='opening',enabled='yes'}",
    "{op='job.counter.reset',name='foreign'}",
  ] {
    let fixture = try WorldJobFixture(
      maintenance: "return {data={changed=true},commands={" + commands + "}}")
    defer { fixture.clean() }
    var (game, origin, id) = try fixture.game()
    let before = game.commander.scriptState.instances[origin]
    game.advanceScriptWorldJobs(delta: 0.1)
    #expect(game.commander.scriptState.worldJobs[id]?.status == .active)
    #expect(game.commander.scriptState.worldJobs[id]?.suspension != nil)
    #expect(game.commander.scriptState.worldJobs[id]?.data == .object([:]))
    #expect(game.commander.scriptState.instances[origin] == before)
    #expect(game.commander.valid)
  }
}

@Test func actualTwoWayHyperspacePreservesTheOriginalStationConditionAndUnloadedJobTime() throws {
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  var (game, _, id) = try fixture.game()
  game.launch()
  let station = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
  game.bodies[station].energy = 30
  game.persistScriptActors()
  let originalSystem = game.commander.system
  let originalStation = try #require(
    game.commander.scriptState.stationResources[game.contractStation.key])
  let destination = try #require(
    game.knownSystems.first {
      $0.id != originalSystem && game.currentSystem.distance(to: $0) <= 7
    })
  game.bodies.removeAll { $0.missionActorID == nil }
  game.celestials = []
  game.selectedSystem = destination.id
  game.beginHyperspace()
  #expect(game.jumpCountdown != nil)
  game.arrive()
  #expect(game.commander.system == destination.id)
  let unloaded = game.commander.scriptState.worldJobs[id]
  game.advanceScriptWorldJobs(delta: 0.1)
  #expect(game.commander.scriptState.worldJobs[id] == unloaded)
  game.dock()
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
  game.purchase()
  #expect(game.commander.fuel == game.commander.fuelCapacity)
  game.launch()
  game.bodies.removeAll { $0.missionActorID == nil }
  game.celestials = []
  game.selectedSystem = originalSystem
  game.beginHyperspace()
  #expect(game.jumpCountdown != nil)
  game.arrive()
  #expect(game.commander.system == originalSystem)
  #expect(game.bodies.first { $0.id == 0 }?.energy == 30)
  #expect(game.commander.scriptState.stationResources[game.contractStation.key] == originalStation)
  #expect(game.commander.scriptState.worldJobs[id] == unloaded)
  #expect(game.commander.valid)
}

@Test(arguments: [false, true])
func firstWorldJobFaultPublicationRetainsDestinationOwnershipAndOnlyAcknowledgesSuccess(
  blocked: Bool
) async throws {
  let fixture = try WorldJobFixture()
  defer { fixture.clean() }
  var (game, origin, id) = try fixture.game()
  game.commander.scriptState.worldJobs[id]?.elapsed = 1e12
  let runtime = GameRuntime(game: game)
  let parent = fixture.root.appendingPathComponent("first-publication")
  let file = parent.appendingPathComponent("commander.json")
  _ = try await runtime.registerNewCommanderDestination(at: file)
  let blocker = Data("writer blocked after registration".utf8)
  if blocked { try blocker.write(to: parent) }
  let before = await runtime.snapshot()
  var expectedJob = try #require(before.commander.scriptState.worldJobs[id])
  expectedJob.suspension = "World job clock limit reached."
  _ = await runtime.advance(delta: 0.1)
  let suspended = await runtime.snapshot()
  #expect(suspended.commander.scriptState.worldJobs[id] == expectedJob)
  #expect(
    suspended.commander.scriptState.instances[origin]
      == before.commander.scriptState.instances[origin])
  #expect(suspended.commander.credits == before.commander.credits)
  #expect(suspended.commander.equipmentInventory == before.commander.equipmentInventory)
  #expect(suspended.commander.salvageLedger == before.commander.salvageLedger)
  #expect(suspended.bodies == before.bodies && suspended.docked == before.docked)
  if blocked {
    #expect(suspended.pendingNewSaveDestination == file)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: parent) == blocker)
    try FileManager.default.removeItem(at: parent)
  } else {
    #expect(suspended.pendingNewSaveDestination == nil)
    let receipt = await runtime.takeNewCommanderSaveReceipt()
    #expect(receipt?.url == file && receipt?.isTrial == false)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: file), from: file)
    #expect(saved.valid && saved.scriptState == suspended.commander.scriptState)
  }
  // Success replaces our own pointer normally; failure retries the still-unpublished destination.
  try await runtime.save(to: file)
  let committed = await runtime.snapshot()
  #expect(committed.pendingNewSaveDestination == nil)
  let receipt = await runtime.takeNewCommanderSaveReceipt()
  #expect(blocked ? receipt?.url == file : receipt == nil)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: file), from: file)
  #expect(saved.valid && saved.scriptState == committed.commander.scriptState)
  #expect(saved.equipmentInventory == committed.commander.equipmentInventory)
}
