import Foundation

/// Produces requests only. Steering, ray tests, damage and transactions belong to G1.
public enum TrafficIntent {
  public static func intents(context: EncounterContext) -> [NPCIntent] {
    let actors = context.actors.filter {
      $0.identity.system == context.system && $0.identity.visit == context.visit && $0.energy > 0
    }.sorted { $0.identity.entity < $1.identity.entity }
    let ordinary = actors.filter { !context.protection.protectedActors.contains($0.identity) }
    let miningFields =
      ordinary.contains { $0.npc?.role == .miner }
      ? MiningFields.generate(
        anchors: context.anchors, seed: context.seed,
        ringPresent: context.miningPresence?.ringPresent
          ?? AsteroidBeltDefinition.isPresent(identity: context.system, seed: context.seed),
        includingLegacy: context.miningPresence?.includingLegacy ?? false
      ).filter { field in
        field.rocks.contains { !context.depletedRocks.contains($0.identity) }
      } : []
    return ordinary.compactMap { actor in
      guard let npc = actor.npc else { return nil }
      let action: NPCAction?
      switch npc.role {
      case .trader:
        if let threat = aggressor(of: actor, among: ordinary + [context.player]) {
          action = .flee(threat.identity)
        } else if case .navigate(let destination, let speed) = npc.intention {
          action = .navigate(
            position: destination, speedUnitsPerSecond: min(speed, actor.maximumSpeedUnitsPerSecond)
          )
        } else {
          action = .dock(context.anchors.station.identity)
        }
      case .miner:
        if let threat = aggressor(of: actor, among: ordinary + [context.player]) {
          action = .flee(threat.identity)
        } else if let pod = nearestPayload(
          to: actor, actors: ordinary, context: context, oreOnly: true), let payload = pod.payload
        {
          action = .scoop(payload)
        } else if let rock = ordinary.filter({
          $0.rock.map { !context.depletedRocks.contains($0) } ?? false
        }).min(by: {
          distance($0, actor) == distance($1, actor)
            ? $0.identity.entity < $1.identity.entity : distance($0, actor) < distance($1, actor)
        }), let identity = rock.rock {
          action =
            distance(rock, actor) <= 500
            ? .mine(identity)
            : .navigate(
              position: rock.position, speedUnitsPerSecond: actor.maximumSpeedUnitsPerSecond)
        } else {
          let field = miningFields.min {
            ($0.position - actor.position).length < ($1.position - actor.position).length
          }
          action =
            field.map {
              .navigate(
                position: $0.position, speedUnitsPerSecond: actor.maximumSpeedUnitsPerSecond)
            } ?? .navigate(position: actor.position, speedUnitsPerSecond: 0)
        }
      case .pirate:
        let police = ordinary.filter { $0.npc?.role == .police && distance($0, actor) <= 6000 }
        let allies = ordinary.filter { $0.npc?.role == .pirate && distance($0, actor) <= 6000 }
        let policeEnergy = police.reduce(0) { $0 + $1.energy }
        let pirateEnergy = allies.reduce(0) { $0 + $1.energy }
        if actor.energy < actor.maximumEnergy * 0.25 || police.count > allies.count
          || policeEnergy > pirateEnergy * 1.5
        {
          if let threat = police.min(by: { distance($0, actor) < distance($1, actor) })
            ?? aggressor(of: actor, among: ordinary + [context.player])
          {
            action = .flee(threat.identity)
          } else {
            action = .navigate(
              position: actor.position + awayFromStation(actor.position, context: context) * 6000,
              speedUnitsPerSecond: actor.maximumSpeedUnitsPerSecond)
          }
        } else if let pod = nearestPayload(
          to: actor, actors: ordinary, context: context, oreOnly: false), let identity = pod.payload
        {
          action = .scoop(identity)
        } else {
          let carriers = (ordinary + [context.player]).filter {
            $0.identity != actor.identity && $0.energy > 0 && $0.npc?.role != .pirate
              && $0.npc?.role != .police && $0.hull != .station
              && !context.protection.protectedActors.contains($0.identity)
              && distance($0, actor) <= 12000 && cargoValue($0) > 0
          }.sorted {
            let a = cargoValue($0)
            let b = cargoValue($1)
            if a != b { return a > b }
            let ad = distance($0, actor)
            let bd = distance($1, actor)
            return ad == bd ? $0.identity.entity < $1.identity.entity : ad < bd
          }
          action =
            carriers.first.map { .engage($0.identity) }
            ?? .navigate(
              position: context.anchors.arrival,
              speedUnitsPerSecond: actor.maximumSpeedUnitsPerSecond)
        }
      case .police, .escort, .mission: action = nil
      }
      let retained = AmbientEncounterPolicy.preserveIntent(
        of: actor, context: context, proposed: action)
      return retained.map { NPCIntent(actor: actor.identity, action: $0) }
    }
  }

  private static func nearestPayload(
    to actor: ActorSnapshot, actors: [ActorSnapshot], context: EncounterContext, oreOnly: Bool
  ) -> ActorSnapshot? {
    actors.filter {
      guard let payload = $0.payload, !context.protection.protectedPayloads.contains(payload),
        distance($0, actor) <= 2000
      else { return false }
      switch payload {
      case .mission, .salvage: return false
      case .wreck: return !oreOnly
      case .ore: return true
      }
    }.min {
      distance($0, actor) == distance($1, actor)
        ? $0.identity.entity < $1.identity.entity : distance($0, actor) < distance($1, actor)
    }
  }

  private static func distance(_ a: ActorSnapshot, _ b: ActorSnapshot) -> Double {
    (a.position - b.position).length
  }
  private static func cargoValue(_ actor: ActorSnapshot) -> Double {
    actor.ordinaryCargo.filter(\.valid).reduce(0) {
      $0 + Double($1.quantity) * Double(max(0, Commodity.all[$1.commodity.rawValue].basePrice))
    }
  }
  private static func aggressor(of actor: ActorSnapshot, among actors: [ActorSnapshot])
    -> ActorSnapshot?
  {
    actors.first { $0.identity == actor.npc?.firstAggressor && distance($0, actor) <= 6000 }
  }
  private static func awayFromStation(_ position: Vector3, context: EncounterContext) -> Vector3 {
    let delta = position - context.anchors.station.position
    return delta.length > 0 ? delta * (1 / delta.length) : .init(0, 0, 1)
  }
}
