import Foundation
import Testing

@testable import L337Core

private func persistenceExpect(_ condition: Bool, sourceLocation: SourceLocation = #_sourceLocation)
{
  #expect(condition, sourceLocation: sourceLocation)
}

private func persistenceRequire<T>(_ value: T?) throws -> T { try #require(value) }

private func persistenceBody(_ entity: UInt64 = 2, visit: UInt64 = 1) -> SpaceBody {
  var body = SpaceBody(id: Int(entity), hull: .cobra, position: .init(10, 20, 30), hostile: true)
  body.orientation.rotate(pitch: 0.1, roll: 0.2, yaw: 0.3)
  body.rotation = 0.7
  body.rotationRate = 0.2
  body.energy = 34
  body.missiles = 1
  body.ecmEnabled = true
  var npc = NPCState(
    role: .pirate, legal: .init(value: 20, bountyTenths: 130),
    firstAggressor: crimeTestID(50), intention: .engage(crimeTestID(60)),
    origin: crimeTestSystem, destination: .init(galaxy: 0, system: 9),
    ordinaryCargo: [
      .init(commodity: .gold, quantity: 17), .init(commodity: .narcotics, quantity: 2),
    ],
    legalProvenance: .recorded, cargoProvenance: .generated, routeProvenance: .inferredLocal)
  npc.resources = .init(
    profile: .nativeHull, energyCapacity: 100, energyRecharge: 2,
    frontCapacity: 80, rearCapacity: 80, shieldRecharge: 1,
    frontShield: 17, rearShield: 23, laserHeat: 51, heatCapacity: 240, heatCooling: 12,
    fuel: 13, fuelCapacity: 70, scoopRemainder: 0.3)
  npc.hasFuelScoops = true
  body.physical = .init(
    identity: crimeTestID(entity, visit: visit), population: .pirate, npc: npc,
    velocity: .init(4, 5, 6), laserCooldown: 0.45,
    catalogueShipID: "SH001", angularVelocity: .init(0.01, 0.02, 0.03))
  return body
}

private func persistenceSnapshot(_ entity: UInt64 = 2, time: Double = 10) throws
  -> NPCPersistenceSnapshot
{
  try persistenceRequire(
    NPCPersistenceSnapshot.capture(
      body: persistenceBody(entity), pose: ShipPose(), physicalTime: time, protection: .init()))
}

private func persistenceRoundtrip(_ ledger: NPCPersistenceLedger) throws -> NPCPersistenceLedger {
  try JSONDecoder().decode(NPCPersistenceLedger.self, from: JSONEncoder().encode(ledger))
}

private func persistenceContext(_ time: Double, radius: Double) -> EncounterContext {
  let context = crimeTestContext(time)
  return .init(
    system: context.system, seed: context.seed, government: context.government,
    visit: context.visit, revision: context.revision, physicalTime: time,
    anchors: context.anchors, player: context.player, actors: context.actors,
    protection: context.protection, budget: context.budget, perceptionRadius: radius)
}

struct NPCPersistenceLedgerTests {
  @Test func outOfRangeRetentionAndWorldUpdatesReenterWithoutAllocatingRepeatedOffers() throws {
    var ledger = NPCPersistenceLedger()
    var snapshot = try persistenceSnapshot()
    snapshot.position = .init(0, 0, 20000)
    _ = ledger.capture(snapshot, protection: .init())
    ledger.cull(actor: snapshot.actor)
    let far = ledger
    for time in [10.0, 11, 12] {
      persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(time)).isEmpty)
    }
    #expect(ledger == far && ledger.unboundSnapshots == [snapshot.actor: snapshot])
    snapshot.position = .init(0, 0, 10000)
    snapshot.physicalTime = 13
    snapshot.energy = 36
    snapshot.rotation = 0.9
    snapshot.npc.resources?.frontShield = 19
    persistenceExpect(ledger.updateUnbound(logicalIdentity: snapshot.actor, snapshot: snapshot))
    let edge = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(13)).first)
    #expect(edge.position == snapshot.position && edge.energy == 36 && edge.npc == snapshot.npc)
    snapshot.position.z = 10001
    snapshot.physicalTime = 14
    persistenceExpect(ledger.updateUnbound(logicalIdentity: snapshot.actor, snapshot: snapshot))
    persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(14)).isEmpty)
    ledger = try persistenceRoundtrip(ledger)
    snapshot.position = .init(0, 0, 2000)
    snapshot.physicalTime = 15
    persistenceExpect(ledger.updateUnbound(logicalIdentity: snapshot.actor, snapshot: snapshot))
    let near = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(15)).first)
    #expect(near.identity == edge.identity && near.position == snapshot.position)
    #expect(ledger.unboundSnapshots[snapshot.actor]?.rotation == 0.9)
    for radius in [0, -1, Double.nan, .infinity] {
      let before = ledger
      persistenceExpect(
        ledger.pendingSpawnRequests(context: persistenceContext(15, radius: radius)).isEmpty)
      #expect(ledger == before)
    }
  }

  @Test func unboundUpdatesRejectBoundTerminalStaleOrChangedActorWithoutMutation() throws {
    var ledger = NPCPersistenceLedger()
    let original = try persistenceSnapshot()
    _ = ledger.capture(original, protection: .init())
    #expect(ledger.unboundSnapshots.isEmpty)
    let bound = ledger
    persistenceExpect(!ledger.updateUnbound(logicalIdentity: original.actor, snapshot: original))
    #expect(ledger == bound)
    ledger.cull(actor: original.actor)
    let unbound = ledger
    var invalids = [original, original, original, original]
    invalids[0].actor = crimeTestID(99)
    invalids[1].actor = .init(system: .init(galaxy: 0, system: 9), visit: 1, entity: 2)
    invalids[2].physicalTime = 9
    invalids[3].energy = .nan
    for invalid in invalids {
      persistenceExpect(!ledger.updateUnbound(logicalIdentity: original.actor, snapshot: invalid))
      #expect(ledger == unbound)
    }
    persistenceExpect(!ledger.updateUnbound(logicalIdentity: crimeTestID(99), snapshot: original))
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10)).first)
    let rebound = try persistenceRequire(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: crimeTestID(100), refusal: nil)
      ]).first)
    persistenceExpect(ledger.terminal(actor: rebound.actor, reason: .destroyed))
    let terminal = ledger
    #expect(ledger.unboundSnapshots.isEmpty)
    persistenceExpect(
      !ledger.updateUnbound(logicalIdentity: original.actor, snapshot: rebound.snapshot))
    #expect(ledger == terminal && ledger.valid)
  }

  @Test func actualBodyCaptureRetainsWorldPoseResourcesAndCatalogueAcrossCodableRoundtrip() throws {
    let body = persistenceBody()
    var pose = ShipPose(position: .init(1000, 2000, 3000))
    pose.orientation.rotate(pitch: 0.4, roll: -0.3, yaw: 0.6)
    let snapshot = try persistenceRequire(
      NPCPersistenceSnapshot.capture(
        body: body, pose: pose, physicalTime: 12.5, protection: .init()))
    #expect(snapshot.position == pose.systemPoint(body.position))
    #expect(snapshot.orientation == body.orientation.transformed(by: pose.orientation))
    #expect(snapshot.npc == body.physical?.npc && snapshot.energy == 34)
    #expect(snapshot.missiles == 1 && snapshot.ecmEnabled && snapshot.hostile)
    #expect(snapshot.laserCooldown == 0.45 && snapshot.catalogueShipID == "SH001")
    #expect(snapshot.rotation == 0.7 && snapshot.rotationRate == 0.2)
    #expect(
      snapshot.velocity == .init(4, 5, 6) && snapshot.angularVelocity == .init(0.01, 0.02, 0.03))
    var ledger = NPCPersistenceLedger()
    persistenceExpect(ledger.capture(snapshot, protection: .init()) == .registered(snapshot.actor))
    let decoded = try persistenceRoundtrip(ledger)
    #expect(decoded == ledger && decoded.snapshot(for: snapshot.actor) == snapshot && decoded.valid)
  }

  @Test func cullRebindNewActorRestoresExactDamageConsumablesAndRenderedPoseOnce() throws {
    var ledger = NPCPersistenceLedger()
    let original = try persistenceSnapshot()
    _ = ledger.capture(original, protection: .init())
    ledger.cull(actor: original.actor)
    ledger = try persistenceRoundtrip(ledger)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(100)).first)
    #expect(
      request.energy == 34 && request.npc == original.npc && request.position == original.position)
    #expect(
      request.identity.producer == .persistence && request.payload == nil && request.rock == nil)
    let receipt = SpawnReceipt(request: request.identity, actor: crimeTestID(100), refusal: nil)
    let rebind = try persistenceRequire(ledger.acknowledge(receipts: [receipt]).first)
    #expect(rebind.logicalIdentity == original.actor && rebind.actor == crimeTestID(100))
    var pose = ShipPose(position: .init(-900, 300, 400))
    pose.orientation.rotate(pitch: -0.2, roll: 0.5, yaw: 0.8)
    var restored = persistenceBody(100)
    restored.energy = 100
    restored.missiles = 4
    restored.ecmEnabled = false
    persistenceExpect(rebind.restore(body: &restored, pose: pose))
    #expect(restored.energy == 34 && restored.missiles == 1 && restored.ecmEnabled)
    #expect(restored.physical?.npc == original.npc && restored.physical?.laserCooldown == 0.45)
    let actualWorld = pose.orientation.apply(restored.modelVector(.init(0, 0, 1)))
    let originalWorld = persistenceBody().modelVector(.init(0, 0, 1))
    #expect((actualWorld - originalWorld).length < 1e-10)
    #expect((pose.systemPoint(restored.position) - original.position).length < 1e-10)
    persistenceExpect(ledger.acknowledge(receipts: [receipt, receipt]).isEmpty)
    persistenceExpect(ledger.capture(original, protection: .init()) == .refused(.staleActor))
    var updated = rebind.snapshot
    updated.energy = 12
    updated.missiles = 0
    updated.ecmEnabled = false
    updated.npc.resources?.fuel = 2
    updated.physicalTime = 101
    persistenceExpect(ledger.capture(updated, protection: .init()) == .updated(original.actor))
    ledger.cull(actor: rebind.actor)
    let retry = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(102)).first)
    #expect(
      retry.energy == 12 && retry.npc?.resources?.fuel == 2 && retry.identity != request.identity)
    let next = ledger.acknowledge(receipts: [
      .init(request: retry.identity, actor: crimeTestID(101), refusal: nil)
    ])
    #expect(next.first?.snapshot.missiles == 0 && next.first?.snapshot.ecmEnabled == false)
    #expect(ledger.livingCount == 1 && ledger.count == 1 && ledger.valid)
  }

  @Test func admissionRefusalReplayWrongVisitAndOldOfferNeverDuplicateOrRefill() throws {
    var ledger = NPCPersistenceLedger()
    _ = ledger.capture(try persistenceSnapshot(), protection: .init())
    ledger.cull(actor: crimeTestID(2))
    let context = crimeTestContext(10)
    let request = try persistenceRequire(ledger.pendingSpawnRequests(context: context).first)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: nil, refusal: .unsafePosition)
      ]).isEmpty)
    ledger = try persistenceRoundtrip(ledger)
    persistenceExpect(ledger.pendingSpawnRequests(context: context) == [request])
    persistenceExpect(
      ledger.pendingSpawnRequests(
        context: crimeTestContext(10, budget: .init(active: [.pirate: 8], total: 8))
      ).isEmpty)
    persistenceExpect(ledger.pendingSpawnRequests(context: context) == [request])
    for actor in [crimeTestID(100, visit: 2), crimeTestID(2)] {
      persistenceExpect(
        ledger.acknowledge(receipts: [.init(request: request.identity, actor: actor, refusal: nil)])
          .isEmpty)
    }
    ledger.resetPhysicalBindings(system: crimeTestSystem)
    let next = try persistenceRequire(ledger.pendingSpawnRequests(context: context).first)
    #expect(next.identity != request.identity && next.npc == request.npc)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: crimeTestID(100), refusal: nil)
      ]).isEmpty)
    let receipt = SpawnReceipt(request: next.identity, actor: crimeTestID(101), refusal: nil)
    persistenceExpect(ledger.acknowledge(receipts: [receipt, receipt]).count == 1)
    persistenceExpect(ledger.pendingSpawnRequests(context: context).isEmpty && ledger.valid)
  }

  @Test func capacityRefusalIsAtomicAndTerminalEntriesNeverEvictOrReleaseExtraShips() throws {
    var ledger = NPCPersistenceLedger()
    for entity in UInt64(2)...129 {
      persistenceExpect(
        ledger.capture(try persistenceSnapshot(entity), protection: .init())
          == .registered(crimeTestID(entity)))
    }
    let full = ledger
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(130), protection: .init()) == .refused(.capacity))
    #expect(ledger == full && ledger.count == 128)
    persistenceExpect(ledger.terminal(actor: crimeTestID(2), reason: .destroyed))
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(130), protection: .init()) == .refused(.capacity))
    ledger.depart(system: .init(galaxy: 0, system: 88))
    #expect(ledger.count == 128)
    ledger.depart(system: crimeTestSystem)
    #expect(ledger.count == 0 && ledger.system == nil && ledger.valid)
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(2), protection: .init()) == .refused(.staleActor))
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(130), protection: .init())
        == .registered(crimeTestID(130)))
  }

  @Test func outOfOrderReceiptsBindOnceAndRetiredPhysicalActorCannotBecomeAnotherShip() throws {
    var ledger = NPCPersistenceLedger()
    for entity in UInt64(2)...3 {
      _ = ledger.capture(try persistenceSnapshot(entity), protection: .init())
      ledger.cull(actor: crimeTestID(entity))
    }
    let requests = ledger.pendingSpawnRequests(context: crimeTestContext(10))
    let receipts: [SpawnReceipt] = [
      .init(request: requests[1].identity, actor: crimeTestID(101), refusal: nil),
      .init(request: requests[0].identity, actor: crimeTestID(100), refusal: nil),
    ]
    let accepted = ledger.acknowledge(receipts: receipts)
    #expect(accepted.map(\.actor.entity) == [100, 101])
    persistenceExpect(ledger.terminal(actor: crimeTestID(101), reason: .destroyed))
    ledger.cull(actor: crimeTestID(100))
    let next = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(11)).first)
    let before = ledger
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: next.identity, actor: crimeTestID(101), refusal: nil)
      ]).isEmpty)
    #expect(ledger == before && ledger.valid)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: next.identity, actor: crimeTestID(102), refusal: nil)
      ]).count == 1)
    #expect(ledger.logicalIdentity(for: crimeTestID(102)) == crimeTestID(2))
  }

  @Test func allocatorOrderStaleTimeAndWrongSystemUpdatesCannotOverwriteActualState() throws {
    var ledger = NPCPersistenceLedger()
    let first = try persistenceSnapshot(10)
    _ = ledger.capture(first, protection: .init())
    persistenceExpect(
      ledger.capture(try persistenceSnapshot(9), protection: .init()) == .refused(.staleActor))
    _ = ledger.capture(try persistenceSnapshot(11), protection: .init())
    var update = first
    update.energy = 21
    update.physicalTime = 11
    persistenceExpect(ledger.capture(update, protection: .init()) == .updated(first.actor))
    let before = ledger
    persistenceExpect(ledger.capture(first, protection: .init()) == .refused(.staleTime))
    var other = try persistenceSnapshot(12)
    other.actor = .init(system: .init(galaxy: 0, system: 9), visit: 1, entity: 12)
    persistenceExpect(ledger.capture(other, protection: .init()) == .refused(.wrongSystem))
    #expect(ledger == before)
    ledger.cull(actor: crimeTestID(99))
    ledger.resetPhysicalBindings(system: other.actor.system)
    #expect(ledger == before && ledger.logicalIdentity(for: first.actor) == first.actor)
  }

  @Test func missionProtectedAndNonShipBodiesAreExcludedWithoutOrdinaryFallbacks() throws {
    let ordinary = persistenceBody()
    var variants: [SpaceBody] = []
    var body = ordinary
    body.navalTarget = true
    variants.append(body)
    body = ordinary
    body.blackjackIdentity = UUID()
    variants.append(body)
    body = ordinary
    body.physical?.npc?.role = .mission
    variants.append(body)
    body = ordinary
    body.physical?.population = .mission
    variants.append(body)
    body = ordinary
    body.physical?.payload = .wreck(crimeTestID(80), lot: 0)
    variants.append(body)
    body = ordinary
    body.physical = nil
    variants.append(body)
    body = ordinary
    body.hull = .cargo
    variants.append(body)
    body = ordinary
    body.energy = 0
    variants.append(body)
    for variant in variants {
      #expect(
        NPCPersistenceSnapshot.capture(
          body: variant, pose: .init(), physicalTime: 10, protection: .init()) == nil)
    }
    let protection = MissionProtection(protectedActors: [crimeTestID(2)])
    #expect(
      NPCPersistenceSnapshot.capture(
        body: ordinary, pose: .init(), physicalTime: 10, protection: protection) == nil)
    var ledger = NPCPersistenceLedger()
    let snapshot = try persistenceSnapshot()
    persistenceExpect(ledger.capture(snapshot, protection: protection) == .refused(.protectedActor))
    #expect(ledger.count == 0 && ledger.valid)
    _ = ledger.capture(snapshot, protection: .init())
    ledger.cull(actor: snapshot.actor)
    persistenceExpect(
      ledger.pendingSpawnRequests(context: crimeTestContext(10, protection: protection)).isEmpty)
    persistenceExpect(
      ledger.pendingSpawnRequests(
        context: crimeTestContext(10, protection: .init(suppressAmbientShips: true))
      ).isEmpty)
  }

  @Test func allTerminalReasonsSurviveReloadAndStalePhysicalReplaysCannotResurrect() throws {
    for reason in [NPCTerminalReason.destroyed, .docked, .jumped, .expired] {
      var ledger = NPCPersistenceLedger()
      let snapshot = try persistenceSnapshot()
      _ = ledger.capture(snapshot, protection: .init())
      persistenceExpect(ledger.terminal(actor: snapshot.actor, reason: reason))
      persistenceExpect(!ledger.terminal(actor: snapshot.actor, reason: reason))
      ledger = try persistenceRoundtrip(ledger)
      ledger.cull(actor: snapshot.actor)
      ledger.resetPhysicalBindings(system: crimeTestSystem)
      persistenceExpect(
        ledger.pendingSpawnRequests(context: crimeTestContext(20, visit: 2)).isEmpty)
      persistenceExpect(ledger.capture(snapshot, protection: .init()) == .refused(.staleActor))
      #expect(
        ledger.count == 1 && ledger.livingCount == 0 && ledger.binding(for: snapshot.actor) == nil
          && ledger.valid)
    }
  }

  @Test func dockAndNewVisitRetainExactSnapshotWithoutHiddenRechargeOrCoordinateReset() throws {
    var ledger = NPCPersistenceLedger()
    let snapshot = try persistenceSnapshot()
    _ = ledger.capture(snapshot, protection: .init())
    ledger.resetPhysicalBindings(system: crimeTestSystem)
    let old = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10)).first)
    ledger = try persistenceRoundtrip(ledger)
    let next = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10000, visit: 5)).first)
    #expect(next.identity.visit == 5 && next.identity != old.identity)
    #expect(next.position == snapshot.position && next.orientation == snapshot.orientation)
    #expect(next.npc == snapshot.npc && next.energy == snapshot.energy)
    persistenceExpect(
      ledger.acknowledge(receipts: [
        .init(request: old.identity, actor: crimeTestID(50), refusal: nil)
      ]).isEmpty)
    let accepted = ledger.acknowledge(receipts: [
      .init(request: next.identity, actor: crimeTestID(51, visit: 5), refusal: nil)
    ])
    #expect(
      accepted.first?.logicalIdentity == snapshot.actor
        && accepted.first?.snapshot.physicalTime == 10)
    #expect(accepted.first?.snapshot.laserCooldown == 0.45 && ledger.valid)
  }

  @Test func policeReservePopulationCapsAndSuppressionUseCurrentAdmissionBudget() throws {
    var ledger = NPCPersistenceLedger()
    for entity in UInt64(2)...12 {
      var snapshot = try persistenceSnapshot(entity)
      if entity == 12 {
        snapshot.population = .police
        snapshot.npc.role = .police
      }
      _ = ledger.capture(snapshot, protection: .init())
      ledger.cull(actor: snapshot.actor)
    }
    let limited = crimeTestContext(10, budget: .init(active: [.pirate: 7], total: 7))
    let requests = ledger.pendingSpawnRequests(context: limited)
    #expect(requests.count == 2 && requests.map(\.population) == [.pirate, .police])
    let suppressed = crimeTestContext(10, protection: .init(suppressAmbientShips: true))
    persistenceExpect(
      ledger.pendingSpawnRequests(context: suppressed).map(\.population) == [.police])
    let full = crimeTestContext(10, budget: .init(total: 128))
    persistenceExpect(ledger.pendingSpawnRequests(context: full).isEmpty)
    let reserved = crimeTestContext(10, budget: .init(total: 116))
    persistenceExpect(ledger.pendingSpawnRequests(context: reserved).map(\.population) == [.police])
    #expect(ledger.livingCount == 11 && ledger.valid)
  }

  @Test func invalidSnapshotAndMismatchedRestoreRefuseWithoutMutation() throws {
    let original = try persistenceSnapshot()
    var ledger = NPCPersistenceLedger()
    for invalidEnergy in [Double.nan, -1, 0, 101] {
      var invalid = original
      invalid.energy = invalidEnergy
      persistenceExpect(ledger.capture(invalid, protection: .init()) == .refused(.invalidSnapshot))
    }
    #expect(ledger.count == 0 && ledger.system == nil)
    _ = ledger.capture(original, protection: .init())
    ledger.cull(actor: original.actor)
    persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(9)).isEmpty)
    persistenceExpect(ledger.pendingSpawnRequests(context: crimeTestContext(.nan)).isEmpty)
    let request = try persistenceRequire(
      ledger.pendingSpawnRequests(context: crimeTestContext(10)).first)
    let rebind = try persistenceRequire(
      ledger.acknowledge(receipts: [
        .init(request: request.identity, actor: crimeTestID(30), refusal: nil)
      ]).first)
    var mismatch = persistenceBody(31)
    let before = mismatch
    persistenceExpect(!rebind.restore(body: &mismatch, pose: .init()))
    #expect(mismatch == before)
    var invalidPose = ShipPose()
    invalidPose.orientation.x = .init(0, 0, 0)
    #expect(
      NPCPersistenceSnapshot.capture(
        body: persistenceBody(), pose: invalidPose, physicalTime: 10, protection: .init()) == nil)
  }
}
