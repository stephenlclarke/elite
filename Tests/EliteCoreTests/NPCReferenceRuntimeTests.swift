import Foundation
import Testing

@testable import EliteCore

private func referenceGame(flee: Bool = true, protectedB: Bool = false) throws -> (
  Game, ActorIdentity, ActorIdentity
) {
  var game = Game(executive: false)
  try NativeSaveTestFixture.prepareCurrentPolicy(&game)
  game.docked = false
  game.screen = .front
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = []
  game.celestials = []
  let allocatedA = game.commander.flightSimulation.allocateActor()
  let a = try #require(allocatedA)
  let allocatedB = game.commander.flightSimulation.allocateActor()
  let b = try #require(allocatedB)
  for (index, actor) in [a, b].enumerated() {
    var npc = NPCState(
      role: .trader, origin: game.systemIdentity,
      destination: .init(galaxy: 1, system: index))
    npc.resources = NPCResources.stock(game.commander.performance)
    npc.resources?.fuel = 23 + index
    npc.resources?.frontShield = 12 + Double(index)
    npc.resources?.rearShield = 15 + Double(index)
    npc.resources?.laserHeat = 37 + Double(index)
    npc.ordinaryCargo = [.init(commodity: .gold, quantity: 4 + index)]
    npc.cargoProvenance = .recorded
    npc.routeProvenance = .generated
    if index == 0 {
      npc.firstAggressor = b
      npc.intention = flee ? .flee(b) : .engage(b)
    }
    var body = SpaceBody(
      id: 40 + index, hull: .cobra,
      position: .init(0, 0, 2000 + 500 * Double(index)))
    body.energy = 73 - Double(index) * 25
    body.missiles = 1 + index
    body.ecmEnabled = true
    body.navalTarget = index == 1 && protectedB
    let allocatedSpawn = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSpawn)
    body.physical = .init(
      identity: actor, population: .civilian, npc: npc,
      laserCooldown: 0.19,
      spawnIdentity: .init(
        system: game.systemIdentity,
        visit: game.commander.flightSimulation.visit, sequence: sequence, member: 0))
    game.bodies.append(body)
    game.nextBodyID = max(game.nextBodyID, body.id + 1)
  }
  #expect(game.persistNPCStates().isEmpty)
  return (game, a, b)
}

private func referenceMovePlayer(_ game: inout Game, near world: Vector3) {
  let previous = game.commander.flightSimulation.pose
  var next = previous
  next.position = world - Vector3(0, 0, 2000)
  for index in game.bodies.indices {
    game.bodies[index].position = next.shipPoint(previous.systemPoint(game.bodies[index].position))
  }
  game.commander.flightSimulation.pose = next
}

private func referenceCullBoth(_ game: inout Game, a: ActorIdentity, b: ActorIdentity) throws {
  let ai = try #require(game.bodies.firstIndex { $0.physical?.identity == a })
  game.bodies[ai].position.x = 45000
  game.tick(delta: 0.001)
  #expect(game.commander.npcPersistence.binding(for: a) == nil)
  let bi = try #require(game.bodies.firstIndex { $0.physical?.identity == b })
  game.bodies[bi].position.z = 45000
  game.tick(delta: 0.001)
  #expect(game.commander.npcPersistence.binding(for: b) == nil)
}

@discardableResult private func referenceBringIn(_ game: inout Game, logical: ActorIdentity) throws
  -> ActorIdentity
{
  let saved = try #require(game.commander.npcPersistence.snapshot(for: logical))
  referenceMovePlayer(&game, near: saved.position)
  game.admitPersistentNPCs()
  return try #require(game.commander.npcPersistence.binding(for: logical))
}

private func referenceExpectA(
  _ game: Game, a: ActorIdentity, target: ActorIdentity, flee: Bool,
  saved: NPCPersistenceSnapshot
) throws {
  let current = try #require(game.commander.npcPersistence.binding(for: a))
  let body = try #require(game.bodies.first { $0.physical?.identity == current })
  #expect(body.physical?.npc?.firstAggressor == target)
  #expect(body.physical?.npc?.intention == (flee ? .flee(target) : .engage(target)))
  #expect(body.physical?.npc?.resources == saved.npc.resources)
  #expect(body.energy == saved.energy && body.missiles == saved.missiles)
  #expect(body.physical?.npc?.ordinaryCargo == saved.npc.ordinaryCargo)
  #expect(body.physical?.npc?.destination == saved.npc.destination)
}

struct NPCReferenceRuntimeTests {
  @Test(arguments: [false, true])
  func asymmetricRepeatedReEntryUsesCurrentTargetWithoutRefilling(flee: Bool) throws {
    let (initial, a, b) = try referenceGame(flee: flee)
    var game = initial
    try referenceCullBoth(&game, a: a, b: b)
    let savedA = try #require(game.commander.npcPersistence.snapshot(for: a))
    let b1 = try referenceBringIn(&game, logical: b)
    #expect(b1 != b && game.commander.npcPersistence.binding(for: a) == nil)
    let a1 = try referenceBringIn(&game, logical: a)
    try referenceExpectA(game, a: a, target: b1, flee: flee, saved: savedA)
    // B is now outside the camera bubble. The real tick culls it before A departs again.
    game.tick(delta: 0.001)
    #expect(game.commander.npcPersistence.binding(for: b) == nil)
    let ai = try #require(game.bodies.firstIndex { $0.physical?.identity == a1 })
    game.bodies[ai].position.x = 45000
    game.tick(delta: 0.001)
    let savedAgain = try #require(game.commander.npcPersistence.snapshot(for: a))
    let b2 = try referenceBringIn(&game, logical: b)
    #expect(b2 != b1)
    try referenceBringIn(&game, logical: a)
    try referenceExpectA(game, a: a, target: b2, flee: flee, saved: savedAgain)
  }

  @Test(arguments: [false, true])
  func realSaveLoadKeepsReferenceToAnEarlierBatchAndPreservesSourceData(
    targetReturnsBeforeSave: Bool
  ) async throws {
    let (initial, a, b) = try referenceGame()
    var game = initial
    try referenceCullBoth(&game, a: a, b: b)
    let oldVisit = game.commander.flightSimulation.visit
    if targetReturnsBeforeSave {
      try referenceBringIn(&game, logical: b)
    } else {
      try referenceBringIn(&game, logical: a)
      game.tick(delta: 0.001)
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let disk = try NativeSaveTestFixture.readVersionedCommander(from: url)
    #expect(
      disk.npcPersistence.binding(for: a) == nil && disk.npcPersistence.binding(for: b) == nil)
    let savedA = try #require(disk.npcPersistence.snapshot(for: a))
    #expect(savedA.npc.intention == .flee(b))
    try await runtime.load(from: url)
    let retained = await runtime.snapshot()
    #expect(!retained.docked && retained.commander.flightSimulation.visit == oldVisit)
    #expect(
      retained.commander.npcPersistence.binding(for: a)
        == game.commander.npcPersistence.binding(for: a))
    #expect(
      retained.commander.npcPersistence.binding(for: b)
        == game.commander.npcPersistence.binding(for: b))
    // Retained flight is distinct from the subsequent genuine actor visit transition.
    await runtime.nativeCommand { $0.dock() }
    #expect(await runtime.snapshot().docked)
    await runtime.key("0")
    game = await runtime.snapshot()
    let afterLoadB = try referenceBringIn(&game, logical: b)
    #expect(afterLoadB.visit > oldVisit && game.commander.npcPersistence.binding(for: a) == nil)
    try referenceBringIn(&game, logical: a)
    try referenceExpectA(game, a: a, target: afterLoadB, flee: true, saved: savedA)
  }

  @Test func actualTargetDeathDoesNotResurrectOrRetargetItsDependentNPC() throws {
    let (initial, a, b) = try referenceGame()
    var game = initial
    try referenceCullBoth(&game, a: a, b: b)
    let b1 = try referenceBringIn(&game, logical: b)
    let bi = try #require(game.bodies.firstIndex { $0.physical?.identity == b1 })
    game.bodies[bi].energy = 0
    game.resolveDestroyed()
    #expect(game.commander.npcPersistence.livingCount == 1)
    try referenceBringIn(&game, logical: a)
    let a1 = try #require(game.commander.npcPersistence.binding(for: a))
    let body = try #require(game.bodies.first { $0.physical?.identity == a1 })
    #expect(body.physical?.npc?.firstAggressor == b)
    #expect(body.physical?.npc?.intention == nil)
    #expect(!game.bodies.contains { $0.physical?.identity == b1 })
    let cargo = game.commander.cargoDebrisLedger.pendingPayloads
    game.admitPersistentNPCs()
    #expect(game.commander.npcPersistence.binding(for: b) == nil)
    #expect(game.commander.cargoDebrisLedger.pendingPayloads == cargo)
    #expect(body.physical?.npc?.resources?.fuel == 23 && body.missiles == 1)
  }

  @Test func playerStationAndForeignReferencesStayInTheirOwnNamespaces() async throws {
    let (initial, a, b) = try referenceGame()
    var game = initial
    let oldPlayer = try #require(game.commander.flightSimulation.player)
    let oldStation = try #require(game.commander.flightSimulation.anchors?.station.identity)
    game.bodies[0].physical?.npc?.firstAggressor = oldPlayer
    game.bodies[0].physical?.npc?.intention = .dock(oldStation)
    try referenceCullBoth(&game, a: a, b: b)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    try await runtime.load(from: url)
    await runtime.key("0")
    game = await runtime.snapshot()
    let current = try referenceBringIn(&game, logical: a)
    let body = try #require(game.bodies.first { $0.physical?.identity == current })
    #expect(body.physical?.npc?.firstAggressor == game.commander.flightSimulation.player)
    #expect(
      body.physical?.npc?.intention
        == game.commander.flightSimulation.anchors.map { .dock($0.station.identity) })
    let (foreignInitial, fa, fb) = try referenceGame()
    var foreignGame = foreignInitial
    let foreign = ActorIdentity(system: .init(galaxy: 7, system: 0), visit: 4, entity: 0)
    foreignGame.bodies[0].physical?.npc?.firstAggressor = foreign
    foreignGame.bodies[0].physical?.npc?.intention = .flee(foreign)
    try referenceCullBoth(&foreignGame, a: fa, b: fb)
    let foreignActor = try referenceBringIn(&foreignGame, logical: fa)
    let restored = try #require(foreignGame.bodies.first { $0.physical?.identity == foreignActor })
    #expect(
      restored.physical?.npc?.firstAggressor == foreign
        && restored.physical?.npc?.intention == .flee(foreign))
  }

  @Test func refusedTargetAdmissionRetainsRelationshipUntilARealSlotOpens() throws {
    let (initial, a, b) = try referenceGame()
    var game = initial
    try referenceCullBoth(&game, a: a, b: b)
    let a1 = try referenceBringIn(&game, logical: a)
    #expect(game.bodies.first { $0.physical?.identity == a1 }?.physical?.npc?.intention == nil)
    let waitingVelocity = try #require(
      game.bodies.first { $0.physical?.identity == a1 }?.physical?.velocity)
    game.tick(delta: 0.01)
    #expect(
      game.bodies.first { $0.physical?.identity == a1 }?.physical?.velocity == waitingVelocity)
    #expect(game.persistNPCStates().isEmpty)
    let context = try #require(game.gameplayContext())
    var requests: [SpawnRequest] = []
    for index in 0..<7 {
      let allocated = game.commander.flightSimulation.allocateSpawn()
      let sequence = try #require(allocated)
      requests.append(
        .init(
          identity: .init(
            system: context.system, visit: context.visit,
            sequence: sequence, member: 0), population: .civilian, hull: .cobra,
          position: context.player.position + .init(Double(index - 3) * 800, 0, 5000),
          orientation: Basis3(), velocity: .init(0, 0, 0),
          npc: .init(role: .escort, origin: context.system, destination: context.system),
          rock: nil, payload: nil, priority: .ordinary))
    }
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: requests, atomic: true)], intents: [])
    )
    #expect(receipts.count == 7 && receipts.allSatisfy { $0.actor != nil })
    let savedB = try #require(game.commander.npcPersistence.snapshot(for: b))
    referenceMovePlayer(&game, near: savedB.position)
    game.admitPersistentNPCs()
    #expect(game.commander.npcPersistence.binding(for: b) == nil)
    #expect(game.bodies.first { $0.physical?.identity == a1 }?.physical?.npc?.intention == nil)
    let removed = try #require(receipts.first?.actor)
    let ri = try #require(game.bodies.firstIndex { $0.physical?.identity == removed })
    game.bodies[ri].energy = 0
    game.resolveDestroyed()
    game.admitPersistentNPCs()
    let b1 = try #require(game.commander.npcPersistence.binding(for: b))
    let restoredA = try #require(game.bodies.first { $0.physical?.identity == a1 })
    #expect(restoredA.physical?.npc?.firstAggressor == b1)
    #expect(restoredA.physical?.npc?.intention == .flee(b1))
    #expect(restoredA.physical?.npc?.resources?.fuel == 23 && restoredA.missiles == 1)
  }

  @Test func changedActualReferenceCannotReuseAnOldLogicalAssociation() throws {
    let (initial, a, b) = try referenceGame()
    var game = initial
    let player = try #require(game.commander.flightSimulation.player)
    game.bodies[1].position.z = 45000
    game.tick(delta: 0.001)
    #expect(game.commander.npcPersistence.binding(for: b) == nil)
    let ai = try #require(game.bodies.firstIndex { $0.physical?.identity == a })
    game.bodies[ai].physical?.npc?.firstAggressor = player
    game.bodies[ai].physical?.npc?.intention = .engage(player)
    game.bodies[ai].position.x = 45000
    game.tick(delta: 0.001)
    try referenceBringIn(&game, logical: b)
    let a1 = try referenceBringIn(&game, logical: a)
    let restored = try #require(game.bodies.first { $0.physical?.identity == a1 })
    #expect(restored.physical?.npc?.firstAggressor == player)
    #expect(restored.physical?.npc?.intention == .engage(player))
  }

  @Test func protectedActorsNeverBecomeOrdinaryPersistentReferenceAliases() throws {
    let (initial, a, b) = try referenceGame(protectedB: true)
    var game = initial
    #expect(game.commander.npcPersistence.count == 1)
    game.bodies[0].position.x = 45000
    game.tick(delta: 0.001)
    let a1 = try referenceBringIn(&game, logical: a)
    game.bodies.removeAll { $0.physical?.identity == b }
    var replacement = SpaceBody(id: 41, hull: .cobra, position: .init(0, 0, 3000))
    replacement.navalTarget = true
    game.bodies.append(replacement)
    game.ensurePhysicalActors()
    game.admitPersistentNPCs()
    let body = try #require(game.bodies.first { $0.physical?.identity == a1 })
    let newActor = try #require(game.bodies.last?.physical?.identity)
    #expect(newActor != b && body.physical?.npc?.firstAggressor == b)
    #expect(body.physical?.npc?.intention == .flee(b))
    #expect(game.commander.npcPersistence.count == 1)
    #expect(game.commander.npcPersistence.logicalIdentity(for: newActor) == nil)
  }
}
