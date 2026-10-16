import Foundation
import Testing

@testable import EliteCore

private func actualMissionBridgeGame() throws -> (Game, UUID, Int) {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/profiled-skirmish")
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.scriptPacks = [pack]
  let instance = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let actor = try #require(
    game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"])
  let index = try #require(game.bodies.firstIndex { $0.missionActorID == actor.identity })
  return (game, instance, index)
}

struct ScriptNativeBridgeTests {
  @Test func actualActorProjectionUsesLiveBodyAndRetainedImmutableOwnershipWithoutMutation() throws
  {
    var (game, instance, index) = try actualMissionBridgeGame()
    let retained = try #require(
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"])
    game.bodies[index].position = game.bodies[index].position + .init(7, 11, 13)
    game.bodies[index].energy -= 1
    game.bodies[index].scriptNPC?.guns["forward"]?.cooldown = 0.2
    let body = game.bodies[index]
    try #require(body != retained.body)
    let before = game.commander
    let bodies = game.bodies
    let nextID = game.nextBodyID
    let descriptor = try #require(game.currentMissionActorDescriptor(bodyID: body.id))
    #expect(descriptor.body == body && descriptor.actorID == retained.identity)
    #expect(descriptor.instanceID == instance && descriptor.alias == "lead")
    #expect(descriptor.encounterID == "opponents" && descriptor.encounterAdmitted)
    #expect(descriptor.presence == ScriptActorPresence.present.rawValue)
    #expect(descriptor.instanceRevision == before.scriptState.instances[instance]?.revision)
    #expect(descriptor.packDigest == before.scriptState.instances[instance]?.digest)
    #expect(descriptor.missionActorID == body.missionActorID)
    #expect(descriptor.missionInstanceID == body.missionInstanceID)
    #expect(game.currentMissionActorDescriptor(bodyID: body.id) == descriptor)
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == nextID)
  }

  @Test(arguments: [
    "instance", "encounter", "alias", "record-source", "presence", "pack", "system", "geometry",
    "fit",
  ])
  func actorProjectionRefusesBrokenActualJoins(field: String) throws {
    var (game, instanceID, index) = try actualMissionBridgeGame()
    let bodyID = game.bodies[index].id
    try #require(game.currentMissionActorDescriptor(bodyID: bodyID) != nil)
    var instance = try #require(game.commander.scriptState.instances[instanceID])
    var encounter = try #require(instance.ownedEncounters["opponents"])
    var actor = try #require(encounter.actors["lead"])
    switch field {
    case "instance":
      game.commander.scriptState.instances.removeValue(forKey: instanceID)
      game.commander.scriptState.instances[UUID()] = instance
    case "encounter":
      instance.ownedEncounters.removeValue(forKey: "opponents")
      instance.ownedEncounters["different"] = encounter
      game.commander.scriptState.instances[instanceID] = instance
    case "alias":
      encounter.actors.removeValue(forKey: "lead")
      encounter.actors["different"] = actor
      instance.ownedEncounters["opponents"] = encounter
      game.commander.scriptState.instances[instanceID] = instance
    case "record-source", "presence":
      if field == "record-source" {
        actor.body.missionInstanceID = UUID()
      } else {
        actor.presence = .outside
      }
      encounter.actors["lead"] = actor
      instance.ownedEncounters["opponents"] = encounter
      game.commander.scriptState.instances[instanceID] = instance
    case "pack": game.scriptPacks = []
    case "system": game.commander.galaxy = 1
    case "geometry":
      let digest = try #require(game.bodies[index].scriptNPC?.fit.models.values.first)
      game.commander.scriptState.geometry.removeValue(forKey: digest)
    default:
      let npc = try #require(game.bodies[index].scriptNPC)
      var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(npc)) as? [String: Any])
      var fit = try #require(object["fit"] as? [String: Any])
      var definition = try #require(fit["definition"] as? [String: Any])
      definition["energy"] = npc.fit.definition.energy + 1
      fit["definition"] = definition
      object["fit"] = fit
      game.bodies[index].scriptNPC = try JSONDecoder().decode(
        ScriptNPCState.self, from: JSONSerialization.data(withJSONObject: object))
    }
    let before = game.commander
    let bodies = game.bodies
    #expect(game.currentMissionActorDescriptor(bodyID: bodyID) == nil)
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test(arguments: [false, true])
  func weaponProjectionRetainsActualAuthoredValuesAndRefusesSubstitutes(componentWeapon: Bool)
    throws
  {
    var (game, _, index) = try actualMissionBridgeGame()
    let body = game.bodies[index]
    let npc = try #require(body.scriptNPC)
    let weapon: ScriptNPCWeapon
    let component: UUID?
    let muzzle: Vector3
    let direction: Vector3
    if componentWeapon {
      let specification = try #require(npc.fit.definition.components?.first)
      let state = try #require(npc.components[specification.id])
      weapon = try #require(specification.weapons?.first)
      component = state.identity
      let pose = specification.orientation.transformed(by: body.orientation)
      let center =
        body.position + body.orientation.apply(specification.position * npc.fit.definition.scale)
      muzzle = center + pose.apply(weapon.muzzle * (specification.scale * npc.fit.definition.scale))
      direction = pose.apply(weapon.direction).unit
    } else {
      weapon = try #require(npc.fit.definition.lasers?.first)
      component = nil
      muzzle = body.position + body.orientation.apply(weapon.muzzle * npc.fit.definition.scale)
      direction = body.orientation.apply(weapon.direction).unit
    }
    let before = game.commander
    let descriptor = try #require(
      game.missionWeaponDescriptor(
        weapon, source: body, component: component, muzzle: muzzle, direction: direction))
    #expect(descriptor.kind == (componentWeapon ? AttackKind.plasma : .laser))
    #expect(descriptor.damage == weapon.damage && descriptor.range == weapon.range)
    #expect(
      descriptor.projectileSpeed == weapon.projectileSpeed && descriptor.lifetime == weapon.lifetime
    )
    #expect(
      descriptor.collisionRadius == weapon.collisionRadius
        && descriptor.collisionDelay == weapon.collisionDelay)
    #expect(descriptor.muzzle == muzzle && descriptor.direction == direction)
    var forged = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(weapon)) as? [String: Any])
    forged["damage"] = weapon.damage + 1
    let substitute = try JSONDecoder().decode(
      ScriptNPCWeapon.self, from: JSONSerialization.data(withJSONObject: forged))
    try #require(substitute.valid)
    #expect(
      game.missionWeaponDescriptor(
        substitute, source: body, component: component, muzzle: muzzle, direction: direction) == nil
    )
    #expect(
      game.missionWeaponDescriptor(
        weapon, source: body, component: UUID(), muzzle: muzzle, direction: direction) == nil)
    #expect(
      game.missionWeaponDescriptor(
        weapon, source: body, component: component, muzzle: muzzle + .init(1, 0, 0),
        direction: direction) == nil)
    #expect(game.commander == before)
    if componentWeapon {
      let key = try #require(npc.components.first { $0.value.identity == component }?.key)
      let original = try #require(npc.components[key])
      let forgedID = UUID()
      game.bodies[index].scriptNPC?.components[key] = .init(
        identity: forgedID, energy: original.energy, guns: original.guns)
      let forgedSource = game.bodies[index]
      try #require(forgedSource.scriptNPC?.valid == true)
      #expect(forgedSource.scriptNPC?.fit == npc.fit)
      #expect(game.commander == before)
      #expect(game.currentMissionActorDescriptor(bodyID: forgedSource.id) == nil)
      #expect(
        game.missionWeaponDescriptor(
          weapon, source: forgedSource, component: forgedID, muzzle: muzzle,
          direction: direction) == nil)
      game.bodies[index].scriptNPC?.components[key] = original
      game.bodies[index].scriptNPC?.components[key]?.energy = 0
      let current = game.bodies[index]
      #expect(
        game.missionWeaponDescriptor(
          weapon, source: current, component: component, muzzle: muzzle, direction: direction)
          == nil)
    } else {
      game.bodies[index].energy -= 0.5
      #expect(
        game.missionWeaponDescriptor(
          weapon, source: body, component: nil, muzzle: muzzle, direction: direction) == nil)
    }
  }

  @Test func actuallyEmittedLegacyShotProjectsItsCustomPhysicsWithoutAStillPresentOwner() throws {
    var (game, instanceID, index) = try actualMissionBridgeGame()
    game.bodies[index].position = .init(0, 0, 1000)
    var facing = Basis3()
    facing.rotate(pitch: 0, roll: 0, yaw: .pi)
    game.bodies[index].orientation = facing
    let pack = try #require(game.scriptPacks.first)
    var instance = try #require(game.commander.scriptState.instances[instanceID])
    let command: ScriptValue = .object([
      "op": .string("actor.intent"), "id": .string("bridge-fire"),
      "encounter": .string("opponents"), "actor": .string("lead"), "mode": .string("attack"),
      "target": .string("player"), "speed": .number(0), "tolerance": .number(10),
      "offset": .array([.number(0), .number(0), .number(0)]),
    ])
    _ = try game.applyScriptNPCIntent(command, pack: pack, state: &instance)
    game.commander.scriptState.instances[instanceID] = instance
    game.advanceScriptNPCWeapons(delta: 0.1)
    let shot = try #require(game.bodies.first { $0.scriptShot != nil }?.scriptShot)
    let component = try #require(game.bodies[index].scriptNPC?.components["turret"]?.identity)
    let projected = try #require(shot.missionDescriptor)
    #expect(projected.component == component && projected.instance == instanceID)
    #expect(projected.owner == game.bodies[index].missionActorID)
    #expect(abs(projected.velocity.length - 2000) < 1e-8 && projected.lifetime == 3)
    #expect(projected.damage == 15 && projected.radius == 2 && projected.collisionDelay == 0.05)
    // Old shots retain physical fields even after the source is absent; no replacement owner is minted.
    game.bodies.removeAll { $0.missionActorID == shot.owner }
    game.commander.scriptState.instances.removeValue(forKey: instanceID)
    let decoded = try JSONDecoder().decode(ScriptNPCShot.self, from: JSONEncoder().encode(shot))
    #expect(decoded == shot && decoded.missionDescriptor == projected)
    var invalid = decoded
    invalid.velocity = .init(Double.infinity, 0, 0)
    #expect(invalid.missionDescriptor == nil)
  }
}
