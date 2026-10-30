import Foundation

struct AlienAttachmentSummary: Equatable, Sendable {
  let count: Int
  let bonusBasisPoints: Int
  var percent: Double { Double(bonusBasisPoints) / 100 }
  var multiplier: Double { 1 + Double(bonusBasisPoints) / 10000 }
}

/// Supply already resolved ordinary component statistics, never a previously alien-folded base.
struct AlienAttachmentBase: Equatable, Sendable {
  let energyCapacity: Double
  let energyRecharge: Double
  let frontShieldCapacity: Double
  let rearShieldCapacity: Double
  let frontShieldRecharge: Double
  let rearShieldRecharge: Double
  var valid: Bool {
    [
      energyCapacity, energyRecharge, frontShieldCapacity, rearShieldCapacity,
      frontShieldRecharge, rearShieldRecharge,
    ].allSatisfy { $0.isFinite && $0 >= 0 }
      && energyCapacity > 0
  }
}

struct AlienAttachmentEffects: Equatable, Sendable {
  let summaries: [AlienModuleKind: AlienAttachmentSummary]
  let energyModuleCount: Int
  let effective: AlienAttachmentBase

  static func resolve(
    ledger: AlienAttachmentLedger, owner: UUID, activeHull: UUID, normalBase: AlienAttachmentBase
  ) throws -> Self {
    guard ledger.owner == owner else { throw AlienAttachmentError.wrongOwner }
    guard normalBase.valid else { throw AlienAttachmentError.invalidState }
    var values = Dictionary(
      uniqueKeysWithValues: AlienModuleKind.allCases.map {
        ($0, AlienAttachmentSummary(count: 0, bonusBasisPoints: 0))
      })
    for item in ledger.fitted(to: activeHull) {
      let prior = values[item.kind]!
      let count = prior.count.addingReportingOverflow(1)
      let bonus = prior.bonusBasisPoints.addingReportingOverflow(item.contributionBasisPoints)
      guard !count.overflow, !bonus.overflow else { throw AlienAttachmentError.arithmeticOverflow }
      values[item.kind] = .init(count: count.partialValue, bonusBasisPoints: bonus.partialValue)
    }
    return try resolve(summaries: values, normalBase: normalBase)
  }

  static func resolve(
    validated: AlienStorageValidatedState, owner: UUID, activeHull: UUID,
    normalBase: AlienAttachmentBase
  ) throws -> Self {
    guard validated.owner == owner else { throw AlienAttachmentError.wrongOwner }
    guard normalBase.valid else { throw AlienAttachmentError.invalidState }
    return try resolve(summaries: validated.summaries(for: activeHull), normalBase: normalBase)
  }

  private static func resolve(
    summaries values: [AlienModuleKind: AlienAttachmentSummary], normalBase: AlienAttachmentBase
  ) throws -> Self {
    func fold(_ base: Double, kind: AlienModuleKind) throws -> Double {
      let value = base * values[kind]!.multiplier
      guard value.isFinite else { throw AlienAttachmentError.arithmeticOverflow }
      return value
    }
    let effective = AlienAttachmentBase(
      energyCapacity: try fold(normalBase.energyCapacity, kind: .energyCapacity),
      energyRecharge: try fold(normalBase.energyRecharge, kind: .energyRecharge),
      frontShieldCapacity: try fold(normalBase.frontShieldCapacity, kind: .shieldCapacity),
      rearShieldCapacity: try fold(normalBase.rearShieldCapacity, kind: .shieldCapacity),
      frontShieldRecharge: try fold(normalBase.frontShieldRecharge, kind: .shieldRecharge),
      rearShieldRecharge: try fold(normalBase.rearShieldRecharge, kind: .shieldRecharge))
    let energy = values[.energyCapacity]!.count.addingReportingOverflow(
      values[.energyRecharge]!.count)
    guard !energy.overflow, effective.valid else { throw AlienAttachmentError.arithmeticOverflow }
    return .init(summaries: values, energyModuleCount: energy.partialValue, effective: effective)
  }
}
