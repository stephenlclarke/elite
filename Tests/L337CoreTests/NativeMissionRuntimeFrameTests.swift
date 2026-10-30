import Foundation
import Testing

@testable import L337Core

private func frameSaveFolder() throws -> URL {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "native-mission-frame-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  return folder
}

struct NativeMissionRuntimeFrameTests {
  @Test func actualRuntimeFrameFiresEachAuthoredGunAndMovesItsNewProjectileExactlyOnce()
    async throws
  {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    game.speed = 0
    for i in game.bodies.indices where game.bodies[i].scriptNPC != nil {
      game.bodies[i].scriptNPC?.intent = nil
      game.bodies[i].scriptNPC?.velocity = .init(0, 0, 0)
    }
    game.bodies[index].orientation = Basis3()
    game.bodies[index].orientation.x = .init(-1, 0, 0)
    game.bodies[index].orientation.y = .init(0, 1, 0)
    game.bodies[index].orientation.z = .init(0, 0, -1)
    game.bodies[index].scriptNPC?.intent = .init(
      request: "runtime-fire", mode: .attack, target: nil, player: true,
      offset: .init(0, 0, 0), speed: 0, tolerance: 1)
    let identity = try #require(game.bodies[index].missionActorID)
    let priorShots = try #require(game.bodies[index].scriptNPC?.shots)
    let folder = try frameSaveFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
    await runtime.setControls(.init())
    let frame = await runtime.advance(delta: 0.1)
    let source = try #require(frame.bodies.first { $0.missionActorID == identity })
    let npc = try #require(source.scriptNPC)
    #expect(npc.shots == priorShots + 2)
    #expect(frame.commander.scriptState.instances[instance]?.suspension == nil)
    let projectiles = frame.bodies.filter { $0.scriptShot?.owner == identity }
    try #require(projectiles.count == 1)
    let body = projectiles[0]
    let shot = try #require(body.scriptShot)
    #expect(abs(shot.age - 0.1) < 1e-9)
    #expect(shot.nativeAttribution?.sourceActorID == identity)
    #expect(shot.nativeAttribution?.instanceID == instance)
    #expect(
      frame.commander.scriptState.projectiles[shot.identity]?.body.scriptShot?.age == shot.age)
    let component = try #require(npc.fit.definition.components?.first)
    let weapon = try #require(component.weapons?.first)
    let pose = component.orientation.transformed(by: source.orientation)
    let muzzle =
      source.position + source.orientation.apply(component.position * npc.fit.definition.scale)
      + pose.apply(weapon.muzzle * (component.scale * npc.fit.definition.scale))
    #expect((body.position - (muzzle + shot.velocity * 0.1)).length < 1e-6)
    #expect(shot.damage == weapon.damage && shot.lifetime == weapon.lifetime)
    #expect(shot.radius == weapon.collisionRadius && shot.collisionDelay == weapon.collisionDelay)

    // A subsequent frame inside every authored cooldown must move the same shot once without
    // allocating another emission or charging either gun again.
    let next = await runtime.advance(delta: 0.001)
    let nextSource = try #require(next.bodies.first { $0.missionActorID == identity })
    #expect(nextSource.scriptNPC?.shots == npc.shots)
    #expect(next.nextBodyID == frame.nextBodyID)
    #expect(
      next.commander.flightSimulation.nextEmission == frame.commander.flightSimulation.nextEmission)
    let moved = try #require(next.bodies.first { $0.scriptShot?.identity == shot.identity })
    let movedShot = try #require(moved.scriptShot)
    #expect(abs(movedShot.age - shot.age - 0.001) < 1e-9)
    #expect((moved.position - body.position - shot.velocity * 0.001).length < 1e-6)
    #expect(
      next.commander.scriptState.projectiles[shot.identity]?.body.scriptShot?.age == movedShot.age)
  }

  @Test func actualRuntimeGivesANativelyAdmittedProfileOneMovementOwnerAndCurrentWorldVelocity()
    async throws
  {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.ensurePhysicalActors()
    game.speed = 0
    game.bodies[index].scriptNPC?.intent = nil
    game.bodies[index].scriptNPC?.velocity = .init(40, 0, 0)
    let owner = try #require(game.bodies[index].missionActorID)
    game.synchronizeScriptNPCPhysicalVelocities()
    game.persistScriptActors(unloading: true)
    game.bodies.removeAll { $0.missionInstanceID == instance }
    try game.restoreScriptActors()
    let source = try #require(game.bodies.first { $0.missionActorID == owner })
    let admission = try #require(source.physical?.identity)
    let spawn = try #require(source.physical?.spawnIdentity)
    let before = game.commander.flightSimulation.pose.systemPoint(source.position)
    let folder = try frameSaveFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
    await runtime.setControls(.init())
    let frame = await runtime.advance(delta: 0.1)
    let actual = try #require(frame.bodies.first { $0.missionActorID == owner })
    let velocity = try #require(actual.scriptNPC?.velocity)
    let world = frame.commander.flightSimulation.pose.orientation.apply(velocity)
    let after = frame.commander.flightSimulation.pose.systemPoint(actual.position)
    let physical = try #require(actual.physical)
    #expect(physical.identity == admission && physical.spawnIdentity == spawn)
    #expect((after - before - world * 0.1).length < 1e-6)
    #expect((physical.velocity - world).length < 1e-6)
    #expect(abs(velocity.x - 35) < 1e-6)
  }

  @Test(arguments: [false, true])
  func actualClassicRuntimeSteersAndTranslatesOnceWithNativeFireOnlyForDeclaredHostility(
    hostile: Bool
  ) async throws {
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-patrol")
    let folder = try frameSaveFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let directory = folder.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: original, to: directory)
    if !hostile {
      let manifest = directory.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
      try text.replacingOccurrences(of: "hostile=true", with: "hostile=false")
        .write(to: manifest, atomically: true, encoding: .utf8)
    }
    let pack = try ScriptPackLibrary.read(directory)
    var game = Game(executive: false)
    // The fixed-forward centre-ray oracle requires the authored closed Cobra fixture.
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
    game.energy = game.commander.performance.energy
    game.frontShield = game.commander.shieldCapacity
    game.rearShield = game.commander.rearShieldCapacity
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    let saved = try #require(
      game.commander.scriptState.instances[instance]?
        .ownedEncounters["raiders"]?.actors["lead"])
    for i in game.bodies.indices where game.bodies[i].missionInstanceID == instance {
      game.bodies[i].physical?.npc?.intention = nil
    }
    let i = try #require(game.bodies.firstIndex { $0.missionActorID == saved.identity })
    try #require(game.bodies[i].scriptNPC == nil && game.bodies[i].physical?.spawnIdentity != nil)
    game.bodies[i].position = .init(0, 0, 1000)
    game.bodies[i].orientation = Basis3()
    game.bodies[i].orientation.x = .init(hostile ? -1 : 1, 0, 0)
    game.bodies[i].orientation.y = .init(0, 1, 0)
    game.bodies[i].orientation.z = .init(0, 0, hostile ? -1 : 1)
    game.bodies[i].rotation = 0
    game.bodies[i].rotationRate = 0
    game.bodies[i].hostile = !hostile
    let pose = game.commander.flightSimulation.pose
    let initialVelocity = pose.orientation.apply(.init(0, 0, hostile ? -20 : 20))
    game.bodies[i].physical?.velocity = initialVelocity
    let player = try #require(game.commander.flightSimulation.player)
    game.bodies[i].physical?.npc?.intention =
      hostile
      ? .engage(player)
      : .navigate(position: pose.systemPoint(.init(0, 0, 5000)), speedUnitsPerSecond: 40)
    game.speed = 0
    game.celestials = []
    let before = pose.systemPoint(game.bodies[i].position)
    let emissions = game.commander.flightSimulation.nextEmission
    let shield = game.frontShield
    let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
    await runtime.setControls(.init())
    let frame = await runtime.advance(delta: 0.1)
    let body = try #require(frame.bodies.first { $0.missionActorID == saved.identity })
    let velocity = try #require(body.physical?.velocity)
    let after = frame.commander.flightSimulation.pose.systemPoint(body.position)
    #expect((after - before - velocity * 0.1).length < 1e-6)
    #expect(velocity != initialVelocity && body.hostile == hostile)
    #expect(frame.commander.flightSimulation.nextEmission == emissions + (hostile ? 1 : 0))
    #expect(hostile ? frame.frontShield < shield : frame.frontShield == shield)
    #expect(frame.commander.scriptState.instances[instance]?.suspension == nil)
  }

  @Test func actualActorOnlyInvalidBindingStopsTheRuntimeBeforeClockOrSceneMutation() async throws {
    var (game, _, index) = try actualMissionBridgeGame()
    try #require(game.commander.scriptState.projectiles.isEmpty)
    game.bodies[index].rotation = .infinity
    let folder = try frameSaveFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
    let before = await runtime.snapshot()
    try #require(before.commander.scriptState.calendarLedger != nil)
    #expect(before.time == game.time && before.bodies == game.bodies)
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    let frame = await runtime.advance(delta: 0.1)
    #expect(frame.paused && frame.message == "MISSION FLIGHT RESTORE REFUSED - PAUSED")
    #expect(frame.commander == before.commander && frame.bodies == before.bodies)
    #expect(frame.time == before.time && frame.nextBodyID == before.nextBodyID)
    #expect(frame.gameplayRevision == before.gameplayRevision)
    #expect(frame.energy == before.energy && frame.fireCooldown == before.fireCooldown)
  }

}
