import Foundation
import Testing

@testable import EliteCore

struct NativeIdentifiedSalvageRecoveryTests {
  @Test func actualEmptyInertiaFrameCapturesPackageAndCradleMeshMassWithoutDebrisFlags()
    async throws
  {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let state = try await f.accept(runtime)
    try await f.renas(runtime)
    var game = await runtime.snapshot()
    // Retain genuine admitted originals while removing unrelated triggers from this frame probe.
    game.bodies = game.bodies.filter { $0.missionInstanceID == state.permission.mission }
    game.commander.nativeStations?.stationInertia = []
    try #require(game.commander.nativeStations?.stationInertia.isEmpty == true)
    try #require(game.bodies.count == 3)
    #expect(game.bodies.allSatisfy { game.asteroidDebrisMassKg($0) == nil })
    let contactFrame = game.beginAsteroidContactStep(delta: 0.05)
    let frame = try #require(contactFrame)
    for body in game.bodies {
      let actor = try #require(body.physical?.identity)
      let snapshot = try #require(frame.identifiedSalvageSnapshot(actor))
      let mesh = try #require(game.scriptNPCMesh(body))
      let alias = try #require(game.identifiedSalvageAlias(body))
      #expect(snapshot.massKg == (alias == "pell-cradle" ? 100000 : 1000))
      #expect(snapshot.mesh.vertices == mesh.vertices && snapshot.mesh.faces == mesh.faces)
      #expect(!snapshot.debris && !snapshot.asteroid)
    }
    var unproved = game
    unproved.commander.scriptState.savedIdentifiedSalvageSource = nil
    #expect(unproved.bodies.allSatisfy { unproved.identifiedSalvageCollision($0) == nil })
    #expect(unproved.beginAsteroidContactStep(delta: 0.05) == nil)
    let rejected = unproved.completeAsteroidContactStep(frame, delta: 0.05)
    if case .refused(let reason) = rejected {
      #expect(reason == "ACTOR CHANGED")
    } else {
      Issue.record("A captured original must reject a now-unproved endpoint mesh.")
    }
    let frameActors = game.bodies.compactMap(\.missionActorID)
    let beforeTime = game.commander.flightSimulation.physicalTime
    game.tick(delta: 0.05)
    #expect(!game.paused)
    #expect(game.commander.flightSimulation.physicalTime > beforeTime)
    let originals = game.bodies.filter { $0.missionInstanceID == state.permission.mission }
    #expect(originals.count == 3)
    #expect(Set(originals.compactMap(\.missionActorID)) == Set(frameActors))
    #expect(originals.allSatisfy { game.identifiedSalvageCollision($0) != nil })
  }

  @Test func actualOtherMissionSameModelKeepsExistingCollisionPolicy() async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    try await f.renas(runtime)
    let directory = f.files.root.appendingPathComponent("unrelated-geometry-control")
    try FileManager.default.copyItem(
      at: ScriptPackLibrary.bundledIdentifiedSalvageDirectory, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    let original = try String(contentsOf: manifest, encoding: .utf8)
    var lines: [String] = []
    var skipping = false
    for line in original.components(separatedBy: "\n") {
      if line == "[identifiedSalvage]" {
        skipping = true
        continue
      }
      if skipping, line == "[[handlers]]" { skipping = false }
      if !skipping { lines.append(line) }
    }
    let text = lines.joined(separator: "\n")
      .replacingOccurrences(of: "id = \"l337.contract\"", with: "id = \"l337.geometry-control\"")
      .replacingOccurrences(of: "\"native-identified-salvage-v1\", ", with: "")
      .replacingOccurrences(of: "z=24000.0", with: "z=30000.0")
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let pack = try ScriptPackLibrary.read(directory)
    var game = await runtime.snapshot()
    game.scriptPacks.append(pack)
    let other = try game.acceptScriptMission(pack)
    game.emitScriptEvent("station.undocked", only: other)
    game.drainScriptEvents()
    let body = try #require(
      game.bodies.first {
        $0.missionInstanceID == other && $0.scriptNPC?.fit.definition.model == "catalogue:SH058"
      })
    let actor = try #require(body.physical?.identity)
    #expect(game.identifiedSalvageAlias(body) == nil)
    #expect(game.identifiedSalvageCollision(body) == nil)
    game.commander.nativeStations?.stationInertia = []
    let contactFrame = game.beginAsteroidContactStep(delta: 0.05)
    let frame = try #require(contactFrame)
    let snapshot = try #require(frame.identifiedSalvageSnapshot(actor))
    #expect(snapshot.massKg == AsteroidImpactPolicy.massKg(hull: body.hull))
    #expect(snapshot.massKg == 100000)
    #expect(snapshot.mesh.vertices == game.gameplayMesh(for: body).vertices)
    #expect(!snapshot.debris && !snapshot.asteroid)
  }

  @Test(arguments: ["aperture", "speed", "scoops", "module", "payload", "binding"])
  func actualNativeCollectorRefusesUnqualifiedApproaches(reason: String) async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let state = try await f.accept(runtime)
    try await f.renas(runtime)
    let offset = reason == "aperture" ? Vector3(30, -45, 55) : Vector3(0, -45, 55)
    try await f.approach(runtime, ordinal: 0, offset: offset)
    await runtime.nativeCommand { game in
      if reason == "speed" { game.speed = 250 }
      if reason == "scoops" || reason == "module" {
        let key = reason == "scoops" ? "Fuel Scoops" : "Targeting: Salvage Module"
        _ = try? game.commander.removeFittedEquipment(key)
      }
      let logical = NativeIdentifiedSalvage.actorIdentity(
        mission: state.permission.mission, digest: f.pack.digest, alias: "pell-01")
      if let index = game.bodies.firstIndex(where: { $0.missionActorID == logical }) {
        if reason == "payload" {
          game.bodies[index].physical?.payload = .mission(
            instance: state.permission.mission, payload: "pell-01")
        }
      }
    }
    let collector: GameRuntime
    if reason == "binding" {
      var malformed = await runtime.snapshot()
      let logical = NativeIdentifiedSalvage.actorIdentity(
        mission: state.permission.mission, digest: f.pack.digest, alias: "pell-01")
      let index = try #require(malformed.bodies.firstIndex { $0.missionActorID == logical })
      // Controlled malformed live binding; a durable command correctly refuses to publish it.
      malformed.bodies[index].physical?.spawnIdentity = nil
      #expect(malformed.identifiedSalvageCollision(malformed.bodies[index]) == nil)
      collector = GameRuntime(game: malformed, saveURL: f.save)
    } else {
      collector = runtime
    }
    _ = await collector.advance(delta: 0.05)
    #expect(try await f.state(collector).captures.isEmpty, "reason: \(reason)")
    #expect(await collector.snapshot().commander.scriptState.savedClueJournal == nil)
  }

  @Test func actualPickupWriterRefusalKeepsAttainedFrameAndOneOriginalUntilSaveRetry() async throws
  {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.accept(runtime)
    try await f.renas(runtime)
    try await f.approach(runtime, ordinal: 0)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("pell-pickup")
    _ = await runtime.advance(delta: 0.05)
    let failed = await runtime.snapshot()
    let pending = try #require(failed.nativeIdentifiedSalvagePending)
    #expect(
      failed.commander.flightSimulation.physicalTime
        > before.commander.flightSimulation.physicalTime)
    #expect(failed.identifiedSalvageState?.captures.isEmpty == true)
    #expect(failed.bodies.contains { $0.physical?.identity == pending.capture.actor })
    #expect(failed.commander.cargoTonnes == before.commander.cargoTonnes)
    #expect(failed.commander.credits == before.commander.credits)
    try f.files.restoreWrites(held, files: files)
    try await runtime.save(to: f.save)
    let saved = await runtime.snapshot()
    #expect(saved.identifiedSalvageState?.captures.map(\.operation) == [pending.capture.operation])
    #expect(!saved.bodies.contains { $0.physical?.identity == pending.capture.actor })
    #expect(saved.commander.cargoTonnes == before.commander.cargoTonnes)
    #expect(saved.nativeIdentifiedSalvagePending == nil)
    _ = await runtime.advance(delta: 0.05)
    #expect(await runtime.snapshot().identifiedSalvageState?.captures.count == 1)
  }

  @Test func consumedOriginalStaysExcludedThroughActualVisitAndColdRebinding() async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let state = try await f.accept(runtime)
    try await f.renas(runtime)
    try await f.collect(runtime, ordinal: 0)
    let original = try #require(try await f.state(runtime).captures.first)
    try await f.returnHome(runtime)
    await runtime.procurementRefuel()
    try await f.renas(runtime)
    #expect(
      !((await runtime.snapshot()).bodies.contains { $0.missionActorID == original.logicalActor }))
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(cold.identifiedSalvageState?.captures.first == original)
    #expect(cold.nativeIdentifiedSalvagePending == nil)
    #expect(
      cold.commander.scriptState.instances[state.permission.mission]?.payloads.values.reduce(0, +)
        == 2)
    try await f.collect(runtime, ordinal: 1)
    #expect(try await f.state(runtime).held.count == 2)
  }

  @Test func actualDestructionLeavesOneHeldMateForUnpaidOwnerReturn() async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let accepted = try await f.accept(runtime)
    try await f.renas(runtime)
    try await f.collect(runtime, ordinal: 0)
    try await f.approach(runtime, ordinal: 1, offset: .init(0, 0, 1000))
    await runtime.key("u")
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<500 {
      if try await f.state(runtime).losses.count == 1 { break }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let lost = await runtime.snapshot()
    #expect(lost.identifiedSalvageState?.losses.first?.kind == .destroyed)
    #expect(lost.identifiedSalvageState?.held.count == 1)
    #expect(lost.commander.scriptState.instances[accepted.permission.mission]?.outcome == .failed)
    #expect(
      lost.commander.scriptState.instances[accepted.permission.mission]?.payloads.values.reduce(
        0, +) == 1)
    try await f.returnHome(runtime)
    let cash = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .receive)
    let returned = await runtime.snapshot()
    #expect(returned.commander.credits == cash)
    #expect(returned.identifiedSalvageState?.reception?.complete == false)
    #expect(returned.identifiedSalvageState?.reception?.originals.count == 1)
    #expect(returned.identifiedSalvageState?.held.isEmpty == true)
    #expect(
      returned.commander.scriptState.instances[accepted.permission.mission]?.payloads.isEmpty
        == true)
    #expect(returned.commander.scriptState.savedClueJournal == nil)
    try await runtime.save(to: f.save)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(cold == returned.commander && world.consistent(with: cold))
  }

  @Test(arguments: [false, true])
  func actualHeldHullOrEscapeLossNeverConsumesUntouchedOriginal(escape: Bool) async throws {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(escapeReady: escape)
    let accepted = try await f.accept(runtime)
    try await f.renas(runtime)
    try await f.collect(runtime, ordinal: 0)
    let before = await runtime.snapshot()
    if escape {
      await runtime.key("escape-pod")
    } else {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
    }
    let lost = await runtime.snapshot()
    #expect(lost.identifiedSalvageState?.losses.count == 1)
    #expect(lost.identifiedSalvageState?.losses.first?.kind == (escape ? .escape : .hull))
    #expect(lost.identifiedSalvageState?.held.isEmpty == true)
    #expect(
      lost.commander.scriptState.instances[accepted.permission.mission]?.payloads.isEmpty == true)
    #expect(lost.commander.scriptState.instances[accepted.permission.mission]?.outcome == .failed)
    #expect(lost.commander.credits == before.commander.credits)
    #expect(lost.commander.scriptState.savedClueJournal == nil)
    let mate = NativeIdentifiedSalvage.actorIdentity(
      mission: accepted.permission.mission, digest: f.pack.digest, alias: "pell-02")
    #expect(
      lost.commander.scriptState.instances[accepted.permission.mission]?.ownedEncounters[
        NativeIdentifiedSalvage.encounterID]?.actors["pell-02"]?.identity == mate)
    #expect(
      lost.commander.scriptState.instances[accepted.permission.mission]?.ownedEncounters[
        NativeIdentifiedSalvage.encounterID]?.actors["pell-02"]?.presence != .destroyed)
    let prepared = try GameRuntime.prepareNativeSaveState(lost)
    #expect(prepared.game.identifiedSalvageState == lost.identifiedSalvageState)
    #expect(
      prepared.commander.scriptState.savedIdentifiedSalvageSource
        == lost.commander.scriptState.savedIdentifiedSalvageSource)
    try await runtime.save(to: f.save)
    let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: f.save), from: f.save)
    #expect(cold == prepared.commander && world.consistent(with: cold))
  }
}

extension NativeIdentifiedSalvageRecoveryTests {
  @Test func actualAliasReaderKeepsBothOriginalsAndCradleAuthorityAndRejectsUnprovedBodies()
    async throws
  {
    let f = try NativeIdentifiedSalvageFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let state = try await f.accept(runtime)
    try await f.renas(runtime)
    let game = await runtime.snapshot()
    var unproved = game
    unproved.commander.scriptState.savedIdentifiedSalvageSource = nil
    for alias in ["pell-cradle", "pell-01", "pell-02"] {
      let logical = NativeIdentifiedSalvage.actorIdentity(
        mission: state.permission.mission, digest: f.pack.digest, alias: alias)
      let body = try #require(game.bodies.first { $0.missionActorID == logical })
      let actualAlias = game.identifiedSalvageAlias(body)
      let revokedAlias = unproved.identifiedSalvageAlias(body)
      #expect(actualAlias == alias)
      #expect(revokedAlias == nil)
      let spawn = try #require(body.physical?.spawnIdentity)
      for mode in ["unmarked", "mission", "logical", "spawn", "visit", "retained-id"] {
        var changed = body
        switch mode {
        case "unmarked":
          changed.missionInstanceID = nil
          changed.missionActorID = nil
        case "mission": changed.missionInstanceID = UUID()
        case "logical": changed.missionActorID = UUID()
        case "spawn": changed.physical?.spawnIdentity = nil
        case "visit":
          changed.physical?.spawnIdentity = .init(
            system: spawn.system, visit: spawn.visit + 1, sequence: spawn.sequence,
            member: spawn.member, producer: spawn.producer)
        default: changed.id += 10000
        }
        let rejected = game.identifiedSalvageAlias(changed)
        #expect(rejected == nil, "alias: \(alias), mode: \(mode)")
      }
    }
  }
}
