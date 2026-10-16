import Foundation
import Testing

@testable import EliteCore

private let bridgeInstance = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let bridgeActor = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

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

  @Test func actorTargetArchivePinsActualSecondProtectedBindingAndRejectsWrongNativeVictimOrSource()
    throws
  {
    var game = Game(executive: false)
    game.launch()
    let targetID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    let targetInstance = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    var sourceBody = SpaceBody(id: 42, hull: .constrictor, position: .init(0, 0, 2000))
    sourceBody.missionActorID = bridgeActor
    sourceBody.missionInstanceID = bridgeInstance
    var targetBody = SpaceBody(id: 77, hull: .thargoid, position: .init(100, 0, 2500))
    targetBody.missionActorID = targetID
    targetBody.missionInstanceID = targetInstance
    game.bodies = [sourceBody, targetBody]
    game.ensurePhysicalActors()
    let context = try #require(game.gameplayContext())
    let source = try #require(game.bodies.first { $0.id == 42 })
    let target = try #require(game.bodies.first { $0.id == 77 })
    let sourceBinding = try MissionNativeBridge.bindActor(
      descriptor: bridgeDescriptor(source, context), body: source, context: context)
    let digest = String(repeating: "b", count: 64)
    let targetDescriptor = MissionActorDescriptor(
      instanceID: targetInstance, instanceRevision: 3,
      packDigest: digest, encounterID: "second-encounter", encounterAdmitted: true,
      system: context.system, alias: "target", actorID: targetID, presence: "present",
      missionActorID: targetID, missionInstanceID: targetInstance, body: target)
    let targetBinding = try MissionNativeBridge.bindActor(
      descriptor: targetDescriptor, body: target, context: context)
    let sourceSnapshot = try #require(
      context.actors.first { $0.identity == sourceBinding.nativeActor })
    let targetSnapshot = try #require(
      context.actors.first { $0.identity == targetBinding.nativeActor })
    let origin = AttackOrigin(
      emissionID: 1, owner: sourceBinding.nativeActor, ordnance: nil,
      emittedAt: context.physicalTime, ownerLegalAtEmission: sourceSnapshot.legal)
    let ledger = CrimeLedger()
    let judgement = try ledger.freezeMissionLaunchJudgement(
      origin: origin,
      intendedVictim: targetSnapshot, emissionPosition: sourceSnapshot.position, context: context)
    let shot = MissionShotDescriptor(
      identity: targetInstance, owner: bridgeActor,
      instance: bridgeInstance, weapon: "cannon", component: nil, velocity: .init(0, 0, 777),
      age: 0, lifetime: 4, damage: 23, radius: 2, collisionDelay: 0.2)
    let archive = try MissionNativeBridge.makeLaunchArchive(
      shot: shot, source: sourceBinding,
      intendedTarget: targetBinding, judgement: judgement)
    #expect(
      archive.intendedTarget
        == .actor(instance: targetInstance, actor: targetID, packDigest: digest))
    #expect(
      archive.judgement.victim == targetSnapshot.identity && archive.sourceActorID == bridgeActor)
    let wrongVictim = try ledger.freezeMissionLaunchJudgement(
      origin: origin,
      intendedVictim: context.player, emissionPosition: sourceSnapshot.position, context: context)
    #expect(throws: MissionNativeBridgeError.invalidArchive) {
      try MissionNativeBridge.makeLaunchArchive(
        shot: shot, source: sourceBinding,
        intendedTarget: targetBinding, judgement: wrongVictim)
    }
    let otherOrigin = AttackOrigin(
      emissionID: 2, owner: targetBinding.nativeActor, ordnance: nil,
      emittedAt: context.physicalTime, ownerLegalAtEmission: targetSnapshot.legal)
    let wrongSource = try ledger.freezeMissionLaunchJudgement(
      origin: otherOrigin,
      intendedVictim: context.player, emissionPosition: targetSnapshot.position, context: context)
    #expect(throws: MissionNativeBridgeError.invalidArchive) {
      try MissionNativeBridge.makeLaunchArchive(
        shot: shot, source: sourceBinding,
        intendedTarget: nil, judgement: wrongSource)
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
    let contact = try #require(
      game.nearestMissionCollision(
        from: point - direction * 50,
        direction: direction, range: 100, radius: 0.1, includePlayer: false))
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
    let original = game
    #expect(throws: (any Error).self) {
      try game.makeMissionNativeLaserProof(
        sourceBodyID: source.id, weapon: weapon,
        component: nil, muzzle: muzzle, direction: .init(0, 0, 0))
    }
    #expect(game.commander == original.commander && game.bodies == original.bodies)
    var invalid = game
    invalid.celestials = [.init(kind: .planet, position: .init(0, 0, 200), radius: -1)]
    let invalidBefore = invalid
    #expect(throws: MissionNativeBridgeError.invalidGeometry) {
      try invalid.makeMissionNativeLaserProof(
        sourceBodyID: source.id, weapon: weapon,
        component: nil, muzzle: muzzle, direction: .init(0, 1, 0))
    }
    #expect(invalid.commander == invalidBefore.commander && invalid.bodies == invalidBefore.bodies)
    let emission = game.commander.flightSimulation.nextEmission
    let proof = try game.makeMissionNativeLaserProof(
      sourceBodyID: source.id, weapon: weapon,
      component: nil, muzzle: muzzle, direction: .init(0, 1, 0))
    #expect(proof.kind == .laser && proof.damage == weapon.damage && proof.contact == nil)
    #expect(proof.sourceActorID == source.missionActorID && proof.origin.emissionID == emission)
    #expect(game.commander.flightSimulation.nextEmission == emission + 1)
    #expect(game.bodies == original.bodies)
    #expect(game.commander.scriptState == original.commander.scriptState)
  }

}
