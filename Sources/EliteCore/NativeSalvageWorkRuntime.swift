import Foundation

extension Game {
  func salvageSectionIsDepleted(_ identity: WreckSectionIdentity) -> Bool {
    if let hot = nativeSalvageWork, hot.plan.section == identity { return hot.cycle.depleted }
    return commander.alienStorageState?.current.salvage.native.depletedSections.contains(identity)
      == true
      || commander.salvageLedger.isDepleted(identity)
  }

  func usesNativeSalvageWork(wreck: WreckIdentity, profile: SalvageProfile) -> Bool {
    profile.sourceRoles.contains(.thargoid)
      || commander.alienStorageState?.current.salvage.wrecksWithSections.contains(wreck) == true
  }

  /// The common cutter has already established actual hit, surface, fitting, protection,
  /// abandonment and current visit. Source lookup here cannot substitute for those checks.
  mutating func beginNativeSalvageWork(
    body: SpaceBody, section: SalvageSectionProfile, source: SalvageLootSource
  ) -> Bool {
    guard let actor = body.physical?.identity, let wreck = body.physical?.salvage?.wreck,
      let owner = commander.equipmentOwnerID, actor.system == systemIdentity,
      actor.visit == commander.flightSimulation.visit, commander.alienStorageStateValid
    else { return false }
    let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
    if let hot = nativeSalvageWork {
      if hot.plan.section == identity && hot.actor == actor { return !hot.cycle.depleted }
      guard flushNativeSalvageWork() else { return false }
    }
    do {
      var candidate = self
      guard candidate.retainNativeSalvageWreck(body) else { return false }
      if candidate.commander.salvageLedger.hasInspectedSection(identity),
        candidate.commander.alienStorageState?.current.salvage.sections.contains(identity) != true
      {
        let imported = try NativeSalvageImport(
          ledger: candidate.commander.salvageLedger, section: identity, owner: owner,
          at: candidate.commander.flightSimulation.physicalTime,
          previous: candidate.commander.alienStorageState?.current.snapshot)
        try imported.apply(to: &candidate.commander)
      }
      guard let previous = candidate.commander.alienStorageState?.current.snapshot,
        let view = candidate.commander.alienStorageState?.current.salvage.native
      else { return false }
      let time = candidate.commander.flightSimulation.physicalTime
      var world = previous.world
      let plan: SalvageLootPlan
      let seed: UInt64
      let cycle: NativeSalvageWorkCycle
      if let original = view.plans.values.first(where: { $0.plan.section == identity }) {
        plan = original.plan
        seed = original.seed
        guard !original.depleted, !original.destroyed else { return false }
        if let existing = view.works[original.id] {
          cycle = existing
        } else {
          let reference: NativeSalvageWorkCycle.Inspection
          let seconds: Double
          let damage: Bool
          if let legacy = world.compactMap({ record -> AlienStorageLegacySection? in
            if case .legacySection(let value) = record, value.id == original.id { return value }
            return nil
          }).first {
            reference = .legacy(original.id)
            seconds = legacy.savedPartialWorkSeconds ?? 0
            damage = legacy.savedDamagedTechnology
          } else {
            reference =
              view.inspections[identity] == nil
              ? .nativeSingleBudget(original.id) : .fresh(original.id)
            seconds = original.progress.nextLot == 0 ? original.workSeconds : 0
            damage = original.progress.nextLot == 0 && original.damagedTechnology
          }
          cycle = .init(
            id: UUID(), owner: owner, version: 1, inspection: reference, beganAt: time,
            observedAt: time, progress: original.progress, currentWorkSeconds: seconds,
            damagedTechnology: damage, releases: 0, lastRelease: nil,
            lastOperation: original.lastOperation, depleted: false, destroyedAt: nil)
          world.append(.nativeWork(cycle))
        }
      } else if let legacy = world.compactMap({ record -> AlienStorageLegacySection? in
        if case .legacySection(let value) = record, value.plan.section == identity { return value }
        return nil
      }).first {
        guard !legacy.sectionDepleted, !legacy.sectionDestroyed, !legacy.wreckDestroyed else {
          return false
        }
        plan = legacy.plan
        seed = legacy.seed
        cycle = .init(
          id: UUID(), owner: owner, version: 1, inspection: .legacy(legacy.id), beganAt: time,
          observedAt: time, progress: legacy.progress,
          currentWorkSeconds: legacy.savedPartialWorkSeconds ?? 0,
          damagedTechnology: legacy.savedDamagedTechnology, releases: 0, lastRelease: nil,
          lastOperation: legacy.savedLedgerLastOperation.flatMap { $0 > 0 ? $0 : nil },
          depleted: false, destroyedAt: nil)
        world.append(.nativeWork(cycle))
      } else {
        guard let physicalWreck = view.wrecks[wreck],
          let facts = candidate.commander.salvageLedger.freshNativeInspection(
            wreck: wreck, section: section, source: source)
        else { return false }
        let inspection = try NativeSalvageInspection(
          id: UUID(), owner: owner, wreck: physicalWreck, at: time, section: section, facts: facts)
        plan = facts.plan
        seed = facts.seed
        cycle = .init(
          id: UUID(), owner: owner, version: 1, inspection: .fresh(inspection.id), beganAt: time,
          observedAt: time, progress: facts.progress, currentWorkSeconds: 0,
          damagedTechnology: false, releases: 0, lastRelease: nil, lastOperation: nil,
          depleted: false, destroyedAt: nil)
        world.append(.nativeInspection(inspection))
        world.append(.nativeWork(cycle))
        for (index, item) in plan.items.enumerated() {
          if case .technology(let definition, _, _, _) = item.content,
            AlienModuleDefinition.isAttachmentDefinition(definition),
            let itemIndex = UInt16(exactly: index)
          {
            world.append(
              .lot(
                .init(
                  id: UUID(), owner: owner, plan: inspection.id, itemIndex: itemIndex,
                  issuedAt: nil, state: .unissued)))
          }
        }
      }
      if world != previous.world {
        try candidate.commander.replaceAlienStorage(with: previous.replacingNativeWorld(world))
      }
      candidate.nativeSalvageWork = .init(
        section: section, seed: seed, plan: plan, actor: actor, cycle: cycle)
      self = candidate
      return true
    } catch { return false }
  }

  mutating func advanceNativeSalvageWork(
    body: SpaceBody, section: SalvageSectionProfile, source: SalvageLootSource,
    delta: Double, publish: ScriptPublisher?
  ) -> Bool {
    guard beginNativeSalvageWork(body: body, section: section, source: source),
      var hot = nativeSalvageWork,
      let operation = commander.flightSimulation.allocateIncident()
    else { return false }
    let time = commander.flightSimulation.physicalTime
    if hot.cycle.currentWorkSeconds < section.workSeconds {
      // The shared allocator sets material/damage even before release. Issuance remains
      // private until the complete budget and the actor's durable publication succeed.
      guard
        case .progress(let progress, _) = SalvageSectionCycle.advance(
          plan: hot.plan, progress: hot.cycle.progress, destroyed: false,
          partialWork: 0, damagedTechnology: hot.cycle.damagedTechnology,
          section: section, pose: modelPose(of: body), velocity: body.physical!.velocity,
          angularVelocity: body.physical!.angularVelocity, tool: .cutter,
          elapsed: 0, availableEmissionSlots: nil)
      else { return false }
      hot.cycle = hot.cycle.observing(
        at: time, progress: progress,
        seconds: min(section.workSeconds, hot.cycle.currentWorkSeconds + delta),
        damaged: hot.cycle.damagedTechnology, operation: operation)
      energy -= delta * 2
      laserHeat += delta * 6
      laserFlash = 0.08
      dischargeAudio.record(.salvageCutter)
      nativeSalvageWork = hot
    }
    if hot.cycle.currentWorkSeconds == section.workSeconds {
      _ = publishNativeSalvageRelease(body: body, at: time, operation: operation, publish: publish)
    }
    return true
  }
}
