import Foundation
import Testing

@testable import EliteCore

private func capacityTarget() throws -> (Game, UUID, SpaceBody) {
  var (game, instance, _) = try actualMissionBridgeGame()
  let actor = try #require(
    game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors["wing"])
  let index = try #require(game.bodies.firstIndex { $0.missionActorID == actor.identity })
  game.bodies[index].scriptNPC?.components["turret"]?.energy = 5
  return (game, instance, game.bodies[index])
}

private func fillActualEventQueue(_ game: inout Game, instance: UUID, to count: Int) throws {
  try #require(game.commander.scriptState.pendingEvents.count <= count)
  while game.commander.scriptState.pendingEvents.count < count {
    // Real declared contact facts exercise the actual queue emitter, not a shadow queue.
    game.emitScriptEvent("contact.requested", only: instance, drain: false)
  }
}

private func componentCapacityPlan(
  _ game: Game, target: SpaceBody, terminal: Bool = true, source: UUID? = nil
) throws -> ScriptMissionEventCapacityPlan {
  try game.planScriptMissionImpactEvents(
    target: target, damage: 6, damageAdmitted: true, victimPart: "turret",
    victimComponentID: target.scriptNPC?.components["turret"]?.identity,
    componentDestroyed: terminal, hullDestroyed: false, sourceWeaponInstanceID: source)
}

struct ScriptMissionEventCapacityTests {
  @Test func actualEmitterBoundaryFitsTargetFactsButRejectsAnAdditionalSourceFireWithoutMutation()
    throws
  {
    var (game, instance, target) = try capacityTarget()
    try fillActualEventQueue(&game, instance: instance, to: 4094)
    let before = game.commander
    let bodies = game.bodies
    let plan = try componentCapacityPlan(game, target: target)
    #expect(plan.requiredEvents == 2 && plan.pendingCount == 4094)
    #expect(plan.nextEvent == before.scriptState.nextEvent)
    #expect(throws: ScriptMissionEventCapacityError.insufficientCapacity) {
      try componentCapacityPlan(game, target: target, source: instance)
    }
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.commander.scriptState.instances[instance]?.suspension == nil)
  }

  @Test func sequenceBoundaryMatchesStrictEmitterIncrementAndCannotOverflow() throws {
    var (game, _, target) = try capacityTarget()
    let limit = UInt64(Int64.max) - 1
    game.commander.scriptState.nextEvent = limit - 1
    let before = game.commander
    let single = try componentCapacityPlan(game, target: target, terminal: false)
    #expect(single.requiredEvents == 1)
    #expect(throws: ScriptMissionEventCapacityError.insufficientCapacity) {
      try componentCapacityPlan(game, target: target)
    }
    #expect(game.commander == before)
    game.commander.scriptState.nextEvent = UInt64.max
    let overflowing = game.commander
    #expect(throws: ScriptMissionEventCapacityError.insufficientCapacity) {
      try componentCapacityPlan(game, target: target, terminal: false)
    }
    #expect(game.commander == overflowing)
  }

  @Test func terminalAccountingUsesActualRetainedAddressAndImmuneDamageAddsNoDamageFact() throws {
    let (game, instance, target) = try capacityTarget()
    let terminal = try game.planScriptMissionImpactEvents(
      target: target, damage: 6, damageAdmitted: true, victimPart: nil, victimComponentID: nil,
      componentDestroyed: false, hullDestroyed: true)
    #expect(terminal.requiredEvents == 2)
    var wrongAddress = target
    wrongAddress.id += 1000
    let unmatched = try game.planScriptMissionImpactEvents(
      target: wrongAddress, damage: 6, damageAdmitted: true, victimPart: nil,
      victimComponentID: nil,
      componentDestroyed: false, hullDestroyed: true)
    #expect(unmatched.requiredEvents == 1)
    let immune = try game.planScriptMissionImpactEvents(
      target: target, damage: 6, damageAdmitted: false, victimPart: "turret",
      victimComponentID: target.scriptNPC?.components["turret"]?.identity,
      componentDestroyed: true, hullDestroyed: false, sourceWeaponInstanceID: instance)
    #expect(immune.requiredEvents == 1)
  }

  @Test func inactiveTargetAndSourceRequireNoSlotsEvenAtBothActualEmitterLimits() throws {
    var (game, instance, target) = try capacityTarget()
    try fillActualEventQueue(&game, instance: instance, to: 4096)
    game.commander.scriptState.instances[instance]?.outcome = .complete
    game.commander.scriptState.nextEvent = UInt64(Int64.max) - 1
    let before = game.commander
    let plan = try componentCapacityPlan(game, target: target, source: instance)
    #expect(plan.requiredEvents == 0 && plan.pendingCount == 4096)
    #expect(game.commander == before)
  }
}
