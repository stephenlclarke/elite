import Foundation

@testable import EliteCore

/// Descriptive test policy, never a native firing or travel authority.
enum ScriptProcurementRangePolicy {
  static func closingMargin(_ body: SpaceBody, context: EncounterContext) -> Double? {
    guard let physical = body.physical,
      let actor = context.actors.first(where: { $0.identity == physical.identity }),
      physical.velocity.finite, actor.velocity.finite, context.player.velocity.finite,
      actor.maximumSpeedUnitsPerSecond.isFinite, actor.maximumSpeedUnitsPerSecond >= 0,
      context.player.maximumSpeedUnitsPerSecond.isFinite,
      context.player.maximumSpeedUnitsPerSecond >= 0
    else { return nil }
    let margin =
      0.1
      * (max(context.player.maximumSpeedUnitsPerSecond, context.player.velocity.length)
        + max(
          actor.maximumSpeedUnitsPerSecond, max(physical.velocity.length, actor.velocity.length)))
    return margin.isFinite ? margin : nil
  }

  static func pulseOnly(_ body: SpaceBody, context: EncounterContext) -> Bool {
    guard let physical = body.physical, let spawn = physical.spawnIdentity,
      physical.identity != context.player.identity,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      context.actors.filter({ $0.identity == physical.identity }).count == 1,
      spawn.system == context.system, spawn.visit == context.visit, spawn.producer == .ambient,
      physical.population == .pirate, physical.npc?.role == .pirate,
      physical.npc?.intention == .engage(context.player.identity),
      let actor = context.actors.first(where: { $0.identity == physical.identity }),
      actor.npc == physical.npc, actor.energy == body.energy, actor.hull == body.hull,
      actor.catalogueShipID == physical.catalogueShipID,
      closingMargin(body, context: context) != nil,
      let catalogue = ShipCatalogue.nativeShip(body.hull), physical.catalogueShipID == catalogue.id,
      let resources = physical.npc?.resources, resources.valid,
      body.missiles == 0, body.energy.isFinite, body.energy > 0, body.position.finite,
      body.position.length.isFinite,
      !context.protection.protectedActors.contains(physical.identity),
      body.scriptNPC == nil, body.scriptShot == nil, body.missionActorID == nil,
      body.missionInstanceID == nil, body.blackjackRole == nil, body.blackjackIdentity == nil,
      !body.navalTarget, physical.ordnance == nil, physical.attackOrigin == nil,
      physical.salvage == nil, physical.empSource == nil, physical.empCrewPod == nil,
      ![Hull.constrictor, .thargoid, .thargon].contains(body.hull)
    else { return false }
    switch resources.profile {
    case .nativeHull, .legacyEnergyOnly: return true
    }
  }
}

struct ScriptProcurementRetreat: Sendable, Equatable {
  let target: ActorIdentity
  let turnSign: Double
}

extension ScriptProcurementPilotBudget {
  /// Cooling or a nearer ordinary actor never cancels an established break turn.
  mutating func updateRetreat(_ facts: ScriptProcurementPreflightFacts) {
    guard facts.valid, facts.live, !facts.paused, !facts.docked, !facts.automaticEngaged,
      facts.needsDefence, facts.threats.allSatisfy(\.pulseOnly)
    else {
      retreat = nil
      return
    }
    if let phase = retreat,
      let target = facts.threats.first(where: { $0.identity == phase.target }), target.pulseOnly,
      target.immediate || facts.incoming
    {
      return
    }
    retreat = nil
    guard let threat = facts.threat, threat.pulseOnly, threat.immediate,
      facts.pulseHeatBlocked || facts.frontShieldLow
    else { return }
    retreat = .init(target: threat.identity, turnSign: threat.position.x <= 0 ? 1 : -1)
  }
}
