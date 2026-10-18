import Foundation

extension Game {
  /// Re-entry uses the retained genuine lot pose. Admission still uses the common
  /// allocator, cargo budget, protection, geometry, and actual spawn receipts.
  mutating func admitPendingNativeSalvage() {
    guard !docked, let native = commander.alienStorageState?.current.salvage else { return }
    let available = (native.pendingBySystem[systemIdentity] ?? []).filter {
      $0.binding == nil && $0.offer == nil && $0.lot.identity.section.wreck.system == systemIdentity
    }.sorted {
      let a = $0.lot.identity
      let b = $1.lot.identity
      if a.section.wreck.site != b.section.wreck.site {
        return a.section.wreck.site < b.section.wreck.site
      }
      if a.section.wreck.lineage != b.section.wreck.lineage {
        return a.section.wreck.lineage < b.section.wreck.lineage
      }
      if a.section.section != b.section.section { return a.section.section < b.section.section }
      return a.lot < b.lot
    }
    for pending in available {
      guard let context = gameplayContext(), context.budget.ordinaryRemaining > 0,
        context.budget.active[.cargo, default: 0] < PopulationClass.cargo.maximum
      else { return }
      let lot = pending.lot
      guard !context.protection.protectedPayloads.contains(.salvage(lot.identity)),
        (lot.position - context.player.position).length <= context.perceptionRadius
      else { continue }
      var candidate = self
      guard candidate.prepareNativeSalvageOfferParent(for: lot) else { continue }
      guard
        let spawn = candidate.commander.salvageLedger.reserveNativeSpawnIdentity(
          system: context.system, visit: context.visit),
        candidate.stageNativeSalvageOffer(pending, spawn: spawn, context: context)
      else { return }
      let request = NativeSalvageOffer.request(lot: lot, spawn: spawn)
      let receipts = candidate.admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit,
          revision: context.revision, batches: [.init(requests: [request], atomic: false)],
          intents: []))
      guard receipts.count == 1, receipts[0].request == spawn, receipts[0].refusal == nil,
        let actor = receipts[0].actor,
        let offered = candidate.commander.alienStorageState?.current.salvage.pending[lot.identity],
        offered.record == pending.record, offered.lot == lot,
        offered.physicalTime == pending.physicalTime,
        offered.offer == spawn, offered.binding == nil,
        let previous = candidate.commander.alienStorageState?.current.snapshot
      else { continue }
      do {
        let world = try previous.world.map { record -> AlienStorageWorldRecord in
          guard record.id == pending.record else { return record }
          switch record {
          case .lot(let item):
            return .lot(
              .init(
                id: item.id, owner: item.owner, plan: item.plan,
                itemIndex: item.itemIndex, issuedAt: item.issuedAt,
                state: .pending(
                  lot: lot, physicalTime: pending.physicalTime, offer: nil, binding: actor)))
          case .companion(let item):
            return .companion(
              .init(
                id: item.id, owner: item.owner, plan: item.plan,
                origin: item.origin, issuedAt: item.issuedAt,
                state: .pending(
                  lot: lot, physicalTime: pending.physicalTime, offer: nil, binding: actor)))
          case .legacyCurrent(let item):
            return .legacyCurrent(
              .init(
                id: item.id, owner: item.owner, claim: item.claim,
                state: .pending(lot: lot, at: pending.physicalTime, offer: nil, binding: actor)))
          default: throw AlienStorageError.invalidJoin
          }
        }
        let revision = previous.worldRevision.addingReportingOverflow(1)
        guard !revision.overflow else { return }
        try candidate.commander.replaceAlienStorage(
          with: .init(
            owner: previous.owner,
            revision: previous.revision, worldRevision: revision.partialValue, world: world,
            sources: previous.sources, attachments: previous.attachments,
            upgrades: previous.upgrades,
            receipts: previous.receipts, commands: previous.commands))
        guard candidate.commander.nativeSalvageSceneIsConsistent(candidate.bodies, docked: false)
        else { continue }
        self = candidate
      } catch { continue }
    }
  }
}
