import Foundation

public enum ScriptGearStatus: String, Codable, Sendable { case issued, returned, released }

/// Retained issue history and rights. Physical devices belong only to the canonical inventory.
public struct ScriptGearIssue: Codable, Sendable, Equatable {
  public let resource: String
  public let kind: OwnedGearKind
  public let items: [UUID]
  public let loan: Bool
  public let returnRemaining: Bool
  public var status: ScriptGearStatus
  public var consumed: Set<UUID>
  public let savedGearVersion: Int?
  public let source: EquipmentIssueSource?
  public let node: EquipmentNodeID?
  public let displacements: [EquipmentIssueDisplacement]?
  public let legacyMissingItems: Set<UUID>?

  public init(
    resource: String, kind: OwnedGearKind, items: [UUID], loan: Bool, returnRemaining: Bool,
    status: ScriptGearStatus = .issued, consumed: Set<UUID> = [], savedGearVersion: Int? = nil,
    source: EquipmentIssueSource? = nil, node: EquipmentNodeID? = nil,
    displacements: [EquipmentIssueDisplacement]? = nil, legacyMissingItems: Set<UUID>? = nil
  ) {
    self.resource = resource
    self.kind = kind
    self.items = items
    self.loan = loan
    self.returnRemaining = returnRemaining
    self.status = status
    self.consumed = consumed
    self.savedGearVersion = savedGearVersion
    self.source = source
    self.node = node
    self.displacements = displacements
    self.legacyMissingItems = legacyMissingItems
  }

  var valid: Bool {
    guard PackValidation.localID(resource), kind.valid, (1...32).contains(items.count),
      Set(items).count == items.count, consumed.isSubset(of: Set(items)),
      status != .released || loan, status != .returned || returnRemaining || consumed.isEmpty
    else { return false }
    switch savedGearVersion ?? 1 {
    case 1:
      return source == nil && node == nil && displacements == nil && legacyMissingItems == nil
    case 2:
      guard let source, let node, let displacements, source.valid,
        source.resource == resource, node == kind.canonicalNode,
        displacements.count <= 32,
        Set(displacements.map(\.item)).count == displacements.count,
        Set(displacements.map(\.location)).count == displacements.count,
        displacements.allSatisfy({ !items.contains($0.item) && $0.location.slot.valid })
      else { return false }
      let missing = legacyMissingItems ?? []
      return missing.count <= 32 && missing.isSubset(of: Set(items))
        && missing.isDisjoint(with: consumed) && (!loan || missing.isEmpty)
    default:
      return false
    }
  }

  func valid(for instance: borrowing ScriptInstance) -> Bool {
    valid(forMission: instance.id, packDigest: instance.digest)
  }

  func valid(forMission mission: UUID, packDigest: String) -> Bool {
    valid
      && (savedGearVersion != 2
        || source
          == EquipmentIssueSource(
            mission: mission, resource: resource, packDigest: packDigest))
  }

  var obligation: EquipmentIssueObligationSnapshot? {
    guard savedGearVersion == 2, valid, let source, let node, let displacements else { return nil }
    let providerStatus: EquipmentIssueStatus
    switch status {
    case .issued: providerStatus = .issued
    case .returned: providerStatus = .returned
    case .released: providerStatus = .released
    }
    return .init(
      source: source, node: node, items: items, consumed: consumed, status: providerStatus,
      loan: loan, returnRemaining: returnRemaining, displacements: displacements,
      legacyMissingItems: legacyMissingItems ?? [])
  }

  func replacingDisplacements(_ values: [EquipmentIssueDisplacement]) -> Self {
    .init(
      resource: resource, kind: kind, items: items, loan: loan, returnRemaining: returnRemaining,
      status: status, consumed: consumed, savedGearVersion: savedGearVersion, source: source,
      node: node, displacements: values, legacyMissingItems: legacyMissingItems)
  }
}

extension OwnedGearKind {
  var canonicalNode: EquipmentNodeID? { EquipmentRuntimeCatalog.node(for: name) }
}

extension OwnedGearSlot {
  var canonicalSlot: ComponentFittingSlot? {
    switch self {
    case .laser(let mount): .laser(mount)
    case .pylon(let index): .missilePylon(index)
    case .fuelStorage(let index): .fuelStorage(index)
    case .module(let name):
      EquipmentRuntimeCatalog.node(for: name).flatMap(EquipmentRuntimeCatalog.slot)
    }
  }
}
