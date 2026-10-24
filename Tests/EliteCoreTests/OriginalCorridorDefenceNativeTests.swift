import Foundation
import Testing

@testable import EliteCore

struct OriginalCorridorDefenceFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { flight.save }
  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledCorridorDefenceDirectory)
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
    let actor = try #require(OriginalCorridorDefence.target(state, alias: "raider-a"))
    try #require(
      actor.presence == .present || OriginalCorridorDefence.qualifiedKill(state, alias: "raider-a"))
    #expect(
      actor.body.scriptNPC?.intent?.mode == .attack && actor.body.scriptNPC?.intent?.player == true)
    #expect(actor.body.scriptNPC?.fit.definition.lasers == [OriginalCorridorDefence.weapon])
  }
  func frame(_ runtime: GameRuntime, id: UUID, alias: String) async throws {
    let state = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    let actor = try #require(OriginalCorridorDefence.target(state, alias: alias))
    await runtime.nativeCommand { game in
      guard let body = game.bodies.first(where: { $0.missionActorID == actor.identity }),
        let station = game.bodies.first(where: { $0.id == 0 })
      else { return }
      var pose = game.commander.flightSimulation.pose
      let normal = pose.orientation.apply(station.orientation.y)
      let right = pose.orientation.apply(station.orientation.x)
      let target = pose.systemPoint(body.position)
      pose.position = target + normal * 1500
      pose.orientation.x = right
      pose.orientation.z = normal * -1
      pose.orientation.y = pose.orientation.z.cross(right)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
    }
  }
  func kill(_ runtime: GameRuntime, id: UUID, alias: String) async throws {
    try await frame(runtime, id: id, alias: alias)
    var flash = false
    for _ in 0..<300 {
      try await frame(runtime, id: id, alias: alias)
      let game = await runtime.snapshot()
      let state = try #require(game.commander.scriptState.instances[id])
      if OriginalCorridorDefence.qualifiedKill(state, alias: alias) { break }
      let actor = try #require(OriginalCorridorDefence.target(state, alias: alias))
      let hit = try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 6000, radius: 0, excludingBodyIDs: [], includePlayer: false)
      var controls = Controls()
      if let hit, case .body(let bodyID) = hit.hit.target {
        controls.fire = game.bodies.contains {
          $0.id == bodyID && $0.missionActorID == actor.identity
        }
      }
      await runtime.setControls(controls)
      let frame = await runtime.advance(delta: 0.05)
      flash = flash || frame.laserFlash > 0
    }
    await runtime.setControls(Controls())
    let state = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    let target = OriginalCorridorDefence.target(state, alias: alias)
    try #require(
      flash && OriginalCorridorDefence.qualifiedKill(state, alias: alias),
      "alias=\(alias) presence=\(String(describing: target?.presence)) energy=\(String(describing: target?.body.energy)) actorPlayer=\(String(describing: target?.destroyedByPlayer)) bodyPlayer=\(String(describing: target?.body.destroyedByPlayer)) suspension=\(String(describing: state.suspension))"
    )
  }
  func kill(_ runtime: GameRuntime, id: UUID) async throws {
    for alias in OriginalCorridorDefence.actorIDs { try await kill(runtime, id: id, alias: alias) }
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
    try await contact(runtime, dialogue: OriginalCorridorDefence.report)
    await confirm(runtime)
    try #require(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
    return id
  }
}

func corridorCurrentEnvelopes(_ game: consuming Game, root: URL) throws {
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
private func corridorNonPlayerRayFacts(_ game: borrowing Game, instance: UUID) throws
  -> (target: Int, owner: ActorIdentity, stationPosition: Vector3, targetPosition: Vector3)
{
  let target = try #require(game.bodies.first { $0.missionInstanceID == instance })
  let station = try #require(game.bodies.first { $0.id == 0 })
  return (target.id, try #require(station.physical?.identity), station.position, target.position)
}

struct OriginalCorridorDefenceNativeTests {
  @Test func corridorFrozenTermsDistinctAdmissionAndProgressStartAtZero() async throws {
    let f = try OriginalCorridorDefenceFixture()
    defer { f.files.clean() }
    #expect(f.pack.digest == OriginalCorridorDefence.digest)
    #expect(f.pack.manifest.npcs == [OriginalCorridorDefence.npc])
    let runtime = try await f.runtime()
    let (key, offer) = try await f.offer(runtime)
    #expect(offer.reward == (1120 + 140 * 2) * 10 && offer.duration == 0 && offer.deposit == 0)
    let before = await runtime.snapshot().commander
    #expect(try await runtime.generateContractBoard(packDigest: f.pack.digest) == key)
    #expect(await runtime.snapshot().commander == before)
    let id = try await f.accept(runtime)
    let accepted = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    #expect(OriginalCorridorDefence.validJob(accepted))
    #expect(OriginalCorridorDefence.progressText(accepted).contains("0/3"))
    try await f.objective(runtime, id: id)
    let admitted = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    let actors = try #require(admitted.ownedEncounters[OriginalCorridorDefence.encounterID]?.actors)
    #expect(actors.count == 3 && Set(actors.values.map(\.identity)).count == 3)
    for alias in OriginalCorridorDefence.actorIDs {
      let actor = try #require(OriginalCorridorDefence.target(admitted, alias: alias))
      #expect(actor.presence == .present && actor.body.scriptNPC?.intent?.player == true)
      #expect(actor.body.scriptNPC?.fit.definition.lasers == [OriginalCorridorDefence.weapon])
    }
  }

  @Test func corridorPartialNativeKillsReloadReviewAndFinalReportRetainHistoricalProof()
    async throws
  {
    let f = try OriginalCorridorDefenceFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let id = try await f.accept(runtime)
    try await f.objective(runtime, id: id)
    for (index, alias) in OriginalCorridorDefence.actorIDs.enumerated() {
      let before = await runtime.snapshot().commander
      try await f.kill(runtime, id: id, alias: alias)
      let killed = await runtime.snapshot()
      let state = try #require(killed.commander.scriptState.instances[id])
      #expect(OriginalCorridorDefence.qualifiedKillCount(state) == index + 1)
      #expect(OriginalCorridorDefence.progressText(state).contains("\(index + 1)/3"))
      #expect(
        killed.commander.credits == before.credits && killed.commander.kills == before.kills + 1)
      #expect(state.outcome == .active && killed.commander.scriptState.savedClueJournal == nil)
      try await runtime.save(to: f.save)
      try await runtime.load(from: f.save, persistMigrations: false)
      try await f.returnToVoss(runtime)
      try await f.contact(
        runtime, dialogue: index == 2 ? OriginalCorridorDefence.report : "voss-corridor-progress")
      if index < 2 {
        await f.confirm(runtime)
        #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .active)
        try await f.objective(runtime, id: id)
        let returned = try #require(await runtime.snapshot().commander.scriptState.instances[id])
        #expect(OriginalCorridorDefence.qualifiedKillCount(returned) == index + 1)
      }
    }
    let report = await runtime.snapshot()
    await f.confirm(runtime)
    let done = await runtime.snapshot()
    let state = try #require(done.commander.scriptState.instances[id])
    let receipt = try #require(state.completionReceipt)
    #expect(done.commander.credits == report.commander.credits + OriginalCorridorDefence.reward)
    #expect(receipt.valid(for: state, engine: done.commander.scriptState))
    #expect(done.commander.scriptState.savedClueJournal?.awards.count == 1)
    var replay = done
    replay.emitScriptEvent("dialogue.confirmed", only: id)
    #expect(replay.commander == done.commander)
    try await f.flight.travel(runtime, path: [7, 185])
    let travelled = await runtime.snapshot()
    #expect(
      travelled.commander.valid
        && travelled.commander.scriptState.instances[id]?.completionReceipt == receipt)
    try corridorCurrentEnvelopes(travelled, root: f.files.root)
  }

  @Test func corridorForgedDuplicateForeignCleanAndUnattributedRecordsCannotValidateSuccess()
    async throws
  {
    let f = try OriginalCorridorDefenceFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let id = try await f.successful(runtime)
    let game = await runtime.snapshot()
    let original = try #require(game.commander.scriptState.instances[id])
    for mode in [
      "duplicate", "foreign", "clean", "actor-attribution", "body-attribution", "disabled",
      "outside", "report",
    ] {
      var state = original
      let encounter = OriginalCorridorDefence.encounterID
      if mode == "duplicate" {
        let duplicate = state.ownedEncounters[encounter]?.actors["raider-a"]
        state.ownedEncounters[encounter]?.actors["raider-b"] = duplicate
      }
      if mode == "foreign" {
        state.ownedEncounters[encounter]?.actors["raider-b"]?.body.missionInstanceID = UUID()
      }
      if mode == "clean" {
        state.ownedEncounters[encounter]?.actors["raider-b"]?.body.hostile = false
      }
      if mode == "actor-attribution" {
        state.ownedEncounters[encounter]?.actors["raider-b"]?.destroyedByPlayer = false
      }
      if mode == "body-attribution" {
        state.ownedEncounters[encounter]?.actors["raider-b"]?.body.destroyedByPlayer = false
      }
      if mode == "disabled" {
        state.ownedEncounters[encounter]?.actors["raider-b"]?.body.energy = 1
      }
      if mode == "outside" {
        state.ownedEncounters[encounter]?.actors["raider-b"]?.presence = .outside
      }
      if mode == "report" {
        state.choiceReceipts.removeValue(forKey: OriginalCorridorDefence.group)
      }
      #expect(
        state.completionReceipt?.valid(for: state, engine: game.commander.scriptState) == false)
      var engine = game.commander.scriptState
      engine.instances[id] = state
      #expect(game.commander.scriptState.savedClueJournal?.valid(engine: engine) == false)
    }
  }
  @Test func corridorNonPlayerLossAndActualRemovalNeverCreateQualifiedKills() async throws {
    let fixture = try OriginalCorridorDefenceFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let failedID = try await fixture.accept(runtime)
    try await fixture.objective(runtime, id: failedID)
    var loss = await runtime.snapshot()
    let balance = loss.commander.credits
    let ray = try corridorNonPlayerRayFacts(loss, instance: failedID)
    // Controlled non-player combat adapter: a real current native emitter/hull ray, never a player flag.
    for _ in 0..<30 where loss.bodies.contains(where: { $0.id == ray.target && $0.energy > 0 }) {
      let contact = try loss.nearestMissionCollision(
        from: ray.stationPosition,
        direction: (ray.targetPosition - ray.stationPosition).unit, range: 15000, radius: 0,
        excludingBodyIDs: [0], includePlayer: false)
      let hit = try #require(contact)
      try #require(hit.hit.target == .body(ray.target))
      _ = try loss.preflightNativeMissionContact(
        hit, owner: ray.owner, damage: OriginalCorridorDefence.weapon.damage, laser: nil, mount: nil
      )
      let emitted = loss.makeAttackOrigin(owner: ray.owner)
      let origin = try #require(emitted)
      let impact = try loss.applyNativeMissionContact(
        hit, origin: origin, damage: OriginalCorridorDefence.weapon.damage, laser: nil, mount: nil,
        emissionPosition: loss.commander.flightSimulation.pose.systemPoint(ray.stationPosition))
      loss.projectScriptMissionImpact(impact)
    }
    #expect(loss.bodies.first { $0.id == ray.target }?.energy == 0)
    loss.resolveDestroyed()
    loss.drainScriptEvents()
    let state = try #require(loss.commander.scriptState.instances[failedID])
    #expect(state.outcome == .failed && state.contract?.settlementAmount == 0)
    #expect(loss.commander.credits == balance && loss.commander.scriptState.savedClueJournal == nil)
    #expect(OriginalCorridorDefence.qualifiedKillCount(state) == 0 && loss.commander.valid)
    try corridorCurrentEnvelopes(loss, root: fixture.files.root)
    let removedRuntime = try await fixture.runtime()
    let removedID = try await fixture.accept(removedRuntime)
    try await fixture.objective(removedRuntime, id: removedID)
    var removed = await removedRuntime.snapshot()
    let body = try #require(removed.bodies.first { $0.missionInstanceID == removedID })
    removed.recordScriptActorRemoval(body, destroyed: false)
    removed.bodies.removeAll { $0.id == body.id }
    removed.drainScriptEvents()
    let removedState = try #require(removed.commander.scriptState.instances[removedID])
    #expect(
      removedState.outcome == .active
        && OriginalCorridorDefence.qualifiedKillCount(removedState) == 0)
    #expect(removed.commander.scriptState.savedClueJournal == nil)
  }
  @Test func corridorCurrentNormalAlienSaveRejectsStrippedOneOfThreeProofs() async throws {
    let fixture = try OriginalCorridorDefenceFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let id = try await fixture.successful(runtime)
    let game = await runtime.snapshot()
    try corridorCurrentEnvelopes(game, root: fixture.files.root)
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
    let file = directory.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    for field in ["attribution", "body-attribution", "report"] {
      var engine = game.commander.scriptState
      if field == "attribution" {
        engine.instances[id]?.ownedEncounters[OriginalCorridorDefence.encounterID]?.actors[
          "raider-b"]?.destroyedByPlayer = nil
      }
      if field == "body-attribution" {
        engine.instances[id]?.ownedEncounters[OriginalCorridorDefence.encounterID]?.actors[
          "raider-b"]?.body.destroyedByPlayer = nil
      }
      if field == "report" {
        engine.instances[id]?.choiceReceipts.removeValue(forKey: OriginalCorridorDefence.group)
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

}
