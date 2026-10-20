import Foundation
import Testing

@testable import EliteCore

private var patrolDirectory: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-patrol")
}
private func patrolGame() throws -> (Game, UUID) {
  let pack = try ScriptPackLibrary.read(patrolDirectory)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  return (game, id)
}
private func actualActor(_ game: Game, alias: String, instance: UUID) throws -> SpaceBody {
  let identity = try #require(
    game.commander.scriptState.instances[instance]?.ownedEncounters["raiders"]?.actors[alias]?
      .identity)
  return try #require(game.bodies.first { $0.missionActorID == identity })
}

private func fitScriptedPatrolTargeting(_ game: inout Game) throws {
  let beforeHardware = game.commander
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .legacyUnknown)
  try #require(game.commander.hasAutomaticDocking)
  #expect(
    game.commander.fittedEquipment(at: .targetingCore)?.node.key
      == TargetingTier.docking.equipmentName)
  #expect(
    game.commander.credits == beforeHardware.credits && game.commander.cargo == beforeHardware.cargo
  )
  #expect(game.commander.scriptState == beforeHardware.scriptState)
  #expect(
    game.commander.contracts == beforeHardware.contracts
      && game.commander.accommodation == beforeHardware.accommodation)
  #expect(game.commander.laser(on: .front) == beforeHardware.laser(on: .front))
  #expect(
    game.commander.laserDamage(against: .sidewinder, mount: .front)
      == beforeHardware.laserDamage(against: .sidewinder, mount: .front))
}

@Test func scriptedPatrolFightsActualTargetsAndReportsThroughNativeStationControls() async throws {
  var game = Game(executive: false)
  game.screen = .status
  try fitScriptedPatrolTargeting(&game)
  game.scriptPacks = [try ScriptPackLibrary.read(patrolDirectory)]
  let runtime = GameRuntime(game: game)
  await runtime.key("contacts-open")
  await runtime.key("return")
  let id = try #require(await runtime.snapshot().commander.scriptState.instances.keys.first)
  await runtime.key("0")
  let legalBefore = await runtime.snapshot().commander.legal
  try #require(legalBefore == 0)
  var firing = Controls()
  var observedFlash = false
  var battle = await runtime.snapshot()
  for _ in 0..<200 {
    // Use actual outbound motion and tracking; fire only at a current owned hull contact.
    firing = Controls()
    if try campaignPatrolOutsideStationZone(await runtime.snapshot()) {
      try await selectCampaignPatrolTarget(runtime, child: id)
      firing.fire = try campaignPatrolHasActualLaserContact(await runtime.snapshot(), child: id)
    }
    await runtime.setControls(firing)
    battle = await runtime.advance(delta: 0.1)
    observedFlash = observedFlash || battle.laserFlash > 0
    if battle.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == true {
      break
    }
  }
  #expect(battle.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == true)
  #expect(battle.commander.kills == 2)
  #expect(battle.commander.scriptState.instances[id]?.data["phase"] == .string("report"))
  #expect(observedFlash && battle.commander.legal == legalBefore)
  let combatBalance = battle.commander.credits
  await runtime.setControls(Controls())
  for _ in 0..<8 {
    await runtime.key("tab")
    if await runtime.snapshot().autoPilot.targetID == 0 { break }
  }
  var returned = await runtime.snapshot()
  for _ in 0..<5000 where !returned.docked { returned = await runtime.advance(delta: 0.02) }
  #expect(returned.docked && returned.dockedAtMainStation)
  #expect(returned.commander.legal == legalBefore)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().scriptOffer == id)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  #expect(await runtime.snapshot().commander.credits == combatBalance + 1000)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().commander.credits == combatBalance + 1000)
}

@Test func actorWorldIdentityAndSpentConditionSurviveNativeDockLaunchAndSave() async throws {
  var (game, id) = try patrolGame()
  let lead = try actualActor(game, alias: "lead", instance: id)
  let index = try #require(game.bodies.firstIndex { $0.id == lead.id })
  game.bodies[index].energy = 37
  game.bodies[index].missiles = 0
  game.persistScriptActors()
  let original = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"])
  game.dock()
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"]?.presence
      == .unloaded)
  game.launch()
  let resumed = try actualActor(game, alias: "lead", instance: id)
  #expect(
    resumed.missionActorID == original.identity && resumed.energy == 37 && resumed.missiles == 0)
  #expect(resumed.id != lead.id)
  let station = try #require(game.bodies.first { $0.id == 0 })
  #expect(
    (station.orientation.inverse(resumed.position - station.position) - original.body.position)
      .length < 1e-8)
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let save = directory.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  let bytes = try Data(contentsOf: save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 26)
  let (strictSaved, strictWorld) = try ScriptSaveStore.read(bytes, from: save)
  #expect(strictSaved.valid && strictWorld.valid && strictWorld.consistent(with: strictSaved))
  let restored = GameRuntime(game: game)
  try await restored.load(from: save)
  let body = try actualActor(await restored.snapshot(), alias: "lead", instance: id)
  #expect(body.energy == 37 && body.missionActorID == original.identity && body.missiles == 0)
}

@Test func foreignEventsCullingAndDuplicateDeathsDoNotCompleteTheOwnedCohort() throws {
  var (game, id) = try patrolGame()
  try verifyPatrolForeignEventsCullingAndDuplicateDeaths(&game, id: id)
}

private func verifyPatrolForeignEventsCullingAndDuplicateDeaths(_ game: inout Game, id: UUID) throws
{
  let before = game.commander.credits
  game.emitScriptEvent(
    "actor.destroyed", values: ["encounter_id": .string("raiders"), "alias": .string("lead")],
    only: id)
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == false)
  let foreignID = try admitMissionTestObstruction(
    &game, hull: .sidewinder, position: .init(8000, 0, 8000))
  let foreignIndex = try #require(game.bodies.firstIndex { $0.id == foreignID })
  game.bodies[foreignIndex].energy = 0
  game.resolveDestroyed()
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors.values.filter {
      $0.presence == .destroyed
    }.count == 0)
  let lead = try actualActor(game, alias: "lead", instance: id)
  let index = try #require(game.bodies.firstIndex { $0.id == lead.id })
  game.bodies[index].position = .init(0, 0, 50000)
  game.tick(delta: 0.01)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"]?.presence
      == .outside)
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == false)
  #expect(game.commander.credits == before && game.commander.kills == 0)
  let wing = try actualActor(game, alias: "wing", instance: id)
  let wingIndex = try #require(game.bodies.firstIndex { $0.id == wing.id })
  game.bodies[wingIndex].energy = 0
  game.bodies[wingIndex].destroyedByPlayer = false
  let dead = game.bodies[wingIndex]
  game.resolveDestroyed()
  game.recordScriptActorRemoval(dead, destroyed: true)
  game.drainScriptEvents()
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors.values.filter {
      $0.presence == .destroyed
    }.count == 1)
  #expect(game.commander.scriptState.instances[id]?.data["phase"] != .string("report"))
  #expect(game.commander.credits == before && game.commander.kills == 0)
}

@Test func encounterPreparationRetainsIdentitiesAndAdmitsTheWholeCohortAfterDenial() throws {
  let pack = try ScriptPackLibrary.read(patrolDirectory)
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.launch()
  let anchor = try #require(game.bodies.first { $0.id == 0 })
  let obstruction = try admitMissionTestObstruction(
    &game, hull: .cobra, position: anchor.position + anchor.orientation.apply(.init(0, 0, 3000)))
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let prepared = try #require(game.commander.scriptState.instances[id]?.ownedEncounters["raiders"])
  #expect(!prepared.admitted && game.bodies.allSatisfy { $0.missionActorID == nil })
  let identities = Set(prepared.actors.values.map(\.identity))
  game.bodies.removeAll { $0.id == obstruction }
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let admitted = try #require(game.commander.scriptState.instances[id]?.ownedEncounters["raiders"])
  #expect(admitted.admitted && Set(admitted.actors.values.map(\.identity)) == identities)
  #expect(game.bodies.filter { $0.missionActorID != nil }.count == 2)
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  #expect(game.bodies.filter { $0.missionActorID != nil }.count == 2)
}

@Test func nativeCompletionRequiresActualAdmittedDestructionAndRollbackIncludesBodies() throws {
  let pack = try ScriptPackLibrary.read(patrolDirectory)
  var (game, id) = try patrolGame()
  try verifyPatrolNativeCompletionAndRollback(&game, id: id, pack: pack)
}

private func verifyPatrolNativeCompletionAndRollback(_ game: inout Game, id: UUID, pack: ScriptPack)
  throws
{
  var state = try #require(game.commander.scriptState.instances[id])
  state.milestones = [0, 1, 2]
  var candidate = game.commander
  let event = ScriptEvent(sequence: 100, kind: "contact.requested", instance: id, values: [:])
  #expect(throws: MissionPackError.self) {
    try game.applyScriptCommand(
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
      event: event, pack: pack, state: &state, candidate: &candidate)
  }
  #expect(state.outcome == .active)
  for index in game.bodies.indices where game.bodies[index].missionActorID != nil {
    game.bodies[index].energy = 0
  }
  game.resolveDestroyed()
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == true)
  #expect(game.commander.kills == 0)
  // Native removal records physical facts first; the actual dispatcher applies their handlers.
  #expect(
    game.commander.scriptState.pendingEvents.filter {
      $0.instance == id && $0.kind == "actor.destroyed"
    }.count == 2)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["phase"] == .string("report"))
}

@Test func sameFrameFatalHitBeforeDockRecordsDeathAndOrdinaryBountyExactlyOnce() throws {
  var (game, id) = try patrolGame()
  try verifyPatrolFatalHitAndBounty(&game, id: id)
}

private func verifyPatrolFatalHitAndBounty(_ game: inout Game, id: UUID) throws {
  let lead = try actualActor(game, alias: "lead", instance: id)
  let index = try #require(game.bodies.firstIndex { $0.id == lead.id })
  let station = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
  // Place this real encounter outside station protection; source hostility remains authored.
  game.bodies[station].position = .init(5000, 0, 0)
  game.bodies[index].position = .init(0, 0, 2000)
  game.bodies[index].orientation = Basis3()
  game.bodies[index].energy = 1
  game.bodies = game.bodies.filter { $0.id == 0 || $0.missionInstanceID == id }
  game.celestials = []
  game.ensurePhysicalActors()
  let context = try #require(game.gameplayContext())
  try #require((context.player.position - context.anchors.station.position).length > 1200)
  let queried = try game.nearestMissionCollision(
    from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
    includePlayer: false)
  let contact = try #require(queried)
  try #require(contact.hit.target == .body(lead.id) && contact.victimPart == nil)
  let allocated = game.makeAttackOrigin(owner: context.player.identity)
  let origin = try #require(allocated)
  let laser = try #require(game.commander.laser(on: .front))
  let damage = game.commander.laserDamage(against: lead.hull, mount: .front)
  try #require(damage >= 1)
  let before = game.commander.credits
  let struck = game.applyCombatHit(
    contact.hit, origin: origin, kind: .laser, damage: damage,
    laser: laser, mount: .front, emissionPosition: context.player.position)
  let incident = try #require(struck)
  #expect(incident.origin == origin && incident.victim != nil)
  let fatal = try #require(game.bodies.first { $0.id == lead.id })
  #expect(fatal.energy == 0 && fatal.physical?.deathOrigin == origin)
  #expect(fatal.physical?.deathIncidentID != nil)
  game.dock()
  #expect(game.commander.kills == 1 && game.commander.credits == before + 50)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"]?.presence
      == .destroyed)
  game.launch()
  #expect(game.bodies.allSatisfy { $0.missionActorID != lead.missionActorID })
  #expect(game.commander.kills == 1 && game.commander.credits == before + 50)
}

@Test func missingLocalStationMeshRetainsTheCanonicalReferenceWithoutMovingActors() throws {
  var (game, id) = try patrolGame()
  try verifyPatrolMissingStationReference(&game, id: id)
}

private func verifyPatrolMissingStationReference(_ game: inout Game, id: UUID) throws {
  game.persistScriptActors()
  let oldFrame = try #require(game.scriptReferenceFrame)
  let lead = try actualActor(game, alias: "lead", instance: id)
  let oldCanonical = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"]?.body
      .position)
  game.bodies.removeAll { $0.id == 0 }
  game.tick(delta: 0.1)
  let frame = try #require(game.scriptReferenceFrame)
  let body = try actualActor(game, alias: "lead", instance: id)
  // Both reference and visible actor receive the same native player-frame translation.
  #expect(frame.station.position.z < oldFrame.station.position.z)
  #expect(body.position.z < lead.position.z)
  let canonical = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"]?.body
      .position)
  // Existing classic NPC actually advances at 60 units/s.
  #expect(abs(canonical.z - oldCanonical.z) <= 6.01)
  try game.restoreScriptActors()
  #expect(game.bodies.filter { $0.id == 0 }.count == 1)
  #expect(game.bodies.filter { $0.missionActorID == lead.missionActorID }.count == 1)
}

@Test func physicalSaveRejectsInconsistentOwnershipBeforePublication() throws {
  var (game, id) = try patrolGame()
  try verifyPatrolPhysicalSaveConsistency(&game, id: id)
}

private func verifyPatrolPhysicalSaveConsistency(_ game: inout Game, id: UUID) throws {
  game.persistScriptActors()
  let body = try actualActor(game, alias: "lead", instance: id)
  let index = try #require(game.bodies.firstIndex { $0.id == body.id })
  game.bodies[index].energy -= 1
  #expect(!game.scriptWorldSave.consistent(with: game.commander))
  game.persistScriptActors()
  #expect(game.scriptWorldSave.consistent(with: game.commander))
}

@Test func nativeSceneLoadCannotAwardOldCommanderDeathsToANewSave() async throws {
  var (game, owner) = try patrolGame()
  for index in game.bodies.indices where game.bodies[index].missionActorID != nil {
    game.bodies[index].energy = 0
    game.bodies[index].destroyedByPlayer = true
  }
  let dead = game.bodies.filter { $0.missionActorID != nil }
  try #require(!dead.isEmpty && dead.allSatisfy { $0.energy == 0 && $0.destroyedByPlayer == true })
  let oldCommander = game.commander
  var fresh = Game(executive: false)
  fresh.screen = .status
  fresh.commander.name = "NEW SCENE OWNER"
  try fresh.commander.prepareEquipment(legacy: false)
  fresh.commander.mirrorFittedEquipment()
  let freshValid = fresh.commander.valid
  try #require(freshValid)
  var rawProbe = game
  let rawLoaded = rawProbe.load(fresh.commander)
  #expect(!rawLoaded && rawProbe.commander == oldCommander)
  #expect(rawProbe.bodies == game.bodies)
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let url = directory.appendingPathComponent("fresh.json")
  let writer = GameRuntime(game: fresh)
  try await writer.save(to: url)
  let expected = await writer.snapshot().commander
  let bytes = try Data(contentsOf: url)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 26 && pointer.scope == "commander")
  let (stored, _) = try ScriptSaveStore.read(bytes, from: url)
  #expect(stored == expected)
  // Launch owns real hardware already; the actor additionally canonicalizes its fitted mirror.
  let originalInventory = try #require(oldCommander.equipmentInventory)
  let originalHistory = try #require(oldCommander.equipmentPurchaseHistory)
  let originalOwner = try #require(oldCommander.equipmentOwnerID)
  let originalDrive = try #require(oldCommander.fittedEquipment(at: .drive))
  try #require(oldCommander.savedEquipmentVersion == 3)
  #expect(originalInventory.owner == originalOwner)
  #expect(originalDrive.node == HyperspaceDriveDefinition.node(for: .basic))
  #expect(originalDrive.provenance == .standard)
  #expect(originalDrive.component?.origin == HyperspaceDriveDefinition.template(for: .basic))
  var expectedBefore = oldCommander
  try expectedBefore.prepareEquipment()
  expectedBefore.mirrorFittedEquipment()
  #expect(expectedBefore.equipmentInventory == originalInventory)
  #expect(expectedBefore.equipmentPurchaseHistory == originalHistory)
  #expect(expectedBefore.equipmentOwnerID == originalOwner)
  #expect(expectedBefore.fittedEquipment(at: .drive) == originalDrive)
  #expect(
    expectedBefore.equipment == oldCommander.equipment.union([HyperspaceDriveTier.basic.label]))
  #expect(
    expectedBefore.credits == oldCommander.credits && expectedBefore.cargo == oldCommander.cargo)
  #expect(expectedBefore.name == oldCommander.name && expectedBefore.shipID == oldCommander.shipID)
  #expect(
    expectedBefore.fuel == oldCommander.fuel && expectedBefore.missiles == oldCommander.missiles)
  #expect(expectedBefore.laserMounts == oldCommander.laserMounts)
  #expect(expectedBefore.kills == oldCommander.kills && expectedBefore.legal == oldCommander.legal)
  #expect(expectedBefore.contracts == oldCommander.contracts)
  #expect(expectedBefore.accommodation == oldCommander.accommodation)
  #expect(expectedBefore.scriptState == oldCommander.scriptState)
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  #expect(before.bodies == game.bodies)
  #expect(before.commander == expectedBefore)
  try await runtime.load(from: url)
  let loaded = await runtime.snapshot()
  let reloadedBytes = try Data(contentsOf: url)
  #expect(loaded.commander == expected && reloadedBytes == bytes)
  #expect(loaded.bodies.isEmpty && loaded.scriptReferenceFrame == nil)
  #expect(loaded.commander.kills == 0 && loaded.commander.credits == fresh.commander.credits)
  #expect(loaded.commander.scriptState.instances.isEmpty)
  #expect(loaded.commander.scriptState.instances[owner] == nil)
  #expect(loaded.commander.equipmentOwnerID != oldCommander.equipmentOwnerID)
}

@Test func scriptedMidflightTitleAndReadOnlyGalleryDoNotRunPhysicsOrDueTimers() async throws {
  var (game, _) = try patrolGame()
  game.screen = .title
  let bodies = game.bodies
  let state = game.commander.scriptState
  let runtime = GameRuntime(game: game)
  for _ in 0..<5 { _ = await runtime.advance(delta: 0.1) }
  #expect(await runtime.snapshot().bodies == bodies)
  #expect(await runtime.snapshot().commander.scriptState == state)
  #expect(await runtime.snapshot().time > game.time)
}

@Test func galleryTrialSavesReloadOnlyWithinItsOwnNamespace() async throws {
  let pack = try ScriptPackLibrary.read(patrolDirectory)
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let live = GameRuntime(game: game)
  let trial = try await live.scriptGalleryTrial(packDigest: pack.digest)
  let namespace = try #require(await trial.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let outside = FileManager.default.temporaryDirectory.appendingPathComponent(
    UUID().uuidString + ".json")
  try Data("keep-production-file".utf8).write(to: outside)
  defer { try? FileManager.default.removeItem(at: outside) }
  await #expect(throws: MissionPackError.self) { try await trial.save(to: outside) }
  #expect(try String(contentsOf: outside, encoding: .utf8) == "keep-production-file")
  await #expect(throws: MissionPackError.self) { try await trial.load(from: outside) }
  await #expect(throws: MissionPackError.self) {
    try await trial.installScriptPack(from: patrolDirectory, destination: namespace)
  }
  let save = namespace.appendingPathComponent("trial.json")
  try await trial.save(to: save)
  let expected = await trial.snapshot().commander
  try await trial.load(from: save)
  #expect(await trial.snapshot().commander == expected)
  #expect(await live.snapshot().commander.scriptState.instances.isEmpty)
}

private func modifiedPatrol(
  source: ((String) -> String)? = nil, manifest: ((String) -> String)? = nil
) throws -> (ScriptPack, URL) {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.copyItem(at: patrolDirectory, to: folder)
  do {
    let file = folder.appendingPathComponent("manifest.toml")
    if let manifest {
      try manifest(String(contentsOf: file, encoding: .utf8)).write(
        to: file, atomically: true, encoding: .utf8)
    }
    let module = folder.appendingPathComponent("scripts/main.lua")
    if let source {
      try source(String(contentsOf: module, encoding: .utf8)).write(
        to: module, atomically: true, encoding: .utf8)
    }
    return (try ScriptPackLibrary.read(folder), folder)
  } catch {
    try? FileManager.default.removeItem(at: folder)
    throw error
  }
}

@Test func deniedLaterCommandRollsBackTheEntirePhysicalAdmission() throws {
  let (pack, folder) = try modifiedPatrol(source: {
    $0.replacingOccurrences(
      of: "commands={{op='encounter.ensure',id='raiders'}}",
      with:
        "commands={{op='encounter.ensure',id='raiders'},{op='credits',id='deny',amount=-1000000000}}"
    )
  })
  defer { try? FileManager.default.removeItem(at: folder) }
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.launch()
  let bodies = game.bodies
  let nextID = game.nextBodyID
  let credits = game.commander.credits
  game.emitScriptEvent("station.undocked")
  #expect(game.bodies == bodies && game.nextBodyID == nextID && game.commander.credits == credits)
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters.isEmpty == true)
  #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  #expect(!game.commander.scriptState.pendingEvents.contains { $0.kind == "encounter.admitted" })
}

@Test func completeEightyTwoRootCohortHasActualBodiesAndUniqueNativeIdentities() throws {
  // Keep the full formation behind the station, clear of the actual planet and sun.
  let definitions = (0..<82).map { index in
    "{id='target\(index)',hull='sidewinder',x=\(index%10*1200-5400),y=\(index/10*1200-4200),z=\(-5000-index/40*2000),hostile=false}"
  }.joined(separator: ",\n")
  let (pack, folder) = try modifiedPatrol(manifest: {
    $0.replacingOccurrences(
      of: "(?s)actors = \\[.*?\\]", with: "actors = [\n" + definitions + "\n]",
      options: .regularExpression)
  })
  defer { try? FileManager.default.removeItem(at: folder) }
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let world = try #require(game.commander.scriptState.instances[id]?.ownedEncounters["raiders"])
  #expect(world.admitted && world.actors.count == 82)
  let bodies = game.bodies.filter { $0.missionActorID != nil }
  #expect(bodies.count == 82 && Set(bodies.compactMap(\.missionActorID)).count == 82)
  #expect(game.commander.valid)
  game.persistScriptActors()
  #expect(game.scriptWorldSave.consistent(with: game.commander))
}

// Compare the two timelines at the same genuine cold boundary. This separately
// proves that the late reference load did not advance or replace combat state.
@inline(never)
private func requireUnchangedColdCombatReference(_ hot: borrowing Game, _ cold: borrowing Game)
  throws
{
  #expect(
    cold.bodies.filter { $0.nativeStationIdentity == nil }
      == hot.bodies.filter { $0.nativeStationIdentity == nil })
  #expect(cold.bodies.count == hot.bodies.count && cold.time == hot.time)
  #expect(cold.scriptSimulationSave.randomState == hot.scriptSimulationSave.randomState)
  #expect(
    cold.scriptSimulationSave.missionLoopCounter == hot.scriptSimulationSave.missionLoopCounter)
  let stations = hot.bodies.filter { $0.nativeStationIdentity != nil }
  try #require(stations.count == 1)
  let station = try #require(stations.first)
  let identity = try #require(station.nativeStationIdentity)
  let rebound = try #require(cold.bodies.first { $0.nativeStationIdentity == identity })
  var flight = hot.withReadOnlyCommander { $0.flightSimulation }
  let allocatedSpawn = flight.allocateSpawn()
  let sequence = try #require(allocatedSpawn)
  let allocatedActor = flight.allocateActor()
  let actor = try #require(allocatedActor)
  #expect(cold.withReadOnlyCommander { $0.flightSimulation } == flight)
  #expect(cold.nextBodyID == hot.nextBodyID + 1 && rebound.id == hot.nextBodyID)
  #expect(rebound.physical?.identity == actor)
  #expect(
    rebound.physical?.spawnIdentity
      == .init(
        system: hot.systemIdentity, visit: flight.visit, sequence: sequence,
        member: 0, producer: .mission))
  let binding = cold.withReadOnlyCommander {
    $0.nativeStations?.ledger.records.first { $0.identity == identity }?.binding
  }
  #expect(binding == .init(actor: actor, bodyID: hot.nextBodyID))
  #expect(rebound.position == station.position && rebound.orientation == station.orientation)
  #expect(rebound.rotation == station.rotation && rebound.energy == station.energy)
}

@Test func resumedNativeCombatRNGAndTacticsMatchTheUninterruptedWorld() async throws {
  let (pack, folder) = try modifiedPatrol(manifest: {
    $0.replacingOccurrences(of: "hull=\"sidewinder\"", with: "hull=\"constrictor\"")
      .replacingOccurrences(of: "x=0, y=0, z=3000", with: "x=10000, y=0, z=30000")
      .replacingOccurrences(of: "x=0, y=0, z=4500", with: "x=-10000, y=0, z=32000")
  })
  defer { try? FileManager.default.removeItem(at: folder) }
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  _ = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  for index in game.bodies.indices where game.bodies[index].missionActorID != nil {
    game.bodies[index].energy = 1
  }
  game.persistScriptActors()
  let uninterrupted = GameRuntime(game: game)
  for _ in 0..<60 { _ = await uninterrupted.advance(delta: 0.1) }
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let save = root.appendingPathComponent("commander.json")
  try await uninterrupted.save(to: save)
  let resumed = GameRuntime(game: game)
  try await resumed.load(from: save)
  for _ in 0..<100 {
    _ = await uninterrupted.advance(delta: 0.1)
    _ = await resumed.advance(delta: 0.1)
  }
  let hot = await uninterrupted.snapshot()
  let endSave = root.appendingPathComponent("uninterrupted-end.json")
  try await uninterrupted.save(to: endSave)
  let reference = GameRuntime(game: game)
  try await reference.load(from: endSave, persistMigrations: false)
  let a = await reference.snapshot()
  try requireUnchangedColdCombatReference(hot, a)
  let b = await resumed.snapshot()
  #expect(a.bodies == b.bodies)
  #expect(a.commander == b.commander)
  #expect(a.scriptSimulationSave.randomState == b.scriptSimulationSave.randomState)
  #expect(a.scriptSimulationSave.missionLoopCounter == b.scriptSimulationSave.missionLoopCounter)
}

@Test func nativeInSystemJumpMovesThePlayerFrameWithoutMovingTheOwnedWorldActors() throws {
  var (game, id) = try patrolGame()
  game.persistScriptActors()
  let before = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"]?.body
      .position)
  game.bodies.removeAll { $0.id == 0 }
  game.inSystemJump()
  game.persistScriptActors()
  let after = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.actors["lead"]?.body
      .position)
  #expect((after - before).length < 1e-9)
}

@Test func galleryNamespaceCannotBeRedirectedToAProductionSaveFolder() async throws {
  let pack = try ScriptPackLibrary.read(patrolDirectory)
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let trial = try await GameRuntime(game: game).scriptGalleryTrial(packDigest: pack.digest)
  let namespace = try #require(await trial.gallerySaveDirectory())
  let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
  defer {
    try? FileManager.default.removeItem(at: namespace)
    try? FileManager.default.removeItem(at: outside)
  }
  let commander = outside.appendingPathComponent("commander.json")
  try Data("production".utf8).write(to: commander)
  try FileManager.default.removeItem(at: namespace)
  try FileManager.default.createSymbolicLink(at: namespace, withDestinationURL: outside)
  await #expect(throws: MissionPackError.self) {
    try await trial.save(to: namespace.appendingPathComponent("commander.json"))
  }
  #expect(try String(contentsOf: commander, encoding: .utf8) == "production")
}
