import Foundation
import Testing

@testable import L337Core

private func reactivePilotPolicyFacts() -> ScriptProcurementPreflightFacts {
  // Pure policy inputs; no Game, hit/origin factory or weapon consumer accepts this fixture.
  let player = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 0)
  var facts = ScriptProcurementPreflightFacts()
  facts.identity = .init(
    player: player, epoch: UUID(), stationEpoch: UUID(), owner: UUID(), revision: 1,
    physicalTime: 0.1)
  facts.valid = true
  facts.live = true
  facts.automaticEngaged = true
  facts.mainTargetCurrent = true
  facts.combatLaser = true
  facts.frontLaser = true
  facts.outsideNoFireZones = true
  facts.exactForwardHit = true
  return facts
}

@Test(arguments: ["clear", "threat", "incoming", "invalid", "paused", "dead", "budget", "acquire"])
func reactivePilotChecksRawThreatDuringAUTOAndKeepsDefaultUnattended(condition: String) {
  var facts = reactivePilotPolicyFacts()
  let player = facts.identity!.player
  var steps = 0
  var expected = ScriptProcurementDockAction.automatic
  switch condition {
  case "threat":
    facts.threat = .init(
      identity: .init(system: player.system, visit: player.visit, entity: 2),
      position: .init(0, 0, 500), wanted: true)
    expected = .react
  case "incoming":
    facts.incoming = true
    expected = .react
  case "invalid":
    facts.valid = false
    expected = .refuse
  case "paused":
    facts.paused = true
    expected = .refuse
  case "dead":
    facts.live = false
    expected = .refuse
  case "budget":
    steps = 3000
    expected = .refuse
  case "acquire":
    facts.mainTargetCurrent = false
    expected = .acquire
  default: break
  }
  let action = facts.requestedDockAction(defensive: true, steps: steps)
  #expect(action == expected)
  if expected == .react {
    let unattended = facts.requestedDockAction(defensive: false, steps: steps)
    let manualBeforeCancel = facts.requestedAction(steps: steps)
    #expect(unattended == .automatic && manualBeforeCancel == .refuse)
  }
}

@Test(arguments: [
  "same", "player", "epoch", "station-epoch", "owner", "revision", "time", "threat", "zone", "hit",
  "tool",
])
func reactivePilotAtUseRequiresExactCurrentIdentityAndFacts(condition: String) {
  let current = reactivePilotPolicyFacts()
  let old = current.identity!
  var expected = current
  switch condition {
  case "player":
    expected.identity = .init(
      player: .init(system: old.player.system, visit: old.player.visit + 1, entity: 0),
      epoch: old.epoch, stationEpoch: old.stationEpoch, owner: old.owner,
      revision: old.revision, physicalTime: old.physicalTime)
  case "epoch", "station-epoch", "owner", "revision", "time":
    expected.identity = .init(
      player: old.player, epoch: condition == "epoch" ? UUID() : old.epoch,
      stationEpoch: condition == "station-epoch" ? UUID() : old.stationEpoch,
      owner: condition == "owner" ? UUID() : old.owner,
      revision: old.revision + (condition == "revision" ? 1 : 0),
      physicalTime: old.physicalTime + (condition == "time" ? 0.1 : 0))
  case "threat": expected.incoming = true
  case "zone": expected.outsideNoFireZones = false
  case "hit": expected.exactForwardHit = false
  case "tool": expected.combatLaser = false
  default: break
  }
  let same = current.rejoins(expected)
  #expect(same == (condition == "same"))
}

@Test func reactivePilotSharesAllInputAndAdvanceBudgetsAcrossReactionCycles() {
  var budget = ScriptProcurementPilotBudget()
  // Repeated cycles cannot recreate a local allowance for keys or real advances.
  for cycle in 0..<4 {
    let tool = budget.reserveTool()
    #expect(tool)
    for _ in 0..<8 {
      let tab = budget.reserveTab()
      #expect(tab)
    }
    for _ in 0..<750 {
      let advanced = budget.recordAdvance(automatic: cycle % 2 == 0)
      #expect(advanced)
    }
  }
  #expect(budget.steps == 3000 && budget.tabs == 32 && budget.tools == 4)
  #expect(budget.automaticAdvances == 1500)
  let exhausted = budget
  let tab = budget.reserveTab()
  let tool = budget.reserveTool()
  let advance = budget.recordAdvance(automatic: true)
  #expect(!tab && !tool && !advance)
  #expect(
    budget.steps == exhausted.steps && budget.tabs == exhausted.tabs
      && budget.tools == exhausted.tools && budget.automaticAdvances == exhausted.automaticAdvances)
}

@Test func reactivePilotInvalidNativeFactsRefuseWithoutControlsOrAdvance() async {
  let runtime = GameRuntime(game: Game(executive: false))
  var held = Controls()
  held.pitch = 0.5
  held.fire = true
  await runtime.setControls(held)
  let before = await runtime.snapshot()
  let controlsBefore = await runtime.controls
  let facts = await runtime.procurementPreflightFacts()
  let defensive = await runtime.procurementPilotStep(
    expected: facts, steps: 0, automatic: false, diagnostic: false)
  let automatic = await runtime.procurementPilotStep(
    expected: facts, steps: 0, automatic: true, diagnostic: false)
  let cancelled = await runtime.procurementCancelForThreat(expected: facts, steps: 0)
  let after = await runtime.snapshot()
  let controlsAfter = await runtime.controls
  #expect(controlsAfter.pitch == controlsBefore.pitch && controlsAfter.fire == controlsBefore.fire)
  #expect(controlsAfter.yaw == controlsBefore.yaw && controlsAfter.roll == controlsBefore.roll)
  #expect(controlsAfter.throttle == controlsBefore.throttle)
  #expect(defensive.status == .refused && automatic.status == .refused && !cancelled)
  #expect(defensive.before == nil && defensive.after == nil)
  #expect(automatic.before == nil && automatic.after == nil)
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.time == before.time && after.gameplayRevision == before.gameplayRevision)
  #expect(after.energy == before.energy && after.nextBodyID == before.nextBodyID)
}
