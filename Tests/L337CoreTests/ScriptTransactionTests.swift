import Foundation
import Testing

@testable import L337Core

private struct DurableFixture {
  let root: URL
  let pack: ScriptPack
  var container: URL { root.appendingPathComponent("save") }
  var url: URL { container.appendingPathComponent("commander.json") }
  init(example: String = "scripted-courier", source: String? = nil, edits: [(String, String)] = [])
    throws
  {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "durable-script-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/" + example)
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    if let source {
      try source.write(
        to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    }
    pack = try ScriptPackLibrary.read(directory)
  }
  func game(accepted: Bool = true, destination: Bool = true) throws -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    if accepted { _ = try game.acceptScriptMission(pack) }
    if destination { game.commander.system = 129 }
    return game
  }
  /// Currency transaction fixtures retain their own 100.0 CR before acceptance.
  func cashGame(accepted: Bool = true, destination: Bool = true) throws -> Game {
    var game = Game(executive: false)
    game.commander.credits = 1000
    game.screen = .status
    game.scriptPacks = [pack]
    if accepted { _ = try game.acceptScriptMission(pack) }
    if destination { game.commander.system = 129 }
    return game
  }
  func breakWriter() throws {
    try FileManager.default.moveItem(at: container, to: root.appendingPathComponent("backup"))
    try Data("blocked directory".utf8).write(to: container)
  }
  func restoreWriter() throws {
    try FileManager.default.removeItem(at: container)
    try FileManager.default.moveItem(at: root.appendingPathComponent("backup"), to: container)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}
@Test func nativeAcceptanceAndConfirmationPublishDurablyBeforeReturning() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(
    game: try fixture.cashGame(accepted: false, destination: false), saveURL: fixture.url)
  await runtime.key("contacts-open")
  #expect(!FileManager.default.fileExists(atPath: fixture.url.path))
  await runtime.key("return")
  let accepted = await runtime.snapshot()
  #expect(
    accepted.commander.scriptState.instances.count == 1 && accepted.commander.cargoTonnes == 1)
  let acceptedPointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.url))
  #expect(acceptedPointer.schemaVersion == 26 && accepted.commander.usesEconomyMiningSaveVersion)
  #expect(!accepted.commander.miningLedger.retainsLegacyFields)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.url), from: fixture.url)
  #expect(saved == accepted.commander)
  let delivery = GameRuntime(game: try fixture.cashGame(), saveURL: fixture.url)
  await delivery.key("contacts-open")
  let offered = try Data(contentsOf: fixture.url)
  await delivery.key("return")
  let completed = await delivery.snapshot()
  #expect(completed.commander.credits == 1500 && completed.commander.cargoTonnes == 0)
  #expect(try Data(contentsOf: fixture.url) != offered)
  let completedPointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.url))
  #expect(completedPointer.schemaVersion == 26 && completed.commander.usesEconomyMiningSaveVersion)
  #expect(!completed.commander.miningLedger.retainsLegacyFields)
  let reloaded = GameRuntime(game: try fixture.cashGame(accepted: false))
  try await reloaded.load(from: fixture.url)
  let reloadedCommander = await reloaded.snapshot().commander
  let unchanged = reloadedCommander == completed.commander
  var changedPaths: [String] = []
  if !unchanged {
    changedPaths = try campaignCommanderChangedPaths(completed.commander, reloadedCommander)
    try campaignReloadEvidence(
      completed.commander, reloadedCommander, name: "native-transaction-reload")
  }
  #expect(unchanged, Comment(rawValue: "Reload changed: " + changedPaths.joined(separator: "; ")))
  await reloaded.key("contacts-open")
  await reloaded.key("return")
  #expect(await reloaded.snapshot().commander.credits == 1500)
}
@Test func failedDurableConfirmationRetainsOfferPropertyBalanceAndPriorPointerForRetry()
  async throws
{
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: try fixture.game(), saveURL: fixture.url)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.url)
  try fixture.breakWriter()
  await runtime.blackjackHandoffClick(x: 128, y: before.viewportHeight - 40)
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.scriptOffer == before.scriptOffer)
  #expect(denied.screen == .handoff && denied.message.contains("NOT COMMITTED"))
  try fixture.restoreWriter()
  #expect(try Data(contentsOf: fixture.url) == pointer)
  await runtime.key("return")
  let expectedCredits = before.commander.credits + 500
  #expect(await runtime.snapshot().commander.credits == expectedCredits)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.url), from: fixture.url)
  #expect(saved.credits == expectedCredits && saved.cargoTonnes == 0)
}

@Test func scriptPublicationPreservesActuallyLoadedLegacyMiningHistory() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  var historical = try fixture.game(accepted: false, destination: false)
  let system = try #require(
    Universe.galaxy().first {
      AsteroidBeltDefinition.isPresent(system: $0, galaxy: 0, policy: .legacyUniform)
    })
  let identity = SystemIdentity(galaxy: 0, system: system.id)
  var flight = FlightSimulationState()
  flight.enter(identity, arriving: false)
  let anchors = try #require(flight.anchors)
  let rock = try #require(
    MiningFields.legacyFields(anchors: anchors, seed: AsteroidBeltDefinition.seed(for: system))
      .flatMap(\.rocks).first)
  let incident = CombatIncident(
    id: 1, physicalTime: 1,
    origin: .init(
      emissionID: 1, owner: .init(system: identity, visit: 1, entity: 0), emittedAt: 1,
      ownerLegalAtEmission: .init()),
    victim: nil, kind: .laser, outcome: .hit, position: rock.position,
    victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil,
    victimIsStation: false, laser: .mining, mount: .front)
  var legacy = MiningLedger.legacyUnworked()
  let hit = legacy.hit(rock: rock, incident: incident, damage: 1)
  try #require(hit != .ignored)
  historical.commander.miningLedger = legacy
  try historical.commander.prepareEquipment()
  historical.ensureScriptCalendar(origin: .inactiveLegacyMigration)
  try ScriptSaveStore.write(
    commander: historical.commander, world: historical.scriptWorldSave, to: fixture.url)
  let oldBytes = try Data(contentsOf: fixture.url)
  try #require(JSONDecoder().decode(ScriptSavePointer.self, from: oldBytes).schemaVersion == 25)
  let runtime = GameRuntime(game: try fixture.game(accepted: false, destination: false))
  try await runtime.load(from: fixture.url, persistMigrations: false)
  let loaded = await runtime.snapshot()
  let retained = loaded.commander.miningLedger
  try #require(retained.retainsLegacyFields && retained.usesEconomyWeightedPresence)
  #expect(retained.remainingEnergy(for: rock) == legacy.remainingEnergy(for: rock))
  #expect(try Data(contentsOf: fixture.url) == oldBytes)
  await runtime.key("contacts-open")
  await runtime.key("return")
  let accepted = await runtime.snapshot()
  #expect(
    accepted.commander.scriptState.instances.count == 1 && accepted.commander.cargoTonnes == 1)
  #expect(accepted.commander.miningLedger == retained && accepted.commander.valid)
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.url))
  #expect(pointer.schemaVersion == 26)
  let reader = GameRuntime(game: try fixture.game(accepted: false, destination: false))
  try await reader.load(from: fixture.url, persistMigrations: false)
  let restored = await reader.snapshot()
  #expect(restored.commander == accepted.commander && restored.commander.miningLedger == retained)
}

@Test func failedCabinPurchaseDoesNotPublishOwnedModuleOrDebit() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  var game = try fixture.game(accepted: false, destination: false)
  game.commander.credits = 1_000_000
  let runtime = GameRuntime(game: game, saveURL: fixture.url)
  try await runtime.save(to: fixture.url)
  let quote = await runtime.passengerBerthQuote()
  let before = await runtime.snapshot()
  try fixture.breakWriter()
  await #expect(throws: (any Error).self) { try await runtime.confirmPassengerBerth(quote) }
  #expect(await runtime.snapshot().commander == before.commander)
  try fixture.restoreWriter()
  try await runtime.confirmPassengerBerth(quote)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.url), from: fixture.url)
  #expect(
    saved.accommodation.ownedBerths.count == 1 && saved.credits == 1_000_000 - PassengerCabin.price)
}
private func actualGameOverRuntime(_ fixture: DurableFixture) async throws -> GameRuntime {
  var game = try fixture.game(destination: false)
  game.launch()
  let delta = 0.001
  let recharge = game.commander.performance.recharge * game.commander.energyRechargeMultiplier
  try #require(recharge.isFinite && recharge >= 0 && recharge * delta < 1)
  // Actual shield/hull damage leaves a finite deficit larger than this positive tick's recharge.
  game.applyDamage(game.frontShield + game.energy + 1, front: true)
  try #require(game.energy == -1)
  game.speed = 0
  game.bodies = []
  game.celestials = []
  let runtime = GameRuntime(game: game, saveURL: fixture.url)
  let dead = await runtime.advance(delta: delta)
  try #require(dead.screen == .gameOver && dead.requiresScriptDurability)
  try await runtime.save(to: fixture.url)
  return runtime
}

extension GameRuntime {
  fileprivate func resetTestControls() -> [Double] {
    [
      controls.pitch, controls.roll, controls.yaw, controls.throttle,
      controls.fire ? 1 : 0, Double(controls.spinContacts), controls.spinRecognition,
      controls.spinSlower ? 1 : 0, controls.spinFaster ? 1 : 0,
    ]
  }
}

/// A fresh main berth retains its own source resource while every old mission fact stays absent.
private func freshNativeResetScriptState(owner: UUID)
  -> (ScriptEngineState, NativeMainStationIdentity)
{
  let system = SystemIdentity(galaxy: 0, system: 7)
  let resourceID = Game.worldResourceIdentity("main-station-v1:main-orbital:0:7")
  let station = NativeMainStationIdentity(world: owner, system: system, resource: resourceID)
  var resource = ScriptStationResource(identity: resourceID, galaxy: 0, system: 7)
  resource.energy = Hull.station.navalEnergy ?? 100
  var expected = ScriptEngineState()
  expected.calendarLedger = .init(origin: .newCommander)
  expected.stationResources[station.key] = resource
  return (expected, station)
}

@Test func gameOverReturnReplacesBoundDurableSaveWithClearedNativeCommander() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  let runtime = try await actualGameOverRuntime(fixture)
  let priorBytes = try Data(contentsOf: fixture.url)
  let prior = try JSONDecoder().decode(ScriptSavePointer.self, from: priorBytes)
  #expect(prior.format == "elite-script-save")
  let beforeReset = await runtime.snapshot()
  await runtime.key("return")
  let reset = await runtime.snapshot()
  let freshOwner = try #require(reset.commander.equipmentOwnerID)
  let (expected, expectedMain) = freshNativeResetScriptState(owner: freshOwner)
  #expect(reset.commander.nativeStations?.mainStations == [expectedMain])
  #expect(reset.screen == .status && reset.docked && reset.requiresScriptDurability)
  #expect(reset.commander.scriptState == expected)
  #expect(reset.commander.scriptState.calendarLedger == expected.calendarLedger)
  #expect(reset.commander.name == "Rowan Calder" && reset.commander.credits == 7200)
  #expect(reset.commander.shipID == "SH025" && reset.commander.fuel == 130)
  #expect(reset.commander.galaxy == 0 && reset.commander.system == 7)
  #expect(reset.commander.cargo.allSatisfy { $0 == 0 })
  #expect(reset.commander.equipmentOwnerID != beforeReset.commander.equipmentOwnerID)
  #expect(reset.commander.valid)
  let bytes = try Data(contentsOf: fixture.url)
  #expect(bytes != priorBytes)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.format == "elite-script-save" && pointer.schemaVersion == 26)
  #expect(pointer.scope == "commander" && pointer.generation != prior.generation)
  let (saved, _) = try ScriptSaveStore.read(bytes, from: fixture.url)
  #expect(saved == reset.commander)
  #expect(saved.scriptState.instances.isEmpty && saved.scriptState == expected)
  let restored = GameRuntime()
  try await restored.load(from: fixture.url)
  let loaded = await restored.snapshot()
  #expect(loaded.commander == saved && loaded.requiresScriptDurability)
}

@Test func failedGameOverResetRestoresNativeStateControlsAndOriginalSaveBytes() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  let runtime = try await actualGameOverRuntime(fixture)
  var controls = Controls()
  controls.pitch = 0.3
  controls.yaw = -0.2
  controls.fire = true
  await runtime.setControls(controls)
  let before = await runtime.snapshot()
  let held = await runtime.resetTestControls()
  let priorBytes = try Data(contentsOf: fixture.url)
  let priorPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: priorBytes)
  // Persisted commanders omit transient NPC bindings retained by the live rollback snapshot.
  let (priorSaved, _) = try ScriptSaveStore.read(priorBytes, from: fixture.url)
  try fixture.breakWriter()
  await runtime.key("return")
  let denied = await runtime.snapshot()
  let deniedControls = await runtime.resetTestControls()
  #expect(denied.commander == before.commander && denied.screen == before.screen)
  #expect(denied.bodies == before.bodies && denied.celestials == before.celestials)
  #expect(denied.docked == before.docked && denied.paused == before.paused)
  #expect(denied.energy == before.energy && denied.frontShield == before.frontShield)
  #expect(denied.rearShield == before.rearShield && denied.spin == before.spin)
  #expect(denied.scriptReferenceFrame == before.scriptReferenceFrame)
  #expect(denied.inventoryContextEpoch == before.inventoryContextEpoch)
  #expect(denied.requiresScriptDurability && deniedControls == held)
  #expect(denied.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
  try fixture.restoreWriter()
  let unchangedBytes = try Data(contentsOf: fixture.url)
  #expect(unchangedBytes == priorBytes)
  let (saved, _) = try ScriptSaveStore.read(unchangedBytes, from: fixture.url)
  #expect(saved == priorSaved)
  await runtime.key("return")
  let reset = await runtime.snapshot()
  let resetControls = await runtime.resetTestControls()
  #expect(resetControls.allSatisfy { $0 == 0 })
  let retriedBytes = try Data(contentsOf: fixture.url)
  #expect(retriedBytes != priorBytes)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: retriedBytes)
  #expect(pointer.format == "elite-script-save" && pointer.schemaVersion == 26)
  #expect(pointer.scope == "commander" && pointer.generation != priorPointer.generation)
  let (retried, _) = try ScriptSaveStore.read(retriedBytes, from: fixture.url)
  let freshOwner = try #require(reset.commander.equipmentOwnerID)
  let (expected, expectedMain) = freshNativeResetScriptState(owner: freshOwner)
  #expect(reset.commander.nativeStations?.mainStations == [expectedMain])
  #expect(reset.screen == .status && reset.docked && reset.requiresScriptDurability)
  #expect(retried == reset.commander && retried.valid && retried.scriptState == expected)
  #expect(
    retried.scriptState.instances.isEmpty
      && retried.scriptState.calendarLedger == expected.calendarLedger)
  #expect(retried.name == "Rowan Calder" && retried.credits == 7200)
  #expect(retried.shipID == "SH025" && retried.fuel == 130)
  #expect(retried.galaxy == 0 && retried.system == 7)
  #expect(retried.cargo.allSatisfy { $0 == 0 })
  #expect(retried.equipmentOwnerID != before.commander.equipmentOwnerID)
  let restored = GameRuntime()
  try await restored.load(from: fixture.url)
  let loaded = await restored.snapshot()
  #expect(loaded.commander == retried && loaded.requiresScriptDurability)
}

private let durableTimers = """
  return {
   accepted=function(e,w,d) return {data=d,commands={
    {op='timer.ensure',id='a',domain='local',after=0.05,interval=0,policy='once'},
    {op='timer.ensure',id='b',domain='local',after=0.05,interval=0,policy='once'}}} end,
   contact=function(e,w,d) return {data=d,commands={}} end,
   confirm=function(e,w,d) return {data=d,commands={}} end,
   timer=function(e,w,d)
    if e.timer_id=='a' then return {data=d,commands={
     {op='credits',id='first-pay',amount=25},{op='timer.cancel',id='b'}}} end
    return {data=d,commands={{op='credits',id='wrong-pay',amount=5000}}} end
  }
  """
private func timerFixture() throws -> DurableFixture {
  try DurableFixture(
    source: durableTimers,
    edits: [
      ("\"cargo-v2\"]", "\"cargo-v2\", \"local-flight-clocks-v2\"]"),
      ("[[dialogs]]", "[[handlers]]\nevent = 'timer.fired'\nfunction = 'timer'\n\n[[dialogs]]"),
    ])
}
@Test func durableTimerCallbackCancelsAnotherDueCallbackBeforeItCanFireOrReplay() async throws {
  let fixture = try timerFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: try fixture.cashGame(), saveURL: fixture.url)
  _ = await runtime.advance(delta: 0.05)
  let before = await runtime.snapshot()
  #expect(before.commander.credits == 1025)
  let id = try #require(before.commander.scriptState.instances.keys.first)
  #expect(before.commander.scriptState.instances[id]?.timers.isEmpty == true)
  let restored = GameRuntime(game: try fixture.cashGame(accepted: false))
  try await restored.load(from: fixture.url)
  _ = await restored.advance(delta: 0.1)
  #expect(await restored.snapshot().commander.credits == 1025)
}
@Test func failedTimerSaveRetainsNativePulseAndFreezesLaterCallbackUntilRecovery() async throws {
  let fixture = try timerFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: try fixture.cashGame(), saveURL: fixture.url)
  try await runtime.save(to: fixture.url)
  try fixture.breakWriter()
  let denied = await runtime.advance(delta: 0.05)
  let id = try #require(denied.commander.scriptState.instances.keys.first)
  let state = try #require(denied.commander.scriptState.instances[id])
  #expect(denied.commander.credits == 1000 && state.suspension != nil)
  #expect(state.timers["a"] == nil && state.timers["b"] != nil)
  #expect(
    denied.commander.scriptState.pendingEvents.contains {
      $0.kind == "timer.fired" && $0.values["timer_id"] == .string("a")
    })
  try fixture.restoreWriter()
  try await runtime.resumeScriptMission(id)
  _ = await runtime.advance(delta: 0.1)
  #expect(await runtime.snapshot().commander.credits == 1025)
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.timers.isEmpty == true)
}
@Test func physicalLaserDeathSurvivesFailedScriptPublicationAndPaysOnceAfterRecovery() async throws
{
  let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/scripted-patrol/scripts/main.lua")
  var source = try String(contentsOf: original, encoding: .utf8)
  let start = try #require(source.range(of: "function M.destroyed"))
  let end = try #require(source.range(of: "function M.contact"))
  source.replaceSubrange(
    start.lowerBound..<end.lowerBound,
    with:
      "function M.destroyed(e,w,d) return {data=d,commands={{op='credits',id='kill-pay',amount=500}}} end\n"
  )
  let fixture = try DurableFixture(example: "scripted-patrol", source: source)
  defer { fixture.clean() }
  var game = try fixture.cashGame(destination: false)
  try fitPhysicalDeathTargeting(&game)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let id = try #require(game.commander.scriptState.instances.keys.first)
  let bounty = try #require(game.bodies.first { $0.missionInstanceID == id }).hull.navalBounty ?? 50
  let runtime = GameRuntime(game: game, saveURL: fixture.url)
  try await runtime.save(to: fixture.url)
  try fixture.breakWriter()
  var controls = Controls()
  var current = await runtime.snapshot()
  let legalBefore = current.commander.legal
  try #require(legalBefore == 0)
  for _ in 0..<200 {
    controls = Controls()
    if try campaignPatrolOutsideStationZone(current) {
      try await selectCampaignPatrolTarget(runtime, child: id)
      current = await runtime.snapshot()
      controls.fire = try campaignPatrolHasActualLaserContact(current, child: id)
    }
    await runtime.setControls(controls)
    current = await runtime.advance(delta: 0.1)
    if current.commander.kills > 0 { break }
  }
  #expect(
    current.commander.kills > 0,
    Comment(rawValue: campaignPatrolDiagnostic(current, child: id)))
  #expect(current.commander.legal == legalBefore)
  #expect(current.commander.credits == 1000 + current.commander.kills * bounty)
  let state = try #require(current.commander.scriptState.instances[id])
  #expect(state.suspension != nil && !state.receipts.contains("kill-pay"))
  let dead =
    state.ownedEncounters["raiders"]?.actors.values.filter { $0.presence == .destroyed }.map(
      \.identity) ?? []
  #expect(
    !dead.isEmpty && current.bodies.allSatisfy { !dead.contains($0.missionActorID ?? UUID()) })
  await runtime.setControls(Controls())
  try fixture.restoreWriter()
  try await runtime.resumeScriptMission(id)
  let recovered = await runtime.snapshot()
  #expect(recovered.commander.credits == current.commander.credits + 500)
  #expect(recovered.commander.kills == current.commander.kills)
  let restored = GameRuntime(game: game)
  try await restored.load(from: fixture.url)
  #expect(await restored.snapshot().commander.credits == recovered.commander.credits)
}

private func fitPhysicalDeathTargeting(_ game: inout Game) throws {
  let before = game.commander
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .grant("death-pilot"))
  try #require(game.commander.hasAutomaticDocking)
  #expect(
    game.commander.fittedEquipment(at: .targetingCore)?.node.key
      == TargetingTier.docking.equipmentName)
  #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
  #expect(game.commander.fuel == before.fuel && game.commander.missiles == before.missiles)
  #expect(
    game.commander.scriptState == before.scriptState && game.commander.contracts == before.contracts
  )
  #expect(game.commander.accommodation == before.accommodation)
  #expect(game.commander.laser(on: .front) == before.laser(on: .front))
  #expect(
    game.commander.laserDamage(against: .sidewinder, mount: .front)
      == before.laserDamage(against: .sidewinder, mount: .front))
}

@Test func initialAcceptanceDiskFailureCreatesNoInstancePayloadOrLostOffer() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  try Data("blocked directory".utf8).write(to: fixture.container)
  let runtime = GameRuntime(
    game: try fixture.game(accepted: false, destination: false), saveURL: fixture.url)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot()
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.commander.scriptState.instances.isEmpty)
  #expect(
    denied.scriptAvailablePackDigest == before.scriptAvailablePackDigest
      && denied.screen == .handoff)
  try FileManager.default.removeItem(at: fixture.container)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.scriptState.instances.count == 1)
  #expect(await runtime.snapshot().commander.cargoTonnes == 1)
}
@Test func admissionAndItsNativeResultAreInTheSamePublishedGeneration() throws {
  let fixture = try DurableFixture(example: "scripted-patrol")
  defer { fixture.clean() }
  var game = try fixture.game(destination: false)
  game.launch()
  game.emitScriptEvent("station.undocked", drain: false)
  let url = fixture.url
  game.drainScriptEvents(publish: { candidate in
    try ScriptSaveStore.write(
      commander: candidate.commander, world: candidate.scriptWorldSave, to: url)
  })
  let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: fixture.url), from: fixture.url)
  #expect(world.bodies.filter { $0.missionActorID != nil }.count == 2)
  #expect(saved.scriptState.pendingEvents.contains { $0.kind == "encounter.admitted" })
  #expect(saved.scriptState.instances.values.first?.ownedEncounters["raiders"]?.admitted == true)
  #expect(saved.scriptState.instances.values.first?.data["phase"] == .string("launch"))
}
@Test func explicitSaveFailureDoesNotPublishPendingHandlerStateOrLoseItsNativeResult() async throws
{
  let fixture = try DurableFixture(example: "scripted-patrol")
  defer { fixture.clean() }
  var game = try fixture.game(destination: false)
  game.launch()
  game.emitScriptEvent("station.undocked", drain: false)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.pendingEvents.contains { $0.kind == "encounter.admitted" })
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  try Data("blocked directory".utf8).write(to: fixture.container)
  let runtime = GameRuntime(game: game)
  #expect(await runtime.snapshot().commander == game.commander)
  await #expect(throws: (any Error).self) { try await runtime.save(to: fixture.url) }
  #expect(await runtime.snapshot().commander == game.commander)
  #expect(await runtime.snapshot().bodies == game.bodies)
  try FileManager.default.removeItem(at: fixture.container)
  try await runtime.save(to: fixture.url)
  let (pending, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.url), from: fixture.url)
  #expect(pending.scriptState.pendingEvents.contains { $0.kind == "encounter.admitted" })
  #expect(pending.scriptState.instances.values.first?.data["phase"] == .string("launch"))
  // Saving binds the writer; a real runtime turn publishes the pending native result handler.
  _ = await runtime.advance(delta: 0.1)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.url), from: fixture.url)
  #expect(saved.scriptState.instances.values.first?.data["phase"] == .string("battle"))
}

@Test func exhaustedResultQueueCannotPublishHalfAnEncounter() throws {
  let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/scripted-patrol/scripts/main.lua")
  var source = try String(contentsOf: original, encoding: .utf8)
  let start = try #require(source.range(of: "function M.undocked"))
  let end = try #require(source.range(of: "function M.admitted"))
  source.replaceSubrange(
    start.lowerBound..<end.lowerBound,
    with:
      "function M.undocked(e,w,d) return {data=d,commands={{op='encounter.ensure',id='raiders'},{op='encounter.ensure',id='raiders'},{op='encounter.ensure',id='raiders'}}} end\n"
  )
  let fixture = try DurableFixture(example: "scripted-patrol", source: source)
  defer { fixture.clean() }
  var game = try fixture.game(destination: false)
  game.launch()
  let bodies = game.bodies
  game.emitScriptEvent("station.undocked", drain: false)
  for _ in 0..<4095 { game.emitScriptEvent("contact.requested", drain: false) }
  let url = fixture.url
  game.drainScriptEvents(publish: { candidate in
    try ScriptSaveStore.write(
      commander: candidate.commander, world: candidate.scriptWorldSave, to: url)
  })
  #expect(
    game.bodies == bodies
      && game.commander.scriptState.instances.values.first?.ownedEncounters.isEmpty == true)
  #expect(
    game.commander.scriptState.instances.values.first?.suspension?.contains("result queue") == true)
  let (saved, world) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
  #expect(
    world.bodies == bodies
      && saved.scriptState.instances.values.first?.ownedEncounters.isEmpty == true)
}

@Test func durableCapabilityRequiresBoundWriterAndTrialUsesOnlyItsOwnWriter() async throws {
  let fixture = try DurableFixture(edits: [
    ("\"cargo-v2\"]", "\"cargo-v2\", \"durable-commands-v2\"]")
  ])
  defer { fixture.clean() }
  let game = try fixture.game(accepted: false, destination: false)
  let memory = GameRuntime(game: game)
  #expect(await memory.snapshot().scriptGallery.first?.status == .locked)
  let configured = GameRuntime(game: game, saveURL: fixture.url)
  #expect(await configured.snapshot().scriptGallery.first?.status == .available)
  let trial = try await memory.scriptGalleryTrial(packDigest: fixture.pack.digest, seed: 42)
  let namespace = try #require(await trial.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let trialFile = namespace.appendingPathComponent("commander.json")
  #expect(FileManager.default.fileExists(atPath: trialFile.path))
  #expect(!FileManager.default.fileExists(atPath: fixture.url.path))
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: trialFile), from: trialFile)
  #expect(saved.scriptState.instances.values.first?.randomState == 42)
  #expect(await memory.snapshot().commander.scriptState.instances.isEmpty)
  try await memory.save(to: fixture.url)
  #expect(await memory.snapshot().scriptGallery.first?.status == .available)
}

@Test func legacyVirtualPassengerFlagMigratesWithoutInventingOrDroppingOwnedCabins() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  var game = try fixture.game(accepted: false, destination: false)
  game.commander.credits = 1_000_000
  try game.confirmPassengerBerth(game.passengerBerthQuote)
  let owned = game.commander.accommodation
  var legacy = game.commander
  legacy.equipment.insert(PassengerCabin.equipmentName)
  try #require(legacy.equipmentInventory == nil && legacy.savedEquipmentVersion == nil)
  try #require(!legacy.usesModularDriveSaveVersion && !legacy.usesRingMiningSaveVersion)
  try #require(!legacy.usesEconomyMiningSaveVersion && !legacy.usesEMPSaveVersion)
  let originalWorld = game.scriptWorldSave
  let file = fixture.root.appendingPathComponent("legacy.json")
  let bytes = try JSONEncoder().encode(legacy)
  try bytes.write(to: file)
  let runtime = GameRuntime()
  try await runtime.load(from: file, persistMigrations: false)
  let restored = await runtime.snapshot()
  #expect(restored.commander.valid && restored.commander.accommodation == owned)
  #expect(!restored.commander.equipment.contains(PassengerCabin.equipmentName))
  #expect(try Data(contentsOf: file) == bytes)
  // Construct the prototype's three complete untyped chunks from the untouched original.
  let oldGeneration = UUID().uuidString
  let oldDirectory = fixture.url.appendingPathExtension("missions").appendingPathComponent(
    oldGeneration)
  try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
  var header = legacy
  header.scriptState = ScriptEngineState()
  try #require(legacy.contracts.boards.isEmpty && legacy.contracts.rrs == nil)
  let encoder = JSONEncoder()
  let chunks = [
    "commander.json": try encoder.encode(header),
    "missions.json": try encoder.encode(legacy.scriptState),
    "world.json": try encoder.encode(originalWorld),
  ]
  for (name, chunk) in chunks { try chunk.write(to: oldDirectory.appendingPathComponent(name)) }
  let old = ScriptSavePointer(
    format: "elite-script-save", schemaVersion: 4, generation: oldGeneration,
    hashes: chunks.mapValues(ScriptPackLibrary.hash))
  let pointerBytes = try encoder.encode(old)
  try pointerBytes.write(to: fixture.url)
  #expect(
    Set(try FileManager.default.contentsOfDirectory(atPath: oldDirectory.path)) == Set(chunks.keys))
  let (oldCommander, oldWorld) = try ScriptSaveStore.read(pointerBytes, from: fixture.url)
  #expect(oldCommander.accommodation == owned && oldCommander.valid)
  #expect(!oldCommander.equipment.contains(PassengerCabin.equipmentName))
  #expect(oldWorld.valid && oldWorld.consistent(with: oldCommander))
  try await runtime.load(from: fixture.url, persistMigrations: false)
  #expect(await runtime.snapshot().commander.accommodation == owned)
  #expect(await runtime.snapshot().commander.valid)
  #expect(!(await runtime.snapshot().commander.equipment.contains(PassengerCabin.equipmentName)))
  #expect(try Data(contentsOf: fixture.url) == pointerBytes)
  #expect(try Data(contentsOf: file) == bytes)
  for (name, chunk) in chunks {
    #expect(try Data(contentsOf: oldDirectory.appendingPathComponent(name)) == chunk)
  }
}

@Test func galleryCannotLoadProductionThroughALinkedGeneration() async throws {
  let fixture = try DurableFixture()
  defer { fixture.clean() }
  var production = try fixture.game()
  production.commander.name = "PRIVATE"
  let live = GameRuntime(game: production)
  try await live.save(to: fixture.url)
  let trial = try await live.scriptGalleryTrial(packDigest: fixture.pack.digest)
  let namespace = try #require(await trial.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let before = await trial.snapshot().commander
  let bytes = try Data(contentsOf: fixture.url)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  let copied = namespace.appendingPathComponent("copied.json")
  var copiedPointer = pointer
  copiedPointer.scope = "gallery"
  try JSONEncoder().encode(copiedPointer).write(to: copied)
  let sidecar = copied.appendingPathExtension("missions")
  try FileManager.default.createDirectory(at: sidecar, withIntermediateDirectories: true)
  let link = sidecar.appendingPathComponent(pointer.generation)
  let productionGeneration = try ScriptSaveStore.generationDirectory(
    pointer.generation, from: fixture.url)
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: productionGeneration)
  await #expect(throws: MissionPackError.self) { try await trial.load(from: copied) }
  #expect(await trial.snapshot().commander == before)
  #expect(try Data(contentsOf: fixture.url) == bytes)
}
