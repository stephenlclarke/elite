import Foundation

struct AmbientEncounterDisposition: Equatable, Sendable {
  let hostile: Bool
  let wanted: Bool?
  /// Reuse ordinary pirate legal tuning: bounty is 50 tenths, or 5 CR.
  var legalOverride: LegalRecord? {
    wanted.map { $0 ? .init(value: 16, bountyTenths: 50) : .init() }
  }
}

/// Initial per-ship disposition, never an encounter frequency or live population quota.
enum AmbientEncounterPolicy {
  static let hostilityPercentages = [90, 70, 50, 40, 30, 20, 10, 0]
  static func sample(
    identity: SpawnIdentity, seed: UInt64, government: Int, role: NPCRole
  ) -> AmbientEncounterDisposition? {
    guard hostilityPercentages.indices.contains(government), identity.producer == .ambient,
      [.trader, .miner, .pirate].contains(role), identity.visit > 0, identity.sequence > 0,
      (0..<8).contains(identity.system.galaxy), (0...256).contains(identity.system.system)
    else { return nil }
    let source =
      seed
      ^ mix(UInt64(identity.system.galaxy) &* 257 &+ UInt64(identity.system.system))
      ^ mix(identity.visit ^ 0x5649_5349_5430_3031)
      ^ mix(identity.sequence ^ 0x5345_5155_454e_4345)
      ^ mix(UInt64(identity.member) ^ 0x4d45_4d42_4552_3031)
    return .init(
      hostile: mix(source ^ 0x484f_5354_494c_4531) % 100 < UInt64(hostilityPercentages[government]),
      wanted: government == 0 ? mix(source ^ 0x5741_4e54_4544_3031) % 100 < 90 : nil)
  }

  /// Preserve the existing generated intent over idle role defaults, not over real combat,
  /// retreat, collection or retargeting. Generated route evidence remains stable when a
  /// real unlawful shot changes legal provenance to recorded. No state is resampled here.
  static func preserveIntent(
    of actor: ActorSnapshot, context: EncounterContext, proposed: NPCAction?
  ) -> NPCAction? {
    guard hostilityPercentages.indices.contains(context.government), actor.energy > 0,
      actor.hull != .station,
      actor.rock == nil, actor.payload == nil, actor.salvage == nil,
      actor.identity.system == context.system, actor.identity.visit == context.visit,
      !context.protection.protectedActors.contains(actor.identity),
      !context.protection.protectedActors.contains(context.player.identity),
      context.player.energy > 0, let npc = actor.npc, npc.routeProvenance == .generated,
      [.trader, .miner, .pirate].contains(npc.role), let current = npc.intention
    else { return proposed }
    if current == .engage(context.player.identity) {
      switch proposed {
      case .none, .some(.navigate(_, _)), .some(.dock(_)), .some(.mine(_)): return current
      default: return proposed
      }
    }
    // A peaceful generated pirate still has its real navigation/dock destination.
    // Do not turn that first idle update into unprovoked aggression against any carrier.
    if npc.role == .pirate, npc.firstAggressor == nil,
      case .some(.engage(_)) = proposed
    {
      switch current {
      case .navigate, .dock: return current
      default: break
      }
    }
    return proposed
  }
  private static func mix(_ input: UInt64) -> UInt64 {
    var value = input
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    return value ^ (value >> 31)
  }
}
