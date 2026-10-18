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

extension GameRuntime {
  fileprivate func procurementMissileControlsForTest() -> Controls { controls }
}
