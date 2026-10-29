import Foundation
import Testing

@testable import EliteCore

private func actualNPCSceneRestorationGame(nearby: Bool = false) throws -> Game {
  var game = Game(executive: false)
  // NPC identity restoration is isolated from the separately tested fresh RRS rebind.
  game.commander.system = try #require(
    game.knownSystems.first { system in
      !NativeStationSource.bindings.contains {
        $0.system == SystemIdentity(galaxy: game.commander.galaxy, system: system.id)
      }
    }?.id)
  game.screen = .status
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/scripted-patrol")
  let pack = try ScriptPackLibrary.read(folder)
  game.scriptPacks = [pack]
  _ = try game.acceptScriptMission(pack)
  game.launch()
  let context = try #require(game.gameplayContext())
  var npc = NPCState(role: .trader, origin: context.system, destination: context.system)
  npc.resources = NPCResources.stock(game.commander.performance)
  npc.resources?.fuel = 23
  npc.resources?.frontShield = 12
  npc.resources?.rearShield = 15
  npc.resources?.laserHeat = 37
  npc.ordinaryCargo = [.init(commodity: .gold, quantity: 4)]
  npc.cargoProvenance = .recorded
  npc.routeProvenance = .generated
  npc.legalProvenance = .recorded
  let requests = (0..<2).map { member in
    var request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: member == 0 ? 0 : 901,
        member: 0, producer: .ambient),
      population: .civilian, hull: .cobra,
      position: context.player.position
        + .init(3000 + Double(member) * 1000, 1200, nearby ? 4000 : 7000),
      orientation: .init(), velocity: .init(4, 5, 6), npc: npc,
      rock: nil, payload: nil, priority: .ordinary)
    request.energy = 73
    return request
  }
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: requests, atomic: true)], intents: []))
  try #require(receipts.count == 2 && receipts.allSatisfy { $0.actor != nil && $0.refusal == nil })
  let refused = game.persistNPCStates()
  try #require(refused.isEmpty)
  return game
}

private func observedSavedNPCs(_ game: Game) -> [NPCPersistenceSnapshot] {
  let protection = game.gameplayContext()?.protection ?? MissionProtection()
  return game.bodies.compactMap {
    NPCPersistenceSnapshot.capture(
      body: $0, pose: game.commander.flightSimulation.pose,
      physicalTime: game.commander.flightSimulation.physicalTime, protection: protection)
  }
}

private func actualSavedNPCSpawns(_ game: Game) -> [ActorIdentity: SpawnIdentity] {
  Dictionary(
    uniqueKeysWithValues: game.bodies.compactMap { body in
      guard
        let snapshot = NPCPersistenceSnapshot.capture(
          body: body, pose: game.commander.flightSimulation.pose,
          physicalTime: game.commander.flightSimulation.physicalTime,
          protection: game.gameplayContext()?.protection ?? .init()),
        let spawn = body.physical?.spawnIdentity
      else { return nil }
      return (snapshot.actor, spawn)
    })
}

enum SavedNPCJoinForgery: CaseIterable, Sendable {
  case duplicateActor, wrongSystem, wrongVisit, unallocatedActor, wrongClock, staleRecord
  case changedPose, changedCondition, changedProvenance, changedReference, protectedActor
  case terminalRecord, outstandingOffer, ambiguousRecord, nonfinitePose
  case omittedLiveActor, missionSource, cargoSource, ordnanceSource, maximumSequence
  case securitySourceOnCivilian, ambientMember, persistenceZero, persistenceCursor,
    persistenceMember
  case duplicateSpawn
}

enum SavedNPCLoadForgery: CaseIterable, Sendable {
  case condition, pose, producer, namespace, duplicateActor, duplicateSpawn, absentMetadata,
    protectedAlias
}

private func ambiguousSavedNPCRecords(_ ledger: NPCPersistenceLedger) throws -> NPCPersistenceLedger
{
  var root = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
  var entries = try #require(root["entries"] as? [Any])
  try #require(entries.count >= 4)
  let first = try #require(entries[1] as? [String: Any])
  let firstSnapshot = try #require(first["snapshot"] as? [String: Any])
  var second = try #require(entries[3] as? [String: Any])
  var secondSnapshot = try #require(second["snapshot"] as? [String: Any])
  secondSnapshot["actor"] = firstSnapshot["actor"]
  second["snapshot"] = secondSnapshot
  entries[3] = second
  root["entries"] = entries
  return try JSONDecoder().decode(
    NPCPersistenceLedger.self, from: JSONSerialization.data(withJSONObject: root))
}

private func verifySavedNPCJoinRefusal(_ game: inout Game, forgery: SavedNPCJoinForgery) throws {
  let bound = game.commander.npcPersistence
  var ledger = bound
  ledger.resetPhysicalBindings(system: game.systemIdentity)
  var observed = observedSavedNPCs(game)
  try #require(observed.count >= 2)
  var spawns = actualSavedNPCSpawns(game)
  let civilian = try #require(
    observed.first { $0.population == .civilian && $0.npc.role == .trader })
  func spawn(_ producer: SpawnProducer, sequence: UInt64 = 0, member: UInt16 = 0) -> SpawnIdentity {
    .init(
      system: civilian.actor.system, visit: civilian.actor.visit, sequence: sequence,
      member: member, producer: producer)
  }
  let actor = observed[0].actor
  var physicalTime = game.commander.flightSimulation.physicalTime
  var protection = try #require(game.gameplayContext()).protection
  switch forgery {
  case .duplicateActor: observed.append(observed[0])
  case .wrongSystem:
    observed[0].actor = .init(
      system: .init(galaxy: 7, system: 255), visit: actor.visit, entity: actor.entity)
  case .wrongVisit:
    observed[0].actor = .init(system: actor.system, visit: actor.visit + 1, entity: actor.entity)
  case .unallocatedActor:
    observed[0].actor = .init(
      system: actor.system, visit: actor.visit, entity: game.commander.flightSimulation.nextActor)
  case .wrongClock: observed[0].physicalTime += 1
  case .staleRecord:
    physicalTime += 1
    for index in observed.indices { observed[index].physicalTime = physicalTime }
  case .changedPose: observed[0].position.x += 1
  case .changedCondition: observed[0].energy -= 1
  case .changedProvenance:
    observed[0].npc.cargoProvenance =
      observed[0].npc.cargoProvenance == .recorded ? .inferredLocal : .recorded
  case .changedReference:
    let player = game.commander.flightSimulation.player
    observed[0].npc.firstAggressor = observed[0].npc.firstAggressor == player ? nil : player
  case .protectedActor: protection.protectedActors.insert(actor)
  case .terminalRecord:
    ledger = bound
    let recorded = ledger.terminal(actor: actor, reason: .destroyed)
    try #require(recorded)
    ledger.resetPhysicalBindings(system: game.systemIdentity)
  case .outstandingOffer:
    let requests = ledger.pendingSpawnRequests(context: try #require(game.gameplayContext()))
    try #require(!requests.isEmpty)
  case .ambiguousRecord: ledger = try ambiguousSavedNPCRecords(ledger)
  case .nonfinitePose: observed[0].position.x = .infinity
  case .omittedLiveActor:
    let omitted = observed.removeFirst()
    spawns.removeValue(forKey: omitted.actor)
  case .missionSource: spawns[civilian.actor] = spawn(.mission)
  case .cargoSource: spawns[civilian.actor] = spawn(.cargo)
  case .ordnanceSource: spawns[civilian.actor] = spawn(.ordnance)
  case .maximumSequence: spawns[civilian.actor] = spawn(.ambient, sequence: .max)
  case .securitySourceOnCivilian: spawns[civilian.actor] = spawn(.security)
  case .ambientMember: spawns[civilian.actor] = spawn(.ambient, member: 1)
  case .persistenceZero: spawns[civilian.actor] = spawn(.persistence)
  case .persistenceCursor: spawns[civilian.actor] = spawn(.persistence, sequence: 1)
  case .persistenceMember:
    let requests = ledger.pendingSpawnRequests(context: try #require(game.gameplayContext()))
    try #require(!requests.isEmpty)
    ledger.resetPhysicalBindings(system: game.systemIdentity)
    spawns[civilian.actor] = spawn(.persistence, sequence: 1, member: 1)
  case .duplicateSpawn:
    let other = try #require(observed.first { $0.actor != civilian.actor })
    let duplicate = spawn(.ambient)
    spawns[civilian.actor] = duplicate
    spawns[other.actor] = duplicate
  }
  let before = ledger
  #expect(throws: NPCSceneRestorationError.self) {
    try ledger.restoreSceneBindings(
      observed, sceneActors: Set(game.bodies.compactMap { $0.physical?.identity }),
      spawnIdentities: spawns, system: game.systemIdentity,
      visit: game.commander.flightSimulation.visit,
      physicalTime: physicalTime, nextActor: game.commander.flightSimulation.nextActor,
      protection: protection)
  }
  #expect(ledger == before)
}

struct NPCSceneRestorationTests {
  @Test func actualExtendedLoadAndFirstSubsequentStepsMatchTheUninterruptedScene() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("commander.json")
    let uninterrupted = GameRuntime(game: try actualNPCSceneRestorationGame(), saveURL: url)
    var controls = Controls()
    controls.pitch = 0.3
    controls.yaw = -0.4
    await uninterrupted.setControls(controls)
    for _ in 0..<3 { _ = await uninterrupted.advance(delta: 0.1) }
    await uninterrupted.setControls(Controls())
    try await uninterrupted.save(to: url)
    let before = await uninterrupted.snapshot()
    try #require(
      before.bodies.contains {
        $0.physical?.spawnIdentity?.producer == .security
          && $0.physical?.spawnIdentity?.sequence == 0
      })
    try #require(
      before.bodies.contains {
        $0.physical?.spawnIdentity?.producer == .ambient
          && $0.physical?.spawnIdentity?.sequence == 0
      })
    let (written, _) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
    var expectedDisk = before.commander
    expectedDisk.npcPersistence.resetPhysicalBindings(system: before.systemIdentity)
    expectedDisk.resetWantedCareerBindings(system: before.systemIdentity)
    let actualDiskMatchesDocumentedCopy = written == expectedDisk
    #expect(actualDiskMatchesDocumentedCopy)
    let resumed = GameRuntime(game: before)
    try await resumed.load(from: url, persistMigrations: false)
    let loaded = await resumed.snapshot()
    let loadedCommanderMatchesLive = loaded.commander == before.commander
    let loadedBodiesMatchLive = loaded.bodies == before.bodies
    #expect(loadedCommanderMatchesLive && loadedBodiesMatchLive)
    #expect(loaded.nextBodyID == before.nextBodyID)
    for step in 0..<20 {
      _ = await uninterrupted.advance(delta: 0.1)
      _ = await resumed.advance(delta: 0.1)
      if step == 0 || step == 19 {
        let a = await uninterrupted.snapshot()
        let b = await resumed.snapshot()
        let commandersMatch = a.commander == b.commander
        let bodiesMatch = a.bodies == b.bodies
        #expect(commandersMatch && bodiesMatch)
        #expect(a.nextBodyID == b.nextBodyID)
        #expect(a.scriptSimulationSave.randomState == b.scriptSimulationSave.randomState)
      }
    }
  }

  @Test(arguments: SavedNPCJoinForgery.allCases)
  func forgedOrAmbiguousSavedJoinsRefuseTheWholeLedger(forgery: SavedNPCJoinForgery) throws {
    var game = try actualNPCSceneRestorationGame()
    try verifySavedNPCJoinRefusal(&game, forgery: forgery)
  }

  @Test func anActualOutOfSceneRecordStaysUnboundWithoutAllocation() throws {
    var game = try actualNPCSceneRestorationGame()
    try verifyPartialJoin(&game)
  }

  private func verifyPartialJoin(_ game: inout Game) throws {
    let original = game.commander.npcPersistence
    var observed = observedSavedNPCs(game)
    let last = observed.popLast()
    let absent = try #require(last)
    var expected = original
    expected.cull(actor: absent.actor)
    game.bodies.removeAll { $0.physical?.identity == absent.actor }
    var disk = original
    disk.resetPhysicalBindings(system: game.systemIdentity)
    let context = try #require(game.gameplayContext())
    try disk.restoreSceneBindings(
      observed, sceneActors: Set(game.bodies.compactMap { $0.physical?.identity }),
      spawnIdentities: actualSavedNPCSpawns(game), system: context.system, visit: context.visit,
      physicalTime: context.physicalTime,
      nextActor: game.commander.flightSimulation.nextActor, protection: context.protection)
    #expect(disk == expected)
    #expect(disk.binding(for: absent.actor) == nil)
    #expect(disk.unboundSnapshots[absent.actor] == original.snapshot(for: absent.actor))
  }

  @Test(arguments: SavedNPCLoadForgery.allCases)
  func invalidSavedSceneFailsLoadWithoutChangingLiveStateOrSaveBytes(forgery: SavedNPCLoadForgery)
    async throws
  {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let good = root.appendingPathComponent("commander.json")
    let bad = root.appendingPathComponent("forged.json")
    let runtime = GameRuntime(game: try actualNPCSceneRestorationGame(), saveURL: good)
    try await runtime.save(to: good)
    let (disk, originalWorld) = try ScriptSaveStore.read(Data(contentsOf: good), from: good)
    var world = originalWorld
    let index = try #require(world.bodies.lastIndex { $0.physical?.npc?.role == .trader })
    switch forgery {
    case .condition: world.bodies[index].energy -= 1
    case .pose: world.bodies[index].position.x += 1
    case .producer: world.bodies[index].physical?.spawnIdentity?.producer = .mission
    case .namespace:
      let physical = try #require(world.bodies[index].physical)
      world.bodies[index].physical = .init(
        identity: .init(
          system: physical.identity.system, visit: physical.identity.visit + 1,
          entity: physical.identity.entity),
        population: physical.population, npc: physical.npc, velocity: physical.velocity,
        laserCooldown: physical.laserCooldown, spawnIdentity: physical.spawnIdentity,
        catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity)
    case .duplicateActor:
      var duplicate = world.bodies[index]
      duplicate.id = world.nextBodyID
      world.nextBodyID += 1
      world.bodies.append(duplicate)
    case .duplicateSpawn:
      let other = try #require(
        world.bodies.first {
          $0.id != world.bodies[index].id && $0.physical?.spawnIdentity?.producer == .ambient
        })
      world.bodies[index].physical?.spawnIdentity = other.physical?.spawnIdentity
    case .absentMetadata: world.bodies[index].physical = nil
    case .protectedAlias: world.bodies[index].missionInstanceID = UUID()
    }
    try ScriptSaveStore.write(commander: disk, world: world, to: bad)
    let commander = await runtime.snapshot().commander
    let bodies = await runtime.snapshot().bodies
    let goodBytes = try Data(contentsOf: good)
    let badBytes = try Data(contentsOf: bad)
    await #expect(throws: (any Error).self) {
      try await runtime.load(from: bad, persistMigrations: false)
    }
    let commanderPreserved = await runtime.snapshot().commander == commander
    let bodiesPreserved = await runtime.snapshot().bodies == bodies
    #expect(commanderPreserved && bodiesPreserved)
    #expect(try Data(contentsOf: good) == goodBytes)
    #expect(try Data(contentsOf: bad) == badBytes)
  }

  @Test func absentLegacyLedgerDoesNotInventBindingsOrAlterTheWorld() throws {
    var game = Game(executive: false)
    let commander = game.commander
    let bodies = game.bodies
    try game.restoreSavedNPCSceneBindings()
    #expect(game.commander == commander && game.bodies == bodies)
  }

  @Test func actualPersistenceReentryAndLegacyNilSourcesRejoinWithoutSpawning() throws {
    var game = try actualNPCSceneRestorationGame(nearby: true)
    try verifyPersistenceAndLegacySources(&game)
  }

  private func verifyPersistenceAndLegacySources(_ game: inout Game) throws {
    let index = try #require(game.bodies.firstIndex { $0.physical?.spawnIdentity?.sequence == 901 })
    let actor = try #require(game.bodies[index].physical?.identity)
    let snapshot = try #require(game.commander.npcPersistence.snapshot(for: actor))
    let context = try #require(game.gameplayContext())
    try #require((snapshot.position - context.player.position).length <= context.perceptionRadius)
    game.commander.npcPersistence.cull(actor: actor)
    game.bodies.remove(at: index)
    game.admitPersistentNPCs()
    try #require(
      game.bodies.contains {
        $0.physical?.spawnIdentity?.producer == .persistence
          && ($0.physical?.spawnIdentity?.sequence ?? 0) > 0
      })
    let legacy = try #require(
      game.bodies.firstIndex { $0.physical?.spawnIdentity?.producer == .ambient })
    game.bodies[legacy].physical?.spawnIdentity = nil
    let refused = game.persistNPCStates()
    try #require(refused.isEmpty)
    let commander = game.commander
    let bodies = game.bodies
    game.commander.npcPersistence.resetPhysicalBindings(system: game.systemIdentity)
    try game.restoreSavedNPCSceneBindings()
    let wholeCommanderPreserved = game.commander == commander
    let wholeScenePreserved = game.bodies == bodies
    #expect(wholeCommanderPreserved && wholeScenePreserved)
  }
}
