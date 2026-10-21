import Foundation

/// The current native record seals one request inside the admission candidate.
/// Neither a payload identity nor an old ordinary offer grants native admission.
enum NativeSalvageOffer {
  static func request(lot: SalvageLot, spawn: SpawnIdentity) -> SpawnRequest {
    .init(
      identity: spawn, population: .cargo, hull: .cargo,
      position: lot.position, orientation: .init(), velocity: lot.velocity, npc: nil,
      rock: nil, payload: .salvage(lot.identity), priority: .ordinary,
      salvage: .init(
        category: lot.category, ownership: lot.loot?.legality.ownership ?? .abandoned,
        claimant: nil, wreck: lot.identity.section.wreck, section: lot.identity.section,
        lot: lot.identity,
        bounds: .init(center: .init(0, 0, 0), radius: lot.halfExtents.length), workSurfaces: []))
  }

  /// A pure record transition preserves the producer's original lot and all history.
  /// Only the actual admission caller can reserve the namespace and publish a binding.
  static func stage(
    _ record: AlienStorageWorldRecord, pending: AlienNativeSalvageIndex.Pending,
    spawn: SpawnIdentity, owner: UUID
  ) throws -> AlienStorageWorldRecord {
    guard record.id == pending.record, pending.offer == nil, pending.binding == nil else {
      throw AlienStorageError.invalidJoin
    }
    switch record {
    case .lot(let item):
      guard item.owner == owner,
        case .pending(let lot, let time, nil, nil) = item.state,
        lot == pending.lot, time == pending.physicalTime
      else { throw AlienStorageError.invalidJoin }
      return .lot(
        .init(
          id: item.id, owner: item.owner, plan: item.plan, itemIndex: item.itemIndex,
          issuedAt: item.issuedAt,
          state: .pending(lot: lot, physicalTime: time, offer: spawn, binding: nil)))
    case .companion(let item):
      guard item.owner == owner,
        case .pending(let lot, let time, nil, nil) = item.state,
        lot == pending.lot, time == pending.physicalTime
      else { throw AlienStorageError.invalidJoin }
      return .companion(
        .init(
          id: item.id, owner: item.owner, plan: item.plan, origin: item.origin,
          issuedAt: item.issuedAt,
          state: .pending(lot: lot, physicalTime: time, offer: spawn, binding: nil)))
    case .legacyCurrent(let item):
      guard item.owner == owner,
        case .pending(let lot, let time, nil, nil) = item.state,
        lot == pending.lot, time == pending.physicalTime
      else { throw AlienStorageError.invalidJoin }
      return .legacyCurrent(
        .init(
          id: item.id, owner: item.owner, claim: item.claim,
          state: .pending(lot: lot, at: time, offer: spawn, binding: nil)))
    default: throw AlienStorageError.invalidJoin
    }
  }
}

extension Game {
  private func nativeSalvageOfferContextIsCurrent(_ context: EncounterContext) -> Bool {
    let flight = commander.flightSimulation
    return !docked && context.system == systemIdentity && context.system == flight.system
      && context.visit == flight.visit && context.revision == gameplayRevision
      && context.physicalTime == flight.physicalTime && context.player.identity == flight.player
      && context.player.position == flight.pose.position
      && context.player.orientation == flight.pose.orientation
      && commander.alienStorageStateValid
  }

  /// The caller already owns a private Game candidate. Validation assigns only the
  /// new immutable Commander state, so failure needs no additional Game copy.
  mutating func stageNativeSalvageOffer(
    _ pending: AlienNativeSalvageIndex.Pending, spawn: SpawnIdentity, context: EncounterContext
  ) -> Bool {
    guard nativeSalvageOfferContextIsCurrent(context),
      let state = commander.alienStorageState,
      state.current.salvage.sections.contains(pending.lot.identity.section),
      let current = state.current.salvage.pending[pending.lot.identity],
      current.record == pending.record, current.lot == pending.lot,
      current.physicalTime == pending.physicalTime,
      current.offer == nil, current.binding == nil,
      spawn.system == context.system, spawn.visit == context.visit, spawn.member == 0,
      commander.salvageLedger.wasNativeSpawnAllocated(spawn),
      commander.salvageLedger.offeredLot(for: spawn) == nil,
      let index = state.current.snapshot.world.firstIndex(where: { $0.id == pending.record })
    else { return false }
    do {
      var world = state.current.snapshot.world
      world[index] = try NativeSalvageOffer.stage(
        world[index], pending: pending, spawn: spawn, owner: state.current.owner)
      try commander.replaceAlienStorage(with: state.current.snapshot.replacingNativeWorld(world))
      return true
    } catch { return false }
  }

  func nativeOfferedSalvageLot(for request: SpawnRequest, context: EncounterContext) -> SalvageLot?
  {
    guard nativeSalvageOfferContextIsCurrent(context),
      let payload = request.payload, case .salvage(let identity) = payload,
      let current = commander.alienStorageState?.current.salvage,
      current.sections.contains(identity.section), let pending = current.pending[identity],
      pending.offer == request.identity, pending.binding == nil,
      request.identity.system == context.system, request.identity.visit == context.visit,
      request.identity.member == 0,
      commander.salvageLedger.wasNativeSpawnAllocated(request.identity),
      commander.salvageLedger.offeredLot(for: request.identity) == nil,
      request == NativeSalvageOffer.request(lot: pending.lot, spawn: request.identity)
    else { return nil }
    return pending.lot
  }

  /// Old released custody may precede native-wreck records. Join a live parent
  /// through the genuine current factory inside the caller's private candidate.
  /// Independent orphan lots still use ordinary common admission without a parent.
  mutating func prepareNativeSalvageOfferParent(for lot: SalvageLot) -> Bool {
    guard commander.alienStorageStateValid,
      let pending = commander.alienStorageState?.current.salvage.pending[lot.identity],
      pending.lot == lot, pending.binding == nil, pending.offer == nil
    else { return false }
    let parents = bodies.filter {
      guard let physical = $0.physical, physical.payload == nil,
        let metadata = physical.salvage, metadata.wreck == lot.identity.section.wreck
      else { return false }
      return metadata.category == .wreck || metadata.category == .section
    }
    guard parents.count <= 1 else { return false }
    guard let body = parents.first else {
      return commander.alienStorageState?.current.salvage.native.wrecks[lot.identity.section.wreck]?
        .binding == nil
    }
    if commander.alienStorageState?.current.salvage.native.wrecks[lot.identity.section.wreck] != nil
    {
      // An existing mismatched binding/source cannot be replaced by copied metadata.
      return nativeSalvageOfferParentMatches(body, lot: lot)
    }
    guard retainNativeSalvageWreck(body) else { return false }
    return nativeSalvageOfferParentMatches(body, lot: lot)
  }

  /// The parent's broad-sphere exception belongs to its current native actor and
  /// retained original source, never another hull with copied wreck metadata.
  func nativeSalvageOfferParentMatches(_ body: SpaceBody, lot: SalvageLot) -> Bool {
    guard commander.alienStorageStateValid, let physical = body.physical,
      let wreck = commander.alienStorageState?.current.salvage.native.wrecks[
        lot.identity.section.wreck],
      wreck.owner == commander.equipmentOwnerID,
      wreck.seed == commander.salvageLedger.nativeInspectionSeed,
      wreck.binding == physical.identity, wreck.destroyedAt == nil,
      wreck.catalogueShipID == physical.catalogueShipID
    else { return false }
    switch wreck.source {
    case .generated(let site):
      return physical.empSource == nil && site.metadata == physical.salvage
    case .emp(let source, let sequence):
      guard physical.empSource == source, let record = commander.savedEMPState?.records[source]
      else { return false }
      return record.wreck == wreck.identity && record.sequence == sequence && record.crewAboard == 0
        && record.pods.count + record.capturedCrewCount == record.crewTotal
    }
  }
}
