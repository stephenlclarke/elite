import Foundation

extension AlienStorageSnapshot {
  /// Preserve all property, command and receipt histories when only world facts change.
  func replacingNativeWorld(_ world: [AlienStorageWorldRecord]) throws -> Self {
    let next = worldRevision.addingReportingOverflow(1)
    guard !next.overflow else { throw AlienStorageError.arithmeticOverflow }
    return .init(
      owner: owner, revision: revision, worldRevision: next.partialValue,
      world: world, sources: sources, attachments: attachments, upgrades: upgrades,
      receipts: receipts, commands: commands)
  }
}

extension NativeSalvageWorkCycle {
  func observing(
    at time: Double, progress: AlienStorageWorldProgress, seconds: Double,
    damaged: Bool, operation: UInt64
  ) -> Self {
    .init(
      id: id, owner: owner, version: version, inspection: inspection, beganAt: beganAt,
      observedAt: time, progress: progress, currentWorkSeconds: seconds,
      damagedTechnology: damaged, releases: releases, lastRelease: lastRelease,
      lastOperation: operation, depleted: depleted, destroyedAt: destroyedAt)
  }

  func releasing(
    at time: Double, progress: AlienStorageWorldProgress, operation: UInt64,
    requiredWorkSeconds: Double, depleted: Bool
  ) throws -> Self {
    let next = releases.addingReportingOverflow(1)
    guard !next.overflow, currentWorkSeconds == requiredWorkSeconds else {
      throw AlienStorageError.invalidJoin
    }
    return .init(
      id: id, owner: owner, version: version, inspection: inspection, beganAt: beganAt,
      observedAt: time, progress: progress, currentWorkSeconds: 0,
      damagedTechnology: false, releases: next.partialValue,
      lastRelease: .init(operation: operation, at: time, creditedWorkSeconds: requiredWorkSeconds),
      lastOperation: operation, depleted: depleted, destroyedAt: destroyedAt)
  }
}

/// Contains one verified current section, never an array of lifetime tool sessions.
/// No closure, actor, or encoded save is a source of tool authority.
struct NativeSalvageHotWork: Sendable {
  let section: SalvageSectionProfile
  let seed: UInt64
  let plan: SalvageLootPlan
  let actor: ActorIdentity
  let hull: UUID
  let epoch: UUID
  let wreckRecord: UUID
  let wreckSource: NativeSalvageWreck.Source
  let catalogueShipID: String
  let originalCycle: NativeSalvageWorkCycle
  var cycle: NativeSalvageWorkCycle
}

extension Game {
  /// One bounded current authority join, reused before hot work and every cold flush.
  /// Mutable motion is observed separately; immutable source and inspection cannot change.
  func nativeSalvageHotWorkIsCurrent(_ hot: NativeSalvageHotWork) -> Bool {
    guard commander.equipmentOwnerID == hot.cycle.owner, commander.hullInstanceID == hot.hull,
      nativeStationRuntimeEpoch == hot.epoch, hot.actor.system == systemIdentity,
      hot.actor.visit == commander.flightSimulation.visit,
      let state = commander.alienStorageState,
      state.current.owner == hot.cycle.owner,
      state.reference == commander.savedAlienStorageReference,
      state.current.salvage.native.works[hot.cycle.inspection.id] == hot.originalCycle,
      let inspection = state.current.salvage.native.plans[hot.cycle.inspection.id],
      inspection.seed == hot.seed, inspection.plan == hot.plan,
      state.current.salvage.native.sectionProfiles[hot.cycle.inspection.id] == hot.section,
      let wreck = state.current.salvage.native.wrecks[hot.plan.section.wreck],
      wreck.id == hot.wreckRecord, wreck.source == hot.wreckSource,
      wreck.owner == hot.cycle.owner, wreck.seed == hot.seed, wreck.binding == hot.actor,
      wreck.destroyedAt == nil, wreck.catalogueShipID == hot.catalogueShipID
    else { return false }
    return true
  }

  @discardableResult
  mutating func flushNativeSalvageWork() -> Bool {
    if case .none = nativeSalvageWork { return true }
    return flushPresentNativeSalvageWork()
  }

  // Keep the original absent-work return outside reconciliation/publication value storage.
  @inline(never)
  private mutating func flushPresentNativeSalvageWork() -> Bool {
    guard let hot = nativeSalvageWork else { return true }
    guard nativeSalvageHotWorkIsCurrent(hot),
      let previous = commander.alienStorageState?.current.snapshot
    else { return false }
    do {
      var world = previous.world
      if let index = world.firstIndex(where: { $0.id == hot.cycle.id }) {
        guard case .nativeWork = world[index] else { return false }
        world[index] = .nativeWork(hot.cycle)
      } else {
        world.append(.nativeWork(hot.cycle))
      }
      world = try NativeSalvageWorkWorld.reconcile(hot.cycle, plan: hot.plan, in: world)
      if world != previous.world {
        try commander.replaceAlienStorage(with: previous.replacingNativeWorld(world))
      }
      nativeSalvageWork = nil
      return true
    } catch { return false }
  }

  /// Called synchronously by the actual cutter, before this frame's common body movement.
  /// The actor-supplied writer returns before any released actor or ownership is published.
  mutating func publishNativeSalvageRelease(
    body: SpaceBody, at time: Double, operation: UInt64, publish: ScriptPublisher?
  ) -> Bool {
    guard let publish else {
      notify("SAVE COMMANDER TO RELEASE SALVAGE")
      return false
    }
    guard let hot = nativeSalvageWork, nativeSalvageHotWorkIsCurrent(hot),
      body.physical?.identity == hot.actor, body.physical?.salvage?.wreck == hot.plan.section.wreck,
      hot.cycle.currentWorkSeconds == hot.section.workSeconds,
      let previous = commander.alienStorageState?.current.snapshot,
      case .released(let progress, let lots, let depleted) = SalvageSectionCycle.advance(
        plan: hot.plan, progress: hot.cycle.progress, destroyed: false,
        partialWork: hot.cycle.currentWorkSeconds, damagedTechnology: hot.cycle.damagedTechnology,
        section: hot.section, pose: modelPose(of: body),
        velocity: body.physical!.velocity, angularVelocity: body.physical!.angularVelocity,
        tool: .cutter, elapsed: 0, availableEmissionSlots: nil)
    else { return false }
    do {
      let cycle = try hot.cycle.releasing(
        at: time, progress: progress, operation: operation,
        requiredWorkSeconds: hot.section.workSeconds, depleted: depleted)
      var world = previous.world
      if let index = world.firstIndex(where: { $0.id == cycle.id }) {
        world[index] = .nativeWork(cycle)
      } else {
        world.append(.nativeWork(cycle))
      }
      world = try NativeSalvageWorkWorld.reconcile(cycle, plan: hot.plan, in: world)
      let emissions = try SalvageSectionEmissionView(
        seed: hot.seed, plan: hot.plan, progress: progress
      ).emissions()
      for lot in lots {
        guard let origin = emissions.first(where: { $0.value.identity == lot.identity })?.key else {
          throw AlienStorageError.invalidJoin
        }
        if case .technology(let definition, _, _) = lot.content,
          AlienModuleDefinition.isAttachmentDefinition(definition)
        {
          guard case .planned(let itemIndex, 0) = origin else {
            throw AlienStorageError.invalidJoin
          }
          if let index = world.firstIndex(where: {
            if case .lot(let old) = $0 {
              return old.plan == cycle.inspection.id && old.itemIndex == itemIndex
            }
            return false
          }) {
            guard case .lot(let old) = world[index], case .unissued = old.state else {
              throw AlienStorageError.invalidJoin
            }
            world[index] = .lot(
              .init(
                id: old.id, owner: old.owner, plan: old.plan, itemIndex: old.itemIndex,
                issuedAt: time,
                state: .pending(lot: lot, physicalTime: time, offer: nil, binding: nil)))
          } else {
            world.append(
              .lot(
                .init(
                  id: UUID(), owner: cycle.owner, plan: cycle.inspection.id, itemIndex: itemIndex,
                  issuedAt: time,
                  state: .pending(lot: lot, physicalTime: time, offer: nil, binding: nil))))
          }
        } else {
          world.append(
            .companion(
              .init(
                id: UUID(), owner: cycle.owner, plan: cycle.inspection.id, origin: origin,
                issuedAt: time,
                state: .pending(lot: lot, physicalTime: time, offer: nil, binding: nil))))
        }
      }
      var candidate = self
      candidate.nativeSalvageWork = nil
      try candidate.commander.replaceAlienStorage(with: previous.replacingNativeWorld(world))
      candidate.admitPendingNativeSalvage()
      try publish(&candidate)
      self = candidate
      notify(depleted ? "SECTION EXHAUSTED" : "SECTION RELEASED")
      return true
    } catch {
      notify("SALVAGE SAVE FAILED - COMPLETED WORK RETAINED")
      return false
    }
  }
}
