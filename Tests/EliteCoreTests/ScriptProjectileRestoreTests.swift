import Foundation
import Testing

@testable import EliteCore

private func withArchive(_ shot: ScriptNPCShot, _ archive: MissionLaunchArchive?) -> ScriptNPCShot {
  .init(
    identity: shot.identity, owner: shot.owner, instance: shot.instance, weapon: shot.weapon,
    component: shot.component, velocity: shot.velocity, age: shot.age, lifetime: shot.lifetime,
    damage: shot.damage, radius: shot.radius, collisionDelay: shot.collisionDelay,
    nativeAttribution: archive)
}

private func retainedProjectileGame(archived: Bool = true) throws -> (Game, UUID) {
  var (game, sample) = try actualShotArchiveFixture()
  let anchor = try #require(game.scriptAnchor)
  var shot = withArchive(sample, archived ? sample.nativeAttribution : nil)
  shot.velocity = anchor.orientation.inverse(sample.velocity)
  shot.age = 0.37
  // A retained canonical save value, not an admitted physical body or allocator receipt.
  var body = SpaceBody(id: 900_000_000, hull: .missile, position: .init(0, 200, 2500))
  body.scriptShot = shot
  game.commander.scriptState.projectiles[shot.identity] = .init(
    galaxy: game.commander.galaxy, system: game.commander.system, body: body, presence: .unloaded)
  try #require(game.commander.valid)
  return (game, shot.identity)
}

private func projectileSaveFolder() throws -> URL {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "projectile-restore-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  return root
}

struct ScriptProjectileRestoreTests {
  @Test(arguments: ["owner", "component"])
  func retainedSourceMismatchFailsBeforeNativeAllocationOrAnyActorRestoration(field: String) throws
  {
    var (game, id) = try retainedProjectileGame()
    let shot = try #require(game.commander.scriptState.projectiles[id]?.body.scriptShot)
    var instance = try #require(game.commander.scriptState.instances[shot.instance])
    var encounter = try #require(instance.ownedEncounters["opponents"])
    let old = try #require(encounter.actors["lead"])
    var body = old.body
    let identity: UUID
    if field == "owner" {
      identity = UUID()
      body.missionActorID = identity
    } else {
      identity = old.identity
      let component = try #require(body.scriptNPC?.components["turret"])
      body.scriptNPC?.components["turret"] = .init(
        identity: UUID(), energy: component.energy, guns: component.guns)
    }
    let altered = ScriptOwnedActor(
      identity: identity, alias: old.alias, body: body, presence: old.presence,
      destroyedByPlayer: old.destroyedByPlayer)
    try #require(altered.valid)
    encounter.actors["lead"] = altered
    instance.ownedEncounters["opponents"] = encounter
    game.commander.scriptState.instances[shot.instance] = instance
    game.bodies.removeAll { $0.missionActorID != nil }
    let before = game.commander
    let bodies = game.bodies
    let next = game.nextBodyID
    #expect(
      !game.commander.scriptState.projectileArchiveValid(
        try #require(game.commander.scriptState.projectiles[id])))
    #expect(throws: NativeMissionProjectileAdmissionError.invalidRecord) {
      try game.admitRetainedMissionProjectile(id)
    }
    #expect(throws: NativeMissionProjectileAdmissionError.invalidRecord) {
      try game.restoreScriptActors()
    }
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == next)
  }

  @Test(arguments: [false, true])
  func format21RuntimeRestoresThroughNativeAdmissionOnceAndRetainsExactShotHistory(archived: Bool)
    async throws
  {
    let root = try projectileSaveFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("commander.json")
    var (game, id) = try retainedProjectileGame(archived: archived)
    let original = try #require(game.commander.scriptState.projectiles[id]?.body.scriptShot)
    try GameRuntime.writeCommander(&game, to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 21)
    let runtime = GameRuntime(game: game)
    try await runtime.load(from: file)
    try #require(await runtime.snapshot().bodies.allSatisfy { $0.scriptShot?.identity != id })
    // Zero physical time still takes the real runtime restoration path without moving the shot.
    let restored = await runtime.advance(delta: 0)
    let body = try #require(restored.bodies.first { $0.scriptShot?.identity == id })
    let shot = try #require(body.scriptShot)
    let physical = try #require(body.physical)
    let saved = try #require(restored.commander.scriptState.projectiles[id])
    let anchor = try #require(restored.scriptAnchor)
    #expect(body.id != 900_000_000 && saved.body.id == body.id && saved.presence == .present)
    #expect(
      physical.population == .projectile
        && physical.identity.system == restored.commander.flightSimulation.player?.system)
    #expect(physical.identity.visit == restored.commander.flightSimulation.player?.visit)
    #expect(
      shot.identity == id && shot.owner == original.owner && shot.instance == original.instance)
    #expect(shot.component == original.component && shot.weapon == original.weapon)
    #expect(
      shot.age == original.age && shot.lifetime == original.lifetime
        && shot.damage == original.damage)
    #expect(shot.radius == original.radius && shot.collisionDelay == original.collisionDelay)
    #expect((shot.velocity - anchor.orientation.apply(original.velocity)).length < 1e-8)
    #expect(shot.nativeAttribution == original.nativeAttribution)
    #expect(physical.attackOrigin == original.nativeAttribution?.origin)
    let again = await runtime.advance(delta: 0)
    #expect(again.bodies.filter { $0.scriptShot?.identity == id }.count == 1)
    #expect(
      again.bodies.first { $0.scriptShot?.identity == id }?.physical?.identity == physical.identity)
    #expect(again.nextBodyID == restored.nextBodyID)
    #expect(again.commander.flightSimulation == restored.commander.flightSimulation)
    try await runtime.save(to: file)
    let next = GameRuntime(game: game)
    try await next.load(from: file)
    let loaded = await next.snapshot()
    let reloaded = try #require(loaded.bodies.first { $0.scriptShot?.identity == id }?.scriptShot)
    #expect(reloaded == again.bodies.first { $0.scriptShot?.identity == id }?.scriptShot)
    #expect(reloaded.nativeAttribution == original.nativeAttribution)
    #expect(loaded.commander.scriptState.projectiles[id]?.presence == .present)
  }

  @Test(arguments: ["pack", "outside", "allocator"])
  func temporaryRestorationRefusalsKeepRetainedShotAndAllocatorsPending(reason: String) async throws
  {
    var (game, id) = try retainedProjectileGame()
    if reason == "pack" {
      game.scriptPacks = []
    } else if reason == "outside" {
      game.commander.scriptState.projectiles[id]?.body.position = .init(100_000, 0, 0)
    } else {
      game.nextBodyID = 999_999_999
    }
    let record = try #require(game.commander.scriptState.projectiles[id])
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    let after = await runtime.advance(delta: 0)
    #expect(after.commander.scriptState.projectiles[id] == record)
    #expect(after.bodies.allSatisfy { $0.scriptShot?.identity != id })
    #expect(after.nextBodyID == before.nextBodyID)
    #expect(after.commander.flightSimulation == before.commander.flightSimulation)
  }

  @Test func malformedPresentArchiveInHashedFormat21RefusesLoadWithoutPublishingOrRewriting()
    async throws
  {
    let root = try projectileSaveFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("commander.json")
    var (game, id) = try retainedProjectileGame()
    try GameRuntime.writeCommander(&game, to: file)
    let runtime = GameRuntime(game: game)
    try await runtime.load(from: file)
    _ = await runtime.advance(delta: 0)
    let before = await runtime.snapshot()
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let missions = directory.appendingPathComponent("missions.json")
    var engine = game.commander.scriptState
    let shot = try #require(engine.projectiles[id]?.body.scriptShot)
    let archive = try #require(shot.nativeAttribution)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
    object["packDigest"] = String(repeating: "f", count: 64)
    let mismatched = try JSONDecoder().decode(
      MissionLaunchArchive.self, from: JSONSerialization.data(withJSONObject: object))
    engine.projectiles[id]?.body.scriptShot = withArchive(shot, mismatched)
    try #require(!engine.valid)
    let changed = try ScriptValueStorage.encoder().encode(engine)
    try changed.write(to: missions)
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(changed)
    let malformed = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
      hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    let bytes = try JSONEncoder().encode(malformed)
    try bytes.write(to: file)
    await #expect(throws: SaveError.self) { try await runtime.load(from: file) }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(try Data(contentsOf: file) == bytes && Data(contentsOf: missions) == changed)
  }
}
