import Foundation

/// Cold, timing-aware joins. The projected plan proves issuance; its full work value
/// is never a reusable current cutting budget and is never written as inspection history.
struct NativeSalvagePlanView: Sendable {
  let plans: [UUID: AlienStorageWorldPlan]
  let plansByWreck: [WreckIdentity: [AlienStorageWorldPlan]]
  let works: [UUID: NativeSalvageWorkCycle]
  let sectionProfiles: [UUID: SalvageSectionProfile]
  let baselineSerials: [UUID: UInt32]
  let wrecks: [WreckIdentity: NativeSalvageWreck]
  let inspections: [WreckSectionIdentity: NativeSalvageInspection]
  let depletedSections: Set<WreckSectionIdentity>

  init(_ records: [AlienStorageWorldRecord]) throws {
    var originals: [UUID: AlienStorageWorldPlan] = [:]
    var legacy: [UUID: AlienStorageLegacySection] = [:]
    var fresh: [UUID: NativeSalvageInspection] = [:]
    var wreckByID: [UUID: NativeSalvageWreck] = [:]
    var wrecks: [WreckIdentity: NativeSalvageWreck] = [:]
    var inspections: [WreckSectionIdentity: NativeSalvageInspection] = [:]
    var cycles: [NativeSalvageWorkCycle] = []
    for record in records {
      switch record {
      case .plan(let value): originals[value.id] = value
      case .legacySection(let value): legacy[value.id] = value
      case .nativeWreck(let value):
        guard value.valid, wreckByID.updateValue(value, forKey: value.id) == nil,
          wrecks.updateValue(value, forKey: value.identity) == nil
        else { throw AlienStorageError.invalidJoin }
      case .nativeInspection(let value):
        guard fresh.updateValue(value, forKey: value.id) == nil,
          inspections.updateValue(value, forKey: value.plan.section) == nil
        else { throw AlienStorageError.duplicateKey }
      case .nativeWork(let value): cycles.append(value)
      default: break
      }
    }
    var plans = originals
    var baselines: [UUID: UInt32] = [:]
    var works: [UUID: NativeSalvageWorkCycle] = [:]
    var sections: [UUID: SalvageSectionProfile] = [:]
    for inspection in fresh.values {
      guard let wreck = wreckByID[inspection.wreck] else { throw AlienStorageError.invalidJoin }
      try inspection.validate(wreck: wreck)
      plans[inspection.id] = .init(
        id: inspection.id, owner: inspection.owner, seed: inspection.seed, plan: inspection.plan,
        inspectedAt: inspection.inspectedAt,
        requiredWorkSeconds: inspection.sectionProfile.workSeconds,
        workSeconds: inspection.preinspection?.partialWorkSeconds ?? 0,
        damagedTechnology: inspection.preinspection?.damagedTechnology ?? false, depleted: false,
        destroyed: wreck.destroyedAt != nil,
        lastOperation: inspection.preinspection?.ledgerLastOperation.flatMap { $0 > 0 ? $0 : nil },
        progress: inspection.initialProgress)
    }
    for cycle in cycles {
      let original: AlienStorageWorldPlan
      let section: SalvageSectionProfile
      let baselineWork: Double
      let baselineDamage: Bool
      switch cycle.inspection {
      case .fresh(let id):
        guard let inspection = fresh[id], let value = plans[id] else {
          throw AlienStorageError.invalidJoin
        }
        original = value
        section = inspection.sectionProfile
        baselineWork = value.workSeconds
        baselineDamage = value.damagedTechnology
      case .nativeSingleBudget(let id):
        guard let value = originals[id] else { throw AlienStorageError.invalidJoin }
        guard let wreck = wrecks[value.plan.section.wreck], wreck.owner == value.owner,
          wreck.seed == value.seed,
          let profile = SalvageCatalogue.profile(catalogueShipID: wreck.catalogueShipID)
            ?? SalvageCatalogue.empProfile(catalogueShipID: wreck.catalogueShipID),
          profile.sourceRoles == value.plan.source.roles,
          let resolvedSection = profile.sections.first(where: {
            $0.index == value.plan.section.section
          })
        else { throw AlienStorageError.invalidJoin }
        section = resolvedSection
        original = .init(
          id: value.id, owner: value.owner, seed: value.seed, plan: value.plan,
          inspectedAt: value.inspectedAt, requiredWorkSeconds: section.workSeconds,
          workSeconds: value.progress.nextLot == 0 ? value.workSeconds : section.workSeconds,
          damagedTechnology: value.damagedTechnology, depleted: value.depleted,
          destroyed: value.destroyed, lastOperation: value.lastOperation, progress: value.progress)
        // Old single-budget records retain their original full-work evidence. An already
        // released batch cannot purchase the next cutting budget again.
        baselineWork = value.progress.nextLot == 0 ? value.workSeconds : 0
        baselineDamage = value.progress.nextLot == 0 && value.damagedTechnology
      case .legacy(let id):
        guard let value = legacy[id],
          let wreck = wrecks[value.plan.section.wreck], wreck.owner == value.owner,
          wreck.seed == value.seed,
          let profile = SalvageCatalogue.profile(catalogueShipID: wreck.catalogueShipID)
            ?? SalvageCatalogue.empProfile(catalogueShipID: wreck.catalogueShipID),
          let resolvedSection = profile.sections.first(where: {
            $0.index == value.plan.section.section
          }),
          profile.sourceRoles == value.plan.source.roles
        else { throw AlienStorageError.invalidJoin }
        section = resolvedSection
        original = .init(
          id: id, owner: value.owner, seed: value.seed, plan: value.plan,
          inspectedAt: value.importedAt, requiredWorkSeconds: section.workSeconds,
          workSeconds: value.savedPartialWorkSeconds ?? 0,
          damagedTechnology: value.savedDamagedTechnology, depleted: value.sectionDepleted,
          destroyed: value.sectionDestroyed || value.wreckDestroyed,
          lastOperation: value.savedLedgerLastOperation,
          progress: value.progress)
        baselineWork = value.savedPartialWorkSeconds ?? 0
        baselineDamage = value.savedDamagedTechnology
        baselines[id] = value.progress.nextLot
      }
      guard cycle.owner == original.owner, cycle.beganAt >= original.inspectedAt,
        works.updateValue(cycle, forKey: original.id) == nil,
        !original.depleted || cycle.depleted,
        !original.destroyed || cycle.destroyedAt != nil
      else { throw AlienStorageError.invalidJoin }
      sections[original.id] = section
      try cycle.validate(
        seed: original.seed, plan: original.plan, requiredWorkSeconds: original.requiredWorkSeconds,
        originalProgress: original.progress, section: section, baselineWork: baselineWork,
        baselineDamage: baselineDamage, baselineDepleted: original.depleted,
        baselineOperation: nil)
      if cycle.releases == 0 {
        guard !cycle.depleted || original.depleted || cycle.destroyedAt != nil,
          cycle.currentWorkSeconds >= baselineWork,
          !baselineDamage || cycle.damagedTechnology,
          cycle.progress.nextLot == original.progress.nextLot,
          cycle.progress.issuedStructural == original.progress.issuedStructural
        else { throw AlienStorageError.invalidJoin }
        for index in cycle.progress.issued.indices where !cycle.progress.discarded[index] {
          guard cycle.progress.issued[index] == original.progress.issued[index] else {
            throw AlienStorageError.invalidJoin
          }
        }
      }
      let hadRelease = cycle.releases > 0 || original.progress.nextLot > 0
      plans[original.id] = .init(
        id: original.id, owner: original.owner, seed: original.seed, plan: original.plan,
        inspectedAt: original.inspectedAt, requiredWorkSeconds: original.requiredWorkSeconds,
        workSeconds: hadRelease ? original.requiredWorkSeconds : cycle.currentWorkSeconds,
        damagedTechnology: original.damagedTechnology || cycle.damagedTechnology,
        depleted: cycle.depleted, destroyed: cycle.destroyedAt != nil,
        lastOperation: cycle.lastOperation ?? original.lastOperation, progress: cycle.progress)
    }
    var depletedSections = Set(
      legacy.values.filter { $0.sectionDepleted || $0.sectionDestroyed || $0.wreckDestroyed }.map {
        $0.plan.section
      })
    for (id, value) in plans {
      let dead = wrecks[value.plan.section.wreck]?.destroyedAt != nil
      if value.depleted || value.destroyed || dead { depletedSections.insert(value.plan.section) }
      if dead && !value.destroyed {
        plans[id] = .init(
          id: value.id, owner: value.owner, seed: value.seed, plan: value.plan,
          inspectedAt: value.inspectedAt, requiredWorkSeconds: value.requiredWorkSeconds,
          workSeconds: value.workSeconds, damagedTechnology: value.damagedTechnology,
          depleted: true, destroyed: true, lastOperation: value.lastOperation,
          progress: value.progress)
      }
    }
    self.depletedSections = depletedSections
    self.plans = plans
    plansByWreck = Dictionary(grouping: Array(plans.values), by: { $0.plan.section.wreck })
    self.works = works
    sectionProfiles = sections
    baselineSerials = baselines
    self.wrecks = wrecks
    self.inspections = inspections
  }

  func emissions(for plan: AlienStorageWorldPlan) throws -> [AlienStorageEmissionOrigin:
    SalvageLootItem]
  {
    let values = try SalvageSectionEmissionView(
      seed: plan.seed, plan: plan.plan, progress: plan.progress
    ).emissions()
    guard let baseline = baselineSerials[plan.id] else { return values }
    return values.filter { UInt32($0.value.identity.lot) >= baseline }
  }
}
