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
}
