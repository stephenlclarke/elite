import Foundation
import Testing

@testable import EliteCore

/// A law/codec fixture using an actual retained actor, native binding, emission allocator and
/// frozen native judgement. It does not claim atomic firing or construct an impact proof.
func actualShotArchiveFixture() throws -> (Game, ScriptNPCShot) {
  var (game, instance, index) = try actualMissionBridgeGame()
  game.ensurePhysicalActors()
  let body = game.bodies[index]
  let npc = try #require(body.scriptNPC)
  let specification = try #require(npc.fit.definition.components?.first)
  let component = try #require(npc.components[specification.id])
  let weapon = try #require(specification.weapons?.first)
  let descriptor = try #require(game.currentMissionActorDescriptor(bodyID: body.id))
  let context = try #require(game.gameplayContext())
  let source = try MissionNativeBridge.bindActor(
    descriptor: descriptor, body: body, context: context)
  let origin = try #require(
    game.makeAttackOrigin(owner: source.nativeActor, sourcePart: component.identity.uuidString))
  let current = try #require(game.gameplayContext())
  let actor = try #require(current.actors.first { $0.identity == source.nativeActor })
  let judgement = try game.commander.crimeLedger.freezeMissionLaunchJudgement(
    origin: origin, intendedVictim: current.player, emissionPosition: actor.position,
    context: current)
  let pose = specification.orientation.transformed(by: body.orientation)
  let shot = ScriptNPCShot(
    identity: ScriptIdentity.uuid("npc-shot-v1:\(descriptor.actorID):\(npc.shots + 1)"),
    owner: descriptor.actorID, instance: instance, weapon: weapon.id, component: component.identity,
    velocity: pose.apply(weapon.direction).unit * (try #require(weapon.projectileSpeed)),
    age: 0, lifetime: try #require(weapon.lifetime), damage: weapon.damage,
    radius: try #require(weapon.collisionRadius),
    collisionDelay: try #require(weapon.collisionDelay))
  let archive = try MissionNativeBridge.makeLaunchArchive(
    shot: #require(shot.missionDescriptor), source: source, intendedTarget: nil,
    judgement: judgement)
  let archived = ScriptNPCShot(
    identity: shot.identity, owner: shot.owner, instance: shot.instance, weapon: shot.weapon,
    component: shot.component, velocity: shot.velocity, age: shot.age, lifetime: shot.lifetime,
    damage: shot.damage, radius: shot.radius, collisionDelay: shot.collisionDelay,
    nativeAttribution: archive)
  return (game, archived)
}

struct ScriptShotArchiveTests {
  @Test func optionalShotArchiveRetainsRealFrozenNativeDataAndOldAbsenceStaysUnknown() throws {
    let (_, shot) = try actualShotArchiveFixture()
    let archive = try #require(shot.nativeAttribution)
    let bytes = try JSONEncoder().encode(shot)
    let decoded = try JSONDecoder().decode(ScriptNPCShot.self, from: bytes)
    #expect(decoded == shot && decoded.nativeAttribution == archive)
    #expect(decoded.nativeAttribution?.origin == archive.origin)
    #expect(decoded.nativeAttribution?.judgement == archive.judgement)
    #expect(
      archive.sourceComponentID == shot.component
        && archive.origin.sourcePart == shot.component?.uuidString)
    #expect(!archive.judgement.launchEffectsApplied)
    var legacy = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    legacy.removeValue(forKey: "nativeAttribution")
    let old = try JSONDecoder().decode(
      ScriptNPCShot.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(old.nativeAttribution == nil && old.valid)
    #expect(old.missionDescriptor == shot.missionDescriptor)
    let encodedOld = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
    #expect(encodedOld["nativeAttribution"] == nil)
  }

  @Test(arguments: [
    "null", "version", "missing-law", "shot", "instance", "source", "component", "source-part",
  ])
  func presentMalformedOrMismatchedShotArchiveCannotDecodeAsUnknown(field: String) throws {
    let (_, shot) = try actualShotArchiveFixture()
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(shot)) as? [String: Any])
    var archive = try #require(object["nativeAttribution"] as? [String: Any])
    switch field {
    case "null": object["nativeAttribution"] = NSNull()
    case "version": archive["schemaVersion"] = 2
    case "missing-law": archive.removeValue(forKey: "judgement")
    case "shot": object["identity"] = UUID().uuidString
    case "instance": object["instance"] = UUID().uuidString
    case "source": object["owner"] = UUID().uuidString
    case "component": object["component"] = UUID().uuidString
    default: archive["sourceComponentID"] = UUID().uuidString
    }
    if field != "null" { object["nativeAttribution"] = archive }
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        ScriptNPCShot.self, from: JSONSerialization.data(withJSONObject: object))
    }
  }

  @Test func persistedArchiveJoinsActualRetainedPackAndOriginalSystemWithoutCurrentOwner() throws {
    var (game, shot) = try actualShotArchiveFixture()
    var body = SpaceBody(id: game.nextBodyID, hull: .missile, position: .init(1, 2, 3))
    body.scriptShot = shot
    let record = ScriptProjectileRecord(
      galaxy: game.commander.galaxy, system: game.commander.system, body: body, presence: .outside)
    game.bodies.removeAll { $0.missionActorID == shot.owner }
    #expect(game.commander.scriptState.projectileArchiveValid(record))
    let decoded = try JSONDecoder().decode(
      ScriptProjectileRecord.self, from: JSONEncoder().encode(record))
    #expect(decoded.body.scriptShot?.nativeAttribution == shot.nativeAttribution)
    #expect(game.commander.scriptState.projectileArchiveValid(decoded))
    let old = try #require(game.commander.scriptState.instances[shot.instance])
    var wrongVersion = ScriptInstance(
      id: old.id, definition: old.definition, version: old.version,
      digest: String(repeating: "f", count: 64))
    wrongVersion.ownedEncounters = old.ownedEncounters
    game.commander.scriptState.instances[shot.instance] = wrongVersion
    #expect(!game.commander.scriptState.projectileArchiveValid(decoded))
    game.commander.scriptState.instances[shot.instance] = old
    var elsewhere = decoded
    elsewhere = ScriptProjectileRecord(
      galaxy: (record.galaxy + 1) % 8, system: record.system, body: record.body,
      presence: record.presence)
    #expect(!game.commander.scriptState.projectileArchiveValid(elsewhere))
  }
}
