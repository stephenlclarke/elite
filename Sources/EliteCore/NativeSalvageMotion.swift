import Foundation

/// Only active physical fragments have hot observations. Historical world records remain
/// immutable until a cold boundary; no history replay or disk write occurs per frame.
struct NativeSalvageMotion: Sendable {
  let lot: SalvageLot
  let actor: ActorIdentity
  let time: Double
  let destroyed: Bool
}

extension Game {
  mutating func observeNativeSalvageMotion(_ body: SpaceBody) -> Bool {
    guard let physical = body.physical, let payload = physical.payload,
      case .salvage(let identity) = payload,
      let pending = commander.alienStorageState?.current.salvage.pending[identity],
      pending.binding == physical.identity,
      commander.nativeSalvageBodyOwnershipMatches(body, lot: pending.lot),
      !commander.salvageLedger.ownsPhysicalActor(physical.identity),
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      body.energy.isFinite, physical.velocity.finite,
      physical.velocity.length.isFinite
    else { return false }
    let position = commander.flightSimulation.pose.systemPoint(body.position)
    let time = commander.flightSimulation.physicalTime
    guard position.finite, position.length.isFinite, time.isFinite,
      time >= pending.physicalTime
    else { return false }
    var lot = pending.lot
    lot.position = position
    lot.velocity = physical.velocity
    nativeSalvageMotion[identity] = .init(
      lot: lot, actor: physical.identity,
      time: time, destroyed: body.energy <= 0)
    return true
  }

  mutating func registerDestroyedNativeSalvage() -> Set<Int> {
    var deferred: Set<Int> = []
    for body in bodies where body.energy <= 0 {
      guard let payload = body.physical?.payload, case .salvage(let identity) = payload,
        commander.alienStorageState?.current.salvage.sections.contains(identity.section) == true
      else { continue }
      guard observeNativeSalvageMotion(body), flushNativeSalvageMotion() else {
        deferred.insert(body.id)
        notify("SALVAGE DEATH SETTLEMENT DEFERRED")
        continue
      }
    }
    return deferred
  }

  @discardableResult
  mutating func flushNativeSalvageMotion(
    parking actors: Set<ActorIdentity> = [],
    parkingSystem: SystemIdentity? = nil
  ) -> Bool {
    guard flushNativeSalvageWrecks(parking: actors, parkingSystem: parkingSystem) else {
      return false
    }
    guard let current = commander.alienStorageState?.current else {
      return nativeSalvageMotion.isEmpty
    }
    let pending = current.salvage.pending
    let relevant = pending.filter { identity, value in
      nativeSalvageMotion[identity] != nil
        || value.binding.map({
          actors.contains($0)
            || $0.system == parkingSystem
        }) == true
    }
    guard !relevant.isEmpty else { return true }
    do {
      let byRecord = Dictionary(uniqueKeysWithValues: relevant.map { ($0.value.record, $0.key) })
      let world = try current.snapshot.world.map { record -> AlienStorageWorldRecord in
        guard let identity = byRecord[record.id], let old = pending[identity] else { return record }
        let motion = nativeSalvageMotion[identity]
        guard motion == nil || motion?.actor == old.binding else {
          throw AlienStorageError.historyChanged
        }
        let lot = motion?.lot ?? old.lot
        let time = motion?.time ?? old.physicalTime
        let park = old.binding.map { actors.contains($0) || $0.system == parkingSystem } == true
        let binding = park ? nil : old.binding
        let offer = park ? nil : old.offer
        let dead = motion?.destroyed == true
        switch record {
        case .lot(let item):
          return .lot(
            .init(
              id: item.id, owner: item.owner, plan: item.plan,
              itemIndex: item.itemIndex, issuedAt: item.issuedAt,
              state: dead
                ? .destroyed(at: time)
                : .pending(lot: lot, physicalTime: time, offer: offer, binding: binding)))
        case .companion(let item):
          return .companion(
            .init(
              id: item.id, owner: item.owner, plan: item.plan,
              origin: item.origin, issuedAt: item.issuedAt,
              state: dead
                ? .destroyed(at: time)
                : .pending(lot: lot, physicalTime: time, offer: offer, binding: binding)))
        case .legacyCurrent(let item):
          return .legacyCurrent(
            .init(
              id: item.id, owner: item.owner, claim: item.claim,
              state: dead
                ? .destroyed(at: time)
                : .pending(lot: lot, at: time, offer: offer, binding: binding)))
        default: throw AlienStorageError.invalidJoin
        }
      }
      let previous = current.snapshot
      let revision = previous.worldRevision.addingReportingOverflow(1)
      guard !revision.overflow else { throw AlienStorageError.arithmeticOverflow }
      let next = AlienStorageSnapshot(
        owner: previous.owner, revision: previous.revision,
        worldRevision: revision.partialValue, world: world, sources: previous.sources,
        attachments: previous.attachments, upgrades: previous.upgrades,
        receipts: previous.receipts, commands: previous.commands)
      try commander.replaceAlienStorage(with: next)
      for identity in relevant.keys { nativeSalvageMotion.removeValue(forKey: identity) }
      return true
    } catch { return false }
  }
}

extension Commander {
  func nativeSalvageSceneIsConsistent(
    _ bodies: [SpaceBody], docked: Bool, atColdBoundary: Bool = false
  ) -> Bool {
    guard alienStorageStateValid else { return false }
    guard let native = alienStorageState?.current.salvage else { return true }
    guard nativeWreckSceneIsConsistent(bodies, docked: docked, atColdBoundary: atColdBoundary)
    else {
      return false
    }
    var seen: Set<SalvageLotIdentity> = []
    var actors: Set<ActorIdentity> = []
    for body in bodies {
      guard let physical = body.physical, let payload = physical.payload,
        case .salvage(let identity) = payload,
        native.sections.contains(identity.section)
          || salvageLedger.nativeTransferredSectionIdentities.contains(identity.section)
      else { continue }
      guard seen.insert(identity).inserted, actors.insert(physical.identity).inserted,
        !docked, body.energy.isFinite, body.energy > 0,
        let pending = native.pending[identity],
        pending.binding == physical.identity, pending.offer == nil,
        nativeSalvageBodyOwnershipMatches(body, lot: pending.lot),
        !salvageLedger.ownsPhysicalActor(physical.identity),
        physical.identity.system == flightSimulation.player?.system,
        physical.identity.visit == flightSimulation.visit,
        salvageLedger.boundActor(for: identity) == nil,
        !salvageLedger.pendingLots.contains(where: { $0.identity == identity })
      else {
        return false
      }
    }
    for pending in native.pending.values {
      if let binding = pending.binding {
        guard !docked, actors.contains(binding), seen.contains(pending.lot.identity),
          binding.system == flightSimulation.player?.system,
          binding.visit == flightSimulation.visit
        else { return false }
      }
    }
    return true
  }
}
