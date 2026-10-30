import Foundation

extension Commander {
  /// A native fragment has one cargo body and one current physical owner. This predicate
  /// validates retained facts; it cannot issue a scoop observation or allocate an actor.
  func nativeSalvageBodyOwnershipMatches(_ body: SpaceBody, lot: SalvageLot) -> Bool {
    guard let physical = body.physical, let spawn = physical.spawnIdentity,
      body.hull == .cargo, physical.population == .cargo, body.energy.isFinite,
      physical.payload == .salvage(lot.identity), physical.npc == nil,
      physical.rock == nil, physical.ordnance == nil,
      physical.empSource == nil, physical.empCrewPod == nil,
      body.missionActorID == nil, body.missionInstanceID == nil,
      !body.navalTarget, body.blackjackIdentity == nil, body.blackjackRole == nil,
      body.blackjackLaserCooldown == nil, !body.enemyMissile,
      body.playerMissileTarget == nil, body.missileSourceID == nil,
      body.scriptNPC == nil, body.scriptShot == nil, body.nativeStationIdentity == nil,
      physical.identity.system == flightSimulation.system,
      physical.identity.visit == flightSimulation.visit,
      physical.identity.entity >= 2, physical.identity.entity < flightSimulation.nextActor,
      lot.identity.section.wreck.system == physical.identity.system,
      spawn.system == physical.identity.system, spawn.visit == physical.identity.visit,
      spawn.member == 0, salvageLedger.wasNativeSpawnAllocated(spawn),
      npcPersistence.logicalIdentity(for: physical.identity) == nil,
      !miningLedger.ownsPhysicalActor(physical.identity),
      !cargoDebrisLedger.ownsPhysicalActor(physical.identity)
    else { return false }
    if let state = savedEMPState,
      state.records.values.contains(where: { record in
        record.hull.binding == physical.identity
          || record.pods.contains(where: { $0.binding == physical.identity })
      })
    {
      return false
    }
    let expected = SalvageTargetMetadata(
      category: lot.category,
      ownership: lot.loot?.legality.ownership ?? .abandoned, claimant: nil,
      wreck: lot.identity.section.wreck, section: lot.identity.section, lot: lot.identity,
      bounds: .init(center: .init(0, 0, 0), radius: lot.halfExtents.length), workSurfaces: [])
    return physical.salvage == expected
  }
}
