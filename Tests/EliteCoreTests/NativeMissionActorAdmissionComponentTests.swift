import Foundation
import Testing

@testable import EliteCore

struct NativeMissionActorAdmissionComponentTests {
  @Test func actualAuthoredThirtyActorCohortHonoursComponentUnitsIndependentlyOfRootCapacity()
    throws
  {
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(
      "elite-native-component-cap-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.copyItem(at: original, to: temporary)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let manifest = temporary.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    let componentStart = try #require(text.range(of: "[[npcs.components]]"))
    let encounterStart = try #require(text.range(of: "[[encounters]]"))
    var components = ""
    for index in 0..<32 {
      components += """
        [[npcs.components]]
        id = "solid\(index)"
        model = "asset:turret"
        scale = 1.0
        position = {x=0.0,y=0.0,z=0.0}
        orientation = {x={x=1.0,y=0.0,z=0.0},y={x=0.0,y=1.0,z=0.0},z={x=0.0,y=0.0,z=1.0}}
        energy = 40.0
        solid = true

        """
    }
    text.replaceSubrange(componentStart.lowerBound..<encounterStart.lowerBound, with: components)
    let actorsStart = try #require(text.range(of: "actors = ["))
    let actorsEnd = try #require(
      text.range(of: "\n]", range: actorsStart.upperBound..<text.endIndex))
    let actors = (0..<30).map { index in
      let alias = index == 0 ? "lead" : index == 1 ? "wing" : String(format: "actor%02d", index)
      let x = -1500 + (index % 6) * 600
      let z = 4000 + (index / 6) * 600
      return
        "  {id=\"\(alias)\", npc=\"training-craft\", x=\(x).0, y=1000.0, z=\(z).0, hostile=true}"
    }.joined(separator: ",\n")
    text.replaceSubrange(actorsStart.upperBound..<actorsEnd.lowerBound, with: "\n" + actors)
    try text.write(to: manifest, atomically: true, encoding: .utf8)

    // The actual loader validates all authored data and computes the edited pack's digest.
    let pack = try ScriptPackLibrary.read(temporary)
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    game.ensurePhysicalActors()
    let admitted = game.bodies.filter { $0.missionInstanceID == instance }
    #expect(admitted.count == 30)
    #expect(admitted.allSatisfy { $0.scriptNPC?.components.count == 32 })
    #expect(admitted.allSatisfy { $0.scriptNativeUnits == 33 })
    #expect(game.bodies.count == 33)
    #expect(game.bodies.reduce(0) { $0 + $1.scriptNativeUnits } == 993)
    game.persistScriptActors(unloading: true)
    game.bodies.removeAll { $0.missionInstanceID == instance }
    #expect(game.bodies.count == 3)

    for index in 0..<32 {
      let id = game.nextBodyID
      game.nextBodyID += 1
      game.bodies.append(
        .init(
          id: id, hull: .cargo,
          position: .init(
            20000 + Double(index % 8) * 400,
            20000 + Double(index / 8) * 400, 20000)))
    }
    game.ensurePhysicalActors()
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    #expect(source.actors.count == 30)
    #expect(source.actors.reduce(0) { $0 + $1.nativeUnits } == 990)
    #expect(game.bodies.count == 35 && game.bodies.count + source.actors.count < 128)
    #expect(game.bodies.reduce(0) { $0 + $1.scriptNativeUnits } == 35)
    let before = game
    let preparation = try game.prepareMissionActorAdmission(source)
    guard case .pending(.nativeUnits) = preparation else {
      Issue.record("35 scene units plus990 actual cohort units must refuse1025 despite65 roots")
      return
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.nextBodyID == before.nextBodyID)
    #expect(
      game.commander.flightSimulation.nextActor == before.commander.flightSimulation.nextActor)
    #expect(
      game.commander.flightSimulation.nextSpawn == before.commander.flightSimulation.nextSpawn)

    let cargoIndex = try #require(game.bodies.lastIndex { $0.hull == .cargo })
    game.bodies.remove(at: cargoIndex)
    #expect(game.bodies.count == 34)
    let recoverySources = try game.retainedMissionActorAdmissionSources()
    let recovery = try #require(recoverySources.first { $0.instanceID == instance })
    let ready = try game.prepareMissionActorAdmission(recovery)
    guard case .ready(let plan) = ready else {
      Issue.record("34 scene units plus990 cohort units must admit exactly1024")
      return
    }
    let stagedBefore = game
    let retained = try #require(game.commander.scriptState.instances[instance])
    let stagedInstance = try plan.retentionPatch.preparingInstance(retained)
    #expect(game.commander == stagedBefore.commander && game.bodies == stagedBefore.bodies)
    let receipt = try game.commitMissionActorAdmission(plan)
    game.commander.scriptState.instances[instance] = stagedInstance
    let restored = game.bodies.filter { $0.missionInstanceID == instance }
    #expect(restored.count == 30 && receipt.nativeActors.count == 30)
    #expect(game.bodies.count == 64 && game.bodies.count < 128)
    #expect(game.bodies.reduce(0) { $0 + $1.scriptNativeUnits } == 1024)
    #expect(game.nextBodyID == stagedBefore.nextBodyID + 30)
    #expect(
      game.commander.flightSimulation.nextActor == stagedBefore.commander.flightSimulation.nextActor
        + 30)
    #expect(
      game.commander.flightSimulation.nextSpawn == stagedBefore.commander.flightSimulation.nextSpawn
        + 1)
    #expect(Set(restored.compactMap { $0.physical?.identity }).count == 30)
    #expect(Set(restored.compactMap { $0.physical?.spawnIdentity?.sequence }).count == 1)
    #expect(
      Set(restored.compactMap { $0.physical?.spawnIdentity?.member })
        == Set((0..<30).map(UInt16.init)))
    #expect(
      restored.allSatisfy { $0.scriptNPC?.components.count == 32 && $0.scriptNativeUnits == 33 })
  }
}
