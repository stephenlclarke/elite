import Foundation
import Testing

@testable import EliteCore

private func identityPack() throws -> ScriptPack {
  try ScriptPackLibrary.read(
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish"))
}
private func identityGame(_ pack: ScriptPack, origin: UUID) throws -> Game {
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  _ = try game.acceptScriptMission(pack, instanceID: origin)
  game.launch()
  return game
}
private func physicalIDs(_ state: ScriptInstance) -> Set<UUID> {
  Set(
    state.ownedEncounters.values.flatMap { cohort in
      cohort.actors.values.flatMap { actor in
        [actor.identity] + (actor.body.scriptNPC?.components.values.map(\.identity) ?? [])
      }
    })
}

@Test func newOwnedPlansPinRootAndComponentIdentitiesWithoutDrawingSimulationRandomness() throws {
  let pack = try identityPack()
  let origin = UUID()
  let base = try identityGame(pack, origin: origin)
  let random = base.scriptSimulationSave.randomState
  var first = base
  var second = base
  var firstState = try #require(first.commander.scriptState.instances[origin])
  var secondState = try #require(second.commander.scriptState.instances[origin])
  let a = try first.ensureScriptEncounter("opponents", pack: pack, state: &firstState)
  let b = try second.ensureScriptEncounter("opponents", pack: pack, state: &secondState)
  #expect(a.0 == "encounter.admitted" && b.0 == "encounter.admitted")
  #expect(firstState.ownedEncounters == secondState.ownedEncounters)
  #expect(physicalIDs(firstState).count == 4)
  #expect(
    first.scriptSimulationSave.randomState == random
      && second.scriptSimulationSave.randomState == random)
  #expect(first.bodies == second.bodies)
}

@Test func separateMissionOriginsCannotAliasIdenticalModelRootsOrComponents() throws {
  let pack = try identityPack()
  let firstID = UUID()
  let secondID = UUID()
  var first = try identityGame(pack, origin: firstID)
  var second = try identityGame(pack, origin: secondID)
  var a = try #require(first.commander.scriptState.instances[firstID])
  var b = try #require(second.commander.scriptState.instances[secondID])
  _ = try first.ensureScriptEncounter("opponents", pack: pack, state: &a)
  _ = try second.ensureScriptEncounter("opponents", pack: pack, state: &b)
  #expect(physicalIDs(a).isDisjoint(with: physicalIDs(b)))
  #expect(physicalIDs(a).count == 4 && physicalIDs(b).count == 4)
}

@Test func anOlderPreparedPlanKeepsItsOriginalRandomIdentitiesAndConditionWhenEventuallyAdmitted()
  async throws
{
  let pack = try identityPack()
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "old-plan-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  let save = folder.appendingPathComponent("commander.json")
  let origin = UUID()
  var game = try identityGame(pack, origin: origin)
  game.bodies = [try #require(game.bodies.first { $0.id == 0 })]
  for id in 1..<1024 {
    game.bodies.append(
      SpaceBody(id: id, hull: .cargo, position: .init(Double(id) * 30, 10000, 10000)))
  }
  game.nextBodyID = 1024
  var state = try #require(game.commander.scriptState.instances[origin])
  let pending = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  #expect(pending.0 == "encounter.pending")
  var cohort = try #require(state.ownedEncounters["opponents"])
  for alias in cohort.actors.keys {
    let old = try #require(cohort.actors[alias])
    let identity = UUID()
    var body = old.body
    body.missionActorID = identity
    body.energy = 41
    if var npc = body.scriptNPC {
      for component in npc.components.keys {
        let value = try #require(npc.components[component])
        npc.components[component] = .init(identity: UUID(), energy: 16, guns: value.guns)
      }
      body.scriptNPC = npc
    }
    cohort.actors[alias] = .init(identity: identity, alias: alias, body: body, presence: .prepared)
  }
  state.ownedEncounters["opponents"] = cohort
  state.acknowledgedThrough = nil
  state.acknowledgedEvents = [1]
  game.commander.scriptState.instances[origin] = state
  #expect(game.commander.valid)
  let identities = physicalIDs(state)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  var pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: save))
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
  let legacyBytes = try JSONEncoder().encode(game.commander.scriptState)
  try legacyBytes.write(to: directory.appendingPathComponent("missions.json"))
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(legacyBytes)
  pointer = .init(
    format: pointer.format, schemaVersion: 11, generation: pointer.generation,
    hashes: hashes, scope: pointer.scope)
  try JSONEncoder().encode(pointer).write(to: save, options: .atomic)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: save)
  var restored = await loaded.snapshot()
  #expect(restored.commander.scriptState.instances[origin]?.data == state.data)
  restored.bodies.removeAll { $0.hull == .cargo }
  var original = try #require(restored.commander.scriptState.instances[origin])
  let admitted = try restored.ensureScriptEncounter("opponents", pack: pack, state: &original)
  restored.commander.scriptState.instances[origin] = original
  #expect(admitted.0 == "encounter.admitted" && physicalIDs(original) == identities)
  #expect(
    original.ownedEncounters["opponents"]?.actors.values.allSatisfy { $0.body.energy == 41 } == true
  )
  #expect(restored.bodies.filter { $0.missionActorID != nil }.count == 2)
  #expect(restored.commander.valid)
}
