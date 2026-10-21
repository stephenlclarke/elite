import Foundation

/// Issued by the real scoop pass, consumed after that physical frame in one actor turn.
/// It contains no game, actor, writer or callback and is never encoded in a save.
struct NativeSalvageCollectionObservation: Sendable {
  fileprivate let body: SpaceBody
  fileprivate let lot: SalvageLot
  fileprivate let owner: UUID
  fileprivate let hull: UUID
  fileprivate let scoops: UUID
  fileprivate let inventoryRevision: UInt64
  fileprivate let epoch: UUID
  fileprivate let player: ActorIdentity
  fileprivate let frame: UInt64
  fileprivate let time: Double
  fileprivate let pose: ShipPose

  fileprivate init(
    body: SpaceBody, lot: SalvageLot, game: Game, context: EncounterContext,
    owner: UUID, hull: UUID, scoops: UUID, inventoryRevision: UInt64
  ) {
    self.body = body
    self.lot = lot
    self.owner = owner
    self.hull = hull
    self.scoops = scoops
    self.inventoryRevision = inventoryRevision
    epoch = game.nativeStationRuntimeEpoch
    player = context.player.identity
    frame = context.revision
    time = context.physicalTime
    pose = game.commander.flightSimulation.pose
  }
}

extension Game {
  func usesNativeSalvageCollection(_ body: SpaceBody) -> Bool {
    guard let payload = body.physical?.payload, case .salvage(let identity) = payload else {
      return false
    }
    if commander.alienStorageState?.current.salvage.sections.contains(identity.section) == true
      || commander.salvageLedger.nativeTransferredSectionIdentities.contains(identity.section)
    {
      return true
    }
    guard let lot = currentSalvageLot(for: body),
      case .technology(let definition, _, _) = lot.content
    else { return false }
    return AlienModuleDefinition.isAttachmentDefinition(definition)
  }

  /// Shared scoop geometry and guidance checks run before this producer is called.
  mutating func observeNativeSalvageCollection(_ body: SpaceBody) {
    guard !docked, !paused, screen != .gameOver, energy.isFinite, energy > 0,
      let context = gameplayContext(), let physical = body.physical,
      body.hull == .cargo || (body.hull == .thargon && !body.hostile),
      body.energy.isFinite, body.energy > 0, body.position.z > 0, body.position.y < 0,
      body.position.length < 85,
      let lot = currentSalvageLot(for: body),
      commander.nativeSalvageBodyOwnershipMatches(body, lot: lot),
      !context.protection.protectedActors.contains(physical.identity),
      !context.protection.protectedPayloads.contains(.salvage(lot.identity)),
      let owner = commander.equipmentOwnerID, let hull = commander.hullInstanceID,
      let inventory = commander.equipmentInventory,
      let scoops = commander.fittedEquipment(at: .utility(.fuelScoops)),
      scoops.location?.hullInstanceID == hull,
      lot.halfExtents.finite, lot.massKg.isFinite, lot.massKg > 0,
      lot.halfExtents.x >= 0, lot.halfExtents.x <= 16,
      lot.halfExtents.y >= 0, lot.halfExtents.y <= 16,
      lot.halfExtents.z >= 0, lot.halfExtents.z <= 16,
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
      !pendingNativeSalvageCollections.contains(where: { $0.body.id == body.id })
    else { return }
    let observation = NativeSalvageCollectionObservation(
      body: body, lot: lot, game: self, context: context,
      owner: owner, hull: hull, scoops: scoops.id, inventoryRevision: inventory.revision)
    pendingNativeSalvageCollections.append(observation)
  }

  fileprivate mutating func applyNativeSalvageCollection(
    _ observation: NativeSalvageCollectionObservation
  ) throws {
    guard !docked, !paused, screen != .gameOver, energy.isFinite, energy > 0,
      pendingNativeStationDock == nil, let context = gameplayContext(),
      context.player.identity == observation.player, context.revision == observation.frame,
      context.physicalTime == observation.time,
      commander.flightSimulation.pose == observation.pose,
      nativeStationRuntimeEpoch == observation.epoch,
      commander.equipmentOwnerID == observation.owner,
      commander.hullInstanceID == observation.hull,
      commander.equipmentInventory?.revision == observation.inventoryRevision,
      commander.fittedEquipment(at: .utility(.fuelScoops))?.id == observation.scoops,
      let index = bodies.firstIndex(where: { $0.id == observation.body.id }),
      bodies[index] == observation.body, currentSalvageLot(for: bodies[index]) == observation.lot,
      let actor = observation.body.physical?.identity,
      !context.protection.protectedActors.contains(actor),
      !context.protection.protectedPayloads.contains(.salvage(observation.lot.identity))
    else { throw SaveError.invalidCommander }
    guard flushNativeSalvageMotion() else { throw SaveError.invalidCommander }
    let identity = observation.lot.identity
    if commander.alienStorageState?.current.salvage.sections.contains(identity.section) != true {
      let imported = try NativeSalvageImport(
        ledger: commander.salvageLedger,
        section: identity.section, owner: observation.owner, at: observation.time,
        previous: commander.alienStorageState?.current.snapshot)
      try imported.apply(to: &commander)
    }
    guard let previous = commander.alienStorageState?.current,
      let pending = previous.salvage.pending[identity],
      pending.binding == observation.body.physical?.identity,
      pending.lot == observation.lot
    else { throw AlienStorageError.historyChanged }
    let result = try NativeSalvageCollectionMutation(
      snapshot: previous.snapshot,
      record: pending.record, lot: pending.lot, hull: observation.hull,
      at: observation.time, cargo: commander.cargo)
    try commander.replaceAlienStorage(with: result.snapshot)
    commander.cargo = result.cargo
    guard let cargo = commander.checkedCargoTonnes, cargo <= commander.capacity else {
      throw SaveError.invalidCommander
    }
    workTargetCollected(bodies[index])
    bodies.remove(at: index)
    guard commander.valid else { throw SaveError.invalidCommander }
  }
}

extension GameRuntime {
  func commitNativeSalvageCollections() {
    let observations = game.pendingNativeSalvageCollections
    game.pendingNativeSalvageCollections.removeAll(keepingCapacity: true)
    guard !observations.isEmpty else { return }
    guard let url = scriptSaveURL else {
      game.notify("SALVAGE NOT SAVED - SAVE COMMANDER TO ENABLE RECOVERY")
      return
    }
    var candidate = game
    do {
      for observation in observations {
        try candidate.applyNativeSalvageCollection(observation)
      }
      try requireGalleryFileAccess(url)
      // The first native acquisition must publish even if the prior live game had no
      // durable script feature. A nil publisher can never authorize physical removal.
      try Self.writeCommander(&candidate, to: url)
      game = candidate
      game.notify("SALVAGE RECOVERED")
    } catch {
      // The already completed physical frame remains; only private custody effects fail.
      game.notify("SALVAGE NOT SAVED - RECOVERY NOT COMMITTED")
    }
  }
}
