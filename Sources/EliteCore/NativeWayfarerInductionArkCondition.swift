import Foundation

extension NativeInductionArkPack {
  /// This initial issue is only offered to the existing prepared native-admission transaction.
  /// Every later admission uses the retained condition, including spent shields and own fuel.
  static func initialCondition(state: borrowing ScriptInstance, actor: ScriptOwnedActor) throws
    -> NPCState?
  {
    guard marked(state) else { return nil }
    guard state.definition == stateID, state.digest == digest, let ark = state.savedNativeArk,
      ark.authorization.job == state.id, ark.authorization.actor == actor.identity,
      ark.admission == nil, ark.legs.isEmpty, ark.loss == nil, ark.fuel.purchases.isEmpty,
      actor.presence == .prepared, actor.body.physical == nil,
      let performance = OriginalFleetDefinitionData.definition(for: NativeInductionArkSource.hull)?
        .nativePerformance,
      performance.valid,
      let profile = try? NativeInductionArkSource.profile(),
      actor.body.scriptNPC?.fit.definition == profile
    else { throw SaveError.invalidCommander }
    // ScriptNPCState.fuel is the one 13-LY reservoir; do not create a second native tank.
    let resources = NPCResources(
      profile: .nativeHull, energyCapacity: performance.energy,
      energyRecharge: performance.recharge,
      frontCapacity: performance.shield, rearCapacity: performance.shield,
      shieldRecharge: performance.shieldRecharge, frontShield: performance.shield,
      rearShield: performance.shield, heatCapacity: 240, heatCooling: 12,
      fuel: nil, fuelCapacity: nil)
    guard resources.valid else { throw SaveError.invalidCommander }
    return NPCState(
      role: .mission, origin: NativeWayfarerInduction.seedSource,
      destination: NativeWayfarerInduction.seedReceiver,
      legalProvenance: .recorded, cargoProvenance: .recorded,
      routeProvenance: .recorded, resources: resources, hasFuelScoops: false)
  }
}
