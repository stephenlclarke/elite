import Foundation
import Testing

@testable import EliteCore

@Test(arguments: [
  "allowed", "heat", "not-pulse", "cooldown", "empty", "unlimited", "own-missile",
  "unjoined", "clean", "zone", "obstructed", "tool", "rear", "paused", "automatic", "budget",
])
func procurementMissilePolicyCannotGrantNativeLaunchAuthority(condition: String) {
  // Descriptive policy only; no native consumer accepts these constructed values.
  let player = ActorIdentity(system: .init(galaxy: 0, system: 0), visit: 1, entity: 1)
  let target = ActorIdentity(system: player.system, visit: 1, entity: 2)
  var facts = ScriptProcurementPreflightFacts()
  facts.identity = .init(
    player: player, epoch: UUID(), stationEpoch: UUID(), owner: UUID(), revision: 1,
    physicalTime: 1)
  facts.valid = true
  facts.live = true
  facts.threat = .init(identity: target, position: .init(0, 0, 500), wanted: true)
  facts.outsideNoFireZones = true
  facts.exactForwardHit = true
  facts.combatLaser = true
  facts.frontLaser = true
  var heat = 246.4
  var pulse = true
  var cooldown = 0.0
  var rounds = 3
  var unlimited = false
  var ownMissile = false
  var steps = 0
  switch condition {
  case "heat": heat = 240
  case "not-pulse": pulse = false
  case "cooldown": cooldown = 0.1
  case "empty": rounds = 0
  case "unlimited": unlimited = true
  case "own-missile": ownMissile = true
  case "unjoined": facts.identity = nil
  case "clean": facts.threat = .init(identity: target, position: .init(0, 0, 500), wanted: false)
  case "zone": facts.outsideNoFireZones = false
  case "obstructed": facts.exactForwardHit = false
  case "tool": facts.combatLaser = false
  case "rear": facts.frontLaser = false
  case "paused": facts.paused = true
  case "automatic": facts.automaticEngaged = true
  case "budget": steps = 3000
  default: break
  }
  let requested = ScriptProcurementMissilePolicy.requestsFallback(
    facts, steps: steps, pulse: pulse, heat: heat, cooldown: cooldown,
    rounds: rounds, unlimited: unlimited, ownMissile: ownMissile)
  #expect(requested == (condition == "allowed"))
}

@Test func procurementMissileAttemptsKeepThreeOriginalIDsAndNeverRetryARefusal() {
  let originals = Set((0..<3).map { _ in UUID() })
  let ordered = originals.sorted { $0.uuidString < $1.uuidString }
  var budget = ScriptProcurementPilotBudget()
  let initial = budget.missileDefence
  let invented = budget.missileDefence.reserve(UUID(), originals: originals)
  #expect(!invented && budget.missileDefence == initial)
  for round in ordered {
    let admitted = budget.missileDefence.reserve(round, originals: originals)
    #expect(admitted)
    let before = budget.missileDefence
    let repeated = budget.missileDefence.reserve(round, originals: originals)
    #expect(!repeated && budget.missileDefence == before)
  }
  let fourth = budget.missileDefence.reserve(UUID(), originals: originals)
  #expect(!fourth && budget.missileDefence.attempted == originals)
  #expect(budget.steps == 0 && budget.tabs == 0 && budget.tools == 0)
}

@Test func procurementMissileStaleActorRequestPreservesActualRuntimeAndBudget() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let before = await runtime.snapshot()
  let budget = ScriptProcurementPilotBudget()
  await #expect(throws: ScriptProcurementMissileRefusal.stale) {
    _ = try await runtime.procurementMissileFallback(
      expected: .init(), budget: budget)
  }
  let after = await runtime.snapshot()
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.energy == before.energy && after.frontShield == before.frontShield)
  #expect(
    after.rearShield == before.rearShield && after.gameplayRevision == before.gameplayRevision)
  #expect(after.nextBodyID == before.nextBodyID)
  #expect(
    after.missileArmed == before.missileArmed && after.weaponsTargetID == before.weaponsTargetID)
  #expect(budget.steps == 0 && budget.tabs == 0 && budget.missileDefence.attempted.isEmpty)
  #expect(!FileManager.default.fileExists(atPath: fixture.save.path))
}

@Test func procurementMissileClearSceneLeavesTheOrdinaryPilotInputsUntouched() async throws {
  let game = try empFixture()
  let runtime = GameRuntime(game: game)
  var input = Controls()
  input.pitch = 0.25
  input.yaw = -0.25
  input.throttle = 0.5
  input.fire = true
  await runtime.setControls(input)
  let before = await runtime.snapshot()
  let facts = await runtime.procurementPreflightFacts()
  try #require(facts.identity != nil && facts.threat == nil && !facts.incoming)
  let budget = try await runtime.procurementMissileFallback(
    expected: facts, budget: .init())
  let after = await runtime.snapshot()
  let afterInput = await runtime.procurementMissileControlsForTest()
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(
    after.missileArmed == before.missileArmed && after.weaponsTargetID == before.weaponsTargetID)
  #expect(after.energy == before.energy && after.gameplayRevision == before.gameplayRevision)
  #expect(after.nextBodyID == before.nextBodyID)
  #expect(budget.steps == 0 && budget.tabs == 0 && budget.tools == 0)
  #expect(budget.missileDefence.attempted.isEmpty)
  #expect(afterInput.pitch == input.pitch && afterInput.yaw == input.yaw)
  #expect(afterInput.roll == input.roll && afterInput.throttle == input.throttle)
  #expect(afterInput.fire == input.fire && afterInput.spinContacts == input.spinContacts)
  #expect(afterInput.spinRecognition == input.spinRecognition)
  #expect(afterInput.spinSlower == input.spinSlower && afterInput.spinFaster == input.spinFaster)
}

@Test func procurementMissileActiveNativeECMDefersWithoutSpendingOriginalStock() async throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.screen = .status
  game.commander.system = 0
  game.selectedSystem = 0
  game.market = MarketItem.at(game.currentSystem, fluctuation: 0)
  game.commander.credits = 100000
  try game.prepareG03FlightEquipment()
  try ScriptProcurementFixture.requirePaidG03Preparation(game)
  game.ensureMissionCalendar()
  game.launch()
  let station = try #require(game.commander.flightSimulation.anchors?.station)
  // A controlled unit boundary, not elapsed travel or an observed enemy ECM history.
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: station.position + .init(0, 0, -5000)))
  let bodyID = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: bodyID, hull: .cobra, position: .init(0, 0, 500), hostile: true))
  let emitterID = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: emitterID, hull: .constrictor, position: .init(0, 0, -1000)))
  game.ensurePhysicalActors()
  let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.cobra)?.id
  game.bodies[index].physical?.npc?.legal = .init(value: 16)
  let emitterIndex = try #require(game.bodies.firstIndex { $0.id == emitterID })
  game.bodies[emitterIndex].physical?.catalogueShipID = ShipCatalogue.nativeShip(.constrictor)?.id
  try #require(game.bodies[emitterIndex].ecmEnabled)
  game.laserHeat = 246.4
  game = try GameRuntime.prepareNativeSaveState(game).game
  StationDefenceRefusalObservation.enable(&game)
  let target = try #require(game.bodies.first { $0.id == bodyID }?.physical?.identity)
  let emitter = try #require(game.bodies.first { $0.id == emitterID }?.physical?.identity)
  // Independent value-copy control proves this boundary can actually launch with ECM inactive.
  let controlSave = fixture.root.appendingPathComponent("control/commander.json")
  let control = GameRuntime(game: game, saveURL: controlSave)
  let controlFacts = await control.procurementPreflightFacts()
  StationDefenceRefusalObservation.emit(
    game, phase: "procurement-control-before", facts: controlFacts)
  let controlBudget = try await control.procurementMissileFallback(
    expected: controlFacts, budget: .init())
  let launched = await control.snapshot()
  StationDefenceRefusalObservation.emit(
    launched, phase: "procurement-control-after", facts: controlFacts, budget: controlBudget)
  try #require(
    launched.commander.missiles == 2 && controlBudget.missileDefence.attempted.count == 1)
  try #require(FileManager.default.fileExists(atPath: controlSave.path))
  let activated = game.activateOrdnanceECM(emitter: emitter)
  try #require(activated)
  game.ecmFrames = 32  // The existing enemy field's native physical-time activation path.
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let before = await runtime.snapshot()
  let facts = await runtime.procurementPreflightFacts()
  StationDefenceRefusalObservation.emit(before, phase: "procurement-active-before", facts: facts)
  let otherwiseRequested = ScriptProcurementMissilePolicy.requestsFallback(
    facts, steps: 0, pulse: before.commander.laser(on: .front) == .pulse,
    heat: before.laserHeat, cooldown: before.missileCooldown, rounds: before.commander.missiles,
    unlimited: before.commander.unlimitedMissiles, ownMissile: false)
  try #require(otherwiseRequested && before.ecmControl.fieldActive && before.commander.valid)
  try #require(before.commander.missiles == 3 && facts.threat?.identity == target)
  let budget = try await runtime.procurementMissileFallback(expected: facts, budget: .init())
  let after = await runtime.snapshot()
  StationDefenceRefusalObservation.emit(
    after, phase: "procurement-active-after", facts: facts, budget: budget)
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.energy == before.energy && after.frontShield == before.frontShield)
  #expect(after.rearShield == before.rearShield && after.nextBodyID == before.nextBodyID)
  #expect(after.gameplayRevision == before.gameplayRevision)
  #expect(after.ecmControl.remainingDuration == before.ecmControl.remainingDuration)
  #expect(after.activeECMActivation == before.activeECMActivation)
  #expect(
    after.missileArmed == before.missileArmed && after.weaponsTargetID == before.weaponsTargetID)
  #expect(budget.steps == 0 && budget.tabs == 0 && budget.tools == 0)
  #expect(budget.missileDefence == ScriptProcurementMissileBudget())
  #expect(!FileManager.default.fileExists(atPath: fixture.save.path))
}

extension GameRuntime {
  fileprivate func procurementMissileControlsForTest() -> Controls { controls }
}
