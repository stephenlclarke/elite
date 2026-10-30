import Foundation

@testable import L337Core

/// Finite test-pilot requests never replace native targeting, ammunition or launch authority.
struct ScriptProcurementMissileBudget: Sendable, Equatable {
  private(set) var originals: Set<UUID>?
  private(set) var attempted: Set<UUID> = []

  mutating func reserve(_ round: UUID, originals: Set<UUID>) -> Bool {
    guard originals.count == 3, originals.contains(round), attempted.count < 3,
      !attempted.contains(round), self.originals == nil || self.originals == originals
    else { return false }
    self.originals = originals
    attempted.insert(round)
    return true
  }
}

enum ScriptProcurementMissileRefusal: Error, Equatable {
  case stale, stock, budget, target, arm, launch, law
}

enum ScriptProcurementMissilePolicy {
  static func requestsFallback(
    _ facts: ScriptProcurementPreflightFacts, steps: Int, pulse: Bool, heat: Double,
    cooldown: Double, rounds: Int, unlimited: Bool, ownMissile: Bool
  ) -> Bool {
    // The next ordinary 0.1-second frame cools by 1.2 before the native pulse heat gate.
    facts.identity != nil && facts.legal == 0 && facts.outsideNoFireZones
      && facts.requestedAction(steps: steps) == .requestFire
      && pulse && heat.isFinite && max(0, heat - 0.1 * 12) >= 240
      && cooldown == 0 && rounds > 0 && rounds <= 3 && !unlimited && !ownMissile
  }
}

/// The existing one-commander preservation oracle lives off the active helper
/// stack. Construction, native actions and pure comparison use separate frames.
private final class ScriptProcurementMissileLaunchBaseline {
  private let commander: Commander

  @inline(never)
  init(game: borrowing Game) throws {
    guard game.commander.equipmentInventory != nil else {
      throw ScriptProcurementMissileRefusal.stock
    }
    commander = game.commander
  }

  @inline(never)
  func accepts(_ game: borrowing Game, round: UUID, player: ActorIdentity, target: ActorIdentity)
    -> Bool
  {
    guard let beforeInventory = commander.equipmentInventory else { return false }
    let emittedAt = commander.flightSimulation.physicalTime
    let missiles = game.bodies.compactMap { body -> OrdnanceState? in
      guard body.energy > 0, let state = body.physical?.ordnance,
        state.profile == .standardMissile, state.origin.owner == player,
        state.target == target,
        state.origin.playerAmmunition == .physical(item: round), state.termination == nil,
        body.physical?.identity == state.origin.ordnance,
        state.origin.emittedAt == emittedAt
      else { return nil }
      return state
    }
    guard let inventory = game.commander.equipmentInventory,
      inventory.owner == beforeInventory.owner, inventory.activeHull == beforeInventory.activeHull,
      inventory.items == beforeInventory.items.filter({ $0.id != round }),
      missiles.count == 1, !game.missileArmed,
      game.commander.missiles == commander.missiles - 1,
      game.commander.equipmentInventory?.items.contains(where: { $0.id == round }) == false,
      game.commander.credits == commander.credits, game.commander.cargo == commander.cargo,
      game.commander.contracts == commander.contracts,
      game.commander.scriptState.instances == commander.scriptState.instances,
      game.commander.scriptState.missionCalendar == commander.scriptState.missionCalendar,
      game.commander.scriptState.calendarLedger == commander.scriptState.calendarLedger,
      game.commander.scriptState.calendarSeconds == commander.scriptState.calendarSeconds,
      game.commander.scriptState.localSeconds == commander.scriptState.localSeconds,
      game.commander.scriptState.flightSeconds == commander.scriptState.flightSeconds,
      game.commander.flightSimulation.physicalTime == emittedAt,
      game.commander.equipmentPurchaseHistory == commander.equipmentPurchaseHistory,
      game.commander.valid
    else { return false }
    return true
  }
}

extension GameRuntime {
  /// No suspension occurs between fresh checks and ordinary keys, including each save barrier.
  /// Any admitted refusal throws out of the defended journey; it is never retried.
  @inline(never)
  func procurementMissileFallback(
    expected: ScriptProcurementPreflightFacts, budget originalBudget: ScriptProcurementPilotBudget
  ) throws -> ScriptProcurementPilotBudget {
    var budget = originalBudget
    var facts = procurementPreflightFacts()
    guard facts.rejoins(expected) else { throw ScriptProcurementMissileRefusal.stale }
    guard let player = facts.identity?.player, let threat = facts.threat else { return budget }
    guard procurementMissileRequested(facts, steps: budget.steps, player: player) else {
      return budget
    }
    let stock = try procurementOriginalMissileStock()
    guard let round = stock.next,
      budget.missileDefence.reserve(round, originals: stock.originals)
    else { throw ScriptProcurementMissileRefusal.budget }

    while !procurementMissileTargetJoined(threat.identity, player: player) {
      guard budget.reserveTab() else { throw ScriptProcurementMissileRefusal.budget }
      key("tab")
      guard game.commander.legal == 0 else { throw ScriptProcurementMissileRefusal.law }
      let observed = procurementPreflightFacts()
      guard observed.identity?.player == player, observed.live, !observed.paused,
        observed.threat?.identity == threat.identity
      else { throw ScriptProcurementMissileRefusal.stale }
    }
    // Q retains the genuine weapons lock; a station or nil lock is never a launch fallback.
    key("q")
    facts = procurementPreflightFacts()
    guard procurementMissileRequested(facts, steps: budget.steps, player: player),
      facts.threat?.identity == threat.identity,
      procurementMissileTargetJoined(threat.identity, player: player),
      try procurementOriginalMissileStock().next == round
    else { throw ScriptProcurementMissileRefusal.target }

    let baseline = try ScriptProcurementMissileLaunchBaseline(game: game)
    key("t")
    facts = procurementPreflightFacts()
    guard game.commander.legal == 0 else { throw ScriptProcurementMissileRefusal.law }
    guard game.missileArmed,
      procurementMissileRequested(facts, steps: budget.steps, player: player),
      facts.threat?.identity == threat.identity,
      procurementMissileTargetJoined(threat.identity, player: player),
      try procurementOriginalMissileStock().next == round
    else { throw ScriptProcurementMissileRefusal.arm }
    try procurementPublishReservedMissile(
      baseline: baseline, round: round, player: player, target: threat.identity)
    return budget
  }

  /// Native keys and durable publication retire before the pure post-launch join.
  @inline(never)
  private func procurementPublishReservedMissile(
    baseline: ScriptProcurementMissileLaunchBaseline, round: UUID,
    player: ActorIdentity, target: ActorIdentity
  ) throws {
    key("m")
    guard game.commander.legal == 0 else { throw ScriptProcurementMissileRefusal.law }
    guard baseline.accepts(game, round: round, player: player, target: target) else {
      throw ScriptProcurementMissileRefusal.launch
    }
  }

  private func procurementMissileRequested(
    _ facts: ScriptProcurementPreflightFacts, steps: Int, player: ActorIdentity
  ) -> Bool {
    let ownMissile = game.bodies.contains { body in
      guard body.energy > 0, let state = body.physical?.ordnance else { return false }
      return state.termination == nil && state.origin.owner == player
        && state.target == facts.threat?.identity
    }
    return facts.identity?.player == player && !game.playerEMPDisabled && !game.workFireSuspended
      && !game.ecmControl.fieldActive
      && game.energy > 1 && game.jumpCountdown == nil && game.pendingNativeStationDock == nil
      && ScriptProcurementMissilePolicy.requestsFallback(
        facts, steps: steps, pulse: game.commander.laser(on: .front) == .pulse,
        heat: game.laserHeat, cooldown: game.missileCooldown, rounds: game.commander.missiles,
        unlimited: game.commander.unlimitedMissiles, ownMissile: ownMissile)
      && scriptPublisher() != nil && game.commander.valid
  }

  /// Current body/context identity joins remain separate from descriptive policy facts.
  private func procurementMissileTargetJoined(_ target: ActorIdentity, player: ActorIdentity)
    -> Bool
  {
    guard let id = game.weaponsTargetID,
      let context = game.gameplayContext(), context.player.identity == player,
      target != player, target.system == context.system, target.visit == context.visit,
      !context.protection.protectedActors.contains(target)
    else { return false }
    let bodies = game.bodies.filter { $0.physical?.identity == target }
    let actors = context.actors.filter { $0.identity == target }
    guard bodies.count == 1, actors.count == 1, let body = bodies.first,
      let actor = actors.first, body.id == id, body.hull.isTargetShip, body.hull != .station,
      body.energy > 0, body.position.finite, body.position.z > 0,
      body.physical?.npc?.intention == .engage(player), body.physical?.npc?.legal.wanted == true,
      actor.energy > 0, actor.npc?.intention == .engage(player), actor.legal.wanted
    else { return false }
    if let payload = body.physical?.payload,
      context.protection.protectedPayloads.contains(payload)
    {
      return false
    }
    return true
  }

  private func procurementOriginalMissileStock() throws -> (originals: Set<UUID>, next: UUID?) {
    guard !game.commander.unlimitedMissiles, game.commander.valid,
      let inventory = game.commander.equipmentInventory,
      let history = game.commander.equipmentPurchaseHistory,
      let foundation = history.paid.first?.binding.snapshot,
      history.owner == inventory.owner, foundation.owner == inventory.owner,
      foundation.activeHull == inventory.activeHull
    else { throw ScriptProcurementMissileRefusal.stock }
    let originals = Set(
      foundation.items.filter {
        $0.node == EquipmentRuntimeCatalog.standardMissile && $0.provenance == .standard
      }.map(\.id))
    let rounds: [(Int, UUID)] = inventory.items.compactMap { item in
      guard item.node == EquipmentRuntimeCatalog.standardMissile, item.provenance == .standard,
        let location = item.location, location.hullInstanceID == inventory.activeHull,
        case .missilePylon(let pylon) = location.slot
      else { return nil }
      return (pylon, item.id)
    }
    guard originals.count == 3, rounds.count == game.commander.missiles,
      rounds.allSatisfy({ originals.contains($0.1) })
    else { throw ScriptProcurementMissileRefusal.stock }
    return (originals, rounds.max { $0.0 < $1.0 }?.1)
  }
}
