import Foundation
import Testing

@testable import EliteCore

private let bridgeInstance = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let bridgeActor = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

private final class BridgeLaserProofFixture: Sendable {
  let game: Game
  let source: SpaceBody
  let weapon: ScriptNPCWeapon
  let muzzle: Vector3

  init(game: Game, source: SpaceBody, weapon: ScriptNPCWeapon, muzzle: Vector3) {
    self.game = game
    self.source = source
    self.weapon = weapon
    self.muzzle = muzzle
  }
}

private func makeBridgeLaserProofFixture() throws -> BridgeLaserProofFixture {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/profiled-skirmish")
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let instance = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  game.ensurePhysicalActors()
  let source = try #require(
    game.bodies.first { $0.missionInstanceID == instance && $0.scriptNPC != nil })
  let weapon = try #require(source.scriptNPC?.fit.definition.lasers?.first { $0.kind == .laser })
  game.bodies = [source]
  game.celestials = []
  let muzzle =
    source.position
    + source.orientation.apply(weapon.muzzle * source.scriptNPC!.fit.definition.scale)
  return .init(game: game, source: source, weapon: weapon, muzzle: muzzle)
}

private func assertBridgeLaserProof(_ fixture: BridgeLaserProofFixture) throws {
  var game = fixture.game
  let source = fixture.source
  let weapon = fixture.weapon
  let muzzle = fixture.muzzle
  let original = (commander: game.commander, bodies: game.bodies)
  #expect(throws: (any Error).self) {
    try game.makeMissionNativeLaserProof(
      sourceBodyID: source.id, weapon: weapon,
      component: nil, muzzle: muzzle, direction: .init(0, 0, 0))
  }
  #expect(game.commander == original.commander && game.bodies == original.bodies)
  try bridgeLaserInvalidGeometryPreservesState(
    game, source: source, weapon: weapon, muzzle: muzzle)
  let queryBefore = (commander: game.commander, bodies: game.bodies)
  let query = try game.queryMissionNativeLaser(
    sourceBodyID: source.id, weapon: weapon,
    component: nil, muzzle: muzzle, direction: .init(0, 1, 0))
  let currentBinding = try game.currentMissionNativeBinding(bodyID: source.id)
  #expect(query.source == currentBinding)
  #expect(query.weapon.damage == weapon.damage && query.contact == nil)
  #expect(query.sourceComponentID == nil && query.context == game.gameplayContext())
  #expect(game.commander == queryBefore.commander && game.bodies == queryBefore.bodies)
  let emission = game.commander.flightSimulation.nextEmission
  let proof = try game.makeMissionNativeLaserProof(
    sourceBodyID: source.id, weapon: weapon,
    component: nil, muzzle: muzzle, direction: .init(0, 1, 0))
  #expect(proof.kind == .laser && proof.damage == weapon.damage && proof.contact == nil)
  #expect(proof.source == query.source && proof.weapon == query.weapon)
  #expect(proof.contact == query.contact && proof.origin.emittedAt == query.context.physicalTime)
  #expect(proof.sourceActorID == source.missionActorID && proof.origin.emissionID == emission)
  #expect(game.commander.flightSimulation.nextEmission == emission + 1)
  #expect(game.bodies == original.bodies)
  #expect(game.commander.scriptState == original.commander.scriptState)
  let freshBefore = (commander: game.commander, bodies: game.bodies)
  try game.validateMissionNativeLaserProof(proof)
  #expect(game.commander == freshBefore.commander && game.bodies == freshBefore.bodies)
  try bridgeLaserChangedSourceRefusesProof(game, source: source, proof: proof)
  bridgeLaserLaterEmissionRefusesProof(game, proof: proof)
  bridgeLaserLaterClockRefusesProof(game, proof: proof)
}

private func bridgeLaserInvalidGeometryPreservesState(
  _ game: Game, source: SpaceBody, weapon: ScriptNPCWeapon, muzzle: Vector3
) throws {
  var invalid = game
  invalid.celestials = [.init(kind: .planet, position: .init(0, 0, 200), radius: -1)]
  let invalidBefore = (commander: invalid.commander, bodies: invalid.bodies)
  #expect(throws: MissionNativeBridgeError.invalidGeometry) {
    try invalid.makeMissionNativeLaserProof(
      sourceBodyID: source.id, weapon: weapon,
      component: nil, muzzle: muzzle, direction: .init(0, 1, 0))
  }
  #expect(invalid.commander == invalidBefore.commander && invalid.bodies == invalidBefore.bodies)
}

private func bridgeLaserChangedSourceRefusesProof(
  _ game: Game, source: SpaceBody, proof: MissionNativeLaserProof
) throws {
  var sourceChanged = game
  let sourceIndex = try #require(sourceChanged.bodies.firstIndex { $0.id == source.id })
  sourceChanged.bodies[sourceIndex].energy -= 1
  #expect(throws: MissionNativeBridgeError.staleBinding) {
    try sourceChanged.validateMissionNativeLaserProof(proof)
  }
}

private func bridgeLaserLaterEmissionRefusesProof(
  _ game: Game, proof: MissionNativeLaserProof
) {
  var laterEmission = game
  let allocatedLater = laterEmission.makeAttackOrigin(owner: proof.source.nativeActor)
  #expect(allocatedLater != nil)
  #expect(throws: MissionNativeBridgeError.staleBinding) {
    try laterEmission.validateMissionNativeLaserProof(proof)
  }
}

private func bridgeLaserLaterClockRefusesProof(
  _ game: Game, proof: MissionNativeLaserProof
) {
  var laterClock = game
  laterClock.commander.flightSimulation.advancePhysicalTime(0.01)
  #expect(throws: MissionNativeBridgeError.staleBinding) {
    try laterClock.validateMissionNativeLaserProof(proof)
  }
}

private final class BridgeLegacyPlasmaFixture: Sendable {
  let game: Game
  let instance: UUID
  let owner: UUID
  let componentID: UUID
  let speed: Double
  let lifetime: Double
  let delay: Double
  let shotID: UUID
  let shot: ScriptNPCShot
  let live: SpaceBody
  let projectileBodyID: Int

  init(
    game: Game, instance: UUID, owner: UUID, componentID: UUID, speed: Double, lifetime: Double,
    delay: Double, shotID: UUID, shot: ScriptNPCShot, live: SpaceBody, projectileBodyID: Int
  ) {
    self.game = game
    self.instance = instance
    self.owner = owner
    self.componentID = componentID
    self.speed = speed
    self.lifetime = lifetime
    self.delay = delay
    self.shotID = shotID
    self.shot = shot
    self.live = live
    self.projectileBodyID = projectileBodyID
  }
}

private func makeBridgeLegacyPlasmaFixture() throws -> BridgeLegacyPlasmaFixture {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/profiled-skirmish")
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let instance = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let source = try #require(
    game.bodies.first { $0.missionInstanceID == instance && $0.scriptNPC != nil })
  let owner = try #require(source.missionActorID)
  let componentSpec = try #require(
    source.scriptNPC?.fit.definition.components?.first {
      ($0.weapons ?? []).contains { $0.kind == .plasma }
    })
  let weapon = try #require(componentSpec.weapons?.first { $0.kind == .plasma })
  let componentID = try #require(source.scriptNPC?.components[componentSpec.id]?.identity)
  let speed = try #require(weapon.projectileSpeed)
  let lifetime = try #require(weapon.lifetime)
  let delay = try #require(weapon.collisionDelay)
  let shotID = UUID(uuidString: "00000000-0000-0000-0000-000000000050")!
  let shot = ScriptNPCShot(
    identity: shotID, owner: owner, instance: instance,
    weapon: weapon.id, component: componentID, velocity: .init(0, 0, speed), age: 0,
    lifetime: lifetime, damage: weapon.damage, radius: try #require(weapon.collisionRadius),
    collisionDelay: delay)
  game.bodies = []
  game.celestials = []
  let context = try #require(game.gameplayContext())
  let allocatedSpawn = game.commander.flightSimulation.allocateSpawn()
  let sequence = try #require(allocatedSpawn)
  let request = SpawnRequest(
    identity: .init(
      system: context.system, visit: context.visit,
      sequence: sequence, member: 0, producer: .ordnance), population: .projectile,
    hull: .missile, position: game.commander.flightSimulation.pose.systemPoint(.init(0, 0, 1000)),
    orientation: .init(), velocity: shot.velocity, npc: nil, rock: nil, payload: nil,
    priority: .ordinary)
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit,
      revision: context.revision, batches: [.init(requests: [request], atomic: true)], intents: []
    ))
  let admittedActor = try #require(receipts.first?.actor)
  let projectileIndex = try #require(
    game.bodies.firstIndex { $0.physical?.identity == admittedActor })
  game.bodies[projectileIndex].scriptShot = shot
  let live = game.bodies[projectileIndex]
  let projectileBodyID = live.id
  game.bodies = [live, .init(id: 101, hull: .cargo, position: .init(0, 0, 1400))]
  game.ensurePhysicalActors()
  game.commander.scriptState.projectiles[shotID] = .init(
    galaxy: game.commander.galaxy,
    system: game.commander.system, body: live, presence: .present)
  return .init(
    game: game, instance: instance, owner: owner, componentID: componentID, speed: speed,
    lifetime: lifetime, delay: delay, shotID: shotID, shot: shot, live: live,
    projectileBodyID: projectileBodyID
  )
}

private func assertBridgeLegacyPlasma(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let proof = try bridgeLegacyPlasmaProof(fixture)
  try bridgeLegacyPlasmaStaleProof(fixture, proof: proof)
  try bridgeLegacyPlasmaHitReplay(fixture)
  try bridgeLegacyPlasmaNoHitExpiry(fixture)
  try bridgeLegacyPlasmaWaitingExpired(fixture)
  try bridgeLegacyPlasmaCorruptJoins(fixture)
  try bridgeLegacyPlasmaDuplicateID(fixture)
  try bridgeLegacyPlasmaFasterShot(fixture)
  try bridgeLegacyPlasmaDamageDrift(fixture)
  try bridgeLegacyPlasmaDuplicateShot(fixture)
  try bridgeLegacyPlasmaRotatedShot(fixture)
}

private func bridgeLegacyPlasmaProof(_ fixture: BridgeLegacyPlasmaFixture) throws
  -> MissionNativeImpactProof
{
  let game = fixture.game
  let instance = fixture.instance
  let owner = fixture.owner
  let speed = fixture.speed
  let lifetime = fixture.lifetime
  let delay = fixture.delay
  let shotID = fixture.shotID
  let shot = fixture.shot
  let live = fixture.live
  let projectileBodyID = fixture.projectileBodyID
  let before = (commander: game.commander, bodies: game.bodies)
  let proofValue = try game.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
  let proof = try #require(proofValue)
  let collisionValue = try game.nearestMissionCollision(
    from: live.position + shot.velocity * delay, direction: shot.velocity.unit,
    range: speed * (0.5 - delay), radius: shot.radius, excludingBodyIDs: [projectileBodyID],
    includePlayer: true)
  let collision = try #require(collisionValue)
  #expect(proof.hit == collision.hit && proof.hit.target == .body(101))
  #expect(proof.sourceActorID == owner && proof.sourceInstanceID == instance)
  #expect(
    proof.originalOrigin == nil && proof.frozenJudgement == nil && proof.currentSource == nil)
  #expect(proof.shot.damage == shot.damage && proof.shot.velocity == shot.velocity)
  #expect(
    proof.shot.radius == shot.radius && proof.shot.lifetime == lifetime
      && proof.shot.collisionDelay == delay)
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  let freshBefore = (commander: game.commander, bodies: game.bodies)
  try game.validateMissionNativeImpactProof(proof)
  #expect(game.commander == freshBefore.commander && game.bodies == freshBefore.bodies)
  return proof
}

private func bridgeLegacyPlasmaStaleProof(
  _ fixture: BridgeLegacyPlasmaFixture, proof: MissionNativeImpactProof
) throws {
  let game = fixture.game
  for scenario in 0..<4 {
    var changed = game
    switch scenario {
    case 0: changed.bodies[0].position.x += 1
    case 1: changed.bodies[0].scriptShot?.age += 0.01
    case 2: changed.bodies[1].position.x += 1000
    default: changed.commander.flightSimulation.advancePhysicalTime(0.01)
    }
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try changed.validateMissionNativeImpactProof(proof)
    }
  }
}

private func bridgeLegacyPlasmaHitReplay(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let owner = fixture.owner
  let shotID = fixture.shotID
  let shot = fixture.shot
  var stepped = game
  let targetEnergy = try #require(stepped.bodies.first { $0.id == 101 }?.energy)
  let applied = try stepped.stepMissionNativeProjectile(projectileID: shotID, delta: 0.5)
  let receipt = try #require(applied)
  #expect(receipt.adjudication == .unknown && receipt.sourceActorID == owner)
  #expect(receipt.damage == shot.damage && receipt.terminalShotID == shotID)
  #expect(stepped.bodies.first { $0.id == 101 }?.energy == max(0, targetEnergy - shot.damage))
  #expect(stepped.commander.scriptState.projectiles[shotID] == nil)
  let committed = (commander: stepped.commander, bodies: stepped.bodies)
  let replay = try stepped.stepMissionNativeProjectile(projectileID: shotID, delta: 0.5)
  #expect(
    replay == nil && stepped.commander == committed.commander
      && stepped.bodies == committed.bodies)
}

private func bridgeLegacyPlasmaNoHitExpiry(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let lifetime = fixture.lifetime
  let delay = fixture.delay
  let shotID = fixture.shotID
  let shot = fixture.shot
  let live = fixture.live
  var noHit = game
  noHit.bodies[1].position = .init(0, 0, 10000)
  let incidentBefore = noHit.commander.flightSimulation.nextIncident
  let early = try noHit.stepMissionNativeProjectile(projectileID: shotID, delta: delay / 2)
  #expect(early == nil)
  #expect(noHit.bodies[0].position == live.position + shot.velocity * (delay / 2))
  #expect(noHit.bodies[0].scriptShot?.age == delay / 2)
  let expiredReceipt = try noHit.stepMissionNativeProjectile(
    projectileID: shotID, delta: lifetime + 1)
  #expect(
    expiredReceipt == nil && noHit.commander.flightSimulation.nextIncident == incidentBefore)
  #expect(noHit.bodies[0].energy == 0 && noHit.bodies[0].scriptShot?.age == lifetime)
  #expect(noHit.commander.scriptState.projectiles[shotID] == nil)
}

private func bridgeLegacyPlasmaWaitingExpired(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let lifetime = fixture.lifetime
  let delay = fixture.delay
  let shotID = fixture.shotID
  let waiting = try game.missionNativeImpactProof(projectileID: shotID, delta: delay / 2)
  #expect(waiting == nil)
  var expired = game
  expired.bodies[0].scriptShot?.age = lifetime
  let afterLife = try expired.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
  #expect(afterLife == nil)
}

private func bridgeLegacyPlasmaCorruptJoins(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let instance = fixture.instance
  let owner = fixture.owner
  let componentID = fixture.componentID
  let shotID = fixture.shotID
  let shot = fixture.shot
  for corruptOwner in [false, true] {
    var corrupt = game
    let wrong = UUID(uuidString: "00000000-0000-0000-0000-000000000098")!
    let altered = ScriptNPCShot(
      identity: shotID,
      owner: corruptOwner ? wrong : owner, instance: instance, weapon: shot.weapon,
      component: corruptOwner ? componentID : wrong, velocity: shot.velocity, age: shot.age,
      lifetime: shot.lifetime, damage: shot.damage, radius: shot.radius,
      collisionDelay: shot.collisionDelay)
    corrupt.bodies[0].scriptShot = altered
    corrupt.commander.scriptState.projectiles[shotID]?.body.scriptShot = altered
    #expect(throws: MissionNativeBridgeError.invalidShot) {
      try corrupt.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    }
  }
}

private func bridgeLegacyPlasmaDuplicateID(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let shotID = fixture.shotID
  let projectileBodyID = fixture.projectileBodyID
  var duplicateBodyID = game
  duplicateBodyID.bodies[1].id = projectileBodyID
  #expect(throws: MissionNativeBridgeError.invalidShot) {
    try duplicateBodyID.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
  }
}

private func bridgeLegacyPlasmaFasterShot(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let shotID = fixture.shotID
  var faster = game
  faster.bodies[0].scriptShot?.velocity.z += 1
  #expect(throws: MissionNativeBridgeError.invalidShot) {
    try faster.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
  }
}

private func bridgeLegacyPlasmaDamageDrift(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let instance = fixture.instance
  let owner = fixture.owner
  let componentID = fixture.componentID
  let lifetime = fixture.lifetime
  let delay = fixture.delay
  let shotID = fixture.shotID
  let shot = fixture.shot
  var drift = game
  drift.bodies[0].scriptShot = ScriptNPCShot(
    identity: shotID, owner: owner, instance: instance,
    weapon: shot.weapon, component: componentID, velocity: shot.velocity, age: 0,
    lifetime: lifetime,
    damage: shot.damage + 1, radius: shot.radius, collisionDelay: delay)
  #expect(throws: MissionNativeBridgeError.invalidShot) {
    try drift.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
  }
}

private func bridgeLegacyPlasmaDuplicateShot(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let shotID = fixture.shotID
  let live = fixture.live
  var duplicate = game
  var extra = live
  extra.id = 102
  duplicate.bodies.append(extra)
  #expect(throws: MissionNativeBridgeError.invalidShot) {
    try duplicate.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
  }
}

private func bridgeLegacyPlasmaRotatedShot(_ fixture: BridgeLegacyPlasmaFixture) throws {
  let game = fixture.game
  let speed = fixture.speed
  let shotID = fixture.shotID
  var rotated = game
  rotated.bodies[0].scriptShot?.velocity = .init(speed, 0, 0)
  rotated.bodies[1].position = .init(400, 0, 1000)
  let rotatedProofValue = try rotated.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
  let rotatedProof = try #require(rotatedProofValue)
  #expect(rotatedProof.hit.target == .body(101) && rotatedProof.originalOrigin == nil)
}

private func bridgeFixture() throws -> (SpaceBody, EncounterContext) {
  var game = Game(executive: false)
  game.launch()
  game.bodies = [.init(id: 42, hull: .constrictor, position: .init(0, 0, 2000))]
  game.bodies[0].missionActorID = bridgeActor
  game.bodies[0].missionInstanceID = bridgeInstance
  game.ensurePhysicalActors()
  return (try #require(game.bodies.first), try #require(game.gameplayContext()))
}
private func bridgeDescriptor(
  _ body: SpaceBody, _ context: EncounterContext,
  revision: UInt64 = 1, actorJoin: UUID? = bridgeActor,
  instanceJoin: UUID? = bridgeInstance, presence: String = "present"
) -> MissionActorDescriptor {
  .init(
    instanceID: bridgeInstance, instanceRevision: revision,
    packDigest: String(repeating: "a", count: 64), encounterID: "ambush", encounterAdmitted: true,
    system: context.system, alias: "enemy", actorID: bridgeActor, presence: presence,
    missionActorID: actorJoin, missionInstanceID: instanceJoin, body: body)
}
private func bridgeContext(
  _ context: EncounterContext, actors: [ActorSnapshot]? = nil,
  protection: MissionProtection? = nil, revision: UInt64? = nil, visit: UInt64? = nil
) -> EncounterContext {
  .init(
    system: context.system, seed: context.seed, government: context.government,
    visit: visit ?? context.visit, revision: revision ?? context.revision,
    physicalTime: context.physicalTime, anchors: context.anchors, player: context.player,
    actors: actors ?? context.actors, protection: protection ?? context.protection,
    budget: context.budget, perceptionRadius: context.perceptionRadius)
}
private func bridgeWeapon(
  _ kind: AttackKind = .laser, speed: Double? = nil,
  life: Double? = nil, radius: Double? = nil, delay: Double? = nil
) -> MissionWeaponDescriptor {
  .init(
    id: "cannon", kind: kind, damage: 23, range: 2345,
    projectileSpeed: speed, lifetime: life, collisionRadius: radius, collisionDelay: delay,
    muzzle: .init(1, 2, 3), direction: .init(0, 0, 1))
}

private func bridgeArchiveFixture() throws -> (MissionLaunchArchive, MissionShotDescriptor) {
  let (body, context) = try bridgeFixture()
  let source = try MissionNativeBridge.bindActor(
    descriptor: bridgeDescriptor(body, context), body: body, context: context)
  let actor = try #require(context.actors.first { $0.identity == source.nativeActor })
  let component = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
  // Pure shape/law fixture: does not claim an actual firing allocator or retained MC1 factory.
  let origin = AttackOrigin(
    emissionID: 1, owner: source.nativeActor, ordnance: nil,
    emittedAt: context.physicalTime, ownerLegalAtEmission: actor.legal,
    sourcePart: component.uuidString)
  let judgement = try CrimeLedger().freezeMissionLaunchJudgement(
    origin: origin, intendedVictim: context.player, emissionPosition: actor.position,
    context: context)
  let shot = MissionShotDescriptor(
    identity: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
    owner: source.actorID, instance: source.instanceID, weapon: "cannon", component: component,
    velocity: .init(0, 0, 777), age: 0, lifetime: 4, damage: 23, radius: 2, collisionDelay: 0.2)
  let archive = try MissionNativeBridge.makeLaunchArchive(
    shot: shot, source: source, intendedTarget: nil, judgement: judgement)
  return (archive, shot)
}

private func bridgeCollisionGame(components: [ScriptNPCComponent] = [], scale: Double = 1) throws
  -> Game
{
  var game = Game(executive: false)
  game.celestials = []
  let vertices: [[Double]] = [
    [0, 0, 0], [10, 0, 0], [10, 10, 0], [7, 10, 0], [7, 3, 0], [3, 3, 0], [3, 10, 0], [0, 10, 0],
  ]
  let face = Array(vertices.indices)
  let bytes = try JSONSerialization.data(withJSONObject: [
    "vertices": vertices,
    "faces": [face, Array(face.reversed()), face, Array(face.reversed())],
    "source": "test authored polygon", "license": "CC0",
  ])
  let design = try JSONDecoder().decode(ShipDesign.self, from: bytes)
  #expect(ScriptPackLibrary.scriptGeometryValid(design))
  let digest = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
  game.commander.scriptState.geometry[digest] = design
  let definition = ScriptNPCDefinition(
    id: "collision", name: "Collision fixture", source: "test",
    basis: "explicit native units", model: "asset:polygon", scale: scale, energy: 100,
    recharge: 0, speed: 0, acceleration: 0, pitch: 0, yaw: 0, roll: 0,
    missiles: 0, fuel: 0, ecm: false, bounty: 0, lasers: [], components: components)
  let npc = ScriptNPCState(
    fit: .init(definition: definition, models: ["asset:polygon": digest]),
    fuel: 0, guns: [:],
    components: Dictionary(
      uniqueKeysWithValues: components.map {
        ($0.id, ScriptNPCComponentState(identity: bridgeActor, energy: $0.energy, guns: [:]))
      }))
  #expect(npc.valid)
  var body = SpaceBody(id: 42, hull: .cobra, position: .init(0, 0, 100))
  body.scriptNPC = npc
  game.bodies = [body]
  return game
}

struct MissionNativeBridgeTests {
  @Test func realProtectedMissionActorBindsStableBodyIDWithoutAllocatingIdentity() throws {
    let (body, context) = try bridgeFixture()
    let descriptor = bridgeDescriptor(body, context)
    let binding = try MissionNativeBridge.bindActor(
      descriptor: descriptor, body: body, context: context)
    #expect(binding.bodyID == 42 && binding.bodyID != 0)
    #expect(binding.actorID == bridgeActor && binding.instanceID == bridgeInstance)
    #expect(binding.nativeActor == body.physical?.identity)
    try MissionNativeBridge.validateBinding(
      binding, descriptor: descriptor, body: body, context: context)
    #expect(context.actors.count == 1 && context.actors.first?.identity == binding.nativeActor)
  }

  @Test func missingUnprotectedWrongVisitAndUUIDJoinsRefuseBinding() throws {
    let (body, context) = try bridgeFixture()
    let descriptor = bridgeDescriptor(body, context)
    #expect(throws: MissionNativeBridgeError.missingActor) {
      try MissionNativeBridge.bindActor(
        descriptor: descriptor, body: body,
        context: bridgeContext(context, actors: []))
    }
    #expect(throws: MissionNativeBridgeError.invalidNativeBinding) {
      try MissionNativeBridge.bindActor(
        descriptor: descriptor, body: body,
        context: bridgeContext(context, protection: .init()))
    }
    #expect(throws: MissionNativeBridgeError.invalidNativeBinding) {
      try MissionNativeBridge.bindActor(
        descriptor: descriptor, body: body,
        context: bridgeContext(context, visit: context.visit + 1))
    }
    for bad in [
      bridgeDescriptor(body, context, actorJoin: nil),
      bridgeDescriptor(body, context, instanceJoin: bridgeActor),
    ] {
      #expect(throws: MissionNativeBridgeError.sourceMismatch) {
        try MissionNativeBridge.bindActor(descriptor: bad, body: body, context: context)
      }
    }
    let lying = MissionActorDescriptor(
      instanceID: bridgeActor, instanceRevision: descriptor.instanceRevision,
      packDigest: descriptor.packDigest, encounterID: descriptor.encounterID,
      encounterAdmitted: descriptor.encounterAdmitted, system: descriptor.system,
      alias: descriptor.alias, actorID: bridgeInstance, presence: descriptor.presence,
      missionActorID: bridgeInstance, missionInstanceID: bridgeActor, body: body)
    #expect(throws: MissionNativeBridgeError.sourceMismatch) {
      try MissionNativeBridge.bindActor(descriptor: lying, body: body, context: context)
    }
    for scenario in 0..<4 {
      var malformed = body
      var matchingContext = context
      if scenario == 0 { malformed.position.x = .infinity }
      if scenario == 1 { malformed.orientation.x = .init(2, 0, 0) }
      if scenario == 2 { malformed.physical?.velocity.x = .infinity }
      if scenario == 3 {
        let physical = try #require(malformed.physical)
        let reserved = ActorIdentity(system: context.system, visit: context.visit, entity: 1)
        malformed.physical = .init(
          identity: reserved,
          population: physical.population, npc: physical.npc, velocity: physical.velocity,
          angularVelocity: physical.angularVelocity)
        let actor = try #require(context.actors.first)
        let reservedSnapshot = ActorSnapshot(
          identity: reserved, hull: actor.hull, position: actor.position,
          orientation: actor.orientation, velocity: actor.velocity, energy: actor.energy,
          maximumEnergy: actor.maximumEnergy,
          maximumSpeedUnitsPerSecond: actor.maximumSpeedUnitsPerSecond,
          legal: actor.legal, npc: actor.npc, rock: actor.rock, payload: actor.payload)
        var protection = context.protection
        protection.protectedActors = [reserved]
        matchingContext = bridgeContext(context, actors: [reservedSnapshot], protection: protection)
      }
      let matching = bridgeDescriptor(malformed, matchingContext)
      #expect(throws: MissionNativeBridgeError.invalidNativeBinding) {
        try MissionNativeBridge.bindActor(
          descriptor: matching, body: malformed, context: matchingContext)
      }
    }
    var ordinary = body
    ordinary.physical?.population = .civilian
    ordinary.physical?.npc?.role = .trader
    #expect(throws: MissionNativeBridgeError.invalidNativeBinding) {
      try MissionNativeBridge.bindActor(
        descriptor: bridgeDescriptor(ordinary, context),
        body: ordinary, context: context)
    }
  }

  @Test func bindingPinsDescriptorBodyAndSceneActorSnapshotRatherThanOnlySourceUUID() throws {
    let (body, context) = try bridgeFixture()
    let descriptor = bridgeDescriptor(body, context)
    let binding = try MissionNativeBridge.bindActor(
      descriptor: descriptor, body: body, context: context)
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try MissionNativeBridge.validateBinding(
        binding,
        descriptor: bridgeDescriptor(body, context, revision: 2), body: body, context: context)
    }
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try MissionNativeBridge.validateBinding(
        binding, descriptor: descriptor, body: body,
        context: bridgeContext(context, revision: context.revision + 1))
    }
    var changed = body
    changed.position.x += 1
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try MissionNativeBridge.validateBinding(
        binding, descriptor: descriptor, body: changed, context: context)
    }
    let actor = try #require(context.actors.first)
    let actors = [
      ActorSnapshot(
        identity: actor.identity, hull: actor.hull,
        position: actor.position + Vector3(1, 0, 0), orientation: actor.orientation,
        velocity: actor.velocity, energy: actor.energy, maximumEnergy: actor.maximumEnergy,
        maximumSpeedUnitsPerSecond: actor.maximumSpeedUnitsPerSecond,
        legal: actor.legal, npc: actor.npc, rock: actor.rock, payload: actor.payload,
        ordinaryCargo: actor.ordinaryCargo, catalogueShipID: actor.catalogueShipID,
        angularVelocity: actor.angularVelocity, salvage: actor.salvage)
    ]
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try MissionNativeBridge.validateBinding(
        binding, descriptor: descriptor, body: body,
        context: bridgeContext(context, actors: actors))
    }
  }

  @Test func weaponValidationKeepsAuthoredPlasmaValuesAndRejectsLaserProjectileFields() throws {
    try MissionNativeBridge.validateWeapon(bridgeWeapon())
    let authored = bridgeWeapon(.plasma, speed: 777, life: 4.5, radius: 2.3, delay: 0.4)
    try MissionNativeBridge.validateWeapon(authored)
    #expect(authored.projectileSpeed == 777 && authored.lifetime == 4.5)
    for bad in [
      bridgeWeapon(speed: 777), bridgeWeapon(.missile),
      bridgeWeapon(.plasma, speed: .nan, life: 4, radius: 2, delay: 0),
      bridgeWeapon(.plasma, speed: 777, life: 0, radius: 2, delay: 0),
      bridgeWeapon(.plasma, speed: 777, life: 4, radius: 101, delay: 0),
      bridgeWeapon(.plasma, speed: 777, life: 4, radius: 2, delay: 4),
    ] {
      #expect(throws: MissionNativeBridgeError.unsupportedWeapon) {
        try MissionNativeBridge.validateWeapon(bad)
      }
    }
  }

  @Test func shotValidationUsesExistingBoundsWithoutAllocatingOrRejectingOldAgeByNewPolicy() throws
  {
    func shot(age: Double = 5, life: Double = 2, speed: Double = 777, delay: Double = 0.2)
      -> MissionShotDescriptor
    {
      .init(
        identity: bridgeActor, owner: bridgeActor, instance: bridgeInstance,
        weapon: "cannon", component: nil, velocity: .init(0, 0, speed),
        age: age, lifetime: life, damage: 23, radius: 2, collisionDelay: delay)
    }
    let old = shot()
    try MissionNativeBridge.validateShot(old)
    #expect(old.age > old.lifetime && old.identity == bridgeActor)
    try MissionNativeBridge.validateShot(shot(age: 60, life: 60, speed: 100000, delay: 60))
    for invalid in [
      shot(age: -1), shot(age: 61), shot(life: 0), shot(speed: 0),
      shot(speed: .infinity), shot(delay: 3),
    ] {
      #expect(throws: MissionNativeBridgeError.invalidShot) {
        try MissionNativeBridge.validateShot(invalid)
      }
    }
  }
  @Test func actualFrozenNativeLawArchiveRoundTripsExactSourceAndAcceptsAbsentLegacyHistory() throws
  {
    let (archive, shot) = try bridgeArchiveFixture()
    #expect(archive.valid && archive.schemaVersion == 1)
    #expect(archive.sourceActorID == bridgeActor && archive.instanceID == bridgeInstance)
    #expect(
      archive.sourceComponentID == shot.component
        && archive.origin.sourcePart == shot.component?.uuidString)
    #expect(archive.intendedTarget == .player && archive.judgement.victim.entity == 0)
    #expect(!archive.judgement.launchEffectsApplied)
    let decoded = try JSONDecoder().decode(
      MissionLaunchArchive.self, from: JSONEncoder().encode(archive))
    #expect(
      decoded == archive && decoded.judgement == archive.judgement
        && decoded.origin == archive.origin)
    try MissionNativeBridge.validateArchive(decoded, shot: shot, packDigest: archive.packDigest)
    try MissionNativeBridge.validateArchive(nil, shot: shot, packDigest: archive.packDigest)
  }

  @Test func presentArchiveWrongShotSourceDigestOrComponentIsHardErrorNotUnknownHistory() throws {
    let (archive, shot) = try bridgeArchiveFixture()
    for scenario in 0..<4 {
      let other = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
      let changed = MissionShotDescriptor(
        identity: scenario == 0 ? other : shot.identity,
        owner: scenario == 1 ? other : shot.owner,
        instance: scenario == 2 ? other : shot.instance, weapon: shot.weapon,
        component: scenario == 3 ? other : shot.component, velocity: shot.velocity,
        age: shot.age, lifetime: shot.lifetime, damage: shot.damage, radius: shot.radius,
        collisionDelay: shot.collisionDelay)
      #expect(throws: MissionNativeBridgeError.invalidArchive) {
        try MissionNativeBridge.validateArchive(
          archive, shot: changed, packDigest: archive.packDigest)
      }
    }
    #expect(throws: MissionNativeBridgeError.invalidArchive) {
      try MissionNativeBridge.validateArchive(
        archive, shot: shot, packDigest: String(repeating: "b", count: 64))
    }
  }

  @Test func decodedMalformedPresentArchiveVersionAndLawAreRejectedInsteadOfBecomingNil() throws {
    let (archive, _) = try bridgeArchiveFixture()
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
    for version in [0, 2, -1] {
      var object = encoded
      object["schemaVersion"] = version
      let data = try JSONSerialization.data(withJSONObject: object)
      #expect(throws: MissionNativeBridgeError.invalidArchive) {
        try JSONDecoder().decode(MissionLaunchArchive.self, from: data)
      }
    }
    var malformed = encoded
    malformed["packDigest"] = "invalid"
    let data = try JSONSerialization.data(withJSONObject: malformed)
    #expect(throws: MissionNativeBridgeError.invalidArchive) {
      try JSONDecoder().decode(MissionLaunchArchive.self, from: data)
    }
    malformed = encoded
    malformed.removeValue(forKey: "judgement")
    let missing = try JSONSerialization.data(withJSONObject: malformed)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(MissionLaunchArchive.self, from: missing)
    }
  }

  @Test func actualRetainedProfiledPackResolverRechecksRevisionBodyAndInstalledContent() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let pack = try ScriptPackLibrary.read(directory)
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    game.ensurePhysicalActors()
    let body = try #require(
      game.bodies.first { $0.missionInstanceID == instance && $0.scriptNPC != nil })
    let binding = try game.currentMissionNativeBinding(bodyID: body.id)
    #expect(binding.actorID == body.missionActorID && binding.instanceID == instance)
    try game.validateMissionNativeBinding(binding)
    let original = game
    game.commander.scriptState.instances[instance]?.revision += 1
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try game.validateMissionNativeBinding(binding)
    }
    game = original
    let index = try #require(game.bodies.firstIndex { $0.id == body.id })
    game.bodies[index].energy -= 1
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try game.validateMissionNativeBinding(binding)
    }
    game = original
    game.scriptPacks = []
    #expect(throws: MissionNativeBridgeError.sourceMismatch) {
      try game.validateMissionNativeBinding(binding)
    }
  }

  @Test func fabricatedNativeBodyCannotPassActualResolverWithoutRetainedMissionAuthority() throws {
    var game = Game(executive: false)
    game.launch()
    var body = SpaceBody(id: 42, hull: .constrictor, position: .init(0, 0, 2000))
    body.missionActorID = bridgeActor
    body.missionInstanceID = bridgeInstance
    game.bodies = [body]
    game.ensurePhysicalActors()
    let native = try #require(game.bodies.first)
    let context = try #require(game.gameplayContext())
    let pure = try MissionNativeBridge.bindActor(
      descriptor: bridgeDescriptor(native, context),
      body: native, context: context)
    #expect(pure.bodyID == native.id)
    #expect(throws: MissionNativeBridgeError.sourceMismatch) {
      try game.currentMissionNativeBinding(bodyID: native.id)
    }
  }

  @Test func positiveRadiusRespectsConcaveAuthoredNotchAndMissingGeometryIsHardFailure() throws {
    var game = try bridgeCollisionGame()
    let notch = try game.nearestMissionCollision(
      from: .init(5, 6, 0), direction: .init(0, 0, 1),
      range: 200, radius: 0.2, includePlayer: false)
    #expect(notch == nil)
    let solid = try game.nearestMissionCollision(
      from: .init(1, 6, 0), direction: .init(0, 0, 1),
      range: 200, radius: 0.2, includePlayer: false)
    #expect(solid?.hit.target == .body(42))
    game.commander.scriptState.geometry = [:]
    #expect(throws: MissionNativeBridgeError.invalidGeometry) {
      try game.nearestMissionCollision(
        from: .init(5, 6, 0), direction: .init(0, 0, 1),
        range: 200, radius: 0.2, includePlayer: false)
    }
  }

  @Test func customComponentUsesActualRenderingScaleOrientationSpinAndSolidLiveState() throws {
    var orientation = Basis3()
    orientation.rotate(pitch: 0, roll: 0.3, yaw: 0)
    let component = ScriptNPCComponent(
      id: "wing", model: "asset:polygon", scale: 3,
      position: .init(20, 0, 0), orientation: orientation, energy: 10, solid: true, weapons: [])
    var game = try bridgeCollisionGame(components: [component], scale: 2)
    game.bodies[0].rotation = 0.4
    let body = game.bodies[0]
    let rendered = try #require(game.scriptNPCMesh(body))
    let local =
      (component.position + component.orientation.apply(Vector3(1, 6, 0) * component.scale)) * 2
    let point = body.position + body.modelVector(local)
    let direction = body.modelVector(.init(0, 0, 1)).unit
    let contactValue = try game.nearestMissionCollision(
      from: point - direction * 50,
      direction: direction, range: 100, radius: 0.1, includePlayer: false)
    let contact = try #require(contactValue)
    #expect(contact.victimPart == "wing" && contact.componentUUID == bridgeActor)
    #expect(contact.selectedTargetBody?.id == 42)
    let expectedVertex = (component.position + orientation.apply(Vector3(10, 0, 0) * 3)) * 2
    #expect(rendered.vertices.contains { ($0 - expectedVertex).length < 1e-9 })
    game.bodies[0].scriptNPC?.components["wing"]?.energy = 0
    let dead = try game.nearestMissionCollision(
      from: point - direction * 50,
      direction: direction, range: 100, radius: 0.1, includePlayer: false)
    #expect(dead == nil)
    let nonsolid = ScriptNPCComponent(
      id: "wing", model: "asset:polygon", scale: 3,
      position: component.position, orientation: orientation, energy: 10, solid: false, weapons: [])
    var ghost = try bridgeCollisionGame(components: [nonsolid], scale: 2)
    ghost.bodies[0].rotation = 0.4
    #expect(
      try ghost.nearestMissionCollision(
        from: point - direction * 50,
        direction: direction, range: 100, radius: 0.1, includePlayer: false) == nil)
  }

  @Test func nativeTiesUseStableBodyIDAndCelestialOcclusionIncludesProjectileRadius() throws {
    var game = Game(executive: false)
    game.celestials = []
    let first = SpaceBody(id: 9, hull: .cargo, position: .init(0, 0, 500))
    let second = SpaceBody(id: 3, hull: .cargo, position: first.position)
    for bodies in [[first, second], [second, first]] {
      game.bodies = bodies
      let hit = try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 1000, radius: 1, includePlayer: false)
      #expect(hit?.hit.target == .body(3))
    }
    var duplicateID = game
    var duplicateBody = second
    duplicateBody.position.x += 100
    duplicateID.bodies.append(duplicateBody)
    #expect(throws: MissionNativeBridgeError.invalidGeometry) {
      try duplicateID.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 1000, radius: 1, excludingBodyIDs: [3], includePlayer: false)
    }
    game.celestials = [.init(kind: .planet, position: .init(0, 0, 200), radius: 10)]
    let celestial = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1),
      range: 1000, radius: 2, includePlayer: false)
    #expect(celestial?.hit.target == .celestial(.planet))
    #expect(abs((celestial?.hit.distance ?? 0) - 188) < 1e-8)
    game.bodies[0].energy = 0
    game.bodies[1].energy = 0
    game.celestials = []
    #expect(
      try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 1000, radius: 1, includePlayer: false) == nil)
  }

  @Test func degenerateZeroRayAndNegativeCelestialCannotExposeBehindTargetAndTinyScaleHits() throws
  {
    var degenerate = try bridgeCollisionGame()
    let data = try JSONSerialization.data(withJSONObject: [
      "vertices": [[0, 0, 0], [1, 0, 0], [2, 0, 0], [3, 0, 0]],
      "faces": [[0, 1, 2], [0, 2, 3], [0, 1, 3], [1, 2, 3]], "source": "test", "license": "CC0",
    ])
    let design = try JSONDecoder().decode(ShipDesign.self, from: data)
    let hash = try #require(degenerate.bodies[0].scriptNPC?.fit.models["asset:polygon"])
    degenerate.commander.scriptState.geometry[hash] = design
    degenerate.bodies.append(.init(id: 99, hull: .cargo, position: .init(0, 0, 500)))
    #expect(throws: MissionNativeBridgeError.invalidGeometry) {
      try degenerate.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 1000, radius: 0, includePlayer: false)
    }
    var celestial = Game(executive: false)
    celestial.bodies = []
    celestial.celestials = [.init(kind: .planet, position: .init(0, 0, 100), radius: -1)]
    #expect(throws: MissionNativeBridgeError.invalidGeometry) {
      try celestial.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 200, radius: 2, includePlayer: false)
    }
    let component = ScriptNPCComponent(
      id: "tiny", model: "asset:polygon", scale: 0.001,
      position: .init(20, 0, 0), orientation: .init(), energy: 10, solid: true, weapons: [])
    let tiny = try bridgeCollisionGame(components: [component], scale: 0.001)
    let point = Vector3(0.020001, 0.000006, 100)
    let contact = try tiny.nearestMissionCollision(
      from: point - Vector3(0, 0, 0.005),
      direction: .init(0, 0, 1), range: 0.01, radius: 0, includePlayer: false)
    #expect(contact?.victimPart == "tiny" && contact?.componentUUID == bridgeActor)
  }

  @Test func actualProfiledLaserProofAllocatesOnlyAfterPhysicalPreflightAndMissHasNoShot() throws {
    let fixture = try makeBridgeLaserProofFixture()
    try assertBridgeLaserProof(fixture)
  }

  @Test func actualLegacyPlasmaRecordProducesGeometricUnknownImpactAndRejectsImmutableDrift() throws
  {
    let fixture = try makeBridgeLegacyPlasmaFixture()
    try assertBridgeLegacyPlasma(fixture)
  }

  @Test func actualArchivedPlasmaProofUsesFrozenLawOnlyForCurrentSourceAndIntendedVictim() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let pack = try ScriptPackLibrary.read(directory)
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    game.ensurePhysicalActors()
    let sourceBody = try #require(
      game.bodies.first { $0.missionInstanceID == instance && $0.scriptNPC != nil })
    game.bodies = [sourceBody]
    game.celestials = []
    let binding = try game.currentMissionNativeBinding(bodyID: sourceBody.id)
    let componentSpec = try #require(
      sourceBody.scriptNPC?.fit.definition.components?.first {
        ($0.weapons ?? []).contains { $0.kind == .plasma }
      })
    let weapon = try #require(componentSpec.weapons?.first { $0.kind == .plasma })
    let componentID = try #require(sourceBody.scriptNPC?.components[componentSpec.id]?.identity)
    let allocatedOrigin = game.makeAttackOrigin(
      owner: binding.nativeActor, sourcePart: componentID.uuidString)
    let origin = try #require(allocatedOrigin)
    let context = try #require(game.gameplayContext())
    let launchPosition = Vector3(0, 0, 500)
    let law = try game.commander.crimeLedger.freezeMissionLaunchJudgement(
      origin: origin,
      intendedVictim: context.player,
      emissionPosition: game.commander.flightSimulation.pose.systemPoint(launchPosition),
      context: context)
    let speed = try #require(weapon.projectileSpeed)
    let lifetime = try #require(weapon.lifetime)
    let radius = try #require(weapon.collisionRadius)
    let delay = try #require(weapon.collisionDelay)
    let shotID = UUID(uuidString: "00000000-0000-0000-0000-000000000060")!
    let descriptor = MissionShotDescriptor(
      identity: shotID, owner: binding.actorID,
      instance: binding.instanceID, weapon: weapon.id, component: componentID,
      velocity: .init(0, 0, -speed), age: 0, lifetime: lifetime, damage: weapon.damage,
      radius: radius, collisionDelay: delay)
    let archive = try MissionNativeBridge.makeLaunchArchive(
      shot: descriptor, source: binding,
      intendedTarget: nil, judgement: law)
    let shot = ScriptNPCShot(
      identity: shotID, owner: binding.actorID, instance: binding.instanceID,
      weapon: weapon.id, component: componentID, velocity: descriptor.velocity, age: 0,
      lifetime: lifetime, damage: weapon.damage, radius: radius, collisionDelay: delay,
      nativeAttribution: archive)
    let allocatedSpawn = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSpawn)
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit,
        sequence: sequence, member: 0, producer: .ordnance), population: .projectile,
      hull: .missile, position: game.commander.flightSimulation.pose.systemPoint(launchPosition),
      orientation: .init(), velocity: descriptor.velocity, npc: nil, rock: nil, payload: nil,
      priority: .ordinary)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: [request], atomic: true)], intents: []
      ))
    let actor = try #require(receipts.first?.actor)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    game.bodies[index].scriptShot = shot
    game.bodies[index].physical?.attackOrigin = archive.origin
    let live = game.bodies[index]
    game.commander.scriptState.projectiles[shotID] = .init(
      galaxy: game.commander.galaxy,
      system: game.commander.system, body: live, presence: .present)
    let knownValue = try game.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    let known = try #require(knownValue)
    #expect(known.hit.target == .player && known.currentSource == binding.nativeActor)
    #expect(known.originalOrigin == origin && known.frozenJudgement == law)
    let freshKnownBefore = game
    try game.validateMissionNativeImpactProof(known)
    #expect(game.commander == freshKnownBefore.commander && game.bodies == freshKnownBefore.bodies)
    var changedSource = game
    let sourceIndex = try #require(changedSource.bodies.firstIndex { $0.id == sourceBody.id })
    changedSource.bodies[sourceIndex].energy -= 1
    #expect(throws: MissionNativeBridgeError.staleBinding) {
      try changedSource.validateMissionNativeImpactProof(known)
    }
    var older = game
    older.commander.flightSimulation.advancePhysicalTime(1)
    let historicalValue = try older.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    let historical = try #require(historicalValue)
    #expect(historical.originalOrigin == origin && historical.frozenJudgement == law)
    #expect(origin.emittedAt < older.commander.flightSimulation.physicalTime)
    var shotJSON = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(shot)) as? [String: Any])
    var archiveJSON = try #require(shotJSON["nativeAttribution"] as? [String: Any])
    var judgementJSON = try #require(archiveJSON["judgement"] as? [String: Any])
    var factsJSON = try #require(judgementJSON["facts"] as? [String: Any])
    var originJSON = try #require(factsJSON["origin"] as? [String: Any])
    originJSON["emittedAt"] = game.commander.flightSimulation.physicalTime + 100
    factsJSON["origin"] = originJSON
    judgementJSON["facts"] = factsJSON
    archiveJSON["judgement"] = judgementJSON
    shotJSON["nativeAttribution"] = archiveJSON
    let futureShot = try JSONDecoder().decode(
      ScriptNPCShot.self,
      from: JSONSerialization.data(withJSONObject: shotJSON))
    let futureArchive = try #require(futureShot.nativeAttribution)
    #expect(futureArchive.valid && futureShot.valid)
    var future = game
    future.bodies[index].scriptShot = futureShot
    future.bodies[index].physical?.attackOrigin = futureArchive.origin
    future.commander.scriptState.projectiles[shotID]?.body.scriptShot = futureShot
    future.commander.scriptState.projectiles[shotID]?.body.physical?.attackOrigin =
      futureArchive.origin
    let futureBefore = future
    #expect(throws: MissionNativeBridgeError.invalidArchive) {
      try future.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    }
    #expect(future.commander == futureBefore.commander && future.bodies == futureBefore.bodies)
    var absent = game
    absent.bodies.removeAll { $0.id == sourceBody.id }
    let unknownValue = try absent.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    let unknown = try #require(unknownValue)
    #expect(unknown.hit.target == .player && unknown.currentSource == nil)
    #expect(unknown.originalOrigin == origin && unknown.frozenJudgement == nil)
    var incidental = game
    incidental.bodies.append(.init(id: 999, hull: .cargo, position: .init(0, 0, 250)))
    incidental.ensurePhysicalActors()
    let blockedValue = try incidental.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    let blocked = try #require(blockedValue)
    #expect(blocked.hit.target == .body(999) && blocked.currentVictim != nil)
    #expect(blocked.originalOrigin == origin && blocked.frozenJudgement == nil)
    var malformed = game
    malformed.bodies[index].physical?.attackOrigin = nil
    #expect(throws: MissionNativeBridgeError.invalidShot) {
      try malformed.missionNativeImpactProof(projectileID: shotID, delta: 0.5)
    }
  }

  @Test func realRoundedCapitalAndFighterFacesPreserveNativeZeroRayAndAcceptSweptQueries() throws {
    for id in ["SH043", "SH171", "SH041"] {
      let ship = try #require(ShipCatalogue.ship(id))
      var game = Game(executive: false)
      game.launch()
      game.celestials = []
      game.bodies = [.init(id: 42, hull: ship.nativeHull ?? .cobra, position: .init(0, 0, 5000))]
      game.ensurePhysicalActors()
      game.bodies[0].physical?.catalogueShipID = id
      let body = game.bodies[0]
      let mesh = game.gameplayMesh(for: body)
      #expect(
        mesh.vertices == ship.design.rawMesh.vertices && mesh.faces == ship.design.rawMesh.faces)
      let faceIndex = try #require(["SH043": 9, "SH171": 13, "SH041": 12][id])
      let face = mesh.faces[faceIndex]
      let faceNormal = (mesh.vertices[face[1]] - mesh.vertices[face[0]])
        .cross(mesh.vertices[face[2]] - mesh.vertices[face[0]]).unit
      #expect(
        face.dropFirst(3).contains {
          abs((mesh.vertices[$0] - mesh.vertices[face[0]]).dot(faceNormal)) > 0
        })
      let center =
        face.reduce(Vector3(0, 0, 0)) { $0 + mesh.vertices[$1] } * (1 / Double(face.count))
      let normal = (mesh.vertices[face[1]] - mesh.vertices[face[0]])
        .cross(mesh.vertices[face[2]] - mesh.vertices[face[0]]).unit
      let origin = body.position + body.modelVector(center + normal * 100)
      let direction = body.modelVector(normal * -1).unit
      let expected = GameplayRaycast.nearest(
        origin: origin, direction: direction, maxDistance: 200,
        bodies: game.bodies, meshOverrides: game.gameplayMeshOverrides)
      let zero = try game.nearestMissionCollision(
        from: origin, direction: direction,
        range: 200, radius: 0, includePlayer: false)
      #expect(zero?.hit == expected)
      let swept = try game.nearestMissionCollision(
        from: origin, direction: direction,
        range: 200, radius: 0.1, includePlayer: false)
      #expect(expected?.target == .body(42))
      #expect(swept?.hit.target == .body(42))
    }
  }

  @Test func allActualCatalogueAndNativeHullAssetsPermitFarMissWithoutInvalidGeometry() throws {
    func assertActualCandidate(_ game: Game) throws {
      let body = try #require(game.bodies.first)
      let vertices = game.gameplayMesh(for: body).vertices.map {
        body.position + body.modelVector($0)
      }
      let minX = try #require(vertices.map(\.x).min())
      let maxX = try #require(vertices.map(\.x).max())
      let minY = try #require(vertices.map(\.y).min())
      let maxY = try #require(vertices.map(\.y).max())
      let minZ = try #require(vertices.map(\.z).min())
      let maxZ = try #require(vertices.map(\.z).max())
      let origin = Vector3((minX + maxX) / 2, (minY + maxY) / 2, minZ - 1)
      for radius in [0.0, 0.1] {
        let candidate = try game.nearestMissionCollision(
          from: origin,
          direction: .init(0, 0, 1), range: maxZ - minZ + 2,
          radius: radius, includePlayer: false)
        if let candidate { #expect(candidate.hit.target == .body(body.id)) }
      }
    }
    var nativeHulls: Set<Hull> = []
    for ship in ShipCatalogue.all {
      var game = Game(executive: false)
      game.launch()
      game.celestials = []
      game.bodies = [.init(id: 42, hull: ship.nativeHull ?? .cobra, position: .init(0, 0, 5000))]
      game.ensurePhysicalActors()
      game.bodies[0].physical?.catalogueShipID = ship.id
      for radius in [0.0, 0.1] {
        let contact = try game.nearestMissionCollision(
          from: .init(10_000_000, 10_000_000, 0),
          direction: .init(0, 0, 1), range: 10000, radius: radius, includePlayer: false)
        #expect(contact == nil, "Catalogue asset \(ship.id) radius \(radius)")
      }
      try assertActualCandidate(game)
      if let hull = ship.nativeHull, nativeHulls.insert(hull).inserted {
        game.bodies[0].physical?.catalogueShipID = nil
        for radius in [0.0, 0.1] {
          let contact = try game.nearestMissionCollision(
            from: .init(10_000_000, 10_000_000, 0),
            direction: .init(0, 0, 1), range: 10000, radius: radius, includePlayer: false)
          #expect(contact == nil, "Actual native hull \(hull) radius \(radius)")
        }
        try assertActualCandidate(game)
      }
    }
  }

  @Test func warpedConvexQuadSweptContactConvergesToOriginalNativeFanSurface() throws {
    var game = try bridgeCollisionGame()
    let vertices: [[Double]] = [[0, 0, 0], [10, 0, 0], [10, 10, 1], [0, 10, 0]]
    let face = [0, 1, 2, 3]
    let data = try JSONSerialization.data(withJSONObject: [
      "vertices": vertices, "faces": [face, face, face, face],
      "source": "native fan regression", "license": "CC0",
    ])
    let design = try JSONDecoder().decode(ShipDesign.self, from: data)
    #expect(ScriptPackLibrary.scriptGeometryValid(design))
    let digest = try #require(game.bodies[0].scriptNPC?.fit.models["asset:polygon"])
    game.commander.scriptState.geometry[digest] = design
    let origin = Vector3(4, 4, 110)
    let direction = Vector3(0, 0, -1)
    let body = game.bodies[0]
    let native = try #require(
      GameplayRaycast.nearest(
        origin: origin, direction: direction,
        maxDistance: 20, bodies: [body], meshOverrides: [body.id: design.rawMesh]))
    let zeroValue = try game.nearestMissionCollision(
      from: origin, direction: direction,
      range: 20, radius: 0, includePlayer: false)
    let zero = try #require(zeroValue)
    #expect(zero.hit == native)
    #expect(abs(zero.hit.distance - 9.6) < 1e-8)
    let sweptValue = try game.nearestMissionCollision(
      from: origin, direction: direction,
      range: 20, radius: 0.001, includePlayer: false)
    let swept = try #require(sweptValue)
    #expect(swept.hit.target == .body(42))
    #expect(abs(swept.hit.distance - zero.hit.distance) < 0.002)
    #expect(swept.hit.distance < zero.hit.distance)
  }

  @Test func inflatedBoundsSkipOffAxisInvalidFacesButCandidateGeometryStillRefuses() throws {
    var game = try bridgeCollisionGame()
    let data = try JSONSerialization.data(withJSONObject: [
      "vertices": [[0, 0, 0], [3, 3, 0], [0, 3, 0], [3, 0, 0]],
      "faces": Array(repeating: [0, 1, 2, 3], count: 4),
      "source": "finite candidate bounds regression", "license": "CC0",
    ])
    let design = try JSONDecoder().decode(ShipDesign.self, from: data)
    #expect(ScriptPackLibrary.scriptGeometryValid(design))
    let digest = try #require(game.bodies[0].scriptNPC?.fit.models["asset:polygon"])
    game.commander.scriptState.geometry[digest] = design
    for position in [Vector3(1000, 0, 100), Vector3(0, 0, 1000)] {
      game.bodies[0].position = position
      for radius in [0.0, 0.1] {
        let result = try game.nearestMissionCollision(
          from: .init(0, 0, 0),
          direction: .init(0, 0, 1), range: 200, radius: radius, includePlayer: false)
        #expect(result == nil)
      }
    }
    game.bodies[0].position = .init(0, 0, 100)
    #expect(throws: MissionNativeBridgeError.invalidGeometry) {
      try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 200, radius: 0.1, includePlayer: false)
    }
  }

  @Test func actualProfiledLaserFireDebitsOnceAndKernelRefusalRestoresWholeVisibleState() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let pack = try ScriptPackLibrary.read(directory)
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    let originalSource = try #require(
      game.bodies.first { $0.missionInstanceID == instance && $0.scriptNPC != nil })
    game.bodies = [originalSource]
    game.celestials = []
    game.bodies[0].position = .init(0, 0, 1000)
    var facing = Basis3()
    facing.rotate(pitch: 0, roll: 0, yaw: .pi)
    game.bodies[0].orientation = facing
    game.bodies[0].scriptNPC?.intent = .init(
      request: "fire-test", mode: .attack,
      target: nil, player: true, offset: .init(0, 0, 0), speed: 0, tolerance: 10)
    game.ensurePhysicalActors()
    let source = game.bodies[0]
    let weapon = try #require(source.scriptNPC?.fit.definition.lasers?.first { $0.kind == .laser })
    let gun = try #require(source.scriptNPC?.guns[weapon.id])
    let shots = try #require(source.scriptNPC?.shots)
    let before = game
    var ledgerJSON = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander.crimeLedger))
        as? [String: Any])
    ledgerJSON["lastIncidentID"] = NSNumber(value: game.commander.flightSimulation.nextIncident)
    var refused = game
    refused.commander.crimeLedger = try JSONDecoder().decode(
      CrimeLedger.self,
      from: JSONSerialization.data(withJSONObject: ledgerJSON))
    let refusedBefore = refused
    #expect(throws: NativeMissionImpactError.refusedLedger) {
      try refused.fireMissionNativeLaser(bodyID: source.id, weaponID: weapon.id, componentID: nil)
    }
    #expect(refused.commander == refusedBefore.commander && refused.bodies == refusedBefore.bodies)
    #expect(
      refused.frontShield == refusedBefore.frontShield
        && refused.rearShield == refusedBefore.rearShield && refused.energy == refusedBefore.energy)
    let result = try game.fireMissionNativeLaser(
      bodyID: source.id, weaponID: weapon.id, componentID: nil)
    let receipt = try #require(result)
    #expect(receipt.kind == .laser && receipt.target == .player)
    #expect(game.bodies[0].energy == source.energy - weapon.energy)
    #expect(game.bodies[0].scriptNPC?.guns[weapon.id]?.heat == gun.heat + weapon.heat)
    #expect(game.bodies[0].scriptNPC?.guns[weapon.id]?.cooldown == weapon.interval)
    #expect(game.bodies[0].scriptNPC?.shots == shots + 1)
    let firedBefore = before.commander.scriptState.pendingEvents.filter {
      $0.kind == "weapon.fired"
    }.count
    #expect(
      game.commander.scriptState.pendingEvents.filter { $0.kind == "weapon.fired" }.count
        == firedBefore + 1)
    #expect(
      game.bodies[0].physical?.npc?.legal.value == (source.physical?.npc?.legal.value ?? 0) + 8)
    let committed = game
    let repeatFire = try game.fireMissionNativeLaser(
      bodyID: source.id, weaponID: weapon.id, componentID: nil)
    #expect(
      repeatFire == nil && game.commander == committed.commander && game.bodies == committed.bodies)
    #expect(game.frontShield == committed.frontShield && game.energy == committed.energy)
  }

}
