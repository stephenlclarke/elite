import Foundation

/// Known old work before the first inspection. No old material, date or completed
/// cycle is inferred; the original ledger entry remains an immutable audit source.
struct NativeSalvagePreinspection: Codable, Sendable, Equatable {
  let partialWorkSeconds: Double
  let damagedTechnology: Bool
  let ledgerLastOperation: UInt64?
  let ledgerRevision: UInt64

  func valid(required: Double) -> Bool {
    partialWorkSeconds.isFinite && partialWorkSeconds >= 0 && partialWorkSeconds <= required
      && ledgerLastOperation != nil
  }
}

/// A fresh source's original inspection is immutable, including an EMPTY result.
/// Later cutting budgets live in the linked cycle, not in this inspection.
struct NativeSalvageInspection: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let wreck: UUID
  let seed: UInt64
  let plan: SalvageLootPlan
  let sectionProfile: SalvageSectionProfile
  let inspectedAt: Double
  let initialProgress: AlienStorageWorldProgress
  let preinspection: NativeSalvagePreinspection?

  init(
    id: UUID, owner: UUID, wreck: NativeSalvageWreck, at time: Double,
    section: SalvageSectionProfile, facts: SalvageNativeInspectionFacts
  ) throws {
    self.id = id
    self.owner = owner
    self.wreck = wreck.id
    seed = facts.seed
    plan = facts.plan
    sectionProfile = section
    inspectedAt = time
    initialProgress = facts.progress
    preinspection = facts.preinspection
    guard facts.requiredWorkSeconds == section.workSeconds else {
      throw AlienStorageError.invalidJoin
    }
    try validate(wreck: wreck)
  }

  func validate(wreck source: NativeSalvageWreck) throws {
    guard source.valid, wreck == source.id, owner == source.owner, seed == source.seed,
      plan.section.wreck == source.identity, plan.section.section == sectionProfile.index,
      inspectedAt.isFinite, inspectedAt >= source.bornAt,
      let profile = SalvageCatalogue.profile(catalogueShipID: source.catalogueShipID),
      profile.sections.first(where: { $0.index == sectionProfile.index }) == sectionProfile,
      plan.source.roles == profile.sourceRoles,
      sectionProfile.workSeconds.isFinite, sectionProfile.workSeconds > 0,
      preinspection?.valid(required: sectionProfile.workSeconds) ?? true,
      initialProgress.issued.allSatisfy({ $0 == 0 }),
      !initialProgress.discarded.contains(true), initialProgress.issuedStructural == 0,
      initialProgress.materialKind == nil, initialProgress.nextLot == 0
    else { throw AlienStorageError.invalidJoin }
    let structural =
      sectionProfile.structural && plan.profile != .asteroid
      ? SalvageLotEmission.structuralUnits(seed: seed, section: plan.section) : 0
    guard initialProgress.structuralUnits == structural else {
      throw AlienStorageError.invalidJoin
    }
    try SalvageSectionEmissionView(seed: seed, plan: plan, progress: initialProgress).validate()
  }

  private enum CodingKeys: String, CodingKey {
    case id, owner, wreck, seed, plan, sectionProfile, inspectedAt, initialProgress, preinspection
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    owner = try values.decode(UUID.self, forKey: .owner)
    wreck = try values.decode(UUID.self, forKey: .wreck)
    seed = try values.decode(UInt64.self, forKey: .seed)
    plan = try values.decode(AlienStoragePlanEvidence.self, forKey: .plan).value()
    sectionProfile = try values.decode(SalvageSectionProfile.self, forKey: .sectionProfile)
    inspectedAt = try values.decode(Double.self, forKey: .inspectedAt)
    initialProgress = try values.decode(AlienStorageWorldProgress.self, forKey: .initialProgress)
    preinspection = try values.decodeIfPresent(
      NativeSalvagePreinspection.self, forKey: .preinspection)
  }

  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(owner, forKey: .owner)
    try values.encode(wreck, forKey: .wreck)
    try values.encode(seed, forKey: .seed)
    try values.encode(AlienStoragePlanEvidence(plan), forKey: .plan)
    try values.encode(sectionProfile, forKey: .sectionProfile)
    try values.encode(inspectedAt, forKey: .inspectedAt)
    try values.encode(initialProgress, forKey: .initialProgress)
    try values.encodeIfPresent(preinspection, forKey: .preinspection)
  }
}
