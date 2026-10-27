import Foundation
import Testing

@testable import EliteCore

struct OriginalVerifiedWarrantFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { flight.save }
  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledVerifiedWarrantDirectory)
  }
  func runtime(defaults: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    try game.prepareG03FlightEquipment()
    game.scriptPacks = defaults ? [] : [pack]
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    if defaults {
      let errors = await runtime.loadDefaultScriptPacks(
        directory: files.root.appendingPathComponent("installed"))
      try #require(errors.isEmpty)
    }
    await runtime.key("0")
    try await flight.dock(runtime)
    return runtime
  }
  func offer(_ runtime: GameRuntime) async throws -> (String, ScriptContractOffer) {
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    let offers = try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers)
    try #require(offers.count == 1)
    return (key, offers[0])
  }
  func accept(_ runtime: GameRuntime) async throws -> UUID {
    let (key, offer) = try await offer(runtime)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed)
    return try await runtime.confirmContract(quote)
  }
  func objective(_ runtime: GameRuntime, id: UUID) async throws {
    try await flight.travel(runtime, path: [7, 185])
    await runtime.key("0")
    let game = await runtime.snapshot()
    let state = try #require(game.commander.scriptState.instances[id])
    let actor = try #require(OriginalVerifiedWarrant.target(state))
    try #require(actor.presence == .present && actor.body.energy > 0)
    #expect(
      actor.body.scriptNPC?.intent?.mode == .attack && actor.body.scriptNPC?.intent?.player == true)
    #expect(actor.body.scriptNPC?.fit.definition.lasers == [OriginalVerifiedWarrant.weapon])
    await runtime.nativeCommand { game in
      guard
        let body = game.bodies.first(where: {
          $0.missionInstanceID == id && $0.missionActorID == actor.identity
        })
      else { return }
      // Controlled player pose only. Native target identity, vitality, fit and attribution stay untouched.
      var pose = game.commander.flightSimulation.pose
      let target = pose.systemPoint(body.position)
      pose.position = target - pose.orientation.z * 1500
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
    }
    let framed = await runtime.snapshot()
    try #require(!framed.docked && framed.commander.system == 185 && framed.screen == .front)
  }
  func kill(_ runtime: GameRuntime, id: UUID) async throws {
    var flash = false
    for _ in 0..<300 {
      let game = await runtime.snapshot()
      if game.commander.scriptState.instances[id].map({ OriginalVerifiedWarrant.qualifiedKill($0) })
        == true
      {
        break
      }
      let hit = try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
        excludingBodyIDs: [], includePlayer: false)
      var controls = Controls()
      if let hit, case .body(let bodyID) = hit.hit.target {
        controls.fire = game.bodies.contains {
          $0.id == bodyID && $0.missionInstanceID == id && $0.missionActorID != nil
        }
      }
      await runtime.setControls(controls)
      let frame = await runtime.advance(delta: 0.05)
      flash = flash || frame.laserFlash > 0
    }
    await runtime.setControls(Controls())
    let game = await runtime.snapshot()
    let state = try #require(game.commander.scriptState.instances[id])
    try #require(flash && OriginalVerifiedWarrant.qualifiedKill(state))
    #expect(game.commander.legal == 0)
  }
  func returnToVoss(_ runtime: GameRuntime) async throws {
    if await runtime.snapshot().docked == false { try await flight.dock(runtime) }
    await runtime.procurementRefuel()
    try await flight.travel(runtime, path: [185, 7])
  }
  func contact(_ runtime: GameRuntime, dialogue: String) async throws {
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().scriptPresentedDialogue?.id == dialogue)
  }
  func confirm(_ runtime: GameRuntime) async {
    if await runtime.snapshot().scriptConfirmSelected == false { await runtime.key("right") }
    await runtime.key("return")
  }
  func successful(_ runtime: GameRuntime) async throws -> UUID {
    let id = try await accept(runtime)
    try await objective(runtime, id: id)
    try await kill(runtime, id: id)
    try await returnToVoss(runtime)
    try await contact(runtime, dialogue: OriginalVerifiedWarrant.report)
    await confirm(runtime)
    try #require(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
    return id
  }
}

func warrantCurrentEnvelopes(_ game: consuming Game, root: URL) throws {
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  let normal = root.appendingPathComponent("normal-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: normal)
  let (loaded, world) = try ScriptSaveStore.read(Data(contentsOf: normal), from: normal)
  #expect(world.consistent(with: loaded) && loaded.scriptState == prepared.commander.scriptState)
  var alien = game
  try alien.commander.replaceAlienStorage(
    with: .init(
      owner: try #require(alien.commander.equipmentOwnerID), revision: 0, worldRevision: 0,
      world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
  let adapted = try GameRuntime.prepareNativeSaveState(alien)
  let url = root.appendingPathComponent("alien-\(UUID())/commander.json")
  try ScriptSaveStore.write(
    commander: adapted.commander, world: adapted.game.scriptWorldSave, to: url)
  let (cold, coldWorld) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
  #expect(cold.usesAlienStorageSaveVersion && coldWorld.consistent(with: cold))
  #expect(cold.scriptState == adapted.commander.scriptState)
}

// Body temporaries return before any native damage/publication frame becomes active.
private func warrantNonPlayerRayFacts(_ game: borrowing Game, instance: UUID) throws
  -> (target: Int, owner: ActorIdentity, stationPosition: Vector3, targetPosition: Vector3)
{
  let target = try #require(game.bodies.first { $0.missionInstanceID == instance })
  let station = try #require(game.bodies.first { $0.id == 0 })
  return (target.id, try #require(station.physical?.identity), station.position, target.position)
}

struct OriginalVerifiedWarrantNativeTests {
  @Test func warrantFrozenBindingsAndExactNativePlanHaveAuthoredTerms() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    #expect(fixture.pack.digest == OriginalVerifiedWarrant.digest)
    #expect(fixture.pack.manifest.npcs == [OriginalVerifiedWarrant.npc])
    let runtime = try await fixture.runtime()
    let (key, offer) = try await fixture.offer(runtime)
    let game = await runtime.snapshot()
    let distance = game.systems[7].distance(to: game.systems[185])
    #expect(distance > 0 && distance <= game.commander.maximumJumpDistance)
    #expect(game.systems[7].name == "Avenor" && game.systems[185].name == "Renas")
    #expect(offer.duration == 0 && offer.reward == (860 + 130 * 2) * 10 && offer.deposit == 0)
    let before = game.commander
    #expect(try await runtime.generateContractBoard(packDigest: fixture.pack.digest) == key)
    #expect(await runtime.snapshot().commander == before)
    let id = try await fixture.accept(runtime)
    let accepted = await runtime.snapshot()
    #expect(
      OriginalVerifiedWarrant.validJob(try #require(accepted.commander.scriptState.instances[id])))
    #expect(
      accepted.commander.cargo == before.cargo && accepted.commander.credits == before.credits)
    #expect(accepted.commander.scriptState.instances[id]?.ownedEncounters.isEmpty == true)
    #expect(accepted.commander.scriptState.savedClueJournal == nil)
  }

  @Test func warrantPlayerKillReturnReportPaysOnceAndSurvivesLaterTravel() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let id = try await fixture.accept(runtime)
    try await fixture.objective(runtime, id: id)
    let beforeCash = await runtime.snapshot().commander.credits
    let beforeKills = await runtime.snapshot().commander.kills
    try await fixture.kill(runtime, id: id)
    let killed = await runtime.snapshot()
    #expect(killed.commander.credits == beforeCash && killed.commander.kills == beforeKills + 1)
    #expect(
      killed.commander.scriptState.instances[id]?.outcome == .active
        && killed.commander.scriptState.savedClueJournal == nil)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    try await fixture.returnToVoss(runtime)
    try await fixture.contact(runtime, dialogue: OriginalVerifiedWarrant.report)
    let report = await runtime.snapshot()
    if report.scriptConfirmSelected { await runtime.key("right") }
    await runtime.key("return")  // Explicit Back.
    #expect(await runtime.snapshot().commander == report.commander)
    try await fixture.contact(runtime, dialogue: OriginalVerifiedWarrant.report)
    await fixture.confirm(runtime)
    let done = await runtime.snapshot()
    let state = try #require(done.commander.scriptState.instances[id])
    let receipt = try #require(state.completionReceipt)
    #expect(done.commander.credits == report.commander.credits + OriginalVerifiedWarrant.reward)
    #expect(receipt.valid(for: state, engine: done.commander.scriptState))
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[OriginalVerifiedWarrant.stateID]?.clueID
        == "verified-warrant-family-trace")
    var replay = done
    replay.emitScriptEvent("dialogue.confirmed", only: id)
    #expect(replay.commander.credits == done.commander.credits)
    try await fixture.flight.travel(runtime, path: [7, 185])
    let travelled = await runtime.snapshot()
    #expect(travelled.commander.system == 185 && travelled.commander.valid)
    #expect(travelled.commander.scriptState.instances[id]?.completionReceipt == receipt)
    try warrantCurrentEnvelopes(travelled, root: fixture.files.root)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == travelled.commander)
  }

  @Test(arguments: ["unrelated", "clean", "nonplayer", "removed"])
  func warrantNativeProofRejectsUnrelatedCleanUnattributedAndRemovedTargets(mode: String)
    async throws
  {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    if mode == "removed" {
      let id = try await fixture.accept(runtime)
      try await fixture.objective(runtime, id: id)
      var removed = await runtime.snapshot()
      let before = removed.commander.credits
      let body = try #require(removed.bodies.first { $0.missionInstanceID == id })
      removed.recordScriptActorRemoval(body, destroyed: false)
      removed.bodies.removeAll { $0.id == body.id }
      removed.drainScriptEvents()
      let state = try #require(removed.commander.scriptState.instances[id])
      #expect(state.outcome == .active && !OriginalVerifiedWarrant.qualifiedKill(state))
      #expect(
        removed.commander.credits == before && removed.commander.scriptState.savedClueJournal == nil
      )
      return
    }
    let id = try await fixture.successful(runtime)
    let game = await runtime.snapshot()
    var state = try #require(game.commander.scriptState.instances[id])
    if mode == "unrelated" {
      state.ownedEncounters[OriginalVerifiedWarrant.encounterID]?.actors[
        OriginalVerifiedWarrant.actorID]?.body.missionInstanceID = UUID()
    }
    if mode == "clean" {
      state.ownedEncounters[OriginalVerifiedWarrant.encounterID]?.actors[
        OriginalVerifiedWarrant.actorID]?.body.hostile = false
    }
    if mode == "nonplayer" {
      state.ownedEncounters[OriginalVerifiedWarrant.encounterID]?.actors[
        OriginalVerifiedWarrant.actorID]?.destroyedByPlayer = false
    }
    if mode == "removed" {
      state.ownedEncounters[OriginalVerifiedWarrant.encounterID]?.actors[
        OriginalVerifiedWarrant.actorID]?.presence = .outside
    }
    #expect(!OriginalVerifiedWarrant.qualifiedKill(state))
    #expect(!state.completionReceipt!.valid(for: state, engine: game.commander.scriptState))
    var engine = game.commander.scriptState
    engine.instances[id] = state
    #expect(game.commander.scriptState.savedClueJournal?.valid(engine: engine) == false)
  }

  @Test func warrantCurrentNormalAlienSaveRejectsStrippedAttributionAndReport() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let id = try await fixture.successful(runtime)
    let game = await runtime.snapshot()
    try warrantCurrentEnvelopes(game, root: fixture.files.root)
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
    let file = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    for field in ["attribution", "body-attribution", "report"] {
      var engine = game.commander.scriptState
      if field == "attribution" {
        engine.instances[id]?.ownedEncounters[OriginalVerifiedWarrant.encounterID]?.actors[
          OriginalVerifiedWarrant.actorID]?.destroyedByPlayer = nil
      }
      if field == "body-attribution" {
        engine.instances[id]?.ownedEncounters[OriginalVerifiedWarrant.encounterID]?.actors[
          OriginalVerifiedWarrant.actorID]?.body.destroyedByPlayer = nil
      }
      if field == "report" {
        engine.instances[id]?.choiceReceipts.removeValue(forKey: OriginalVerifiedWarrant.group)
      }
      let bytes = try ScriptValueStorage.encoder().encode(engine)
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
      let rehashed = ScriptSavePointer(
        format: pointer.format, schemaVersion: pointer.schemaVersion,
        generation: pointer.generation,
        hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
      #expect(throws: SaveError.self) {
        try ScriptSaveStore.read(JSONEncoder().encode(rehashed), from: fixture.save)
      }
      try original.write(to: file)
    }
  }

  @Test func warrantNonPlayerFailureAndWithdrawalRemainValidWithoutReward() async throws {
    let fixture = try OriginalVerifiedWarrantFixture()
    defer { fixture.files.clean() }
    let withdraw = try await fixture.runtime()
    let id = try await fixture.accept(withdraw)
    let before = await withdraw.snapshot().commander.credits
    try await fixture.contact(withdraw, dialogue: "voss-withdraw")
    await fixture.confirm(withdraw)
    let cancelled = await withdraw.snapshot()
    #expect(cancelled.commander.scriptState.instances[id]?.outcome == .abandoned)
    #expect(
      cancelled.commander.credits == before
        && cancelled.commander.scriptState.savedClueJournal == nil)
    try warrantCurrentEnvelopes(cancelled, root: fixture.files.root)
    let runtime = try await fixture.runtime()
    let failedID = try await fixture.accept(runtime)
    try await fixture.objective(runtime, id: failedID)
    var loss = await runtime.snapshot()
    let balance = loss.commander.credits
    let ray = try warrantNonPlayerRayFacts(loss, instance: failedID)
    // Controlled non-player combat adapter: a real current native emitter/hull ray, never a player flag.
    for _ in 0..<30 where loss.bodies.contains(where: { $0.id == ray.target && $0.energy > 0 }) {
      let contact = try loss.nearestMissionCollision(
        from: ray.stationPosition,
        direction: (ray.targetPosition - ray.stationPosition).unit, range: 15000, radius: 0,
        excludingBodyIDs: [0], includePlayer: false)
      let hit = try #require(contact)
      try #require(hit.hit.target == .body(ray.target))
      _ = try loss.preflightNativeMissionContact(
        hit, owner: ray.owner, damage: OriginalVerifiedWarrant.weapon.damage, laser: nil, mount: nil
      )
      let emitted = loss.makeAttackOrigin(owner: ray.owner)
      let origin = try #require(emitted)
      let impact = try loss.applyNativeMissionContact(
        hit, origin: origin, damage: OriginalVerifiedWarrant.weapon.damage, laser: nil, mount: nil,
        emissionPosition: loss.commander.flightSimulation.pose.systemPoint(ray.stationPosition))
      loss.projectScriptMissionImpact(impact)
    }
    #expect(loss.bodies.first { $0.id == ray.target }?.energy == 0)
    loss.resolveDestroyed()
    loss.drainScriptEvents()
    let state = try #require(loss.commander.scriptState.instances[failedID])
    #expect(state.outcome == .failed && state.contract?.settlementAmount == 0)
    #expect(loss.commander.credits == balance && loss.commander.scriptState.savedClueJournal == nil)
    #expect(!OriginalVerifiedWarrant.qualifiedKill(state) && loss.commander.valid)
    try warrantCurrentEnvelopes(loss, root: fixture.files.root)
  }
}
