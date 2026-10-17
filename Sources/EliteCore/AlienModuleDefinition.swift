import Foundation

enum AlienModuleKind: String, CaseIterable, Codable, Sendable {
  case energyCapacity, energyRecharge, shieldCapacity, shieldRecharge
  var definitionID: String { "alien-module-" + rawValue }
  var upgradeDefinitionID: String { "alien-module-upgrade-" + rawValue }
  var axes: [SalvageUpgradeAxis] {
    switch self {
    case .energyCapacity: [.energyCapacity]
    case .energyRecharge: [.energyRecharge]
    case .shieldCapacity: [.frontShieldCapacity, .rearShieldCapacity]
    case .shieldRecharge: [.frontShieldRecharge, .rearShieldRecharge]
    }
  }
  var isEnergyModule: Bool { self == .energyCapacity || self == .energyRecharge }
}

enum AlienAttachmentError: Error, Equatable {
  case invalidSource, wrongOwner, staleRevision, replayedCommand, duplicateItem, replayedSource
  case unavailable, retiredItem, noChange, invalidState, arithmeticOverflow
}

/// Typed source contract only; actual loot creation, recovery and consumption remain actor-owned.
/// These IDs are distinct from legacy artefacts and ordinary capped scalar upgrades.
enum AlienModuleDefinition {
  static let baseBonusBasisPoints = 1000
  static let massKg = 8.0
  static let halfExtents = Vector3(2, 2, 2)

  static func kind(for lot: SalvageLot) throws -> AlienModuleKind {
    guard case .technology(let id, _, _) = lot.content,
      let kind = AlienModuleKind.allCases.first(where: { $0.definitionID == id })
    else { throw AlienAttachmentError.invalidSource }
    try validate(lot, kind: kind, upgrade: false)
    return kind
  }
  static func upgradeBonus(for lot: SalvageLot, kind: AlienModuleKind) throws -> Int {
    try validate(lot, kind: kind, upgrade: true)
    guard case .technology(_, let quality, _) = lot.content else {
      throw AlienAttachmentError.invalidSource
    }
    return quality.bonusBasisPoints
  }
  static func isAttachmentDefinition(_ id: String) -> Bool {
    AlienModuleKind.allCases.contains { $0.definitionID == id || $0.upgradeDefinitionID == id }
  }
  /// A planned item has no world pose yet. Validate its typed evidence directly, without
  /// manufacturing a positioned source lot or claiming actual recovery/ownership.
  static func validatePlanned(_ item: SalvageLootItem) throws {
    guard case .technology(let id, _, _, _) = item.content,
      let kind = AlienModuleKind.allCases.first(where: {
        $0.definitionID == id || $0.upgradeDefinitionID == id
      })
    else { throw AlienAttachmentError.invalidSource }
    try validateEvidence(item, kind: kind, upgrade: id == kind.upgradeDefinitionID)
  }
  private static func validate(_ lot: SalvageLot, kind: AlienModuleKind, upgrade: Bool) throws {
    guard case .technology(let id, let quality, let condition) = lot.content,
      lot.position.finite, lot.position.length.isFinite,
      lot.velocity.finite, lot.velocity.length.isFinite,
      lot.massKg == massKg, lot.halfExtents == halfExtents,
      let evidence = lot.loot, evidence.identity == lot.identity,
      evidence.massKg == lot.massKg, evidence.halfExtents == lot.halfExtents,
      case .technology(let fixedID, let fixedQuality, let fixedCondition, _) = evidence.content,
      fixedID == id, fixedQuality == quality, fixedCondition == condition
    else { throw AlienAttachmentError.invalidSource }
    try validateEvidence(evidence, kind: kind, upgrade: upgrade)
  }
  private static func validateEvidence(
    _ evidence: SalvageLootItem, kind: AlienModuleKind, upgrade: Bool
  ) throws {
    guard case .technology(let id, let quality, let condition, let axis) = evidence.content,
      id == (upgrade ? kind.upgradeDefinitionID : kind.definitionID), (0...100).contains(condition),
      evidence.identity.section.section < 64,
      (0..<8).contains(evidence.identity.section.wreck.system.galaxy),
      (0...256).contains(evidence.identity.section.wreck.system.system),
      evidence.provenance == .alien, evidence.massKg == massKg, evidence.halfExtents == halfExtents,
      evidence.effect == .scalar(axes: kind.axes),
      evidence.bonusBasisPoints == (upgrade ? quality.bonusBasisPoints : baseBonusBasisPoints),
      !evidence.requiresChunking, !evidence.legality.commodityIllegal,
      (0...255).contains(evidence.legality.sourceLegalValue), evidence.saleValueTenths >= 0,
      upgrade ? axis.map({ kind.axes.contains($0) }) == true : axis == nil
    else { throw AlienAttachmentError.invalidSource }
  }
}
