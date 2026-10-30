import Foundation

extension NativeInductionCrewLogPack {
  static func initialBody(_ body: inout SpaceBody, state: borrowing ScriptInstance, alias: String)
    throws
  {
    guard marked(state) else { return }
    guard state.definition == stateID, state.digest == digest,
      let source = state.savedNativeCrewLog, source.authorization.job == state.id,
      source.admission == nil, source.losses.isEmpty,
      let role = NativeInductionCrewLogRole(rawValue: alias),
      body.missionActorID == actor(job: state.id, role: role),
      body.missionInstanceID == state.id, body.physical == nil, body.id == -1,
      body.scriptNPC != nil
    else { throw SaveError.invalidCommander }
    if role == .tender {
      guard body.scriptNPC?.components["drive"] != nil else { throw SaveError.invalidCommander }
      body.scriptNPC?.components["drive"]?.energy = 0
    }
  }

  static func mechanicallyDisabled(_ actor: ScriptOwnedActor, state: borrowing ScriptInstance)
    -> Bool
  {
    state.definition == stateID && state.digest == digest && state.savedNativeCrewLog != nil
      && actor.alias == NativeInductionCrewLogRole.tender.rawValue
      && actor.identity == Self.actor(job: state.id, role: .tender)
  }

  static func initialResources(state: borrowing ScriptInstance, actor: ScriptOwnedActor) throws
    -> NPCState?
  {
    guard marked(state) else { return nil }
    guard let source = state.savedNativeCrewLog, source.authorization.job == state.id,
      source.admission == nil, source.losses.isEmpty, actor.presence == .prepared,
      let role = NativeInductionCrewLogRole(rawValue: actor.alias),
      actor.identity == Self.actor(job: state.id, role: role),
      let performance = OriginalFleetDefinitionData.definition(
        for: NativeInductionCrewLogSource.hull)?
        .nativePerformance, performance.valid
    else { throw SaveError.invalidCommander }
    let recorder = role == .recorder
    let resources = NPCResources(
      profile: .nativeHull, energyCapacity: recorder ? 100 : performance.energy,
      energyRecharge: recorder ? 0 : performance.recharge,
      frontCapacity: recorder ? 0 : performance.shield,
      rearCapacity: recorder ? 0 : performance.shield,
      shieldRecharge: recorder ? 0 : performance.shieldRecharge,
      frontShield: recorder ? 0 : performance.shield,
      rearShield: recorder ? 0 : performance.shield,
      heatCapacity: 240, heatCooling: 12, fuel: nil, fuelCapacity: nil)
    guard resources.valid else { throw SaveError.invalidCommander }
    return .init(
      role: .mission, origin: NativeInductionCrewLogSource.location,
      destination: NativeInductionCrewLogSource.receiver,
      legalProvenance: .recorded, cargoProvenance: .recorded,
      routeProvenance: .recorded, resources: resources, hasFuelScoops: false)
  }
}
