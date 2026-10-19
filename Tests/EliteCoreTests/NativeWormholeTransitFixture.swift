import Foundation
import Testing

@testable import EliteCore

/// Controlled geometry over the installed original-world authority; no synthetic world records.
struct NativeWormholeTransitFixture {
  let storage: NativeStationTestStorage
  let pack: ScriptPack
  init(edits: [(String, String)] = []) throws {
    storage = try NativeStationTestStorage()
    do {
      let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/mission-packs/profiled-skirmish")
      let directory = storage.root.appendingPathComponent("pack")
      try FileManager.default.copyItem(at: original, to: directory)
      let manifest = directory.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: manifest, encoding: .utf8)
      let changes =
        [
          (
            "capabilities = [",
            "capabilities = [\"npc-wormhole-transit-v2\", \"mission-calendar-v2\", \"durable-commands-v2\", \"local-flight-clocks-v2\", "
          ),
          ("fuel = 0.0", "fuel = 7.0"),
          ("hostile=true", "hostile=false"),
          ("[[npcs.components]]\nid = \"turret\"", "[[npcs.components]]\nid = \"drive\""),
          ("title = \"Profiled skirmish demonstration\"", "title = \"Native transit fixture\""),
          (
            "milestones = [\"Accept skirmish\", \"Defeat both assigned ships\", \"Report at Lave orbital station\"]",
            "milestones = [\"Observe native transit\"]"
          ),
          ("requiredDestructionEncounters = [\"opponents\"]", ""),
          (
            "reward = \"100 credits, plus declared native combat bounties.\"",
            "reward = \"No reward; native transit fixture.\""
          ),
          ("x=0.0, y=0.0, z=3000.0", "x=10000.0, y=10000.0, z=3000.0"),
          ("x=1000.0, y=0.0, z=4500.0", "x=12000.0, y=10000.0, z=4500.0"),
          (
            "[[npcs.lasers]]",
            """
            [npcs.drive]
            component = "drive"
            rangeLightYears = 7.0
            activationSeconds = 1.0
            massLockScale = 1.0
            fuelUnit = "native-light-years"

            [[npcs.lasers]]
            """
          ),
        ] + edits
      for (before, after) in changes { text = text.replacingOccurrences(of: before, with: after) }
      text += "\n[[handlers]]\nevent = \"timer.fired\"\nfunction = \"timer\"\n"
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      // Only the model assets are reused. This new fixture declares no combat or reward objective.
      try Self.source.write(
        to: directory.appendingPathComponent("scripts/main.lua"), atomically: true,
        encoding: .utf8)
      pack = try ScriptPackLibrary.read(directory)
    } catch {
      storage.clean()
      throw error
    }
  }
  var publisher: ScriptPublisher {
    let url = storage.url
    return { candidate in try GameRuntime.writeCommander(&candidate, to: url) }
  }
  func game() throws -> (Game, UUID, OriginalWorldJourneyContext) {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = 7
    game.selectedSystem = 7
    try game.commander.prepareEquipment(legacy: false)
    game.scriptDurabilityAvailable = true
    game.scriptPacks = [pack]
    let id = try game.acceptScriptMission(pack, drainAccepted: false)
    game.drainScriptEvents(publish: publisher)
    game.launch()
    game.emitScriptEvent("station.undocked", drain: false)
    game.drainScriptEvents(publish: publisher)
    game.persistScriptActors()
    try #require(
      game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.admitted == true)
    let destination = try #require(
      game.systems.first {
        $0.id != game.commander.system && $0.id != Plugh.systemID
          && game.currentSystem.distance(to: $0) > 0
          && game.currentSystem.distance(to: $0) <= 7
      })
    let key = try #require(destination.original?.key)
    let context = try #require(
      OriginalWorldJourneyContext.production(in: game, destinationWorld: key))
    try #require(context.route.valid)
    try GameRuntime.writeCommander(&game, to: storage.url)
    return (game, id, context)
  }
  func request(
    _ game: inout Game, instance id: UUID, alias: String = "lead", retry: Bool = false,
    destinationWorld: String? = nil
  ) throws -> UUID {
    let state = try #require(game.commander.scriptState.instances[id])
    let actor = try #require(state.ownedEncounters["opponents"]?.actors[alias])
    let destination: String
    if let destinationWorld {
      destination = destinationWorld
    } else {
      destination = try #require(
        game.systems.first {
          $0.id != game.commander.system && $0.id != Plugh.systemID
            && game.currentSystem.distance(to: $0) > 0 && game.currentSystem.distance(to: $0) <= 7
        }?.original?.key)
    }
    _ = try game.requestScriptNPCTransit(
      .object([
        "op": .string(retry ? "actor.transit.retry" : "actor.transit"), "id": .string("journey"),
        "encounter": .string("opponents"), "actor": .string(alias),
        "destination": .string(destination),
      ]), pack: pack, state: state)
    try GameRuntime.writeCommander(&game, to: storage.url)
    return NativeWormholeLeg.identity(instance: id, actor: actor.identity, request: "journey")
  }
  func physicalStep(_ game: inout Game) throws -> NativeWormholeMotionSample {
    let context = try #require(game.gameplayContext())
    let director = try #require(game.commander.encounterDirector)
    try #require(
      director.decisionCount == 0 && director.admittedCount == 0 && director.pendingRequests.isEmpty
    )
    // Maintained resource-fixture pattern: postpone only unconsumed unrelated encounter proposals.
    game.commander.encounterDirector = EncounterDirector(context: context)
    let sample = NativeWormholeMotionSample(game)
    let advanced = game.advanceScriptClockValues(
      delta: 0.1, flight: true, local: true, calendar: true)
    try #require(advanced)
    game.tick(delta: 0.1)
    try #require(!game.paused && !game.docked && game.screen != .gameOver)
    game.persistScriptActors()
    return sample
  }
  func step(_ game: inout Game, context: OriginalWorldJourneyContext) throws {
    try #require(context.matches(game, at: game.systemIdentity))
    let transit = game.commander.scriptState.transitSeconds
    let sample = try physicalStep(&game)
    game.advanceNativeWormholeFrame(from: sample, publish: publisher)
    game.drainScriptEvents(publish: publisher)
    game.fireDueScriptTimers(
      flight: true, local: true, calendar: true,
      transit: game.commander.scriptState.transitSeconds > transit, publish: publisher)
  }
  static let source = """
    local function idle(e,w,d) return {data=d,commands={}} end
    return {
      accepted=function(e,w,d) return {data={transitPulses=0},commands={
        {op='timer.ensure',id='transit',domain='transit',after=1,interval=0,policy='once'}}} end,
      admitted=idle, destroyed=idle, contact=idle, confirm=idle,
      timer=function(e,w,d) d.transitPulses=d.transitPulses+1; return {data=d,commands={}} end,
      undocked=function(e,w,d) return {data=d,commands={{op='encounter.ensure',id='opponents'}}} end
    }
    """
}
