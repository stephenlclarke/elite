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
  for id in 1..<128 {
    game.bodies.append(
      SpaceBody(id: id, hull: .cargo, position: .init(Double(id) * 30, 10000, 10000)))
  }
  game.nextBodyID = 128
  game.ensurePhysicalActors()
  try #require(game.bodies.count == 128 && game.bodies.allSatisfy { $0.physical != nil })
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
  let imported = await loaded.snapshot().commander.scriptState.instances[origin]?
    .ownedEncounters["opponents"]?.legacyProvenance
  try #require(imported?.sourceSchema == 11)
  // The capacity-pending plan must keep its original condition through a modern resave too.
  try await loaded.save(to: save)
  let modern = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: save))
  #expect(modern.schemaVersion == 21)
  let reloaded = GameRuntime(game: game)
  try await reloaded.load(from: save)
  var restored = await reloaded.snapshot()
  #expect(restored.commander.scriptState.instances[origin]?.data == state.data)
  #expect(
    restored.commander.scriptState.instances[origin]?.ownedEncounters["opponents"]?.actors
      == cohort.actors)
  #expect(
    restored.commander.scriptState.instances[origin]?.ownedEncounters["opponents"]?.legacyProvenance
      == imported)
  try assertHistoricalIdentityForgeryRollback(
    commander: restored.commander, world: restored.scriptWorldSave, owner: origin, save: save)
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
  #expect(
    original.ownedEncounters["opponents"]?.actors.values.allSatisfy {
      $0.body.scriptNPC?.components.values.allSatisfy { $0.energy == 16 } == true
    } == true)
  #expect(
    original.ownedEncounters["opponents"]?.legacyProvenance?.actors.values.allSatisfy {
      $0.prepared == nil
    } == true)
  // A genuine player laser changes the admitted condition without changing historical lineage.
  let lead = try #require(
    restored.bodies.first { $0.missionActorID == cohort.actors["lead"]?.identity })
  try #require(lead.position.z > 0 && lead.energy == 41)
  restored.fireLaser()
  let damaged = try #require(restored.bodies.first { $0.missionActorID == lead.missionActorID })
  try #require(damaged.energy > 0 && damaged.energy < lead.energy)
  let admittedRuntime = GameRuntime(game: restored)
  try await admittedRuntime.save(to: save)
  let finalRuntime = GameRuntime(game: restored)
  try await finalRuntime.load(from: save)
  let final = await finalRuntime.snapshot()
  let finalState = try #require(final.commander.scriptState.instances[origin])
  #expect(physicalIDs(finalState) == identities)
  #expect(finalState.ownedEncounters["opponents"]?.actors["lead"]?.body.energy == damaged.energy)
  #expect(final.bodies.first { $0.missionActorID == lead.missionActorID }?.energy == damaged.energy)
  #expect(finalState.data == state.data && final.commander.valid)
}

private func identitySaveFiles(_ root: URL) throws -> [String: Data] {
  var files: [String: Data] = [:]
  for name in try FileManager.default.subpathsOfDirectory(atPath: root.path) {
    let url = root.appendingPathComponent(name)
    if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
      files[name] = try Data(contentsOf: url)
    }
  }
  return files
}

private func assertHistoricalIdentityForgeryRollback(
  commander: Commander, world: ScriptWorldSave, owner: UUID, save: URL
) throws {
  let receipt = try #require(
    commander.scriptState.instances[owner]?.ownedEncounters["opponents"]?.legacyProvenance)
  let bytes = try JSONEncoder().encode(receipt)
  let root = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  let actors = try #require(root["actors"] as? [String: Any])
  let lead = try #require(actors["lead"] as? [String: Any])
  let files = try identitySaveFiles(save.deletingLastPathComponent())
  for change in 0..<8 {
    var forged = root
    var changedActors = actors
    var changedLead = lead
    switch change {
    case 0: forged["instanceID"] = UUID().uuidString
    case 1: forged["digest"] = String(repeating: "b", count: 64)
    case 2: forged["version"] = "9.9.9"
    case 3: forged["encounterID"] = "other"
    case 4:
      changedActors["other"] = changedActors.removeValue(forKey: "lead")
      forged["actors"] = changedActors
    case 5:
      changedLead["identity"] = UUID().uuidString
      changedActors["lead"] = changedLead
      forged["actors"] = changedActors
    case 6:
      var components = try #require(changedLead["components"] as? [String: Any])
      let component = try #require(components.keys.first)
      components[component] = UUID().uuidString
      changedLead["components"] = components
      changedActors["lead"] = changedLead
      forged["actors"] = changedActors
    default:
      var snapshot = try #require(changedLead["prepared"] as? [String: Any])
      var body = try #require(snapshot["body"] as? [String: Any])
      body["energy"] = 40
      snapshot["body"] = body
      changedLead["prepared"] = snapshot
      changedActors["lead"] = changedLead
      forged["actors"] = changedActors
    }
    let decoder = JSONDecoder()
    decoder.userInfo[LegacyMissionEncounterProvenance.storageKey] = true
    let decoded = try decoder.decode(
      LegacyMissionEncounterProvenance.self, from: JSONSerialization.data(withJSONObject: forged))
    var candidate = commander
    candidate.scriptState.instances[owner]?.ownedEncounters["opponents"]?.legacyProvenance = decoded
    #expect(!candidate.valid)
    #expect(throws: SaveError.self) {
      try ScriptSaveStore.write(commander: candidate, world: world, to: save)
    }
    #expect(
      candidate.scriptState.instances[owner]?.ownedEncounters["opponents"]?.legacyProvenance
        == decoded)
    #expect(try identitySaveFiles(save.deletingLastPathComponent()) == files)
  }
  #expect(throws: SaveError.self) {
    _ = try JSONDecoder().decode(LegacyMissionEncounterProvenance.self, from: bytes)
  }
  for change in 0..<4 {
    var oversized = root
    var changedLead = lead
    switch change {
    case 0: oversized["sourceSchema"] = 12
    case 1:
      oversized["actors"] = Dictionary(
        uniqueKeysWithValues: (0..<129).map { ("actor\($0)", NSNull()) })
    case 2:
      changedLead["components"] = Dictionary(
        uniqueKeysWithValues: (0..<33).map { ("part\($0)", NSNull()) })
      oversized["actors"] = ["lead": changedLead]
    default:
      var snapshot = try #require(changedLead["prepared"] as? [String: Any])
      var body = try #require(snapshot["body"] as? [String: Any])
      var npc = try #require(body["scriptNPC"] as? [String: Any])
      npc["components"] = Dictionary(uniqueKeysWithValues: (0..<33).map { ("part\($0)", NSNull()) })
      body["scriptNPC"] = npc
      snapshot["body"] = body
      changedLead["prepared"] = snapshot
      oversized["actors"] = ["lead": changedLead]
    }
    let decoder = JSONDecoder()
    decoder.userInfo[LegacyMissionEncounterProvenance.storageKey] = true
    let data = try JSONSerialization.data(withJSONObject: oversized)
    #expect(throws: SaveError.self) {
      _ = try decoder.decode(LegacyMissionEncounterProvenance.self, from: data)
    }
    #expect(try identitySaveFiles(save.deletingLastPathComponent()) == files)
  }
  #expect(commander.valid)
}

@Test(arguments: 0..<4)
func currentPreparedPlansStillRejectRandomIdentitiesAndSpentConditionWithoutMigration(change: Int)
  throws
{
  let pack = try identityPack()
  let origin = UUID()
  var game = try identityGame(pack, origin: origin)
  game.bodies = [try #require(game.bodies.first { $0.id == 0 })]
  for id in 1..<128 {
    game.bodies.append(.init(id: id, hull: .cargo, position: .init(Double(id) * 30, 10000, 10000)))
  }
  game.nextBodyID = 128
  game.ensurePhysicalActors()
  var state = try #require(game.commander.scriptState.instances[origin])
  let pending = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  try #require(pending.0 == "encounter.pending")
  var encounter = try #require(state.ownedEncounters["opponents"])
  try #require(encounter.legacyProvenance == nil)
  var actor = try #require(encounter.actors["lead"])
  if change == 0 {
    let identity = UUID()
    actor.body.missionActorID = identity
    actor = .init(
      identity: identity, alias: actor.alias, body: actor.body, presence: actor.presence)
  } else if change == 1 {
    let part = try #require(actor.body.scriptNPC?.components.keys.first)
    let old = try #require(actor.body.scriptNPC?.components[part])
    actor.body.scriptNPC?.components[part] = .init(
      identity: UUID(), energy: old.energy, guns: old.guns)
  } else if change == 2 {
    actor.body.energy = 41
  } else {
    let part = try #require(actor.body.scriptNPC?.components.keys.first)
    actor.body.scriptNPC?.components[part]?.energy = 16
  }
  encounter.actors["lead"] = actor
  state.ownedEncounters["opponents"] = encounter
  game.commander.scriptState.instances[origin] = state
  game.bodies.removeAll { $0.hull == .cargo }
  let beforeCommander = game.commander
  let beforeBodies = game.bodies
  let beforeNext = game.nextBodyID
  let beforeState = state
  #expect(throws: (any Error).self) {
    _ = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  }
  #expect(game.commander == beforeCommander && game.bodies == beforeBodies)
  #expect(game.nextBodyID == beforeNext && state == beforeState)
}

@Test func anOversizedLegacySnapshotMigrationPreservesTheActualCommanderAndEverySavedFile()
  async throws
{
  let pack = try identityPack()
  let origin = UUID()
  var game = try identityGame(pack, origin: origin)
  game.bodies = [try #require(game.bodies.first { $0.id == 0 })]
  for id in 1..<128 {
    game.bodies.append(.init(id: id, hull: .cargo, position: .init(Double(id) * 30, 10000, 10000)))
  }
  game.nextBodyID = 128
  game.ensurePhysicalActors()
  var state = try #require(game.commander.scriptState.instances[origin])
  let pending = try game.ensureScriptEncounter("opponents", pack: pack, state: &state)
  try #require(pending.0 == "encounter.pending")
  game.commander.scriptState.instances[origin] = state
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "legacy-size-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  let save = folder.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  let before = await runtime.snapshot()
  var padded = before.commander
  for _ in 0..<6 {
    var padding = ScriptInstance(
      id: UUID(), definition: state.definition, version: state.version, digest: state.digest)
    padding.journal = [String](repeating: String(repeating: "x", count: 12000), count: 450)
    padded.scriptState.instances[padding.id] = padding
  }
  var tail = ScriptInstance(
    id: UUID(), definition: state.definition, version: state.version, digest: state.digest)
  padded.scriptState.instances[tail.id] = tail
  let encoder = JSONEncoder()
  let maximum = 33_554_432
  var remaining = maximum - 64 - (try encoder.encode(padded.scriptState).count)
  try #require(remaining > 0)
  while remaining > 3 {
    let overhead = tail.journal.isEmpty ? 2 : 3
    let count = min(12000, remaining - overhead)
    tail.journal.append(String(repeating: "x", count: count))
    remaining -= count + overhead
  }
  padded.scriptState.instances[tail.id] = tail
  try #require(padded.valid && tail.journal.count <= 512)
  let legacyBytes = try encoder.encode(padded.scriptState)
  try #require(legacyBytes.count <= maximum && legacyBytes.count >= maximum - 67)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: save))
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
  try legacyBytes.write(to: directory.appendingPathComponent("missions.json"), options: .atomic)
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(legacyBytes)
  let old = ScriptSavePointer(
    format: pointer.format, schemaVersion: 11, generation: pointer.generation,
    hashes: hashes, scope: pointer.scope)
  try encoder.encode(old).write(to: save, options: .atomic)
  let files = try identitySaveFiles(folder)
  await #expect(throws: SaveError.self) { try await runtime.load(from: save) }
  let after = await runtime.snapshot()
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.time == before.time && after.screen == before.screen && after.speed == before.speed)
  #expect(
    after.energy == before.energy && after.frontShield == before.frontShield
      && after.rearShield == before.rearShield)
  #expect(after.nextBodyID == before.nextBodyID && after.jumpCountdown == before.jumpCountdown)
  #expect(try identitySaveFiles(folder) == files)
}
