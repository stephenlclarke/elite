import Foundation
import Testing

@testable import EliteCore

private var npcExample: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/profiled-skirmish")
}
private struct NPCFixture {
  let root: URL
  var directory: URL { root.appendingPathComponent("pack") }
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(edits: [(String, String)] = [], source: String? = nil) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent("npc-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: npcExample, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    for (a, b) in edits { text = text.replacingOccurrences(of: a, with: b) }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    if let source {
      try source.write(
        to: directory.appendingPathComponent("scripts/main.lua"), atomically: true,
        encoding: .utf8)
    }
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game(launch: Bool = true) throws -> (Game, UUID) {
    let pack = try ScriptPackLibrary.read(directory)
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let id = try game.acceptScriptMission(pack)
    if launch {
      game.launch()
      game.emitScriptEvent("station.undocked")
      game.drainScriptEvents()
    }
    return (game, id)
  }
}
private func npcIndex(_ game: Game, _ id: UUID, _ alias: String = "lead") throws -> Int {
  let identity = try #require(
    game.commander.scriptState.instances[id]?
      .ownedEncounters["opponents"]?.actors[alias]?.identity)
  return try #require(game.bodies.firstIndex { $0.missionActorID == identity })
}
private func npcIntent(
  _ mode: String, request: String = "test", target: String? = nil,
  offset: Vector3 = .init(0, 0, 0), speed: Double = 1, tolerance: Double = 10
) -> ScriptValue {
  var fields: [String: ScriptValue] = [
    "op": .string("actor.intent"), "id": .string(request),
    "encounter": .string("opponents"), "actor": .string("lead"), "mode": .string(mode),
    "offset": .array([.number(offset.x), .number(offset.y), .number(offset.z)]),
    "speed": .number(speed), "tolerance": .number(tolerance),
  ]
  if let target { fields["target"] = .string(target) }
  return .object(fields)
}
private func setNPCIntent(_ game: inout Game, id: UUID, command: ScriptValue) throws {
  var state = try #require(game.commander.scriptState.instances[id])
  let pack = try #require(game.scriptPack(for: state))
  _ = try game.applyScriptNPCIntent(command, pack: pack, state: &state)
  game.commander.scriptState.instances[id] = state
}

@Test func profiledShipsAdmitActualModelsComponentsAndSourceZerosWithoutPlayerDefaults() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  let (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  let npc = try #require(game.bodies[index].scriptNPC)
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.admitted == true)
  #expect(game.bodies[index].missiles == 0 && !game.bodies[index].ecmEnabled && npc.fuel == 0)
  #expect(npc.fit.definition.energy == 120 && npc.components["turret"]?.energy == 40)
  #expect(game.commander.scriptState.geometry.count == 2)
  #expect(game.bodies.filter { $0.scriptNPC != nil }.count == 2)
  #expect(game.bodies.filter { $0.scriptNPC != nil }.map(\.scriptNativeUnits) == [2, 2])
  let mesh = try #require(game.scriptNPCMesh(game.bodies[index]))
  #expect(mesh.vertices.count == 16 && mesh.faces.count == 12)
  #expect(
    mesh.materials.count == 2
      && mesh.faceMaterials == Array(repeating: 0, count: 6) + Array(repeating: 1, count: 6))
  #expect(mesh.vertices[0] == .init(-40, -20, -60))
  #expect(mesh.vertices[8] == .init(-6, 22, -9))
  #expect(game.commander.valid)
}

@Test func licensedModelBytesInstallImmutablyAndTamperingLinksOrMissingGeometryAreDenied() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  let pack = try ScriptPackLibrary.read(fixture.directory)
  let installed = try ScriptPackLibrary.install(
    pack, directory: fixture.root.appendingPathComponent("library"))
  #expect(try ScriptPackLibrary.read(installed).digest == pack.digest)
  #expect(
    try ScriptPackLibrary.install(pack, directory: fixture.root.appendingPathComponent("library"))
      == installed)
  let model = fixture.directory.appendingPathComponent("models/hull.json")
  let original = try Data(contentsOf: model)
  try Data("{}".utf8).write(to: model)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
  try FileManager.default.removeItem(at: model)
  let elsewhere = fixture.root.appendingPathComponent("elsewhere.json")
  try original.write(to: elsewhere)
  try FileManager.default.createSymbolicLink(at: model, withDestinationURL: elsewhere)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
  try FileManager.default.removeItem(at: model)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
}

@Test func npcManifestRejectsUnknownKeysUnboundedFitsAndUndeclaredCapability() throws {
  for edits in [
    [("\"profiled-encounters-v2\", ", "")],
    [("energy = 120.0", "energy = -1.0")],
    [("missiles = 0", "missiles = 33")],
    [("scale = 1.0", "scale = 1000000.0")],
    [("trackingRate = 2.0", "trackingRate = -1.0")],
    [("speed = 100.0", "teleport = true\nspeed = 100.0")],
    [("npc=\"training-craft\"", "npc=\"missing\"")],
    [("collisionDelay = 0.05", "collisionDelay = 3.0")],
    [("muzzle = {x=0.0,y=0.0,z=61.0}", "muzzle = {x=0.0,y=0.0,z=61.0,q=4}")],
  ] {
    let fixture = try NPCFixture(edits: edits)
    defer { fixture.clean() }
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
  }
}

@Test func nativeFlightRequestsPreserveIdentityAndReachActualCoordinatesWithBoundedAcceleration()
  throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  let original = game.bodies[index]
  let goal = Vector3(0, 0, 3500)
  try setNPCIntent(&game, id: id, command: npcIntent("approach", offset: goal))
  let pack = try #require(game.scriptPacks.first)
  var state = try #require(game.commander.scriptState.instances[id])
  #expect(
    try game.applyScriptNPCIntent(npcIntent("flee", target: "player"), pack: pack, state: &state)
      == nil)
  #expect(game.bodies[index].scriptNPC?.intent?.mode == .approach)
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect(abs((game.bodies[index].scriptNPC?.velocity.length ?? 0) - 5) < 1e-8)
  #expect((game.bodies[index].position - original.position).length <= 0.5 + 1e-8)
  for _ in 0..<200 { game.advanceScriptNPCFlight(delta: 0.1) }
  let station = try #require(game.bodies.first { $0.id == 0 })
  let actual = station.orientation.inverse(game.bodies[index].position - station.position)
  #expect((actual - goal).length <= 10.1)
  #expect(game.bodies[index].missionActorID == original.missionActorID)
  #expect(game.bodies[index].scriptNPC?.intent?.status == .reached)
  #expect(game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.arrived" }.count == 1)
  game.persistScriptActors()
  #expect(game.commander.valid)
}

@Test func followingAndFleeingUseTheSameOwnedTargetAndForeignOrMalformedIntentsCannotMoveShips()
  throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  try setNPCIntent(
    &game, id: id, command: npcIntent("follow", target: "wing", offset: .init(100, 0, 0)))
  for _ in 0..<30 { game.advanceScriptNPCFlight(delta: 0.1) }
  #expect(game.bodies[index].scriptNPC?.velocity.length ?? 0 > 0)
  #expect(game.bodies[index].orientation.validRotation)
  try setNPCIntent(&game, id: id, command: npcIntent("flee", request: "flee", target: "player"))
  for _ in 0..<40 { game.advanceScriptNPCFlight(delta: 0.1) }
  #expect(game.bodies[index].scriptNPC?.intent?.mode == .flee)
  let before = game.bodies
  #expect(throws: (any Error).self) {
    try setNPCIntent(&game, id: id, command: npcIntent("follow", request: "bad", target: "foreign"))
  }
  #expect(throws: (any Error).self) {
    try setNPCIntent(&game, id: id, command: npcIntent("approach", request: "bad", speed: 2))
  }
  #expect(game.bodies == before)
  let wing = try npcIndex(game, id, "wing")
  try setNPCIntent(&game, id: id, command: npcIntent("attack", request: "lost", target: "wing"))
  game.bodies[wing].energy = 0
  game.advanceScriptNPCFlight(delta: 0.1)
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect(game.bodies[index].scriptNPC?.intent?.status == .lost)
  #expect(
    game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.target.lost" }.count == 1)
}

@Test func componentRayHitsUseMeasuredGeometryAndCannotBecomeHullDeathOrPlayerBounty() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  game.bodies[index].position = .init(0, 0, 2000)
  game.bodies[index].orientation = Basis3()
  let kills = game.commander.kills
  let hit = try #require(
    game.scriptNPCHit(from: .init(0, 25, 0), direction: .init(0, 0, 1), range: 3000))
  #expect(hit.body == index && hit.component == "turret" && abs(hit.distance - 1991) < 1e-8)
  let component = try #require(game.bodies[index].scriptNPC?.components["turret"]?.identity)
  game.damageScriptNPC(hit, amount: 40, player: true, attacker: nil)
  #expect(game.bodies[index].energy == 120)
  #expect(game.bodies[index].scriptNPC?.components["turret"]?.energy == 0)
  #expect(game.scriptNPCMesh(game.bodies[index])?.faces.count == 6)
  #expect(
    game.commander.scriptState.pendingEvents.filter { $0.kind == "component.destroyed" }.count == 1)
  #expect(
    game.commander.scriptState.pendingEvents.last?.values["component_id"]
      == .string(component.uuidString))
  #expect(game.scriptNPCHit(from: .init(0, 25, 0), direction: .init(0, 0, 1), range: 3000) == nil)
  // A ray through the bounding sphere but outside the measured hull must miss.
  #expect(game.scriptNPCHit(from: .init(50, 0, 0), direction: .init(0, 0, 1), range: 3000) == nil)
  let hull = try #require(
    game.scriptNPCHit(from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 3000))
  #expect(hull.component == nil && abs(hull.distance - 1940) < 1e-8)
  let ally = try #require(game.bodies[try npcIndex(game, id, "wing")].missionActorID)
  game.damageScriptNPC(hull, amount: 120, player: false, attacker: ally)
  game.resolveDestroyed()
  #expect(game.commander.kills == kills)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors["lead"]?.presence
      == .destroyed)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.destroyed == false)
}

private func aimNPCAtPlayer(_ game: inout Game, id: UUID) throws -> Int {
  let index = try npcIndex(game, id)
  game.bodies[index].position = .init(0, 0, 1000)
  var facing = Basis3()
  facing.rotate(pitch: 0, roll: 0, yaw: .pi)
  game.bodies[index].orientation = facing
  try setNPCIntent(
    &game, id: id,
    command: npcIntent("attack", request: "fire-test", target: "player", speed: 0))
  return index
}

@Test func npcLasersAndPlasmaSpendActualEnergyHeatAndCooldownAndDamageRealColliders() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try aimNPCAtPlayer(&game, id: id)
  let shield = game.frontShield
  game.advanceScriptNPCWeapons(delta: 0.1)
  #expect(game.frontShield == shield - 6)
  #expect(game.bodies[index].energy == 119.5)
  #expect(game.bodies[index].scriptNPC?.guns["forward"]?.heat == 3.2)
  #expect(game.bodies[index].scriptNPC?.shots == 2)
  #expect(game.bodies.filter { $0.scriptShot != nil }.count == 1)
  let projectile = try #require(game.bodies.first { $0.scriptShot != nil })
  #expect(abs((projectile.scriptShot?.velocity.length ?? 0) - 2000) < 1e-8)
  #expect(projectile.scriptShot?.damage == 15 && projectile.scriptShot?.lifetime == 3)
  for _ in 0..<5 { game.advanceScriptNPCShots(delta: 0.1) }
  #expect(game.frontShield == shield - 21)
  game.resolveDestroyed()
  #expect(!game.bodies.contains { $0.scriptShot != nil })
  game.bodies[index].energy = 0.4
  let shots = game.bodies[index].scriptNPC?.shots
  game.advanceScriptNPCWeapons(delta: 0.1)
  // Zero-cost turret can fire, but the energy-costing forward laser cannot.
  #expect(game.bodies[index].scriptNPC?.guns["forward"]?.cooldown == 0)
  #expect(game.bodies[index].energy == 0.4)
  #expect(game.bodies[index].scriptNPC?.shots == shots)
}

@Test func plasmaHitsTheActualInterveningShipAndECMCannotDestroyOrClaimPlasma() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  _ = try aimNPCAtPlayer(&game, id: id)
  let wing = try npcIndex(game, id, "wing")
  game.bodies[wing].position = .init(0, 25, 700)
  game.bodies[wing].orientation = Basis3()
  let shield = game.frontShield
  game.advanceScriptNPCWeapons(delta: 0.1)
  game.commander.equipment.insert("E.C.M. System")
  game.ecm()
  #expect(game.bodies.contains { $0.scriptShot != nil })
  for _ in 0..<3 { game.advanceScriptNPCShots(delta: 0.1) }
  #expect(game.bodies[wing].energy == 105)
  #expect(game.frontShield == shield - 6)
  for _ in 0..<32 { game.ecmControl.advance() }
  #expect(
    !game.ecmControl.events.contains {
      if case .missilesDestroyed = $0.announcement { true } else { false }
    })
}

@Test func profiledConditionAndLiveProjectilesSurviveCameraSaveAndDockWithoutConstructorRefill()
  async throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try aimNPCAtPlayer(&game, id: id)
  game.advanceScriptNPCWeapons(delta: 0.1)
  game.advanceScriptNPCShots(delta: 0.1)
  game.bodies[index].scriptNPC?.components["turret"]?.energy = 17
  game.bodies[index].scriptNPC?.velocity = .init(5, 0, 0)
  game.bodies[index].energy = 97
  let identity = game.bodies[index].missionActorID
  let shot = try #require(game.bodies.first { $0.scriptShot != nil }?.scriptShot)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let saved = await runtime.snapshot()
  #expect(saved.commander.valid && saved.scriptWorldSave.consistent(with: saved.commander))
  let restored = GameRuntime(game: game)
  try await restored.load(from: fixture.save)
  let loaded = await restored.snapshot()
  #expect(loaded.bodies == saved.bodies)
  #expect(loaded.commander.scriptState == saved.commander.scriptState)
  var docked = loaded
  docked.dock()
  #expect(docked.commander.scriptState.projectiles[shot.identity]?.presence == .unloaded)
  let before = docked.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[
    "lead"]?.body
  docked.launch()
  let resumed = try npcIndex(docked, id)
  #expect(docked.bodies[resumed].missionActorID == identity)
  #expect(docked.bodies[resumed].energy == 97)
  #expect(docked.bodies[resumed].scriptNPC?.components["turret"]?.energy == 17)
  #expect(docked.bodies[resumed].scriptNPC?.shots == before?.scriptNPC?.shots)
  #expect(docked.bodies.first { $0.scriptShot?.identity == shot.identity }?.scriptShot?.age == 0.1)
  #expect(docked.commander.valid)
}

@Test func wholeProfiledCohortCountsSolidComponentsAndRetainsThePreparedPlanWhileBlocked() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game(launch: false)
  game.launch()
  let station = try #require(game.bodies.first { $0.id == 0 })
  game.bodies.append(
    .init(
      id: 98, hull: .asteroid,
      position: station.position + station.orientation.apply(.init(0, 0, 3000))))
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let prepared = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"])
  #expect(!prepared.admitted && prepared.actors.values.allSatisfy { $0.presence == .prepared })
  #expect(!game.bodies.contains { $0.scriptNPC != nil })
  let identities = prepared.actors.mapValues(\.identity)
  let components = prepared.actors.mapValues { $0.body.scriptNPC?.components["turret"]?.identity }
  game.bodies =
    [station]
    + (1...1020).map { SpaceBody(id: $0 + 100, hull: .cargo, position: .init(100000, 0, 0)) }
  game.nextBodyID = 2000
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  #expect(!game.bodies.contains { $0.scriptNPC != nil })
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors.mapValues(
      \.identity) == identities)
  game.bodies = [station]
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.admitted == true)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors.mapValues(
      \.identity) == identities)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors.mapValues {
      $0.body.scriptNPC?.components["turret"]?.identity
    } == components)
}

@Test func rejectedLaterCommandCannotLeakProfileModelsBodiesIntentsOrMoney() throws {
  let fixture = try NPCFixture(
    source: """
      local M={}
      function M.accepted(e,w,d) return {data=d,commands={}} end
      function M.undocked(e,w,d) return {data=d,commands={{op='encounter.ensure',id='opponents'},
        {op='actor.intent',id='move',encounter='opponents',actor='lead',mode='attack',target='player',offset={0,0,0},speed=1,tolerance=100},
        {op='credits',id='overspend',amount=-100000}}} end
      function M.admitted(e,w,d) return {data=d,commands={}} end
      function M.destroyed(e,w,d) return {data=d,commands={}} end
      function M.contact(e,w,d) return {data=d,commands={}} end
      function M.confirm(e,w,d) return {data=d,commands={}} end
      return M
      """
  )
  defer { fixture.clean() }
  var (game, id) = try fixture.game(launch: false)
  game.launch()
  let bodies = game.bodies
  let credits = game.commander.credits
  game.emitScriptEvent("station.undocked")
  #expect(game.bodies == bodies && game.commander.credits == credits)
  #expect(game.commander.scriptState.geometry.isEmpty)
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters.isEmpty == true)
  #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  #expect(!game.commander.scriptState.pendingEvents.contains { $0.kind == "encounter.admitted" })
}

@Test func changingIntentInARotatedFrameCannotRotateOrResetTheActualVelocity() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  let station = try #require(game.bodies.firstIndex { $0.id == 0 })
  game.bodies[station].orientation.rotate(pitch: 0.3, roll: 0.4, yaw: 0.5)
  game.bodies[index].scriptNPC?.velocity = .init(10, 4, 2)
  game.persistScriptActors()
  let canonical = game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[
    "lead"]?.body.scriptNPC?.velocity
  #expect(canonical != game.bodies[index].scriptNPC?.velocity)
  try setNPCIntent(&game, id: id, command: npcIntent("hold", request: "brake"))
  #expect(game.bodies[index].scriptNPC?.velocity == .init(10, 4, 2))
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect((game.bodies[index].scriptNPC?.velocity.length ?? 0) < Vector3(10, 4, 2).length)
  let snapshot = game.scriptNPCSnapshot(game.bodies[index].scriptNPC)
  #expect(snapshot["name"]?.string == "Profiled training opponent")
  #expect(snapshot["components"]?["turret"]?["identity"]?.string != nil)
}

@Test func profileSceneSaveRejectsAlteredModelHashForeignShotOwnerAndDuplicateComponentIdentity()
  throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try aimNPCAtPlayer(&game, id: id)
  game.advanceScriptNPCWeapons(delta: 0.1)
  game.persistScriptActors()
  #expect(game.commander.valid)
  var changed = game
  let hash = try #require(changed.commander.scriptState.geometry.keys.first)
  changed.commander.scriptState.geometry.removeValue(forKey: hash)
  #expect(!changed.commander.valid)
  changed = game
  let wing = try npcIndex(changed, id, "wing")
  let component = try #require(changed.bodies[index].scriptNPC?.components["turret"])
  changed.bodies[wing].scriptNPC?.components["turret"] = component
  changed.persistScriptActors()
  #expect(!changed.commander.valid)
  var json = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander.scriptState))
      as? [String: Any])
  // UUID dictionaries are encoded as alternating key/value arrays by Foundation.
  var projectiles = try #require(json["savedProjectiles"] as? [Any])
  var record = try #require(projectiles[1] as? [String: Any])
  var body = try #require(record["body"] as? [String: Any])
  var shot = try #require(body["scriptShot"] as? [String: Any])
  shot["owner"] = UUID().uuidString
  body["scriptShot"] = shot
  record["body"] = body
  projectiles[1] = record
  json["savedProjectiles"] = projectiles
  let forged = try JSONDecoder().decode(
    ScriptEngineState.self, from: JSONSerialization.data(withJSONObject: json))
  #expect(!forged.valid)
}

@Test func sweptSphereContactIncludesFacesEdgesCornersAndNonunitLocalDirections() {
  let a = Vector3(-10, -10, 100)
  let b = Vector3(10, -10, 100)
  let c = Vector3(0, 10, 100)
  func hit(_ origin: Vector3, range: Double = 200) -> Double? {
    ScriptSweptCollision.triangle(
      origin: origin, direction: .init(0, 0, 1), range: range,
      radius: 2, a: a, b: b, c: c)
  }
  #expect(abs((hit(.init(0, 0, 0)) ?? 0) - 98) < 1e-8)
  #expect(abs((hit(.init(0, -11, 0)) ?? 0) - (100 - sqrt(3))) < 1e-8)
  #expect(abs((hit(.init(11, -11, 0)) ?? 0) - (100 - sqrt(2))) < 1e-8)
  #expect(hit(.init(12, -12, 0)) == nil)
  #expect(hit(.init(0, 0, 0), range: 97) == nil)
  #expect(hit(.init(0, 0, 101)) == 0)
  #expect(
    ScriptSweptCollision.triangle(
      origin: .init(0, -11, 99), direction: .init(1, 0, 0),
      range: 10, radius: 2, a: a, b: b, c: c) == 0)
  #expect(
    ScriptSweptCollision.sphere(origin: .init(3, 0, 0), direction: .init(-2, 0, 0), radius: 1) == 1)
  #expect(
    ScriptSweptCollision.sphere(origin: .init(0, 0, 0), direction: .init(0, 0, 0), radius: 1) == 0)
  #expect(
    ScriptSweptCollision.sphere(origin: .init(3, 0, 0), direction: .init(0, 0, 0), radius: 1) == nil
  )
}

@Test func aClassicConeNearMissCannotInterceptAnActualProfiledHullHit() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.speed = 0
  game.commander.installLaser(.naval, on: .front)
  let ordinary = try #require(game.bodies.firstIndex { $0.id == 1 })
  game.bodies[ordinary].position = .init(80, 0, 1400)
  let oldEnergy = game.bodies[ordinary].energy
  let index = try npcIndex(game, id)
  game.bodies[index].position = .init(0, 0, 2500)
  var controls = Controls()
  controls.fire = true
  game.tick(delta: 0.1, controls: controls)
  #expect(game.bodies[ordinary].energy == oldEnergy)
  #expect(!game.bodies[ordinary].hostile)
  #expect(game.bodies[index].energy < 120)
}

@Test func catalogueNpcGeometryUsesMeasuredRawVerticesAndNeverChangesThePlayerFit() throws {
  let fixture = try NPCFixture(edits: [
    ("model = \"asset:hull\"", "model = \"catalogue:SH128\""),
    ("scale = 1.0", "scale = 1.6"),
  ])
  defer { fixture.clean() }
  let (game, id) = try fixture.game()
  let body = game.bodies[try npcIndex(game, id)]
  let mesh = try #require(game.scriptNPCMesh(body))
  let raw = try #require(ShipCatalogue.ship("SH128")?.design.rawMesh)
  #expect(mesh.vertices[0] == raw.vertices[0] * 1.6)
  #expect(body.scriptNPC?.fit.models["catalogue:SH128"] != nil)
  #expect(game.commander.shipID == "SH023")
  #expect(ShipCatalogue.ship("SH128")?.game?.cargo == 0)
  #expect(game.commander.valid)
}

@Test func projectilesRespectLifetimeAndWeaponsWaitForRealWorldCapacityWithoutSpending() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try aimNPCAtPlayer(&game, id: id)
  game.bodies[index].scriptNPC?.guns["forward"]?.heat = 256
  let originalEnergy = game.bodies[index].energy
  let extras = 1024 - game.bodies.reduce(0) { $0 + $1.scriptNativeUnits }
  game.bodies += (0..<extras).map {
    SpaceBody(id: 1000 + $0, hull: .cargo, position: .init(100000, 0, 0))
  }
  game.advanceScriptNPCWeapons(delta: 0.01)
  #expect(!game.bodies.contains { $0.scriptShot != nil })
  #expect(game.bodies[index].scriptNPC?.shots == 0 && game.bodies[index].energy == originalEnergy)
  game.bodies.removeAll { $0.id >= 1000 }
  game.advanceScriptNPCWeapons(delta: 0.01)
  let projectileIndex = try #require(game.bodies.firstIndex { $0.scriptShot != nil })
  let shotIdentity = try #require(game.bodies[projectileIndex].scriptShot?.identity)
  game.bodies[projectileIndex].position = .init(5000, 5000, 5000)
  game.persistScriptActors()
  #expect(game.commander.scriptState.projectiles[shotIdentity] != nil)
  for _ in 0..<31 { game.advanceScriptNPCShots(delta: 0.1) }
  game.resolveDestroyed()
  #expect(!game.bodies.contains { $0.scriptShot?.identity == shotIdentity })
  #expect(game.commander.scriptState.projectiles[shotIdentity] == nil)
}

@Test func nativeProfiledPatrolUsesActualPlayerLasersAutomaticDockingAndStationConfirmation()
  async throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.commander.installTargetingComputer(.military)
  game.commander.installLaser(.naval, on: .front)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  for alias in ["lead", "wing"] {
    let identity = try #require(
      game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[alias]?
        .identity)
    for _ in 0..<12 {
      await runtime.key("r")
      if await runtime.snapshot().autoTargetBody?.missionActorID == identity { break }
    }
    #expect(await runtime.snapshot().autoTargetBody?.missionActorID == identity)
    for _ in 0..<200 {
      let frame = await runtime.advance(delta: 0.02)
      if frame.autoPilot.status == "TRACKING TARGET" { break }
    }
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<300 {
      let frame = await runtime.advance(delta: 0.05)
      if frame.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[alias]?
        .presence == .destroyed
      {
        break
      }
    }
    await runtime.setControls(Controls())
    #expect(
      await runtime.snapshot().commander.scriptState.instances[id]?.ownedEncounters["opponents"]?
        .actors[alias]?.presence == .destroyed)
  }
  let won = await runtime.snapshot()
  #expect(won.commander.kills == 2)
  #expect(won.commander.scriptState.instances[id]?.data["phase"] == .string("report"))
  #expect(won.commander.scriptState.instances[id]?.suspension == nil)
  for _ in 0..<12 {
    await runtime.key("r")
    if await runtime.snapshot().autoTargetBody?.id == 0 { break }
  }
  var returned = await runtime.snapshot()
  for _ in 0..<5000 where !returned.docked { returned = await runtime.advance(delta: 0.02) }
  #expect(returned.docked && returned.dockedAtMainStation)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().scriptOffer == id)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  #expect(await runtime.snapshot().commander.credits == won.commander.credits + 1000)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  #expect(await loaded.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
}

@Test func physicalNpcReplayAfterSavePreservesShotIdentitiesStocksAndWeaponResults() async throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  _ = try aimNPCAtPlayer(&game, id: id)
  game.speed = 0
  let runtime = GameRuntime(game: game)
  _ = await runtime.advance(delta: 0.1)
  try await runtime.save(to: fixture.save)
  let resumed = GameRuntime(game: game)
  try await resumed.load(from: fixture.save)
  for _ in 0..<12 {
    _ = await runtime.advance(delta: 0.1)
    _ = await resumed.advance(delta: 0.1)
  }
  let uninterrupted = await runtime.snapshot()
  let restored = await resumed.snapshot()
  #expect(uninterrupted.bodies == restored.bodies)
  #expect(
    uninterrupted.frontShield == restored.frontShield && uninterrupted.energy == restored.energy)
  #expect(uninterrupted.commander.scriptState == restored.commander.scriptState)
}

@Test func profiledGalleryStartsRealModelsAndWeaponsInAnIsolatedSavedWorld() async throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.screen = .status
  let pack = try ScriptPackLibrary.read(fixture.directory)
  game.scriptPacks = [pack]
  game.commander.credits = 123456
  game.openGallery()
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let bytes = try Data(contentsOf: fixture.save)
  try await runtime.startScriptGalleryTrial(packDigest: pack.digest, seed: 7823)
  let directory = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: directory) }
  #expect(await runtime.snapshot().isMissionTrial)
  #expect(await runtime.snapshot().bodies.filter { $0.scriptNPC != nil }.count == 2)
  #expect(await runtime.snapshot().commander.scriptState.geometry.count == 2)
  for _ in 0..<30 { _ = await runtime.advance(delta: 0.1) }
  #expect(await runtime.snapshot().bodies.contains { ($0.scriptNPC?.shots ?? 0) > 0 })
  try await runtime.saveForInterface()
  try await runtime.restartScriptGalleryTrial()
  #expect(
    await runtime.snapshot().bodies.filter { $0.scriptNPC != nil }.allSatisfy {
      $0.energy == 120 && $0.scriptNPC?.shots == 0
    })
  try await runtime.returnFromScriptGalleryTrial()
  #expect(await runtime.snapshot().commander == before.commander)
  #expect(try Data(contentsOf: fixture.save) == bytes)
}
