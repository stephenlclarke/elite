import Foundation
import Testing

@testable import EliteCore

enum CrimboFixture {
  static let system = NativeCrimboRegistry.system
  static func station(owner: UUID, system: SystemIdentity) -> NativeMainStationIdentity {
    .init(
      world: owner, system: system,
      resource: Game.worldResourceIdentity(
        "main-station-v1:main-orbital:\(system.galaxy):\(system.system)"))
  }

  static func registry(owner: UUID = UUID(), sequence: UInt64 = 1) throws -> NativeCrimboRegistry {
    var flight = FlightSimulationState()
    flight.enter(system, arriving: false)
    let planet = try #require(flight.anchors?.planet)
    let orbit = try OrbitFormationState(
      incarnation: UUID(),
      anchor: .init(
        identity: UUID(), center: planet.position, basis: Basis3(), planetRadius: planet.radius,
        orbitRadius: 3000, surfaceClearance: 100),
      configuration: .init(
        direction: .positive, angularSpeed: 0.01, slotSpacing: 0.08,
        captureDistance: 1000, captureTimeout: 120), phase: 0, angularSpeed: 0.01)
    return try .init(
      world: owner, spawnSequence: sequence, origin: station(owner: owner, system: system),
      orbit: orbit, santaLoadout: .init(missiles: 0, ecmEnabled: false),
      rudolfLoadout: .init(missiles: 2, ecmEnabled: true))
  }

  static func snapshot(entity: UInt64, slot: Int, visit: UInt64 = 1, time: Double = 1)
    throws -> NPCPersistenceSnapshot
  {
    let member = NativeCrimboMember(identity: UUID(), slot: slot, ownership: .pending)
    var npc = NPCState(role: member.role, origin: system, destination: system)
    npc.resources = NPCResources.stock(
      try #require(ShipCatalogue.ship(member.catalogueShipID)?.game))
    npc.resources?.frontShield = 13
    npc.resources?.rearShield = 17
    npc.resources?.laserHeat = 47
    npc.resources?.fuel = 19
    npc.ordinaryCargo = [.init(commodity: .gold, quantity: 3)]
    var body = SpaceBody(id: Int(entity), hull: member.hull, position: .init(0, 0, 4000))
    body.energy = 31
    body.missiles = 1
    body.ecmEnabled = true
    body.physical = .init(
      identity: .init(system: system, visit: visit, entity: entity), population: .civilian,
      npc: npc, velocity: .init(2, 3, 4), laserCooldown: 0.7,
      spawnIdentity: .init(
        system: system, visit: visit, sequence: 1, member: UInt16(slot), producer: .provider),
      catalogueShipID: member.catalogueShipID)
    return try #require(
      NPCPersistenceSnapshot.capture(
        body: body, pose: ShipPose(), physicalTime: time, protection: .init()))
  }

  static func convoyBodies(_ game: Game) -> [SpaceBody] {
    game.bodies.filter { body in
      body.physical.map { game.isNativeCrimboMember($0.identity) } ?? false
    }
  }

  static func game() throws -> Game {
    var game = Game(executive: false)
    // Explicit adapter fixture injection; production readiness is exclusively G1-owned.
    game.nativeCrimboLifecycleAvailable = true
    game.commander.galaxy = system.galaxy
    game.commander.system = system.system
    game.systems = Universe.systemsIncludingPlugh(number: system.galaxy)
    try game.commander.prepareEquipment()
    game.commander.flightSimulation.enter(system, arriving: false)
    game.screen = .front
    game.docked = false
    game.bodies = []
    game.ensurePhysicalActors()
    let sequence = try #require(game.commander.flightSimulation.allocateSpawn())
    let owner = try #require(game.commander.equipmentOwnerID)
    game.commander.savedCrimboState = try registry(owner: owner, sequence: sequence)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    return game
  }
}

struct NativeCrimboRegistryTests {
  @Test func originalsAndManifestSurviveRoundTripWithoutMissionState() throws {
    let registry = try CrimboFixture.registry()
    let restored = try JSONDecoder().decode(
      NativeCrimboRegistry.self, from: JSONEncoder().encode(registry))
    #expect(restored == registry)
    #expect(
      restored.members.map(\.catalogueShipID) == Array(repeating: "SH151", count: 6) + ["SH150"])
    #expect(restored.members.map(\.role) == Array(repeating: NPCRole.escort, count: 6) + [.trader])
    #expect(restored.manifest.subject == restored.members[6].identity)
    #expect(restored.members.allSatisfy { $0.ownership == .pending })
  }

  @Test func boundedDecodeRejectsExtraMembersBeforeDecodingTheirPayload() throws {
    let registry = try CrimboFixture.registry()
    let bytes = try JSONEncoder().encode(registry)
    var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    object["members"] = Array(repeating: ["untrusted": "not a member"], count: 8)
    let hostile = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeCrimboError.invalidRegistry) {
      try JSONDecoder().decode(NativeCrimboRegistry.self, from: hostile)
    }
  }

  @Test func duplicateSlotsForeignOriginalAndInvalidLoadoutAreRejected() throws {
    var registry = try CrimboFixture.registry()
    registry.members[1] = registry.members[0]
    #expect(throws: NativeCrimboError.invalidRegistry) { try registry.validate() }
    registry = try CrimboFixture.registry()
    registry.members[0].ownership = .live(
      .init(
        firstActor: .init(
          system: .init(galaxy: 0, system: 8), visit: 1, entity: 2)))
    #expect(throws: NativeCrimboError.invalidRegistry) { try registry.validate() }
    #expect(!NativeCrimboLoadout(missiles: 999, ecmEnabled: true).valid(catalogue: "SH151"))
  }

  @Test func checkedTransferPreservesSpentResourcesAndRejectsEveryReplay() throws {
    var ledger = NPCPersistenceLedger()
    let original = try CrimboFixture.snapshot(entity: 2, slot: 6)
    let logical = NPCLogicalIdentity(firstActor: original.actor)
    #expect(ledger.capture(original, protection: .init()) == .registered(original.actor))
    let expected = [logical: original]
    let parked = try ledger.takeProviderOriginals(expected: expected, protection: .init())
    #expect(parked == expected && ledger.count == 0 && ledger.valid)
    #expect(ledger.capture(original, protection: .init()) == .refused(.staleActor))
    #expect(throws: NativeCrimboError.invalidTransfer) {
      try ledger.takeProviderOriginals(expected: expected, protection: .init())
    }
    ledger.depart(system: CrimboFixture.system)
    var restored = original
    restored.actor = .init(system: CrimboFixture.system, visit: 2, entity: 3)
    restored.physicalTime = 20
    #expect(ledger.capture(restored, protection: .init()) == .registered(restored.actor))
    try ledger.importProviderOriginals(
      parked: parked, admitted: [logical: restored], protection: .init())
    #expect(ledger.binding(for: logical) == restored.actor)
    #expect(ledger.snapshot(for: logical.firstActor) == restored)
    #expect(ledger.count == 1 && ledger.valid)
    #expect(throws: NativeCrimboError.invalidTransfer) {
      try ledger.importProviderOriginals(
        parked: parked, admitted: [logical: restored], protection: .init())
    }
  }

  @Test func failedBulkTransferIsAtomicAndHealedImportIsRefused() throws {
    var ledger = NPCPersistenceLedger()
    let first = try CrimboFixture.snapshot(entity: 2, slot: 0)
    let second = try CrimboFixture.snapshot(entity: 3, slot: 6)
    _ = ledger.capture(first, protection: .init())
    _ = ledger.capture(second, protection: .init())
    let l1 = NPCLogicalIdentity(firstActor: first.actor)
    let l2 = NPCLogicalIdentity(firstActor: second.actor)
    let before = ledger
    var changed = second
    changed.energy += 1
    #expect(throws: NativeCrimboError.invalidTransfer) {
      try ledger.takeProviderOriginals(expected: [l1: first, l2: changed], protection: .init())
    }
    #expect(ledger == before)
    let parked = try ledger.takeProviderOriginals(
      expected: [l1: first, l2: second], protection: .init())
    var a = first
    a.actor = .init(system: CrimboFixture.system, visit: 2, entity: 4)
    var b = second
    b.actor = .init(system: CrimboFixture.system, visit: 2, entity: 5)
    b.npc.resources?.frontShield = 255
    _ = ledger.capture(a, protection: .init())
    _ = ledger.capture(b, protection: .init())
    let provisional = ledger
    #expect(throws: NativeCrimboError.invalidTransfer) {
      try ledger.importProviderOriginals(
        parked: parked, admitted: [l1: a, l2: b], protection: .init())
    }
    #expect(ledger == provisional)
  }

  @Test func terminalMemberCannotReturnAsPendingOnRoundTrip() throws {
    var registry = try CrimboFixture.registry()
    for index in registry.members.indices {
      registry.members[index].ownership = .terminal(
        .init(
          firstActor: .init(
            system: CrimboFixture.system, visit: 1, entity: UInt64(index + 2))), .destroyed)
    }
    let originalSanta = registry.members[6].ownership
    let restored = try JSONDecoder().decode(
      NativeCrimboRegistry.self, from: JSONEncoder().encode(registry))
    #expect(restored.members[6].ownership == originalSanta)
    #expect(restored.members[6].ownership != .pending)
  }
  @Test func parkingConsumesOutstandingOfferAndRejectsLateReceipt() throws {
    var ledger = NPCPersistenceLedger()
    let snapshot = try CrimboFixture.snapshot(entity: 2, slot: 6)
    let logical = NPCLogicalIdentity(firstActor: snapshot.actor)
    _ = ledger.capture(snapshot, protection: .init())
    ledger.cull(actor: snapshot.actor)
    var game = try CrimboFixture.game()
    game.commander.flightSimulation.advancePhysicalTime(1)
    let context = try #require(game.gameplayContext())
    let request = try #require(ledger.pendingSpawnRequests(context: context).first)
    let expected = try #require(ledger.snapshot(for: logical.firstActor))
    _ = try ledger.takeProviderOriginals(expected: [logical: expected], protection: .init())
    let late = SpawnReceipt(
      request: request.identity,
      actor: .init(system: CrimboFixture.system, visit: context.visit, entity: 3), refusal: nil)
    #expect(ledger.acknowledge(receipts: [late]).isEmpty)
    #expect(ledger.count == 0 && ledger.valid)
  }

  @Test func restoredProviderAddressMustMatchOriginalCatalogueAndSlot() throws {
    var ledger = NPCPersistenceLedger()
    let original = try CrimboFixture.snapshot(entity: 2, slot: 6)
    _ = ledger.capture(original, protection: .init())
    ledger.resetPhysicalBindings(system: CrimboFixture.system)
    let before = ledger
    let wrong = SpawnIdentity(
      system: CrimboFixture.system, visit: 1, sequence: 1, member: 0, producer: .provider)
    #expect(throws: NPCSceneRestorationError.invalidRecord) {
      try ledger.restoreSceneBindings(
        [original], sceneActors: [original.actor], spawnIdentities: [original.actor: wrong],
        system: CrimboFixture.system, visit: 1, physicalTime: original.physicalTime,
        nextActor: 3, protection: .init())
    }
    #expect(ledger == before)
    let correct = SpawnIdentity(
      system: CrimboFixture.system, visit: 1, sequence: 1, member: 6, producer: .provider)
    try ledger.restoreSceneBindings(
      [original], sceneActors: [original.actor], spawnIdentities: [original.actor: correct],
      system: CrimboFixture.system, visit: 1, physicalTime: original.physicalTime,
      nextActor: 3, protection: .init())
    #expect(ledger.binding(for: original.actor) == original.actor)
    #expect(ledger.snapshot(for: original.actor) == original)
  }

  @Test func derivedWholeCircleClearsActualSpheresAndWeakestCatalogueLimits() throws {
    let registry = try CrimboFixture.registry()
    let santa = try #require(ShipCatalogue.ship("SH150"))
    let rudolf = try #require(ShipCatalogue.ship("SH151"))
    let radii = try (0..<7).map { slot in
      try #require((slot == 6 ? santa : rudolf).design.rawMesh.vertices.map(\.length).max())
    }
    let limits = try (0..<7).map { slot -> OrbitFormationLimits in
      let p = try #require((slot == 6 ? santa : rudolf).game)
      return .init(
        speed: p.speed * 18, acceleration: p.acceleration * 18, turnRate: min(p.pitch, p.yaw))
    }
    let center = registry.orbit.anchor.center
    let sun = SphereAnchor(position: center + .init(0, 0, 12000), radius: 1100)
    let obstacle = SphereAnchor(position: center + .init(1700, 0, 0), radius: 600)
    let environment = NativeCrimboOrbitEnvironment(
      planet: .init(position: center, radius: registry.orbit.anchor.planetRadius), sun: sun,
      playerPosition: center + .init(0, 6000, 0), reference: Basis3(),
      hullRadii: radii, limits: limits, obstacles: [obstacle])
    let orbit = try NativeCrimboOrbitPolicy.derive(
      environment: environment, incarnation: UUID(), anchorIdentity: UUID())
    #expect(
      NativeCrimboOrbitPolicy.circleDistance(
        obstacle, center: center, basis: orbit.anchor.basis, radius: orbit.anchor.orbitRadius)
        > obstacle.radius + (radii.max() ?? 0))
    #expect(
      orbit.configuration.angularSpeed * orbit.anchor.orbitRadius <= 0.75
        * (limits.map(\.speed).min() ?? 0))
    #expect(
      pow(orbit.configuration.angularSpeed, 2) * orbit.anchor.orbitRadius <= 0.5
        * (limits.map(\.acceleration).min() ?? 0))
    #expect(orbit.configuration.angularSpeed <= 0.75 * (limits.map(\.turnRate).min() ?? 0))
    #expect(7 * orbit.configuration.slotSpacing < 2 * .pi)
    #expect(orbit.anchor.center == environment.planet.position)
    #expect(orbit.configuration.captureTimeout == 2 * .pi / orbit.configuration.angularSpeed)
  }

  @Test func geometryDerivationRejectsMissingOriginalHullAndUnresolvedSphere() throws {
    let planet = SphereAnchor(position: .init(0, 0, 0), radius: 1500)
    let invalid = NativeCrimboOrbitEnvironment(
      planet: planet, sun: planet, playerPosition: .init(0, 0, 10000), reference: Basis3(),
      hullRadii: Array(repeating: 20, count: 6),
      limits: Array(repeating: .init(speed: 100, acceleration: 10, turnRate: 1), count: 7),
      obstacles: [])
    #expect(throws: NativeCrimboError.invalidMotion) {
      try NativeCrimboOrbitPolicy.derive(
        environment: invalid, incarnation: UUID(), anchorIdentity: UUID())
    }
  }

  @Test func absentOrdinaryClockRebasePreservesEverySpentResource() throws {
    var snapshot = try CrimboFixture.snapshot(entity: 2, slot: 6)
    let capacity = try #require(snapshot.npc.resources?.energyCapacity)
    let recharge = try #require(snapshot.npc.resources?.electricalRecharge)
    var reserve = try #require(ElectricalReserve(capacity: capacity, recharge: recharge, at: 0))
    #expect(reserve.drain(50, at: 0))
    snapshot.npc.resources?.electrical = reserve
    let frozen = try Game.freezeNativeCrimboSnapshot(snapshot, at: 1000)
    #expect(frozen.energy == snapshot.energy && frozen.missiles == snapshot.missiles)
    #expect(frozen.position == snapshot.position && frozen.velocity == snapshot.velocity)
    #expect(
      frozen.laserCooldown == snapshot.laserCooldown
        && frozen.npc.ordinaryCargo == snapshot.npc.ordinaryCargo)
    #expect(frozen.npc.resources?.frontShield == snapshot.npc.resources?.frontShield)
    #expect(frozen.npc.resources?.rearShield == snapshot.npc.resources?.rearShield)
    #expect(frozen.npc.resources?.laserHeat == snapshot.npc.resources?.laserHeat)
    #expect(frozen.npc.resources?.fuel == snapshot.npc.resources?.fuel)
    #expect(frozen.npc.resources?.electrical?.remaining == reserve.remaining)
    #expect(frozen.npc.resources?.electrical?.recharge == recharge)
    #expect(frozen.npc.resources?.electrical?.physicalTime == 1000)
  }

  @Test func electricalDisableDeadlineRemainsExclusiveToActualEMPOwner() throws {
    var snapshot = try CrimboFixture.snapshot(entity: 2, slot: 6)
    let capacity = try #require(snapshot.npc.resources?.energyCapacity)
    let recharge = try #require(snapshot.npc.resources?.electricalRecharge)
    var reserve = try #require(ElectricalReserve(capacity: capacity, recharge: recharge, at: 0))
    #expect(reserve.drain(capacity, at: 0))
    snapshot.npc.resources?.electrical = reserve
    #expect(throws: NativeCrimboError.invalidTransfer) {
      try Game.freezeNativeCrimboSnapshot(snapshot, at: 1000)
    }
    #expect(snapshot.npc.resources?.electrical?.disabledAt == 0)
    #expect(snapshot.npc.resources?.electrical?.remaining == 0)
  }

  @Test func parkedImportAcceptsOnlyActualRotatedCameraRoundoff() throws {
    var ledger = NPCPersistenceLedger()
    let original = try CrimboFixture.snapshot(entity: 2, slot: 6)
    let logical = NPCLogicalIdentity(firstActor: original.actor)
    _ = ledger.capture(original, protection: .init())
    let parked = try ledger.takeProviderOriginals(
      expected: [logical: original], protection: .init())
    ledger.depart(system: CrimboFixture.system)
    let actor = ActorIdentity(system: CrimboFixture.system, visit: 2, entity: 3)
    var rebound = original
    rebound.actor = actor
    rebound.physicalTime = 20
    var body = SpaceBody(id: 3, hull: original.hull, position: .init(0, 0, 0))
    body.physical = .init(identity: actor, population: .civilian, npc: original.npc)
    var pose = ShipPose()
    pose.position = .init(12000, 500, -16000)
    pose.orientation.rotate(pitch: 0.3, roll: 0.2, yaw: -0.4)
    #expect(
      NPCRebind(logicalIdentity: original.actor, actor: actor, snapshot: rebound)
        .restore(body: &body, pose: pose))
    let captured = try #require(
      NPCPersistenceSnapshot.capture(
        body: body, pose: pose, physicalTime: 20, protection: .init()))
    #expect(captured.position != original.position || captured.orientation != original.orientation)
    _ = ledger.capture(captured, protection: .init())
    try ledger.importProviderOriginals(
      parked: parked, admitted: [logical: captured], protection: .init())
    #expect(ledger.binding(for: logical) == actor)
    #expect(ledger.snapshot(for: logical.firstActor)?.energy == original.energy)
    #expect(ledger.snapshot(for: logical.firstActor)?.npc.resources == original.npc.resources)
  }

  @Test func importNeverForgivesDifferentElectricalResourceClock() throws {
    var ledger = NPCPersistenceLedger()
    var original = try CrimboFixture.snapshot(entity: 2, slot: 6)
    let capacity = try #require(original.npc.resources?.energyCapacity)
    let recharge = try #require(original.npc.resources?.electricalRecharge)
    original.npc.resources?.electrical = ElectricalReserve(
      capacity: capacity, recharge: recharge, at: 1)
    let logical = NPCLogicalIdentity(firstActor: original.actor)
    _ = ledger.capture(original, protection: .init())
    _ = try ledger.takeProviderOriginals(expected: [logical: original], protection: .init())
    ledger.depart(system: CrimboFixture.system)
    let parked = try Game.freezeNativeCrimboSnapshot(original, at: 20)
    var current = try Game.freezeNativeCrimboSnapshot(parked, at: 21)
    current.actor = .init(system: CrimboFixture.system, visit: 2, entity: 3)
    _ = ledger.capture(current, protection: .init())
    let before = ledger
    #expect(throws: NativeCrimboError.invalidTransfer) {
      try ledger.importProviderOriginals(
        parked: [logical: parked], admitted: [logical: current], protection: .init())
    }
    #expect(ledger == before)
  }

}
