import Foundation
import Testing

@testable import EliteCore

private func persistedNPCGame() throws -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var npc = NPCState(
    role: .trader, origin: game.systemIdentity, destination: .init(galaxy: 1, system: 0))
  npc.resources = NPCResources.stock(game.commander.performance)
  npc.resources?.fuel = 23
  npc.resources?.frontShield = 12
  npc.resources?.rearShield = 15
  npc.resources?.laserHeat = 37
  npc.ordinaryCargo = [.init(commodity: .gold, quantity: 4)]
  npc.cargoProvenance = .recorded
  npc.routeProvenance = .generated
  npc.legalProvenance = .recorded
  npc.legal = .init(value: 16, bountyTenths: 50)
  npc.hasFuelScoops = false
  npc.firstAggressor = game.commander.flightSimulation.player
  npc.intention = .engage(try #require(game.commander.flightSimulation.player))
  var body = SpaceBody(id: 40, hull: .cobra, position: .init(0, 0, 2000))
  body.energy = 73
  body.missiles = 1
  body.ecmEnabled = true
  let spawn = SpawnIdentity(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit, sequence: 1,
    member: 0)
  body.physical = .init(
    identity: actor, population: .civilian, npc: npc, velocity: .init(0, 0, 10),
    laserCooldown: 0.19, spawnIdentity: spawn)
  game.bodies = [body]
  return game
}

struct NPCPersistenceRuntimeTests {
  @Test func dockingUnbindsSpentNPCsWithoutChangingTheirRetainedStateAndReloadsTheWholeCommander()
    async throws
  {
    var game = try persistedNPCGame()
    try await verifyDockedNPCPersistence(&game)
  }

  @Test func deadNPCOutsideBubbleSettlesBeforeCullAndNeverResurrects() throws {
    var game = try persistedNPCGame()
    let source = try #require(game.bodies[0].physical?.identity)
    #expect(game.persistNPCStates().isEmpty)
    game.bodies[0].position.z = 45000
    game.bodies[0].energy = 0
    game.tick(delta: 0.001)
    #expect(game.bodies.isEmpty && game.commander.npcPersistence.livingCount == 0)
    #expect(game.commander.npcPersistence.binding(for: source) == nil)
    #expect(
      game.commander.cargoDebrisLedger.pendingPayloads.map(\.amount) == [
        .init(commodity: .gold, quantity: 4)
      ])
    game.admitPersistentNPCs()
    #expect(game.bodies.isEmpty)
  }

  @Test func dockingSettlesPendingDeathBeforeDiscardingScene() throws {
    var game = try persistedNPCGame()
    #expect(game.persistNPCStates().isEmpty)
    game.bodies[0].energy = 0
    game.dock()
    #expect(game.docked && game.commander.npcPersistence.livingCount == 0)
    #expect(
      game.commander.cargoDebrisLedger.pendingPayloads.map(\.amount) == [
        .init(commodity: .gold, quantity: 4)
      ])
    game.launch()
    #expect(!game.bodies.contains { $0.physical?.npc != nil })
  }

  @Test func blockedCargoSettlementPreventsDockAndCameraRemovalUntilCapacityReturns() throws {
    var game = try persistedNPCGame()
    #expect(game.persistNPCStates().isEmpty)
    let source = try #require(game.bodies[0].physical?.identity)
    // A valid full historical debris ledger makes this real death defer atomically.
    for _ in 0..<CargoDebrisLedger.maximumSources {
      let allocated = game.commander.flightSimulation.allocateActor()
      let actor = try #require(allocated)
      let allocatedEvent = game.commander.flightSimulation.allocateIncident()
      let event = try #require(allocatedEvent)
      let dead = ActorSnapshot(
        identity: actor, hull: .cobra, position: .init(0, 0, 2500),
        orientation: Basis3(), velocity: .init(0, 0, 0), energy: 0, maximumEnergy: 100,
        maximumSpeedUnitsPerSecond: 100, legal: .init(),
        npc: .init(role: .trader, origin: game.systemIdentity, destination: game.systemIdentity),
        rock: nil, payload: nil, ordinaryCargo: [.init(commodity: .food, quantity: 1)])
      let registration = game.commander.cargoDebrisLedger.registerDeath(
        actor: dead,
        manifest: dead.ordinaryCargo, settlementID: event, physicalTime: 0, protection: .init())
      #expect(registration == .registered(lots: 1))
    }
    game.bodies[0].energy = 0
    game.resolveDestroyed()
    let event = try #require(game.bodies[0].physical?.deathIncidentID)
    game.bodies[0].position.z = 45000
    game.tick(delta: 0.001)
    #expect(game.bodies.contains { $0.physical?.identity == source && $0.energy == 0 })
    #expect(
      game.bodies.first { $0.physical?.identity == source }?.physical?.deathIncidentID == event)
    game.dock()
    #expect(!game.docked && game.hasUnsettledCargoDeaths)
    game.commander.equipment.insert("Escape Pod")
    game.commander.cargo[0] = 1
    let beforeEscape = game.commander
    game.escapePod()
    #expect(!game.docked && game.commander == beforeEscape)
    game.commander.cargo[0] = 0
    game.commander.equipment.insert("Fuel Scoops")
    game.admitPendingCargo()
    let pod = try #require(game.bodies.firstIndex { $0.physical?.payload != nil })
    game.bodies[pod].position = .init(0, -10, 40)
    game.scoopCargo()
    #expect(game.commander.cargo[0] == 1)
    game.resolveDestroyed()
    #expect(!game.hasUnsettledCargoDeaths && game.commander.npcPersistence.livingCount == 0)
    #expect(
      game.commander.cargoDebrisLedger.pendingPayloads.filter { $0.amount.commodity == .gold }.map(
        \.amount) == [.init(commodity: .gold, quantity: 4)])
    game.admitPersistentNPCs()
    #expect(!game.bodies.contains { $0.physical?.npc != nil })
    game.dock()
    #expect(game.docked)
  }

  @Test func realSaveReloadAndLaunchRetainSpentStateAndRebindSceneReferences() async throws {
    let game = try persistedNPCGame()
    let source = try #require(game.bodies[0].physical?.identity)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let onDisk = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: url))
    #expect(onDisk.npcPersistence.binding(for: source) == nil)
    try await runtime.load(from: url)
    await runtime.key("0")
    let loaded = await runtime.snapshot()
    let rebound = try #require(loaded.commander.npcPersistence.binding(for: source))
    let body = try #require(loaded.bodies.first { $0.physical?.identity == rebound })
    #expect(rebound != source && rebound.visit == loaded.commander.flightSimulation.visit)
    #expect(body.energy == 73 && body.missiles == 1 && body.ecmEnabled)
    #expect(body.physical?.laserCooldown == 0.19)
    #expect(body.physical?.npc?.resources == game.bodies[0].physical?.npc?.resources)
    #expect(body.physical?.npc?.ordinaryCargo == game.bodies[0].physical?.npc?.ordinaryCargo)
    #expect(body.physical?.npc?.routeProvenance == .generated)
    #expect(body.physical?.npc?.legal == game.bodies[0].physical?.npc?.legal)
    #expect(body.physical?.npc?.firstAggressor == loaded.commander.flightSimulation.player)
    #expect(
      body.physical?.npc?.intention
        == .engage(try #require(loaded.commander.flightSimulation.player)))
    #expect(loaded.bodies.filter { $0.physical?.npc?.role == .trader }.count == 1)
  }

  @Test func actualCullKeepsCoastingStateWithoutReAdmissionUntilPlayerReturns() throws {
    var game = try persistedNPCGame()
    game.bodies[0].physical?.npc?.firstAggressor = nil
    game.bodies[0].physical?.npc?.intention = .navigate(
      position: .init(0, 0, 100000), speedUnitsPerSecond: 100)
    game.bodies[0].position.z = 45000
    let source = try #require(game.bodies[0].physical?.identity)
    game.tick(delta: 0.001)
    #expect(game.bodies.isEmpty)
    #expect(game.commander.npcPersistence.binding(for: source) == nil)
    let culled = try #require(game.commander.npcPersistence.snapshot(for: source))
    let allocator = game.commander.flightSimulation.nextActor
    game.tick(delta: 0.1)
    game.tick(delta: 0.1)
    #expect(game.bodies.isEmpty && game.commander.flightSimulation.nextActor == allocator)
    let coasted = try #require(game.commander.npcPersistence.snapshot(for: source))
    #expect(coasted.position.z > culled.position.z)
    #expect(coasted.laserCooldown == 0)
    #expect(coasted.npc.resources?.laserHeat ?? 0 < culled.npc.resources?.laserHeat ?? 0)
    #expect(coasted.npc.resources?.fuel == culled.npc.resources?.fuel)
    game.commander.flightSimulation.pose.position = coasted.position - .init(0, 0, 1000)
    game.admitPersistentNPCs()
    let actor = try #require(game.commander.npcPersistence.binding(for: source))
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(body.energy == coasted.energy && body.physical?.npc?.resources == coasted.npc.resources)
    #expect(body.missiles == 1 && actor != source)
    game.admitPersistentNPCs()
    #expect(game.bodies.count == 1 && game.commander.npcPersistence.binding(for: source) == actor)
  }

  @Test func actualDestroyedNPCSettlesCargoThenCannotReturnAsFreshStock() throws {
    var game = try persistedNPCGame()
    let source = try #require(game.bodies[0].physical?.identity)
    #expect(game.persistNPCStates().isEmpty)
    game.bodies[0].energy = 0
    game.resolveDestroyed()
    game.admitPersistentNPCs()
    #expect(game.bodies.isEmpty && game.commander.npcPersistence.livingCount == 0)
    #expect(game.commander.npcPersistence.count == 1)
    #expect(
      game.commander.cargoDebrisLedger.pendingPayloads.map(\.amount) == [
        .init(commodity: .gold, quantity: 4)
      ])
    #expect(game.commander.npcPersistence.binding(for: source) == nil)
  }

  @Test func failedSaveCannotPublishNPCBindingsOrConsumeARecord() async throws {
    let game = try persistedNPCGame()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: directory.path)
      try? FileManager.default.removeItem(at: directory)
    }
    let file = directory.appendingPathComponent("commander.json")
    let original = try JSONEncoder().encode(game.commander)
    try original.write(to: file, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    let runtime = GameRuntime(game: game)
    let beforeFailedSave = await runtime.snapshot()
    var failed = false
    do { try await runtime.save(to: file) } catch { failed = true }
    #expect(failed)
    let after = await runtime.snapshot()
    #expect(
      after.commander == beforeFailedSave.commander && after.bodies == beforeFailedSave.bodies)
    #expect(try Data(contentsOf: file) == original)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    try await runtime.save(to: file)
    #expect(await runtime.snapshot().commander.npcPersistence.count == 1)
  }
}

private func verifyDockedNPCPersistence(_ game: inout Game) async throws {
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  try #require(game.persistNPCStates().isEmpty)
  let before = game.commander
  let actor = try #require(game.bodies[0].physical?.identity)
  try #require(before.npcPersistence.binding(for: actor) == actor)
  var expected = before
  expected.npcPersistence.resetPhysicalBindings(system: game.systemIdentity)
  game.dock()
  #expect(game.docked && game.bodies.isEmpty)
  #expect(game.commander.npcPersistence == expected.npcPersistence)
  #expect(game.commander.npcPersistence.livingCount == 1)
  let completeDockedCommanderPreserved = game.commander == expected
  #expect(completeDockedCommanderPreserved)
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "docked-npc-" + UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let file = root.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: file)
  game = await runtime.snapshot()
  let completeLiveCommanderPreserved = game.commander == expected
  #expect(completeLiveCommanderPreserved)
  let bytes = try Data(contentsOf: file)
  let onDisk = try JSONDecoder().decode(Commander.self, from: bytes)
  let completeDiskCommanderPreserved = onDisk == expected
  #expect(completeDiskCommanderPreserved)
  try await runtime.load(from: file, persistMigrations: false)
  game = await runtime.snapshot()
  let completeRestoredCommanderPreserved = game.commander == expected
  #expect(completeRestoredCommanderPreserved)
  #expect(game.docked && game.bodies.isEmpty)
  #expect(try Data(contentsOf: file) == bytes)
}

/// Captures the existing failed native callers without changing their fixtures or assertions.
@Test(arguments: ["flight", "docked", "absent"])
func actualNativeSaveCallerDiagnosticRetainsWholeValues(variant: String) async throws {
  var game = variant == "absent" ? Game(executive: false) : try persistedNPCGame()
  var stages: [String: Any] = ["variant": variant]
  var expected: Commander
  if variant == "absent" {
    game.screen = .status
    expected = game.commander
    let persisted = game.persistSalvagePoses()
    stages["absentPosePersistence"] = persisted
    game.dock()
  } else if variant == "docked" {
    try game.commander.prepareEquipment()
    game.commander.mirrorFittedEquipment()
    let refusals = game.persistNPCStates()
    stages["initialNPCRefusals"] = refusals.count
    expected = game.commander
    expected.npcPersistence.resetPhysicalBindings(system: game.systemIdentity)
    game.dock()
  } else {
    expected = game.commander
  }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let expectedBytes = try encoder.encode(expected)
  stages["afterDockEqualsExpected"] = game.commander == expected
  stages["afterDockEncodedFieldDifferences"] = try nativeSaveDiagnosticDifferences(
    expectedBytes, encoder.encode(game.commander))
  let runtime = GameRuntime(game: game)
  let ready = await runtime.snapshot()
  let readyBytes = try encoder.encode(ready.commander)
  stages["readyCommanderValid"] = ready.commander.valid
  stages["readyFlightValid"] = ready.commander.flightSimulation.valid
  stages["readyNPCRegistryValid"] = ready.commander.npcPersistence.valid
  stages["readyEquipmentValid"] = ready.commander.equipmentStateValid
  stages["readyStationValid"] = ready.commander.nativeStationStateValid
  stages["readyScriptStateValid"] = ready.commander.scriptState.valid
  stages["readyCargoTonnes"] = ready.commander.checkedCargoTonnes
  stages["readyCargoCapacity"] = ready.commander.capacity
  stages["readyWorldValid"] = ready.scriptWorldSave.valid
  stages["readyWorldConsistent"] = ready.scriptWorldSave.consistent(with: ready.commander)
  stages["readyRequiresVersionedDurability"] = ready.requiresScriptDurability
  stages["runtimeInitEqualsInput"] = ready.commander == game.commander
  stages["runtimeInitEncodedFieldDifferences"] = try nativeSaveDiagnosticDifferences(
    encoder.encode(game.commander), readyBytes)
  do {
    let prepared = try GameRuntime.prepareNativeSaveState(ready)
    stages["nativePrepare"] = "succeeded"
    stages["preparedCommanderValid"] = prepared.commander.valid
    stages["preparedWorldValid"] = prepared.game.scriptWorldSave.valid
    stages["preparedWorldConsistent"] = prepared.game.scriptWorldSave.consistent(
      with: prepared.commander)
    stages["nativePrepareLiveEqualsReady"] = prepared.game.commander == ready.commander
    stages["nativePrepareLiveEncodedFieldDifferences"] = try nativeSaveDiagnosticDifferences(
      readyBytes, encoder.encode(prepared.game.commander))
  } catch {
    stages["nativePrepareError"] = String(reflecting: error)
  }
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "native-save-diagnostic-" + UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("commander.json")
  var action = "save"
  do {
    try await runtime.save(to: file)
    stages["save"] = "succeeded"
    let after = await runtime.snapshot()
    stages["savedLiveEqualsReady"] = after.commander == ready.commander
    stages["savedLiveEqualsExpected"] = after.commander == expected
    stages["savedLiveEncodedFieldDifferences"] = try nativeSaveDiagnosticDifferences(
      readyBytes, encoder.encode(after.commander))
    let bytes = try Data(contentsOf: file)
    let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
    stages["fileTopLevelKeys"] = object?.keys.sorted()
    if let pointer = try? JSONDecoder().decode(ScriptSavePointer.self, from: bytes) {
      stages["schema"] = pointer.schemaVersion
      action = "officialVersionedReader"
      let (commander, world) = try ScriptSaveStore.read(bytes, from: file)
      stages["officialVersionedReader"] = "succeeded"
      stages["diskCommanderValid"] = commander.valid
      stages["diskWorldConsistent"] = world.consistent(with: commander)
      stages["diskEncodedFieldDifferencesFromSavedLive"] = try nativeSaveDiagnosticDifferences(
        encoder.encode(after.commander), encoder.encode(commander))
    } else {
      action = "officialRawReader"
      let commander = try JSONDecoder().decode(Commander.self, from: bytes)
      stages["officialRawReader"] = "succeeded"
      stages["diskCommanderValid"] = commander.valid
      stages["diskEncodedFieldDifferencesFromSavedLive"] = try nativeSaveDiagnosticDifferences(
        encoder.encode(after.commander), encoder.encode(commander))
    }
    action = "runtimeLoad"
    try await runtime.load(from: file, persistMigrations: false)
    stages["runtimeLoad"] = "succeeded"
    let loaded = await runtime.snapshot()
    stages["loadedEqualsSavedLive"] = loaded.commander == after.commander
    stages["loadedEncodedFieldDifferencesFromSavedLive"] = try nativeSaveDiagnosticDifferences(
      encoder.encode(after.commander), encoder.encode(loaded.commander))
    stages["loadKeptSavedBytes"] = try Data(contentsOf: file) == bytes
    // Retain the original complete-value oracle; diagnostics never normalize expected data.
    #expect(after.commander == ready.commander)
    #expect(try Data(contentsOf: file) == bytes)
  } catch {
    stages["failedAction"] = action
    stages["error"] = String(reflecting: error)
    Issue.record("Actual native save diagnostic failed at \(action): \(error)")
  }
  let result = try JSONSerialization.data(
    withJSONObject: stages, options: [.prettyPrinted, .sortedKeys])
  if let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
    let output = URL(fileURLWithPath: evidence, isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try result.write(to: output.appendingPathComponent("native-save-" + variant + ".json"))
  }
  print("NATIVE_SAVE_DIAGNOSTIC " + String(decoding: result, as: UTF8.self))
}

/// Encoded field deltas are supplemental; actual Commander equality remains the oracle.
private func nativeSaveDiagnosticDifferences(_ before: Data, _ after: Data) throws -> [String: Any]
{
  guard let a = try JSONSerialization.jsonObject(with: before) as? [String: Any],
    let b = try JSONSerialization.jsonObject(with: after) as? [String: Any]
  else { throw SaveError.invalidCommander }
  var changes: [String: Any] = [:]
  for key in Set(a.keys).union(b.keys).sorted() {
    let old = a[key] as? NSObject
    let new = b[key] as? NSObject
    if old == new { continue }
    changes[key] = ["before": a[key] ?? NSNull(), "after": b[key] ?? NSNull()]
  }
  return changes
}
