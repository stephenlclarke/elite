import Foundation
import Testing

@testable import EliteCore

private func retainedNativeProjectile() throws -> (
  Game, UUID, Vector3, Vector3, MissionLaunchArchive
) {
  var (game, instance, index) = try actualMissionBridgeGame()
  game.ensurePhysicalActors()
  let owner = game.bodies[index]
  let npc = try #require(owner.scriptNPC)
  let specification = try #require(npc.fit.definition.components?.first)
  let component = try #require(npc.components[specification.id])
  let weapon = try #require(specification.weapons?.first)
  let binding = try game.currentMissionNativeBinding(bodyID: owner.id)
  let emission = game.makeAttackOrigin(
    owner: binding.nativeActor, sourcePart: component.identity.uuidString)
  let origin = try #require(emission)
  let context = try #require(game.gameplayContext())
  let source = try #require(context.actors.first { $0.identity == binding.nativeActor })
  let judgement = try game.commander.crimeLedger.freezeMissionLaunchJudgement(
    origin: origin, intendedVictim: context.player,
    emissionPosition: source.position, context: context)
  let identity = UUID()
  let velocity =
    owner.modelVector(.init(0.1, 0.2, 1)).unit
    * (try #require(weapon.projectileSpeed))
  let shot = ScriptNPCShot(
    identity: identity, owner: binding.actorID, instance: instance, weapon: weapon.id,
    component: component.identity, velocity: velocity, age: 0.125,
    lifetime: try #require(weapon.lifetime), damage: weapon.damage,
    radius: try #require(weapon.collisionRadius),
    collisionDelay: try #require(weapon.collisionDelay))
  let descriptor = try #require(shot.missionDescriptor)
  // This is retained-history/provider setup, not a claim that the atomic gun producer ran.
  let archive = try MissionNativeBridge.makeLaunchArchive(
    shot: descriptor, source: binding, intendedTarget: nil, judgement: judgement)
  let anchor = try #require(game.scriptAnchor)
  let position = owner.position + .init(100, 50, 500)
  var body = SpaceBody(
    id: 777, hull: .missile,
    position: anchor.orientation.inverse(position - anchor.position))
  body.orientation = Basis3().relative(to: anchor.orientation)
  body.energy = 1
  body.rotationRate = 0
  body.scriptShot = .init(
    identity: identity, owner: shot.owner, instance: instance, weapon: shot.weapon,
    component: shot.component, velocity: anchor.orientation.inverse(velocity), age: shot.age,
    lifetime: shot.lifetime, damage: shot.damage, radius: shot.radius,
    collisionDelay: shot.collisionDelay, nativeAttribution: archive)
  game.commander.scriptState.projectiles[identity] = .init(
    galaxy: game.commander.galaxy, system: game.commander.system, body: body, presence: .unloaded)
  try #require(game.commander.valid)
  return (game, identity, position, velocity, archive)
}

struct NativeMissionProjectileTests {
  @Test func actualRetainedAdmissionPreservesTuningArchiveAndVerifiedIdempotentBinding() throws {
    var (game, identity, position, velocity, archive) = try retainedNativeProjectile()
    let before = game.commander.flightSimulation
    let bodyID = game.nextBodyID
    let receipt = try game.admitRetainedMissionProjectile(identity)
    let body = try #require(game.bodies.first { $0.id == receipt.bodyID })
    let system = try #require(before.system)
    #expect(receipt.bodyID == bodyID && game.nextBodyID == bodyID + 1)
    #expect(receipt.actor.system == system && receipt.actor.visit == before.visit)
    #expect(game.commander.flightSimulation.nextActor == before.nextActor + 1)
    #expect(game.commander.flightSimulation.nextSpawn == before.nextSpawn + 1)
    #expect((body.position - position).length < 1e-8)
    let restored = try #require(body.scriptShot)
    #expect((restored.velocity - velocity).length < 1e-8)
    #expect(restored.nativeAttribution == archive && body.physical?.attackOrigin == archive.origin)
    #expect(restored.damage == 15 && restored.lifetime == 3 && restored.radius == 2)
    #expect(body.physical?.population == .projectile && body.physical?.ordnance == nil)
    game.commander.scriptState.projectiles[identity]?.body.id = receipt.bodyID
    game.commander.scriptState.projectiles[identity]?.presence = .present
    let commander = game.commander
    let bodies = game.bodies
    let duplicate = try game.admitRetainedMissionProjectile(identity)
    #expect(duplicate == receipt && game.commander == commander && game.bodies == bodies)
    #expect(game.nextBodyID == bodyID + 1)
  }

  @Test(arguments: [false, true])
  func nativeCapacityAndExhaustedAllocatorRefuseWithoutChangingAnyRetainedOrPhysicalState(
    exhausted: Bool
  ) throws {
    var (game, identity, _, _, _) = try retainedNativeProjectile()
    if exhausted {
      let bytes = try JSONEncoder().encode(game.commander.flightSimulation)
      var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      object["nextSpawn"] = NSNumber(value: UInt64.max)
      game.commander.flightSimulation = try JSONDecoder().decode(
        FlightSimulationState.self, from: JSONSerialization.data(withJSONObject: object))
    } else {
      for index in 0..<PopulationClass.projectile.maximum {
        let actor = try #require(game.commander.flightSimulation.allocateActor())
        var body = SpaceBody(
          id: 1000 + index, hull: .missile, position: .init(5000, 1000, 6000))
        body.physical = .init(identity: actor, population: .projectile)
        game.bodies.append(body)
      }
    }
    let before = game
    #expect(throws: NativeMissionProjectileAdmissionError.self) {
      try game.admitRetainedMissionProjectile(identity)
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(
      game.nextBodyID == before.nextBodyID && game.gameplayRevision == before.gameplayRevision)
  }

  @Test func anUnavailableExactPackPreservesThePendingShotAndHistoricalArchive() throws {
    var (game, identity, _, _, archive) = try retainedNativeProjectile()
    game.scriptPacks = []
    let before = game
    #expect(throws: NativeMissionProjectileAdmissionError.unavailablePack) {
      try game.admitRetainedMissionProjectile(identity)
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.nextBodyID == before.nextBodyID)
    #expect(
      game.commander.scriptState.projectiles[identity]?.body.scriptShot?.nativeAttribution
        == archive)
  }

  @Test(arguments: [false, true])
  func nativeManualAndGuidedCameraChangesRotateShotVelocityWithoutIntegratingItTwice(guided: Bool)
    throws
  {
    var (game, identity, _, _, archive) = try retainedNativeProjectile()
    let receipt = try game.admitRetainedMissionProjectile(identity)
    let body = try #require(game.bodies.first { $0.id == receipt.bodyID })
    let start = game.commander.flightSimulation.pose
    let position = start.systemPoint(body.position)
    let velocity = start.orientation.apply(try #require(body.scriptShot?.velocity))
    if guided {
      var end = start
      end.orientation.rotate(pitch: 0.1, roll: -0.2, yaw: 0.3)
      game.workBraking = .init(velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
      game.approvedWorkMotion = .init(
        start: start, end: end, initialVelocity: .init(0, 0, 0),
        acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
        duration: 0.1, playerRadius: 1)
      try #require(game.moveWorkFrame(delta: 0.1))
    } else {
      var controls = Controls()
      controls.pitch = 0.3
      controls.yaw = -0.4
      game.tick(delta: 0.1, controls: controls)
    }
    let moved = try #require(game.bodies.first { $0.id == receipt.bodyID })
    let pose = game.commander.flightSimulation.pose
    let worldVelocity = pose.orientation.apply(try #require(moved.scriptShot?.velocity))
    #expect((pose.systemPoint(moved.position) - position).length < 1e-8)
    #expect((worldVelocity - velocity).length < 1e-8)
    #expect(moved.scriptShot?.nativeAttribution == archive)
  }
}
