import Foundation

extension Game {
  func salvageSectionIsDepleted(_ identity: WreckSectionIdentity) -> Bool {
    if let hot = nativeSalvageWork, hot.plan.section == identity { return hot.cycle.depleted }
    return commander.alienStorageState?.current.salvage.native.depletedSections.contains(identity)
      == true
      || commander.salvageLedger.isDepleted(identity)
  }

  func usesNativeSalvageWork(section: WreckSectionIdentity, profile: SalvageProfile) -> Bool {
    profile.sourceRoles.contains(.thargoid)
      || commander.alienStorageState?.current.salvage.sections.contains(section) == true
  }

  /// The common cutter has already established actual hit, surface, fitting, protection,
  /// abandonment and current visit. Source lookup here cannot substitute for those checks.
  mutating func beginNativeSalvageWork(
    body: SpaceBody, section: SalvageSectionProfile, source: SalvageLootSource
  ) -> Bool {
    guard let actor = body.physical?.identity, let wreck = body.physical?.salvage?.wreck,
      let owner = commander.equipmentOwnerID, let hull = commander.hullInstanceID,
      actor.system == systemIdentity, actor.visit == commander.flightSimulation.visit
    else { return false }
    let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
    if let hot = nativeSalvageWork {
      if hot.plan.section == identity && hot.actor == actor {
        // All comparisons are one bounded section/source, not lifetime history.
        guard nativeSalvageHotWorkIsCurrent(hot), hot.section == section,
          hot.catalogueShipID == body.physical?.catalogueShipID,
          source.roles == hot.plan.source.roles
        else { return false }
        if case .fresh = hot.cycle.inspection, source != hot.plan.source { return false }
        return !hot.cycle.depleted
      }
      guard flushNativeSalvageWork() else { return false }
    }
    guard commander.alienStorageStateValid else { return false }
    do {
      var candidate = self
      candidate.canonicalizeWorkTarget(actor)
      guard
        let canonical = candidate.bodies.first(where: {
          $0.physical?.identity == actor && $0.id == body.id
        }),
        candidate.retainNativeSalvageWreck(canonical)
      else { return false }
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
            lastOperation: nil, depleted: false, destroyedAt: nil)
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
          lastOperation: nil,
          depleted: false, destroyedAt: nil)
        world.append(.nativeWork(cycle))
      } else {
        guard let physicalWreck = view.wrecks[wreck],
          let facts = candidate.commander.salvageLedger.freshNativeInspection(
            wreck: wreck, section: section, source: source)
        else { return false }
        guard facts.matches(candidate.commander.salvageLedger) else { return false }
        let inspection = try NativeSalvageInspection(
          id: UUID(), owner: owner, wreck: physicalWreck, at: time, section: section, facts: facts)
        plan = facts.plan
        seed = facts.seed
        cycle = .init(
          id: UUID(), owner: owner, version: 1, inspection: .fresh(inspection.id), beganAt: time,
          observedAt: time, progress: facts.progress,
          currentWorkSeconds: facts.preinspection?.partialWorkSeconds ?? 0,
          damagedTechnology: facts.preinspection?.damagedTechnology ?? false, releases: 0,
          lastRelease: nil,
          lastOperation: nil,
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
      guard
        let retained = candidate.commander.alienStorageState?.current.salvage.native.wrecks[wreck]
      else { return false }
      candidate.nativeSalvageWork = .init(
        section: section, seed: seed, plan: plan, actor: actor, hull: hull,
        epoch: candidate.nativeStationRuntimeEpoch, wreckRecord: retained.id,
        wreckSource: retained.source, catalogueShipID: retained.catalogueShipID,
        originalCycle: cycle, cycle: cycle)
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
      let actual = bodies.first(where: { $0.physical?.identity == hot.actor && $0.id == body.id }),
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
          section: section, pose: modelPose(of: actual), velocity: actual.physical!.velocity,
          angularVelocity: actual.physical!.angularVelocity, tool: .cutter,
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
      _ = publishNativeSalvageRelease(
        body: actual, at: time, operation: operation, publish: publish)
    }
    return true
  }
}
